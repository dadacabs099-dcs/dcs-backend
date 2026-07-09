import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

/// Zone model matching Firestore 'zones' collection structure
class ZoneModel {
  final String id;
  final String zoneName;
  final String city;
  final double latitude;
  final double longitude;
  final double radius; // in km

  const ZoneModel({
    required this.id,
    required this.zoneName,
    required this.city,
    required this.latitude,
    required this.longitude,
    required this.radius,
  });

  factory ZoneModel.fromMap(Map<String, dynamic> data, String id) {
    return ZoneModel(
      id: id,
      zoneName: data['zoneName'] ?? '',
      city: data['city'] ?? '',
      latitude: (data['latitude'] ?? 0).toDouble(),
      longitude: (data['longitude'] ?? 0).toDouble(),
      radius: (data['radius'] ?? 5).toDouble(),
    );
  }

  /// Check if a given point is within this zone's radius
  bool containsPoint(double lat, double lng) {
    final distance = _haversineDistance(latitude, longitude, lat, lng);
    return distance <= radius;
  }

  /// Haversine distance in km between two points
  static double _haversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const earthRadius = 6371.0; // km
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) * math.cos(_toRadians(lat2)) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  static double _toRadians(double degree) => degree * math.pi / 180;
}

/// Stream of all active zones from Firestore
final allZonesStreamProvider = StreamProvider<List<ZoneModel>>((ref) {
  return FirebaseFirestore.instance
      .collection('zones')
      .where('isActive', isEqualTo: true)
      .snapshots()
      .map((snap) => snap.docs
          .map((d) => ZoneModel.fromMap(d.data(), d.id))
          .toList());
});

/// Detect the user's current zone based on GPS position
/// Returns the nearest zone if within radius, or empty string
String detectZoneFromPosition(List<ZoneModel> zones, Position position) {
  // First check: find any zone that contains the point
  for (final zone in zones) {
    if (zone.containsPoint(position.latitude, position.longitude)) {
      return zone.zoneName;
    }
  }

  // Second check: find the nearest zone (within 2x radius as a soft boundary)
  ZoneModel? nearest;
  double minDistance = double.infinity;
  for (final zone in zones) {
    final dist = ZoneModel._haversineDistance(
      zone.latitude, zone.longitude,
      position.latitude, position.longitude,
    );
    if (dist < minDistance) {
      minDistance = dist;
      nearest = zone;
    }
  }

  // If within 2x the zone radius, consider it in that zone
  if (nearest != null && minDistance <= nearest.radius * 2) {
    return nearest.zoneName;
  }

  return ''; // No zone detected
}