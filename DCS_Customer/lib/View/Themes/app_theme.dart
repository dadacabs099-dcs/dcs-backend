import 'package:flutter/material.dart';

// Modern Uber-like color scheme
class AppColors {
  static const Color primary = Color(0xFF000000);      // Black
  static const Color secondary = Color(0xFF276EF1);    // Blue accent
  static const Color success = Color(0xFF27C24F);     // Green
  static const Color warning = Color(0xFFFFB300);     // Amber
  static const Color error = Color(0xFFFF3B30);       // Red
  
  // Dark Mode Colors
  static const Color darkBackground = Color(0xFF121212);  // Dark gray
  static const Color darkSurface = Color(0xFF1E1E1E);     // Lighter dark gray
  static const Color darkTextPrimary = Color(0xFFFFFFFF); // White
  static const Color darkTextSecondary = Color(0xFF9E9E9E); // Gray
  static const Color darkDivider = Color(0xFF2C2C2C);     // Divider color
  
  // Light Mode Colors
  static const Color lightBackground = Color(0xFFF5F5F5);  // Light gray
  static const Color lightSurface = Color(0xFFFFFFFF);     // White
  static const Color lightTextPrimary = Color(0xFF000000); // Black
  static const Color lightTextSecondary = Color(0xFF666666); // Gray
  static const Color lightDivider = Color(0xFFE0E0E0);     // Divider color
  
  // Backward compatibility - default to dark mode
  static const Color background = darkBackground;
  static const Color surface = darkSurface;
  static const Color textPrimary = darkTextPrimary;
  static const Color textSecondary = darkTextSecondary;
  static const Color divider = darkDivider;
}

ThemeData appTheme = ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: AppColors.darkBackground,
  primaryColor: AppColors.primary,
  colorScheme: const ColorScheme.dark(
    primary: AppColors.primary,
    secondary: AppColors.secondary,
    surface: AppColors.darkSurface,
    error: AppColors.error,
    onPrimary: AppColors.darkTextPrimary,
    onSecondary: AppColors.darkTextPrimary,
    onSurface: AppColors.darkTextPrimary,
    onError: AppColors.darkTextPrimary,
  ),
  
  // Elevated Button Theme
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.secondary,
      foregroundColor: Colors.white,
      elevation: 4,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      textStyle: const TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 16,
        fontFamily: 'medium',
      ),
    ),
  ),
  
  // Text Button Theme
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: AppColors.secondary,
      textStyle: const TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 14,
        fontFamily: 'medium',
      ),
    ),
  ),
  
  // Card Theme
  cardTheme: CardThemeData(
    color: AppColors.darkSurface,
    elevation: 4,
    shadowColor: Colors.black45,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    ),
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  ),
  
  // Input Decoration Theme
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: AppColors.darkSurface,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: AppColors.darkDivider),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: AppColors.darkDivider),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: AppColors.secondary, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: AppColors.error),
    ),
    hintStyle: const TextStyle(
      color: AppColors.darkTextSecondary,
      fontFamily: 'regular',
      fontSize: 14,
    ),
    labelStyle: const TextStyle(
      color: AppColors.darkTextSecondary,
      fontFamily: 'medium',
      fontSize: 14,
    ),
  ),
  
  // Text Theme
  textTheme: const TextTheme(
    displayLarge: TextStyle(
      color: AppColors.darkTextPrimary,
      fontFamily: 'bold',
      fontSize: 32,
      fontWeight: FontWeight.bold,
    ),
    displayMedium: TextStyle(
      color: AppColors.darkTextPrimary,
      fontFamily: 'bold',
      fontSize: 28,
      fontWeight: FontWeight.bold,
    ),
    displaySmall: TextStyle(
      color: AppColors.darkTextPrimary,
      fontFamily: 'bold',
      fontSize: 24,
      fontWeight: FontWeight.bold,
    ),
    headlineLarge: TextStyle(
      color: AppColors.darkTextPrimary,
      fontFamily: 'bold',
      fontSize: 22,
      fontWeight: FontWeight.bold,
    ),
    headlineMedium: TextStyle(
      color: AppColors.darkTextPrimary,
      fontFamily: 'semiBold',
      fontSize: 20,
      fontWeight: FontWeight.w600,
    ),
    headlineSmall: TextStyle(
      color: AppColors.darkTextPrimary,
      fontFamily: 'semiBold',
      fontSize: 18,
      fontWeight: FontWeight.w600,
    ),
    titleLarge: TextStyle(
      color: AppColors.darkTextPrimary,
      fontFamily: 'medium',
      fontSize: 18,
      fontWeight: FontWeight.w500,
    ),
    titleMedium: TextStyle(
      color: AppColors.darkTextPrimary,
      fontFamily: 'medium',
      fontSize: 16,
      fontWeight: FontWeight.w500,
    ),
    titleSmall: TextStyle(
      color: AppColors.darkTextPrimary,
      fontFamily: 'regular',
      fontSize: 14,
      fontWeight: FontWeight.w500,
    ),
    bodyLarge: TextStyle(
      color: AppColors.darkTextPrimary,
      fontFamily: 'regular',
      fontSize: 16,
    ),
    bodyMedium: TextStyle(
      color: AppColors.darkTextPrimary,
      fontFamily: 'regular',
      fontSize: 14,
    ),
    bodySmall: TextStyle(
      color: AppColors.darkTextSecondary,
      fontFamily: 'regular',
      fontSize: 12,
    ),
  ),
  
  // App Bar Theme
  appBarTheme: const AppBarTheme(
    backgroundColor: AppColors.darkBackground,
    elevation: 0,
    centerTitle: true,
    titleTextStyle: TextStyle(
      color: AppColors.darkTextPrimary,
      fontFamily: 'bold',
      fontSize: 20,
      fontWeight: FontWeight.bold,
    ),
    iconTheme: IconThemeData(
      color: AppColors.darkTextPrimary,
    ),
  ),
  
  // Icon Theme
  iconTheme: const IconThemeData(
    color: AppColors.darkTextPrimary,
    size: 24,
  ),
);

// Light Theme
ThemeData appLightTheme = ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: AppColors.lightBackground,
  primaryColor: AppColors.primary,
  colorScheme: const ColorScheme.light(
    primary: AppColors.primary,
    secondary: AppColors.secondary,
    surface: AppColors.lightSurface,
    error: AppColors.error,
    onPrimary: AppColors.lightTextPrimary,
    onSecondary: AppColors.lightTextPrimary,
    onSurface: AppColors.lightTextPrimary,
    onError: AppColors.lightTextPrimary,
  ),
  
  // Elevated Button Theme
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.secondary,
      foregroundColor: Colors.white,
      elevation: 4,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      textStyle: const TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 16,
        fontFamily: 'medium',
      ),
    ),
  ),
  
  // Text Button Theme
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: AppColors.secondary,
      textStyle: const TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 14,
        fontFamily: 'medium',
      ),
    ),
  ),
  
  // Card Theme
  cardTheme: CardThemeData(
    color: AppColors.lightSurface,
    elevation: 4,
    shadowColor: Colors.black26,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    ),
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  ),
  
  // Input Decoration Theme
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: AppColors.lightSurface,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: AppColors.lightDivider),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: AppColors.lightDivider),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: AppColors.secondary, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: AppColors.error),
    ),
    hintStyle: const TextStyle(
      color: AppColors.lightTextSecondary,
      fontFamily: 'regular',
      fontSize: 14,
    ),
    labelStyle: const TextStyle(
      color: AppColors.lightTextSecondary,
      fontFamily: 'medium',
      fontSize: 14,
    ),
  ),
  
  // Text Theme
  textTheme: const TextTheme(
    displayLarge: TextStyle(
      color: AppColors.lightTextPrimary,
      fontFamily: 'bold',
      fontSize: 32,
      fontWeight: FontWeight.bold,
    ),
    displayMedium: TextStyle(
      color: AppColors.lightTextPrimary,
      fontFamily: 'bold',
      fontSize: 28,
      fontWeight: FontWeight.bold,
    ),
    displaySmall: TextStyle(
      color: AppColors.lightTextPrimary,
      fontFamily: 'bold',
      fontSize: 24,
      fontWeight: FontWeight.bold,
    ),
    headlineLarge: TextStyle(
      color: AppColors.lightTextPrimary,
      fontFamily: 'bold',
      fontSize: 22,
      fontWeight: FontWeight.bold,
    ),
    headlineMedium: TextStyle(
      color: AppColors.lightTextPrimary,
      fontFamily: 'semiBold',
      fontSize: 20,
      fontWeight: FontWeight.w600,
    ),
    headlineSmall: TextStyle(
      color: AppColors.lightTextPrimary,
      fontFamily: 'semiBold',
      fontSize: 18,
      fontWeight: FontWeight.w600,
    ),
    titleLarge: TextStyle(
      color: AppColors.lightTextPrimary,
      fontFamily: 'medium',
      fontSize: 18,
      fontWeight: FontWeight.w500,
    ),
    titleMedium: TextStyle(
      color: AppColors.lightTextPrimary,
      fontFamily: 'medium',
      fontSize: 16,
      fontWeight: FontWeight.w500,
    ),
    titleSmall: TextStyle(
      color: AppColors.lightTextPrimary,
      fontFamily: 'regular',
      fontSize: 14,
      fontWeight: FontWeight.w500,
    ),
    bodyLarge: TextStyle(
      color: AppColors.lightTextPrimary,
      fontFamily: 'regular',
      fontSize: 16,
    ),
    bodyMedium: TextStyle(
      color: AppColors.lightTextPrimary,
      fontFamily: 'regular',
      fontSize: 14,
    ),
    bodySmall: TextStyle(
      color: AppColors.lightTextSecondary,
      fontFamily: 'regular',
      fontSize: 12,
    ),
  ),
  
  // App Bar Theme
  appBarTheme: const AppBarTheme(
    backgroundColor: AppColors.lightBackground,
    elevation: 0,
    centerTitle: true,
    titleTextStyle: TextStyle(
      color: AppColors.lightTextPrimary,
      fontFamily: 'bold',
      fontSize: 20,
      fontWeight: FontWeight.bold,
    ),
    iconTheme: IconThemeData(
      color: AppColors.lightTextPrimary,
    ),
  ),
  
  // Icon Theme
  iconTheme: const IconThemeData(
    color: AppColors.lightTextPrimary,
    size: 24,
  ),
);
