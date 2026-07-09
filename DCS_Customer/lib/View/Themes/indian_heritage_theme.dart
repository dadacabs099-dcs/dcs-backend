import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// ── Indian Heritage Car Theme Color Palette ──────────────────────────────────
// Designed for a realistic, premium ride-hailing experience
class IndianHeritageCarColors {
  // Primary Branding (Realistic Saffron/Yellow)
  static const Color primaryYellow = Color(0xFFFFD600); 
  static const Color deepGold = Color(0xFFEAB308);      
  static const Color saffron = Color(0xFFFFD600);      // Alias for legacy support
  
  // Neutral Palette (Metallic & Charcoal)
  static const Color charcoal = Color(0xFF000000);      
  static const Color gunmetal = Color(0xFF1E1E1E);      
  static const Color obsidian = Color(0xFF121212);      
  static const Color platinum = Color(0xFFF3F4F6);      
  static const Color silver = Color(0xFFE5E7EB);        
  static const Color marbleWhite = Color(0xFFFFFFFF);   // Alias for legacy support
  
  // Functional Colors
  static const Color success = Color(0xFF10B981);      // Emerald Green
  static const Color error = Color(0xFFEF4444);        // Modern Red
  static const Color warning = Color(0xFFF59E0B);      // Amber
  static const Color info = Color(0xFF3B82F6);
  static const Color marigold = Color(0xFFFFE500);     // Brighter Yellow
  static const Color oceanBlue = Color(0xFF1E3A8A);     // Deep Ocean Blue
  static const Color sandstone = Color(0xFFD4A574);     // Sandstone Beige
  static const Color terracotta = Color(0xFFCC5500);    // Terracotta Orange
  static const Color emerald = Color(0xFF00C853);
  static const Color ruby = Color(0xFFFF1744);

  // Dark Theme Variants
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color darkCard = Color(0xFF2C2C2C);
  
  // Text Colors
  static const Color textLight = Color(0xFFFFFFFF);
  static const Color textMuted = Color(0xFF9CA3AF);
  static const Color textDark = Color(0xFF111827);
  static const Color textPrimary = Color(0xFFFFFFFF);    
  static const Color textSecondary = Color(0xFFB0B0B0); 
  static const Color textTertiary = Color(0xFF757575); 
}

// Legacy Aliases to prevent build breaks
typedef IndianHeritageColors = IndianHeritageCarColors;

// ── Dark Theme Data (Realistic Car Aesthetic) ───────────────────────────────
ThemeData indianHeritageCarTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  scaffoldBackgroundColor: IndianHeritageCarColors.obsidian,
  primaryColor: IndianHeritageCarColors.primaryYellow,
  
  colorScheme: const ColorScheme.dark(
    primary: IndianHeritageCarColors.primaryYellow,
    secondary: IndianHeritageCarColors.primaryYellow,
    surface: IndianHeritageCarColors.gunmetal,
    error: IndianHeritageCarColors.error,
    onPrimary: Colors.black,
    onSecondary: Colors.black,
  ),
  
  // Elevated Button: Realistic, high-contrast action buttons
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: IndianHeritageCarColors.primaryYellow,
      foregroundColor: Colors.black,
      elevation: 4,
      shadowColor: IndianHeritageCarColors.primaryYellow.withOpacity(0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
      textStyle: const TextStyle(
        fontWeight: FontWeight.w900, 
        fontSize: 16, 
        letterSpacing: 0.5,
        fontFamily: 'bold'
      ),
    ),
  ),
  
  // Card: Sleek, slightly translucent car-interface feel
  cardTheme: CardThemeData(
    color: IndianHeritageCarColors.gunmetal,
    elevation: 8,
    shadowColor: Colors.black54,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: BorderSide(color: Colors.white.withOpacity(0.05), width: 1),
    ),
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  ),
  
  // Input: Modern, clean fields
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: IndianHeritageCarColors.gunmetal,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: IndianHeritageCarColors.primaryYellow, width: 2),
    ),
    contentPadding: const EdgeInsets.all(18),
    hintStyle: const TextStyle(color: IndianHeritageCarColors.textSecondary, fontSize: 14),
  ),
  
  textTheme: const TextTheme(
    displayLarge: TextStyle(color: IndianHeritageCarColors.textPrimary, fontSize: 32, fontWeight: FontWeight.w900, fontFamily: 'bold'),
    displayMedium: TextStyle(color: IndianHeritageCarColors.textPrimary, fontSize: 28, fontWeight: FontWeight.w900, fontFamily: 'bold'),
    displaySmall: TextStyle(color: IndianHeritageCarColors.textPrimary, fontSize: 24, fontWeight: FontWeight.w900, fontFamily: 'bold'),
    headlineLarge: TextStyle(color: IndianHeritageCarColors.textPrimary, fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'bold'),
    bodyLarge: TextStyle(color: IndianHeritageCarColors.textPrimary, fontSize: 16, fontFamily: 'medium'),
    bodyMedium: TextStyle(color: IndianHeritageCarColors.textSecondary, fontSize: 14, fontFamily: 'regular'),
  ),
  
  appBarTheme: const AppBarTheme(
    backgroundColor: IndianHeritageCarColors.primaryYellow,
    foregroundColor: Colors.black,
    elevation: 0,
    centerTitle: true,
    titleTextStyle: TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.w900, fontFamily: 'bold'),
    iconTheme: IconThemeData(color: Colors.black, size: 24),
  ),
  
  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    backgroundColor: IndianHeritageCarColors.gunmetal,
    selectedItemColor: IndianHeritageCarColors.primaryYellow,
    unselectedItemColor: IndianHeritageCarColors.textTertiary,
    type: BottomNavigationBarType.fixed,
    elevation: 10,
  ),
);

// ── Light Theme Data (Clean & Premium) ───────────────────────────────────
ThemeData indianHeritageCarLightTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  scaffoldBackgroundColor: IndianHeritageCarColors.platinum,
  primaryColor: IndianHeritageCarColors.primaryYellow,
  
  colorScheme: const ColorScheme.light(
    primary: IndianHeritageCarColors.primaryYellow,
    secondary: IndianHeritageCarColors.charcoal,
    surface: Colors.white,
    error: IndianHeritageCarColors.error,
    onPrimary: Colors.black,
    onSecondary: Colors.white,
  ),
  
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: IndianHeritageCarColors.primaryYellow,
      foregroundColor: Colors.black,
      elevation: 4,
      shadowColor: IndianHeritageCarColors.primaryYellow.withOpacity(0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
      textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, fontFamily: 'bold'),
    ),
  ),
  
  cardTheme: CardThemeData(
    color: Colors.white,
    elevation: 6,
    shadowColor: Colors.black.withOpacity(0.05),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  ),
  
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: IndianHeritageCarColors.silver),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: IndianHeritageCarColors.primaryYellow, width: 2),
    ),
    contentPadding: const EdgeInsets.all(18),
  ),
  
  appBarTheme: const AppBarTheme(
    backgroundColor: IndianHeritageCarColors.primaryYellow,
    foregroundColor: Colors.black,
    elevation: 0,
    centerTitle: true,
    titleTextStyle: TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.w900, fontFamily: 'bold'),
    iconTheme: IconThemeData(color: Colors.black),
  ),
);

// Legacy Aliases for legacy support
ThemeData get indianHeritageTheme => indianHeritageCarTheme;
ThemeData get indianHeritageLightTheme => indianHeritageCarLightTheme;
