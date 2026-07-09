import 'package:dio/dio.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:Dadacabs/View/Widgets/translated_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_map/flutter_map.dart' as flmap;
import 'package:latlong2/latlong.dart' as latlong;
import 'package:go_router/go_router.dart';
import 'package:Dadacabs/Model/trip_model.dart';
import 'package:Dadacabs/View/Themes/indian_heritage_theme.dart';
import 'package:Dadacabs/Container/Providers/theme_provider.dart';
import 'package:Dadacabs/Container/utils/keys.dart';
import 'package:Dadacabs/Model/direction_polyline_details_model.dart';
import 'package:Dadacabs/Container/Repositories/firestore_repo.dart';
import 'package:Dadacabs/Container/Providers/user_data_provider.dart';
import 'package:Dadacabs/Container/Providers/vehicle_providers.dart';
import 'package:Dadacabs/Container/Providers/fare_config_providers.dart';
import 'package:Dadacabs/Container/Services/fare_service.dart';
import 'package:Dadacabs/Model/driver_model.dart';
import 'package:Dadacabs/Model/vehicle_type_model.dart';
import 'package:Dadacabs/View/Screens/Main_Screens/Home_Screen/home_providers.dart';
import 'package:Dadacabs/View/Screens/Main_Screens/Home_Screen/home_logics.dart';
import 'package:Dadacabs/View/Routes/routes.dart';
// Modified by Jayant Pandit on 2026-07-11 10:00:00
// Reason: Import flutter_contacts for passenger contact picker in "For Other" flow
import 'package:flutter_contacts/flutter_contacts.dart';
// Modified by Jayant Pandit on 2026-07-11 11:00:00
// Reason: Import responsive utilities for auto-adjusted font sizing based on screen width
import 'package:Dadacabs/Container/utils/responsive_utils.dart';

class WhereToScreenModern extends ConsumerStatefulWidget {
  final TripModel? initialTrip;

  const WhereToScreenModern({
    super.key,
    this.initialTrip,
  });

  @override
  ConsumerState<WhereToScreenModern> createState() => _WhereToScreenModernState();
}

class _WhereToScreenModernState extends ConsumerState<WhereToScreenModern> {
  late TextEditingController _searchController;
  // Modified by Jayant Pandit on 2026-07-09 14:30:00
  // Reason: Replaced Google Maps with OSM (FlutterMap). Google Maps code commented out.
  final flmap.MapController _mapController = flmap.MapController();
  bool _showSuggestions = false;
  bool _isLoadingSuggestions = false;
  bool _showFareSheet = false;
  TripModel? _fareTrip;
  int _ridePurposeIndex = 0; // 0 = For me, 1 = For someone else
  int _selectedVehicleIndex = 0;
  List<Map<String, dynamic>> _additionalStops = [];

  // Modified by Jayant Pandit on 2026-07-09 14:30:00
  // Reason: Color scheme update: renamed darkYellow→lemonYellow (bg), darkYellow for legacy accents.
  static const Color lemonYellow = Color(0xFFFFF176);
  static const Color darkYellow = Color(0xFFFFD600);
  List<Map<String, dynamic>> _placeSuggestions = [];
  LatLng? _selectedDestination;
  LatLng? _currentLocation;
  DirectionPolylineDetails? _directionDetails;
  final Dio _dio = Dio();

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _selectedDestination = null;
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  /// Calculate distance and duration between pickup and destination using Google Directions API
  Future<void> _calculateRouteDetails() async {
    if (_selectedDestination == null || widget.initialTrip == null) return;
    // Guard against invalid (0,0) destination coordinates
    if (_selectedDestination!.latitude == 0.0 && _selectedDestination!.longitude == 0.0) return;
    
    final pickup = widget.initialTrip!.pickupLocation;
    final dropoff = _selectedDestination!;
    final straightLineDistance = Geolocator.distanceBetween(
      pickup.latitude, pickup.longitude,
      dropoff.latitude, dropoff.longitude,
    );
    
    try {
      String url = "https://maps.googleapis.com/maps/api/directions/json"
          "?origin=${pickup.latitude},${pickup.longitude}"
          "&destination=${dropoff.latitude},${dropoff.longitude}"
          "&mode=driving"
          "&traffic_model=best_guess"
          "&departure_time=now"
          "&key=${AppKeys.mapKey}";
      
      final Response res = await _dio.get(url);
      
      if (res.statusCode == 200 && 
          res.data["routes"] != null && 
          (res.data["routes"] as List).isNotEmpty) {
        final leg = res.data["routes"][0]["legs"][0];
        final durationText = leg["duration_in_traffic"] != null
            ? leg["duration_in_traffic"]["text"]
            : leg["duration"]["text"];
        final durationValue = leg["duration_in_traffic"] != null
            ? leg["duration_in_traffic"]["value"]
            : leg["duration"]["value"];
        _directionDetails = DirectionPolylineDetails(
          distanceText: leg["distance"]["text"],
          distanceValue: leg["distance"]["value"],
          durationText: durationText,
          durationValue: durationValue,
        );
        return;
      }
    } catch (e) {
      print("WhereTo: Directions API error, using straight-line distance: $e");
    }
    
    // Fallback: use straight-line distance * 1.3 (rough road factor), capped at max reasonable city distance (100km)
    final cappedDistance = (straightLineDistance * 1.3).clamp(0, 100000).toInt();
    _directionDetails = DirectionPolylineDetails(
      distanceText: "${(cappedDistance / 1000).toStringAsFixed(1)} km",
      distanceValue: cappedDistance,
      durationText: "${(cappedDistance / 500).toInt()} min",
      durationValue: (cappedDistance / 500).toInt() * 60,
    );
  }

  /// Get user's current location to bias search results nearby
  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return;

      Position pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      if (mounted) {
        setState(() {
          _currentLocation = LatLng(pos.latitude, pos.longitude);
        });
      }
    } catch (e) {
      print("WhereTo: Error getting current location: $e");
    }
  }

  /// Fetch place predictions from Google Places Autocomplete API (matching Partner's direct API approach)
  Future<void> _fetchPlacePredictions(String query) async {
    if (query.length < 2) {
      setState(() {
        _placeSuggestions = [];
        _showSuggestions = false;
      });
      return;
    }

    setState(() {
      _isLoadingSuggestions = true;
      _showSuggestions = true;
    });

    try {
      String url = "https://maps.googleapis.com/maps/api/place/autocomplete/json"
          "?input=${Uri.encodeComponent(query)}"
          "&components=country:in"
          "&key=${AppKeys.mapKey}";

      // Bias results to user's current location if available
      if (_currentLocation != null) {
        url += "&location=${_currentLocation!.latitude},${_currentLocation!.longitude}";
        url += "&radius=50000"; // 50km radius
      }

      final Response res = await _dio.get(url);

      if (mounted && res.statusCode == 200 && res.data["status"] == "OK") {
        final predictions = res.data["predictions"] as List;
        setState(() {
          _placeSuggestions = predictions.map<Map<String, dynamic>>((p) => {
            'placeId': p['place_id'] ?? '',
            'description': p['description'] ?? '',
            'mainText': p['structured_formatting']?['main_text'] ?? '',
            'secondaryText': p['structured_formatting']?['secondary_text'] ?? '',
          }).toList();
          _isLoadingSuggestions = false;
        });
      } else {
        setState(() {
          _placeSuggestions = [];
          _isLoadingSuggestions = false;
        });
      }
    } catch (e) {
      print("WhereTo: Autocomplete error: $e");
      if (mounted) {
        setState(() {
          _placeSuggestions = [];
          _isLoadingSuggestions = false;
        });
      }
    }
  }

  /// Get place details (lat/lng) from Place ID
  Future<void> _selectPlace(String placeId, String description) async {
    try {
      String url = "https://maps.googleapis.com/maps/api/place/details/json"
          "?place_id=$placeId"
          "&key=${AppKeys.mapKey}";

      final Response res = await _dio.get(url);

      if (res.statusCode == 200 && res.data["status"] == "OK") {
        final result = res.data["result"];
        final location = result["geometry"]["location"];
        final lat = location["lat"] as double;
        final lng = location["lng"] as double;

        setState(() {
          _searchController.text = description;
          _selectedDestination = LatLng(lat, lng);
          _directionDetails = null;
          _showSuggestions = false;
          _placeSuggestions = [];
        });
        _mapController.move(latlong.LatLng(_selectedDestination!.latitude, _selectedDestination!.longitude), 15);
        // Calculate route details (distance & duration) for the selected destination
        await _calculateRouteDetails();
      } else {
        // Fallback: use geocoding API to resolve coordinates
        await _geocodeAndSelect(description);
      }
    } catch (e) {
      print("WhereTo: Place details error: $e");
      // Fallback: use geocoding API
      await _geocodeAndSelect(description);
    }
  }

  /// Fallback: resolve address via Geocoding API (matching Partner's direct API pattern)
  Future<void> _geocodeAndSelect(String address) async {
    try {
      String url = "https://maps.googleapis.com/maps/api/geocode/json"
          "?address=${Uri.encodeComponent(address)}"
          "&key=${AppKeys.mapKey}";

      final Response res = await _dio.get(url);

      if (res.statusCode == 200 && res.data["status"] == "OK" && res.data["results"] != null && res.data["results"].isNotEmpty) {
        final location = res.data["results"][0]["geometry"]["location"];
        final lat = location["lat"] as double;
        final lng = location["lng"] as double;

        setState(() {
          _searchController.text = address;
          _selectedDestination = LatLng(lat, lng);
          _directionDetails = null;
          _showSuggestions = false;
          _placeSuggestions = [];
        });
        _mapController.move(latlong.LatLng(_selectedDestination!.latitude, _selectedDestination!.longitude), 15);
        // Calculate route details (distance & duration) for the selected destination
        await _calculateRouteDetails();
      }
    } catch (e) {
      print("WhereTo: Geocode fallback error: $e");
    }
  }

  void _updateSuggestions(String query) {
    _fetchPlacePredictions(query);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    // Modified by Jayant Pandit on 2026-07-10 08:00:00
    // Reason: Watch available drivers to render on selection screen map
    final availableDrivers = ref.watch(homeScreenAvailableDriversProvider);

    return Scaffold(
      backgroundColor: isDark ? IndianHeritageColors.darkBackground : IndianHeritageColors.platinum,
      body: Stack(
        children: [
          // ── Background Map ────────────────────────────────────────────
          // Modified by Jayant Pandit on 2026-07-09 14:30:00
          // Reason: Replaced GoogleMap with FlutterMap (OSM). Google Maps code commented out.
          flmap.FlutterMap(
            mapController: _mapController,
            options: flmap.MapOptions(
              center: latlong.LatLng(
                widget.initialTrip?.pickupLocation.latitude ?? 0.0,
                widget.initialTrip?.pickupLocation.longitude ?? 0.0,
              ),
              zoom: 15,
            ),
            children: [
              flmap.TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'dev.hyderali.DCS_user',
              ),
              // Modified by Jayant Pandit on 2026-07-10 08:00:00
              // Reason: Show vehicle markers on selection screen map
              if (availableDrivers.isNotEmpty)
                flmap.MarkerLayer(markers: availableDrivers.map((d) {
                  return flmap.Marker(
                    point: latlong.LatLng(d.driverLoc.latitude, d.driverLoc.longitude),
                    builder: (_) => Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        color: _vehicleColor(d.carType),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 4)],
                      ),
                      child: Icon(_osmVehicleIcon(d.carType), color: Colors.white, size: 16),
                    ),
                  );
                }).toList()),
              flmap.MarkerLayer(markers: [
                if (_selectedDestination != null)
                  flmap.Marker(
                    point: latlong.LatLng(
                      _selectedDestination!.latitude,
                      _selectedDestination!.longitude,
                    ),
                    builder: (_) => Container(
                      width: 30, height: 30,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEF5350),
                        shape: BoxShape.circle,
                        border: Border.fromBorderSide(BorderSide(color: Colors.white, width: 2)),
                      ),
                      child: const Icon(Icons.location_on, color: Colors.white, size: 18),
                    ),
                  )
                else if (widget.initialTrip != null)
                  flmap.Marker(
                    point: latlong.LatLng(
                      widget.initialTrip!.pickupLocation.latitude,
                      widget.initialTrip!.pickupLocation.longitude,
                    ),
                    builder: (_) => Container(
                      width: 30, height: 30,
                      decoration: const BoxDecoration(
                        color: Color(0xFF4CAF50),
                        shape: BoxShape.circle,
                        border: Border.fromBorderSide(BorderSide(color: Colors.white, width: 2)),
                      ),
                      child: const Icon(Icons.person_pin, color: Colors.white, size: 18),
                    ),
                  ),
              ]),
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
              onPressed: () => context.pop(),
              child: const Icon(Icons.arrow_back),
            ),
          ),

          // ── Search Input & Suggestions Overlay ──────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? IndianHeritageColors.darkBackground : Colors.white,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              child: Column(
                children: [
                  // ── Padding for status bar ────────────────────────────
                  SizedBox(height: MediaQuery.of(context).padding.top + 16),

                  // ── Search Input ──────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[900] : Colors.grey[100],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                        ),
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: _updateSuggestions,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          // Modified by Jayant Pandit on 2026-07-11 11:00:00
                          // Reason: Responsive font size for search input text
                          fontSize: ResponsiveUtils.fontSize(context, 16),
                        ),
                        decoration: InputDecoration(
                          hintText: 'Where to?',
                          hintStyle: TextStyle(
                            color: Colors.grey[600],
                            // Modified by Jayant Pandit on 2026-07-11 11:00:00
                            // Reason: Responsive font size for search hint text
                            fontSize: ResponsiveUtils.fontSize(context, 16),
                          ),
                          border: InputBorder.none,
                          prefixIcon: Icon(
                            Icons.location_on_rounded,
                            color: IndianHeritageColors.primaryYellow,
                            size: 20,
                          ),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? GestureDetector(
                                  onTap: () {
                                    _searchController.clear();
                                    setState(() => _showSuggestions = false);
                                  },
                                  child: Icon(
                                    Icons.close_rounded,
                                    color: Colors.grey[600],
                                    size: 20,
                                  ),
                                )
                              : null,
                          contentPadding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ),

                  // ── Search Suggestions (Google Places Autocomplete) ──
                  if (_showSuggestions && (_placeSuggestions.isNotEmpty || _isLoadingSuggestions))
                    Container(
                      color: isDark ? Colors.grey[900] : Colors.grey[100],
                      child: _isLoadingSuggestions
                          ? const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _placeSuggestions.length,
                              itemBuilder: (context, index) {
                                final place = _placeSuggestions[index];
                                return _placeSuggestionTile(place, isDark);
                              },
                            ),
                    ),

                  // ── Quick Action Buttons ──────────────────────────────
                  if (!_showSuggestions)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      child: Row(
                        children: [
                          _quickActionChip(Icons.home_rounded, "Home", isDark),
                          const SizedBox(width: 8),
                          _quickActionChip(Icons.work_rounded, "Work", isDark),
                          const SizedBox(width: 8),
                          _quickActionChip(Icons.location_on_rounded, "Current Location", isDark),
                        ],
                      ),
                    ),

                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),

          // ── Confirm Button / Fare Estimate Panel (Bottom) ────────────
          if (_selectedDestination != null && !_showFareSheet)
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: SizedBox(
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    if (_directionDetails == null && _selectedDestination != null) {
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (context) => const Center(
                          child: CircularProgressIndicator(color: IndianHeritageColors.primaryYellow),
                        ),
                      );
                      await _calculateRouteDetails();
                      if (context.mounted) Navigator.pop(context);
                    }

                    double? distanceKm;
                    int? durationMinutes;
                    if (_directionDetails != null) {
                      distanceKm = _directionDetails!.distanceValue != null
                          ? _directionDetails!.distanceValue! / 1000.0
                          : null;
                      if (distanceKm != null && distanceKm > 500) distanceKm = null;
                      durationMinutes = _directionDetails!.durationValue != null
                          ? (_directionDetails!.durationValue! / 60.0).round()
                          : null;
                    } else {
                      final pickup = widget.initialTrip?.pickupLocation;
                      if (pickup != null && _selectedDestination != null) {
                        final meters = Geolocator.distanceBetween(
                          pickup.latitude, pickup.longitude,
                          _selectedDestination!.latitude, _selectedDestination!.longitude,
                        );
                        distanceKm = meters / 1000.0;
                        durationMinutes = (meters / 500).round();
                      }
                    }

                    final updatedTrip = TripModel(
                      tripId: widget.initialTrip?.tripId ?? 'temp-${DateTime.now().millisecondsSinceEpoch}',
                      userId: widget.initialTrip?.userId ?? 'guest',
                      driverId: widget.initialTrip?.driverId,
                      driverName: widget.initialTrip?.driverName,
                      pickupAddress: widget.initialTrip?.pickupAddress ?? 'Pickup Location',
                      dropoffAddress: _searchController.text,
                      pickupLocation: widget.initialTrip?.pickupLocation ?? const LatLng(0.0, 0.0),
                      dropoffLocation: _selectedDestination ?? const LatLng(0.0, 0.0),
                      carType: widget.initialTrip?.carType ?? 'Sedan',
                      carName: widget.initialTrip?.carName,
                      carPlateNum: widget.initialTrip?.carPlateNum,
                      estimatedFare: widget.initialTrip?.estimatedFare ?? 0.0,
                      distanceKm: distanceKm,
                      durationMinutes: durationMinutes,
                      driverPhoto: widget.initialTrip?.driverPhoto,
                      createdAt: widget.initialTrip?.createdAt ?? DateTime.now(),
                      status: widget.initialTrip?.status ?? TripStatus.pending,
                    );

                    _showFareResults(updatedTrip);
                  },
                  icon: const Icon(Icons.arrow_forward, size: 20),
                  label: TranslatedText(
                    'Select Vehicle',
                    style: TextStyle(
                      // Modified by Jayant Pandit on 2026-07-11 11:00:00
                      // Reason: Responsive font size for Select Vehicle button text
                      fontSize: ResponsiveUtils.fontSize(context, 16),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: IndianHeritageColors.primaryYellow,
                    foregroundColor: IndianHeritageColors.charcoal,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 8,
                    shadowColor: IndianHeritageColors.primaryYellow.withAlpha(102),
                  ),
                ),
              ),
            ),

          // ── Fare Estimate Panel (replaces confirm button) ────────────
          if (_showFareSheet && _fareTrip != null)
            _buildFareEstimatePanel(MediaQuery.of(context).size, isDark),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Fare Estimate Flow
  // ─────────────────────────────────────────────────────────────────────────────

  void _showFareResults(TripModel trip) {
    setState(() {
      _fareTrip = trip;
      _showFareSheet = true;
      _selectedVehicleIndex = 0;
    });
  }

  Widget _buildFareEstimatePanel(Size size, bool isDark) {
    final vehicleTypesAsync = ref.watch(vehicleTypesStreamProvider);
    final distanceKm = _fareTrip!.distanceKm ?? 0.0;
    final durationMinutes = _fareTrip!.durationMinutes ?? 0;
    final availableDrivers = ref.watch(homeScreenAvailableDriversProvider);
    final pickupAddr = _fareTrip!.pickupAddress;
    final dropoffAddr = _fareTrip!.dropoffAddress;

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        height: size.height * 0.55,
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
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Trip summary header
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
                            // Reason: Responsive font size for pickup address in fare estimate header
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
                                dropoffAddr,
                                style: TextStyle(
                                  // Modified by Jayant Pandit on 2026-07-11 11:00:00
                                  // Reason: Responsive font size for dropoff address in fare estimate header
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
                        // Reason: Responsive font size for distance in fare estimate header
                        fontSize: ResponsiveUtils.fontSize(context, 14),
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                ],
              ),
            ),
            // Add stop + Ride purpose
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                children: [
                  // Add stop
                  Expanded(
                    child: InkWell(
                      onTap: _onAddStop,
                    child: Row(
                      children: [
                        Icon(Icons.add_circle_outline, size: 18, color: darkYellow),
                        const SizedBox(width: 8),
                        Text(
                          _additionalStops.isEmpty ? 'Add stop' : '${_additionalStops.length} stop(s)',
                          style: TextStyle(
                            // Modified by Jayant Pandit on 2026-07-11 11:00:00
                            // Reason: Responsive font size for add stop text
                            fontSize: ResponsiveUtils.fontSize(context, 13),
                            fontWeight: FontWeight.w600,
                            color: darkYellow,
                          ),
                        ),
                        ],
                      ),
                    ),
                  ),
                  // Ride purpose toggle
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[900] : Colors.grey[100],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _purposeChip('For me', 0, isDark),
                        const SizedBox(width: 2),
                        _purposeChip('For other', 1, isDark),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Vehicle list
            Expanded(
              child: vehicleTypesAsync.when(
                // Modified by Jayant Pandit on 2026-07-08 10:30:00
                // Reason: Filter vehicle list by online driver availability — matching home_screen_modern.dart behavior
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
            // Bottom bar: Book button + back
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              decoration: BoxDecoration(
                color: isDark ? IndianHeritageColors.darkSurface : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  // Back button
                  SizedBox(
                    width: 52,
                    height: 52,
                    child: OutlinedButton(
                      onPressed: () => setState(() {
                        _showFareSheet = false;
                        _fareTrip = null;
                      }),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        side: BorderSide(color: Colors.grey[300]!),
                      ),
                      child: Icon(Icons.arrow_back_rounded, color: isDark ? Colors.white : Colors.black87, size: 22),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Modified by Jayant Pandit on 2026-07-08 10:30:00
                  // Reason: Use same availability-filtered list as the displayed vehicle types to keep index in sync
                  // Book button
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton(
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
                          backgroundColor: darkYellow,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 8,
                          shadowColor: darkYellow.withOpacity(0.4),
                        ),
                        child: Text(
                          'Book ${_selectedVehicleName()}',
                          style: TextStyle(
                            // Modified by Jayant Pandit on 2026-07-11 11:00:00
                            // Reason: Responsive font size for Book button text in fare estimate
                            fontSize: ResponsiveUtils.fontSize(context, 16),
                            fontWeight: FontWeight.w900,
                          ),
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

  // Modified by Jayant Pandit on 2026-07-11 10:00:00
  // Reason: "For other" chip now triggers passenger selection dialog matching Rapido flow.
  // "For me" clears the booking passenger provider.
  Widget _purposeChip(String label, int index, bool isDark) {
    final selected = _ridePurposeIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() => _ridePurposeIndex = index);
        if (index == 1) {
          // "For other" — show passenger selection dialog
          _showPassengerSelectionDialog();
        } else {
          // "For me" — clear any previously set passenger
          ref.read(homeScreenBookingPassengerProvider.notifier).state = null;
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? darkYellow : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.black : (isDark ? Colors.white70 : Colors.black54),
          ),
        ),
      ),
    );
  }

  // Modified by Jayant Pandit on 2026-07-11 10:00:00
  // Reason: Passenger selection dialog for "Booking for someone else" — replicates home_screen_modern.dart flow
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
                          ? darkYellow.withOpacity(0.12)
                          : (isDark ? Colors.grey[900] : Colors.grey[100]),
                      borderRadius: BorderRadius.circular(12),
                      border: passengerType == 'myself'
                          ? Border.all(color: darkYellow, width: 2)
                          : null,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.person_rounded,
                          color: passengerType == 'myself' ? darkYellow : Colors.grey,
                          size: 28,
                        ),
                        const SizedBox(width: 14),
                        Text(
                          'Myself',
                          style: TextStyle(
                            // Modified by Jayant Pandit on 2026-07-11 11:00:00
                            // Reason: Responsive font size for Myself option text
                            fontSize: ResponsiveUtils.fontSize(context, 16),
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const Spacer(),
                        if (passengerType == 'myself')
                          Icon(Icons.check_circle_rounded, color: darkYellow, size: 22),
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
                          ? darkYellow.withOpacity(0.12)
                          : (isDark ? Colors.grey[900] : Colors.grey[100]),
                      borderRadius: BorderRadius.circular(12),
                      border: passengerType == 'new'
                          ? Border.all(color: darkYellow, width: 2)
                          : null,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.person_add_alt_1_rounded,
                          color: passengerType == 'new' ? darkYellow : Colors.grey,
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
                          Icon(Icons.check_circle_rounded, color: darkYellow, size: 22),
                      ],
                    ),
                  ),
                ),
                if (passengerType == 'new') ...[
                  const SizedBox(height: 16),
                  // Modified by Jayant Pandit on 2026-07-11 10:00:00
                  // Reason: Contact picker for passenger details — uses FlutterContacts.native.showPicker()
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
                        foregroundColor: darkYellow,
                        side: BorderSide(color: darkYellow.withOpacity(0.5)),
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
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: darkYellow,
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

  void _onAddStop() async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Add a stop'),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: TextField(
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search for a place',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onSubmitted: (val) => Navigator.pop(ctx, val),
            ),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      setState(() {
        _additionalStops.add({'name': result, 'address': result});
      });
    }
  }

  // Modified by Jayant Pandit on 2026-07-08 10:30:00
  // Reason: Use same availability-filtered list as displayed vehicle types to keep selected name in sync with filtered index
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

  // Modified by Jayant Pandit on 2026-07-08 10:30:00
  // Reason: Sync with home_screen_modern.dart — handle compound names like "Auto Rickshaw", "Luxury Car", "Hatchback" by using contains() instead of ==
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
    final now = DateTime.now();
    final durationMinutes = _fareTrip?.durationMinutes ?? 0;
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
                ? (isDark ? Colors.grey[800] : darkYellow.withOpacity(0.12))
                : (isDark ? Colors.grey[900] : Colors.grey[100]),
            borderRadius: BorderRadius.circular(14),
            border: isSelected
                ? Border.all(color: darkYellow, width: 2)
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: darkYellow.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: hasImage
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          vehicle.fullImageUrl!,
                          width: 52,
                          height: 52,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(fallbackIcon, color: darkYellow, size: 28),
                          loadingBuilder: (_, child, progress) {
                            if (progress == null) return child;
                            return const SizedBox(
                              width: 52, height: 52,
                              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                            );
                          },
                        ),
                      )
                    : Icon(fallbackIcon, color: darkYellow, size: 28),
              ),
              const SizedBox(width: 12),
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
                            // Reason: Responsive font size for vehicle name in fare estimate
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
                              color: darkYellow,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Selected',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        // Modified by Jayant Pandit on 2026-07-11 11:00:00
                        // Reason: Responsive font size for vehicle subtitle in fare estimate
                        fontSize: ResponsiveUtils.fontSize(context, 11),
                        color: Colors.grey[500],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '₹${fare.toStringAsFixed(0)}',
                          style: TextStyle(
                            // Modified by Jayant Pandit on 2026-07-11 11:00:00
                            // Reason: Responsive font size for fare price in fare estimate
                            fontSize: ResponsiveUtils.fontSize(context, 16),
                            fontWeight: FontWeight.w800,
                            color: darkYellow,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.access_time_rounded, size: 12, color: Colors.grey[500]),
                        const SizedBox(width: 3),
                        Text('${durationMinutes} mins', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                        const SizedBox(width: 8),
                        Icon(Icons.location_on_rounded, size: 12, color: Colors.grey[500]),
                        const SizedBox(width: 3),
                        Text(dropTimeStr, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                      ],
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(Icons.check_circle_rounded, color: darkYellow, size: 22)
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

  // Modified by Jayant Pandit on 2026-07-09 18:00:00
  // Reason: Navigate to active trip screen immediately, then do Firestore write + webhook in background.
  // Previously awaited both before navigation, which blocked the UI if Firestore/webhook was slow.
  // Also added null safety for provider reads to prevent crashes.
  // Consistent with home_screen_modern.dart fix.
  // Modified by Jayant Pandit on 2026-07-11 10:00:00
  // Reason: Pass bookingPassenger (from "For Other" dialog) to trip model for partner compatibility.
  // Added sequential Firestore write + propagation delay + webhook for reliable driver notification.
  void _requestRide(VehicleTypeModel vehicle) {
    if (_fareTrip == null || !mounted) return;

    final pickUp = ref.read(homeScreenPickUpLocationProvider);
    final user = ref.read(userDataProvider);
    final bookingPassenger = ref.read(homeScreenBookingPassengerProvider);

    final trip = TripModel(
      tripId: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: user?.uid ?? 'guest',
      // Modified by Jayant Pandit on 2026-07-11 10:00:00
      // Reason: Use bookingPassenger name when ride is "For Other", otherwise fall back to logged-in user name
      userName: bookingPassenger ?? user?.name ?? 'Customer',
      userPhone: user?.phone ?? '',
      pickupLocation: pickUp != null && pickUp.locationLatitude != null && pickUp.locationLongitude != null
          ? LatLng(pickUp.locationLatitude!, pickUp.locationLongitude!)
          : _fareTrip!.pickupLocation,
      pickupAddress: pickUp?.humanReadableAddress ?? _fareTrip!.pickupAddress,
      dropoffLocation: _fareTrip!.dropoffLocation,
      dropoffAddress: _fareTrip!.dropoffAddress,
      createdAt: DateTime.now(),
      estimatedFare: _calculateFare(vehicle, _fareTrip!.distanceKm ?? 0.0, _fareTrip!.durationMinutes ?? 0),
      carType: vehicle.name,
      carName: vehicle.name,
      distanceKm: _fareTrip!.distanceKm,
      durationMinutes: _fareTrip!.durationMinutes,
      status: TripStatus.pending,
    );

    // Navigate immediately for responsive UI
    if (mounted) {
      context.pushNamed(Routes().activeTripModern, extra: trip);
    }
    // Modified by Jayant Pandit on 2026-07-11 10:00:00
    // Reason: Sequential Firestore write + propagation delay + webhook, matching home_screen_modern.dart fix
    _performRideRequestFirestoreWriteAndNotify(trip);
  }

  // Modified by Jayant Pandit on 2026-07-11 10:00:00
  // Reason: Extracted ride request logic into separate async method for proper error handling.
  Future<void> _performRideRequestFirestoreWriteAndNotify(TripModel trip) async {
    try {
      debugPrint("RIDE_REQUEST(WHERE_TO): Writing trip ${trip.tripId} to Firestore...");
      await ref.read(globalFirestoreRepoProvider).addUserRideRequestToDB(
        context, ref, null, trip,
      );
      debugPrint("RIDE_REQUEST(WHERE_TO): Firestore write complete for ${trip.tripId}");
      await Future.delayed(const Duration(seconds: 1));
      debugPrint("RIDE_REQUEST(WHERE_TO): Notifying drivers via webhook for ${trip.tripId}");
      await HomeScreenLogics.notifyDriversViaWebhook(trip.tripId);
      debugPrint("RIDE_REQUEST(WHERE_TO): Webhook notification complete for ${trip.tripId}");
    } catch (e) {
      debugPrint("RIDE_REQUEST(WHERE_TO): ERROR for trip ${trip.tripId}: $e");
    }
  }

  /// Google Places Autocomplete suggestion tile
  Widget _placeSuggestionTile(Map<String, dynamic> place, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: ListTile(
        dense: true,
        leading: const Icon(
          Icons.location_on_outlined,
          color: Colors.grey,
          size: 22,
        ),
        title: Text(
          place['mainText'] ?? '',
          style: TextStyle(
            // Modified by Jayant Pandit on 2026-07-11 11:00:00
            // Reason: Responsive font size for place suggestion main text
            fontSize: ResponsiveUtils.fontSize(context, 14),
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black87,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          place['secondaryText'] ?? '',
          style: TextStyle(
            // Modified by Jayant Pandit on 2026-07-11 11:00:00
            // Reason: Responsive font size for place suggestion secondary text
            fontSize: ResponsiveUtils.fontSize(context, 12),
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        onTap: () => _selectPlace(
          place['placeId'] ?? '',
          place['description'] ?? '',
        ),
      ),
    );
  }

  /// Quick action chip for common places
  Widget _quickActionChip(IconData icon, String label, bool isDark) {
    return Expanded(
      child: InkWell(
        onTap: () async {
          if (label == "Current Location" && _currentLocation != null) {
            setState(() {
              _selectedDestination = _currentLocation;
              _searchController.text = "Current Location";
            });
            _mapController.move(latlong.LatLng(_currentLocation!.latitude, _currentLocation!.longitude), 15);
          } else {
            // For Home/Work, search via Places API
            _searchController.text = label;
            await _fetchPlacePredictions(label);
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[800] : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
          ),
          child: Column(
            children: [
              Icon(icon, size: 24, color: IndianHeritageColors.primaryYellow),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  // Modified by Jayant Pandit on 2026-07-11 11:00:00
                  // Reason: Responsive font size for quick action chip label
                  fontSize: ResponsiveUtils.fontSize(context, 11),
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.grey[700],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Modified by Jayant Pandit on 2026-07-10 08:00:00
  // Reason: Helper to return Material icon for vehicle type on OSM markers
  IconData _osmVehicleIcon(String carType) {
    final ct = carType.toLowerCase();
    if (ct.contains('bike') || ct.contains('moto') || ct.contains('scooter')) return Icons.motorcycle_rounded;
    if (ct.contains('auto') || ct.contains('rickshaw') || ct.contains('three')) return Icons.electric_rickshaw_rounded;
    if (ct.contains('suv') || ct.contains('xl') || ct.contains('van')) return Icons.airport_shuttle_rounded;
    if (ct.contains('truck') || ct.contains('parcel') || ct.contains('dost')) return Icons.local_shipping_rounded;
    if (ct.contains('sedan') || ct.contains('hatchback') || ct.contains('premium') || ct.contains('luxury')) return Icons.directions_car_rounded;
    return Icons.local_taxi_rounded;
  }

  // Modified by Jayant Pandit on 2026-07-10 08:00:00
  // Reason: Helper to return color for vehicle type on OSM markers
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
}
