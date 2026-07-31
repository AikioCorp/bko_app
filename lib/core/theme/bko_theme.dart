import 'package:flutter/material.dart';

class BkoTheme {
  // Apple-inspired Color Palette (Dark Obsidian & Warm Gold Accent)
  static const Color bgObsidian = Color(0xFF0B0F17);
  static const Color bgSurface = Color(0xFF161B22);
  static const Color bgSurfaceElevated = Color(0xFF1F242D);
  static const Color bgSurfaceTranslucent = Color(0xE6161B22);

  static const Color borderSubtle = Color(0xFF21262D);
  static const Color borderStrong = Color(0xFF30363D);

  static const Color textPrimary = Color(0xFFF0F6FC);
  static const Color textSecondary = Color(0xFF8B949E);
  static const Color textMuted = Color(0xFF6E7681);

  // Gold Signature Accent used with restraint
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
      fontFamily: '.SF Pro Text', // Native Cupertino font fallback
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: textPrimary),
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: bgObsidian,
        selectedItemColor: goldAccent,
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        unselectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
      ),
      cardTheme: CardThemeData(
        color: bgSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: borderSubtle, width: 1),
        ),
      ),
    );
  }
}
