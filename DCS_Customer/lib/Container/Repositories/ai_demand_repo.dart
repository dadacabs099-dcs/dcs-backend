// ignore_for_file: public_member_api_docs, sort_constructors_first

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:Dadacabs/Model/AI/demand_prediction_model.dart';
import 'package:Dadacabs/Container/utils/error_notification.dart';

final globalAIDemandRepoProvider = Provider<AIDemandRepo>((ref) {
  return AIDemandRepo();
});

/// [AIDemandRepo] handles AI-based demand prediction operations
class AIDemandRepo {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _zonesCollection = 'demand_zones';
  final String _predictionsCollection = 'demand_predictions';
  final String _heatMapCollection = 'heat_map_data';
  final String _pricingRulesCollection = 'surge_pricing_rules';

  /// Get all demand zones
  Stream<List<DemandZone>> getDemandZones() {
    return _db
        .collection(_zonesCollection)
        .orderBy('lastUpdated', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => DemandZone.fromJson(doc.data()))
          .toList();
    });
  }

  /// Get demand for specific zone
  Future<DemandZone?> getZoneDemand(
    String zoneId,
    BuildContext context,
  ) async {
    try {
      DocumentSnapshot<Map<String, dynamic>> doc =
          await _db.collection(_zonesCollection).doc(zoneId).get();

      if (doc.exists && doc.data() != null) {
        return DemandZone.fromJson(doc.data()!);
      }
      return null;
    } catch (e) {
      if (context.mounted) {
        ErrorNotification().showError(
            context, "Failed to get zone demand: $e");
      }
      return null;
    }
  }

  /// Get demand zones near a location
  Stream<List<DemandZone>> getNearbyDemandZones(LatLng location, double radiusKm) {
    // Convert km to approximate degrees (rough estimation)
    final latDelta = radiusKm / 111.0;
    final lngDelta = radiusKm / (111.0 * cos(location.latitude * pi / 180));

    return _db
        .collection(_zonesCollection)
        .where('centerLocation.latitude',
            isGreaterThan: location.latitude - latDelta)
        .where('centerLocation.latitude',
            isLessThan: location.latitude + latDelta)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .where((doc) {
            final data = doc.data();
            final center = data['centerLocation'] as GeoPoint;
            final lng = center.longitude;
            return lng >= location.longitude - lngDelta &&
                lng <= location.longitude + lngDelta;
          })
          .map((doc) => DemandZone.fromJson(doc.data()))
          .toList();
    });
  }

  /// Get demand predictions for a zone
  Future<DemandPrediction?> getZonePrediction(
    String zoneId,
    BuildContext context,
  ) async {
    try {
      QuerySnapshot<Map<String, dynamic>> query = await _db
          .collection(_predictionsCollection)
          .where('zoneId', isEqualTo: zoneId)
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        return DemandPrediction.fromJson(query.docs.first.data());
      }
      return null;
    } catch (e) {
      if (context.mounted) {
        ErrorNotification().showError(
            context, "Failed to get prediction: $e");
      }
      return null;
    }
  }

  /// Get heat map data for visualization
  Stream<List<HeatMapData>> getHeatMapData() {
    return _db
        .collection(_heatMapCollection)
        .orderBy('intensity', descending: true)
        .limit(100) // Top 100 hot spots
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => HeatMapData.fromJson(doc.data()))
          .toList();
    });
  }

  /// Get surge pricing rules
  Future<List<SurgePricingRule>> getSurgePricingRules(
    BuildContext context,
  ) async {
    try {
      QuerySnapshot<Map<String, dynamic>> query = await _db
          .collection(_pricingRulesCollection)
          .where('isActive', isEqualTo: true)
          .get();

      return query.docs
          .map((doc) => SurgePricingRule.fromJson(doc.data()))
          .toList();
    } catch (e) {
      if (context.mounted) {
        ErrorNotification().showError(
            context, "Failed to get pricing rules: $e");
      }
      return [];
    }
  }

  /// Calculate surge multiplier for a location
  Future<double> calculateSurgeMultiplier(
    LatLng location,
    String zoneId,
    BuildContext context,
  ) async {
    try {
      // Get zone demand
      final zone = await getZoneDemand(zoneId, context);
      if (zone == null) return 1.0;

      // Get pricing rules
      final rules = await getSurgePricingRules(context);
      
      // Find applicable rule
      final applicableRule = rules.firstWhere(
        (rule) => rule.zoneId == zoneId,
        orElse: () => SurgePricingRule(
          ruleId: 'default',
          zoneId: zoneId,
          minMultiplier: 1.0,
          maxMultiplier: 2.5,
          demandThreshold: 10,
          driverThreshold: 5,
          isActive: true,
        ),
      );

      // Calculate multiplier
      final activeDrivers = zone.hourlyStats.isNotEmpty
          ? zone.hourlyStats.first.activeDrivers
          : 0;
      
      return applicableRule.calculateMultiplier(
        zone.currentDemand,
        activeDrivers,
      );
    } catch (e) {
      return 1.0; // Default to no surge on error
    }
  }

  /// Get peak hours for a zone
  Future<List<int>> getPeakHours(String zoneId, BuildContext context) async {
    try {
      final zone = await getZoneDemand(zoneId, context);
      if (zone == null) return [];

      // Find hours with highest demand scores
      final sorted = List<HourlyDemand>.from(zone.hourlyStats)
        ..sort((a, b) => b.demandScore.compareTo(a.demandScore));

      // Return top 5 peak hours
      return sorted.take(5).map((h) => h.hour).toList();
    } catch (e) {
      return [];
    }
  }

  /// Get demand trend prediction
  Future<DemandTrend> predictTrend(String zoneId, BuildContext context) async {
    try {
      final zone = await getZoneDemand(zoneId, context);
      return zone?.trend ?? DemandTrend.stable;
    } catch (e) {
      return DemandTrend.stable;
    }
  }

  /// Create or update demand zone (Admin only)
  Future<bool> updateDemandZone(
    DemandZone zone,
    BuildContext context,
  ) async {
    try {
      await _db.collection(_zonesCollection).doc(zone.zoneId).set(
            zone.toJson(),
            SetOptions(merge: true),
          );
      return true;
    } catch (e) {
      if (context.mounted) {
        ErrorNotification().showError(
            context, "Failed to update zone: $e");
      }
      return false;
    }
  }

  /// Trigger demand prediction (would call ML model)
  Future<DemandPrediction?> generatePrediction(
    String zoneId,
    BuildContext context,
  ) async {
    try {
      // In production, this would call an ML model API
      // For now, use simple heuristic based on historical data
      final zone = await getZoneDemand(zoneId, context);
      if (zone == null) return null;

      // Simple prediction based on current trend
      int predictedDemand = zone.currentDemand;
      switch (zone.trend) {
        case DemandTrend.increasing:
        case DemandTrend.peak:
          predictedDemand = (zone.currentDemand * 1.3).round();
          break;
        case DemandTrend.decreasing:
        case DemandTrend.low:
          predictedDemand = (zone.currentDemand * 0.7).round();
          break;
        case DemandTrend.stable:
        default:
          predictedDemand = zone.currentDemand;
      }

      final prediction = DemandPrediction(
        predictionId: 'pred_${DateTime.now().millisecondsSinceEpoch}',
        zoneId: zoneId,
        timestamp: DateTime.now(),
        predictedRequests: predictedDemand,
        confidence: 0.75,
        modelVersion: '1.0.0',
        features: {
          'currentDemand': zone.currentDemand,
          'hourOfDay': DateTime.now().hour,
          'dayOfWeek': DateTime.now().weekday,
          'historicalAvg': zone.hourlyStats.isNotEmpty
              ? zone.hourlyStats.map((h) => h.tripCount).reduce((a, b) => a + b) /
                  zone.hourlyStats.length
              : 0,
        },
        timeSlots: [
          TimeSlotPrediction(
            startTime: DateTime.now(),
            endTime: DateTime.now().add(const Duration(hours: 1)),
            predictedDemand: (predictedDemand * 0.4).round(),
            surgeMultiplier: zone.surgeMultiplier,
            confidence: 0.8,
          ),
          TimeSlotPrediction(
            startTime: DateTime.now().add(const Duration(hours: 1)),
            endTime: DateTime.now().add(const Duration(hours: 2)),
            predictedDemand: (predictedDemand * 0.35).round(),
            surgeMultiplier: zone.surgeMultiplier * 0.9,
            confidence: 0.7,
          ),
          TimeSlotPrediction(
            startTime: DateTime.now().add(const Duration(hours: 2)),
            endTime: DateTime.now().add(const Duration(hours: 3)),
            predictedDemand: (predictedDemand * 0.25).round(),
            surgeMultiplier: zone.surgeMultiplier * 0.8,
            confidence: 0.6,
          ),
        ],
      );

      // Store prediction
      await _db
          .collection(_predictionsCollection)
          .doc(prediction.predictionId)
          .set(prediction.toJson());

      return prediction;
    } catch (e) {
      if (context.mounted) {
        ErrorNotification().showError(
            context, "Failed to generate prediction: $e");
      }
      return null;
    }
  }

  /// Get recommended zones for drivers (high demand areas)
  Future<List<DemandZone>> getRecommendedZones(
    LatLng currentLocation,
    BuildContext context, {
    int limit = 5,
  }) async {
    try {
      final zones = await getNearbyDemandZones(currentLocation, 10).first;
      
      // Sort by demand score (surge multiplier * predicted demand)
      zones.sort((a, b) {
        final scoreA = a.surgeMultiplier * a.predictedDemand;
        final scoreB = b.surgeMultiplier * b.predictedDemand;
        return scoreB.compareTo(scoreA);
      });

      return zones.take(limit).toList();
    } catch (e) {
      return [];
    }
  }

  // Helper constant
  static double cos(double radians) => cos_(radians);
  static double cos_(double x) {
    // Simple cosine approximation
    double result = 1.0;
    double term = 1.0;
    for (int i = 1; i <= 10; i++) {
      term *= -x * x / ((2 * i) * (2 * i - 1));
      result += term;
    }
    return result;
  }
}

// Import math functions
double cos(double radians) => cos_(radians);
double cos_(double x) {
  // Taylor series approximation
  double result = 1.0;
  double term = 1.0;
  double x2 = x * x;
  for (int i = 1; i <= 6; i++) {
    term *= -x2 / ((2 * i) * (2 * i - 1));
    result += term;
  }
  return result;
}

const double pi = 3.141592653589793;
