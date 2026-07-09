// AI-Based Demand Prediction Model for DCS
// Uses historical data to predict ride demand in specific zones

import 'package:cloud_firestore/cloud_firestore.dart';

/// [DemandZone] represents a geographical area with demand metrics
class DemandZone {
  final String zoneId;
  final String zoneName;
  final GeoPoint centerLocation;
  final double radiusKm;
  final int currentDemand;
  final int predictedDemand;
  final double surgeMultiplier;
  final DateTime lastUpdated;
  final List<HourlyDemand> hourlyStats;
  final DemandTrend trend;

  DemandZone({
    required this.zoneId,
    required this.zoneName,
    required this.centerLocation,
    required this.radiusKm,
    required this.currentDemand,
    required this.predictedDemand,
    required this.surgeMultiplier,
    required this.lastUpdated,
    required this.hourlyStats,
    required this.trend,
  });

  factory DemandZone.fromJson(Map<String, dynamic> json) {
    return DemandZone(
      zoneId: json['zoneId'] ?? '',
      zoneName: json['zoneName'] ?? '',
      centerLocation: json['centerLocation'] ?? const GeoPoint(0, 0),
      radiusKm: json['radiusKm']?.toDouble() ?? 0.0,
      currentDemand: json['currentDemand'] ?? 0,
      predictedDemand: json['predictedDemand'] ?? 0,
      surgeMultiplier: json['surgeMultiplier']?.toDouble() ?? 1.0,
      lastUpdated: DateTime.parse(json['lastUpdated'] ?? DateTime.now().toIso8601String()),
      hourlyStats: (json['hourlyStats'] as List<dynamic>?)
              ?.map((e) => HourlyDemand.fromJson(e))
              .toList() ??
          [],
      trend: DemandTrend.values.firstWhere(
        (e) => e.name == json['trend'],
        orElse: () => DemandTrend.stable,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'zoneId': zoneId,
      'zoneName': zoneName,
      'centerLocation': centerLocation,
      'radiusKm': radiusKm,
      'currentDemand': currentDemand,
      'predictedDemand': predictedDemand,
      'surgeMultiplier': surgeMultiplier,
      'lastUpdated': lastUpdated.toIso8601String(),
      'hourlyStats': hourlyStats.map((e) => e.toJson()).toList(),
      'trend': trend.name,
    };
  }

  /// Get color based on demand level
  String get demandColor {
    if (surgeMultiplier >= 2.0) return '#FF0000'; // High demand - Red
    if (surgeMultiplier >= 1.5) return '#FF8800'; // Medium-High - Orange
    if (surgeMultiplier >= 1.2) return '#FFCC00'; // Medium - Yellow
    return '#00FF00'; // Normal - Green
  }

  /// Get demand level text
  String get demandLevel {
    if (surgeMultiplier >= 2.0) return 'Very High';
    if (surgeMultiplier >= 1.5) return 'High';
    if (surgeMultiplier >= 1.2) return 'Moderate';
    return 'Normal';
  }
}

/// [HourlyDemand] tracks demand for a specific hour
class HourlyDemand {
  final int hour; // 0-23
  final int tripCount;
  final double avgFare;
  final int activeDrivers;
  final double demandScore; // 0.0 to 1.0

  HourlyDemand({
    required this.hour,
    required this.tripCount,
    required this.avgFare,
    required this.activeDrivers,
    required this.demandScore,
  });

  factory HourlyDemand.fromJson(Map<String, dynamic> json) {
    return HourlyDemand(
      hour: json['hour'] ?? 0,
      tripCount: json['tripCount'] ?? 0,
      avgFare: json['avgFare']?.toDouble() ?? 0.0,
      activeDrivers: json['activeDrivers'] ?? 0,
      demandScore: json['demandScore']?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'hour': hour,
      'tripCount': tripCount,
      'avgFare': avgFare,
      'activeDrivers': activeDrivers,
      'demandScore': demandScore,
    };
  }
}

/// [DemandTrend] indicates if demand is increasing or decreasing
enum DemandTrend {
  increasing,
  decreasing,
  stable,
  peak,
  low,
}

/// [DemandPrediction] represents ML-based predictions
class DemandPrediction {
  final String predictionId;
  final String zoneId;
  final DateTime timestamp;
  final int predictedRequests;
  final double confidence; // 0.0 to 1.0
  final String modelVersion;
  final Map<String, dynamic> features; // Input features used
  final List<TimeSlotPrediction> timeSlots;

  DemandPrediction({
    required this.predictionId,
    required this.zoneId,
    required this.timestamp,
    required this.predictedRequests,
    required this.confidence,
    required this.modelVersion,
    required this.features,
    required this.timeSlots,
  });

  factory DemandPrediction.fromJson(Map<String, dynamic> json) {
    return DemandPrediction(
      predictionId: json['predictionId'] ?? '',
      zoneId: json['zoneId'] ?? '',
      timestamp: DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
      predictedRequests: json['predictedRequests'] ?? 0,
      confidence: json['confidence']?.toDouble() ?? 0.0,
      modelVersion: json['modelVersion'] ?? '1.0',
      features: json['features'] ?? {},
      timeSlots: (json['timeSlots'] as List<dynamic>?)
              ?.map((e) => TimeSlotPrediction.fromJson(e))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'predictionId': predictionId,
      'zoneId': zoneId,
      'timestamp': timestamp.toIso8601String(),
      'predictedRequests': predictedRequests,
      'confidence': confidence,
      'modelVersion': modelVersion,
      'features': features,
      'timeSlots': timeSlots.map((e) => e.toJson()).toList(),
    };
  }
}

/// [TimeSlotPrediction] for specific time windows
class TimeSlotPrediction {
  final DateTime startTime;
  final DateTime endTime;
  final int predictedDemand;
  final double surgeMultiplier;
  final double confidence;

  TimeSlotPrediction({
    required this.startTime,
    required this.endTime,
    required this.predictedDemand,
    required this.surgeMultiplier,
    required this.confidence,
  });

  factory TimeSlotPrediction.fromJson(Map<String, dynamic> json) {
    return TimeSlotPrediction(
      startTime: DateTime.parse(json['startTime'] ?? DateTime.now().toIso8601String()),
      endTime: DateTime.parse(json['endTime'] ?? DateTime.now().toIso8601String()),
      predictedDemand: json['predictedDemand'] ?? 0,
      surgeMultiplier: json['surgeMultiplier']?.toDouble() ?? 1.0,
      confidence: json['confidence']?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'predictedDemand': predictedDemand,
      'surgeMultiplier': surgeMultiplier,
      'confidence': confidence,
    };
  }
}

/// [HeatMapData] for visualizing demand on map
class HeatMapData {
  final GeoPoint location;
  final double intensity; // 0.0 to 1.0
  final int requestCount;
  final double avgWaitTime;

  HeatMapData({
    required this.location,
    required this.intensity,
    required this.requestCount,
    required this.avgWaitTime,
  });

  factory HeatMapData.fromJson(Map<String, dynamic> json) {
    return HeatMapData(
      location: json['location'] ?? const GeoPoint(0, 0),
      intensity: json['intensity']?.toDouble() ?? 0.0,
      requestCount: json['requestCount'] ?? 0,
      avgWaitTime: json['avgWaitTime']?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'location': location,
      'intensity': intensity,
      'requestCount': requestCount,
      'avgWaitTime': avgWaitTime,
    };
  }
}

/// [SurgePricingRule] defines pricing adjustments
class SurgePricingRule {
  final String ruleId;
  final String zoneId;
  final double minMultiplier;
  final double maxMultiplier;
  final int demandThreshold;
  final int driverThreshold;
  final DateTime? startTime;
  final DateTime? endTime;
  final bool isActive;

  SurgePricingRule({
    required this.ruleId,
    required this.zoneId,
    required this.minMultiplier,
    required this.maxMultiplier,
    required this.demandThreshold,
    required this.driverThreshold,
    this.startTime,
    this.endTime,
    required this.isActive,
  });

  factory SurgePricingRule.fromJson(Map<String, dynamic> json) {
    return SurgePricingRule(
      ruleId: json['ruleId'] ?? '',
      zoneId: json['zoneId'] ?? '',
      minMultiplier: json['minMultiplier']?.toDouble() ?? 1.0,
      maxMultiplier: json['maxMultiplier']?.toDouble() ?? 1.0,
      demandThreshold: json['demandThreshold'] ?? 0,
      driverThreshold: json['driverThreshold'] ?? 0,
      startTime: json['startTime'] != null
          ? DateTime.parse(json['startTime'])
          : null,
      endTime: json['endTime'] != null
          ? DateTime.parse(json['endTime'])
          : null,
      isActive: json['isActive'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ruleId': ruleId,
      'zoneId': zoneId,
      'minMultiplier': minMultiplier,
      'maxMultiplier': maxMultiplier,
      'demandThreshold': demandThreshold,
      'driverThreshold': driverThreshold,
      'startTime': startTime?.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'isActive': isActive,
    };
  }

  /// Calculate surge multiplier based on current conditions
  double calculateMultiplier(int currentDemand, int activeDrivers) {
    if (!isActive) return 1.0;
    if (activeDrivers == 0) return maxMultiplier;
    
    final ratio = currentDemand / activeDrivers;
    if (ratio < 1.0) return 1.0;
    
    final multiplier = 1.0 + (ratio - 1.0) * 0.5;
    return multiplier.clamp(minMultiplier, maxMultiplier);
  }
}
