// Modified by Jayant Pandit on 2026-07-11 12:45:00
// Reason: Wrap in Scaffold with transparent background to provide Material ancestor.
// OTP TextField widgets require a Material ancestor in the widget tree.
// HeritageBackgroundWrapper returns a Stack, which doesn't provide Material context.
// Without Scaffold, the OTP screen throws "No Material widget found" error.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:Dadacabs/View/Components/all_components.dart';
import 'package:Dadacabs/View/Themes/indian_heritage_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'phone_login_logics.dart';
import 'phone_login_providers.dart';
import 'package:Dadacabs/View/Widgets/heritage_background_wrapper.dart';

class OTPVerificationScreen extends ConsumerStatefulWidget {
  final String phoneNumber;
  final String verificationId;

  const OTPVerificationScreen({
    super.key,
    required this.phoneNumber,
    required this.verificationId,
  });

  @override
  ConsumerState<OTPVerificationScreen> createState() => _OTPVerificationScreenState();
}

class _OTPVerificationScreenState extends ConsumerState<OTPVerificationScreen> {
  final List<TextEditingController> otpControllers = List.generate(
    6,
    (index) => TextEditingController(),
  );
  final List<FocusNode> focusNodes = List.generate(
    6,
    (index) => FocusNode(),
  );

  int _resendTimer = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    startResendTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      focusNodes[0].requestFocus();
    });
  }

  void startResendTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendTimer > 0) {
        if (mounted) {
          setState(() {
            _resendTimer--;
          });
        }
      } else {
        timer.cancel();
      }
    });
  }

  String getOtpCode() {
    return otpControllers.map((c) => c.text).join();
  }

  void onOtpChanged(int index, String value) {
    if (value.isNotEmpty && index < 5) {
      focusNodes[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      focusNodes[index - 1].requestFocus();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var controller in otpControllers) {
      controller.dispose();
    }
    for (var node in focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isLoading = ref.watch(otpVerifyIsLoadingProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Modified by Jayant Pandit on 2026-07-11 12:45:00
    // Reason: Wrap in Scaffold with transparent background to provide Material ancestor.
    // OTP TextField widgets require a Material ancestor in the widget tree.
    // HeritageBackgroundWrapper returns a Stack, which doesn't provide Material context.
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: HeritageBackgroundWrapper(
        pageName: "Verify",
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 80),
                Text(
                  "Verify OTP",
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontFamily: 'bold',
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : IndianHeritageCarColors.charcoal,
                  ),
                ),
                const SizedBox(height: 12),
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      color: isDark ? Colors.white70 : IndianHeritageCarColors.textMuted,
                      fontSize: 16,
                    ),
                    children: [
                      const TextSpan(text: "Enter the 6-digit code sent to "),
                      TextSpan(
                        text: "+91 ${widget.phoneNumber}",
                        style: TextStyle(
                          color: isDark ? Colors.white : IndianHeritageCarColors.charcoal,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 48),

                // OTP Input Fields
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(6, (index) {
                    return Container(
                      width: (size.width - 48 - 40) / 6,
                      height: 60,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.black.withOpacity(0.4) : Colors.white.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: focusNodes[index].hasFocus
                              ? IndianHeritageCarColors.primaryYellow
                              : (isDark ? Colors.white.withOpacity(0.2) : IndianHeritageCarColors.silver),
                          width: 1.5,
                        ),
                      ),
                      child: TextField(
                        controller: otpControllers[index],
                        focusNode: focusNodes[index],
                        keyboardType: TextInputType.number,
                        maxLength: 1,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : IndianHeritageCarColors.charcoal,
                        ),
                        decoration: const InputDecoration(
                          counterText: "",
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onChanged: (value) => onOtpChanged(index, value),
                      ),
                    );
                  }),
                ),

                const SizedBox(height: 32),

                if (widget.verificationId.startsWith("dev_bypass_"))
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: IndianHeritageCarColors.primaryYellow.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: IndianHeritageCarColors.primaryYellow.withOpacity(0.3)),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            "DEVELOPMENT OTP",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                              color: IndianHeritageCarColors.primaryYellow,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.verificationId.split('_').last,
                            style: TextStyle(
                              color: isDark ? Colors.white : IndianHeritageCarColors.charcoal,
                              fontWeight: FontWeight.w900,
                              fontSize: 28,
                              letterSpacing: 4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 32),

                // Resend Section
                Center(
                  child: _resendTimer > 0
                      ? Text(
                          "Resend code in ${_resendTimer}s",
                          style: TextStyle(
                            color: isDark ? Colors.white54 : IndianHeritageCarColors.textMuted,
                            fontFamily: 'medium',
                          ),
                        )
                      : TextButton(
                          onPressed: () {
                            ref.read(phoneLoginIsLoadingProvider.notifier).state = true;
                            PhoneLoginLogics().resendOTP(context, ref, widget.phoneNumber);
                            setState(() {
                              _resendTimer = 60;
                            });
                            startResendTimer();
                          },
                          child: const Text(
                            "Resend OTP",
                            style: TextStyle(
                              color: IndianHeritageCarColors.primaryYellow,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                ),

                const SizedBox(height: 48),

                // Verify Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: isLoading
                        ? null
                        : () => PhoneLoginLogics().verifyOTP(
                              context,
                              ref,
                              widget.verificationId,
                              getOtpCode(),
                              widget.phoneNumber,
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
                            "Verify & Continue",
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                          ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
