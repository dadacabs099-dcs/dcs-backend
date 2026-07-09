// ignore_for_file: public_member_api_docs, sort_constructors_first

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:Dadacabs/Model/user_model.dart';
import 'package:Dadacabs/Container/utils/error_notification.dart';

final globalUserRepoProvider = Provider<UserRepo>((ref) {
  return UserRepo();
});

/// [UserRepo] handles all user profile operations
class UserRepo {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final String _primaryCollection = 'users'; // Single collection matching Admin Panel convention

  /// Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;
  String? get currentUserEmail => _auth.currentUser?.email;

  /// Create user profile after registration
  Future<bool> createUserProfile(UserModel user, BuildContext context) async {
    try {
      await _db.collection(_primaryCollection).doc(user.uid).set(user.toJson());
      return true;
    } catch (e) {
      if (context.mounted) {
        ErrorNotification().showError(
            context, "Failed to create profile: $e");
      }
      return false;
    }
  }

  /// Get user profile by UID (direct lookup - minimal server usage)
  Future<UserModel?> getUserProfile(String userId, BuildContext context) async {
    try {
      DocumentSnapshot<Map<String, dynamic>> doc =
          await _db.collection(_primaryCollection).doc(userId).get();

      if (doc.exists && doc.data() != null) {
        return UserModel.fromJson(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      if (context.mounted) {
        ErrorNotification().showError(
            context, "Failed to load profile: $e");
      }
      return null;
    }
  }

  /// Get user profile by email address (single collection - minimal server usage)
  Future<UserModel?> getUserByEmail(String email) async {
    try {
      final snapshot = await _db.collection(_primaryCollection)
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return UserModel.fromJson(snapshot.docs.first.data(), snapshot.docs.first.id);
      }
      return null;
    } catch (e) {
      debugPrint("Failed to find user by email: $e");
      return null;
    }
  }

  /// Get user profile by phone number (similar to Partner App's getDriverByPhone)
  String _normalizePhoneForSearch(String phone) {
    final clean = phone.replaceAll(RegExp(r'\D'), '');
    if (clean.length == 10) return clean;
    if (clean.length == 11 && clean.startsWith('0')) return clean.substring(1);
    if (clean.length > 10 && clean.startsWith('91')) return clean.substring(clean.length - 10);
    return clean;
  }

  Future<UserModel?> getUserByPhone(String phone, [BuildContext? context]) async {
    try {
      debugPrint("=== getUserByPhone START ===");
      debugPrint("Input phone: $phone");
      
      final normalizedTen = _normalizePhoneForSearch(phone);
      debugPrint("Normalized to 10-digit: $normalizedTen");
      
      // 1. Try exact 10-digit match first (Standard - matching Partner APK)
      debugPrint("Step 1: Trying 10-digit match");
      var snapshot = await _db
          .collection(_primaryCollection)
          .where('phone', isEqualTo: normalizedTen)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        debugPrint("✓ FOUND by 10-digit: $normalizedTen");
        return UserModel.fromJson(snapshot.docs.first.data(), snapshot.docs.first.id);
      }

      // 2. Try with +91 prefix (Common format)
      debugPrint("Step 2: Trying +91 prefix format");
      snapshot = await _db
          .collection(_primaryCollection)
          .where('phone', isEqualTo: '+91$normalizedTen')
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        debugPrint("✓ FOUND by +91 format: +91$normalizedTen");
        return UserModel.fromJson(snapshot.docs.first.data(), snapshot.docs.first.id);
      }

      // 3. Try 91 prefix format (No + sign)
      debugPrint("Step 3: Trying 91 prefix format");
      snapshot = await _db
          .collection(_primaryCollection)
          .where('phone', isEqualTo: '91$normalizedTen')
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        debugPrint("✓ FOUND by 91 format: 91$normalizedTen");
        return UserModel.fromJson(snapshot.docs.first.data(), snapshot.docs.first.id);
      }

      // 4. Fallback: Full collection scan (handles variations)
      debugPrint("Step 4: Full collection scan for resilience");
      final allDocs = await _db.collection(_primaryCollection).get();
      debugPrint("Total documents in $_primaryCollection: ${allDocs.docs.length}");
      
      for (var doc in allDocs.docs) {
        try {
          final data = doc.data();
          final phoneKeys = ['phone', 'mobile', 'Phone', 'phoneNumber', 'Full Number'];
          
          for (final key in phoneKeys) {
            if (data.containsKey(key) && data[key] != null) {
              final storedPhone = data[key].toString();
              final storedDigits = storedPhone.replaceAll(RegExp(r'\D'), '');
              debugPrint("Doc ${doc.id}: $key = '$storedPhone' (digits: $storedDigits)");
              
              if (storedDigits.length >= 10 &&
                  storedDigits.substring(storedDigits.length - 10) == normalizedTen) {
                debugPrint("✓ FOUND in Step 4: $key = '$storedPhone'");
                return UserModel.fromJson(data, doc.id);
              }
            }
          }
        } catch (e) {
          debugPrint("Error parsing doc ${doc.id}: $e");
        }
      }

      debugPrint("✗ NOT FOUND for phone: $phone");
      debugPrint("=== getUserByPhone END ===");
      return null;
    } catch (e) {
      debugPrint("ERROR in getUserByPhone: $e");
      if (context != null && context.mounted) {
        // Only show error if it's a permission/network issue, not a simple "not found"
        if (e.toString().contains('permission') || 
            e.toString().contains('PERMISSION_DENIED') ||
            e.toString().contains('network') ||
            e.toString().contains('UNAVAILABLE')) {
          ErrorNotification().showError(
            context, 
            "Firestore Error: Unable to fetch profile. Please check your internet connection.",
          );
        }
      }
      return null;
    }
  }

  /// Stream user profile for real-time updates (direct lookup - minimal server usage)
  Stream<UserModel?> streamUserProfile(String userId) {
    return _db
        .collection(_primaryCollection)
        .doc(userId)
        .snapshots()
        .map((doc) {
      if (doc.exists && doc.data() != null) {
        return UserModel.fromJson(doc.data()!, doc.id);
      }
      return null;
    });
  }

  /// Update user profile
  Future<bool> updateUserProfile(
    String userId,
    Map<String, dynamic> updates,
    BuildContext context,
  ) async {
    try {
      await _db.collection(_primaryCollection).doc(userId).update(updates);
      return true;
    } catch (e) {
      if (context.mounted) {
        ErrorNotification().showError(
            context, "Failed to update profile: $e");
      }
      return false;
    }
  }

  /// Update profile image
  Future<bool> updateProfileImage(
    String userId,
    String imageUrl,
    BuildContext context,
  ) async {
    return updateUserProfile(userId, {'profileImage': imageUrl}, context);
  }

  /// Update wallet balance
  Future<bool> updateWalletBalance(
    String userId,
    double amount,
    BuildContext context,
  ) async {
    try {
      // Use FieldValue for atomic increment
      await _db.collection(_primaryCollection).doc(userId).update({
        'walletBalance': FieldValue.increment(amount),
      });
      return true;
    } catch (e) {
      if (context.mounted) {
        ErrorNotification().showError(
            context, "Failed to update wallet: $e");
      }
      return false;
    }
  }

  /// Update preferred payment method
  Future<bool> updatePreferredPaymentMethod(
    String userId,
    String method,
    BuildContext context,
  ) async {
    return updateUserProfile(userId, {'preferredPaymentMethod': method}, context);
  }

  /// Add payment method
  Future<bool> addPaymentMethod(
    String userId,
    String paymentMethod,
    BuildContext context,
  ) async {
    try {
      await _db.collection(_primaryCollection).doc(userId).update({
        'paymentMethods': FieldValue.arrayUnion([paymentMethod]),
      });
      return true;
    } catch (e) {
      if (context.mounted) {
        ErrorNotification().showError(
            context, "Failed to add payment method: $e");
      }
      return false;
    }
  }

  /// Remove payment method
  Future<bool> removePaymentMethod(
    String userId,
    String paymentMethod,
    BuildContext context,
  ) async {
    try {
      await _db.collection(_primaryCollection).doc(userId).update({
        'paymentMethods': FieldValue.arrayRemove([paymentMethod]),
      });
      return true;
    } catch (e) {
      if (context.mounted) {
        ErrorNotification().showError(
            context, "Failed to remove payment method: $e");
      }
      return false;
    }
  }

  /// Update last login
  Future<void> updateLastLogin(String userId) async {
    try {
      await _db.collection(_primaryCollection).doc(userId).update({
        'lastLoginAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      // Silent fail for non-critical update
      debugPrint("Failed to update last login: $e");
    }
  }

  /// Increment total rides count
  Future<void> incrementTotalRides(String userId) async {
    try {
      await _db.collection(_primaryCollection).doc(userId).update({
        'totalRides': FieldValue.increment(1),
      });
    } catch (e) {
      debugPrint("Failed to increment rides: $e");
    }
  }

  /// Update user rating (average)
  Future<bool> updateUserRating(
    String userId,
    double newRating,
    BuildContext context,
  ) async {
    try {
      // Get current user data
      final user = await getUserProfile(userId, context);
      if (user == null) return false;

      // Calculate new average
      final currentRides = user.totalRides;
      final currentRating = user.rating;
      final newAverage =
          ((currentRating * currentRides) + newRating) / (currentRides + 1);

      await _db.collection(_primaryCollection).doc(userId).update({
        'rating': newAverage,
      });
      return true;
    } catch (e) {
      if (context.mounted) {
        ErrorNotification().showError(
            context, "Failed to update rating: $e");
      }
      return false;
    }
  }

  /// Save addresses
  Future<bool> saveAddresses(
    String userId,
    String? homeAddress,
    String? workAddress,
    BuildContext context,
  ) async {
    try {
      final updates = <String, dynamic>{};
      if (homeAddress != null) updates['homeAddress'] = homeAddress;
      if (workAddress != null) updates['workAddress'] = workAddress;

      await _db.collection(_primaryCollection).doc(userId).update(updates);
      return true;
    } catch (e) {
      if (context.mounted) {
        ErrorNotification().showError(
            context, "Failed to save addresses: $e");
      }
      return false;
    }
  }
}
