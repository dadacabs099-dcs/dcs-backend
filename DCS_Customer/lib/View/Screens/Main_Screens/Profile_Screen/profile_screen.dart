import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:Dadacabs/View/Screens/Nav_Screens/navigation_providers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:Dadacabs/Container/Repositories/user_repo.dart';
import 'package:Dadacabs/Model/user_model.dart';
import 'package:Dadacabs/View/Routes/routes.dart';

import 'package:Dadacabs/View/Themes/indian_heritage_theme.dart';
import 'package:Dadacabs/Container/Providers/theme_provider.dart';

import 'package:Dadacabs/Container/Providers/user_data_provider.dart';
import 'package:Dadacabs/View/Widgets/translated_text.dart';
import 'package:Dadacabs/View/Screens/Auth_Screens/Login_Screen/phone_login_logics.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Fetches user profile — first via direct Firestore read (matching Partner APK's getDriverDetails),
/// then subscribes to real-time stream. Works even when [userDataProvider] is null after app restart.
final userProfileProvider = StreamProvider<UserModel?>((ref) async* {
  // 1. Get UID: prefer in-memory provider, fallback to Firebase Auth session
  final userData = ref.watch(userDataProvider);
  final uid = userData?.uid ?? FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) {
    yield null;
    return;
  }

  // 2. Do a direct Firestore fetch first (ensures data on first load)
  try {
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (doc.exists && doc.data() != null) {
      yield UserModel.fromJson(doc.data()!, doc.id);
    }
  } catch (e) {
    debugPrint("userProfileProvider initial fetch error: $e");
  }

  // 3. Switch to real-time stream for live updates
  yield* ref.read(globalUserRepoProvider).streamUserProfile(uid);
});

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProfileProvider);
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;

    return Scaffold(
      backgroundColor: isDark ? IndianHeritageColors.darkBackground : IndianHeritageColors.marbleWhite,
      appBar: AppBar(
        backgroundColor: IndianHeritageColors.primaryYellow,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded, color: IndianHeritageColors.charcoal),
          onPressed: () => ref.read(navigationScaffoldKeyProvider).currentState?.openDrawer(),
        ),
        title: const TranslatedText(
          'My Profile',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 20,
            color: IndianHeritageColors.charcoal,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: IndianHeritageColors.charcoal),
            onPressed: () {
              // Edit profile action
            },
          ),
        ],
      ),
      body: userAsync.when(
        data: (user) => user != null 
          ? _buildProfileContent(context, ref, user, isDark)
          : _buildNoUserContent(context, isDark),
        loading: () => const Center(
          child: CircularProgressIndicator(color: IndianHeritageColors.primaryYellow),
        ),
        error: (err, stack) => Center(
          child: Text(
            "Error: $err", 
            style: TextStyle(color: isDark ? Colors.white : IndianHeritageColors.charcoal),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileContent(BuildContext context, WidgetRef ref, UserModel user, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          // Profile Header
          _buildProfileHeader(context, user, isDark),
          const SizedBox(height: 30),
          
          // Stats Cards
          _buildStatsRow(context, user, isDark),
          const SizedBox(height: 30),
          
          // Menu Options
          _buildMenuSection(context, ref, user, isDark),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context, UserModel user, bool isDark) {
    return Column(
      children: [
        // Profile Image
        Stack(
          children: [
            CircleAvatar(
              radius: 60,
              backgroundColor: IndianHeritageColors.primaryYellow,
              backgroundImage: user.profileImage != null
                  ? NetworkImage(user.profileImage!)
                  : null,
              child: user.profileImage == null
                  ? Text(
                      user.name.isNotEmpty ? user.name[0].toUpperCase() : "U",
                      style: const TextStyle(
                        fontSize: 40,
                        color: IndianHeritageColors.charcoal,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: IndianHeritageColors.charcoal,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.camera_alt,
                  color: IndianHeritageColors.primaryYellow,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),
        
        // Name & Rating
        Text(
          user.name,
          style: Theme.of(context).textTheme.bodySmall!.copyWith(
            fontFamily: "bold",
            fontSize: 24,
            color: isDark ? Colors.white : IndianHeritageColors.charcoal,
          ),
        ),
        const SizedBox(height: 5),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.star, color: Colors.amber, size: 20),
            const SizedBox(width: 5),
            Text(
              user.rating.toStringAsFixed(1),
              style: Theme.of(context).textTheme.bodySmall!.copyWith(
                fontSize: 16,
                color: isDark ? Colors.white : IndianHeritageColors.charcoal,
              ),
            ),
            const SizedBox(width: 5),
            TranslatedText(
              '(${user.totalRides} rides)',
              style: Theme.of(context).textTheme.bodySmall!.copyWith(
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          user.email,
          style: Theme.of(context).textTheme.bodySmall!.copyWith(
            color: Colors.grey,
            fontSize: 14,
          ),
        ),
        if (user.phone.isNotEmpty) ...[
          const SizedBox(height: 5),
          Text(
            user.phone,
            style: Theme.of(context).textTheme.bodySmall!.copyWith(
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStatsRow(BuildContext context, UserModel user, bool isDark) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            context,
            icon: Icons.local_taxi,
            value: user.totalRides.toString(),
            label: "Total Rides",
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: _buildStatCard(
            context,
            icon: Icons.account_balance_wallet,
            value: "₹${user.walletBalance?.toStringAsFixed(0) ?? '0'}",
            label: "Wallet",
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: _buildStatCard(
            context,
            icon: Icons.star,
            value: user.rating.toStringAsFixed(1),
            label: "Rating",
            isDark: isDark,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(BuildContext context, {
    required IconData icon,
    required String value,
    required String label,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: isDark ? IndianHeritageColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[200]!,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: IndianHeritageColors.primaryYellow, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.bodySmall!.copyWith(
              fontFamily: "bold",
              fontSize: 18,
              color: isDark ? Colors.white : IndianHeritageColors.charcoal,
            ),
          ),
          const SizedBox(height: 4),
          TranslatedText(
            label,
            style: Theme.of(context).textTheme.bodySmall!.copyWith(
              color: Colors.grey,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuSection(BuildContext context, WidgetRef ref, UserModel user, bool isDark) {
    return Column(
      children: [
        _buildMenuItem(
          context,
          icon: Icons.history,
          title: "Ride History",
          subtitle: "View your past trips",
          isDark: isDark,
          onTap: () => context.pushNamed(Routes().rideHistory),
        ),
        _buildMenuItem(
          context,
          icon: Icons.payment,
          title: "Payments & Wallet",
          subtitle: "Manage payment methods",
          isDark: isDark,
          onTap: () => context.pushNamed(Routes().payments),
        ),
        _buildMenuItem(
          context,
          icon: Icons.location_on,
          title: "Saved Addresses",
          subtitle: user.homeAddress ?? "Add home & work locations",
          isDark: isDark,
          onTap: () => _showAddressesDialog(context, ref, user, isDark),
        ),
        _buildMenuItem(
          context,
          icon: Icons.notifications,
          title: "Notifications",
          subtitle: "Manage notification preferences",
          isDark: isDark,
          onTap: () => context.pushNamed(Routes().notifications),
        ),
        _buildMenuItem(
          context,
          icon: Icons.settings,
          title: "Settings",
          subtitle: "App preferences and support settings",
          isDark: isDark,
          onTap: () => context.pushNamed(Routes().settings),
        ),
        _buildMenuItem(
          context,
          icon: Icons.help_outline,
          title: "Help & Support",
          subtitle: "FAQs and contact us",
          isDark: isDark,
          onTap: () {},
        ),
        _buildMenuItem(
          context,
          icon: Icons.logout,
          title: "Logout",
          subtitle: "Sign out from your account",
          isDark: isDark,
          isDestructive: true,
          onTap: () => _logout(context, ref, isDark),
        ),
      ],
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required bool isDark,
    bool isDestructive = false,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 5),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDestructive 
              ? Colors.red.withOpacity(0.1) 
              : IndianHeritageColors.primaryYellow.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: isDestructive ? Colors.red : IndianHeritageColors.primaryYellow,
        ),
      ),
      title: TranslatedText(
        title,
        style: Theme.of(context).textTheme.bodySmall!.copyWith(
          fontFamily: "bold",
          color: isDestructive ? Colors.red : (isDark ? Colors.white : IndianHeritageColors.charcoal),
        ),
      ),
      subtitle: TranslatedText(
        subtitle,
        style: Theme.of(context).textTheme.bodySmall!.copyWith(
          color: Colors.grey,
          fontSize: 12,
        ),
      ),
      trailing: const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
      onTap: onTap,
    );
  }

  void _showAddressesDialog(BuildContext context, WidgetRef ref, UserModel user, bool isDark) {
    final homeController = TextEditingController(text: user.homeAddress);
    final workController = TextEditingController(text: user.workAddress);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? IndianHeritageColors.darkSurface : Colors.white,
        title: TranslatedText(
          'Saved Addresses',
          style: TextStyle(
            fontFamily: "bold",
            color: isDark ? Colors.white : IndianHeritageColors.charcoal,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: homeController,
              style: TextStyle(
                color: isDark ? Colors.white : IndianHeritageColors.charcoal,
              ),
                decoration: InputDecoration(
                labelText: 'Home Address',
                labelStyle: const TextStyle(color: Colors.grey),
                prefixIcon: const Icon(Icons.home, color: IndianHeritageColors.primaryYellow),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: workController,
              style: TextStyle(
                color: isDark ? Colors.white : IndianHeritageColors.charcoal,
              ),
                decoration: InputDecoration(
                labelText: 'Work Address',
                labelStyle: const TextStyle(color: Colors.grey),
                prefixIcon: const Icon(Icons.work, color: IndianHeritageColors.primaryYellow),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const TranslatedText('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final repo = ref.read(globalUserRepoProvider);
              await repo.saveAddresses(
                user.uid,
                homeController.text.isNotEmpty ? homeController.text : null,
                workController.text.isNotEmpty ? workController.text : null,
                context,
              );
              if (context.mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: IndianHeritageColors.primaryYellow,
              foregroundColor: IndianHeritageColors.charcoal,
            ),
            child: const TranslatedText('Save'),
          ),
        ],
      ),
    );
  }

  void _logout(BuildContext context, WidgetRef ref, bool isDark) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? IndianHeritageColors.darkSurface : Colors.white,
        title: TranslatedText(
          'Logout',
          style: TextStyle(
            fontFamily: "bold",
            color: isDark ? Colors.white : IndianHeritageColors.charcoal,
          ),
        ),
        content: TranslatedText(
          'Are you sure you want to logout?',
          style: TextStyle(
            color: isDark ? Colors.white : IndianHeritageColors.charcoal,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const TranslatedText('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              // Clear dev bypass session (matching Partner APK pattern)
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('dev_bypass_phone');
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                context.goNamed(Routes().login);
              }
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

  Widget _buildNoUserContent(BuildContext context, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.grey, size: 60),
          const SizedBox(height: 20),
          TranslatedText(
            'No user data found',
            style: TextStyle(
              color: isDark ? Colors.white : IndianHeritageColors.charcoal,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              context.goNamed(Routes().login);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: IndianHeritageColors.primaryYellow,
              foregroundColor: Colors.black,
            ),
            child: const TranslatedText('Go to Login'),
          ),
        ],
      ),
    );
  }
}
