import 'dart:async';
import 'package:flutter/material.dart' hide Text;
import 'package:Dadacabs/View/Widgets/translated_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:Dadacabs/Container/utils/firebase_messaging.dart';
import 'package:Dadacabs/Container/utils/set_blackmap.dart';
import 'package:Dadacabs/View/Routes/routes.dart';
import 'package:Dadacabs/View/Screens/Main_Screens/Home_Screen/home_logics.dart';
import 'package:Dadacabs/View/Screens/Main_Screens/Home_Screen/home_providers.dart';
import 'package:Dadacabs/View/Screens/Nav_Screens/navigation_providers.dart';
import 'package:Dadacabs/View/Themes/indian_heritage_theme.dart';
import 'package:Dadacabs/Container/Providers/theme_provider.dart';
import 'package:Dadacabs/View/Components/active_trip_banner.dart';
import 'package:Dadacabs/Container/Providers/user_data_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final TextEditingController whereToController = TextEditingController();
  CameraPosition initpos = const CameraPosition(target: LatLng(19.0760, 72.8777), zoom: 14);

  final Completer<GoogleMapController> completer = Completer();
  GoogleMapController? controller;  
  // Location service monitoring
  StreamSubscription<ServiceStatus>? _serviceStatusSubscription;
  bool _isLocationDialogOpen = false;
  @override
  void initState() {
    super.initState();
    MessagingService().init(context, ref);
    _setInitialPayment();
    _initializeLocationMonitoring();
  }

  void _setInitialPayment() {
    // We'll use a post-frame callback to avoid build conflicts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(userDataProvider);
      if (user != null && user.preferredPaymentMethod != null) {
        ref.read(homeScreenSelectedPaymentProvider.notifier).state = user.preferredPaymentMethod!;
      }
    });
  }

  void _initializeLocationMonitoring() {
    // Monitor location service status
    _serviceStatusSubscription = Geolocator.getServiceStatusStream().listen((ServiceStatus status) {
      if (status == ServiceStatus.disabled) {
        _showLocationRequiredDialog();
      }
    });
  }

  Future<bool> _checkLocationServiceAndPrompt() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showLocationRequiredDialog();
      return false;
    }
    return true;
  }

  void _showLocationRequiredDialog() {
    if (_isLocationDialogOpen) return;
    _isLocationDialogOpen = true;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.location_off_rounded, color: Colors.redAccent, size: 28),
                SizedBox(width: 12),
                Text('GPS Required', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            content: const Text(
              'Location services (GPS) are disabled. This app requires active location services to show your location on the map. Please enable phone location to proceed.',
              style: TextStyle(fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  await Geolocator.openLocationSettings();
                },
                child: const Text('OPEN SETTINGS', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
              ),
              TextButton(
                onPressed: () async {
                  bool enabled = await Geolocator.isLocationServiceEnabled();
                  if (enabled) {
                    _isLocationDialogOpen = false;
                    if (context.mounted) Navigator.pop(context);
                  } else {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enable location services')),
                      );
                    }
                  }
                },
                child: const Text('RETRY', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    ).then((_) {
      _isLocationDialogOpen = false;
    });
  }

  @override
  void dispose() {
    controller?.dispose();
    _serviceStatusSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final dropOffLocation = ref.watch(homeScreenDropOffLocationProvider);
    final pickUpLocation = ref.watch(homeScreenPickUpLocationProvider);

    ref.listen<ThemeMode>(themeModeProvider, (previous, next) {
      if (controller != null) {
        if (next == ThemeMode.dark) {
          SetBlackMap().setBlackMapTheme(controller!);
        } else {
          controller!.setMapStyle(null);
        }
      }
    });

    return Scaffold(
      body: Stack(
        children: [
          // ── Map ─────────────────────────────────────────────────────────
          GoogleMap(
            mapType: MapType.normal,
            myLocationButtonEnabled: false,
            trafficEnabled: true,
            compassEnabled: false,
            buildingsEnabled: true,
            myLocationEnabled: true,
            zoomControlsEnabled: false,
            initialCameraPosition: initpos,
            polylines: ref.watch(homeScreenMainPolylinesProvider),
            markers: ref.watch(homeScreenMainMarkersProvider),
            circles: ref.watch(homeScreenMainCirclesProvider),
            onMapCreated: (map) async {
              completer.complete(map);
              controller = map;
              if (isDark) SetBlackMap().setBlackMapTheme(map);
              bool locEnabled = await _checkLocationServiceAndPrompt();
              if (locEnabled && context.mounted) {
                HomeScreenLogics().getUserLoc(context, ref, controller!);
              }
            },
            onCameraMove: (pos) {
              if (dropOffLocation != null) return;
              if (ref.watch(homeScreenCameraMovementProvider) != pos.target) {
                ref.read(homeScreenCameraMovementProvider.notifier).state = pos.target;
              }
            },
            onCameraIdle: () {
              if (dropOffLocation != null) return;
              HomeScreenLogics().getAddressfromCordinates(context, ref);
            },
          ),

          // ── Center Pin ──────────────────────────────────────────────────
          if (dropOffLocation == null)
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
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        "PICKUP HERE",
                        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const Icon(Icons.location_on_rounded, size: 45, color: Colors.black),
                  ],
                ),
              ),
            ),

          // ── Floating Action Buttons ─────────────────────────────────────
          Positioned(
            top: 50,
            left: 20,
            child: FloatingActionButton.small(
              heroTag: 'drawer_btn',
              onPressed: () => ref.read(navigationScaffoldKeyProvider).currentState?.openDrawer(),
              backgroundColor: isDark ? Colors.grey[900] : Colors.white,
              foregroundColor: isDark ? Colors.white : Colors.black,
              child: const Icon(Icons.menu_rounded),
            ),
          ),

          Positioned(
            top: 50,
            right: 20,
            child: FloatingActionButton.small(
              heroTag: 'loc_btn',
              onPressed: () {
                if (controller != null) HomeScreenLogics().getUserLoc(context, ref, controller!);
              },
              backgroundColor: isDark ? Colors.grey[900] : Colors.white,
              foregroundColor: isDark ? Colors.white : Colors.black,
              child: const Icon(Icons.my_location_rounded),
            ),
          ),

          // ── Active Trip Banner ──────────────────────────────────────────
          const Positioned(
            top: 100,
            left: 0,
            right: 0,
            child: ActiveTripBanner(),
          ),

          // ── Bottom Sheet ────────────────────────────────────────────────
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: size.width,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
              decoration: BoxDecoration(
                color: isDark ? IndianHeritageColors.darkSurface : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 25, offset: const Offset(0, -5)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Service Type Selector (Rapido/Uber Style)
                  SizedBox(
                    height: 110,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _serviceItem(0, "Bike", 'assets/imgs/motorbike.png', Icons.motorcycle_rounded, isDark),
                        _serviceItem(1, "Auto", 'assets/imgs/auto.png', Icons.electric_rickshaw_rounded, isDark),
                        _serviceItem(2, "Dada Cab", 'assets/imgs/sedan.png', Icons.local_taxi_rounded, isDark),
                        _serviceItem(3, "Dada XL", 'assets/imgs/suv.png', Icons.airport_shuttle_rounded, isDark),
                        _serviceItem(4, "Intercity", 'assets/imgs/intercity.png', Icons.map_rounded, isDark),
                        _serviceItem(5, "Parcel", 'assets/imgs/parcel.png', Icons.inventory_2_rounded, isDark),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Location Input Section
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[900] : const Color(0xFFF8F8F8),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
                    ),
                    child: Column(
                      children: [
                        // Pickup Field
                        _locationRow(
                          context: context,
                          label: "PICKUP",
                          address: pickUpLocation?.humanReadableAddress ?? "Locating...",
                          icon: Icons.circle,
                          iconColor: Colors.green,
                          onTap: () => HomeScreenLogics().changePickUpLoc(context, ref, controller!),
                          isDark: isDark,
                        ),

                        Padding(
                          padding: const EdgeInsets.only(left: 36),
                          child: Divider(height: 32, thickness: 1, color: isDark ? Colors.grey[800] : Colors.grey[300]),
                        ),

                        // Drop-off Field
                        _locationRow(
                          context: context,
                          label: "WHERE TO?",
                          address: dropOffLocation?.locationName ?? "Enter destination",
                          icon: Icons.square,
                          iconColor: IndianHeritageColors.primaryYellow,
                          onTap: () async {
                            await context.pushNamed(Routes().whereTo, extra: controller);
                            if (context.mounted) {
                              HomeScreenLogics().openWhereToScreen(context, ref, controller!);
                            }
                          },
                          isDark: isDark,
                          isHighlight: dropOffLocation == null,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                  _buildPaymentSelector(context, ref, isDark),
                  const SizedBox(height: 20),

                  // Action Button
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      onPressed: () {
                        if (dropOffLocation == null) {
                          context.pushNamed(Routes().whereTo, extra: controller);
                        } else {
                          context.pushNamed(Routes().bookingSummary, extra: controller);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: IndianHeritageColors.primaryYellow,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: TranslatedText(
                        dropOffLocation == null ? "Select Destination" : "Confirm Journey",
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _serviceItem(int index, String title, String assetPath, IconData fallbackIcon, bool isDark) {
    final selectedIndex = ref.watch(homeScreenSelectedRideProvider) ?? 0;
    final active = selectedIndex == index;

    return Container(
      width: 90,
      margin: const EdgeInsets.only(right: 12),
      child: InkWell(
        onTap: () => ref.read(homeScreenSelectedRideProvider.notifier).state = index,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: active ? IndianHeritageColors.primaryYellow.withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: active ? IndianHeritageColors.primaryYellow : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                fallbackIcon, 
                size: 32, 
                color: active ? IndianHeritageColors.primaryYellow : Colors.grey[400]
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: active ? FontWeight.w900 : FontWeight.bold,
                  color: active ? (isDark ? Colors.white : Colors.black) : Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentSelector(BuildContext context, WidgetRef ref, bool isDark) {
    final selectedPayment = ref.watch(homeScreenSelectedPaymentProvider);
    final user = ref.watch(userDataProvider);

    return InkWell(
      onTap: () => _showPaymentOptions(context, ref, isDark),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[900] : const Color(0xFFF8F8F8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
        ),
        child: Row(
          children: [
            Icon(
              selectedPayment == 'cash' 
                  ? Icons.money_rounded 
                  : selectedPayment == 'wallet' 
                      ? Icons.account_balance_wallet_rounded 
                      : selectedPayment == 'card'
                          ? Icons.credit_card_rounded
                          : selectedPayment == 'upi_app'
                              ? Icons.app_shortcut_rounded
                              : Icons.qr_code_rounded,
              color: IndianHeritageColors.primaryYellow,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    TranslatedText(
                      'PAYMENT METHOD',
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.grey[500], letterSpacing: 0.5),
                    ),
                  Text(
                    selectedPayment.replaceAll('_', ' ').toUpperCase(),
                    style: TextStyle(
                      fontSize: 14, 
                      fontWeight: FontWeight.w900, 
                      color: isDark ? Colors.white : Colors.black
                    ),
                  ),
                ],
              ),
            ),
            if (selectedPayment == 'wallet')
              Text(
                "₹${user?.walletBalance?.toStringAsFixed(0) ?? '0'}",
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 13),
              ),
            const SizedBox(width: 8),
            Icon(Icons.keyboard_arrow_up_rounded, size: 20, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  void _showPaymentOptions(BuildContext context, WidgetRef ref, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? IndianHeritageColors.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const TranslatedText(
                'Select Payment Method',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 20),
              _paymentOptionItem(ref, 'cash', 'Cash', Icons.money_rounded, isDark),
              _paymentOptionItem(ref, 'wallet', 'Wallet', Icons.account_balance_wallet_rounded, isDark),
              _paymentOptionItem(ref, 'card', 'Credit/Debit Card', Icons.credit_card_rounded, isDark),
              _paymentOptionItem(ref, 'upi_app', 'UPI App (GPay, PhonePe)', Icons.app_shortcut_rounded, isDark),
              _paymentOptionItem(ref, 'upi_vpa', 'UPI ID (VPA)', Icons.qr_code_rounded, isDark),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _paymentOptionItem(WidgetRef ref, String value, String title, IconData icon, bool isDark) {
    final selected = ref.watch(homeScreenSelectedPaymentProvider) == value;
    return ListTile(
      onTap: () {
        ref.read(homeScreenSelectedPaymentProvider.notifier).state = value;
        Navigator.pop(context);
      },
      leading: Icon(icon, color: selected ? IndianHeritageColors.primaryYellow : Colors.grey),
      title: TranslatedText(
        title,
        style: TextStyle(
          fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
          color: selected ? IndianHeritageColors.primaryYellow : (isDark ? Colors.white : Colors.black),
        ),
      ),
      trailing: selected ? const Icon(Icons.check_circle_rounded, color: IndianHeritageColors.primaryYellow) : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Widget _locationRow({
    required BuildContext context,
    required String label,
    required String address,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
    required bool isDark,
    bool isHighlight = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 14, color: iconColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TranslatedText(
                  label,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.grey[500], letterSpacing: 0.5),
                ),
                const SizedBox(height: 2),
                Text(
                  address,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: isHighlight ? FontWeight.w900 : FontWeight.w600,
                    color: isHighlight ? (isDark ? Colors.white : Colors.black) : (isDark ? Colors.grey[400] : Colors.grey[700]),
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey[400]),
        ],
      ),
    );
  }
}
