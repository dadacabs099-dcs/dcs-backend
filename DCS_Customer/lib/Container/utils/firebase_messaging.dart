import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:Dadacabs/Container/utils/error_notification.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MessagingService {
  static String? fcmToken; // Variable to store the FCM token

  static final MessagingService _instance = MessagingService._internal();

  factory MessagingService() => _instance;

  MessagingService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  Future<void> init(BuildContext context, WidgetRef ref) async {
    if (!(kIsWeb ||
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS)) {
      debugPrint('Firebase messaging is not supported on this platform. Skipping messaging initialization.');
      return;
    }

    try {
      // Requesting permission for notifications
      NotificationSettings settings = await _fcm.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      debugPrint(
          'User granted notifications permission: ${settings.authorizationStatus}');

      // Retrieving the FCM token
      fcmToken = await _fcm.getToken();
      print('fcmToken: $fcmToken');

      // Update FCM token in current user's profile in Firestore if logged in
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null && fcmToken != null) {
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.uid)
              .update({'fcmToken': fcmToken});
          debugPrint('Updated user FCM token in Firestore');
        } catch (e) {
          debugPrint('Failed to update user FCM token in Firestore: $e');
        }
      }

      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'high_importance_channel', // id
        'DCS', // title
        importance: Importance.max,
      );

      final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
          FlutterLocalNotificationsPlugin();

      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      // Handling background messages using the specified handler
      FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler);

      Future<void> showLocalNotification(RemoteMessage message) async {
        final notificationData = message.data;
        final screen = notificationData['screen'];

        final androidDetails = AndroidNotificationDetails(
          'high_importance_channel',
          'DCS',
          channelDescription: 'Customer notifications',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          ticker: message.notification?.title,
        );

        final notificationDetails = NotificationDetails(
          android: androidDetails,
          iOS: const DarwinNotificationDetails(),
        );

        await flutterLocalNotificationsPlugin.show(
          DateTime.now().millisecondsSinceEpoch.remainder(100000),
          message.notification?.title ?? 'DCS Notification',
          message.notification?.body ?? '',
          notificationDetails,
          payload: screen,
        );
      }

      // Listening for incoming messages while the app is in the foreground
      FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
        if (message.notification != null) {
          if (message.notification!.title != null &&
              message.notification!.body != null) {
            await showLocalNotification(message);
          }
        }
      });

      // Handling a notification click event by navigating to the specified screen
      void handleNotificationClick(
          BuildContext context, RemoteMessage message) {
        final notificationData = message.data;

        if (notificationData.containsKey('screen')) {
          final screen = notificationData['screen'];
          if (screen is String && screen.isNotEmpty) {
            context.goNamed(screen);
          }
        }
      }

      // Handling the initial message received when the app is launched from dead (killed state)
      // When the app is killed and a new notification arrives when user clicks on it
      // It gets the data to which screen to open
      FirebaseMessaging.instance.getInitialMessage().then((message) {
        if (message != null) {
          handleNotificationClick(context, message);
        }
      });

      // Handling a notification click event when the app is in the background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        handleNotificationClick(context, message);
      });
    } catch (e, stackTrace) {
      debugPrint('Firebase messaging initialization failed: $e');
      debugPrint('$stackTrace');
      if (context.mounted) {
        ErrorNotification().showError(context, 'Firebase messaging is unavailable on this platform.');
      }
    }
  }
}

// Handler for background messages
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you're going to use other Firebase services in the background, such as Firestore,
  // make sure you call `initializeApp` before using other Firebase services.
  debugPrint('Handling a background message: ${message.notification!.title}');
}
