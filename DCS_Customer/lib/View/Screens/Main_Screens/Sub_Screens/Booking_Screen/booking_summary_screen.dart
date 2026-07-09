import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:Dadacabs/View/Widgets/translated_text.dart';
import 'package:Dadacabs/Container/Providers/theme_provider.dart';
import 'package:Dadacabs/View/Screens/Main_Screens/Home_Screen/home_logics.dart';
import 'package:Dadacabs/View/Screens/Main_Screens/Home_Screen/home_providers.dart';
import 'package:Dadacabs/View/Themes/indian_heritage_theme.dart';
import 'package:Dadacabs/Model/vehicle_type_model.dart';
import 'package:Dadacabs/Container/Providers/vehicle_providers.dart';

class BookingSummaryScreen extends ConsumerWidget {
  final GoogleMapController controller;

  const BookingSummaryScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final pickup = ref.watch(homeScreenPickUpLocationProvider);
    final dropoff = ref.watch(homeScreenDropOffLocationProvider);
    final directionDetails = ref.watch(homeScreenDirectionDetailsProvider);
    final rate = ref.watch(homeScreenRateProvider);
    final selectedPayment = ref.watch(homeScreenSelectedPaymentProvider);
    final selectedServiceIndex = ref.watch(homeScreenSelectedRideProvider) ?? 0;

    final vehicleTypesAsync = ref.watch(vehicleTypesStreamProvider);
    final vehicleTypes = vehicleTypesAsync.maybeWhen(
      data: (types) => types.where((t) => t.isActive).toList(),
      orElse: () => VehicleTypeModel.defaults,
    );

    final selectedType = _resolveSelectedVehicleType(selectedServiceIndex, vehicleTypes);
    final travelDistance = directionDetails?.distanceText ?? 'Calculating...';
    final travelDuration = directionDetails?.durationText ?? 'Calculating...';
    final fareText = rate != null ? '₹${rate.toStringAsFixed(0)}' : 'Estimating...';
    final paymentLabel = _formatPaymentMethod(selectedPayment);

    return Scaffold(
      backgroundColor: isDark ? IndianHeritageColors.darkBackground : IndianHeritageColors.marbleWhite,
      appBar: AppBar(
        title: const TranslatedText('Confirm Ride'),
        backgroundColor: IndianHeritageColors.primaryYellow,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              const TranslatedText(
                'Review your ride details before confirming.',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 20),
              _infoCard(
                context,
                title: 'Pickup',
                subtitle: pickup?.humanReadableAddress ?? 'Not set',
                icon: Icons.my_location_rounded,
                iconBg: IndianHeritageColors.success,
                isDark: isDark,
              ),
              const SizedBox(height: 12),
              _infoCard(
                context,
                title: 'Drop-off',
                subtitle: dropoff?.locationName ?? 'Not set',
                icon: Icons.location_on_rounded,
                iconBg: IndianHeritageColors.primaryYellow,
                isDark: isDark,
              ),
              const SizedBox(height: 12),
              _serviceCard(context, selectedType, isDark),
              const SizedBox(height: 12),
              _rideStatsCard(context, travelDistance, travelDuration, fareText, isDark),
              const SizedBox(height: 12),
              _paymentCard(context, paymentLabel, isDark),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 58,
                child: ElevatedButton(
                  onPressed: pickup == null || dropoff == null
                      ? null
                      : () => HomeScreenLogics().requestARide(MediaQuery.of(context).size, context, ref, controller),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: IndianHeritageColors.primaryYellow,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const TranslatedText(
                    'Confirm Ride',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  VehicleTypeModel _resolveSelectedVehicleType(int selectedIndex, List<VehicleTypeModel> vehicleTypes) {
    final mapping = {
      0: 'bike',
      1: 'auto',
      2: 'economy',
      3: 'xl',
      4: 'intercity',
      5: 'truck',
    };
    final selectedId = mapping[selectedIndex] ?? 'economy';
    return vehicleTypes.firstWhere(
      (type) => type.id.toLowerCase() == selectedId || type.name.toLowerCase() == selectedId,
      orElse: () => VehicleTypeModel.defaults.first,
    );
  }

  String _formatPaymentMethod(String selectedPayment) {
    return selectedPayment
        .replaceAll('_', ' ')
        .split(' ')
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  Widget _infoCard(BuildContext context,
      {required String title,
      required String subtitle,
      required IconData icon,
      required Color iconBg,
      required bool isDark}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? IndianHeritageColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.05), blurRadius: 18, offset: const Offset(0, 8)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: iconBg.withOpacity(0.14), shape: BoxShape.circle),
            child: Icon(icon, color: iconBg, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TranslatedText(
                  title,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: isDark ? Colors.white70 : Colors.grey[600]),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? Colors.white : IndianHeritageColors.charcoal),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _serviceCard(BuildContext context, VehicleTypeModel selectedType, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? IndianHeritageColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white24 : Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: IndianHeritageColors.primaryYellow.withOpacity(0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.directions_car_rounded,
              color: IndianHeritageColors.primaryYellow,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  selectedType.name,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: isDark ? Colors.white : IndianHeritageColors.charcoal),
                ),
                const SizedBox(height: 4),
                TranslatedText(
                  '${selectedType.capacity} seats • ${selectedType.baseFare == 0 ? 'Live pricing' : 'Base ₹${selectedType.baseFare.toStringAsFixed(0)}'}',
                  style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.grey[600]),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? Colors.white12 : IndianHeritageColors.primaryYellow.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              selectedType.id.toUpperCase(),
              style: TextStyle(fontWeight: FontWeight.bold, color: IndianHeritageColors.primaryYellow),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rideStatsCard(BuildContext context, String distance, String duration, String fare, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? IndianHeritageColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.05), blurRadius: 18, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TranslatedText(
            'Ride Details',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _metricTile(context, 'Distance', distance, isDark),
              const SizedBox(width: 12),
              _metricTile(context, 'Duration', duration, isDark),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: isDark ? Colors.white10 : Colors.grey.shade200),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const TranslatedText(
                'Estimated Fare',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.grey),
              ),
              Text(
                fare,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: isDark ? Colors.white : IndianHeritageColors.charcoal),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricTile(BuildContext context, String label, String value, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? Colors.white10 : IndianHeritageColors.silver.withOpacity(0.65),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TranslatedText(
              label,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? Colors.white70 : Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: isDark ? Colors.white : IndianHeritageColors.charcoal),
            ),
          ],
        ),
      ),
    );
  }

  Widget _paymentCard(BuildContext context, String paymentLabel, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? IndianHeritageColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: IndianHeritageColors.primaryYellow.withOpacity(0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.wallet_rounded, color: IndianHeritageColors.primaryYellow, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const TranslatedText(
                  'Payment',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.grey),
                ),
                const SizedBox(height: 6),
                Text(
                  paymentLabel,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: isDark ? Colors.white : IndianHeritageColors.charcoal),
                ),
              ],
            ),
          ),
          const Icon(Icons.edit_rounded, size: 22, color: Colors.grey),
        ],
      ),
    );
  }
}
