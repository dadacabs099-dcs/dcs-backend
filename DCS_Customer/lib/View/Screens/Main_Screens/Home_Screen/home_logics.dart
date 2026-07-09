import 'dart:io';

import 'package:elegant_notification/elegant_notification.dart';
import 'package:Dadacabs/Container/Providers/user_data_provider.dart';
import 'package:Dadacabs/View/Themes/indian_heritage_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoder2/geocoder2.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:lottie/lottie.dart' as lottie;
import 'package:Dadacabs/Container/Repositories/address_parser_repo.dart';
import 'package:Dadacabs/Container/Repositories/direction_polylines_repo.dart';
import 'package:Dadacabs/Container/Repositories/firestore_repo.dart';
import 'package:Dadacabs/Container/utils/error_notification.dart';
import 'package:Dadacabs/Container/utils/keys.dart';
import 'package:Dadacabs/Model/direction_model.dart';
import 'package:Dadacabs/Model/trip_model.dart';
import 'package:Dadacabs/View/Components/all_components.dart';
import 'package:Dadacabs/View/Routes/routes.dart';
import 'package:Dadacabs/View/Screens/Main_Screens/Home_Screen/home_providers.dart';
import 'package:dio/dio.dart';
import 'package:Dadacabs/Model/vehicle_type_model.dart';
import 'package:Dadacabs/Container/Providers/vehicle_providers.dart';
import 'package:Dadacabs/Container/Providers/fare_config_providers.dart';
import 'package:Dadacabs/Container/Providers/zone_detection_provider.dart';
import 'package:Dadacabs/Model/driver_model.dart';
import 'package:Dadacabs/Model/fare_config_model.dart';

class HomeScreenLogics {
  void changePickUpLoc(BuildContext context, WidgetRef ref,
      GoogleMapController controller) async {
    try {
      ref
          .watch(homeScreenDropOffLocationProvider.notifier)
          .update((state) => null);

      ref
          .watch(homeScreenMainMarkersProvider)
          .removeWhere((element) => element.markerId.value == "pickUpId");
      ref
          .watch(homeScreenMainMarkersProvider)
          .removeWhere((element) => element.markerId.value == "dropOffId");
      ref
          .watch(homeScreenMainCirclesProvider)
          .removeWhere((ele) => ele.circleId.value == "pickUpCircle");
      ref
          .watch(homeScreenMainCirclesProvider)
          .removeWhere((ele) => ele.circleId.value == "dropOffCircle");
      ref.watch(homeScreenMainPolylinesProvider.notifier).update((state) => {});
      Position pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      controller.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(
          target: LatLng(pos.latitude, pos.longitude), zoom: 14)));
    } catch (e) {
      if (context.mounted) {
        ElegantNotification.error(
            description: Text(
          "An Error Occurred $e",
          style: const TextStyle(color: Colors.black),
        )).show(context);
      }
    }
  }

  /// [getUserLoc] fetches the user's location as soon as the app starts.
  /// Replicated from Partner APK's [getDriverLoc] for consistent, accurate location handling.

  void getUserLoc(BuildContext context, WidgetRef ref,
      GoogleMapController controller) async {
    try {
      // Step 1: Check if location services are enabled (matching Partner APK)
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print("🔥 User App: Location services are disabled");
        if (context.mounted) {
          ErrorNotification().showError(context, "Location services are disabled. Please enable GPS.");
        }
        return;
      }

      // Step 2: Check and request location permissions (matching Partner APK)
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print("🔥 User App: Location permissions are denied");
          if (context.mounted) {
            ErrorNotification().showError(context, "Location permissions are denied. Please grant location access.");
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print("🔥 User App: Location permissions are permanently denied");
        if (context.mounted) {
          ErrorNotification().showError(context, "Location permissions are permanently denied. Please enable them in Settings.");
        }
        return;
      }

      // Step 3: Get current position with high accuracy (matching Partner APK)
      Position pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      print("🔥 User App: Location obtained: ${pos.latitude}, ${pos.longitude}");

      // Step 4: Animate camera to the actual GPS location (matching Partner APK)
      if (context.mounted && controller != null) {
        controller.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(
            target: LatLng(pos.latitude, pos.longitude), zoom: 16)));

        await ref
            .watch(globalAddressParserProvider)
            .humanReadableAddress(pos, context, ref);

        // Step 5: Detect current zone based on GPS position
        final zones = ref.read(allZonesStreamProvider).value ?? [];
        final detectedZone = detectZoneFromPosition(zones, pos);
        ref.read(currentZoneNameProvider.notifier).update((state) => detectedZone);
        if (detectedZone.isNotEmpty) {
          print("📍 Zone detected: $detectedZone");
        }
      }
      if (context.mounted) {
        ref
            .read(globalFirestoreRepoProvider)
            .getDriverData(context, ref, LatLng(pos.latitude, pos.longitude));
      }
    } catch (e) {
      print("🔥 User App: Error getting location: $e");
      if (context.mounted) {
        ErrorNotification().showError(context, "Unable to get your location. Please check your location settings.");
      }
    }
  }

  /// [getAddressfromCordinates] read data from [cameraMovementProvider] (which is updated whenever the camera moves) and gets the human readable address
  /// from the [cameraMovementProvider] and returns a [Direction] model which is assigned to [pickUpLocationProvider] (which sets the user's pick up Location)

  void getAddressfromCordinates(BuildContext context, WidgetRef ref) async {
    try {
      if (ref.read(homeScreenCameraMovementProvider) == null) {
        return;
      }

      final coord = ref.read(homeScreenCameraMovementProvider)!;
      String url =
          "https://maps.googleapis.com/maps/api/geocode/json?latlng=${coord.latitude},${coord.longitude}&key=${AppKeys.mapKey}";

      Response res = await Dio().get(url);

      if (res.statusCode == 200 && res.data["status"] == "OK" && res.data["results"] != null && res.data["results"].isNotEmpty) {
        Direction model = Direction(
            locationLatitude: coord.latitude,
            locationLongitude: coord.longitude,
            humanReadableAddress: res.data["results"][0]["formatted_address"]);
        ref
            .read(homeScreenPickUpLocationProvider.notifier)
            .update((state) => model);
      } else {
        // Fallback if Geocoding fails
        Direction model = Direction(
            locationLatitude: coord.latitude,
            locationLongitude: coord.longitude,
            humanReadableAddress: "Current Location");
        ref
            .read(homeScreenPickUpLocationProvider.notifier)
            .update((state) => model);
      }
    } catch (e) {
      print("Geocoding error: $e");
      // Continue silently on network errors
    }
  }

  /// Function for [WhereTo] TextField Button

  void openWhereToScreen(BuildContext context, WidgetRef ref,
      GoogleMapController controller) async {
    try {
      if (ref.watch(homeScreenDropOffLocationProvider) == null) {
        return;
      }

      if (context.mounted) {
        /// Making [Markers] for [pickUp] and [dropOff] Places
        Marker pickUpMarker = Marker(
            markerId: const MarkerId("pickUpId"),
            infoWindow: InfoWindow(
              title: ref.watch(homeScreenPickUpLocationProvider)!.locationName,
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueGreen),
            position: LatLng(
                ref.watch(homeScreenPickUpLocationProvider)!.locationLatitude!,
                ref
                    .watch(homeScreenPickUpLocationProvider)!
                    .locationLongitude!));
        Marker dropOffMarker = Marker(
            markerId: const MarkerId("dropOffId"),
            infoWindow: InfoWindow(
              title: ref.watch(homeScreenDropOffLocationProvider)!.locationName,
            ),
            icon:
                BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            position: LatLng(
                ref.watch(homeScreenDropOffLocationProvider)!.locationLatitude!,
                ref
                    .watch(homeScreenDropOffLocationProvider)!
                    .locationLongitude!));

        /// Making [Circle] for [pickUp] and [dropOff] Places

        Circle pickUpCircle = Circle(
            circleId: const CircleId("pickUpCircle"),
            fillColor: Colors.green,
            radius: 500,
            strokeColor: Colors.black,
            center: LatLng(
                ref.watch(homeScreenPickUpLocationProvider)!.locationLatitude!,
                ref
                    .watch(homeScreenPickUpLocationProvider)!
                    .locationLongitude!));
        Circle dropOffCircle = Circle(
            circleId: const CircleId("dropOffCircle"),
            fillColor: Colors.red,
            radius: 500,
            strokeColor: Colors.black,
            center: LatLng(
                ref.watch(homeScreenDropOffLocationProvider)!.locationLatitude!,
                ref
                    .watch(homeScreenDropOffLocationProvider)!
                    .locationLongitude!));

        /// Calling function to draw [Polylines]
        ref
            .watch(globalDirectionPolylinesRepoProvider)
            .setNewDirectionPolylines(ref, context, controller);

        /// Adding [Markers] to [pickUp] and [dropOff] Places
        ref
            .watch(homeScreenMainMarkersProvider.notifier)
            .update((state) => {...state, pickUpMarker, dropOffMarker});

        /// Adding [Circles] to [pickUp] and [dropOff] Places
        ref
            .watch(homeScreenMainCirclesProvider.notifier)
            .update((state) => {...state, pickUpCircle, dropOffCircle});
      }
    } catch (e) {
      if (context.mounted) {
        ErrorNotification().showError(context, "An Error Occurred $e");
      }
    }
  }

  double calculateDistance(
    lat1,
    lon1,
    lat2,
    lon2,
  ) {
    double calculatedDistance = Geolocator.distanceBetween(
      lat1,
      lon1,
      lat2,
      lon2,
    );

    return calculatedDistance;
  }

  dynamic requestARide(size, BuildContext context, WidgetRef ref,
      GoogleMapController controller) {
    if (ref.read(homeScreenDropOffLocationProvider) == null) {
      ErrorNotification().showError(context, "Please add destination first");
      return;
    }

    final selectedServiceIndex = ref.read(homeScreenSelectedRideProvider) ?? 0;
    final availableDrivers = ref.read(homeScreenAvailableDriversProvider);

    // Use the same vehicle index ordering as the home screen vehicle selector.
    final requestedType = _requestedTypeForIndex(selectedServiceIndex);

    final pickUpLoc = ref.read(homeScreenPickUpLocationProvider);
    if (pickUpLoc == null) {
      ErrorNotification().showError(context, "Unable to determine pickup location");
      return;
    }

    // Show Searching Bottom Sheet
    ref.read(homeScreenStartDriverSearch.notifier).update((state) => true);
    
    // Simulate waiting to find a driver
    Future.delayed(const Duration(seconds: 3), () async {
      if (context.mounted) {
        context.pop(); // Close the matching sheet

        // Calculate Fare using existing vehicleTypes pricing + zone-based overrides
        final vehicleTypes = ref.read(vehicleTypesStreamProvider).value ?? VehicleTypeModel.defaults;
        final fareConfigs = ref.read(fareConfigsStreamProvider).value ?? [];
        final details = ref.read(homeScreenDirectionDetailsProvider);
        
        // Get current zone name from provider (auto-detected from GPS)
        final currentZone = ref.read(currentZoneNameProvider);
        
        // Match vehicle type from Firestore vehicleTypes collection
        final matchedVehicleType = vehicleTypes.firstWhere(
          (v) => v.id.toLowerCase() == requestedType || v.name.toLowerCase() == requestedType,
          orElse: () => vehicleTypes.firstWhere(
            (v) => v.id.toLowerCase() == 'economy',
            orElse: () => vehicleTypes.first,
          ),
        );
        
        // Try to find zone-specific fare override from fareConfigs
        FareConfigModel? matchedFareConfig;
        if (currentZone.isNotEmpty) {
          matchedFareConfig = fareConfigs.firstWhere(
            (f) => f.zoneName == currentZone && 
            (f.vehicleType.toLowerCase() == matchedVehicleType.name.toLowerCase() ||
                     f.vehicleType.toLowerCase() == requestedType),
            orElse: () => FareConfigModel(
              id: '', zoneId: '', zoneName: '', vehicleType: '',
              baseFare: 0, perKmRate: 0, perMinuteRate: 0, minimumFare: 0,
            ),
          );
          if (matchedFareConfig!.baseFare == 0) matchedFareConfig = null;
        }
        
        // Calculate fare: use zone override if exists, otherwise use vehicleTypes from Firestore
        double tripFare;
        if (details != null) {
          final distKm = details.distanceValue! / 1000.0;
          final durMin = (details.durationValue! / 60.0).toDouble();
          
          if (matchedFareConfig != null) {
            // Use zone-specific fare config (Dadacabs-style with base distance)
            tripFare = matchedFareConfig.calculateFare(
              distanceKm: distKm,
              durationMinutes: durMin,
            );
          } else {
            // Use vehicle type pricing from Firestore vehicleTypes collection
            // This is the EXISTING data you already configured in admin panel
            tripFare = matchedVehicleType.baseFare +
                (distKm * matchedVehicleType.perKmRate) +
                (durMin * matchedVehicleType.perMinuteRate);
            if (tripFare < matchedVehicleType.minimumFare) {
              tripFare = matchedVehicleType.minimumFare;
            }
          }
        } else {
          tripFare = matchedVehicleType.baseFare;
        }

        final tripId = DateTime.now().millisecondsSinceEpoch.toString();
        
        // Calculate distance and duration for the trip
        final pickUpData = ref.read(homeScreenPickUpLocationProvider)!;
        final dropOffData = ref.read(homeScreenDropOffLocationProvider)!;
        // details is already declared above at line 355
        
        double? tripDistanceKm;
        int? tripDurationMinutes;
        if (details != null && details.distanceValue != null) {
          tripDistanceKm = details.distanceValue! / 1000.0;
          tripDurationMinutes = details.durationValue != null ? (details.durationValue! / 60.0).round() : null;
        } else {
          // Fallback: straight-line distance
          final meters = Geolocator.distanceBetween(
            pickUpData.locationLatitude ?? 0.0,
            pickUpData.locationLongitude ?? 0.0,
            dropOffData.locationLatitude ?? 0.0,
            dropOffData.locationLongitude ?? 0.0,
          );
          tripDistanceKm = meters / 1000.0;
          tripDurationMinutes = (meters / 500).round();
        }
        
        final user = ref.read(userDataProvider);
        final trip = TripModel(
          tripId: tripId,
          userId: user!.uid,
          userName: user.name ?? 'Customer',
          userPhone: user.phone ?? '',
          pickupLocation: LatLng(
            pickUpData.locationLatitude ?? 0.0,
            pickUpData.locationLongitude ?? 0.0,
          ),
          pickupAddress: pickUpData.locationName ?? '',
          dropoffLocation: LatLng(
            dropOffData.locationLatitude ?? 0.0,
            dropOffData.locationLongitude ?? 0.0,
          ),
          dropoffAddress: dropOffData.locationName ?? '',
          status: TripStatus.pending,
          createdAt: DateTime.now(),
          estimatedFare: double.parse(tripFare.toStringAsFixed(2)),
          paymentMethod: ref.read(homeScreenSelectedPaymentProvider),
          distanceKm: tripDistanceKm,
          durationMinutes: tripDurationMinutes,
        );

        // Modified by Jayant Pandit on 2026-07-09 18:00:00
        // Reason: Await Firestore write before notifying webhook. Fire-and-forget caused race:
        // webhook fetched trip before Firestore write propagated, returning 404 → no notification to drivers.
        await ref.read(globalFirestoreRepoProvider).addUserRideRequestToDB(context, ref, null, trip);
        await HomeScreenLogics.notifyDriversViaWebhook(trip.tripId);

        context.pushNamed(Routes().activeTrip, extra: trip);
      }
    });

    return showModalBottomSheet(
        context: context,
        isDismissible: false,
        enableDrag: false,
        builder: (context) {
          return Consumer(
            builder: (context, ref, child) {
              return Container(
                  width: size.width,
                  height: 400,
                  decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(24.0),
                          topRight: Radius.circular(24.0))),
                  child: Column(
                    key: const Key("sec"),
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      lottie.Lottie.asset(
                        "assets/jsons/dribbble.json",
                        height: 250,
                        width: 250,
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20.0),
                        child: Text(
                            "Finding you a ride...",
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "Connecting to nearby ${requestedType.toUpperCase()} drivers",
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      )
                    ],
                  ));
            },
          );
        }).whenComplete(() {
      ref.read(homeScreenStartDriverSearch.notifier).update((state) => false);
    });
  }

  // Modified by Jayant Pandit on 2026-07-08 18:00:00
  // Reason: Client-side FCM sending replaced by Cloud Functions trigger on trips collection.
  // The onNewTripRequest function in functions/src/notifications.ts handles driver notification
  // via Admin SDK, with proper authentication (no exposed server key), carType filtering,
  // deviceTokens array support, and invalid token pruning.
  Future<dynamic> sendNotificationToDrivers(
      BuildContext context, WidgetRef ref, List<DriverModel> drivers) async {
    // No-op: Notifications handled by Firebase Cloud Function onNewTripRequest
    debugPrint("sendNotificationToDrivers: Cloud Functions handles driver notifications");
  }

  String _requestedTypeForIndex(int index) {
    final types = VehicleTypeModel.defaults.map((v) => v.id.toLowerCase()).toList();
    if (index >= 0 && index < types.length) {
      return types[index];
    }
    return 'economy';
  }

  bool _matchesRequestedType(String driverType, String requestedType) {
    switch (requestedType) {
      case 'bike':
        return driverType.contains('bike') || driverType.contains('moto') || driverType.contains('motorcycle') || driverType.contains('scooter');
      case 'auto':
        return driverType.contains('auto') || driverType.contains('rickshaw') || driverType.contains('three-wheeler');
      case 'economy':
        return driverType.contains('car') || driverType.contains('sedan') || driverType.contains('hatchback') || driverType.contains('mini') || driverType.contains('economy') || driverType.contains('taxi');
      case 'premium':
        return driverType.contains('premium') || driverType.contains('luxury') || driverType.contains('sedan') || driverType.contains('town car');
      case 'xl':
        return driverType.contains('suv') || driverType.contains('xl') || driverType.contains('innova') || driverType.contains('ertiga') || driverType.contains('xuv');
      case 'van':
        return driverType.contains('van') || driverType.contains('minivan') || driverType.contains('tempo') || driverType.contains('traveller') || driverType.contains('dost');
      case 'intercity':
        return driverType.contains('intercity') || driverType.contains('tour') || driverType.contains('traveller') || driverType.contains('tempo');
      case 'parcel':
        return driverType.contains('parcel') || driverType.contains('truck') || driverType.contains('van') || driverType.contains('dost');
      default:
        return driverType.contains(requestedType);
    }
  }

  // Modified by Jayant Pandit on 2026-07-08 18:00:00
  // Reason: Client-side FCM sending replaced by Cloud Functions trigger onUserUpdate in trips collection.
  // The onDriverAcceptTrip function in functions/src/notifications.ts handles user notifications
  // when driver arrival status is detected.
  Future<dynamic> sendNotificationToUserAboutDriverArrival(
      BuildContext context) async {
    // No-op: Notifications handled by Firebase Cloud Function onDriverAcceptTrip
    debugPrint("sendNotificationToUserAboutDriverArrival: Cloud Functions handles user notifications");
  }

  // Modified by Jayant Pandit on 2026-07-09 18:00:00
  // Reason: Call Railway webhook to notify matching drivers via Admin SDK.
  // Added retry: firestore write is now awaited before webhook, but network may still fail.
  static Future<void> notifyDriversViaWebhook(String tripId) async {
    const maxRetries = 3;
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        await Dio().post(
          '${AppKeys.notifServerUrl}/notify-drivers',
          data: {'tripId': tripId},
          options: Options(
            headers: {HttpHeaders.contentTypeHeader: "application/json"},
            sendTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 10),
          ),
        );
        debugPrint("notifyDriversViaWebhook: Success for trip $tripId (attempt $attempt)");
        return;
      } catch (e) {
        debugPrint("notifyDriversViaWebhook: Failed for trip $tripId (attempt $attempt/$maxRetries): $e");
        if (attempt < maxRetries) {
          await Future.delayed(Duration(seconds: attempt));
        }
      }
    }
    debugPrint("notifyDriversViaWebhook: All $maxRetries attempts failed for trip $tripId");
  }
}
