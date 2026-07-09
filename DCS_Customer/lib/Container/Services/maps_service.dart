import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:Dadacabs/Model/vehicle_type_model.dart';
import 'package:Dadacabs/Container/utils/keys.dart';

/// [MapsService] provides Google Maps API integration
/// for navigation, directions, and location services
class MapsService {
  static const String _apiKey = AppKeys.mapKey;
  static const String _baseUrl = 'https://maps.googleapis.com/maps/api';
  
  final PolylinePoints _polylinePoints = PolylinePoints();

  /// Get directions route between two points
  static Future<RouteInfo> getDirections(
    LatLng origin,
    LatLng destination, {
    List<LatLng> waypoints = const [],
    bool optimizeWaypoints = false,
  }) async {
    try {
      String url = '$_baseUrl/directions/json?'
          'origin=${origin.latitude},${origin.longitude}'
          '&destination=${destination.latitude},${destination.longitude}'
          '&mode=driving'
          '&traffic_model=best_guess'
          '&departure_time=now'
          '&key=$_apiKey';

      // Add waypoints if provided
      if (waypoints.isNotEmpty) {
        final waypointsStr = waypoints
            .map((wp) => '${wp.latitude},${wp.longitude}')
            .join('|');
        url += '&waypoints=${optimizeWaypoints ? 'optimize:true|' : ''}$waypointsStr';
      }

      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode != 200) {
        throw Exception('Failed to get directions: ${response.statusCode}');
      }

      final data = json.decode(response.body);

      if (data['status'] != 'OK') {
        throw Exception('Directions API error: ${data['status']}');
      }

      final route = data['routes'][0];
      final leg = route['legs'][0];

      // Decode polyline
      final points = _decodePolyline(route['overview_polyline']['points']);

      return RouteInfo(
        polylinePoints: points,
        distance: leg['distance']['value'].toDouble(), // meters
        duration: Duration(seconds: leg['duration']['value']),
        distanceText: leg['distance']['text'],
        durationText: leg['duration']['text'],
        startAddress: leg['start_address'],
        endAddress: leg['end_address'],
        steps: List<Map<String, dynamic>>.from(leg['steps']),
        waypointOrder: route['waypoint_order'] != null
            ? List<int>.from(route['waypoint_order'])
            : null,
      );
    } catch (e) {
      throw Exception('Error getting directions: $e');
    }
  }

  /// Calculate distance matrix for multiple origins/destinations
  static Future<List<DistanceInfo>> getDistanceMatrix(
    List<LatLng> origins,
    List<LatLng> destinations, {
    String mode = 'driving',
  }) async {
    try {
      final originsStr = origins
          .map((o) => '${o.latitude},${o.longitude}')
          .join('|');
      final destinationsStr = destinations
          .map((d) => '${d.latitude},${d.longitude}')
          .join('|');

      final url = '$_baseUrl/distancematrix/json?'
          'origins=$originsStr'
          '&destinations=$destinationsStr'
          '&mode=$mode'
          '&traffic_model=best_guess'
          '&departure_time=now'
          '&key=$_apiKey';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode != 200) {
        throw Exception('Failed to get distance matrix: ${response.statusCode}');
      }

      final data = json.decode(response.body);

      if (data['status'] != 'OK') {
        throw Exception('Distance Matrix API error: ${data['status']}');
      }

      final rows = data['rows'] as List<dynamic>;
      final List<DistanceInfo> results = [];

      for (var i = 0; i < rows.length; i++) {
        final elements = rows[i]['elements'] as List<dynamic>;
        for (var j = 0; j < elements.length; j++) {
          final element = elements[j];
          if (element['status'] == 'OK') {
            results.add(DistanceInfo(
              originIndex: i,
              destinationIndex: j,
              distance: element['distance']['value'].toDouble(),
              duration: Duration(seconds: element['duration']['value']),
              distanceText: element['distance']['text'],
              durationText: element['duration']['text'],
            ));
          }
        }
      }

      return results;
    } catch (e) {
      throw Exception('Error getting distance matrix: $e');
    }
  }

  /// Geocode address to coordinates
  static Future<LatLng?> geocodeAddress(String address) async {
    try {
      final encodedAddress = Uri.encodeComponent(address);
      final url = '$_baseUrl/geocode/json?'
          'address=$encodedAddress'
          '&key=$_apiKey';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode != 200) {
        throw Exception('Failed to geocode: ${response.statusCode}');
      }

      final data = json.decode(response.body);

      if (data['status'] == 'OK' && data['results'].isNotEmpty) {
        final location = data['results'][0]['geometry']['location'];
        return LatLng(location['lat'], location['lng']);
      }

      return null;
    } catch (e) {
      throw Exception('Error geocoding address: $e');
    }
  }

  /// Reverse geocode coordinates to address
  static Future<String?> reverseGeocode(LatLng location) async {
    try {
      final url = '$_baseUrl/geocode/json?'
          'latlng=${location.latitude},${location.longitude}'
          '&key=$_apiKey';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode != 200) {
        throw Exception('Failed to reverse geocode: ${response.statusCode}');
      }

      final data = json.decode(response.body);

      if (data['status'] == 'OK' && data['results'].isNotEmpty) {
        return data['results'][0]['formatted_address'];
      }

      return null;
    } catch (e) {
      throw Exception('Error reverse geocoding: $e');
    }
  }

  /// Get place autocomplete suggestions
  static Future<List<PlaceSuggestion>> getPlaceSuggestions(
    String input, {
    LatLng? location,
    double radius = 50000, // 50km
  }) async {
    try {
      String url = '$_baseUrl/place/autocomplete/json?'
          'input=${Uri.encodeComponent(input)}'
          '&types=geocode|establishment'
          '&key=$_apiKey';

      if (location != null) {
        url += '&location=${location.latitude},${location.longitude}'
            '&radius=${radius.toInt()}';
      }

      final response = await http.get(Uri.parse(url));

      if (response.statusCode != 200) {
        throw Exception('Failed to get suggestions: ${response.statusCode}');
      }

      final data = json.decode(response.body);

      if (data['status'] == 'OK') {
        final predictions = data['predictions'] as List<dynamic>;
        return predictions.map((p) => PlaceSuggestion(
          placeId: p['place_id'],
          description: p['description'],
          mainText: p['structured_formatting']['main_text'],
          secondaryText: p['structured_formatting']['secondary_text'],
        )).toList();
      }

      return [];
    } catch (e) {
      throw Exception('Error getting suggestions: $e');
    }
  }

  /// Get place details
  static Future<PlaceDetails?> getPlaceDetails(String placeId) async {
    try {
      final url = '$_baseUrl/place/details/json?'
          'place_id=$placeId'
          '&fields=geometry,formatted_address,name'
          '&key=$_apiKey';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode != 200) {
        throw Exception('Failed to get place details: ${response.statusCode}');
      }

      final data = json.decode(response.body);

      if (data['status'] == 'OK') {
        final result = data['result'];
        final location = result['geometry']['location'];
        return PlaceDetails(
          placeId: placeId,
          name: result['name'],
          address: result['formatted_address'],
          location: LatLng(location['lat'], location['lng']),
        );
      }

      return null;
    } catch (e) {
      throw Exception('Error getting place details: $e');
    }
  }

  /// Calculate estimated fare based on distance and time
  static double calculateEstimatedFare(
    double distanceKm,
    int durationMinutes, {
    String carType = 'economy',
    double surgeMultiplier = 1.0,
    List<VehicleTypeModel>? activeVehicleTypes,
  }) {
    if (activeVehicleTypes != null && activeVehicleTypes.isNotEmpty) {
      final matchedType = activeVehicleTypes.firstWhere(
        (v) => v.id.toLowerCase() == carType.toLowerCase() || v.name.toLowerCase() == carType.toLowerCase(),
        orElse: () => activeVehicleTypes.firstWhere(
          (v) => v.id.toLowerCase() == 'economy',
          orElse: () => activeVehicleTypes.first,
        ),
      );

      double fare = matchedType.baseFare +
          (distanceKm * matchedType.perKmRate) +
          (durationMinutes * matchedType.perMinuteRate);

      fare *= surgeMultiplier;

      fare = fare < matchedType.minimumFare ? matchedType.minimumFare : fare;
      return fare.roundToDouble();
    }

    // Base rates by car type (fallback)
    final Map<String, Map<String, double>> rates = {
      'bike': {
        'baseFare': 20.0,
        'perKm': 6.0,
        'perMinute': 1.0,
        'minimumFare': 25.0,
      },
      'economy': {
        'baseFare': 40.0,
        'perKm': 12.0,
        'perMinute': 1.5,
        'minimumFare': 60.0,
      },
      'premium': {
        'baseFare': 60.0,
        'perKm': 18.0,
        'perMinute': 2.0,
        'minimumFare': 90.0,
      },
      'xl': {
        'baseFare': 80.0,
        'perKm': 22.0,
        'perMinute': 2.5,
        'minimumFare': 120.0,
      },
      'truck': {
        'baseFare': 150.0,
        'perKm': 30.0,
        'perMinute': 3.0,
        'minimumFare': 250.0,
      },
    };

    final rate = rates[carType] ?? rates['economy']!;

    double fare = rate['baseFare']! +
        (distanceKm * rate['perKm']!) +
        (durationMinutes * rate['perMinute']!);

    // Apply surge pricing
    fare *= surgeMultiplier;

    // Apply minimum fare
    fare = fare < rate['minimumFare']! ? rate['minimumFare']! : fare;

    return fare.roundToDouble();
  }

  /// Calculate ETA with traffic consideration
  static String formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes} min';
    } else {
      return '${duration.inSeconds} sec';
    }
  }

  /// Format distance
  static String formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    } else {
      return '${meters.toStringAsFixed(0)} m';
    }
  }

  /// Decode polyline string to list of coordinates
  static List<LatLng> _decodePolyline(String encoded) {
    final List<LatLng> points = [];
    int index = 0;
    int len = encoded.length;
    int lat = 0;
    int lng = 0;

    while (index < len) {
      int b;
      int shift = 0;
      int result = 0;

      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);

      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;

      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);

      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }

    return points;
  }
}

/// Route information model
class RouteInfo {
  final List<LatLng> polylinePoints;
  final double distance; // meters
  final Duration duration;
  final String distanceText;
  final String durationText;
  final String startAddress;
  final String endAddress;
  final List<Map<String, dynamic>> steps;
  final List<int>? waypointOrder;

  RouteInfo({
    required this.polylinePoints,
    required this.distance,
    required this.duration,
    required this.distanceText,
    required this.durationText,
    required this.startAddress,
    required this.endAddress,
    required this.steps,
    this.waypointOrder,
  });

  /// Get formatted distance
  String get formattedDistance => MapsService.formatDistance(distance);

  /// Get formatted duration
  String get formattedDuration => MapsService.formatDuration(duration);
}

/// Distance information model
class DistanceInfo {
  final int originIndex;
  final int destinationIndex;
  final double distance; // meters
  final Duration duration;
  final String distanceText;
  final String durationText;

  DistanceInfo({
    required this.originIndex,
    required this.destinationIndex,
    required this.distance,
    required this.duration,
    required this.distanceText,
    required this.durationText,
  });
}

/// Place suggestion model
class PlaceSuggestion {
  final String placeId;
  final String description;
  final String mainText;
  final String secondaryText;

  PlaceSuggestion({
    required this.placeId,
    required this.description,
    required this.mainText,
    required this.secondaryText,
  });
}

/// Place details model
class PlaceDetails {
  final String placeId;
  final String name;
  final String address;
  final LatLng location;

  PlaceDetails({
    required this.placeId,
    required this.name,
    required this.address,
    required this.location,
  });
}
