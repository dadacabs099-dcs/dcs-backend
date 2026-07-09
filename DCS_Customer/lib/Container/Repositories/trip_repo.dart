// ignore_for_file: public_member_api_docs, sort_constructors_first

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:Dadacabs/Model/trip_model.dart';
import 'package:Dadacabs/Container/utils/error_notification.dart';
import 'package:Dadacabs/Model/vehicle_type_model.dart';

final globalTripRepoProvider = Provider<TripRepo>((ref) {
  return TripRepo();
});

/// [TripRepo] handles all trip-related database operations
class TripRepo {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _collection = 'trips';

  /// Create a new trip request
  Future<String?> createTrip(TripModel trip, BuildContext context) async {
    try {
      await _db.collection(_collection).doc(trip.tripId).set(trip.toJson());
      return trip.tripId;
    } catch (e) {
      if (context.mounted) {
        ErrorNotification().showError(context, "Failed to create trip: $e");
      }
      return null;
    }
  }

  /// Get a single trip by ID
  Future<TripModel?> getTrip(String tripId, BuildContext context) async {
    try {
      DocumentSnapshot<Map<String, dynamic>> doc = 
          await _db.collection(_collection).doc(tripId).get();
      
      if (doc.exists && doc.data() != null) {
        return TripModel.fromJson(doc.data()!);
      }
      return null;
    } catch (e) {
      if (context.mounted) {
        ErrorNotification().showError(context, "Failed to get trip: $e");
      }
      return null;
    }
  }

  /// Get all trips for a user
  Stream<List<TripModel>> getUserTrips(String userId) {
    return _db
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => TripModel.fromJson(doc.data()))
          .toList();
    });
  }

  /// Get user's trip history (completed trips)
  Stream<List<TripModel>> getUserTripHistory(String userId) {
    return _db
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'completed')
        .orderBy('completedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => TripModel.fromJson(doc.data()))
          .toList();
    });
  }

  /// Get active trip for user (pending, accepted, arriving, arrived, ongoing)
  Stream<TripModel?> getUserActiveTrip(String userId) {
    final activeStatuses = [
      'pending',
      'accepted', 
      'arriving',
      'arrived',
      'ongoing'
    ];
    
    return _db
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .where('status', whereIn: activeStatuses)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        return TripModel.fromJson(snapshot.docs.first.data());
      }
      return null;
    });
  }

  /// Cancel a trip
  Future<bool> cancelTrip(
    String tripId,
    String reason,
    BuildContext context,
  ) async {
    try {
      await _db.collection(_collection).doc(tripId).update({
        'status': 'cancelled',
        'cancelledAt': DateTime.now().toIso8601String(),
        'cancellationReason': reason,
      });
      return true;
    } catch (e) {
      if (context.mounted) {
        ErrorNotification().showError(context, "Failed to cancel trip: $e");
      }
      return false;
    }
  }

  /// Update trip status
  Future<bool> updateTripStatus(
    String tripId,
    TripStatus status,
    BuildContext context,
  ) async {
    try {
      Map<String, dynamic> update = {'status': status.name};
      
      // Add timestamp based on status
      switch (status) {
        case TripStatus.accepted:
          update['acceptedAt'] = DateTime.now().toIso8601String();
          break;
        case TripStatus.ongoing:
          update['startedAt'] = DateTime.now().toIso8601String();
          break;
        case TripStatus.completed:
          update['completedAt'] = DateTime.now().toIso8601String();
          break;
        default:
          break;
      }
      
      await _db.collection(_collection).doc(tripId).update(update);
      return true;
    } catch (e) {
      if (context.mounted) {
        ErrorNotification().showError(context, "Failed to update trip: $e");
      }
      return false;
    }
  }

  /// Rate a trip (user rating driver)
  Future<bool> rateTrip(
    String tripId,
    double rating,
    String? review,
    BuildContext context,
  ) async {
    try {
      await _db.collection(_collection).doc(tripId).update({
        'userRating': rating,
        'userReview': review,
      });

      // Modified by Jayant Pandit on 2026-05-17 13:36:05
      // Reason: Recalculate driver's overall average rating in Firestore drivers collection whenever a new customer rating is submitted
      // Old: Did not update the driver's overall average rating (only updated the userRating in the trip doc)
      // Recalculate driver's average rating in drivers collection
      final tripDoc = await _db.collection(_collection).doc(tripId).get();
      final driverId = tripDoc.data()?['driverId'];
      
      if (driverId != null) {
        final tripsSnapshot = await _db
            .collection(_collection)
            .where('driverId', isEqualTo: driverId)
            .where('status', isEqualTo: 'completed')
            .get();

        double totalRating = rating;
        int ratingCount = 1;

        for (var doc in tripsSnapshot.docs) {
          if (doc.id == tripId) continue;
          final data = doc.data();
          if (data['userRating'] != null) {
            totalRating += (data['userRating'] as num).toDouble();
            ratingCount++;
          }
        }

        double averageRating = totalRating / ratingCount;

        await _db.collection('drivers').doc(driverId).update({
          'rating': averageRating,
        });
      }

      return true;
    } catch (e) {
      if (context.mounted) {
        ErrorNotification().showError(context, "Failed to submit rating: $e");
      }
      return false;
    }
  }

  /// Update payment status
  Future<bool> updatePaymentStatus(
    String tripId,
    bool isPaid,
    BuildContext context,
  ) async {
    try {
      await _db.collection(_collection).doc(tripId).update({
        'isPaid': isPaid,
        'paidAt': isPaid ? DateTime.now().toIso8601String() : null,
      });
      return true;
    } catch (e) {
      if (context.mounted) {
        ErrorNotification().showError(context, "Failed to update payment: $e");
      }
      return false;
    }
  }

  /// Calculate estimated fare based on distance
  double calculateEstimatedFare(
    double distanceKm,
    String serviceType, {
    List<VehicleTypeModel>? activeVehicleTypes,
  }) {
    if (activeVehicleTypes != null && activeVehicleTypes.isNotEmpty) {
      VehicleTypeModel? matchedType;
      
      switch (serviceType) {
        case 'parcel_bike':
          matchedType = activeVehicleTypes.firstWhere(
            (v) => v.id.toLowerCase() == 'bike' || v.id.toLowerCase() == 'delivery',
            orElse: () => activeVehicleTypes.firstWhere(
              (v) => v.name.toLowerCase().contains('bike'),
              orElse: () => activeVehicleTypes.first,
            ),
          );
          break;
        case 'parcel_truck':
          matchedType = activeVehicleTypes.firstWhere(
            (v) => v.id.toLowerCase() == 'truck' || v.id.toLowerCase() == 'cargo',
            orElse: () => activeVehicleTypes.firstWhere(
              (v) => v.name.toLowerCase().contains('truck'),
              orElse: () => activeVehicleTypes.first,
            ),
          );
          break;
        case 'ride':
        default:
          matchedType = activeVehicleTypes.firstWhere(
            (v) => v.id.toLowerCase() == 'economy' || v.id.toLowerCase() == 'sedan' || v.id.toLowerCase() == 'mini',
            orElse: () => activeVehicleTypes.firstWhere(
              (v) => v.name.toLowerCase().contains('cab') || v.name.toLowerCase().contains('sedan'),
              orElse: () => activeVehicleTypes.first,
            ),
          );
          break;
      }

      double fare = matchedType.baseFare + (distanceKm * matchedType.perKmRate);
      return fare < matchedType.minimumFare ? matchedType.minimumFare : fare;
    }

    double baseFare;
    double perKmRate;
    
    switch (serviceType) {
      case 'parcel_bike':
        baseFare = 30;
        perKmRate = 8;
        break;
      case 'parcel_truck':
        baseFare = 100;
        perKmRate = 25;
        break;
      case 'ride':
      default:
        baseFare = 50;
        perKmRate = 12;
        break;
    }
    
    return baseFare + (distanceKm * perKmRate);
  }
}
