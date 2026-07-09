// Modified by Jayant Pandit on 2026-07-11 12:30:00
// Reason: Wrap in Scaffold with transparent background to provide Material ancestor.
// TextField and other Material widgets require a Material ancestor in the widget tree.
// HeritageBackgroundWrapper returns a Stack, which doesn't provide Material context.
// Without Scaffold, the login screen throws "No Material widget found" error.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:Dadacabs/View/Components/all_components.dart';
import 'package:Dadacabs/View/Themes/indian_heritage_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:Dadacabs/View/Routes/app_routes.dart';
import 'phone_login_logics.dart';
import 'phone_login_providers.dart';
import 'package:Dadacabs/View/Widgets/heritage_background_wrapper.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController phoneController = TextEditingController();

  @override
  void dispose() {
    phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.sizeOf(context);

    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Modified by Jayant Pandit on 2026-07-11 12:30:00
    // Reason: Wrap in Scaffold with transparent background to provide Material ancestor.
    // TextField and other Material widgets require a Material ancestor in the widget tree.
    // HeritageBackgroundWrapper returns a Stack, which doesn't provide Material context.
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: HeritageBackgroundWrapper(
        pageName: "Login",
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),

                // App Branding
                Center(
                  child: Column(
                    children: [
                      Container(
                        height: 100,
                        width: 100,
                        decoration: BoxDecoration(
                          color: IndianHeritageCarColors.primaryYellow,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: IndianHeritageCarColors.primaryYellow.withOpacity(0.3),
                              blurRadius: 30,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(12),
                        child: Image.asset(
                          'assets/imgs/logo.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        "DadaCabs Customer",
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontFamily: 'bold',
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : IndianHeritageCarColors.charcoal,
                        ),
                      ),
                      Text(
                        "CUSTOMER APP",
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: IndianHeritageCarColors.primaryYellow,
                          fontFamily: 'bold',
                          letterSpacing: 4,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 60),

                Text(
                  "Customer Login",
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontFamily: 'bold',
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : IndianHeritageCarColors.charcoal,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "Enter your mobile number to get started",
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: isDark ? Colors.white70 : IndianHeritageCarColors.textMuted,
                  ),
                ),

                const SizedBox(height: 48),

                // Phone Number Field
                Text(
                  "Enter Mobile Number",
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                    color: isDark ? Colors.white : IndianHeritageCarColors.charcoal,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black.withOpacity(0.4) : Colors.white.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? Colors.white.withOpacity(0.2) : IndianHeritageCarColors.silver,
                    ),
                  ),
                  child: Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          "+91",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : IndianHeritageCarColors.charcoal,
                          ),
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 30,
                        color: isDark ? Colors.white.withOpacity(0.3) : IndianHeritageCarColors.silver,
                      ),
                      Expanded(
                        child: TextField(
                          controller: phoneController,
                          keyboardType: TextInputType.phone,
                          maxLength: 10,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                            color: isDark ? Colors.white : IndianHeritageCarColors.charcoal,
                          ),
                          decoration: InputDecoration(
                            hintText: "000 000 0000",
                            hintStyle: TextStyle(
                              color: isDark ? Colors.white54 : IndianHeritageCarColors.textMuted,
                            ),
                            counterText: "",
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 48),

                // Bottom Button
                Consumer(
                  builder: (context, ref, child) {
                    final isLoading = ref.watch(phoneLoginIsLoadingProvider);
                    return SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: isLoading
                            ? null
                            : () => PhoneLoginLogics().sendOTP(
                                  context,
                                  ref,
                                  phoneController,
                                ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: IndianHeritageCarColors.primaryYellow,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: isLoading
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  color: Colors.black,
                                ),
                              )
                            : const Text(
                                "Continue",
                                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                              ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 32),

                Center(
                  child: Text(
                    "By continuing, you agree to our Terms & Privacy Policy",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white54 : IndianHeritageCarColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
