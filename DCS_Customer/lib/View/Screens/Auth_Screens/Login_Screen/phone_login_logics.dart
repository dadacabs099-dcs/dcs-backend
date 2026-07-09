import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:Dadacabs/Container/utils/error_notification.dart';
import 'package:Dadacabs/Container/Providers/user_data_provider.dart';
import 'package:Dadacabs/Container/Repositories/user_repo.dart';
import 'package:Dadacabs/Model/user_model.dart';
import 'package:Dadacabs/View/Routes/routes.dart';
import 'phone_login_providers.dart';

class PhoneLoginLogics {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Send OTP to phone number
  void sendOTP(
    BuildContext context,
    WidgetRef ref,
    TextEditingController phoneController,
  ) async {
    String phoneNumber = phoneController.text.trim();

    // Validate phone number
    if (phoneNumber.isEmpty) {
      ErrorNotification().showError(context, "Please enter mobile number");
      return;
    }

    if (phoneNumber.length != 10) {
      ErrorNotification().showError(context, "Please enter valid 10-digit mobile number");
      return;
    }

    // Set loading state
    ref.read(phoneLoginIsLoadingProvider.notifier).state = true;

    try {
      // For production, use real Firebase Auth. For testing, keep the bypass option.
      const bool useBypass = true;

      if (useBypass) {
        // DEVELOPMENT BYPASS: Using random fake OTP
        String randomOTP = (100000 + (DateTime.now().millisecondsSinceEpoch % 900000)).toString();
        String fakeVerificationId = "dev_bypass_$randomOTP";
        
        await Future.delayed(const Duration(seconds: 1));
        
        ref.read(phoneLoginIsLoadingProvider.notifier).state = false;
        ref.read(verificationIdProvider.notifier).state = fakeVerificationId;

        if (context.mounted) {
          context.pushNamed(
            Routes().otp,
            extra: {
              'phoneNumber': phoneNumber,
              'verificationId': fakeVerificationId,
            },
          );
          ErrorNotification().showSuccess(context, "Use OTP $randomOTP (Dev Mode)");
        }
      } else {
        // REAL FIREBASE AUTH LOGIC
        await _auth.verifyPhoneNumber(
          phoneNumber: "+91$phoneNumber",
          verificationCompleted: (PhoneAuthCredential credential) async {
            await _signInWithCredential(context, ref, credential, phoneNumber);
          },
          verificationFailed: (FirebaseAuthException e) {
            ref.read(phoneLoginIsLoadingProvider.notifier).state = false;
            String errorMessage = "Firebase Auth fails: ${e.message}";
            if (e.code == 'invalid-phone-number') {
              errorMessage = "The provided phone number is not valid.";
            } else if (e.code == 'too-many-requests') {
              errorMessage = "Too many requests. Please try again later.";
            }
            ErrorNotification().showError(context, errorMessage);
          },
          codeSent: (String verificationId, int? resendToken) {
            ref.read(phoneLoginIsLoadingProvider.notifier).state = false;
            ref.read(verificationIdProvider.notifier).state = verificationId;

            if (context.mounted) {
              context.pushNamed(
                Routes().otp,
                extra: {
                  'phoneNumber': phoneNumber,
                  'verificationId': verificationId,
                },
              );
            }
          },
          codeAutoRetrievalTimeout: (String verificationId) {
            ref.read(verificationIdProvider.notifier).state = verificationId;
          },
        );
      }
    } catch (e) {
      ref.read(phoneLoginIsLoadingProvider.notifier).state = false;
      ErrorNotification().showError(context, "Unexpected Error: ${e.toString()}");
    }
  }

  /// Verify OTP code
  void verifyOTP(
    BuildContext context,
    WidgetRef ref,
    String verificationId,
    String otpCode,
    String phoneNumber,
  ) async {
    if (otpCode.length != 6) {
      ErrorNotification().showError(context, "Please enter complete 6-digit OTP");
      return;
    }

    ref.read(otpVerifyIsLoadingProvider.notifier).state = true;

    try {
      // DEVELOPMENT BYPASS
      if (verificationId.startsWith("dev_bypass_")) {
        await Future.delayed(const Duration(seconds: 1));
        
        String correctOTP = verificationId.split('_').last;
        
        if (otpCode != correctOTP) {
          ref.read(otpVerifyIsLoadingProvider.notifier).state = false;
          ErrorNotification().showError(context, "Invalid OTP. Use $correctOTP");
          return;
        }
        
        // DEV BYPASS: Fetch user by phone number using UserRepo (replicating Partner APK pattern)
        final userRepo = ref.read(globalUserRepoProvider);
        final userData = await userRepo.getUserByPhone(phoneNumber);
        
        ref.read(otpVerifyIsLoadingProvider.notifier).state = false;
        
        if (context.mounted) {
          if (userData != null) {
            // Modified by Jayant Pandit on 2026-05-18 18:24:00
            // Reason: Persist dev bypass login state so minimizing app does not cause a relogin
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('dev_bypass_phone', phoneNumber);

            ref.read(userDataProvider.notifier).state = userData;
            String welcomeName = userData.name.isEmpty ? "Customer" : userData.name;
            ErrorNotification().showSuccess(context, "Use OTP $correctOTP (Dev Mode)");
            await Future.delayed(const Duration(milliseconds: 500));
            if (context.mounted) {
              ErrorNotification().showSuccess(context, "Welcome back, $welcomeName!");
              context.goNamed(Routes().home);
            }
          } else {
            ErrorNotification().showSuccess(context, "Welcome! Let's set up your profile.");
            context.goNamed(Routes().register, extra: phoneNumber);
          }
        }
        return;
      }

      // PROD LOGIC
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: otpCode,
      );
      await _signInWithCredential(context, ref, credential, phoneNumber);
    } catch (e) {
      ref.read(otpVerifyIsLoadingProvider.notifier).state = false;
      ErrorNotification().showError(context, "Verification failed: ${e.toString()}");
    }
  }

  /// Sign in with phone credential
  Future<void> _signInWithCredential(
    BuildContext context,
    WidgetRef ref,
    PhoneAuthCredential credential,
    String phoneNumber,
  ) async {
    try {
      UserCredential userCredential = await _auth.signInWithCredential(credential);
      if (userCredential.user != null) {
        await _handlePostSignIn(context, ref, userCredential.user!.uid, phoneNumber);
      }
    } on FirebaseAuthException catch (e) {
      ref.read(otpVerifyIsLoadingProvider.notifier).state = false;
      ErrorNotification().showError(context, "Firebase Auth fails: ${e.message}");
    }
  }

  /// Handle post sign-in logic (Firestore lookup via UserRepo — matching Partner APK pattern)
  Future<void> _handlePostSignIn(BuildContext context, WidgetRef ref, String uid, String phoneNumber) async {
    final userRepo = ref.read(globalUserRepoProvider);
    
    // 1. Try fetching by UID first (Standard — matching Partner APK's getDriverDetails(uid))
    UserModel? userData = await userRepo.getUserProfile(uid, context);
    
    // 2. If not found by UID, try by Phone Number (Legacy/Fallback — matching Partner APK's getDriverByPhone)
    if (userData == null) {
      userData = await userRepo.getUserByPhone(phoneNumber, context);
      
      // MIGRATION: If found by phone but not UID, update the record with the new UID
      if (userData != null) {
        try {
          await FirebaseFirestore.instance.collection("users").doc(uid).set(
            userData.toJson(),
            SetOptions(merge: true)
          );
          userData = userData.copyWith(uid: uid);
        } catch (e) {
          debugPrint("Migration failed: $e");
        }
      }
    }
    
    ref.read(otpVerifyIsLoadingProvider.notifier).state = false;
    
    if (context.mounted) {
      if (userData != null) {
        ref.read(userDataProvider.notifier).state = userData;
        String welcomeName = userData.name.isEmpty ? "Customer" : userData.name;
        ErrorNotification().showSuccess(context, "Welcome back, $welcomeName!");
        context.goNamed(Routes().home);
      } else {
        // No user found, go to profile setup with phone number
        context.goNamed(
          Routes().register,
          extra: phoneNumber,
        );
      }
    }
  }

  /// Resend OTP
  void resendOTP(BuildContext context, WidgetRef ref, String phoneNumber) async {
    sendOTP(context, ref, TextEditingController(text: phoneNumber));
  }

  /// Logout user
  Future<void> logout(BuildContext context, WidgetRef ref) async {
    // Clear dev bypass persistence on logout
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('dev_bypass_phone');

    await _auth.signOut();
    if (context.mounted) {
      context.goNamed(Routes().login);
    }
  }
}
