import 'package:flutter/material.dart' hide Text;
import 'package:Dadacabs/View/Widgets/translated_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:Dadacabs/View/Routes/routes.dart';
import 'package:Dadacabs/Model/trip_model.dart';
import 'package:Dadacabs/View/Themes/indian_heritage_theme.dart';
import 'package:Dadacabs/Container/Providers/theme_provider.dart';

class VehicleSelectionScreenModern extends ConsumerStatefulWidget {
  final TripModel trip;

  const VehicleSelectionScreenModern({
    super.key,
    required this.trip,
  });

  @override
  ConsumerState<VehicleSelectionScreenModern> createState() =>
      _VehicleSelectionScreenModernState();
}

class _VehicleSelectionScreenModernState
    extends ConsumerState<VehicleSelectionScreenModern>
    with TickerProviderStateMixin {
  int _selectedVehicleIndex = 0;
  late AnimationController _slideController;

  // Mock vehicle data
  final List<Map<String, dynamic>> _vehicles = [
    {
      'type': 'Bike',
      'icon': Icons.motorcycle_rounded,
      'fare': 45,
      'eta': '2 min',
      'description': 'Solo ride, budget-friendly',
      'seats': 1,
      'available': 5,
      'baseColor': Colors.orange,
    },
    {
      'type': 'Auto',
      'icon': Icons.electric_rickshaw_rounded,
      'fare': 65,
      'eta': '1 min',
      'description': 'Compact 3-seater',
      'seats': 3,
      'available': 12,
      'baseColor': Colors.yellow,
    },
    {
      'type': 'Dada Cab',
      'icon': Icons.local_taxi_rounded,
      'fare': 120,
      'eta': '3 min',
      'description': 'Premium sedan, AC included',
      'seats': 4,
      'available': 8,
      'baseColor': IndianHeritageColors.primaryYellow,
    },
    {
      'type': 'Dada XL',
      'icon': Icons.airport_shuttle_rounded,
      'fare': 180,
      'eta': '4 min',
      'description': 'Spacious SUV for groups',
      'seats': 6,
      'available': 3,
      'baseColor': Colors.blue,
    },
  ];

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _slideController.forward();
    });
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: isDark ? IndianHeritageColors.darkBackground : IndianHeritageColors.marbleWhite,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: isDark ? Colors.white : Colors.black),
          onPressed: () => context.pop(),
        ),
        title: const TranslatedText('Select Ride'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ── Pickup to Dropoff Info ─────────────────────────────────
            Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? IndianHeritageColors.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.location_on_rounded, 
                        color: Colors.green, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TranslatedText(
                              'From',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            TranslatedText(
                              widget.trip.pickupAddress ?? 'Pickup',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Divider(
                      color: isDark ? Colors.grey[800] : Colors.grey[300],
                    ),
                  ),
                  Row(
                    children: [
                      Icon(Icons.location_on_rounded, 
                        color: IndianHeritageColors.primaryYellow, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TranslatedText(
                              'To',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            TranslatedText(
                              widget.trip.dropoffAddress ?? 'Destination',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Trip Details Summary ──────────────────────────────────
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: IndianHeritageColors.primaryYellow.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: IndianHeritageColors.primaryYellow.withOpacity(0.3),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _detailInfo(
                    'Distance',
                    '${widget.trip.distanceKm?.toStringAsFixed(1) ?? "0"} km',
                    Icons.route_rounded,
                  ),
                  Container(
                    width: 1,
                    height: 30,
                    color: IndianHeritageColors.primaryYellow.withOpacity(0.3),
                  ),
                  _detailInfo(
                    'Duration',
                    '${widget.trip.durationMinutes ?? "0"} min',
                    Icons.schedule_rounded,
                  ),
                ],
              ),
            ),

            // ── Vehicle Options ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TranslatedText(
                    'Available Vehicles',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _vehicles.length,
                    itemBuilder: (context, index) {
                      return _buildVehicleCard(
                        index,
                        _vehicles[index],
                        isDark,
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Confirm Selection Button ───────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () {
                    // Create updated trip with vehicle selection
                    final selectedVehicle = _vehicles[_selectedVehicleIndex];
                    final updatedTrip = TripModel(
                      tripId: widget.trip.tripId,
                      userId: widget.trip.userId,
                      driverId: widget.trip.driverId,
                      driverName: widget.trip.driverName,
                      pickupAddress: widget.trip.pickupAddress,
                      dropoffAddress: widget.trip.dropoffAddress,
                      pickupLocation: widget.trip.pickupLocation,
                      dropoffLocation: widget.trip.dropoffLocation,
                      carType: selectedVehicle['type'],
                      carName: selectedVehicle['type'],
                      carPlateNum: widget.trip.carPlateNum,
                      estimatedFare: selectedVehicle['fare'].toDouble(),
                      distanceKm: widget.trip.distanceKm,
                      durationMinutes: widget.trip.durationMinutes,
                      driverPhoto: widget.trip.driverPhoto,
                      createdAt: widget.trip.createdAt,
                      status: widget.trip.status,
                    );

                    context.pushNamed(
                      Routes().bookingSummaryModern,
                      extra: updatedTrip,
                    );
                  },
                  icon: const Icon(Icons.arrow_forward, size: 20),
                  label: const TranslatedText(
                    'Confirm Selection',
                    style: TextStyle(
                      fontSize: 16,
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
                    shadowColor: IndianHeritageColors.primaryYellow.withOpacity(0.4),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _detailInfo(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: IndianHeritageColors.primaryYellow, size: 20),
        const SizedBox(height: 4),
        TranslatedText(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: IndianHeritageColors.charcoal,
          ),
        ),
        TranslatedText(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: IndianHeritageColors.charcoal,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildVehicleCard(int index, Map<String, dynamic> vehicle, bool isDark) {
    final isSelected = index == _selectedVehicleIndex;
    
    return GestureDetector(
      onTap: () {
        setState(() => _selectedVehicleIndex = index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? vehicle['baseColor'].withOpacity(0.15)
              : (isDark ? Colors.grey[900] : Colors.grey[100]),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? vehicle['baseColor']
                : (isDark ? Colors.grey[800]! : Colors.grey[300]!),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: vehicle['baseColor'].withOpacity(0.2),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Stack(
          children: [
            Row(
              children: [
                // ── Vehicle Icon ────────────────────────────────────
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: vehicle['baseColor'].withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Icon(
                      vehicle['icon'] as IconData,
                      size: 32,
                      color: vehicle['baseColor'],
                    ),
                  ),
                ),

                const SizedBox(width: 16),

                // ── Vehicle Info ────────────────────────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TranslatedText(
                            vehicle['type'],
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          TranslatedText(
                            '₹${vehicle['fare']}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: vehicle['baseColor'],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      TranslatedText(
                        vehicle['description'],
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            color: Colors.grey[600],
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          TranslatedText(
                            vehicle['eta'],
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Icon(
                            Icons.people_outline_rounded,
                            color: Colors.grey[600],
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          TranslatedText(
                            '${vehicle['seats']} seats',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // ── Selection Indicator ──────────────────────────────────
            if (isSelected)
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: vehicle['baseColor'],
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ),

            // ── Availability Badge ───────────────────────────────────
            Positioned(
              bottom: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: vehicle['available'] > 0 ? Colors.green : Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TranslatedText(
                  '${vehicle['available']} available',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
