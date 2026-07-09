// ignore_for_file: public_member_api_docs, sort_constructors_first

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:Dadacabs/Model/Pooling/pool_trip_model.dart';
import 'package:Dadacabs/Container/utils/error_notification.dart';

final globalPoolRepoProvider = Provider<PoolRepo>((ref) {
  return PoolRepo();
});

/// [PoolRepo] handles all ride pooling operations
class PoolRepo {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _collection = 'pool_trips';
  final String _requestsCollection = 'pool_requests';

  /// Create a new pool trip request
  Future<String?> createPoolTrip(
    PoolTrip poolTrip,
    BuildContext context,
  ) async {
    try {
      await _db.collection(_collection).doc(poolTrip.poolId).set(
            poolTrip.toJson(),
          );
      return poolTrip.poolId;
    } catch (e) {
      if (context.mounted) {
        ErrorNotification().showError(
            context, "Failed to create pool: $e");
      }
      return null;
    }
  }

  /// Find available pools near a location
  Stream<List<PoolTrip>> findAvailablePools(
    LatLng pickupLocation,
    LatLng dropoffLocation,
    int requiredSeats,
  ) {
    // Use standard Firestore query without geo filtering
    return _db
        .collection(_collection)
        .where('availableSeats', isGreaterThanOrEqualTo: requiredSeats)
        .where('status', whereIn: ['matching', 'confirmed'])
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => PoolTrip.fromJson(doc.data()))
          .toList();
    });
  }

  /// Request to join a pool
  Future<bool> requestToJoinPool(
    PoolRequest request,
    BuildContext context,
  ) async {
    try {
      await _db
          .collection(_requestsCollection)
          .doc(request.requestId)
          .set(request.toJson());

      // Update pool available seats temporarily (reserved)
      await _db.collection(_collection).doc(request.poolId).update({
        'availableSeats': FieldValue.increment(-1),
      });

      return true;
    } catch (e) {
      if (context.mounted) {
        ErrorNotification().showError(
            context, "Failed to request pool: $e");
      }
      return false;
    }
  }

  /// Accept a passenger into the pool
  Future<bool> acceptPassenger(
    String poolId,
    String requestId,
    PoolPassenger passenger,
    BuildContext context,
  ) async {
    try {
      // Update request status
      await _db.collection(_requestsCollection).doc(requestId).update({
        'status': 'accepted',
      });

      // Add passenger to pool
      await _db.collection(_collection).doc(poolId).update({
        'passengers': FieldValue.arrayUnion([passenger.toJson()]),
        'currentPassengers': FieldValue.increment(1),
      });

      return true;
    } catch (e) {
      if (context.mounted) {
        ErrorNotification().showError(
            context, "Failed to accept passenger: $e");
      }
      return false;
    }
  }

  /// Reject a pool request
  Future<bool> rejectPassenger(
    String poolId,
    String requestId,
    String reason,
    BuildContext context,
  ) async {
    try {
      // Update request status
      await _db.collection(_requestsCollection).doc(requestId).update({
        'status': 'rejected',
        'rejectionReason': reason,
      });

      // Restore available seats
      await _db.collection(_collection).doc(poolId).update({
        'availableSeats': FieldValue.increment(1),
      });

      return true;
    } catch (e) {
      if (context.mounted) {
        ErrorNotification().showError(
            context, "Failed to reject passenger: $e");
      }
      return false;
    }
  }

  /// Get active pools for a driver
  Stream<List<PoolTrip>> getDriverPools(String driverId) {
    return _db
        .collection(_collection)
        .where('driverId', isEqualTo: driverId)
        .where('status', whereIn: ['matching', 'confirmed', 'inProgress'])
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => PoolTrip.fromJson(doc.data()))
          .toList();
    });
  }

  /// Get pool requests for a driver
  Stream<List<PoolRequest>> getPoolRequests(String poolId) {
    return _db
        .collection(_requestsCollection)
        .where('poolId', isEqualTo: poolId)
        .where('status', isEqualTo: 'pending')
        .orderBy('requestedAt')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => PoolRequest.fromJson(doc.data()))
          .toList();
    });
  }

  /// Get user's active pool trips
  Stream<PoolTrip?> getUserActivePool(String userId) {
    return _db
        .collection(_collection)
        .where('passengers', arrayContains: {'passengerId': userId})
        .where('status', whereIn: ['confirmed', 'driverEnRoute', 'arrived', 'inProgress'])
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        return PoolTrip.fromJson(snapshot.docs.first.data());
      }
      return null;
    });
  }

  /// Get user's pool history
  Stream<List<PoolTrip>> getUserPoolHistory(String userId) {
    return _db
        .collection(_collection)
        .where('passengers', arrayContains: {'passengerId': userId})
        .where('status', isEqualTo: 'completed')
        .orderBy('completedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => PoolTrip.fromJson(doc.data()))
          .toList();
    });
  }

  /// Update pool status
  Future<bool> updatePoolStatus(
    String poolId,
    PoolStatus status,
    BuildContext context,
  ) async {
    try {
      Map<String, dynamic> update = {'status': status.name};

      switch (status) {
        case PoolStatus.driverEnRoute:
          // Driver heading to first pickup
          break;
        case PoolStatus.arrived:
          update['arrivedAt'] = DateTime.now().toIso8601String();
          break;
        case PoolStatus.inProgress:
          update['startedAt'] = DateTime.now().toIso8601String();
          break;
        case PoolStatus.completed:
          update['completedAt'] = DateTime.now().toIso8601String();
          break;
        default:
          break;
      }

      await _db.collection(_collection).doc(poolId).update(update);
      return true;
    } catch (e) {
      if (context.mounted) {
        ErrorNotification().showError(
            context, "Failed to update pool status: $e");
      }
      return false;
    }
  }

  /// Mark a stop as completed
  Future<bool> completeStop(
    String poolId,
    String stopId,
    BuildContext context,
  ) async {
    try {
      // Get current pool
      final doc = await _db.collection(_collection).doc(poolId).get();
      if (!doc.exists) return false;

      final pool = PoolTrip.fromJson(doc.data()!);

      // Update stop status
      final updatedStops = pool.stops.map((stop) {
        if (stop.stopId == stopId) {
          return PoolStop(
            stopId: stop.stopId,
            passengerId: stop.passengerId,
            passengerName: stop.passengerName,
            phoneNumber: stop.phoneNumber,
            location: stop.location,
            address: stop.address,
            type: stop.type,
            sequence: stop.sequence,
            estimatedTime: stop.estimatedTime,
            actualTime: DateTime.now(),
            status: StopStatus.completed,
          );
        }
        return stop;
      }).toList();

      await _db.collection(_collection).doc(poolId).update({
        'stops': updatedStops.map((s) => s.toJson()).toList(),
      });

      return true;
    } catch (e) {
      if (context.mounted) {
        ErrorNotification().showError(
            context, "Failed to complete stop: $e");
      }
      return false;
    }
  }

  /// Rate pool experience
  Future<bool> ratePool(
    String poolId,
    String userId,
    double rating,
    String? review,
    bool isDriver, // true if driver is rating passenger
    BuildContext context,
  ) async {
    try {
      if (isDriver) {
        // Driver rating passenger
        await _db.collection(_collection).doc(poolId).update({
          'passengerRatings.$userId': rating,
        });
      } else {
        // Passenger rating driver
        await _db.collection(_collection).doc(poolId).update({
          'driverRating': rating,
          'driverReview': review,
        });
      }
      return true;
    } catch (e) {
      if (context.mounted) {
        ErrorNotification().showError(
            context, "Failed to submit rating: $e");
      }
      return false;
    }
  }

  /// Cancel pool (by driver or system)
  Future<bool> cancelPool(
    String poolId,
    String reason,
    BuildContext context,
  ) async {
    try {
      await _db.collection(_collection).doc(poolId).update({
        'status': 'cancelled',
        'cancelledAt': DateTime.now().toIso8601String(),
        'cancellationReason': reason,
      });
      return true;
    } catch (e) {
      if (context.mounted) {
        ErrorNotification().showError(
            context, "Failed to cancel pool: $e");
      }
      return false;
    }
  }

  /// Calculate fare split for passengers
  Map<String, double> calculateFareSplit(
    double totalFare,
    List<PoolPassenger> passengers,
    double discountPercentage,
  ) {
    final discountedTotal = totalFare * (1 - discountPercentage / 100);
    final perPassenger = discountedTotal / passengers.length;

    return {
      for (var p in passengers) p.passengerId: perPassenger,
    };
  }

  /// Optimize route for pool (simplified - would use real routing API)
  List<PoolStop> optimizeRoute(List<PoolStop> stops, GeoPoint driverLocation) {
    // Simple distance-based sorting
    // In production, use Google Maps Directions API with optimize:true
    final sorted = List<PoolStop>.from(stops);
    sorted.sort((a, b) => a.sequence.compareTo(b.sequence));
    return sorted;
  }
}
