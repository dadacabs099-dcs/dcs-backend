import 'package:flutter/material.dart' hide Text;
import 'package:Dadacabs/View/Widgets/translated_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:Dadacabs/View/Themes/indian_heritage_theme.dart';
import 'package:Dadacabs/Container/Providers/theme_provider.dart';
import 'package:Dadacabs/Container/Repositories/user_repo.dart';
import 'package:Dadacabs/View/Screens/Nav_Screens/navigation_providers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:Dadacabs/View/Routes/routes.dart';
import 'package:intl/intl.dart';
import 'package:Dadacabs/Container/Providers/user_data_provider.dart';
import 'package:Dadacabs/Model/user_model.dart';

final userProfileProvider = StreamProvider((ref) {
  final user = ref.watch(userDataProvider);
  if (user == null) return Stream.value(null);
  return ref.read(globalUserRepoProvider).streamUserProfile(user.uid);
});

class CustomerDrawer extends ConsumerWidget {
  const CustomerDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProfileProvider);
    final userFallback = ref.watch(userDataProvider);
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    
    // Determine which user data to show (prefer live stream if available)
    final user = userAsync.value ?? userFallback;
    final currentYear = DateTime.now().year;

    return Drawer(
      backgroundColor: isDark ? IndianHeritageColors.darkBackground : IndianHeritageColors.marbleWhite,
      child: Column(
        children: [
          _buildDrawerHeader(context, user),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _drawerTile(context, Icons.home_rounded, "Home", () {
                  Navigator.pop(context);
                  ref.read(navigationStateProvider.notifier).state = 0;
                }, isDark: isDark),
                _drawerTile(context, Icons.history_rounded, "Your Rides", () {
                  Navigator.pop(context);
                  ref.read(navigationStateProvider.notifier).state = 1;
                }, isDark: isDark),
                _drawerTile(context, Icons.account_balance_wallet_rounded, "Payment", () {
                  Navigator.pop(context);
                  ref.read(navigationStateProvider.notifier).state = 2;
                }, isDark: isDark),
                _drawerTile(context, Icons.notifications_rounded, "Notifications", () {
                  Navigator.pop(context);
                  context.pushNamed(Routes().notifications);
                }, isDark: isDark),
                _drawerTile(context, Icons.person_rounded, "Profile", () {
                  Navigator.pop(context);
                  ref.read(navigationStateProvider.notifier).state = 3;
                }, isDark: isDark),
                _drawerTile(context, Icons.support_agent_rounded, "Support", () {
                  Navigator.pop(context);
                }, isDark: isDark),
                const Divider(color: Colors.grey, indent: 16, endIndent: 16, thickness: 0.5),
                _drawerTile(
                  context,
                  Icons.logout_rounded,
                  "Logout",
                  () async {
                    await FirebaseAuth.instance.signOut();
                    if (context.mounted) context.goNamed(Routes().login);
                  },
                  isDestructive: true,
                  isDark: isDark,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TranslatedText(
                  '© $currentYear Dadacabs Services Pvt Ltd',
                  style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.black54,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                TranslatedText(
                  'App Developed by Jayant Pandit',
                  style: TextStyle(
                    color: isDark ? Colors.white38 : Colors.black38,
                    fontSize: 9,
                  ),
                ),
                const SizedBox(height: 2),
                TranslatedText(
                  user != null && user.createdAt != null 
                      ? 'Member since ${DateFormat('MMMM yyyy').format(user.createdAt!)}' 
                      : 'DCS User',
                  style: TextStyle(
                    color: isDark ? IndianHeritageColors.primaryYellow.withOpacity(0.5) : Colors.black45,
                    fontSize: 9,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 8),
                TranslatedText(
                  'v1.0.0',
                  style: TextStyle(
                    color: isDark ? Colors.white24 : Colors.black26,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerHeader(BuildContext context, UserModel? user) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 20,
        bottom: 24,
        left: 20,
        right: 20,
      ),
      color: IndianHeritageColors.primaryYellow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          CircleAvatar(
            radius: 35,
            backgroundColor: IndianHeritageColors.charcoal,
            child: Text(
              user?.name != null && user!.name.isNotEmpty
                  ? user.name[0].toUpperCase()
                  : "U",
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: IndianHeritageColors.primaryYellow,
              ),
            ),
          ),
          const SizedBox(height: 15),
          Text(
            user?.name ?? "Customer",
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: IndianHeritageColors.charcoal,
            ),
          ),
          Text(
            user?.phone ?? "",
            style: const TextStyle(color: Colors.black54, fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          // Wallet balance quick view
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.account_balance_wallet, color: Colors.black, size: 14),
                const SizedBox(width: 6),
                Text(
                  "₹${user?.walletBalance?.toStringAsFixed(0) ?? '0'}",
                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _drawerTile(BuildContext context, IconData icon, String title, VoidCallback onTap,
      {bool isDestructive = false, bool isDark = true}) {
    return ListTile(
      leading: Icon(
        icon, 
        color: isDestructive ? Colors.red : (isDark ? Colors.white70 : Colors.black87), 
        size: 22
      ),
      title: TranslatedText(
        title,
        style: TextStyle(
          color: isDestructive ? Colors.red : (isDark ? Colors.white : Colors.black),
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}
