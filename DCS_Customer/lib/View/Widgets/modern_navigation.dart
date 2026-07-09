import 'package:flutter/material.dart' hide Text;
import 'package:Dadacabs/View/Widgets/translated_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:Dadacabs/View/Themes/indian_heritage_theme.dart';
import 'package:Dadacabs/Container/Providers/theme_provider.dart';
import 'package:Dadacabs/View/Routes/routes.dart';

// ── Navigation State Provider ──────────────────────────────────────────
final navigationIndexProvider = StateProvider<int>((ref) => 0);

class BottomNavItem {
  final String label;
  final IconData icon;
  final String routeName;

  BottomNavItem({
    required this.label,
    required this.icon,
    required this.routeName,
  });
}

/// Modern Bottom Navigation Bar
/// 
/// Provides tab-based navigation between main screens:
/// - Home (main booking screen)
/// - History (past rides)
/// - Profile (user account)
/// - Support (help & support)
class ModernBottomNavigation extends ConsumerWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const ModernBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;

    final navItems = [
      BottomNavItem(
        label: 'Home',
        icon: Icons.home_rounded,
        routeName: Routes().homeModern,
      ),
      BottomNavItem(
        label: 'History',
        icon: Icons.history_rounded,
        routeName: Routes().rideHistory,
      ),
      BottomNavItem(
        label: 'Profile',
        icon: Icons.person_rounded,
        routeName: Routes().profile,
      ),
      BottomNavItem(
        label: 'Support',
        icon: Icons.help_outline_rounded,
        routeName: Routes().supportScreen,
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: isDark ? IndianHeritageColors.darkSurface : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: onTap,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: IndianHeritageColors.primaryYellow,
        unselectedItemColor: Colors.grey[600],
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 11,
        ),
        items: navItems.map((item) {
          return BottomNavigationBarItem(
            icon: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: navItems.indexOf(item) == currentIndex
                    ? IndianHeritageColors.primaryYellow.withOpacity(0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(item.icon),
            ),
            label: item.label,
          );
        }).toList(),
      ),
    );
  }
}

/// Modern Drawer Navigation
/// 
/// Side drawer with user profile and menu options
class ModernDrawerNavigation extends ConsumerWidget {
  const ModernDrawerNavigation({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;

    return Drawer(
      backgroundColor: isDark ? IndianHeritageColors.darkSurface : Colors.white,
      child: Column(
        children: [
          // ── Drawer Header (User Profile) ────────────────────────
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 16,
              left: 16,
              right: 16,
              bottom: 16,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  IndianHeritageColors.primaryYellow.withOpacity(0.9),
                  IndianHeritageColors.deepGold.withOpacity(0.7),
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: IndianHeritageColors.charcoal,
                      child: const Text(
                        'J',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: IndianHeritageColors.primaryYellow,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const TranslatedText(
                            'John Doe',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: IndianHeritageColors.charcoal,
                            ),
                          ),
                          const SizedBox(height: 4),
                          TranslatedText(
                            '+91 98765 43210',
                            style: TextStyle(
                              fontSize: 12,
                              color: IndianHeritageColors.charcoal.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Rating Row
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: IndianHeritageColors.charcoal.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 16),
                      const SizedBox(width: 4),
                      const TranslatedText(
                        '4.8 • 250 rides',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: IndianHeritageColors.charcoal,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Menu Items ──────────────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              children: [
                _drawerMenuTile(
                  context,
                  Icons.home_rounded,
                  'Home',
                  Routes().homeModern,
                  isDark,
                ),
                _drawerMenuTile(
                  context,
                  Icons.history_rounded,
                  'Ride History',
                  Routes().rideHistory,
                  isDark,
                ),
                _drawerMenuTile(
                  context,
                  Icons.wallet_rounded,
                  'Wallet',
                  Routes().paymentModern,
                  isDark,
                ),
                _drawerMenuTile(
                  context,
                  Icons.location_on_rounded,
                  'Saved Addresses',
                  Routes().savedAddresses,
                  isDark,
                ),
                _drawerMenuTile(
                  context,
                  Icons.person_rounded,
                  'Profile',
                  Routes().profile,
                  isDark,
                ),
                const Divider(indent: 16, endIndent: 16),
                _drawerMenuTile(
                  context,
                  Icons.help_outline_rounded,
                  'Help & Support',
                  Routes().supportScreen,
                  isDark,
                ),
                _drawerMenuTile(
                  context,
                  Icons.info_outline_rounded,
                  'About Us',
                  Routes().aboutScreen,
                  isDark,
                ),
                _drawerMenuTile(
                  context,
                  Icons.security_rounded,
                  'Privacy & Terms',
                  Routes().privacyScreen,
                  isDark,
                ),
              ],
            ),
          ),

          // ── Drawer Footer (Settings) ────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                ),
              ),
            ),
            child: Row(
              children: [
                // Dark Mode Toggle
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      ref.read(themeModeProvider.notifier).state = 
                          isDark ? ThemeMode.light : ThemeMode.dark;
                    },
                    child: Row(
                      children: [
                        Icon(
                          isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                          color: IndianHeritageColors.primaryYellow,
                        ),
                        const SizedBox(width: 12),
                        TranslatedText(
                          isDark ? 'Light Mode' : 'Dark Mode',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Logout
                ElevatedButton.icon(
                  onPressed: () {
                    _showLogoutConfirmation(context);
                  },
                  icon: const Icon(Icons.logout, size: 16),
                  label: const TranslatedText('Logout'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _drawerMenuTile(
    BuildContext context,
    IconData icon,
    String label,
    String routeName,
    bool isDark,
  ) {
    return ListTile(
      leading: Icon(icon, color: IndianHeritageColors.primaryYellow, size: 20),
      title: TranslatedText(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : Colors.black87,
        ),
      ),
      onTap: () {
        Navigator.pop(context);
        context.pushNamed(routeName);
      },
    );
  }

  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const TranslatedText('Logout'),
        content: const TranslatedText('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const TranslatedText('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Implement logout logic
              context.go('/login');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const TranslatedText('Logout'),
          ),
        ],
      ),
    );
  }
}

/// Modern App Shell
/// 
/// Wraps screens with bottom navigation and drawer
class ModernAppShell extends ConsumerWidget {
  final Widget child;

  const ModernAppShell({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navIndex = ref.watch(navigationIndexProvider);

    return Scaffold(
      body: child,
      drawer: const ModernDrawerNavigation(),
      bottomNavigationBar: ModernBottomNavigation(
        currentIndex: navIndex,
        onTap: (index) {
          ref.read(navigationIndexProvider.notifier).state = index;
          
          final routes = [
            Routes().homeModern,
            Routes().rideHistory,
            Routes().profile,
            Routes().supportScreen,
          ];
          
          context.pushNamed(routes[index]);
        },
      ),
    );
  }
}
