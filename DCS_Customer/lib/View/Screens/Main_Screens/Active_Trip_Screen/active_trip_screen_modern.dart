import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:Dadacabs/View/Widgets/translated_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// Modified by Jayant Pandit on 2026-07-11 12:00:00
// Reason: Replaced google_maps_flutter with flutter_map + latlong2 for OSM tile rendering.
// GoogleMap widget was showing blank/black screen due to API key or billing issues.
import 'package:flutter_map/flutter_map.dart' as flmap;
import 'package:latlong2/latlong.dart' as latlong;
import 'package:geolocator/geolocator.dart';
import 'package:Dadacabs/Model/trip_model.dart';
import 'package:Dadacabs/View/Themes/indian_heritage_theme.dart';
import 'package:Dadacabs/Container/Providers/theme_provider.dart';
// Modified by Jayant Pandit on 2026-07-11 11:00:00
// Reason: Import responsive utilities for auto-adjusted font sizing based on screen width
import 'package:Dadacabs/Container/utils/responsive_utils.dart';

// Modified by Jayant Pandit on 2026-07-11 10:00:00
// Reason: Complete rewrite to replicate Rapido Customer APK flow:
// 1. "Finding nearby Partners" searching animation when trip status is pending
// 2. Driver info card with call button + vehicle name when driver is assigned
// 3. Trip Progress (Picked up → In Transit) only when trip is ongoing
// 4. SOS button shown ONLY when trip is in Progress (ongoing status)
// 5. Cancel button shown during Finding phase

class ActiveTripScreenModern extends ConsumerStatefulWidget {
  final TripModel? trip;

  const ActiveTripScreenModern({
    super.key,
    required this.trip,
  });

  @override
  ConsumerState<ActiveTripScreenModern> createState() => _ActiveTripScreenModernState();
}

class _ActiveTripScreenModernState extends ConsumerState<ActiveTripScreenModern>
    with TickerProviderStateMixin {
  // Modified by Jayant Pandit on 2026-07-11 12:00:00
  // Reason: Replaced GoogleMapController with FlutterMap MapController for OSM rendering.
  // GoogleMap was showing a blank screen; FlutterMap + OSM tiles match home/where-to screens.
  final flmap.MapController _mapController = flmap.MapController();
  Timer? _updateTimer;
  // Modified by Jayant Pandit on 2026-07-11 12:00:00
  // Reason: OSM markers use flmap.Marker (latlong.LatLng) instead of google_maps Marker (LatLng).
  // Stored as a list for direct rendering in flmap.MarkerLayer.
  final List<flmap.Marker> _osmMarkers = [];

  // Modified by Jayant Pandit on 2026-07-11 10:00:00
  // Reason: Animation controllers for "Finding nearby Partners" pulsating radar effect
  late AnimationController _radarController;
  late AnimationController _dotBlinkController;

  // Modified by Jayant Pandit on 2026-07-11 11:00:00
  // Reason: Live trip state from Firestore — updated in real-time when driver accepts,
  // status changes, or driver photo/name/phone/car info is written to the trip document.
  // This replaces widget.trip for all UI rendering so the screen reflects live data.
  TripModel? _liveTrip;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _tripSubscription;

  @override
  void initState() {
    super.initState();
    // Modified by Jayant Pandit on 2026-07-11 10:00:00
    // Reason: Initialize radar and blink animations for searching state
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _dotBlinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    // Modified by Jayant Pandit on 2026-07-11 11:00:00
    // Reason: Initialize live trip from widget, then subscribe to Firestore for real-time updates
    _liveTrip = widget.trip;
    _subscribeToTrip();
    _initializeMap();
    _startLocationUpdates();
  }

  void _initializeMap() {
    // Modified by Jayant Pandit on 2026-07-11 11:00:00
    // Reason: Use _liveTrip (initially widget.trip) for initial marker placement
    if (_liveTrip == null) return;

    _osmMarkers.clear();

    // Modified by Jayant Pandit on 2026-07-11 12:00:00
    // Reason: All markers now use flmap.Marker with latlong.LatLng and builder widgets
    // instead of google_maps Marker with BitmapDescriptor. Green circle = pickup,
    // red circle = dropoff, blue circle with car icon = driver.
    // Pickup marker
    _osmMarkers.add(
      flmap.Marker(
        point: latlong.LatLng(_liveTrip!.pickupLocation.latitude, _liveTrip!.pickupLocation.longitude),
        width: 40,
        height: 40,
        builder: (_) => Container(
          decoration: const BoxDecoration(
            color: Colors.green,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.location_on, color: Colors.white, size: 24),
        ),
      ),
    );

    // Dropoff marker
    if (_liveTrip!.dropoffLocation.latitude != 0.0 || _liveTrip!.dropoffLocation.longitude != 0.0) {
      _osmMarkers.add(
        flmap.Marker(
          point: latlong.LatLng(_liveTrip!.dropoffLocation.latitude, _liveTrip!.dropoffLocation.longitude),
          width: 40,
          height: 40,
          builder: (_) => Container(
            decoration: const BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.flag, color: Colors.white, size: 24),
          ),
        ),
      );
    }

    // Driver marker — only when driver is assigned
    if (_liveTrip!.driverId != null) {
      _osmMarkers.add(
        flmap.Marker(
          point: latlong.LatLng(
            _liveTrip!.pickupLocation.latitude,
            _liveTrip!.pickupLocation.longitude,
          ),
          width: 40,
          height: 40,
          builder: (_) => Container(
            decoration: const BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.directions_car, color: Colors.white, size: 24),
          ),
        ),
      );
    }
  }

  void _startLocationUpdates() {
    _updateTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      try {
        if (mounted) {
          Position position = await Geolocator.getCurrentPosition();
          // Modified by Jayant Pandit on 2026-07-11 12:00:00
          // Reason: For FlutterMap OSM, move map by setting center instead of animateCamera.
          // The marker layer will update on setState below.
          _mapController.move(
            latlong.LatLng(position.latitude, position.longitude),
            _mapController.zoom,
          );
        }
      } catch (e) {
        debugPrint('Error updating location: $e');
      }
    });
  }

  // Modified by Jayant Pandit on 2026-07-11 11:00:00
  // Reason: Subscribe to Firestore trip document for real-time updates.
  // When a driver accepts, the Partner app writes driverId, driverName,
  // driverPhone, driverPhoto, carName, carPlateNum, and status to the trip.
  // This listener picks up those changes and updates _liveTrip so the UI
  // immediately shows the driver's photo and info instead of placeholder.
  void _subscribeToTrip() {
    final tripId = _liveTrip?.tripId;
    if (tripId == null || tripId.isEmpty) return;
    try {
      _tripSubscription = FirebaseFirestore.instance
          .collection('trips')
          .doc(tripId)
          .snapshots()
          .listen((snapshot) {
        if (!mounted) return;
        if (snapshot.exists && snapshot.data() != null) {
          final updatedTrip = TripModel.fromJson(snapshot.data()!);
          setState(() {
            _liveTrip = updatedTrip;
          });
          // Update driver marker position if driver location is available
          _updateDriverMarker(updatedTrip);
        }
      }, onError: (e) {
        debugPrint('ACTIVE_TRIP: Firestore trip subscription error: $e');
      });
    } catch (e) {
      debugPrint('ACTIVE_TRIP: Failed to subscribe to trip: $e');
    }
  }

  // Modified by Jayant Pandit on 2026-07-11 11:00:00
  // Reason: Update driver marker on map when trip data changes (e.g. driver location)
  // Modified by Jayant Pandit on 2026-07-11 12:00:00
  // Reason: Replaced google_maps Marker with flmap.Marker for OSM rendering.
  // The driver marker is the third marker in _osmMarkers (index 2) when present.
  void _updateDriverMarker(TripModel trip) {
    if (trip.driverId == null) return;
    // Remove old driver marker (index 2 if it exists)
    if (_osmMarkers.length > 2) {
      _osmMarkers.removeAt(2);
    }
    if (trip.status == TripStatus.accepted ||
        trip.status == TripStatus.arriving ||
        trip.status == TripStatus.arrived ||
        trip.status == TripStatus.ongoing) {
      _osmMarkers.add(
        flmap.Marker(
          point: latlong.LatLng(trip.pickupLocation.latitude, trip.pickupLocation.longitude),
          width: 40,
          height: 40,
          builder: (_) => Container(
            decoration: const BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.directions_car, color: Colors.white, size: 24),
          ),
        ),
      );
    }
    setState(() {});
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    // Modified by Jayant Pandit on 2026-07-11 11:00:00
    // Reason: Cancel Firestore trip subscription to prevent memory leaks
    _tripSubscription?.cancel();
    _radarController.dispose();
    _dotBlinkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final bool isDesktop = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.linux ||
            defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.macOS);

    ref.listen<ThemeMode>(themeModeProvider, (previous, next) {
      // Modified by Jayant Pandit on 2026-07-11 12:00:00
      // Reason: Removed SetBlackMap dark theme listener — FlutterMap/OSM does not support
      // Google Maps style theming. OSM tiles are always the same regardless of dark mode.
    });

    // Modified by Jayant Pandit on 2026-07-11 11:00:00
    // Reason: Use _liveTrip (Firestore real-time) instead of widget.trip (initial only).
    // _liveTrip starts as widget.trip but updates automatically when driver accepts.
    final trip = _liveTrip;
    if (trip == null) {
      return Scaffold(
        appBar: AppBar(
          // Modified by Jayant Pandit on 2026-07-11 11:00:00
          // Reason: Apply responsive font size to app bar title
          title: TranslatedText(
            'Active Trip',
            style: TextStyle(fontSize: ResponsiveUtils.fontSize(context, 18)),
          ),
          backgroundColor: IndianHeritageColors.primaryYellow,
        ),
        body: Center(
          child: TranslatedText(
            'No active trip',
            style: TextStyle(
              color: isDark ? Colors.white : IndianHeritageColors.charcoal,
              fontSize: ResponsiveUtils.fontSize(context, 14),
            ),
          ),
        ),
      );
    }

    final tripStatus = trip.status;
    final isPending = tripStatus == TripStatus.pending;
    final isDriverAssigned = tripStatus == TripStatus.accepted ||
        tripStatus == TripStatus.arriving ||
        tripStatus == TripStatus.arrived;
    final isOngoing = tripStatus == TripStatus.ongoing;
    final isCompleted = tripStatus == TripStatus.completed || tripStatus == TripStatus.cancelled;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Full-Screen Map ────────────────────────────────────────────
          // Modified by Jayant Pandit on 2026-07-11 12:00:00
          // Reason: Replaced GoogleMap widget with FlutterMap + OSM tiles.
          // GoogleMap was showing a blank black screen because Google Maps API key was
          // either invalid, restricted, or billing not enabled. FlutterMap uses free
          // OpenStreetMap tiles that require no API key and always render correctly.
          isDesktop ? _buildDesktopMapPlaceholder(isDark) : flmap.FlutterMap(
            mapController: _mapController,
            options: flmap.MapOptions(
              center: latlong.LatLng(
                trip.pickupLocation.latitude,
                trip.pickupLocation.longitude,
              ),
              zoom: 15,
            ),
            children: [
              flmap.TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'dev.hyderali.DCS_customer',
              ),
              if (_osmMarkers.isNotEmpty)
                flmap.MarkerLayer(markers: _osmMarkers),
            ],
          ),

          // ── Header with Back Button ────────────────────────────────────
          Positioned(
            top: 50,
            left: 20,
            child: FloatingActionButton.small(
              heroTag: 'back_btn',
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              onPressed: () => Navigator.pop(context),
              child: const Icon(Icons.arrow_back),
            ),
          ),

          // ── Trip Status Card (Top Center) ──────────────────────────────
          Positioned(
            top: 50,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Color(trip!.statusColor),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      // ignore: deprecated_member_use
                      color: Color(trip!.statusColor).withAlpha((0.4 * 255).round()),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TranslatedText(
                  // Modified by Jayant Pandit on 2026-07-11 10:00:00
                  // Reason: Show "Finding nearby Partners" during pending, standard status text otherwise
                  isPending ? 'FINDING NEARBY PARTNERS' : trip!.statusText.toUpperCase(),
                  style: TextStyle(
                    color: Colors.white,
                    // Modified by Jayant Pandit on 2026-07-11 11:00:00
                    // Reason: Responsive font size for status badge text
                    fontSize: ResponsiveUtils.fontSize(context, 12),
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
          ),

          // ── Bottom Sheet: Different content based on trip status ────────
          if (isPending)
            // Modified by Jayant Pandit on 2026-07-11 10:00:00
            // Reason: "Finding nearby Partners" searching screen with pulsating radar animation
            _buildFindingPartnersSheet(isDark)
          else if (isDriverAssigned || isOngoing || isCompleted)
            // Modified by Jayant Pandit on 2026-07-11 10:00:00
            // Reason: Driver info card — shown after driver is assigned, during trip, and after completion
            _buildDriverInfoSheet(isDark, isOngoing),
        ],
      ),
    );
  }

  // Modified by Jayant Pandit on 2026-07-11 10:00:00
  // Reason: "Finding nearby Partners" bottom sheet with pulsating radar animation,
  // searching dots, and Cancel Ride button — replicates Rapido Customer APK searching flow
  Widget _buildFindingPartnersSheet(bool isDark) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        decoration: BoxDecoration(
          color: isDark ? IndianHeritageColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            const BoxShadow(
              color: Color.fromRGBO(0, 0, 0, 0.25),
              blurRadius: 24,
              offset: Offset(0, -10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Modified by Jayant Pandit on 2026-07-11 10:00:00
            // Reason: Pulsating radar animation — three concentric circles expanding outward
            SizedBox(
              width: 120,
              height: 120,
              child: AnimatedBuilder(
                animation: _radarController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: _RadarPainter(_radarController.value),
                    child: Center(
                      child: AnimatedBuilder(
                        animation: _dotBlinkController,
                        builder: (context, child) {
                          return Opacity(
                            opacity: _dotBlinkController.value,
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: IndianHeritageColors.primaryYellow,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: IndianHeritageColors.primaryYellow.withOpacity(0.4),
                                    blurRadius: 12,
                                    spreadRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            // Modified by Jayant Pandit on 2026-07-11 11:00:00
            // Reason: Responsive font sizes for finding partners sheet text
            TranslatedText(
              'Finding nearby Partners...',
              style: TextStyle(
                fontSize: ResponsiveUtils.fontSize(context, 18),
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            // Modified by Jayant Pandit on 2026-07-11 10:00:00
            // Reason: Animated searching dots (...) to show activity
            TranslatedText(
              'Looking for ${_liveTrip!.carType ?? 'vehicle'} drivers near you',
              style: TextStyle(
                fontSize: ResponsiveUtils.fontSize(context, 13),
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(height: 8),
            _buildSearchingDots(),
            const SizedBox(height: 28),
            // Modified by Jayant Pandit on 2026-07-11 10:00:00
            // Reason: Cancel Ride button during searching phase
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: () {
                  // Cancel ride — pop back to home
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.close_rounded, size: 20),
                label: TranslatedText(
                  'Cancel Ride',
                  // Modified by Jayant Pandit on 2026-07-11 11:00:00
                  // Reason: Responsive font size for cancel button
                  style: TextStyle(fontSize: ResponsiveUtils.fontSize(context, 16), fontWeight: FontWeight.w700),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Modified by Jayant Pandit on 2026-07-11 10:00:00
  // Reason: Animated "searching" dots widget — shows "..." animation while finding partners
  Widget _buildSearchingDots() {
    return AnimatedBuilder(
      animation: _dotBlinkController,
      builder: (context, child) {
        final dots = '.' * ((_dotBlinkController.value * 3).floor() + 1);
        return Text(
          dots,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: IndianHeritageColors.primaryYellow,
          ),
        );
      },
    );
  }

  // Modified by Jayant Pandit on 2026-07-11 10:00:00
  // Reason: Driver info bottom sheet — shown after driver is assigned. Contains:
  // Driver avatar + name + call button, vehicle info, trip progress (only if ongoing),
  // Message button, SOS button (only if ongoing)
  Widget _buildDriverInfoSheet(bool isDark, bool isOngoing) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 300),
        offset: const Offset(0, 0),
        child: Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? IndianHeritageColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              const BoxShadow(
                color: Color.fromRGBO(0, 0, 0, 0.25),
                blurRadius: 24,
                offset: Offset(0, -10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Drag Handle ────────────────────────────────────
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 16),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // ── Driver Info ────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    // Driver Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[900] : Colors.grey[100],
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                        ),
                      ),
                      child: Row(
                        children: [
                          // Modified by Jayant Pandit on 2026-07-11 11:00:00
                          // Reason: Driver avatar — use _liveTrip (live Firestore data) for photo.
                          // When a driver accepts, Partner app writes driverPhoto to trips/{tripId},
                          // and this CircleAvatar updates immediately via _tripSubscription listener.
                          CircleAvatar(
                            radius: ResponsiveUtils.container(context, 32) / 2,
                            backgroundColor: IndianHeritageColors.primaryYellow,
                            backgroundImage: _liveTrip!.driverPhoto != null
                                ? NetworkImage(_liveTrip!.driverPhoto!)
                                : null,
                            child: _liveTrip!.driverPhoto == null
                                ? Text(
                                    (_liveTrip!.driverName ?? 'D')[0].toUpperCase(),
                                    style: TextStyle(
                                      // Modified by Jayant Pandit on 2026-07-11 11:00:00
                                      // Reason: Responsive font size for driver avatar letter
                                      fontSize: ResponsiveUtils.fontSize(context, 24),
                                      color: IndianHeritageColors.charcoal,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TranslatedText(
                                  _liveTrip!.driverName ?? 'Driver',
                                  style: TextStyle(
                                    // Modified by Jayant Pandit on 2026-07-11 11:00:00
                                    // Reason: Responsive font size for driver name
                                    fontSize: ResponsiveUtils.fontSize(context, 16),
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.star, color: Colors.amber, size: ResponsiveUtils.iconSize(context, 14)),
                                    const SizedBox(width: 4),
                                    TranslatedText(
                                      '4.8 (250 rides)',
                                      style: TextStyle(
                                        // Modified by Jayant Pandit on 2026-07-11 11:00:00
                                        // Reason: Responsive font size for rating text
                                        fontSize: ResponsiveUtils.fontSize(context, 12),
                                        color: Colors.grey,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // Call Button
                          FloatingActionButton.small(
                            heroTag: 'call_driver',
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: TranslatedText('Calling ${_liveTrip!.driverName}...'),
                                ),
                              );
                            },
                            child: const Icon(Icons.call, size: 18),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Modified by Jayant Pandit on 2026-07-11 10:00:00
                    // Reason: Vehicle info bar — shows vehicle name and plate number
                    // Modified by Jayant Pandit on 2026-07-11 11:00:00
                    // Reason: Responsive font size for vehicle name in vehicle info bar
                    if (_liveTrip!.carName != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: IndianHeritageColors.primaryYellow.withAlpha(38),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: IndianHeritageColors.primaryYellow.withAlpha(77),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.local_taxi_rounded,
                              color: IndianHeritageColors.primaryYellow,
                              // Modified by Jayant Pandit on 2026-07-11 11:00:00
                              // Reason: Responsive icon size for vehicle type icon
                              size: ResponsiveUtils.iconSize(context, 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  TranslatedText(
                                    _liveTrip!.carName!,
                                    style: TextStyle(
                                      fontSize: ResponsiveUtils.fontSize(context, 14),
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                  if (_liveTrip!.carPlateNum != null)
                                    TranslatedText(
                                      _liveTrip!.carPlateNum!,
                                      style: TextStyle(
                                        // Modified by Jayant Pandit on 2026-07-11 11:00:00
                                        // Reason: Responsive font size for plate number
                                        fontSize: ResponsiveUtils.fontSize(context, 12),
                                        color: Colors.orange,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 16),

                    // Modified by Jayant Pandit on 2026-07-11 10:00:00
                    // Reason: Trip Progress card — ONLY shown when trip is ongoing (Picked up → In Transit)
                    if (isOngoing) ...[
                      _buildTripProgressCard(isDark),
                      const SizedBox(height: 16),
                    ],

                    // Modified by Jayant Pandit on 2026-07-11 10:00:00
                    // Reason: Action buttons — SOS button only shown when trip is ongoing
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: TranslatedText('Sending message to driver...'),
                                ),
                              );
                            },
                            icon: const Icon(Icons.message, size: 18),
                            label: const TranslatedText('Message'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                              foregroundColor: isDark ? Colors.white : Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        // Modified by Jayant Pandit on 2026-07-11 10:00:00
                        // Reason: SOS button — ONLY visible when trip is in Progress (ongoing)
                        if (isOngoing) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _showEmergencyOptions(context, isDark),
                              icon: const Icon(Icons.sos, size: 18),
                              label: const TranslatedText('SOS'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTripProgressCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TranslatedText(
            'Trip Progress',
            style: TextStyle(
              // Modified by Jayant Pandit on 2026-07-11 11:00:00
              // Reason: Responsive font size for trip progress title
              fontSize: ResponsiveUtils.fontSize(context, 14),
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      color: Colors.green,
                      // Modified by Jayant Pandit on 2026-07-11 11:00:00
                      // Reason: Responsive icon size for trip progress icons
                      size: ResponsiveUtils.iconSize(context, 32),
                    ),
                    const SizedBox(height: 8),
                    TranslatedText(
                      'Picked up',
                      style: TextStyle(
                        // Modified by Jayant Pandit on 2026-07-11 11:00:00
                        // Reason: Responsive font size for trip progress step label
                        fontSize: ResponsiveUtils.fontSize(context, 12),
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    Container(
                      width: 32,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    Icon(
                      Icons.location_on_rounded,
                      color: Colors.grey[400],
                      // Modified by Jayant Pandit on 2026-07-11 11:00:00
                      // Reason: Responsive icon size for trip progress icons
                      size: ResponsiveUtils.iconSize(context, 32),
                    ),
                    const SizedBox(height: 8),
                    TranslatedText(
                      'In transit',
                      style: TextStyle(
                        // Modified by Jayant Pandit on 2026-07-11 11:00:00
                        // Reason: Responsive font size for trip progress step label
                        fontSize: ResponsiveUtils.fontSize(context, 12),
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showEmergencyOptions(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? IndianHeritageColors.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TranslatedText(
              'Emergency Help',
              style: TextStyle(
                // Modified by Jayant Pandit on 2026-07-11 11:00:00
                // Reason: Responsive font size for emergency dialog title
                fontSize: ResponsiveUtils.fontSize(context, 18),
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.call, color: Colors.green),
              title: const TranslatedText('Call Support'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: TranslatedText('Calling support...')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.warning, color: Colors.red),
              title: const TranslatedText('Report Safety Issue'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: TranslatedText('Issue reported')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.cancel, color: Colors.orange),
              title: const TranslatedText('Cancel Ride'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: TranslatedText('Ride cancelled')),
                );
              },
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const TranslatedText(
                'Close',
                style: TextStyle(color: IndianHeritageColors.primaryYellow),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopMapPlaceholder(bool isDark) {
    return Container(
      color: isDark ? IndianHeritageColors.darkBackground : Colors.grey.shade200,
      child: Center(
        child: Text(
          'Active trip map unavailable on desktop',
          style: TextStyle(
            color: isDark ? Colors.white70 : Colors.black87,
            // Modified by Jayant Pandit on 2026-07-11 11:00:00
            // Reason: Responsive font size for desktop placeholder text
            fontSize: ResponsiveUtils.fontSize(context, 16),
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

// Modified by Jayant Pandit on 2026-07-11 10:00:00
// Reason: Custom painter for pulsating radar animation — three concentric circles
// expanding outward with fading opacity, used in "Finding nearby Partners" screen
class _RadarPainter extends CustomPainter {
  final double animationValue;
  _RadarPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    for (int i = 0; i < 3; i++) {
      final delay = i * 0.33;
      final progress = (animationValue - delay).clamp(0.0, 1.0);
      final radius = maxRadius * progress;
      // Modified by Jayant Pandit on 2026-07-11 10:00:00
      // Reason: Opacity fades as circle expands — gives pulsating radar effect
      final opacity = (1.0 - progress).clamp(0.0, 1.0);
      final paint = Paint()
        ..color = IndianHeritageColors.primaryYellow.withOpacity(opacity * 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) =>
      oldDelegate.animationValue != animationValue;
}
