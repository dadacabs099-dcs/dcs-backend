import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:Dadacabs/Container/utils/error_notification.dart';
import 'package:Dadacabs/Container/Repositories/user_repo.dart';
import 'package:Dadacabs/Model/user_model.dart';
import 'package:Dadacabs/View/Routes/routes.dart';
import 'package:Dadacabs/Container/Providers/user_data_provider.dart';
import 'package:go_router/go_router.dart';
import 'register_providers.dart';

class RegisterLogics {
  // ──────────────────────────────────────────────────────────────
  // Step 1 — Validate inputs and generate a mock OTP
  // ──────────────────────────────────────────────────────────────
  void sendOTP(
    BuildContext context,
    WidgetRef ref,
    TextEditingController nameController,
    TextEditingController phoneController,
  ) async {
    final name = nameController.text.trim();
    final phone = phoneController.text.trim();

    if (name.isEmpty) {
      ErrorNotification().showError(context, "Please enter your full name");
      return;
    }
    if (phone.isEmpty || phone.length != 10) {
      ErrorNotification().showError(context, "Please enter a valid 10-digit mobile number");
      return;
    }

    // Check if phone already registered
    ref.read(registerIsLoadingProvider.notifier).update((s) => true);
    final existing = await ref.read(globalUserRepoProvider).getUserByPhone(phone, context);
    ref.read(registerIsLoadingProvider.notifier).update((s) => false);

    if (existing != null) {
      if (context.mounted) {
        ErrorNotification().showError(
          context,
          "This mobile number is already registered. Please login.",
        );
      }
      return;
    }

    // Generate mock OTP
    final otp = (100000 + (DateTime.now().millisecondsSinceEpoch % 900000)).toString();
    ref.read(registerOtpProvider.notifier).update((s) => otp);
    ref.read(registerStepProvider.notifier).update((s) => 1); // move to OTP step

    if (context.mounted) {
      ErrorNotification().showSuccess(context, "OTP sent! Use code $otp");
    }
  }

  // ──────────────────────────────────────────────────────────────
  // Step 2 — Verify OTP and create user account
  // ──────────────────────────────────────────────────────────────
  void verifyAndRegister(
    BuildContext context,
    WidgetRef ref,
    String name,
    String phone,
    String enteredOtp,
  ) async {
    final correctOtp = ref.read(registerOtpProvider);

    if (enteredOtp.length != 6) {
      ErrorNotification().showError(context, "Please enter the complete 6-digit OTP");
      return;
    }

    if (enteredOtp != correctOtp) {
      ErrorNotification().showError(context, "Invalid OTP. Please use $correctOtp");
      return;
    }

    ref.read(registerIsLoadingProvider.notifier).update((s) => true);

    try {
      // Create a new user doc in Firestore under 'users' collection
      final uid = DateTime.now().millisecondsSinceEpoch.toString(); // temp UID
      final user = UserModel(
        uid: uid,
        name: name,
        email: '',
        phone: '+91$phone',
        profileImage: '',
        isActive: true,
        walletBalance: 0.0,
        totalRides: 0,
        rating: 5.0,
        createdAt: DateTime.now(),
      );

      await ref.read(globalUserRepoProvider).createUserProfile(user, context);

      // Set user data in provider after successful registration
      ref.read(userDataProvider.notifier).state = user;

      ref.read(registerIsLoadingProvider.notifier).update((s) => false);

      if (context.mounted) {
        ErrorNotification().showSuccess(context, "Welcome to Dada Cabs, $name! 🎉");
        context.goNamed(Routes().home);
      }
    } catch (e) {
      ref.read(registerIsLoadingProvider.notifier).update((s) => false);
      if (context.mounted) {
        ErrorNotification().showError(context, "Registration failed: $e");
      }
    }
  }
  // ──────────────────────────────────────────────────────────────
  // Simple Registration (After phone is already verified)
  // ──────────────────────────────────────────────────────────────
  void registerUserSimple(
    BuildContext context,
    WidgetRef ref,
    String name,
    String email,
    String phone,
  ) async {
    ref.read(registerIsLoadingProvider.notifier).update((s) => true);

    try {
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        debugPrint("No active Firebase session during registration. Dev mode detected - using generated UID.");
      }

      // If we are in Dev Mode (no user), we generate a dummy UID based on phone
      // This matches Partner APK's approach for dev bypass mode
      String targetUid = currentUser?.uid ?? "dev_uid_$phone";

      // Normalize phone number for storage
      final cleanInput = phone.replaceAll(RegExp(r'\D'), '');
      String formattedPhone = cleanInput;
      if (cleanInput.length == 10) {
        formattedPhone = '+91$cleanInput';
      } else if (cleanInput.length == 11 && cleanInput.startsWith('0')) {
        formattedPhone = '+91${cleanInput.substring(1)}';
      } else if (cleanInput.length == 12 && cleanInput.startsWith('91')) {
        formattedPhone = '+$cleanInput';
      } else if (cleanInput.length == 13 && cleanInput.startsWith('091')) {
        formattedPhone = '+91${cleanInput.substring(3)}';
      }

      // Create a new user doc in Firestore under 'users' collection
      final user = UserModel(
        uid: targetUid,
        name: name,
        email: email,
        phone: formattedPhone,
        profileImage: '',
        isActive: true,
        walletBalance: 0.0,
        totalRides: 0,
        rating: 5.0,
        createdAt: DateTime.now(),
      );

      // ignore: use_build_context_synchronously
      final created = await ref.read(globalUserRepoProvider).createUserProfile(user, context);
      if (!created) {
        debugPrint("Registration failed: createUserProfile returned false.");
        ref.read(registerIsLoadingProvider.notifier).update((s) => false);
        return;
      }

      // Set user data in provider after successful registration (Partner APK pattern)
      ref.read(userDataProvider.notifier).state = user;

      // Persist dev bypass session so splash can restore after app restart (matches phone_login_logics pattern)
      // Uses clean 10-digit digits (not +91 prefix) so splash screen's getByPhone lookup works consistently
      final rawPhone10 = cleanInput.length >= 10 ? cleanInput.substring(cleanInput.length - 10) : cleanInput;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('dev_bypass_phone', rawPhone10);
      debugPrint("Dev bypass session persisted for phone: $rawPhone10");

      ref.read(registerIsLoadingProvider.notifier).update((s) => false);

      if (context.mounted) {
        ErrorNotification().showSuccess(context, "Welcome to Dada Cabs, $name! 🎉");
        context.goNamed(Routes().home);
      }
    } catch (e) {
      ref.read(registerIsLoadingProvider.notifier).update((s) => false);
      if (context.mounted) {
        ErrorNotification().showError(context, "Registration failed: $e");
      }
    }
  }
}
