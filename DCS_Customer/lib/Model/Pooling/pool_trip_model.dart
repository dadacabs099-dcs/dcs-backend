// Ride Pooling / Carpool Model for DCS
// Enables multiple passengers to share a ride

import 'package:cloud_firestore/cloud_firestore.dart';

/// [PoolTrip] represents a shared ride with multiple passengers
class PoolTrip {
  final String poolId;
  final String driverId;
  final String driverName;
  final String driverPhone;
  final String carName;
  final String carPlateNum;
  final String carType;
  
  // Route information
  final GeoPoint driverLocation;
  final List<PoolStop> stops; // Ordered list of pickup and dropoff points
  final List<String> routePolyline; // Encoded polyline for map
  
  // Capacity
  final int maxPassengers;
  final int currentPassengers;
  final int availableSeats;
  
  // Financial
  final double baseFare; // Total trip fare
  final Map<String, double> passengerFares; // Individual passenger contributions
  final double discountPercentage; // Savings vs individual ride
  
  // Status
  final PoolStatus status;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  
  // Timing
  final DateTime estimatedStartTime;
  final int estimatedDurationMinutes;
  final double estimatedDistanceKm;
  
  // Matching preferences
  final int maxWaitTimeMinutes; // How long to wait for matches
  final int maxDeviationPercentage; // Max route deviation allowed (e.g., 15%)
  
  // Passengers
  final List<PoolPassenger> passengers;
  
  // Rating
  final double? driverRating;
  final Map<String, double>? passengerRatings;

  PoolTrip({
    required this.poolId,
    required this.driverId,
    required this.driverName,
    required this.driverPhone,
    required this.carName,
    required this.carPlateNum,
    required this.carType,
    required this.driverLocation,
    required this.stops,
    required this.routePolyline,
    required this.maxPassengers,
    required this.currentPassengers,
    required this.availableSeats,
    required this.baseFare,
    required this.passengerFares,
    required this.discountPercentage,
    required this.status,
    required this.createdAt,
    this.startedAt,
    this.completedAt,
    this.cancelledAt,
    required this.estimatedStartTime,
    required this.estimatedDurationMinutes,
    required this.estimatedDistanceKm,
    required this.maxWaitTimeMinutes,
    required this.maxDeviationPercentage,
    required this.passengers,
    this.driverRating,
    this.passengerRatings,
  });

  factory PoolTrip.fromJson(Map<String, dynamic> json) {
    return PoolTrip(
      poolId: json['poolId'] ?? '',
      driverId: json['driverId'] ?? '',
      driverName: json['driverName'] ?? '',
      driverPhone: json['driverPhone'] ?? '',
      carName: json['carName'] ?? '',
      carPlateNum: json['carPlateNum'] ?? '',
      carType: json['carType'] ?? '',
      driverLocation: json['driverLocation'] ?? const GeoPoint(0, 0),
      stops: (json['stops'] as List<dynamic>?)
              ?.map((e) => PoolStop.fromJson(e))
              .toList() ??
          [],
      routePolyline: (json['routePolyline'] as List<dynamic>?)
              ?.cast<String>() ??
          [],
      maxPassengers: json['maxPassengers'] ?? 4,
      currentPassengers: json['currentPassengers'] ?? 0,
      availableSeats: json['availableSeats'] ?? 4,
      baseFare: json['baseFare']?.toDouble() ?? 0.0,
      passengerFares: (json['passengerFares'] as Map<String, dynamic>?)
              ?.map((key, value) => MapEntry(key, value.toDouble())) ??
          {},
      discountPercentage: json['discountPercentage']?.toDouble() ?? 0.0,
      status: PoolStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => PoolStatus.matching,
      ),
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      startedAt: json['startedAt'] != null
          ? DateTime.parse(json['startedAt'])
          : null,
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'])
          : null,
      cancelledAt: json['cancelledAt'] != null
          ? DateTime.parse(json['cancelledAt'])
          : null,
      estimatedStartTime: DateTime.parse(
          json['estimatedStartTime'] ?? DateTime.now().toIso8601String()),
      estimatedDurationMinutes: json['estimatedDurationMinutes'] ?? 0,
      estimatedDistanceKm: json['estimatedDistanceKm']?.toDouble() ?? 0.0,
      maxWaitTimeMinutes: json['maxWaitTimeMinutes'] ?? 5,
      maxDeviationPercentage: json['maxDeviationPercentage'] ?? 15,
      passengers: (json['passengers'] as List<dynamic>?)
              ?.map((e) => PoolPassenger.fromJson(e))
              .toList() ??
          [],
      driverRating: json['driverRating']?.toDouble(),
      passengerRatings: (json['passengerRatings'] as Map<String, dynamic>?)
          ?.map((key, value) => MapEntry(key, value.toDouble())),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'poolId': poolId,
      'driverId': driverId,
      'driverName': driverName,
      'driverPhone': driverPhone,
      'carName': carName,
      'carPlateNum': carPlateNum,
      'carType': carType,
      'driverLocation': driverLocation,
      'stops': stops.map((e) => e.toJson()).toList(),
      'routePolyline': routePolyline,
      'maxPassengers': maxPassengers,
      'currentPassengers': currentPassengers,
      'availableSeats': availableSeats,
      'baseFare': baseFare,
      'passengerFares': passengerFares,
      'discountPercentage': discountPercentage,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
      'startedAt': startedAt?.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'cancelledAt': cancelledAt?.toIso8601String(),
      'estimatedStartTime': estimatedStartTime.toIso8601String(),
      'estimatedDurationMinutes': estimatedDurationMinutes,
      'estimatedDistanceKm': estimatedDistanceKm,
      'maxWaitTimeMinutes': maxWaitTimeMinutes,
      'maxDeviationPercentage': maxDeviationPercentage,
      'passengers': passengers.map((e) => e.toJson()).toList(),
      'driverRating': driverRating,
      'passengerRatings': passengerRatings,
    };
  }

  /// Get status display text
  String get statusText {
    switch (status) {
      case PoolStatus.matching:
        return 'Matching Passengers';
      case PoolStatus.confirmed:
        return 'Confirmed';
      case PoolStatus.driverEnRoute:
        return 'Driver on the way';
      case PoolStatus.arrived:
        return 'Driver arrived';
      case PoolStatus.inProgress:
        return 'Trip in progress';
      case PoolStatus.completed:
        return 'Completed';
      case PoolStatus.cancelled:
        return 'Cancelled';
    }
  }

  /// Get color for status
  int get statusColor {
    switch (status) {
      case PoolStatus.matching:
        return 0xFFFF9800; // Orange
      case PoolStatus.confirmed:
        return 0xFF2196F3; // Blue
      case PoolStatus.driverEnRoute:
        return 0xFF4CAF50; // Green
      case PoolStatus.arrived:
        return 0xFF9C27B0; // Purple
      case PoolStatus.inProgress:
        return 0xFF00BCD4; // Cyan
      case PoolStatus.completed:
        return 0xFF4CAF50; // Green
      case PoolStatus.cancelled:
        return 0xFFF44336; // Red
    }
  }

  /// Calculate savings for a passenger
  double calculateSavings(String passengerId) {
    final individualFare = passengerFares[passengerId] ?? 0.0;
    final saving = individualFare * (discountPercentage / 100);
    return saving;
  }
}

/// [PoolStop] represents a pickup or dropoff point
class PoolStop {
  final String stopId;
  final String passengerId;
  final String passengerName;
  final String phoneNumber;
  final GeoPoint location;
  final String address;
  final StopType type; // pickup or dropoff
  final int sequence; // Order in the route (1, 2, 3...)
  final DateTime? estimatedTime;
  final DateTime? actualTime;
  final StopStatus status;

  PoolStop({
    required this.stopId,
    required this.passengerId,
    required this.passengerName,
    required this.phoneNumber,
    required this.location,
    required this.address,
    required this.type,
    required this.sequence,
    this.estimatedTime,
    this.actualTime,
    required this.status,
  });

  factory PoolStop.fromJson(Map<String, dynamic> json) {
    return PoolStop(
      stopId: json['stopId'] ?? '',
      passengerId: json['passengerId'] ?? '',
      passengerName: json['passengerName'] ?? '',
      phoneNumber: json['phoneNumber'] ?? '',
      location: json['location'] ?? const GeoPoint(0, 0),
      address: json['address'] ?? '',
      type: StopType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => StopType.pickup,
      ),
      sequence: json['sequence'] ?? 0,
      estimatedTime: json['estimatedTime'] != null
          ? DateTime.parse(json['estimatedTime'])
          : null,
      actualTime: json['actualTime'] != null
          ? DateTime.parse(json['actualTime'])
          : null,
      status: StopStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => StopStatus.pending,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'stopId': stopId,
      'passengerId': passengerId,
      'passengerName': passengerName,
      'phoneNumber': phoneNumber,
      'location': location,
      'address': address,
      'type': type.name,
      'sequence': sequence,
      'estimatedTime': estimatedTime?.toIso8601String(),
      'actualTime': actualTime?.toIso8601String(),
      'status': status.name,
    };
  }
}

/// [PoolPassenger] represents a passenger in a pool
class PoolPassenger {
  final String passengerId;
  final String name;
  final String phone;
  final String? photoUrl;
  final GeoPoint pickupLocation;
  final String pickupAddress;
  final GeoPoint dropoffLocation;
  final String dropoffAddress;
  final DateTime joinedAt;
  final double fare;
  final double savings;
  final bool hasPaid;
  final DateTime? paymentTime;
  final double? rating;

  PoolPassenger({
    required this.passengerId,
    required this.name,
    required this.phone,
    this.photoUrl,
    required this.pickupLocation,
    required this.pickupAddress,
    required this.dropoffLocation,
    required this.dropoffAddress,
    required this.joinedAt,
    required this.fare,
    required this.savings,
    required this.hasPaid,
    this.paymentTime,
    this.rating,
  });

  factory PoolPassenger.fromJson(Map<String, dynamic> json) {
    return PoolPassenger(
      passengerId: json['passengerId'] ?? '',
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      photoUrl: json['photoUrl'],
      pickupLocation: json['pickupLocation'] ?? const GeoPoint(0, 0),
      pickupAddress: json['pickupAddress'] ?? '',
      dropoffLocation: json['dropoffLocation'] ?? const GeoPoint(0, 0),
      dropoffAddress: json['dropoffAddress'] ?? '',
      joinedAt: DateTime.parse(json['joinedAt'] ?? DateTime.now().toIso8601String()),
      fare: json['fare']?.toDouble() ?? 0.0,
      savings: json['savings']?.toDouble() ?? 0.0,
      hasPaid: json['hasPaid'] ?? false,
      paymentTime: json['paymentTime'] != null
          ? DateTime.parse(json['paymentTime'])
          : null,
      rating: json['rating']?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'passengerId': passengerId,
      'name': name,
      'phone': phone,
      'photoUrl': photoUrl,
      'pickupLocation': pickupLocation,
      'pickupAddress': pickupAddress,
      'dropoffLocation': dropoffLocation,
      'dropoffAddress': dropoffAddress,
      'joinedAt': joinedAt.toIso8601String(),
      'fare': fare,
      'savings': savings,
      'hasPaid': hasPaid,
      'paymentTime': paymentTime?.toIso8601String(),
      'rating': rating,
    };
  }
}

/// [PoolRequest] for requesting to join a pool
class PoolRequest {
  final String requestId;
  final String poolId;
  final String passengerId;
  final String passengerName;
  final GeoPoint pickupLocation;
  final String pickupAddress;
  final GeoPoint dropoffLocation;
  final String dropoffAddress;
  final DateTime requestedAt;
  final PoolRequestStatus status;
  final String? rejectionReason;

  PoolRequest({
    required this.requestId,
    required this.poolId,
    required this.passengerId,
    required this.passengerName,
    required this.pickupLocation,
    required this.pickupAddress,
    required this.dropoffLocation,
    required this.dropoffAddress,
    required this.requestedAt,
    required this.status,
    this.rejectionReason,
  });

  factory PoolRequest.fromJson(Map<String, dynamic> json) {
    return PoolRequest(
      requestId: json['requestId'] ?? '',
      poolId: json['poolId'] ?? '',
      passengerId: json['passengerId'] ?? '',
      passengerName: json['passengerName'] ?? '',
      pickupLocation: json['pickupLocation'] ?? const GeoPoint(0, 0),
      pickupAddress: json['pickupAddress'] ?? '',
      dropoffLocation: json['dropoffLocation'] ?? const GeoPoint(0, 0),
      dropoffAddress: json['dropoffAddress'] ?? '',
      requestedAt: DateTime.parse(
          json['requestedAt'] ?? DateTime.now().toIso8601String()),
      status: PoolRequestStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => PoolRequestStatus.pending,
      ),
      rejectionReason: json['rejectionReason'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'requestId': requestId,
      'poolId': poolId,
      'passengerId': passengerId,
      'passengerName': passengerName,
      'pickupLocation': pickupLocation,
      'pickupAddress': pickupAddress,
      'dropoffLocation': dropoffLocation,
      'dropoffAddress': dropoffAddress,
      'requestedAt': requestedAt.toIso8601String(),
      'status': status.name,
      'rejectionReason': rejectionReason,
    };
  }
}

/// Enums
enum PoolStatus {
  matching, // Looking for passengers
  confirmed, // Pool is full/ready
  driverEnRoute,
  arrived,
  inProgress,
  completed,
  cancelled,
}

enum StopType {
  pickup,
  dropoff,
}

enum StopStatus {
  pending,
  next, // Next stop
  arrived,
  completed,
  skipped,
}

enum PoolRequestStatus {
  pending,
  accepted,
  rejected,
  cancelled,
}

/// [PoolMatchingCriteria] for algorithm to match passengers
class PoolMatchingCriteria {
  final double maxDistanceKm; // Max distance between pickup points
  final int maxWaitMinutes; // Max wait time for matching
  final int maxRouteDeviationPercent; // Max additional distance
  final int minPassengerSavingsPercent; // Min savings for passenger
  final List<String>? preferredGender; // Gender preference (optional)

  PoolMatchingCriteria({
    required this.maxDistanceKm,
    required this.maxWaitMinutes,
    required this.maxRouteDeviationPercent,
    required this.minPassengerSavingsPercent,
    this.preferredGender,
  });

  factory PoolMatchingCriteria.defaultCriteria() {
    return PoolMatchingCriteria(
      maxDistanceKm: 2.0, // 2km radius
      maxWaitMinutes: 5,
      maxRouteDeviationPercent: 15, // 15% longer route acceptable
      minPassengerSavingsPercent: 20, // At least 20% savings
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'maxDistanceKm': maxDistanceKm,
      'maxWaitMinutes': maxWaitMinutes,
      'maxRouteDeviationPercent': maxRouteDeviationPercent,
      'minPassengerSavingsPercent': minPassengerSavingsPercent,
      'preferredGender': preferredGender,
    };
  }
}
