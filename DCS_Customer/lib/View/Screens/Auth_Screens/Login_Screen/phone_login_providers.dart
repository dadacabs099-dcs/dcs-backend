import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider for phone login loading state
final phoneLoginIsLoadingProvider = StateProvider<bool>((ref) => false);

/// Provider for OTP verification loading state
final otpVerifyIsLoadingProvider = StateProvider<bool>((ref) => false);

/// Provider to store verification ID temporarily
final verificationIdProvider = StateProvider<String?>((ref) => null);

/// Provider to store phone number temporarily
final phoneNumberProvider = StateProvider<String>((ref) => "");
