import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geoflutterfire2/geoflutterfire2.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:Dadacabs/Model/driver_model.dart';
import 'package:Dadacabs/Model/trip_model.dart';
import 'package:Dadacabs/View/Screens/Main_Screens/Home_Screen/home_providers.dart';

import '../utils/error_notification.dart';
import '../utils/marker_icons.dart';

final globalFirestoreRepoProvider = Provider<FirestoreRepo>((ref) {
  return FirestoreRepo();
});

class FirestoreRepo {
  FirebaseFirestore db = FirebaseFirestore.instance;
  FirebaseAuth auth = FirebaseAuth.instance;
  final GeoFlutterFire geo = GeoFlutterFire();
  
  // Track active stream subscriptions
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _driversSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _locationsSubscription;

  // Caches for two-stream merge
  final Map<String, Map<String, dynamic>> _driverProfileCache = {};
  final Map<String, Map<String, dynamic>> _driverLocationCache = {};

  // Modified by Jayant Pandit on 2026-07-09 14:30:00
  // Reason: Track whether each cache has been populated at least once, so we only merge when BOTH are ready
  // This prevents the race condition where one stream fires before the other, producing incomplete merged data
  bool _profileCacheReady = false;
  bool _locationCacheReady = false;

  Future<void> getDriverData(
      BuildContext context, WidgetRef ref, LatLng userPos) async {
    try {
      await _driversSubscription?.cancel();
      await _locationsSubscription?.cancel();
      _driverProfileCache.clear();
      _driverLocationCache.clear();
      _profileCacheReady = false;
      _locationCacheReady = false;

      // Modified by Jayant Pandit on 2026-07-08 18:00:00
      // Reason: Remove server-side isOnline filter. Some drivers have isOnline as string "true" instead of boolean true,
      // which Firestore .where(isEqualTo: true) silently filters out. Fetch all and filter client-side via _isDriverOnline().
      final driversStream = db.collection("drivers").snapshots();

      _driversSubscription = driversStream.listen((event) {
        try {
          _driverProfileCache.clear();
          for (final doc in event.docs) {
            final data = doc.data();
            data['__driverId'] = doc.id;
            _driverProfileCache[doc.id] = data;
          }
          _profileCacheReady = true;
          // Modified by Jayant Pandit on 2026-07-09 14:30:00
          // Reason: Process drivers immediately when profiles arrive instead of waiting for locations.
          // Previously required BOTH caches ready, which blocked forever if driver_locations never fired.
          // Now: process profiles immediately; locations will re-merge when they arrive.
          if (_profileCacheReady) {
            _mergeAndProcessDrivers(ref);
          }
        } catch (e) {
          print("ERROR processing drivers stream: $e");
        }
      }, onError: (error) {
        print("ERROR drivers stream failed: $error");
        _tryFallbackDriversStream(ref);
      });

      /// Stream 2: driver_locations collection -- supplementary real-time locations
      final locationsStream = db.collection("driver_locations").snapshots();

      _locationsSubscription = locationsStream.listen((event) {
        try {
          _driverLocationCache.clear();
          for (final doc in event.docs) {
            final data = doc.data();
            data['__driverId'] = doc.id;
            _driverLocationCache[doc.id] = data;
          }
          _locationCacheReady = true;
          if (_profileCacheReady && _locationCacheReady) {
            _mergeAndProcessDrivers(ref);
          }
        } catch (e) {
          print("ERROR processing driver_locations stream: $e");
        }
      }, onError: (error) {
        print("ERROR driver_locations stream failed: $error");
      });
    } catch (e) {
      if (context.mounted) {
        ErrorNotification().showError(context, "An Error Occurred $e");
      }
    }
  }

  // Modified by Jayant Pandit on 2026-07-09 18:00:00
  // Reason: Changed from void to async + await _processDriverDataList.
  // Previously void silently discarded the Future; if MarkerIcons.getIconForVehicle threw (e.g. cold start),
  // the entire driver list would be lost and zero drivers shown on map.
  Future<void> _mergeAndProcessDrivers(WidgetRef ref) async {
    final allIds = <String>{..._driverProfileCache.keys, ..._driverLocationCache.keys};
    final merged = <Map<String, dynamic>>[];

    for (final id in allIds) {
      final profile = _driverProfileCache[id];
      final location = _driverLocationCache[id];
      final mergedData = <String, dynamic>{};
      if (profile != null) mergedData.addAll(profile);
      if (location != null) mergedData.addAll(location);
      mergedData['__driverId'] = id;
      merged.add(mergedData);
    }

    try {
      await _processDriverDataList(merged, ref);
    } catch (e) {
      print("ERROR: _processDriverDataList failed: $e");
    }
  }

  Future<void> _tryFallbackDriversStream(WidgetRef ref) async {
    try {
      await _driversSubscription?.cancel();
      // Modified by Jayant Pandit on 2026-07-08 18:00:00
      // Reason: Same as main stream — remove server-side isOnline filter so string "true" values are not excluded
      final fallbackStream = db.collection("Drivers").snapshots();
      _driversSubscription = fallbackStream.listen((event) {
        try {
          _driverProfileCache.clear();
          for (final doc in event.docs) {
            final data = doc.data();
            data['__driverId'] = doc.id;
            _driverProfileCache[doc.id] = data;
          }
          _profileCacheReady = true;
          if (_profileCacheReady && _locationCacheReady) {
            _mergeAndProcessDrivers(ref);
          }
        } catch (e) {
          print("ERROR processing fallback Drivers stream: $e");
        }
      }, onError: (error) {
        print("ERROR fallback Drivers stream failed: $error");
      });
    } catch (e) {
      print("ERROR setting up fallback driver stream: $e");
    }
  }

  Future<void> _processDriverDataList(
      List<Map<String, dynamic>> docs,
      WidgetRef ref) async {
    try {
      print('DEBUG Firestore: Processing driver snapshot of ${docs.length} documents');

      final List<DriverModel> onlineDrivers = [];
      final Set<Marker> markers = {};
      int onlineCount = 0;
      int offlineCount = 0;
      int noLocationCount = 0;
      final Set<String> seenDriverIds = {};

      for (final driverData in docs) {
        try {
          if (driverData is! Map<String, dynamic>) {
            print('⚠️ Skipping driver entry that is not a Map: ${driverData.runtimeType}');
            continue;
          }

          final driverId = driverData['__driverId']?.toString() ?? '';
          if (driverId.isNotEmpty) {
            if (seenDriverIds.contains(driverId)) {
              print('LOG Driver: Duplicate ID $driverId skipped');
              continue;
            }
            seenDriverIds.add(driverId);
          }

          final isOnline = _isDriverOnline(driverData);
          if (!isOnline) {
            offlineCount++;
            continue;
          }

          final LatLng? driverLatLng = _parseDriverLocation(driverData);
          if (driverLatLng == null) {
            noLocationCount++;
            print('LOG Driver: Online driver $driverId has no parsable location');
            continue;
          }

          final position = Position(
            latitude: driverLatLng.latitude,
            longitude: driverLatLng.longitude,
            timestamp: DateTime.now(),
            accuracy: 0,
            altitude: 0,
            altitudeAccuracy: 0,
            heading: 0,
            headingAccuracy: 0,
            speed: 0,
            speedAccuracy: 0,
          );

          final carType = driverData["carType"] ?? driverData["Car Type"] ?? '';
          final carName = driverData["carName"] ?? driverData["Car Name"] ?? '';
          final carPlateNum = driverData["carPlateNum"] ?? driverData["Car Plate Num"] ?? '';
          final driverStatus = driverData["driverStatus"] ?? driverData["status"] ?? '';
          final email = driverData["email"]?.toString() ?? '';
          final name = driverData["name"]?.toString() ?? '';
          // Modified by Jayant Pandit on 2026-07-11 11:00:00
          // Reason: Extract driver profile photo URL from Firestore 'profileUrl' field
          // Also check nested documents.driver_photo.url as fallback (Partner app writes both)
          final profileUrl = driverData["profileUrl"]?.toString()
              ?? driverData["documents"]?["driver_photo"]?["url"]?.toString();

          final model = DriverModel(
            carName,
            carPlateNum,
            carType,
            position,
            driverStatus,
            email,
            name,
            // Modified by Jayant Pandit on 2026-07-11 11:00:00
            // Reason: Pass profileUrl to DriverModel so customer app can display driver photo
            profileUrl: profileUrl,
          );

          onlineDrivers.add(model);

          final markerId = 'driver_$driverId';
          final icon = await MarkerIcons.getIconForVehicle(carType);
          final marker = Marker(
            markerId: MarkerId(markerId),
            infoWindow: InfoWindow(
              title: carName.isNotEmpty ? carName : name,
              snippet: '$carType - Online',
            ),
            position: driverLatLng,
            icon: icon,
          );
          markers.add(marker);

          onlineCount++;
        } catch (e) {
          print("⚠️ Error processing combined driver data: $e");
        }
      }

      print('LOG Driver: online=$onlineCount offline=$offlineCount noLocation=$noLocationCount total=$onlineCount drivers on map');

      ref.read(homeScreenAvailableDriversProvider.notifier).update((state) => onlineDrivers);
      ref.read(homeScreenMainMarkersProvider.notifier).update((state) => markers);
    } catch (e) {
      print("⚠️ Error processing combined driver snapshot: $e");
    }
  }

  /// Check if a driver is online, handling multiple field formats
  bool _isDriverOnline(Map<String, dynamic> data) {
    // Check isOnline field (boolean or string)
    if (data.containsKey("isOnline")) {
      final isOnlineVal = data["isOnline"];
      if (isOnlineVal is bool) {
        return isOnlineVal;
      }
      if (isOnlineVal is String) {
        return isOnlineVal.toLowerCase() == "true";
      }
      if (isOnlineVal is int) {
        return isOnlineVal == 1;
      }
    }
    
    // Fallback: check driverStatus field
    final driverStatus = data["driverStatus"]?.toString().toLowerCase() ?? '';
    if (driverStatus == "online" || driverStatus == "idle" || driverStatus == "active" || driverStatus == "available") {
      return true;
    }
    
    // Fallback: check service availability fields used in some legacy documents
    final statusField = data["status"]?.toString().toLowerCase() ?? '';
    if (statusField == "online" || statusField == "idle" || statusField == "active" || statusField == "available") {
      return true;
    }
    
    // If neither field indicates online, driver is considered offline
    return false;
  }

  /// Parse driver location from various possible field formats
  LatLng? _parseDriverLocation(Map<String, dynamic> data) {
    final driverLocData = data["driverLoc"]
        ?? data["location"]
        ?? data["loc"]
        ?? data["position"]
        ?? data["coordinates"]
        ?? data["currentLocation"]
        ?? data["current_loc"]
        ?? data["current_location"]
        ?? data["geoPoint"]
        ?? data["geopoint"];
    if (driverLocData == null) {
      return null;
    }

    try {
      // Format 1: Map with 'geopoint' key (GeoFlutterFire format)
      if (driverLocData is Map) {
        final possibleGeoPoint = driverLocData["geopoint"] ?? driverLocData["geoPoint"] ?? driverLocData["geo_point"];
        if (possibleGeoPoint != null) {
          if (possibleGeoPoint is GeoPoint) {
            return LatLng(possibleGeoPoint.latitude, possibleGeoPoint.longitude);
          }
          if (possibleGeoPoint is Map) {
            // Modified by Jayant Pandit on 2026-07-09 18:00:00
            // Reason: Handle _latitude/_longitude keys (GeoFlutterFire uses private field names internally)
            final lat = _toDouble(possibleGeoPoint["latitude"] ?? possibleGeoPoint["_latitude"] ?? possibleGeoPoint["lat"]);
            final lng = _toDouble(possibleGeoPoint["longitude"] ?? possibleGeoPoint["_longitude"] ?? possibleGeoPoint["lng"] ?? possibleGeoPoint["lon"]);
            if (lat != null && lng != null) {
              return LatLng(lat, lng);
            }
          }
        }

        // Format 2: Map with direct latitude/longitude keys (also handle _latitude/_longitude from GeoFlutterFire internal format)
        final directLat = _toDouble(driverLocData["latitude"] ?? driverLocData["_latitude"] ?? driverLocData["lat"]);
        final directLng = _toDouble(driverLocData["longitude"] ?? driverLocData["_longitude"] ?? driverLocData["lng"] ?? driverLocData["lon"]);
        if (directLat != null && directLng != null) {
          return LatLng(directLat, directLng);
        }
      }

      // Format 4: Direct GeoPoint
      if (driverLocData is GeoPoint) {
        return LatLng(driverLocData.latitude, driverLocData.longitude);
      }

      if (driverLocData is String) {
        final components = driverLocData.split(RegExp(r'[ ,;]+'));
        if (components.length >= 2) {
          final lat = _toDouble(components[0]);
          final lng = _toDouble(components[1]);
          if (lat != null && lng != null) {
            return LatLng(lat, lng);
          }
        }
      }

      if (driverLocData is List && driverLocData.length >= 2) {
        final lat = _toDouble(driverLocData[0]);
        final lng = _toDouble(driverLocData[1]);
        if (lat != null && lng != null) {
          return LatLng(lat, lng);
        }
      }
    } catch (e) {
      print("⚠️ Error parsing driver location: $e");
    }

    return null;
  }

  bool _hasValidDriverData(Map<String, dynamic> data) {
    if (!_isDriverOnline(data)) return false;
    return _parseDriverLocation(data) != null;
  }

  /// Safely convert a value to double
  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  // Modified by Jayant Pandit on 2026-07-08 18:00:00
  // Reason: Changed return type from void to Future<void> so callers can await the Firestore write and handle errors
  // Modified by Jayant Pandit on 2026-07-11 10:00:00
  // Reason: Added detailed logging for ride request write to help debug notification delivery failures.
  // Logs trip ID, collection path, user info, and pickup/dropoff coordinates.
  // Modified by Jayant Pandit on 2026-07-11 12:30:00
  // Reason: Enhanced logging to dump full tripJson keys, pickupLoc format, and carType/serviceType values so we can
  // verify what the Partner app's GeoFlutterFire within() query will see in the Firestore trips collection.
  Future<void> addUserRideRequestToDB(
      context, WidgetRef ref, DriverModel? selectedDriver, TripModel trip) async {
    try {
      debugPrint("FIRESTORE_REPO: Writing ride request for trip ${trip.tripId}, user=${trip.userId}, pickup=(${trip.pickupLocation.latitude},${trip.pickupLocation.longitude})");

      final pickupLocPoint = geo.point(
        latitude: trip.pickupLocation.latitude,
        longitude: trip.pickupLocation.longitude,
      ).data;

      final dropoffLocPoint = geo.point(
        latitude: trip.dropoffLocation.latitude,
        longitude: trip.dropoffLocation.longitude,
      ).data;

      final tripJson = trip.toJson();
      tripJson['pickupLoc'] = pickupLocPoint;
      tripJson['dropoffLoc'] = dropoffLocPoint;
      if (selectedDriver != null) {
        tripJson['driverId'] = selectedDriver.email;
        tripJson['driverName'] = selectedDriver.name;
        tripJson['carName'] = selectedDriver.carName;
        tripJson['carPlateNum'] = selectedDriver.carPlateNum;
        tripJson['carType'] = selectedDriver.carType;
      }

      // Log critical fields for Partner app debugging
      debugPrint("FIRESTORE_REPO: tripJson keys=${tripJson.keys.toList()}");
      debugPrint("FIRESTORE_REPO: tripJson[status]=${tripJson['status']}, tripJson[carType]=${tripJson['carType']}, tripJson[serviceType]=${tripJson['serviceType']}");
      debugPrint("FIRESTORE_REPO: tripJson[pickupLoc]=${tripJson['pickupLoc']}");
      debugPrint("FIRESTORE_REPO: tripJson[pickupLat]=${tripJson['pickupLat']}, tripJson[pickupLng]=${tripJson['pickupLng']}");
      debugPrint("FIRESTORE_REPO: selectedDriver=${selectedDriver != null ? selectedDriver.name : 'null (general request)'}");

      // Save trip to Firestore trips collection
      await db.collection('trips').doc(trip.tripId).set(tripJson);
      debugPrint("FIRESTORE_REPO: Trip ${trip.tripId} saved to trips collection successfully");

      // Also save old-style ride request for driver compatibility
      if (selectedDriver != null) {
        await db.collection(auth.currentUser!.email.toString()).add({
          "OriginLat": trip.pickupLocation.latitude,
          "OriginLng": trip.pickupLocation.longitude,
          "OriginAddress": trip.pickupAddress,
          "destinationLat": trip.dropoffLocation.latitude,
          "destinationLng": trip.dropoffLocation.longitude,
          "destinationAddress": trip.dropoffAddress,
          "time": DateTime.now(),
          "userEmail": auth.currentUser!.email.toString(),
          "driverEmail": selectedDriver.email,
          "tripId": trip.tripId,
        });
      }
    } catch (e) {
      if (context.mounted) {
        ErrorNotification().showError(context, "An Error Occurred $e");
      }
    }
  }

  void nullifyUserRides(context) async {
    try {
      var data = await db.collection(auth.currentUser!.email.toString()).get();

      for (var alldata in data.docs) {
        alldata.reference.delete();
      }
    } catch (e) {
      if (context.mounted) {
        ErrorNotification().showError(context, "An Error Occurred $e");
      }
    }
  }

  void setDriverStatus(context, String driverEmail, String driverStatus) async {
    try {
      QuerySnapshot<Map<String, dynamic>> drivers = await db
          .collection("drivers")
          .where("email", isEqualTo: driverEmail)
          .get();

      if (drivers.docs.isEmpty) {
        drivers = await db
            .collection("Drivers")
            .where("email", isEqualTo: driverEmail)
            .get();
      }

      for (var driver in drivers.docs) {
        driver.reference.update({"driverStatus": driverStatus});
      }
    } catch (e) {
      if (context.mounted) {
        ErrorNotification().showError(context, "An Error Occurred $e");
      }
    }
  }
}