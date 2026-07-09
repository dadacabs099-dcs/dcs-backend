import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../View/Routes/routes.dart';
import '../utils/error_notification.dart';
import '../Providers/user_data_provider.dart';
import 'user_repo.dart';

/// [authRepoProvider] used to cache the [AuthRepo] class to prevent it from creating multiple instances

final globalAuthRepoProvider = Provider<AuthRepo>((ref) {
  return AuthRepo();
});

/// [AuthRepo] provides functions used for authentication purposes

class AuthRepo {
  void loginUser(email, password, BuildContext context, WidgetRef ref) async {
    try {
      final userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);
      
      // Load user data from Firestore after successful login
      if (userCredential.user != null) {
        try {
          final userRepo = UserRepo();
          var userData = await userRepo.getUserProfile(userCredential.user!.uid, context);

          // Legacy migration: if record exists with email as document ID, migrate it to UID-based key
          if (userData == null && email != null && email.toString().contains('@')) {
            final legacyUser = await userRepo.getUserByEmail(email);
            if (legacyUser != null) {
              final migratedUser = legacyUser.copyWith(uid: userCredential.user!.uid);
              await userRepo.createUserProfile(migratedUser, context);
              userData = migratedUser;
              // Change made by Jayant Pandit on 2026-05-29 00:05:00 - Reason: Migrate legacy customer document keyed by email to UID-based profile after successful login.
            }
          }

          if (userData != null && context.mounted) {
            ref.read(userDataProvider.notifier).state = userData;
          }
        } catch (e) {
          debugPrint("Error loading user data after login: $e");
        }
      }
      
      if (context.mounted) {
        context.goNamed(Routes().home);
      }
    } catch (e) {
      if (context.mounted) {
        ErrorNotification().showError(context, "An Error Occurred $e");
      }
    }
  }

  Future<void> registerUser(email, password, BuildContext context, WidgetRef ref, {String? name, String? phone}) async {
    try {
      print("🔥 USER: Starting user registration");
      
      // Step 1: Create Firebase Auth user
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      print("🔥 USER: Firebase Auth successful");
      print("🔥 USER: UID: ${userCredential.user?.uid}");

      // Step 2: Create Firestore document matching admin-panel schema
      await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
        // Basic fields matching admin-panel User model
        'uid': userCredential.user!.uid,
        'name': name ?? email.split('@')[0],
        'email': email,
        'phone': phone ?? '',
        'profileImage': null,
        
        // Account status
        'isActive': true,
        'isVerified': false,
        'isAdmin': false,
        'isSuspended': false,
        
        // Wallet
        'walletBalance': 0,
        'walletTransactions': [],
        
        // Preferences
        'preferredPaymentMethod': 'cash',
        'preferences': {
          'preferredVehicleType': 'sedan',
          'notificationEnabled': true,
          'emailMarketing': false,
          'smsMarketing': false
        },
        
        // Stats
        'stats': {
          'totalRides': 0,
          'totalDistance': 0,
          'totalSpent': 0,
          'cancelledRides': 0
        },
        
        // Loyalty
        'loyaltyPoints': 0,
        
        // Timestamps
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      });
      // Change made by Jayant Pandit on 2026-05-29 00:00:00 - Reason: Save customer profile document keyed by UID not email so login can resolve the record after authentication. Signed: Jayant Pandit

      print("🔥 USER: Firestore document created");
      
      // Load user data into provider after successful registration
      if (userCredential.user != null) {
        try {
          final userRepo = UserRepo();
          final userData = await userRepo.getUserProfile(userCredential.user!.uid, context);
          if (userData != null && context.mounted) {
            ref.read(userDataProvider.notifier).state = userData;
          }
        } catch (e) {
          debugPrint("Error loading user data after registration: $e");
        }
      }
      
      if (context.mounted) {
        ErrorNotification().showSuccess(context, "User account created successfully!");
        context.goNamed(Routes().home);
      }
    } catch (e) {
      print("🔥 USER: Registration error: $e");
      if (context.mounted) {
        ErrorNotification().showError(context, "Registration failed: ${e.toString()}");
      }
    }
  }
}
