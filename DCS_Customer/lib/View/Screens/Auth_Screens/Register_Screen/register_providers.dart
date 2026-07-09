import 'package:flutter_riverpod/flutter_riverpod.dart';

final registerIsLoadingProvider = StateProvider.autoDispose<bool>((ref) => false);

/// Tracks which step the user is on: 0 = details form, 1 = OTP entry
final registerStepProvider = StateProvider.autoDispose<int>((ref) => 0);

/// Holds the generated mock OTP
final registerOtpProvider = StateProvider.autoDispose<String>((ref) => '');
