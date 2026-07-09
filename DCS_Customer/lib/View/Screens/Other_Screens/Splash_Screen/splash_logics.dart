import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:Dadacabs/Container/utils/error_notification.dart';
import 'package:Dadacabs/Container/Providers/user_data_provider.dart';
import 'package:Dadacabs/Container/Repositories/user_repo.dart';
import 'package:Dadacabs/Model/user_model.dart';
import 'package:Dadacabs/View/Routes/routes.dart';

class SplashLogics{
  void initializeUser(BuildContext context, WidgetRef ref) async {
    FirebaseAuth? _auth;
    try {
      _auth = FirebaseAuth.instance;
    } catch (e) {
      _auth = null;
    }

    final User? user = _auth?.currentUser;
    UserModel? userData;

    if (user != null) {
      // Load user data before navigating
      try {
        final userRepo = UserRepo();
        userData = await userRepo.getUserProfile(user.uid, context);

        if (userData == null) {
          // Fallback to phone or email-based lookup for legacy documents
          if (user.phoneNumber != null && user.phoneNumber!.isNotEmpty) {
            userData = await userRepo.getUserByPhone(user.phoneNumber!);
          }
          if (userData == null && user.email != null && user.email!.isNotEmpty) {
            userData = await userRepo.getUserByEmail(user.email!);
          }

          if (userData != null && userData.uid != user.uid) {
            final migratedUser = userData.copyWith(uid: user.uid);
            await userRepo.createUserProfile(migratedUser, context);
            userData = migratedUser;
          }
        }

        if (userData != null) {
          ref.read(userDataProvider.notifier).state = userData;
        }
      } catch (e) {
        debugPrint("Error loading user on splash: $e");
      }

      String destination = Routes().home;
      Object? extra;

      if (context.mounted && userData == null) {
        if (user.phoneNumber != null && user.phoneNumber!.isNotEmpty) {
          destination = Routes().register;
          extra = user.phoneNumber!.replaceFirst('+91', '');
        } else {
          destination = Routes().login;
        }
      }

      Timer(
        const Duration(seconds: 3),
        () {
          if (extra != null) {
            context.goNamed(destination, extra: extra);
          } else {
            context.goNamed(destination);
          }
        },
      );
    } else {
      // Modified by Jayant Pandit on 2026-05-18 18:25:00
      // Reason: Check SharedPreferences to see if a Dev Bypass session exists (Partner APK pattern).
      // This prevents relogin on minimize.
      try {
        final prefs = await SharedPreferences.getInstance();
        final bypassPhone = prefs.getString('dev_bypass_phone');
        if (bypassPhone != null && bypassPhone.isNotEmpty) {
          final userRepo = UserRepo();
          final userData = await userRepo.getUserByPhone(bypassPhone, context);
          if (userData != null) {
            ref.read(userDataProvider.notifier).state = userData;
            Timer(const Duration(seconds: 3), () {
              context.goNamed(Routes().home);
            });
            return;
          }
        }
      } catch (e) {
        debugPrint("Error loading bypass user on splash: $e");
      }

      Timer(const Duration(seconds: 3), () {
        context.goNamed(Routes().login);
      });
    }
  }

  /// [checkPermissions] checking the permission status

  void checkPermissions(BuildContext context, WidgetRef ref) async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
        LocationPermission permission2 = await Geolocator.checkPermission();
        if (context.mounted &&
            (permission2 == LocationPermission.whileInUse ||
                permission2 == LocationPermission.always)) {
          initializeUser(context, ref);
        } else {
          if (context.mounted) {
            ErrorNotification().showError(
                context, "Location Access is required to run DCS.");
          }
          await Future.delayed(const Duration(seconds: 2));
          SystemChannels.platform
              .invokeMethod("SystemNavigator.pop");
        }
        return;
      } else if ( context.mounted &&( permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always)) {
        initializeUser(context, ref);
        return;
      }

      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.unableToDetermine) {
        if (context.mounted) {
          ErrorNotification()
              .showError(context, "Location Access is required to run DCS.");
          await Future.delayed(const Duration(seconds: 2));
          SystemChannels.platform
              .invokeMethod("SystemNavigator.pop");
        }
        return;
      }
    } catch (e) {
      if (context.mounted) {
        ErrorNotification().showError(context, "An Error Occurred $e");
      }
    }
  }
}
