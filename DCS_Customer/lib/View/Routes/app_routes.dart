import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:Dadacabs/View/Routes/routes.dart';
import 'package:Dadacabs/Model/trip_model.dart';
import 'package:Dadacabs/View/Screens/Auth_Screens/Login_Screen/login_screen.dart';
import 'package:Dadacabs/View/Screens/Auth_Screens/Login_Screen/otp_verification_screen.dart';
import 'package:Dadacabs/View/Screens/Auth_Screens/Register_Screen/register_screen.dart';
import 'package:Dadacabs/View/Screens/Main_Screens/Sub_Screens/Where_To_Screen/where_to_screen.dart';
import 'package:Dadacabs/View/Screens/Main_Screens/Sub_Screens/Booking_Screen/booking_summary_screen.dart';
import 'package:Dadacabs/View/Screens/Main_Screens/Parcel_Screen/parcel_screen.dart';
import 'package:Dadacabs/View/Screens/Main_Screens/Parcel_Screen/parcel_confirm_screen.dart';
import 'package:Dadacabs/View/Screens/Main_Screens/Parcel_Screen/parcel_tracking_screen.dart';
import 'package:Dadacabs/View/Screens/Main_Screens/Profile_Screen/profile_screen.dart';
import 'package:Dadacabs/View/Screens/Main_Screens/History_Screen/history_screen.dart';
import 'package:Dadacabs/View/Screens/Main_Screens/Payment_Screen/payment_screen.dart';
import 'package:Dadacabs/View/Screens/Main_Screens/Notifications_Screen/notifications_screen.dart';
import 'package:Dadacabs/View/Screens/Other_Screens/Settings_Screen/settings_screen.dart';
import 'package:Dadacabs/View/Screens/Main_Screens/Active_Trip_Screen/active_trip_screen.dart';
import 'package:Dadacabs/View/Screens/Main_Screens/Active_Trip_Screen/active_trip_screen_modern.dart';
import 'package:Dadacabs/View/Screens/Main_Screens/Sub_Screens/Booking_Screen/booking_summary_screen_modern.dart';
import 'package:Dadacabs/View/Screens/Main_Screens/Home_Screen/home_screen_modern.dart';
import 'package:Dadacabs/View/Screens/Main_Screens/Payment_Screen/payment_screen_modern.dart';
import 'package:Dadacabs/View/Screens/Main_Screens/Sub_Screens/Vehicle_Selection_Screen/vehicle_selection_screen_modern.dart';
import 'package:Dadacabs/View/Screens/Main_Screens/Sub_Screens/Where_To_Screen/where_to_screen_modern.dart';
import 'package:Dadacabs/View/Screens/Main_Screens/Sub_Screens/Pickup_Screen/pickup_screen_modern.dart';
import 'package:Dadacabs/View/Screens/Main_Screens/Trip_Completion_Screen/trip_completion_screen.dart';
import 'package:Dadacabs/View/Screens/Nav_Screens/navigation_screen.dart';

import 'package:Dadacabs/View/Screens/Other_Screens/Splash_Screen/splash_screen.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');



final GoRouter router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/${Routes().splash}',



  routes:allRoutes
);


final List<RouteBase> allRoutes =[

  // Other Screen Routes

    GoRoute(
      name: Routes().splash,
      path: '/${Routes().splash}',
      builder: (BuildContext context, GoRouterState state) {
        return const SplashScreen();
      },
    ),

    // Auth Routes
    GoRoute(
      name: Routes().login,
      path: '/${Routes().login}',
      builder: (BuildContext context, GoRouterState state) {
        return const LoginScreen();
      },
    ),
    GoRoute(
      name: Routes().register,
      path: '/${Routes().register}',
      builder: (BuildContext context, GoRouterState state) {
        final phone = state.extra as String?;
        return RegisterScreen(phoneNumber: phone);
      },
    ),
    GoRoute(
      name: Routes().otp,
      path: '/${Routes().otp}',
      builder: (BuildContext context, GoRouterState state) {
        final extra = state.extra as Map<String, String>;
        return OTPVerificationScreen(
          phoneNumber: extra['phoneNumber'] ?? '',
          verificationId: extra['verificationId'] ?? '',
        );
      },
    ),
    GoRoute(
      name: Routes().home,
      path: '/${Routes().home}',
      builder: (BuildContext context, GoRouterState state) {
        return const NavigationScreen();
      },
    ),
    GoRoute(
      name: Routes().navigationScreen,
      path: '/${Routes().navigationScreen}',
      builder: (BuildContext context, GoRouterState state) {
        return const NavigationScreen();
      },
    ),

    // Main Routes


  // Main Sub Routes
 GoRoute(
      name: Routes().whereTo,
      path: '/${Routes().whereTo}',
      builder: (BuildContext context, GoRouterState state) {
        return WhereToScreen(controller: state.extra as GoogleMapController);
      },
    ),
    GoRoute(
      name: Routes().bookingSummary,
      path: '/${Routes().bookingSummary}',
      builder: (BuildContext context, GoRouterState state) {
        return BookingSummaryScreen(controller: state.extra as GoogleMapController);
      },
    ),
    GoRoute(
      name: Routes().homeModern,
      path: '/${Routes().homeModern}',
      builder: (BuildContext context, GoRouterState state) {
        return const HomeScreenModern();
      },
    ),
    GoRoute(
      name: Routes().paymentModern,
      path: '/${Routes().paymentModern}',
      builder: (BuildContext context, GoRouterState state) {
        return const PaymentScreenModern();
      },
    ),
    GoRoute(
      name: Routes().pickupModern,
      path: '/${Routes().pickupModern}',
      builder: (BuildContext context, GoRouterState state) {
        return const PickupScreenModern();
      },
    ),
    GoRoute(
      name: Routes().whereToModern,
      path: '/${Routes().whereToModern}',
      builder: (BuildContext context, GoRouterState state) {
        return WhereToScreenModern(initialTrip: state.extra as TripModel?);
      },
    ),
    GoRoute(
      name: Routes().vehicleSelectionModern,
      path: '/${Routes().vehicleSelectionModern}',
      builder: (BuildContext context, GoRouterState state) {
        return VehicleSelectionScreenModern(trip: state.extra as TripModel);
      },
    ),
    GoRoute(
      name: Routes().bookingSummaryModern,
      path: '/${Routes().bookingSummaryModern}',
      builder: (BuildContext context, GoRouterState state) {
        return BookingSummaryScreenModern(trip: state.extra as TripModel?);
      },
    ),
    GoRoute(
      name: Routes().activeTripModern,
      path: '/${Routes().activeTripModern}',
      builder: (BuildContext context, GoRouterState state) {
        return ActiveTripScreenModern(trip: state.extra as TripModel?);
      },
    ),
    GoRoute(
      name: Routes().supportScreen,
      path: '/${Routes().supportScreen}',
      builder: (BuildContext context, GoRouterState state) {
        return Scaffold(
          appBar: AppBar(title: const Text('Help & Support')),
          body: const Center(child: Text('Support content coming soon.')),
        );
      },
    ),
    GoRoute(
      name: Routes().aboutScreen,
      path: '/${Routes().aboutScreen}',
      builder: (BuildContext context, GoRouterState state) {
        return Scaffold(
          appBar: AppBar(title: const Text('About Us')),
          body: const Center(child: Text('About page coming soon.')),
        );
      },
    ),
    GoRoute(
      name: Routes().privacyScreen,
      path: '/${Routes().privacyScreen}',
      builder: (BuildContext context, GoRouterState state) {
        return Scaffold(
          appBar: AppBar(title: const Text('Privacy & Terms')),
          body: const Center(child: Text('Privacy content coming soon.')),
        );
      },
    ),
    GoRoute(
      name: Routes().savedAddresses,
      path: '/${Routes().savedAddresses}',
      builder: (BuildContext context, GoRouterState state) {
        return Scaffold(
          appBar: AppBar(title: const Text('Saved Addresses')),
          body: const Center(child: Text('Saved addresses will appear here.')),
        );
      },
    ),

    // Parcel Delivery Routes
    GoRoute(
      name: Routes().parcel,
      path: '/${Routes().parcel}',
      builder: (BuildContext context, GoRouterState state) {
        return const ParcelScreen();
      },
    ),
    GoRoute(
      name: Routes().parcelConfirm,
      path: '/${Routes().parcelConfirm}',
      builder: (BuildContext context, GoRouterState state) {
        return const ParcelConfirmScreen();
      },
    ),
    GoRoute(
      name: Routes().parcelTracking,
      path: '/${Routes().parcelTracking}',
      builder: (BuildContext context, GoRouterState state) {
        return const ParcelTrackingScreen();
      },
    ),

    // User Profile & Settings Routes
    GoRoute(
      name: Routes().profile,
      path: '/${Routes().profile}',
      builder: (BuildContext context, GoRouterState state) {
        return const ProfileScreen();
      },
    ),
    GoRoute(
      name: Routes().rideHistory,
      path: '/${Routes().rideHistory}',
      builder: (BuildContext context, GoRouterState state) {
        return const HistoryScreen();
      },
    ),
    GoRoute(
      name: Routes().notifications,
      path: '/${Routes().notifications}',
      builder: (BuildContext context, GoRouterState state) {
        return const NotificationsScreen();
      },
    ),
    GoRoute(
      name: Routes().payments,
      path: '/${Routes().payments}',
      builder: (BuildContext context, GoRouterState state) {
        return const PaymentScreen();
      },
    ),
    GoRoute(
      name: Routes().settings,
      path: '/${Routes().settings}',
      builder: (BuildContext context, GoRouterState state) {
        return const SettingsScreen();
      },
    ),

    GoRoute(
      name: Routes().activeTrip,
      path: '/${Routes().activeTrip}',
      builder: (BuildContext context, GoRouterState state) {
        final trip = state.extra as TripModel?;
        return ActiveTripScreen(trip: trip);
      },
    ),
    GoRoute(
      name: Routes().tripCompletion,
      path: '/${Routes().tripCompletion}',
      builder: (BuildContext context, GoRouterState state) {
        final trip = state.extra as TripModel;
        return TripCompletionScreen(trip: trip);
      },
    ),
  ];

