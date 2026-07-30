import 'package:flutter/material.dart';

class BkoTheme {
  // Semantic Colors
  static const Color bgObsidian = Color(0xFF0B0F17);
  static const Color bgSurface = Color(0xFF161B22);
  static const Color bgSurfaceElevated = Color(0xFF1F242D);
  
  static const Color borderSubtle = Color(0xFF21262D);
  static const Color borderStrong = Color(0xFF30363D);

  static const Color textPrimary = Color(0xFFF0F6FC);
  static const Color textSecondary = Color(0xFF8B949E);
  static const Color textMuted = Color(0xFF6E7681);

  static const Color goldAccent = Color(0xFFE6B009);
  static const Color goldAccentHover = Color(0xFFF2C029);

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgObsidian,
      primaryColor: goldAccent,
      colorScheme: const ColorScheme.dark(
        primary: goldAccent,
        secondary: goldAccentHover,
        surface: bgSurface,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: bgObsidian,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: bgObsidian,
        selectedItemColor: goldAccent,
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      cardTheme: CardThemeData(
        color: bgSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: borderSubtle),
        ),
      ),
    );
  }
}
