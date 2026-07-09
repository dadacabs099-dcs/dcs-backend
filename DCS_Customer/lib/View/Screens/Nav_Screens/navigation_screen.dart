import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:Dadacabs/View/Screens/Main_Screens/Home_Screen/home_screen_modern.dart';
import 'package:Dadacabs/View/Screens/Main_Screens/History_Screen/history_screen.dart';
import 'package:Dadacabs/View/Screens/Main_Screens/Payment_Screen/payment_screen_modern.dart';
import 'package:Dadacabs/View/Screens/Main_Screens/Profile_Screen/profile_screen.dart';
import 'package:Dadacabs/View/Screens/Nav_Screens/navigation_providers.dart';
import 'package:Dadacabs/View/Screens/Nav_Screens/widgets/customer_drawer.dart';
import 'package:Dadacabs/View/Themes/indian_heritage_theme.dart';
import 'package:Dadacabs/Container/Providers/theme_provider.dart';

class NavigationScreen extends ConsumerWidget {
  const NavigationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(navigationStateProvider);
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;

    const screens = [
      HomeScreenModern(),
      HistoryScreen(),
      PaymentScreenModern(),
      ProfileScreen(),
    ];

    final navItems = [
      _NavItem(
        icon: Icons.home_outlined,
        selectedIcon: Icons.home_rounded,
        label: "Home",
      ),
      _NavItem(
        icon: Icons.history_outlined,
        selectedIcon: Icons.history_rounded,
        label: "Activity",
      ),
      _NavItem(
        icon: Icons.account_balance_wallet_outlined,
        selectedIcon: Icons.account_balance_wallet_rounded,
        label: "Payments",
      ),
      _NavItem(
        icon: Icons.person_outline_rounded,
        selectedIcon: Icons.person_rounded,
        label: "Account",
      ),
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      key: ref.watch(navigationScaffoldKeyProvider),
      drawer: const CustomerDrawer(),
      body: IndexedStack(
        index: selectedIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? IndianHeritageColors.darkSurface : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(navItems.length, (index) {
                final item = navItems[index];
                final isSelected = selectedIndex == index;
                return GestureDetector(
                  onTap: () => ref
                      .read(navigationStateProvider.notifier)
                      .update((_) => index),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? IndianHeritageColors.primaryYellow.withOpacity(isDark ? 0.2 : 1.0)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          isSelected ? item.selectedIcon : item.icon,
                          color: isSelected
                              ? (isDark ? IndianHeritageColors.primaryYellow : Colors.black)
                              : (isDark ? Colors.grey[500] : Colors.grey[600]),
                          size: 24,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected
                              ? (isDark ? IndianHeritageColors.primaryYellow : Colors.black)
                              : (isDark ? Colors.grey[500] : Colors.grey[600]),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  const _NavItem({required this.icon, required this.selectedIcon, required this.label});
}
