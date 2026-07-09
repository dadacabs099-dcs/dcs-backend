import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:Dadacabs/View/Themes/indian_heritage_theme.dart';
import 'package:Dadacabs/View/Screens/Auth_Screens/Login_Screen/phone_login_logics.dart';
import 'package:Dadacabs/View/Screens/Auth_Screens/Register_Screen/register_logics.dart';
import 'package:Dadacabs/View/Screens/Auth_Screens/Register_Screen/register_providers.dart';
import 'package:Dadacabs/Container/Providers/theme_provider.dart';
import 'package:Dadacabs/Container/utils/error_notification.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  final String? phoneNumber;
  const RegisterScreen({super.key, this.phoneNumber});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(registerIsLoadingProvider);
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, 
            color: isDark ? Colors.white : Colors.black),
          onPressed: () => PhoneLoginLogics().logout(context, ref),
        ),
      ),
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      Text(
                        "Complete Profile",
                        style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Just one more step to start your ride",
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                      
                      const SizedBox(height: 40),

                      // Read-only Phone Field
                      _fieldLabel("Mobile Number", isDark),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey[900] : const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isDark ? Colors.grey[800]! : Colors.transparent),
                        ),
                        child: Text(
                          widget.phoneNumber == null || widget.phoneNumber!.isEmpty
                              ? "No Phone Number"
                              : (widget.phoneNumber!.startsWith('+')
                                  ? widget.phoneNumber!
                                  : '+91${widget.phoneNumber!}'),
                          style: TextStyle(
                            color: isDark ? Colors.grey[500] : Colors.grey[600],
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 24),

                      // Name Field
                      _fieldLabel("Full Name", isDark),
                      const SizedBox(height: 8),
                      _styledTextField(
                        controller: _nameController,
                        hint: "Enter your full name",
                        icon: Icons.person_outline_rounded,
                        isDark: isDark,
                      ),
                      
                      const SizedBox(height: 24),

                      // Email Field
                      _fieldLabel("Email Address (Optional)", isDark),
                      const SizedBox(height: 8),
                      _styledTextField(
                        controller: _emailController,
                        hint: "Enter your email",
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        isDark: isDark,
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom Button
              Padding(
                padding: const EdgeInsets.all(24),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : () => _handleRegister(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: IndianHeritageColors.primaryYellow,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 3, color: Colors.black),
                          )
                        : const Text(
                            "Create Profile & Start Riding",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleRegister() {
    if (_nameController.text.trim().isEmpty) {
      ErrorNotification().showError(context, "Please enter your name");
      return;
    }
    RegisterLogics().registerUserSimple(
      context,
      ref,
      _nameController.text.trim(),
      _emailController.text.trim(),
      widget.phoneNumber ?? "",
    );
  }

  Widget _fieldLabel(String label, bool isDark) => Text(
    label,
    style: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.bold,
      color: isDark ? Colors.grey[300] : Colors.grey[800],
    ),
  );

  Widget _styledTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    required bool isDark,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.grey[800]! : Colors.transparent),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black,
          fontWeight: FontWeight.bold,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.normal),
          prefixIcon: Icon(icon, color: IndianHeritageColors.primaryYellow),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        ),
      ),
    );
  }
}
