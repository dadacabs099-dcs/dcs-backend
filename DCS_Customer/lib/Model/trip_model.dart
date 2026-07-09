// ignore_for_file: public_member_api_docs, sort_constructors_first

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geoflutterfire2/geoflutterfire2.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// TripStatus enum to track ride state
enum TripStatus {
  pending,      // Looking for driver
  accepted,     // Driver accepted
  arriving,     // Driver on the way
  arrived,      // Driver at pickup
  ongoing,      // Ride in progress
  completed,    // Ride finished
  cancelled,    // Cancelled by user or driver
}

/// [TripModel] represents a ride/trip in the system
class TripModel {
  String tripId;
  String userId;
  String? driverId;
  String? driverName;
  String? driverPhone;
  String? driverPhoto;
  String? carName;
  String? carPlateNum;
  String? carType;
  // Modified by Jayant Pandit on 2026-07-10 08:00:00
  // Reason: Added user info fields for Partner app compatibility on incoming ride requests
  String? userName;
  String? userPhone;
  String? userPhoto;
  
  // Location data
  LatLng pickupLocation;
  String pickupAddress;
  LatLng dropoffLocation;
  String dropoffAddress;
  
  // Trip details
  TripStatus status;
  DateTime createdAt;
  DateTime? acceptedAt;
  DateTime? startedAt;
  DateTime? completedAt;
  DateTime? cancelledAt;
  String? cancellationReason;
  
  // Pricing
  double estimatedFare;
  double? actualFare;
  double? discountAmount;
  double? finalFare;
  String paymentMethod;
  bool isPaid;
  DateTime? paidAt;
  
  // Trip metrics
  double? distanceKm;
  int? durationMinutes;
  String? polylineEncoded;
  
  // Rating
  double? userRating;
  String? userReview;
  double? driverRating;
  String? driverReview;
  
  // Service type
  String serviceType; // 'ride', 'parcel_bike', 'parcel_truck'
  String? parcelDescription;
  double? parcelWeight;

  TripModel({
    required this.tripId,
    required this.userId,
    this.driverId,
    this.driverName,
    this.driverPhone,
    this.driverPhoto,
    this.carName,
    this.carPlateNum,
    this.carType,
    this.userName,
    this.userPhone,
    this.userPhoto,
    required this.pickupLocation,
    required this.pickupAddress,
    required this.dropoffLocation,
    required this.dropoffAddress,
    this.status = TripStatus.pending,
    required this.createdAt,
    this.acceptedAt,
    this.startedAt,
    this.completedAt,
    this.cancelledAt,
    this.cancellationReason,
    required this.estimatedFare,
    this.actualFare,
    this.discountAmount,
    this.finalFare,
    this.paymentMethod = 'cash',
    this.isPaid = false,
    this.paidAt,
    this.distanceKm,
    this.durationMinutes,
    this.polylineEncoded,
    this.userRating,
    this.userReview,
    this.driverRating,
    this.driverReview,
    this.serviceType = 'ride',
    this.parcelDescription,
    this.parcelWeight,
  });

  Map<String, dynamic> toJson() {
    final geo = GeoFlutterFire();
    // Modified by Jayant Pandit on 2026-07-10 08:00:00
    // Reason: Add GeoFlutterFire pickupLoc/dropoffLoc for partner app geo-queries and user info fields
    return {
      'tripId': tripId,
      'userId': userId,
      'driverId': driverId,
      'driverName': driverName,
      'driverPhone': driverPhone,
      'driverPhoto': driverPhoto,
      'carName': carName,
      'carPlateNum': carPlateNum,
      'carType': carType,
      'userName': userName,
      'userPhone': userPhone,
      'userPhoto': userPhoto,
      'pickupLoc': geo.point(latitude: pickupLocation.latitude, longitude: pickupLocation.longitude).data,
      'dropoffLoc': geo.point(latitude: dropoffLocation.latitude, longitude: dropoffLocation.longitude).data,
      'pickupLat': pickupLocation.latitude,
      'pickupLng': pickupLocation.longitude,
      'pickupAddress': pickupAddress,
      'dropoffLat': dropoffLocation.latitude,
      'dropoffLng': dropoffLocation.longitude,
      'dropoffAddress': dropoffAddress,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
      'acceptedAt': acceptedAt?.toIso8601String(),
      'startedAt': startedAt?.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'cancelledAt': cancelledAt?.toIso8601String(),
      'cancellationReason': cancellationReason,
      'estimatedFare': estimatedFare,
      'actualFare': actualFare,
      'discountAmount': discountAmount,
      'finalFare': finalFare,
      'paymentMethod': paymentMethod,
      'isPaid': isPaid,
      'paidAt': paidAt?.toIso8601String(),
      'distanceKm': distanceKm,
      'durationMinutes': durationMinutes,
      'polylineEncoded': polylineEncoded,
      'userRating': userRating,
      'userReview': userReview,
      'driverRating': driverRating,
      'driverReview': driverReview,
      'serviceType': serviceType,
      'parcelDescription': parcelDescription,
      'parcelWeight': parcelWeight,
    };
  }

  factory TripModel.fromJson(Map<String, dynamic> json) {
    return TripModel(
      tripId: json['tripId'] ?? '',
      userId: json['userId'] ?? '',
      driverId: json['driverId'],
      driverName: json['driverName'],
      driverPhone: json['driverPhone'],
      driverPhoto: json['driverPhoto'],
      carName: json['carName'],
      carPlateNum: json['carPlateNum'],
      carType: json['carType'],
      userName: json['userName'],
      userPhone: json['userPhone'],
      userPhoto: json['userPhoto'],
      pickupLocation: LatLng(
        json['pickupLat']?.toDouble() ?? 0.0,
        json['pickupLng']?.toDouble() ?? 0.0,
      ),
      pickupAddress: json['pickupAddress'] ?? '',
      dropoffLocation: LatLng(
        json['dropoffLat']?.toDouble() ?? 0.0,
        json['dropoffLng']?.toDouble() ?? 0.0,
      ),
      dropoffAddress: json['dropoffAddress'] ?? '',
      status: TripStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => TripStatus.pending,
      ),
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      acceptedAt: json['acceptedAt'] != null ? DateTime.parse(json['acceptedAt']) : null,
      startedAt: json['startedAt'] != null ? DateTime.parse(json['startedAt']) : null,
      completedAt: json['completedAt'] != null ? DateTime.parse(json['completedAt']) : null,
      cancelledAt: json['cancelledAt'] != null ? DateTime.parse(json['cancelledAt']) : null,
      cancellationReason: json['cancellationReason'],
      estimatedFare: json['estimatedFare']?.toDouble() ?? 0.0,
      actualFare: json['actualFare']?.toDouble(),
      discountAmount: json['discountAmount']?.toDouble(),
      finalFare: json['finalFare']?.toDouble(),
      paymentMethod: json['paymentMethod'] ?? 'cash',
      isPaid: json['isPaid'] ?? false,
      paidAt: json['paidAt'] != null ? DateTime.parse(json['paidAt']) : null,
      distanceKm: json['distanceKm']?.toDouble(),
      durationMinutes: json['durationMinutes'],
      polylineEncoded: json['polylineEncoded'],
      userRating: json['userRating']?.toDouble(),
      userReview: json['userReview'],
      driverRating: json['driverRating']?.toDouble(),
      driverReview: json['driverReview'],
      serviceType: json['serviceType'] ?? 'ride',
      parcelDescription: json['parcelDescription'],
      parcelWeight: json['parcelWeight']?.toDouble(),
    );
  }

  /// Get status display text
  String get statusText {
    switch (status) {
      case TripStatus.pending:
        return 'Finding Driver';
      case TripStatus.accepted:
        return 'Driver Assigned';
      case TripStatus.arriving:
        return 'Driver Arriving';
      case TripStatus.arrived:
        return 'Driver Arrived';
      case TripStatus.ongoing:
        return 'On Trip';
      case TripStatus.completed:
        return 'Completed';
      case TripStatus.cancelled:
        return 'Cancelled';
    }
  }

  /// Get status color
  int get statusColor {
    switch (status) {
      case TripStatus.pending:
        return 0xFFFFA000; // Amber
      case TripStatus.accepted:
      case TripStatus.arriving:
        return 0xFF2196F3; // Blue
      case TripStatus.arrived:
        return 0xFF4CAF50; // Green
      case TripStatus.ongoing:
        return 0xFF9C27B0; // Purple
      case TripStatus.completed:
        return 0xFF4CAF50; // Green
      case TripStatus.cancelled:
        return 0xFFF44336; // Red
    }
  }
}
