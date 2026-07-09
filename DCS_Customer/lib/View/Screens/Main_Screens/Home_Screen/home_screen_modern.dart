import 'dart:async';
import 'package:flutter/material.dart' hide Text;
import 'package:Dadacabs/View/Widgets/translated_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_map/flutter_map.dart' as flmap;
import 'package:latlong2/latlong.dart' as latlong;
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:Dadacabs/Container/Repositories/firestore_repo.dart';
import 'package:Dadacabs/Container/Providers/user_data_provider.dart';
import 'package:Dadacabs/Container/Providers/vehicle_providers.dart';
import 'package:Dadacabs/Container/Providers/fare_config_providers.dart';
import 'package:Dadacabs/Container/Services/fare_service.dart';
import 'package:Dadacabs/Container/utils/firebase_messaging.dart';
import 'package:Dadacabs/Model/driver_model.dart';
import 'package:Dadacabs/Model/trip_model.dart';
import 'package:Dadacabs/Model/vehicle_type_model.dart';
import 'package:Dadacabs/View/Routes/routes.dart';
import 'package:Dadacabs/View/Screens/Main_Screens/Home_Screen/home_logics.dart';
import 'package:Dadacabs/View/Screens/Main_Screens/Home_Screen/home_providers.dart';
import 'package:Dadacabs/View/Screens/Nav_Screens/navigation_providers.dart';
import 'package:Dadacabs/View/Themes/indian_heritage_theme.dart';
import 'package:Dadacabs/Container/Providers/theme_provider.dart';
// Modified by Jayant Pandit on 2026-07-11 11:00:00
// Reason: Import responsive utilities for auto-adjusted font sizing based on screen width
import 'package:Dadacabs/Container/utils/responsive_utils.dart';

class HomeScreenModern extends ConsumerStatefulWidget {
  const HomeScreenModern({super.key});

  @override
  ConsumerState<HomeScreenModern> createState() => _HomeScreenModernState();
}

class _HomeScreenModernState extends ConsumerState<HomeScreenModern> {
  // Modified by Jayant Pandit on 2026-07-09 14:30:00
  // Reason: Removed Google Maps controller/Completer, keep only OSM. Google Maps code commented out as requested.
  final flmap.MapController _mapController = flmap.MapController();
  TripModel? _pendingTrip;
  bool _showRideOptions = false;
  int _selectedVehicleIndex = 0;

  // Modified by Jayant Pandit on 2026-07-08 10:30:00
  // Reason: Store pending camera target fetched before controller is ready, then apply in onMapCreated
  LatLng? _pendingCameraTarget;

  // Modified by Jayant Pandit on 2026-07-08 18:00:00
  // Reason: Track whether driver stream has been initialized with real location to avoid stale empty state
  bool _driversInitialized = false;

  double _defaultLat = 19.0760;
  double _defaultLng = 72.8777;
  // Modified by Jayant Pandit on 2026-07-08 18:00:00
  // Reason: Store current GPS position to show a blue-dot marker on OSM
  LatLng? _currentGpsPosition;

  // Modified by Jayant Pandit on 2026-07-09 14:30:00
  // Reason: Changed lemonYellow to lemonYellow for backgrounds. Text now uses Colors.black instead.
  static const Color lemonYellow = Color(0xFFFFF176);
  static const Color darkYellow = Color(0xFFFFD600);
  static const Color bikeGreen = Color(0xFF4CAF50);
  static const Color autoOrange = Color(0xFFFF9800);
  static const Color parcelBlue = Color(0xFF2196F3);

  final List<Map<String, dynamic>> _promoBanners = [
    {
      'badge': 'NEW',
      'title': 'Introducing',
      'subtitle': 'Metro tickets',
      'bgColor': const Color(0xFFFFF3E0),
      'icon': Icons.directions_subway_rounded,
      'iconColor': autoOrange,
    },
    {
      'badge': null,
      'title': 'In a hurry?',
      'subtitle': 'Get priority cab',
      'bgColor': const Color(0xFFE8F5E9),
      'icon': Icons.flash_on_rounded,
      'iconColor': bikeGreen,
    },
    {
      'badge': 'OFFER',
      'title': 'First ride',
      'subtitle': '50% off up to ₹80',
      'bgColor': const Color(0xFFE3F2FD),
      'icon': Icons.celebration_rounded,
      'iconColor': parcelBlue,
    },
    {
      'badge': null,
      'title': 'Safe rides',
      'subtitle': 'Track your trip live',
      'bgColor': const Color(0xFFF3E5F5),
      'icon': Icons.shield_rounded,
      'iconColor': const Color(0xFF9C27B0),
    },
    {
      'badge': '₹0',
      'title': 'No cancellation',
      'subtitle': 'Zero penalty fee',
      'bgColor': const Color(0xFFFFFDE7),
      'icon': Icons.money_off_rounded,
      'iconColor': const Color(0xFFFDD835),
    },
    {
      'badge': null,
      'title': 'Group rides',
      'subtitle': 'Share & save more',
      'bgColor': const Color(0xFFFCE4EC),
      'icon': Icons.groups_rounded,
      'iconColor': const Color(0xFFE91E63),
    },
  ];

  // Modified by Jayant Pandit on 2026-07-09 18:00:00
  // Reason: Start driver stream immediately and mark initialized. Previously _driversInitialized
  // was only set after GPS was obtained, which caused the build method to keep calling
  // _forceRefreshDrivers via post-frame callbacks, constantly resetting the stream.
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      MessagingService().init(context, ref);
      _initializeDriverStream();
      _driversInitialized = true;
      _loadInitialLocation();
    });
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  // Modified by Jayant Pandit on 2026-07-08 18:00:00
  // Reason: Use getCurrentPosition with proper permission checks instead of unreliable getLastKnownPosition.
  // Also store _currentGpsPosition for OSM blue-dot marker and call getDriverData with real user location.
  Future<void> _loadInitialLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('HomeScreen: Location services disabled');
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        debugPrint('HomeScreen: Location permission denied');
        return;
      }
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      if (!mounted) return;
      final userLoc = LatLng(pos.latitude, pos.longitude);
      _currentGpsPosition = userLoc;
      _pendingCameraTarget = userLoc;
      _applyPendingCameraTarget();
      // Refresh driver data stream with real user location
      // Note: using userLoc local variable instead of _pendingCameraTarget because
      // _applyPendingCameraTarget nullifies _pendingCameraTarget in OSM mode
      ref.read(globalFirestoreRepoProvider).getDriverData(context, ref, userLoc);
      _driversInitialized = true;
    } catch (e) {
      debugPrint('HomeScreen: Failed to load initial location: $e');
    }
  }

  // Modified by Jayant Pandit on 2026-07-09 14:30:00
  // Reason: Apply pending camera target to OSM map controller only (Google Maps fully removed).
  void _applyPendingCameraTarget() {
    if (_pendingCameraTarget == null || !mounted) return;
    _mapController.move(
      latlong.LatLng(_pendingCameraTarget!.latitude, _pendingCameraTarget!.longitude),
      16,
    );
    _pendingCameraTarget = null;
  }

  void _initializeDriverStream() {
    const fallbackLoc = LatLng(19.0760, 72.8777);
    ref.read(globalFirestoreRepoProvider).getDriverData(context, ref, fallbackLoc);
  }

  // Modified by Jayant Pandit on 2026-07-08 18:00:00
  // Reason: Force re-fetch driver data with current GPS; used when returning from active trip screen or when build detects stale data
  void _forceRefreshDrivers() {
    if (_currentGpsPosition != null) {
      ref.read(globalFirestoreRepoProvider).getDriverData(context, ref, _currentGpsPosition!);
    } else {
      _loadInitialLocation();
    }
  }

  void _onWhereToTap() async {
    final pickUp = ref.read(homeScreenPickUpLocationProvider);
    final trip = TripModel(
      tripId: 'temp-${DateTime.now().millisecondsSinceEpoch}',
      userId: ref.read(userDataProvider)?.uid ?? 'guest',
      pickupAddress: pickUp?.humanReadableAddress ?? 'Current Location',
      pickupLocation: pickUp != null && pickUp.locationLatitude != null && pickUp.locationLongitude != null
          ? LatLng(pickUp.locationLatitude!, pickUp.locationLongitude!)
          : const LatLng(19.0760, 72.8777),
      dropoffAddress: '',
      dropoffLocation: const LatLng(0.0, 0.0),
      createdAt: DateTime.now(),
      estimatedFare: 0.0,
    );
    final result = await context.pushNamed(Routes().whereToModern, extra: trip);
    if (result != null && result is TripModel && mounted) {
      setState(() {
        _pendingTrip = result;
        _showRideOptions = true;
      });
    }
  }

  // Modified by Jayant Pandit on 2026-07-08 10:30:00
  // Reason: Show "Booking for someone else?" dialog before entering pickup flow
  void _onFromTap() {
    _showBookingForDialog();
  }

  // Modified by Jayant Pandit on 2026-07-08 10:30:00
  // Reason: First dialog asking if booking is for someone else — two buttons: Yes / No
  void _showBookingForDialog() {
    final isDark = ref.read(themeModeProvider) == ThemeMode.dark;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.people_alt_outlined, size: 48, color: lemonYellow),
              const SizedBox(height: 16),
              Text(
                'Booking for someone else?',
                style: TextStyle(
                  // Modified by Jayant Pandit on 2026-07-11 11:00:00
                  // Reason: Responsive font size for booking dialog title
                  fontSize: ResponsiveUtils.fontSize(context, 18),
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'You can book a ride for your friends & family',
                style: TextStyle(
                  // Modified by Jayant Pandit on 2026-07-11 11:00:00
                  // Reason: Responsive font size for booking dialog subtitle
                  fontSize: ResponsiveUtils.fontSize(context, 13),
                  color: Colors.grey[500],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _showPassengerSelectionDialog();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: lemonYellow,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Yes, for someone else',
                    style: TextStyle(
                      // Modified by Jayant Pandit on 2026-07-11 11:00:00
                      // Reason: Responsive font size for booking dialog button text
                      fontSize: ResponsiveUtils.fontSize(context, 15),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: () {
                    ref.read(homeScreenBookingPassengerProvider.notifier).state = null;
                    Navigator.of(ctx).pop();
                    _navigateToPickup();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? Colors.white : Colors.black87,
                    side: BorderSide(color: Colors.grey[300]!),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'No, Booking for me',
                    style: TextStyle(
                      // Modified by Jayant Pandit on 2026-07-11 11:00:00
                      // Reason: Responsive font size for booking dialog button text
                      fontSize: ResponsiveUtils.fontSize(context, 15),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Modified by Jayant Pandit on 2026-07-08 10:30:00
  // Reason: Second dialog for selecting passenger — "Myself" or "Add New User" with name/phone fields
  void _showPassengerSelectionDialog() {
    final isDark = ref.read(themeModeProvider) == ThemeMode.dark;
    String passengerType = 'myself';
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Booking ride for',
                  style: TextStyle(
                    // Modified by Jayant Pandit on 2026-07-11 11:00:00
                    // Reason: Responsive font size for passenger selection dialog title
                    fontSize: ResponsiveUtils.fontSize(context, 18),
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                // Myself option
                InkWell(
                  onTap: () => setDialogState(() => passengerType = 'myself'),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: passengerType == 'myself'
                          ? lemonYellow.withOpacity(0.12)
                          : (isDark ? Colors.grey[900] : Colors.grey[100]),
                      borderRadius: BorderRadius.circular(12),
                      border: passengerType == 'myself'
                          ? Border.all(color: lemonYellow, width: 2)
                          : null,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.person_rounded,
                          color: passengerType == 'myself' ? lemonYellow : Colors.grey,
                          size: 28,
                        ),
                        const SizedBox(width: 14),
                        Text(
                          'Myself',
                          style: TextStyle(
                            // Modified by Jayant Pandit on 2026-07-11 11:00:00
                            // Reason: Responsive font size for passenger option text
                            fontSize: ResponsiveUtils.fontSize(context, 16),
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const Spacer(),
                        if (passengerType == 'myself')
                          Icon(Icons.check_circle_rounded, color: lemonYellow, size: 22),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Add New User option
                InkWell(
                  onTap: () => setDialogState(() => passengerType = 'new'),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: passengerType == 'new'
                          ? lemonYellow.withOpacity(0.12)
                          : (isDark ? Colors.grey[900] : Colors.grey[100]),
                      borderRadius: BorderRadius.circular(12),
                      border: passengerType == 'new'
                          ? Border.all(color: lemonYellow, width: 2)
                          : null,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.person_add_alt_1_rounded,
                          color: passengerType == 'new' ? lemonYellow : Colors.grey,
                          size: 28,
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Add New User',
                              style: TextStyle(
                                // Modified by Jayant Pandit on 2026-07-11 11:00:00
                                // Reason: Responsive font size for Add New User text
                                fontSize: ResponsiveUtils.fontSize(context, 16),
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            Text(
                              'Enter name & phone number',
                              style: TextStyle(
                                // Modified by Jayant Pandit on 2026-07-11 11:00:00
                                // Reason: Responsive font size for Add New User subtitle
                                fontSize: ResponsiveUtils.fontSize(context, 12),
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        if (passengerType == 'new')
                          Icon(Icons.check_circle_rounded, color: lemonYellow, size: 22),
                      ],
                    ),
                  ),
                ),
                if (passengerType == 'new') ...[
                  const SizedBox(height: 16),
                  // Modified by Jayant Pandit on 2026-07-08 16:30:00
                  // Reason: Added "Select from Contacts" — uses FlutterContacts.native.showPicker() API
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        try {
                          final contact = await FlutterContacts.native.showPicker(properties: {ContactProperty.name, ContactProperty.phone});
                          if (contact != null) {
                            nameCtrl.text = contact.displayName ?? '';
                            if (contact.phones.isNotEmpty) {
                              phoneCtrl.text = contact.phones.first.number.replaceAll(RegExp(r'\D'), '');
                            }
                            setDialogState(() {});
                          }
                        } catch (e) {
                          debugPrint('Contact picker error: $e');
                        }
                      },
                      icon: const Icon(Icons.contacts_rounded, size: 20),
                      label: const Text('Select from Contacts'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: lemonYellow,
                        side: BorderSide(color: lemonYellow.withOpacity(0.5)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: 'Passenger Name',
                      hintText: 'Enter name',
                      filled: true,
                      fillColor: isDark ? Colors.grey[900] : Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Phone Number',
                      hintText: '10-digit mobile number',
                      filled: true,
                      fillColor: isDark ? Colors.grey[900] : Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      String? passengerInfo;
                      if (passengerType == 'new') {
                        final name = nameCtrl.text.trim();
                        if (name.isEmpty) return;
                        final phone = phoneCtrl.text.trim();
                        passengerInfo = phone.isNotEmpty ? '$name ($phone)' : name;
                      }
                      ref.read(homeScreenBookingPassengerProvider.notifier).state = passengerInfo;
                      Navigator.of(ctx).pop();
                      _navigateToPickup();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: lemonYellow,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      passengerType == 'new' ? 'Done' : 'Continue',
                      style: TextStyle(
                        // Modified by Jayant Pandit on 2026-07-11 11:00:00
                        // Reason: Responsive font size for Done/Continue button text
                        fontSize: ResponsiveUtils.fontSize(context, 16),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToPickup() async {
    await context.pushNamed(Routes().pickupModern);
  }

  void _onServiceTap(String service) {
    if (service == 'parcel') {
      context.pushNamed(Routes().parcel);
      return;
    }
    if (_pendingTrip != null && _pendingTrip!.dropoffLocation.latitude != 0.0) {
      setState(() {
        _showRideOptions = true;
        _selectedVehicleIndex = 0;
      });
    } else {
      _onWhereToTap();
    }
  }

  // Modified by Jayant Pandit on 2026-07-09 18:00:00
  // Reason: Navigate to active trip screen immediately, then do Firestore write + webhook in background.
  // Previously awaited both before navigation, which blocked the UI if Firestore/webhook was slow.
  // Also added null safety for provider reads to prevent crashes.
  // Modified by Jayant Pandit on 2026-07-11 10:00:00
  // Reason: Added robust error handling + Firestore write verification before webhook.
  // Previously fire-and-forget .then() silently dropped errors if Firestore write failed,
  // meaning webhook would fire but trip didn't exist yet → drivers never notified.
  void _requestRide(VehicleTypeModel vehicle) {
    if (_pendingTrip == null || !mounted) return;

    final pickUp = ref.read(homeScreenPickUpLocationProvider);
    final user = ref.read(userDataProvider);
    final bookingPassenger = ref.read(homeScreenBookingPassengerProvider);

    final trip = TripModel(
      tripId: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: user?.uid ?? 'guest',
      userName: bookingPassenger ?? user?.name ?? 'Customer',
      userPhone: user?.phone ?? '',
      pickupLocation: pickUp != null && pickUp.locationLatitude != null && pickUp.locationLongitude != null
          ? LatLng(pickUp.locationLatitude!, pickUp.locationLongitude!)
          : _pendingTrip!.pickupLocation,
      pickupAddress: pickUp?.humanReadableAddress ?? _pendingTrip!.pickupAddress,
      dropoffLocation: _pendingTrip!.dropoffLocation,
      dropoffAddress: _pendingTrip!.dropoffAddress,
      createdAt: DateTime.now(),
      estimatedFare: _calculateFare(vehicle, _pendingTrip!.distanceKm ?? 0.0, _pendingTrip!.durationMinutes ?? 0),
      carType: vehicle.name,
      carName: vehicle.name,
      distanceKm: _pendingTrip!.distanceKm,
      durationMinutes: _pendingTrip!.durationMinutes,
      status: TripStatus.pending,
    );

    // Navigate immediately for responsive UI
    if (mounted) {
      context.pushNamed(Routes().activeTripModern, extra: trip);
    }
    // Modified by Jayant Pandit on 2026-07-11 10:00:00
    // Reason: Sequentially await Firestore write, then delay 1s for propagation, then webhook.
    // This prevents the race condition where webhook fires before Firestore document is visible.
    _performRideRequestFirestoreWriteAndNotify(trip);
  }

  // Modified by Jayant Pandit on 2026-07-11 10:00:00
  // Reason: Extracted ride request logic into separate async method for proper error handling.
  // Sequentially: (1) Firestore write, (2) 1s propagation delay, (3) webhook with 3 retries.
  Future<void> _performRideRequestFirestoreWriteAndNotify(TripModel trip) async {
    try {
      debugPrint("RIDE_REQUEST: Writing trip ${trip.tripId} to Firestore...");
      await ref.read(globalFirestoreRepoProvider).addUserRideRequestToDB(
        context, ref, null, trip,
      );
      debugPrint("RIDE_REQUEST: Firestore write complete for ${trip.tripId}");

      // Modified by Jayant Pandit on 2026-07-11 10:00:00
      // Reason: Allow 1 second for Firestore document to propagate before webhook fetches it.
      // Without this delay, the webhook notification server may query Firestore before the
      // document is visible, resulting in 404 and no driver notification.
      await Future.delayed(const Duration(seconds: 1));

      debugPrint("RIDE_REQUEST: Notifying drivers via webhook for ${trip.tripId}");
      await HomeScreenLogics.notifyDriversViaWebhook(trip.tripId);
      debugPrint("RIDE_REQUEST: Webhook notification complete for ${trip.tripId}");
    } catch (e) {
      debugPrint("RIDE_REQUEST: ERROR for trip ${trip.tripId}: $e");
    }
  }

  // Modified by Jayant Pandit on 2026-07-08 10:30:00
  // Reason: Use same online-availability filter as the displayed vehicle list so the selected name matches the filtered index
  String _selectedVehicleName() {
    final vehicleTypes = ref.read(vehicleTypesStreamProvider).value ?? VehicleTypeModel.defaults;
    final availableDrivers = ref.read(homeScreenAvailableDriversProvider);
    final active = vehicleTypes.where((v) => v.isActive).toList();
    final baseDisplay = active.isNotEmpty ? active : VehicleTypeModel.defaults;
    final available = baseDisplay.where((v) => _getOnlineCount(v.name, availableDrivers) > 0).toList();
    final display = available.isNotEmpty ? available : baseDisplay;
    if (display.isEmpty) return 'Ride';
    final idx = _selectedVehicleIndex < display.length ? _selectedVehicleIndex : 0;
    return display[idx].name;
  }

  double _calculateFare(VehicleTypeModel vehicle, double distanceKm, int durationMinutes) {
    final fareConfigs = ref.read(fareConfigsStreamProvider).value ?? [];
    final currentZone = ref.read(currentZoneNameProvider);
    final surgeRules = ref.read(surgeRulesStreamProvider).value ?? [];
    final vehicleTypes = ref.read(vehicleTypesStreamProvider).value ?? VehicleTypeModel.defaults;
    return FareService.calculateFare(
      zoneName: currentZone,
      vehicleType: vehicle.name,
      distanceKm: distanceKm,
      durationMinutes: durationMinutes.toDouble(),
      fareConfigs: fareConfigs,
      vehicleTypes: vehicleTypes,
      surgeRules: surgeRules,
    );
  }

  // Modified by Jayant Pandit on 2026-07-08 18:00:00
  // Reason: Return appropriate Material icon for OSM driver marker based on carType
  IconData _osmVehicleIcon(String carType) {
    final ct = carType.toLowerCase();
    if (ct.contains('bike') || ct.contains('moto') || ct.contains('scooter')) return Icons.motorcycle_rounded;
    if (ct.contains('auto') || ct.contains('rickshaw') || ct.contains('three')) return Icons.electric_rickshaw_rounded;
    if (ct.contains('suv') || ct.contains('xl') || ct.contains('van')) return Icons.airport_shuttle_rounded;
    if (ct.contains('truck') || ct.contains('parcel') || ct.contains('dost')) return Icons.local_shipping_rounded;
    if (ct.contains('sedan') || ct.contains('hatchback') || ct.contains('premium') || ct.contains('luxury')) return Icons.directions_car_rounded;
    return Icons.local_taxi_rounded;
  }

  // Modified by Jayant Pandit on 2026-07-08 18:00:00
  // Reason: Return color for OSM vehicle marker based on carType (matches MarkerIcons._colorForType)
  Color _vehicleColor(String carType) {
    final ct = carType.toLowerCase();
    if (ct.contains('bike') || ct.contains('moto') || ct.contains('scooter')) return Colors.green;
    if (ct.contains('auto') || ct.contains('rickshaw') || ct.contains('three')) return Colors.orange;
    if (ct.contains('suv') || ct.contains('xl') || ct.contains('premium')) return Colors.purple;
    if (ct.contains('van') || ct.contains('truck') || ct.contains('parcel') || ct.contains('dost')) return Colors.cyan;
    if (ct.contains('intercity') || ct.contains('tour')) return Colors.blue;
    if (ct.contains('sedan') || ct.contains('hatchback')) return Colors.indigo;
    return Colors.green;
  }

  // Modified by Jayant Pandit on 2026-07-08 10:30:00
  // Reason: Enhanced matching for all vehicle types including compound names like "Auto Rickshaw", "Luxury Car", "Hatchback", "Small Truck" by aligning Firestore vehicleType names with driver carType field values
  int _getOnlineCount(String vehicleType, List<DriverModel> drivers) {
    return drivers.where((d) {
      final vt = vehicleType.toLowerCase().trim();
      final dt = d.carType.toLowerCase().trim();
      if (vt.contains('bike')) return dt.contains('bike') || dt.contains('moto') || dt.contains('motorcycle');
      if (vt.contains('auto') || vt.contains('rickshaw')) return dt.contains('auto') || dt.contains('rickshaw');
      if (vt.contains('van') || vt.contains('truck') || vt.contains('parcel')) return dt.contains('van') || dt.contains('truck') || dt.contains('parcel');
      if (vt.contains('sedan') || vt.contains('economy')) return dt.contains('sedan') || dt.contains('economy') || dt.contains('car');
      if (vt.contains('premium') || vt.contains('luxury')) return dt.contains('premium') || dt.contains('luxury');
      if (vt.contains('suv') || vt.contains('xl')) return dt.contains('suv') || dt.contains('xl');
      if (vt.contains('hatchback')) return dt.contains('hatchback');
      return dt.contains(vt);
    }).length;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final availableDrivers = ref.watch(homeScreenAvailableDriversProvider);

    // Modified by Jayant Pandit on 2026-07-09 18:00:00
    // Reason: Removed post-frame callback from build method. _driversInitialized is now always set
    // in initState, so this callback would never fire. The driver stream persists across rebuilds.
    return SizedBox.expand(
      child: Stack(
        children: [
          // Modified by Jayant Pandit on 2026-07-09 14:30:00
          // Reason: Removed Google Maps. Only OpenStreetMap (FlutterMap) used. Google Maps code commented out.
          flmap.FlutterMap(
            mapController: _mapController,
            options: flmap.MapOptions(
              center: latlong.LatLng(
                _pendingCameraTarget?.latitude ?? _defaultLat,
                _pendingCameraTarget?.longitude ?? _defaultLng,
              ),
              zoom: 16,
              onTap: (tapPos, point) {
                ref.read(homeScreenCameraMovementProvider.notifier).state = LatLng(point.latitude, point.longitude);
                HomeScreenLogics().getAddressfromCordinates(context, ref);
              },
            ),
            children: [
              flmap.TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'dev.hyderali.DCS_user',
              ),
              // Modified by Jayant Pandit on 2026-07-08 18:00:00
              // Reason: Show current GPS position as a blue dot marker on OSM when location is available
              if (_currentGpsPosition != null)
                flmap.MarkerLayer(markers: [
                  flmap.Marker(
                    point: latlong.LatLng(_currentGpsPosition!.latitude, _currentGpsPosition!.longitude),
                    builder: (_) => Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                        color: Color(0xFF4285F4),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ),
                ]),
              // Modified by Jayant Pandit on 2026-07-08 18:00:00
              // Reason: Show vehicle-type-specific icons on OSM map using driverModel positions
              if (availableDrivers.isNotEmpty)
                flmap.MarkerLayer(markers: availableDrivers.map((d) {
                  final icon = _osmVehicleIcon(d.carType);
                  return flmap.Marker(
                    point: latlong.LatLng(d.driverLoc.latitude, d.driverLoc.longitude),
                    builder: (_) => Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: _vehicleColor(d.carType),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 4)],
                      ),
                      child: Icon(icon, color: Colors.white, size: 20),
                    ),
                  );
                }).toList()),
            ],
          ),

          // ── Center Pickup Pin ─────────────────────────────────────
          if (ref.watch(homeScreenDropOffLocationProvider) == null && !_showRideOptions)
            Align(
              alignment: Alignment.center,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 35),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: lemonYellow,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        "PICKUP HERE",
                        style: TextStyle(color: Colors.black87, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const Icon(Icons.location_on_rounded, size: 45, color: lemonYellow),
                  ],
                ),
              ),
            ),

          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
            child: Row(
              children: [
                _topButton(
                  icon: Icons.menu_rounded,
                  isDark: isDark,
                  onTap: () {
                    ref.read(navigationScaffoldKeyProvider).currentState?.openDrawer();
                  },
                ),
                const Spacer(),
                _topButton(
                  icon: Icons.shield_rounded,
                  isDark: isDark,
                  onTap: null,
                ),
                const SizedBox(width: 8),
                _topButton(
                  icon: Icons.notifications_outlined,
                  isDark: isDark,
                  onTap: () {
                    context.pushNamed(Routes().notifications);
                  },
                ),
              ],
            ),
          ),

          // Modified by Jayant Pandit on 2026-07-09 14:30:00
          // Reason: Removed map toggle (Google Maps removed). Only OSM my-location FAB remains.
          Positioned(
            right: 16,
            bottom: _showRideOptions ? size.height * 0.52 : size.height * 0.62,
            child: FloatingActionButton.small(
              heroTag: 'my_location',
              onPressed: () async {
                try {
                  final pos = await Geolocator.getCurrentPosition();
                  _currentGpsPosition = LatLng(pos.latitude, pos.longitude);
                  _mapController.move(
                    latlong.LatLng(pos.latitude, pos.longitude),
                    16,
                  );
                } catch (_) {}
              },
              backgroundColor: Colors.white,
              elevation: 4,
              child: Icon(Icons.my_location_rounded, color: Colors.black, size: 22),
            ),
          ),

          if (_showRideOptions && _pendingTrip != null)
            _buildRideOptionsSheet(size, isDark, availableDrivers),

          if (!_showRideOptions)
            _buildBottomPanel(size, isDark, availableDrivers),
        ],
      ),
    );
  }

  Widget _topButton({
    required IconData icon,
    required bool isDark,
    VoidCallback? onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: isDark ? Colors.white : Colors.black87, size: 22),
        onPressed: onTap,
      ),
    );
  }

  Widget _buildBottomPanel(Size size, bool isDark, List<DriverModel> availableDrivers) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        height: size.height * 0.35,
        decoration: BoxDecoration(
          color: isDark ? IndianHeritageColors.darkSurface : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Location Input Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[900] : const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      // Modified by Jayant Pandit on 2026-07-08 10:30:00
                      // Reason: Show "Booking for someone else?" dialog before navigating to pickup screen — matching Rapido-style flow
                      // Pickup Field
                      InkWell(
                        onTap: () => _onFromTap(),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.circle, size: 14, color: Colors.green),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'FROM',
                                    style: TextStyle(
                                      // Modified by Jayant Pandit on 2026-07-11 11:00:00
                                      // Reason: Responsive font size for FROM label
                                      fontSize: ResponsiveUtils.fontSize(context, 10),
                                      fontWeight: FontWeight.w800,
                                      color: Colors.grey[500],
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    ref.watch(homeScreenPickUpLocationProvider)?.humanReadableAddress ?? 'Current Location',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      // Modified by Jayant Pandit on 2026-07-11 11:00:00
                                      // Reason: Responsive font size for pickup address text
                                      fontSize: ResponsiveUtils.fontSize(context, 15),
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.grey[400] : Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey[400]),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 36),
                        child: Divider(height: 32, thickness: 1, color: isDark ? Colors.grey[800] : Colors.grey[300]),
                      ),
                      // Drop-off Field
                      InkWell(
                        onTap: _onWhereToTap,
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: lemonYellow.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.square_rounded, size: 14, color: lemonYellow),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'WHERE TO?',
                                    style: TextStyle(
                                      // Modified by Jayant Pandit on 2026-07-11 11:00:00
                                      // Reason: Responsive font size for WHERE TO label
                                      fontSize: ResponsiveUtils.fontSize(context, 10),
                                      fontWeight: FontWeight.w800,
                                      color: Colors.grey[500],
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _pendingTrip?.dropoffAddress.isNotEmpty == true
                                        ? _pendingTrip!.dropoffAddress
                                        : 'Enter destination',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      // Modified by Jayant Pandit on 2026-07-11 11:00:00
                                      // Reason: Responsive font size for destination text
                                      fontSize: ResponsiveUtils.fontSize(context, 15),
                                      fontWeight: FontWeight.w900,
                                      color: isDark ? Colors.white : Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.search_rounded, size: 20, color: lemonYellow),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // "Everything in minutes" section — Promotional banner carousel
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Everything in minutes',
                      style: TextStyle(
                        // Modified by Jayant Pandit on 2026-07-11 11:00:00
                        // Reason: Responsive font size for section title
                        fontSize: ResponsiveUtils.fontSize(context, 18),
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    TextButton(
                      onPressed: () {},
                      child: Text(
                        'View All',
                        style: TextStyle(
                          // Modified by Jayant Pandit on 2026-07-11 11:00:00
                          // Reason: Responsive font size for View All link
                          fontSize: ResponsiveUtils.fontSize(context, 13),
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Promotional banner carousel
              SizedBox(
                height: 130,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _promoBanners.length,
                  itemBuilder: (context, index) {
                    final b = _promoBanners[index];
                    return SizedBox(
                      width: 170,
                      child: Padding(
                        padding: EdgeInsets.only(right: index < _promoBanners.length - 1 ? 12 : 0),
                        child: _buildPromoCard(
                          badge: b['badge'],
                          title: b['title'],
                          subtitle: b['subtitle'],
                          bgColor: b['bgColor'],
                          icon: b['icon'],
                          iconColor: b['iconColor'],
                          isDark: isDark,
                          onTap: () {},
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 20),

              // Service icons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    _buildServiceIcon(
                      icon: Icons.inventory_2_rounded,
                      label: 'Parcel',
                      color: parcelBlue,
                      isDark: isDark,
                      onTap: () => _onServiceTap('parcel'),
                    ),
                    const SizedBox(width: 20),
                    _buildServiceIcon(
                      icon: Icons.more_horiz_rounded,
                      label: 'More',
                      color: Colors.grey,
                      isDark: isDark,
                      onTap: () {},
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // "In a hurry?" CTA section
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFD600), Color(0xFFFFC107)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'In a hurry?',
                            style: TextStyle(
                              // Modified by Jayant Pandit on 2026-07-11 11:00:00
                              // Reason: Responsive font size for CTA title
                              fontSize: ResponsiveUtils.fontSize(context, 16),
                              fontWeight: FontWeight.w800,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'An auto will arrive in 5 mins.',
                            style: TextStyle(
                              // Modified by Jayant Pandit on 2026-07-11 11:00:00
                              // Reason: Responsive font size for CTA subtitle
                              fontSize: ResponsiveUtils.fontSize(context, 13),
                              fontWeight: FontWeight.w500,
                              color: Colors.black87.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        _onServiceTap('auto');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      child: Text(
                        'Book Now',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          // Modified by Jayant Pandit on 2026-07-11 11:00:00
                          // Reason: Responsive font size for Book Now button text
                          fontSize: ResponsiveUtils.fontSize(context, 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPromoCard({
    String? badge,
    required String title,
    required String subtitle,
    required Color bgColor,
    required IconData icon,
    required Color iconColor,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[900] : bgColor,
          borderRadius: BorderRadius.circular(16),
          border: isDark
              ? Border.all(color: Colors.grey[800]!, width: 1)
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (badge != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            if (badge != null) const SizedBox(height: 8),
            Icon(icon, color: iconColor, size: 28),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                // Modified by Jayant Pandit on 2026-07-11 11:00:00
                // Reason: Responsive font size for promo card title
                fontSize: ResponsiveUtils.fontSize(context, 13),
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                // Modified by Jayant Pandit on 2026-07-11 11:00:00
                // Reason: Responsive font size for promo card subtitle
                fontSize: ResponsiveUtils.fontSize(context, 14),
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceIcon({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[900] : color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              // Modified by Jayant Pandit on 2026-07-11 11:00:00
              // Reason: Responsive font size for service icon label
              fontSize: ResponsiveUtils.fontSize(context, 12),
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRideOptionsSheet(Size size, bool isDark, List<DriverModel> availableDrivers) {
    final vehicleTypesAsync = ref.watch(vehicleTypesStreamProvider);
    final distanceKm = _pendingTrip!.distanceKm ?? 0.0;
    final durationMinutes = _pendingTrip!.durationMinutes ?? 0;
    final pickUp = ref.watch(homeScreenPickUpLocationProvider);
    final pickupAddr = pickUp?.humanReadableAddress ?? _pendingTrip!.pickupAddress;

    final now = DateTime.now();
    final dropTime = now.add(Duration(minutes: durationMinutes));

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        height: size.height * 0.52,
        decoration: BoxDecoration(
          color: isDark ? IndianHeritageColors.darkSurface : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 24,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Location header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pickupAddr,
                          style: TextStyle(
                            // Modified by Jayant Pandit on 2026-07-11 11:00:00
                            // Reason: Responsive font size for pickup address in ride options header
                            fontSize: ResponsiveUtils.fontSize(context, 15),
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.arrow_forward_ios_rounded, size: 10, color: Colors.grey[400]),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                _pendingTrip!.dropoffAddress,
                                style: TextStyle(
                                  // Modified by Jayant Pandit on 2026-07-11 11:00:00
                                  // Reason: Responsive font size for dropoff address in ride options header
                                  fontSize: ResponsiveUtils.fontSize(context, 12),
                                  color: Colors.grey[500],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (distanceKm > 0)
                    Text(
                      '${distanceKm.toStringAsFixed(1)} km',
                      style: TextStyle(
                        // Modified by Jayant Pandit on 2026-07-11 11:00:00
                        // Reason: Responsive font size for distance in ride options header
                        fontSize: ResponsiveUtils.fontSize(context, 14),
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                ],
              ),
            ),
            // Add stop
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: InkWell(
                onTap: () {},
                child: Row(
                  children: [
                    Icon(Icons.add_circle_outline, size: 18, color: lemonYellow),
                    const SizedBox(width: 8),
                    Text(
                      'Add stop',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: lemonYellow,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            // Vehicle list
            Expanded(
              // Modified by Jayant Pandit on 2026-07-08 10:30:00
              // Reason: Filter vehicle list to only show types with online/available drivers. Show message when no driver is available.
              child: vehicleTypesAsync.when(
                data: (vehicleTypes) {
                  final activeVehicles = vehicleTypes.where((v) => v.isActive).toList();
                  final baseVehicles = activeVehicles.isNotEmpty ? activeVehicles : VehicleTypeModel.defaults;
                  final availableVehicles = baseVehicles.where((v) => _getOnlineCount(v.name, availableDrivers) > 0).toList();
                  final displayVehicles = availableVehicles.isNotEmpty ? availableVehicles : baseVehicles;
                  if (displayVehicles.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'No drivers available nearby. Please try again later.',
                          style: TextStyle(
                            // Modified by Jayant Pandit on 2026-07-11 11:00:00
                            // Reason: Responsive font size for no-drivers message
                            fontSize: ResponsiveUtils.fontSize(context, 14),
                            color: Colors.grey[500],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: displayVehicles.length,
                    itemBuilder: (context, index) {
                      final vehicle = displayVehicles[index];
                      final fare = _calculateFare(vehicle, distanceKm, durationMinutes);
                      final onlineCount = _getOnlineCount(vehicle.name, availableDrivers);
                      final isSelected = index == _selectedVehicleIndex;
                      return _buildVehicleOption(vehicle, fare, onlineCount, isSelected, isDark, onTap: () {
                        setState(() => _selectedVehicleIndex = index);
                      });
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) {
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: VehicleTypeModel.defaults.length,
                    itemBuilder: (context, index) {
                      final vehicle = VehicleTypeModel.defaults[index];
                      final fare = _calculateFare(vehicle, distanceKm, durationMinutes);
                      final onlineCount = _getOnlineCount(vehicle.name, availableDrivers);
                      final isSelected = index == _selectedVehicleIndex;
                      return _buildVehicleOption(vehicle, fare, onlineCount, isSelected, isDark, onTap: () {
                        setState(() => _selectedVehicleIndex = index);
                      });
                    },
                  );
                },
              ),
            ),
            // Bottom bar: Cash + Offers + Book button
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              decoration: BoxDecoration(
                color: isDark ? IndianHeritageColors.darkSurface : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Payment + Offers row
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () {},
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.grey[900] : Colors.grey[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.money_rounded, size: 16, color: Colors.green),
                                const SizedBox(width: 6),
                                Text('Cash', style: TextStyle(
                                  // Modified by Jayant Pandit on 2026-07-11 11:00:00
                                  // Reason: Responsive font size for payment method text
                                  fontSize: ResponsiveUtils.fontSize(context, 13),
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : Colors.black87,
                                )),
                                const Spacer(),
                                Icon(Icons.chevron_right, size: 16, color: Colors.grey[400]),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: InkWell(
                          onTap: () {},
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.grey[900] : Colors.grey[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.local_offer_rounded, size: 16, color: Colors.redAccent),
                                const SizedBox(width: 6),
                                Text('Offers', style: TextStyle(
                                  // Modified by Jayant Pandit on 2026-07-11 11:00:00
                                  // Reason: Responsive font size for Offers text
                                  fontSize: ResponsiveUtils.fontSize(context, 13),
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : Colors.black87,
                                )),
                                const Spacer(),
                                Icon(Icons.chevron_right, size: 16, color: Colors.grey[400]),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Book button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      // Modified by Jayant Pandit on 2026-07-08 10:30:00
                      // Reason: Use same filtered list (by online driver availability) as the displayed list to keep index in sync
                      onPressed: () {
                        final vehicleTypes = vehicleTypesAsync.value ?? VehicleTypeModel.defaults;
                        final activeVehicles = vehicleTypes.where((v) => v.isActive).toList();
                        final baseVehicles = activeVehicles.isNotEmpty ? activeVehicles : VehicleTypeModel.defaults;
                        final availableVehicles = baseVehicles.where((v) => _getOnlineCount(v.name, availableDrivers) > 0).toList();
                        final display = availableVehicles.isNotEmpty ? availableVehicles : baseVehicles;
                        if (display.isNotEmpty) {
                          final idx = _selectedVehicleIndex < display.length ? _selectedVehicleIndex : 0;
                          _requestRide(display[idx]);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: lemonYellow,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 8,
                        shadowColor: lemonYellow.withOpacity(0.4),
                      ),
                      child: Text(
                        'Book ${_selectedVehicleName()}',
                        style: TextStyle(
                          // Modified by Jayant Pandit on 2026-07-11 11:00:00
                          // Reason: Responsive font size for Book button text
                          fontSize: ResponsiveUtils.fontSize(context, 16),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleOption(
    VehicleTypeModel vehicle,
    double fare,
    int onlineCount,
    bool isSelected,
    bool isDark, {
    VoidCallback? onTap,
  }) {
    IconData fallbackIcon;
    String subtitle = '';
    if (vehicle.name.toLowerCase().contains('bike') || vehicle.name.toLowerCase().contains('moto')) {
      fallbackIcon = Icons.motorcycle_rounded;
      subtitle = 'Fast & affordable';
    } else if (vehicle.name.toLowerCase().contains('auto') || vehicle.name.toLowerCase().contains('rickshaw')) {
      fallbackIcon = Icons.electric_rickshaw_rounded;
      subtitle = 'Hassle-free Auto rides';
    } else if (vehicle.name.toLowerCase().contains('suv') || vehicle.name.toLowerCase().contains('xl')) {
      fallbackIcon = Icons.airport_shuttle_rounded;
      subtitle = 'Spacious & comfortable';
    } else if (vehicle.name.toLowerCase().contains('van') || vehicle.name.toLowerCase().contains('truck')) {
      fallbackIcon = Icons.local_shipping_rounded;
      subtitle = 'For large loads';
    } else {
      fallbackIcon = Icons.local_taxi_rounded;
      subtitle = 'Affordable everyday rides';
    }

    // Modified by Jayant Pandit on 2026-07-09 18:00:00
    // Reason: Use fullImageUrl getter that prepends Firebase Hosting base URL to relative paths
    final hasImage = vehicle.fullImageUrl != null && vehicle.fullImageUrl!.isNotEmpty;
    final durationMinutes = _pendingTrip?.durationMinutes ?? 0;
    final now = DateTime.now();
    final dropTime = now.add(Duration(minutes: durationMinutes));
    final dropTimeStr = 'Drop ${dropTime.hour.toString().padLeft(2, '0')}:${dropTime.minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? Colors.grey[800] : lemonYellow.withOpacity(0.12))
                : (isDark ? Colors.grey[900] : Colors.grey[100]),
            borderRadius: BorderRadius.circular(14),
            border: isSelected
                ? Border.all(color: lemonYellow, width: 2)
                : null,
          ),
          child: Row(
            children: [
              // Vehicle image/icon
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: lemonYellow.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: hasImage
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        // Modified by Jayant Pandit on 2026-07-09 18:00:00
                        // Reason: Added errorBuilder to fall back to icon if image URL is invalid/broken.
                        child: Image.network(
                          vehicle.fullImageUrl!,
                          width: 52,
                          height: 52,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(fallbackIcon, color: Colors.black54, size: 28),
                          loadingBuilder: (_, child, progress) {
                            if (progress == null) return child;
                            return const SizedBox(
                              width: 52, height: 52,
                              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                            );
                          },
                        ),
                      )
                    : Icon(fallbackIcon, color: Colors.black54, size: 28),
              ),
              const SizedBox(width: 12),
              // Vehicle details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          vehicle.name,
                          style: TextStyle(
                            // Modified by Jayant Pandit on 2026-07-11 11:00:00
                            // Reason: Responsive font size for vehicle name in ride options
                            fontSize: ResponsiveUtils.fontSize(context, 15),
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        if (isSelected) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Selected',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '₹${fare.toStringAsFixed(0)}',
                          style: TextStyle(
                            // Modified by Jayant Pandit on 2026-07-11 11:00:00
                            // Reason: Responsive font size for fare price in vehicle option
                            fontSize: ResponsiveUtils.fontSize(context, 16),
                            fontWeight: FontWeight.w800,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.access_time_rounded, size: 12, color: Colors.grey[500]),
                        const SizedBox(width: 3),
                        Text(
                          '${durationMinutes} mins',
                          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.location_on_rounded, size: 12, color: Colors.grey[500]),
                        const SizedBox(width: 3),
                        Text(
                          dropTimeStr,
                          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Online count or check
              if (isSelected)
                Icon(Icons.check_circle_rounded, color: lemonYellow, size: 22)
              else if (onlineCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$onlineCount',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.green),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

}
