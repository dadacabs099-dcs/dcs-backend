import 'dart:async';
import 'package:flutter/material.dart' hide Text;
import 'package:Dadacabs/View/Widgets/translated_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:Dadacabs/View/Screens/Main_Screens/Active_Trip_Screen/active_trip_providers.dart';
import 'package:Dadacabs/Container/Repositories/trip_repo.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:Dadacabs/Model/trip_model.dart';

import 'package:Dadacabs/View/Themes/indian_heritage_theme.dart';
import 'package:Dadacabs/Container/Providers/theme_provider.dart';
import 'package:Dadacabs/Container/utils/set_blackmap.dart';
import 'package:intl/intl.dart';


class ActiveTripScreen extends ConsumerStatefulWidget {
  final TripModel? trip;

  const ActiveTripScreen({
    super.key,
    required this.trip,
  });

  @override
  ConsumerState<ActiveTripScreen> createState() => _ActiveTripScreenState();
}

class _ActiveTripScreenState extends ConsumerState<ActiveTripScreen> {
  late GoogleMapController _mapController;
  final Completer<GoogleMapController> _mapCompleter = Completer();
  Timer? _updateTimer;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    _initializeMap();
    _startLocationUpdates();
  }

  void _initializeMap() {
    if (widget.trip == null) return;

    // Add pickup marker (green)
    _markers.add(
      Marker(
        markerId: const MarkerId('pickup'),
        position: widget.trip!.pickupLocation,
        infoWindow: InfoWindow(title: 'Pickup: ${widget.trip!.pickupAddress}'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ),
    );

    // Add dropoff marker (red)
    _markers.add(
      Marker(
        markerId: const MarkerId('dropoff'),
        position: widget.trip!.dropoffLocation,
        infoWindow: InfoWindow(title: 'Dropoff: ${widget.trip!.dropoffAddress}'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
    );

    // Add driver marker if available
    if (widget.trip!.driverId != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('driver'),
          position: LatLng(
            widget.trip!.pickupLocation.latitude,
            widget.trip!.pickupLocation.longitude,
          ),
          infoWindow: InfoWindow(
            title: 'Driver: ${widget.trip!.driverName ?? "Driver"}',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );
    }
  }

  void _startLocationUpdates() {
    _updateTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      try {
        if (mounted && _mapController != null) {
          Position position = await Geolocator.getCurrentPosition();
          _mapController.animateCamera(
            CameraUpdate.newLatLng(
              LatLng(position.latitude, position.longitude),
            ),
          );
        }
      } catch (e) {
        print('Error updating location: $e');
      }
    });
  }

  Future<void> _cancelTrip(bool isDark) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? IndianHeritageColors.darkSurface : Colors.white,
        title: const TranslatedText(
          'Cancel Trip?',
          style: TextStyle(
            color: IndianHeritageColors.charcoal,
            fontFamily: 'bold',
          ),
        ),
        content: TranslatedText(
          'Are you sure you want to cancel this trip?',
          style: TextStyle(
            color: isDark ? Colors.white70 : IndianHeritageColors.charcoal,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const TranslatedText('No'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              ref.read(tripActionLoadingProvider.notifier).state = true;
              try {
                await ref.read(globalTripRepoProvider).cancelTrip(
                  widget.trip!.tripId,
                  'Cancelled by user',
                  context,
                );
                if (mounted) {
                  Navigator.pop(context);
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: TranslatedText('Error: $e')),
                  );
                }
              } finally {
                ref.read(tripActionLoadingProvider.notifier).state = false;
              }
            },
            child: const Text('Yes, Cancel Trip', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;

    ref.listen<ThemeMode>(themeModeProvider, (previous, next) {
      if (_mapController != null) {
        if (next == ThemeMode.dark) {
          SetBlackMap().setBlackMapTheme(_mapController);
        } else {
          _mapController.setMapStyle(null);
        }
      }
    });

    if (widget.trip == null) {
      return Scaffold(
        appBar: AppBar(
          title: const TranslatedText('Active Trip'),
          backgroundColor: IndianHeritageColors.primaryYellow,
        ),
        body: Center(
          child: TranslatedText(
            'No active trip',
            style: TextStyle(
              color: isDark ? Colors.white : IndianHeritageColors.charcoal,
            ),
          ),
        ),
      );
    }

    final trip = widget.trip!;
    final isLoading = ref.watch(tripActionLoadingProvider);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: isDark ? IndianHeritageColors.darkBackground : IndianHeritageColors.marbleWhite,
      appBar: AppBar(
        backgroundColor: IndianHeritageColors.primaryYellow,
        elevation: 0,
        title: const TranslatedText(
          'Active Trip',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 20,
            color: IndianHeritageColors.charcoal,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close, color: IndianHeritageColors.charcoal),
            onPressed: isLoading ? null : () => _cancelTrip(isDark),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Map View
            SizedBox(
              height: size.height * 0.45,
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: trip.pickupLocation,
                  zoom: 15,
                ),
                markers: _markers,
                polylines: _polylines,
                onMapCreated: (controller) {
                  if (!_mapCompleter.isCompleted) {
                    _mapCompleter.complete(controller);
                    _mapController = controller;
                  }
                  if (isDark) {
                    SetBlackMap().setBlackMapTheme(controller);
                  }
                },
                myLocationEnabled: true,
                myLocationButtonEnabled: true,
              ),
            ),

            // Trip Details Panel
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? IndianHeritageColors.darkCard : Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                border: Border(
                  top: BorderSide(
                    color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[200]!,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Trip Status
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Color(trip.statusColor).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Color(trip.statusColor),
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      trip.statusText,
                      style: TextStyle(
                        color: Color(trip.statusColor),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Driver Info Card
                  if (trip.driverName != null)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? IndianHeritageColors.darkBackground : Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[200]!,
                        ),
                      ),
                      child: Row(
                        children: [
                          // Driver Avatar
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: IndianHeritageColors.primaryYellow,
                            backgroundImage: trip.driverPhoto != null
                                ? NetworkImage(trip.driverPhoto!)
                                : null,
                            child: trip.driverPhoto == null
                                ? Text(
                                    trip.driverName?[0].toUpperCase() ?? 'D',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      color: IndianHeritageColors.charcoal,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  trip.driverName ?? 'Driver',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : IndianHeritageColors.charcoal,
                                  ),
                                ),
                                if (trip.carName != null)
                                  Text(
                                    trip.carName!,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                if (trip.carPlateNum != null)
                                  Text(
                                    trip.carPlateNum!,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.orange,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.call, color: Colors.green),
                            onPressed: isLoading
                                ? null
                                : () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: TranslatedText('Calling ${trip.driverName}...'),
                                      ),
                                    );
                                  },
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 20),

                  // Route Info
                  _buildRouteInfo(context, trip, isDark),
                  const SizedBox(height: 20),

                  // Trip Details Grid
                  _buildTripDetailsGrid(context, trip, isDark),
                  const SizedBox(height: 20),

                  // Estimated Fare (Dynamic gradient according to active theme!)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark 
                            ? [IndianHeritageColors.charcoal, IndianHeritageColors.darkSurface] 
                            : [IndianHeritageColors.primaryYellow, IndianHeritageColors.deepGold],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      border: Border.all(
                        color: Colors.white.withOpacity(0.15),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        const TranslatedText(
                          'Estimated Fare',
                          style: TextStyle(
                            color: IndianHeritageColors.charcoal,
                            fontSize: 13,
                            fontFamily: 'bold',
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '₹${trip.finalFare?.toStringAsFixed(0) ?? trip.estimatedFare.toStringAsFixed(0)}',
                          style: TextStyle(
                            color: isDark ? IndianHeritageColors.primaryYellow : IndianHeritageColors.charcoal,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'bold',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Emergency SOS / Help Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: isLoading
                          ? null
                          : () {
                              _showEmergencyOptions(context, isDark);
                            },
                      icon: const Icon(Icons.sos, size: 22, color: Colors.white),
                      label: const TranslatedText('Emergency Help (SOS)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        shadowColor: Colors.red.withOpacity(0.3),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
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

  Widget _buildRouteInfo(BuildContext context, TripModel trip, bool isDark) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                const Icon(Icons.circle, color: Colors.green, size: 12),
                Container(
                  width: 2,
                  height: 40,
                  color: isDark ? Colors.grey[700] : Colors.grey[300],
                ),
                const Icon(Icons.location_on, color: Colors.red, size: 16),
              ],
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const TranslatedText(
                    'Pickup',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    trip.pickupAddress,
                    style: TextStyle(
                      color: isDark ? Colors.white : IndianHeritageColors.charcoal,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 25),
                  const TranslatedText(
                    'Dropoff',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    trip.dropoffAddress,
                    style: TextStyle(
                      color: isDark ? Colors.white : IndianHeritageColors.charcoal,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTripDetailsGrid(BuildContext context, TripModel trip, bool isDark) {
    return Row(
      children: [
        Expanded(
          child: _buildDetailCard(
            context,
            icon: Icons.directions,
            value: trip.distanceKm != null
                ? '${trip.distanceKm!.toStringAsFixed(1)} km'
                : 'Calculating',
            label: 'Distance',
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildDetailCard(
            context,
            icon: Icons.schedule,
            value: trip.durationMinutes != null
                ? '${trip.durationMinutes} min'
                : 'Calculating',
            label: 'Duration',
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildDetailCard(
            context,
            icon: Icons.local_taxi,
            value: trip.carType ?? 'Ride',
            label: 'Vehicle',
            isDark: isDark,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailCard(
    BuildContext context, {
    required IconData icon,
    required String value,
    required String label,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? IndianHeritageColors.darkBackground : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[200]!,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: IndianHeritageColors.primaryYellow, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: isDark ? Colors.white : IndianHeritageColors.charcoal,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          TranslatedText(
            label,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 10,
            ),
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
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Need Help?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : IndianHeritageColors.charcoal,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.call, color: Colors.green),
              title: const TranslatedText(
                'Call Support',
                style: TextStyle(color: IndianHeritageColors.charcoal),
              ),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: TranslatedText('Calling support...')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.warning, color: Colors.red),
              title: const TranslatedText(
                'Report Safety Issue',
                style: TextStyle(color: IndianHeritageColors.charcoal),
              ),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: TranslatedText('Issue reported to support')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.message, color: IndianHeritageColors.primaryYellow),
              title: const TranslatedText(
                'Send Message to Driver',
                style: TextStyle(color: IndianHeritageColors.charcoal),
              ),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: TranslatedText('Message sent to driver')),
                );
              },
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const TranslatedText('Cancel', style: TextStyle(color: IndianHeritageColors.primaryYellow)),
            ),
          ],
        ),
      ),
    );
  }
}
