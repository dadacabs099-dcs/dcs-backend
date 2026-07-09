import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:Dadacabs/View/Screens/Main_Screens/Parcel_Screen/parcel_providers.dart';
import 'package:Dadacabs/View/Themes/indian_heritage_theme.dart';
import 'package:Dadacabs/Container/Providers/theme_provider.dart';

class ParcelTrackingScreen extends ConsumerWidget {
  const ParcelTrackingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Size size = MediaQuery.sizeOf(context);
    final parcelDelivery = ref.watch(activeParcelDeliveryProvider);
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;

    if (parcelDelivery == null) {
      return Scaffold(
        backgroundColor: isDark ? IndianHeritageColors.darkBackground : IndianHeritageColors.marbleWhite,
        body: Center(
          child: Text(
            "No active delivery",
            style: TextStyle(
              color: isDark ? Colors.white : IndianHeritageColors.charcoal,
              fontSize: 16,
            ),
          ),
        ),
      );
    }

    final status = parcelDelivery['status'] as String;
    final type = parcelDelivery['type'] as String;
    final price = parcelDelivery['price'] as double;

    return Scaffold(
      backgroundColor: isDark ? IndianHeritageColors.darkBackground : IndianHeritageColors.marbleWhite,
      body: SafeArea(
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.arrow_back, 
                        color: isDark ? Colors.white : IndianHeritageColors.charcoal,
                      ),
                      onPressed: () => context.pop(),
                    ),
                    Expanded(
                      child: Text(
                        "Track Delivery",
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall!.copyWith(
                          fontFamily: "bold",
                          fontSize: 18,
                          color: isDark ? Colors.white : IndianHeritageColors.charcoal,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),

              // Status Card
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: IndianHeritageColors.primaryYellow.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: IndianHeritageColors.primaryYellow.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    Icon(
                      type == 'bike' ? Icons.pedal_bike : Icons.local_shipping,
                      size: 50,
                      color: IndianHeritageColors.primaryYellow,
                    ),
                    const SizedBox(height: 15),
                    Text(
                      _getStatusText(status),
                      style: Theme.of(context).textTheme.bodySmall!.copyWith(
                        fontFamily: "bold",
                        fontSize: 20,
                        color: isDark ? Colors.white : IndianHeritageColors.charcoal,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      "Your package is on the way",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // Progress Steps
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildProgressSteps(context, status, isDark),
              ),

              const Spacer(),

              // Delivery Details
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? IndianHeritageColors.darkCard : Colors.white,
                  border: Border(
                    top: BorderSide(
                      color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[200]!,
                    ),
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Delivery Details",
                      style: Theme.of(context).textTheme.bodySmall!.copyWith(
                        fontFamily: "bold",
                        fontSize: 16,
                        color: isDark ? Colors.white : IndianHeritageColors.charcoal,
                      ),
                    ),
                    const SizedBox(height: 15),
                    _buildDetailRow(
                      context,
                      "Delivery ID",
                      "#${parcelDelivery['id']?.toString().substring(0, 8) ?? 'N/A'}",
                      isDark,
                    ),
                    _buildDetailRow(
                      context,
                      "Vehicle Type",
                      type == 'bike' ? 'Bike' : 'Truck',
                      isDark,
                    ),
                    _buildDetailRow(
                      context,
                      "Package Weight",
                      parcelDelivery['weight'] ?? 'N/A',
                      isDark,
                    ),
                    _buildDetailRow(
                      context,
                      "Amount",
                      "₹${price.toStringAsFixed(0)}",
                      isDark,
                    ),
                    const SizedBox(height: 20),
                    
                    // Cancel Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton(
                        onPressed: () {
                          // Cancel delivery
                          ref.read(activeParcelDeliveryProvider.notifier).state = null;
                          context.pop();
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text(
                          "Cancel Delivery",
                          style: TextStyle(
                            color: Colors.red,
                            fontFamily: "bold",
                            fontSize: 15,
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
      ),
    );
  }

  Widget _buildProgressSteps(BuildContext context, String status, bool isDark) {
    final steps = [
      {'icon': Icons.check_circle, 'label': 'Booked'},
      {'icon': Icons.local_shipping, 'label': 'Picked Up'},
      {'icon': Icons.directions_bike, 'label': 'In Transit'},
      {'icon': Icons.home, 'label': 'Delivered'},
    ];

    int currentStep = 0;
    switch (status) {
      case 'searching_driver':
        currentStep = 0;
        break;
      case 'driver_assigned':
        currentStep = 0;
        break;
      case 'picked_up':
        currentStep = 1;
        break;
      case 'in_transit':
        currentStep = 2;
        break;
      case 'delivered':
        currentStep = 3;
        break;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: steps.asMap().entries.map((entry) {
        final index = entry.key;
        final step = entry.value;
        final isCompleted = index <= currentStep;
        final isCurrent = index == currentStep;

        return Expanded(
          child: Column(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isCompleted ? IndianHeritageColors.primaryYellow : (isDark ? Colors.grey[850] : Colors.grey[200]),
                  shape: BoxShape.circle,
                  border: isCurrent
                      ? Border.all(
                          color: isDark ? Colors.white : IndianHeritageColors.charcoal, 
                          width: 2,
                        )
                      : null,
                ),
                child: Icon(
                  step['icon'] as IconData,
                  color: isCompleted 
                      ? Colors.black 
                      : (isDark ? Colors.grey[600] : Colors.grey[400]),
                  size: 20,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                step['label'] as String,
                style: TextStyle(
                  fontSize: 10,
                  fontFamily: isCurrent ? "bold" : null,
                  color: isCompleted 
                      ? (isDark ? Colors.white : IndianHeritageColors.charcoal) 
                      : Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodySmall!.copyWith(
              fontFamily: "bold",
              fontSize: 14,
              color: isDark ? Colors.white : IndianHeritageColors.charcoal,
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'searching_driver':
        return "Finding Driver...";
      case 'driver_assigned':
        return "Driver Assigned";
      case 'picked_up':
        return "Package Picked Up";
      case 'in_transit':
        return "In Transit";
      case 'delivered':
        return "Delivered";
      default:
        return "Processing...";
    }
  }
}
