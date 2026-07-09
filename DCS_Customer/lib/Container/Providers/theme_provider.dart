import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:Dadacabs/View/Themes/indian_heritage_theme.dart';

// Theme mode provider
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.light);

  Future<void> toggleTheme() async {
    // No-op: Dark theme is disabled so the entire app remains on the Light Indian Heritage Vintage Car Theme.
  }

  ThemeData getTheme(BuildContext context) {
    return indianHeritageCarLightTheme;
  }
}
