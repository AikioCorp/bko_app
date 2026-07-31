import 'package:flutter/material.dart';

class BkoTheme {
  // Signature Gold Accent
  static const Color goldAccent = Color(0xFFE6B009);
  static const Color goldAccentHover = Color(0xFFF2C029);

  // Dark Theme Tokens (Defaults)
  static const Color darkBgObsidian = Color(0xFF0B0F17);
  static const Color darkBgSurface = Color(0xFF161B22);
  static const Color darkBgSurfaceElevated = Color(0xFF1F242D);
  static const Color darkBorderSubtle = Color(0xFF21262D);
  static const Color darkBorderStrong = Color(0xFF30363D);
  static const Color darkTextPrimary = Color(0xFFF0F6FC);
  static const Color darkTextSecondary = Color(0xFF8B949E);
  static const Color darkTextMuted = Color(0xFF6E7681);
  static const Color darkLiquidGlassBg = Color(0xCC161B22);
  static const Color darkLiquidGlassBorder = Color(0x33E6B009);
  static const Color darkLiquidGlassActive = Color(0x26E6B009);

  // Light Theme Tokens (Black-Focused Luxury)
  static const Color lightBgObsidian = Color(0xFFF8F9FA);
  static const Color lightBgSurface = Color(0xFFFFFFFF);
  static const Color lightBgSurfaceElevated = Color(0xFFF1F3F5);
  static const Color lightBorderSubtle = Color(0xFFE2E8F0);
  static const Color lightBorderStrong = Color(0xFFCBD5E1);
  static const Color lightTextPrimary = Color(0xFF0F172A); // Deep Obsidian Black
  static const Color lightTextSecondary = Color(0xFF475569);
  static const Color lightTextMuted = Color(0xFF64748B);
  static const Color lightLiquidGlassBg = Color(0xF5FFFFFF);
  static const Color lightLiquidGlassBorder = Color(0x250F172A);
  static const Color lightLiquidGlassActive = Color(0xFF0F172A); // Black Accent in Light Mode

  // Static Fallback Constants (Backward Compatibility for Const Constructors)
  static const Color bgObsidian = darkBgObsidian;
  static const Color bgSurface = darkBgSurface;
  static const Color bgSurfaceElevated = darkBgSurfaceElevated;
  static const Color borderSubtle = darkBorderSubtle;
  static const Color borderStrong = darkBorderStrong;
  static const Color textPrimary = darkTextPrimary;
  static const Color textSecondary = darkTextSecondary;
  static const Color textMuted = darkTextMuted;

  // Context-aware Dynamic Color Getters
  static Color getBgObsidian(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkBgObsidian : lightBgObsidian;

  static Color getBgSurface(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkBgSurface : lightBgSurface;

  static Color getBgSurfaceElevated(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkBgSurfaceElevated : lightBgSurfaceElevated;

  static Color getBorderSubtle(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkBorderSubtle : lightBorderSubtle;

  static Color getBorderStrong(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkBorderStrong : lightBorderStrong;

  static Color getTextPrimary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkTextPrimary : lightTextPrimary;

  static Color getTextSecondary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkTextSecondary : lightTextSecondary;

  static Color getTextMuted(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkTextMuted : lightTextMuted;

  static Color getLiquidGlassBg(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkLiquidGlassBg : lightLiquidGlassBg;

  static Color getLiquidGlassBorder(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkLiquidGlassBorder : lightLiquidGlassBorder;

  static Color getLiquidGlassActive(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkLiquidGlassActive : lightLiquidGlassActive;

  // Primary Button Color (Gold in Dark Mode, Deep Black in Light Mode)
  static Color getPrimaryButtonBg(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? goldAccent : const Color(0xFF0F172A);

  static Color getPrimaryButtonText(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? Colors.black : Colors.white;

  // Active Filter Pill Background
  static Color getActivePillBg(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? goldAccent : const Color(0xFF0F172A);

  static Color getActivePillText(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? Colors.black : Colors.white;

  // Active Bottom Nav Item Color
  static Color getActiveNavItemColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? goldAccent : const Color(0xFF0F172A);

  // Safe Typography Helper with System Fallback (Offline & Production Safe)
  static TextStyle fontLato({
    double? fontSize,
    FontWeight? fontWeight,
    double? letterSpacing,
    double? height,
    Color? color,
  }) {
    return TextStyle(
      fontFamily: 'Lato',
      fontFamilyFallback: const ['sans-serif', '.SF Pro Text', 'Roboto'],
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      height: height,
      color: color,
    );
  }

  // Dark ThemeData Definition
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBgObsidian,
      primaryColor: goldAccent,
      colorScheme: const ColorScheme.dark(
        primary: goldAccent,
        secondary: goldAccentHover,
        surface: darkBgSurface,
      ),
      fontFamily: 'Lato',
      fontFamilyFallback: const ['sans-serif', '.SF Pro Text', 'Roboto'],
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: darkTextPrimary),
        titleTextStyle: fontLato(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          color: darkTextPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: darkBgSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: darkBorderSubtle, width: 1),
        ),
      ),
    );
  }

  // Light ThemeData Definition (Black-Focused Premium)
  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBgObsidian,
      primaryColor: const Color(0xFF0F172A),
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF0F172A),
        secondary: goldAccent,
        surface: lightBgSurface,
      ),
      fontFamily: 'Lato',
      fontFamilyFallback: const ['sans-serif', '.SF Pro Text', 'Roboto'],
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: lightTextPrimary),
        titleTextStyle: fontLato(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          color: lightTextPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: lightBgSurface,
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.04),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: lightBorderSubtle, width: 1),
        ),
      ),
    );
  }
}
