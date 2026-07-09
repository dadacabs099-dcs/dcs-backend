import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dcs_partner/Model/fare_config_model.dart';

/// Stream of all active fare configurations from Firestore
final fareConfigsStreamProvider = StreamProvider<List<FareConfigModel>>((ref) {
  return FirebaseFirestore.instance
      .collection('fareConfigs')
      .where('isActive', isEqualTo: true)
      .snapshots()
      .map((snap) => snap.docs
          .map((d) => FareConfigModel.fromMap(d.data(), d.id))
          .toList());
});

/// Get fare config for a specific zone and vehicle type
final fareConfigForZoneProvider = StreamProvider.family<FareConfigModel?, ({String zoneName, String vehicleType})>((ref, params) {
  return FirebaseFirestore.instance
      .collection('fareConfigs')
      .where('isActive', isEqualTo: true)
      .where('zoneName', isEqualTo: params.zoneName)
      .where('vehicleType', isEqualTo: params.vehicleType)
      .limit(1)
      .snapshots()
      .map((snap) {
        if (snap.docs.isEmpty) return null;
        return FareConfigModel.fromMap(snap.docs.first.data(), snap.docs.first.id);
      });
});

/// Provider to hold the current zone name for the driver's location
final currentZoneNameProvider = StateProvider<String>((ref) => '');

/// Get the standard fare for a vehicle type in the current zone
/// Used for surge calculation display on the trip request card
double getStandardFare({
  required List<FareConfigModel> fareConfigs,
  required String zoneName,
  required String serviceType,
  required double distanceKm,
}) {
  final type = serviceType.toLowerCase();
  
  // Try to find zone-based fare config
  if (zoneName.isNotEmpty) {
    final config = fareConfigs.firstWhere(
      (f) => f.zoneName == zoneName && 
             (f.vehicleType.toLowerCase() == type ||
              f.vehicleType.toLowerCase() == 'sedan' && type.contains('car') ||
              f.vehicleType.toLowerCase() == type),
      orElse: () => FareConfigModel(
        id: '', zoneId: '', zoneName: '', vehicleType: '',
        baseFare: 0, perKmRate: 0, perMinuteRate: 0, minimumFare: 0,
      ),
    );
    if (config.baseFare > 0) {
      return config.calculateFare(distanceKm: distanceKm);
    }
  }
  
  // Fallback to hardcoded rates
  double baseFare = 40.0;
  double perKmRate = 12.0;
  if (type.contains("bike")) {
    baseFare = 20.0; perKmRate = 6.0;
  } else if (type.contains("auto")) {
    baseFare = 30.0; perKmRate = 10.0;
  } else if (type.contains("suv") || type.contains("premium") || type.contains("xl")) {
    baseFare = 80.0; perKmRate = 22.0;
  }
  return baseFare + (distanceKm * perKmRate);
}