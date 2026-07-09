import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:Dadacabs/View/Routes/routes.dart';
import 'package:Dadacabs/View/Screens/Main_Screens/Parcel_Screen/parcel_providers.dart';
import 'package:Dadacabs/View/Themes/indian_heritage_theme.dart';
import 'package:Dadacabs/Container/Providers/theme_provider.dart';
import 'package:Dadacabs/View/Widgets/heritage_background_wrapper.dart';

class ParcelConfirmScreen extends ConsumerWidget {
  const ParcelConfirmScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Size size = MediaQuery.sizeOf(context);
    final deliveryType = ref.watch(parcelDeliveryTypeProvider);
    final senderAddress = ref.watch(parcelSenderAddressProvider);
    final receiverAddress = ref.watch(parcelReceiverAddressProvider);
    final receiverPhone = ref.watch(parcelReceiverPhoneProvider);
    final description = ref.watch(parcelDescriptionProvider);
    final weight = ref.watch(parcelWeightProvider);
    final estimatedPrice = ref.watch(parcelEstimatedPriceProvider);
    final isLoading = ref.watch(parcelBookingLoadingProvider);
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;

    return Scaffold(
      backgroundColor: isDark ? IndianHeritageColors.darkBackground : IndianHeritageColors.marbleWhite,
      appBar: AppBar(
        backgroundColor: IndianHeritageColors.primaryYellow,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: IndianHeritageColors.charcoal),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          "Confirm Delivery",
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 20,
            color: IndianHeritageColors.charcoal,
          ),
        ),
      ),
      body: SafeArea(
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Delivery Type Card
                      _buildInfoCard(
                        context,
                        title: "Delivery Type",
                        content: deliveryType == 'bike' ? 'Send by Bike' : 'Send by Truck',
                        icon: deliveryType == 'bike' ? Icons.pedal_bike : Icons.local_shipping,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 15),

                      // Sender Address
                      _buildInfoCard(
                        context,
                        title: "Sender Address",
                        content: senderAddress.isEmpty ? 'Not specified' : senderAddress,
                        icon: Icons.location_on,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 15),

                      // Receiver Address
                      _buildInfoCard(
                        context,
                        title: "Receiver Address",
                        content: receiverAddress.isEmpty ? 'Not specified' : receiverAddress,
                        icon: Icons.location_on_outlined,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 15),

                      // Receiver Phone
                      _buildInfoCard(
                        context,
                        title: "Receiver Phone",
                        content: receiverPhone.isEmpty ? 'Not specified' : receiverPhone,
                        icon: Icons.phone,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 15),

                      // Package Details
                      _buildInfoCard(
                        context,
                        title: "Package Details",
                        content: '${description.isEmpty ? 'No description' : description}\nWeight: $weight',
                        icon: Icons.inventory_2_outlined,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 30),

                      // Price Section
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: IndianHeritageColors.primaryYellow.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: IndianHeritageColors.primaryYellow.withOpacity(0.3)),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              "Estimated Price",
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              "₹${estimatedPrice.toStringAsFixed(0)}",
                              style: Theme.of(context).textTheme.bodySmall!.copyWith(
                                fontFamily: "bold",
                                fontSize: 36,
                                color: Colors.green,
                              ),
                            ),
                            const SizedBox(height: 5),
                            const Text(
                              "Final price may vary based on distance",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom Button panel
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
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: HeritageButton(
                        text: "Book Delivery",
                        isLoading: isLoading,
                        onPressed: isLoading
                            ? null
                            : () async {
                                ref.read(parcelBookingLoadingProvider.notifier).state = true;
                                
                                // Simulate booking process
                                await Future.delayed(const Duration(seconds: 2));
                                
                                // Create parcel delivery data
                                final parcelData = {
                                  'id': DateTime.now().millisecondsSinceEpoch.toString(),
                                  'type': deliveryType,
                                  'senderAddress': senderAddress,
                                  'receiverAddress': receiverAddress,
                                  'receiverPhone': receiverPhone,
                                  'description': description,
                                  'weight': weight,
                                  'price': estimatedPrice,
                                  'status': 'searching_driver',
                                  'createdAt': DateTime.now().toIso8601String(),
                                };
                                
                                ref.read(activeParcelDeliveryProvider.notifier).state = parcelData;
                                ref.read(parcelBookingLoadingProvider.notifier).state = false;
                                
                                if (context.mounted) {
                                  context.pushNamed(Routes().parcelTracking);
                                }
                              },
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

  Widget _buildInfoCard(
    BuildContext context, {
    required String title,
    required String content,
    required IconData icon,
    required bool isDark,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: isDark ? IndianHeritageColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[200]!,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: IndianHeritageColors.primaryYellow, size: 24),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  content,
                  style: Theme.of(context).textTheme.bodySmall!.copyWith(
                    fontSize: 14,
                    color: isDark ? Colors.white : IndianHeritageColors.charcoal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
