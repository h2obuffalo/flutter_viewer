import 'package:flutter/material.dart';

class RetroTheme {
  // Color Palette
  static const Color neonCyan = Color(0xFF00FFFF);
  static const Color hotPink = Color(0xFFFF00FF);
  static const Color darkBlue = Color(0xFF0A0E27);
  static const Color electricGreen = Color(0xFF39FF14);
  static const Color darkGray = Color(0xFF1A1A2E);
  static const Color glowColor = Color(0xFF00FFFF);
  static const Color errorRed = Color(0xFFFF1744);
  static const Color warningYellow = Color(0xFFFFC107);
  static const Color mutedGray = Color(0xFF666666);

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: neonCyan,
      scaffoldBackgroundColor: darkBlue,
      fontFamily: 'VT323',
      
      // Text Theme
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 48,
          fontWeight: FontWeight.bold,
          color: neonCyan,
          letterSpacing: 2,
        ),
        displayMedium: TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.bold,
          color: hotPink,
          letterSpacing: 2,
        ),
        headlineLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: neonCyan,
        ),
        bodyLarge: TextStyle(
          fontSize: 20,
          color: neonCyan,
        ),
        bodyMedium: TextStyle(
          fontSize: 18,
          color: electricGreen,
        ),
      ),
      
      // Input Decoration
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: neonCyan, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: neonCyan, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: electricGreen, width: 3),
        ),
        filled: true,
        fillColor: darkGray,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        hintStyle: const TextStyle(color: Colors.grey),
      ),
      
      // Elevated Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: darkGray,
          foregroundColor: neonCyan,
          side: const BorderSide(color: neonCyan, width: 2),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }

  // Box Decoration for Retro Containers
  static BoxDecoration get retroBorder => BoxDecoration(
    border: Border.all(color: neonCyan, width: 2),
    borderRadius: BorderRadius.circular(4),
  );

  // Scanline Effect
  static BoxDecoration get scanlineBackground => BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        darkBlue,
        darkBlue.withValues(alpha: 0.9),
        darkBlue,
      ],
      stops: const [0.0, 0.01, 0.02],
    ),
  );
}
