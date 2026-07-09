import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:Dadacabs/View/Widgets/translated_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:Dadacabs/Model/direction_model.dart';
import 'package:Dadacabs/View/Themes/indian_heritage_theme.dart';
import 'package:Dadacabs/Container/Providers/theme_provider.dart';
import 'package:Dadacabs/View/Screens/Main_Screens/Home_Screen/home_providers.dart';
import 'package:Dadacabs/Container/utils/keys.dart';

class PickupScreenModern extends ConsumerStatefulWidget {
  const PickupScreenModern({super.key});

  @override
  ConsumerState<PickupScreenModern> createState() => _PickupScreenModernState();
}

class _PickupScreenModernState extends ConsumerState<PickupScreenModern> {
  late TextEditingController _searchController;
  GoogleMapController? _mapController;
  bool _showSuggestions = false;
  bool _isLoadingSuggestions = false;
  List<Map<String, dynamic>> _placeSuggestions = [];
  LatLng? _selectedPickup;
  LatLng? _currentLocation;
  final Dio _dio = Dio();

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    // Get current pickup from provider
    final currentPickup = ref.read(homeScreenPickUpLocationProvider);
    if (currentPickup != null) {
      _searchController.text = currentPickup.humanReadableAddress ?? '';
      _selectedPickup = LatLng(
        currentPickup.locationLatitude ?? 0.0,
        currentPickup.locationLongitude ?? 0.0,
      );
    }
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _dio.close();
    super.dispose();
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
      print("PickupScreen: Error getting current location: $e");
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
      print("PickupScreen: Autocomplete error: $e");
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
          _selectedPickup = LatLng(lat, lng);
          _showSuggestions = false;
          _placeSuggestions = [];
        });
        _mapController?.animateCamera(CameraUpdate.newLatLng(_selectedPickup!));
      } else {
        // Fallback: use geocoding API to resolve coordinates
        await _geocodeAndSelect(description);
      }
    } catch (e) {
      print("PickupScreen: Place details error: $e");
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
          _selectedPickup = LatLng(lat, lng);
          _showSuggestions = false;
          _placeSuggestions = [];
        });
        _mapController?.animateCamera(CameraUpdate.newLatLng(_selectedPickup!));
      }
    } catch (e) {
      print("PickupScreen: Geocode fallback error: $e");
    }
  }

  void _updateSuggestions(String query) {
    _fetchPlacePredictions(query);
  }

  void _selectPickup(String name, String address, double lat, double lng) {
    setState(() {
      _searchController.text = name;
      _selectedPickup = LatLng(lat, lng);
      _showSuggestions = false;
      _placeSuggestions = [];
    });
    _mapController?.animateCamera(
      CameraUpdate.newLatLng(_selectedPickup!),
    );
  }

  void _confirmPickup() {
    if (_selectedPickup != null && _searchController.text.isNotEmpty) {
      // Update the pickup location in the provider using Direction model
      final pickupLocation = Direction(
        locationLatitude: _selectedPickup!.latitude,
        locationLongitude: _selectedPickup!.longitude,
        humanReadableAddress: _searchController.text,
        locationName: _searchController.text,
      );
      ref
          .read(homeScreenPickUpLocationProvider.notifier)
          .update((state) => pickupLocation);

      // Navigate back
      context.pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a pickup location')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final bool isDesktop = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.linux ||
            defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.macOS);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Background Map ────────────────────────────────────────────
          isDesktop
              ? _buildDesktopMapPlaceholder(isDark)
              : GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _selectedPickup ?? _currentLocation ?? const LatLng(0.0, 0.0),
                    zoom: 15,
                  ),
                  markers: {
                    if (_selectedPickup != null)
                      Marker(
                        markerId: const MarkerId('pickup'),
                        position: _selectedPickup!,
                        infoWindow: const InfoWindow(title: 'Pickup Location'),
                        icon: BitmapDescriptor.defaultMarkerWithHue(
                          BitmapDescriptor.hueGreen,
                        ),
                      ),
                  },
                  onMapCreated: (controller) {
                    _mapController = controller;
                  },
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  compassEnabled: false,
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
                color: isDark
                    ? IndianHeritageColors.darkBackground
                    : Colors.white,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              child: Column(
                children: [
                  // ── Padding for status bar ────────────────────────────
                  SizedBox(
                      height: MediaQuery.of(context).padding.top + 16),

                  // ── Search Input ──────────────────────────────────────
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[900] : Colors.grey[100],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark
                              ? Colors.grey[800]!
                              : Colors.grey[300]!,
                        ),
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: _updateSuggestions,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontSize: 16,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Pickup Location',
                          hintStyle: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                          border: InputBorder.none,
                          prefixIcon: const Icon(
                            Icons.location_on_rounded,
                            color: Colors.green,
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
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 14),
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
                          _quickActionChip(Icons.my_location_rounded, "Current Location", isDark),
                        ],
                      ),
                    ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          // ── Confirm Button (Bottom) ────────────────────────────────────
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: ElevatedButton(
              onPressed: _confirmPickup,
              style: ElevatedButton.styleFrom(
                backgroundColor: IndianHeritageColors.primaryYellow,
                foregroundColor: IndianHeritageColors.charcoal,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 8,
              ),
              child: const TranslatedText(
                'Confirm Pickup',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopMapPlaceholder(bool isDark) {
    return Container(
      color: isDark ? Colors.grey[900] : Colors.grey[100],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.map_rounded,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 20),
            TranslatedText(
              'Map Preview',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            const SizedBox(height: 8),
            TranslatedText(
              'Desktop preview - Maps work on mobile',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
          ],
        ),
      ),
    );
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
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black87,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          place['secondaryText'] ?? '',
          style: TextStyle(
            fontSize: 12,
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
              _selectedPickup = _currentLocation;
              _searchController.text = "Current Location";
            });
            _mapController?.animateCamera(CameraUpdate.newLatLng(_currentLocation!));
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
              Icon(icon, size: 24, color: Colors.green),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.grey[700]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}