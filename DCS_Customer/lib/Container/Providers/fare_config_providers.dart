import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:Dadacabs/Model/fare_config_model.dart';

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

/// Provider to hold the current zone name (set by the app based on user location)
final currentZoneNameProvider = StateProvider<String>((ref) => '');

/// Stream of surge pricing rules from Firestore
final surgeRulesStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return FirebaseFirestore.instance
      .collection('surge_pricing_rules')
      .snapshots()
      .map((snap) => snap.docs.map((d) => d.data()).toList());
});

/// Calculate fare for a ride using zone-based pricing
/// Falls back to vehicleTypes defaults if no fare config exists for the zone
final calculateFareProvider = Provider.family<double, ({
  String zoneName,
  String vehicleType,
  double distanceKm,
  double durationMinutes,
})>((ref, params) {
  final fareConfigs = ref.watch(fareConfigsStreamProvider);
  
  return fareConfigs.when(
    data: (configs) {
      // Find fare config for this zone and vehicle type
      final config = configs.firstWhere(
        (c) => c.zoneName == params.zoneName && c.vehicleType == params.vehicleType,
        orElse: () => FareConfigModel(
          id: 'default',
          zoneId: '',
          zoneName: '',
          vehicleType: params.vehicleType,
          baseFare: 0,
          baseDistance: 2,
          perKmRate: 0,
          perMinuteRate: 0,
          minimumFare: 0,
        ),
      );
      
      // If no fare config found (baseFare is 0), return 0 to signal fallback
      if (config.baseFare == 0) return 0;
      
      return config.calculateFare(
        distanceKm: params.distanceKm,
        durationMinutes: params.durationMinutes,
      );
    },
    loading: () => 0,
    error: (_, __) => 0,
  );
});