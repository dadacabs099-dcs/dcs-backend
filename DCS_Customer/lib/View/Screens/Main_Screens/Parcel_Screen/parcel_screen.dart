import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:Dadacabs/View/Routes/routes.dart';
import 'package:Dadacabs/View/Screens/Main_Screens/Parcel_Screen/parcel_providers.dart';
import 'package:Dadacabs/View/Themes/indian_heritage_theme.dart';
import 'package:Dadacabs/Container/Providers/theme_provider.dart';
import 'package:Dadacabs/View/Widgets/heritage_background_wrapper.dart';

class ParcelScreen extends ConsumerWidget {
  const ParcelScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Size size = MediaQuery.sizeOf(context);
    final selectedType = ref.watch(parcelDeliveryTypeProvider);
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
          "Send a Package",
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
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with logo
                  Center(
                    child: Image.asset(
                      'assets/imgs/logo.png',
                      width: size.width * 0.4,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 30),
                  
                  // Title
                  Text(
                    "Send a Package",
                    style: Theme.of(context).textTheme.bodySmall!.copyWith(
                      fontFamily: "bold",
                      fontSize: 24,
                      color: isDark ? Colors.white : IndianHeritageColors.charcoal,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "Choose your delivery vehicle",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Delivery Type Selection
                  Row(
                    children: [
                      // Bike Option
                      Expanded(
                        child: _buildDeliveryOption(
                          context,
                          ref,
                          type: 'bike',
                          icon: Icons.pedal_bike,
                          title: 'Send by Bike',
                          subtitle: 'Small packages\nUp to 5kg',
                          price: '₹30-50',
                          isSelected: selectedType == 'bike',
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 15),
                      // Truck Option
                      Expanded(
                        child: _buildDeliveryOption(
                          context,
                          ref,
                          type: 'truck',
                          icon: Icons.local_shipping,
                          title: 'Send by Truck',
                          subtitle: 'Large packages\nUp to 100kg',
                          price: '₹100-200',
                          isSelected: selectedType == 'truck',
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),

                  // Package Details Section
                  if (selectedType != null) ...[
                    Text(
                      "Package Details",
                      style: Theme.of(context).textTheme.bodySmall!.copyWith(
                        fontFamily: "bold",
                        fontSize: 18,
                        color: isDark ? Colors.white : IndianHeritageColors.charcoal,
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Sender Address
                    _buildAddressInput(
                      context,
                      ref,
                      label: "Sender Address",
                      icon: Icons.location_on,
                      provider: parcelSenderAddressProvider,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 15),
                    
                    // Receiver Address
                    _buildAddressInput(
                      context,
                      ref,
                      label: "Receiver Address",
                      icon: Icons.location_on_outlined,
                      provider: parcelReceiverAddressProvider,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 15),
                    
                    // Receiver Phone
                    _buildTextInput(
                      context,
                      ref,
                      label: "Receiver Phone Number",
                      icon: Icons.phone,
                      provider: parcelReceiverPhoneProvider,
                      keyboardType: TextInputType.phone,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 15),
                    
                    // Package Description
                    _buildTextInput(
                      context,
                      ref,
                      label: "What's in the package?",
                      icon: Icons.inventory_2_outlined,
                      provider: parcelDescriptionProvider,
                      maxLines: 2,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 15),
                    
                    // Package Weight
                    _buildWeightSelector(context, ref, isDark),
                    const SizedBox(height: 30),
                    
                    // Continue Button (Heritage themed)
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: HeritageButton(
                        text: "Continue",
                        onPressed: () {
                          context.pushNamed(Routes().parcelConfirm);
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeliveryOption(
    BuildContext context,
    WidgetRef ref, {
    required String type,
    required IconData icon,
    required String title,
    required String subtitle,
    required String price,
    required bool isSelected,
    required bool isDark,
  }) {
    return InkWell(
      onTap: () {
        ref.read(parcelDeliveryTypeProvider.notifier).state = type;
      },
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: isSelected 
              ? IndianHeritageColors.primaryYellow.withOpacity(0.15) 
              : (isDark ? IndianHeritageColors.darkCard : Colors.white),
          border: Border.all(
            color: isSelected 
                ? IndianHeritageColors.primaryYellow 
                : (isDark ? Colors.white.withOpacity(0.05) : Colors.grey[300]!),
            width: 2,
          ),
          borderRadius: BorderRadius.circular(15),
          boxShadow: isSelected ? [
            BoxShadow(
              color: IndianHeritageColors.primaryYellow.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ] : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: isSelected ? IndianHeritageColors.primaryYellow : Colors.grey,
              size: 35,
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall!.copyWith(
                fontFamily: "bold",
                fontSize: 14,
                color: isSelected 
                    ? IndianHeritageColors.primaryYellow 
                    : (isDark ? Colors.white : IndianHeritageColors.charcoal),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall!.copyWith(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              price,
              style: Theme.of(context).textTheme.bodySmall!.copyWith(
                fontFamily: "bold",
                fontSize: 16,
                color: Colors.green,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressInput(
    BuildContext context,
    WidgetRef ref, {
    required String label,
    required IconData icon,
    required StateProvider<String> provider,
    required bool isDark,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? IndianHeritageColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[200]!,
        ),
      ),
      child: TextField(
        onChanged: (value) {
          ref.read(provider.notifier).state = value;
        },
        style: TextStyle(
          color: isDark ? Colors.white : IndianHeritageColors.charcoal,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.grey),
          prefixIcon: Icon(icon, color: IndianHeritageColors.primaryYellow),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(15),
        ),
      ),
    );
  }

  Widget _buildTextInput(
    BuildContext context,
    WidgetRef ref, {
    required String label,
    required IconData icon,
    required StateProvider<String> provider,
    required bool isDark,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? IndianHeritageColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[200]!,
        ),
      ),
      child: TextField(
        onChanged: (value) {
          ref.read(provider.notifier).state = value;
        },
        style: TextStyle(
          color: isDark ? Colors.white : IndianHeritageColors.charcoal,
        ),
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.grey),
          prefixIcon: Icon(icon, color: IndianHeritageColors.primaryYellow),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(15),
        ),
      ),
    );
  }

  Widget _buildWeightSelector(BuildContext context, WidgetRef ref, bool isDark) {
    final selectedWeight = ref.watch(parcelWeightProvider);
    final weights = ['1-2 kg', '2-5 kg', '5-10 kg', '10-20 kg', '20+ kg'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Package Weight",
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: weights.map((weight) {
            final isSelected = selectedWeight == weight;
            return ChoiceChip(
              label: Text(weight),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  ref.read(parcelWeightProvider.notifier).state = weight;
                }
              },
              backgroundColor: isDark ? IndianHeritageColors.darkCard : Colors.grey[200],
              selectedColor: IndianHeritageColors.primaryYellow,
              labelStyle: TextStyle(
                color: isSelected 
                    ? Colors.black 
                    : (isDark ? Colors.white : IndianHeritageColors.charcoal),
                fontFamily: isSelected ? "bold" : null,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
