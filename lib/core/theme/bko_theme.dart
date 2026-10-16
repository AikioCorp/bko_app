import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class BkoTheme {
  // Signature Gold/Yellow Accent (Exact web #FFBF00)
  static const Color goldAccent = Color(0xFFFFBF00);
  static const Color goldAccentHover = Color(0xFFFFCF33);
  static const Color successColor = Color(0xFF10B981);
  static const Color onMedia = Color(0xFFFFFFFF);
  static const Color mediaBackground = Color(0xFF000000);
  static const Color onBrand = Color(0xFF0B0B0B);
  static const Color mediaScrim = Color(0xE60B0B0B);
  static Color getAccent(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? goldAccent
          : const Color(0xFF805B00);
  static Color getError(BuildContext context) =>
      Theme.of(context).colorScheme.error;
  static Color getSuccess(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF6EE7B7)
          : const Color(0xFF146C43);
  static const Color errorColor = Color(0xFFBA1A1A);

  // Dark Theme Tokens (Exact match with bko_web globals.css)
  static const Color darkBgObsidian = Color(0xFF0B0B0B); // Pure dark neutral
  static const Color darkBgSurface = Color(0xFF121212);
  static const Color darkBgSurfaceElevated = Color(0xFF1A1A1A);
  static const Color darkBorderSubtle = Color(0xFF262626);
  static const Color darkBorderStrong = Color(0xFF333333);
  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFFB8B8B8);
  static const Color darkTextMuted = Color(0xFF929292);
  static const Color darkLiquidGlassBg = Color(0xCC121212);
  static const Color darkLiquidGlassBorder = Color(0x33FFBF00);
  static const Color darkLiquidGlassActive = Color(0x26FFBF00);

  // Light Theme Tokens (Black-Focused Luxury)
  static const Color lightBgObsidian = Color(0xFFF8F9FA);
  static const Color lightBgSurface = Color(0xFFFFFFFF);
  static const Color lightBgSurfaceElevated = Color(0xFFF1F3F5);
  static const Color lightBorderSubtle = Color(0xFFE2E8F0);
  static const Color lightBorderStrong = Color(0xFFCBD5E1);
  static const Color lightTextPrimary =
      Color(0xFF0F172A); // Deep Obsidian Black
  static const Color lightTextSecondary = Color(0xFF475569);
  static const Color lightTextMuted = Color(0xFF59677A);
  static const Color lightLiquidGlassBg = Color(0xF5FFFFFF);
  static const Color lightLiquidGlassBorder = Color(0x250F172A);
  static const Color lightLiquidGlassActive =
      Color(0xFF0F172A); // Black Accent in Light Mode

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
      Theme.of(context).scaffoldBackgroundColor;

  static Color getBgSurface(BuildContext context) =>
      Theme.of(context).colorScheme.surface;

  static Color getBgSurfaceElevated(BuildContext context) =>
      Theme.of(context).colorScheme.surfaceContainerHighest;

  static Color getBorderSubtle(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkBorderSubtle
          : lightBorderSubtle;

  static Color getBorderStrong(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkBorderStrong
          : lightBorderStrong;

  static Color getTextPrimary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkTextPrimary
          : lightTextPrimary;

  static Color getTextSecondary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkTextSecondary
          : lightTextSecondary;

  static Color getTextMuted(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkTextMuted
          : lightTextMuted;

  static Color getLiquidGlassBg(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkLiquidGlassBg
          : lightLiquidGlassBg;

  static Color getLiquidGlassBorder(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkLiquidGlassBorder
          : lightLiquidGlassBorder;

  static Color getLiquidGlassActive(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkLiquidGlassActive
          : lightLiquidGlassActive;

  // Primary Button Color (Gold in Dark Mode, Deep Black in Light Mode)
  static Color getPrimaryButtonBg(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? goldAccent
          : const Color(0xFF0F172A);

  static Color getPrimaryButtonText(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? Colors.black
          : Colors.white;

  // Active Filter Pill Background
  static Color getActivePillBg(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? goldAccent
          : const Color(0xFF0F172A);

  static Color getActivePillText(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? Colors.black
          : Colors.white;

  // Active Bottom Nav Item Color
  static Color getActiveNavItemColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? goldAccent
          : const Color(0xFF0F172A);

  // Official Brand Typography (Poppins with system fallbacks)
  static TextStyle fontPoppins({
    double? fontSize,
    FontWeight? fontWeight,
    double? letterSpacing,
    double? height,
    Color? color,
    TextDecoration? decoration,
    Color? decorationColor,
  }) {
    return GoogleFonts.poppins(
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      height: height,
      color: color,
      decoration: decoration,
      decorationColor: decorationColor,
    );
  }

  // Backward compatibility alias: redirects to official Poppins brand font
  static TextStyle fontLato({
    double? fontSize,
    FontWeight? fontWeight,
    double? letterSpacing,
    double? height,
    Color? color,
    TextDecoration? decoration,
    Color? decorationColor,
  }) =>
      fontPoppins(
        fontSize: fontSize,
        fontWeight: fontWeight,
        letterSpacing: letterSpacing,
        height: height,
        color: color,
        decoration: decoration,
        decorationColor: decorationColor,
      );

  // Native iOS swipe-back gesture and parallax page transitions
  static const PageTransitionsTheme _pageTransitionsTheme =
      PageTransitionsTheme(
    builders: {
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.android: ZoomPageTransitionsBuilder(),
    },
  );

  // Dark ThemeData Definition
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBgObsidian,
      primaryColor: goldAccent,
      pageTransitionsTheme: _pageTransitionsTheme,
      elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
              backgroundColor: goldAccent,
              foregroundColor: onBrand,
              elevation: 0,
              shadowColor: Colors.transparent,
              surfaceTintColor: Colors.transparent)),
      snackBarTheme:
          const SnackBarThemeData(behavior: SnackBarBehavior.floating),
      colorScheme: const ColorScheme.dark(
        primary: goldAccent,
        secondary: goldAccentHover,
        surface: darkBgSurface,
        onSurface: darkTextPrimary,
        onSurfaceVariant: darkTextSecondary,
        surfaceContainerHighest: darkBgSurfaceElevated,
        onPrimary: onBrand,
        onSecondary: onBrand,
        outline: darkBorderStrong,
        outlineVariant: darkBorderSubtle,
        error: Color(0xFFFFB4AB),
        onError: Color(0xFF690005),
        errorContainer: Color(0xFF410002),
        onErrorContainer: Color(0xFFFFDAD6),
      ),
      fontFamily: GoogleFonts.poppins().fontFamily,
      iconTheme: const IconThemeData(color: darkTextPrimary),
      textTheme: ThemeData(brightness: Brightness.dark).textTheme.apply(
          fontFamily: GoogleFonts.poppins().fontFamily,
          bodyColor: darkTextPrimary,
          displayColor: darkTextPrimary),
      dividerColor: darkBorderSubtle,
      dialogTheme: const DialogThemeData(
          backgroundColor: darkBgSurface,
          surfaceTintColor: Colors.transparent,
          elevation: 0),
      bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: darkBgSurface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          modalElevation: 0),
      popupMenuTheme: const PopupMenuThemeData(
          color: darkBgSurface,
          surfaceTintColor: Colors.transparent,
          elevation: 0),
      inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: darkBgSurfaceElevated,
          hintStyle: const TextStyle(color: darkTextSecondary),
          labelStyle: const TextStyle(color: darkTextSecondary),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: darkBorderSubtle))),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.light,
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
      pageTransitionsTheme: _pageTransitionsTheme,
      elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
              backgroundColor: goldAccent,
              foregroundColor: onBrand,
              elevation: 0,
              shadowColor: Colors.transparent,
              surfaceTintColor: Colors.transparent)),
      snackBarTheme:
          const SnackBarThemeData(behavior: SnackBarBehavior.floating),
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF0F172A),
        secondary: goldAccent,
        surface: lightBgSurface,
        onSurface: lightTextPrimary,
        onSurfaceVariant: lightTextSecondary,
        surfaceContainerHighest: lightBgSurfaceElevated,
        onPrimary: onMedia,
        onSecondary: onBrand,
        outline: lightBorderStrong,
        outlineVariant: lightBorderSubtle,
        error: Color(0xFFBA1A1A),
        onError: onMedia,
        errorContainer: Color(0xFFFFDAD6),
        onErrorContainer: Color(0xFF410002),
      ),
      fontFamily: GoogleFonts.poppins().fontFamily,
      iconTheme: const IconThemeData(color: lightTextPrimary),
      textTheme: ThemeData(brightness: Brightness.light).textTheme.apply(
          fontFamily: GoogleFonts.poppins().fontFamily,
          bodyColor: lightTextPrimary,
          displayColor: lightTextPrimary),
      dividerColor: lightBorderSubtle,
      dialogTheme: const DialogThemeData(
          backgroundColor: lightBgSurface,
          surfaceTintColor: Colors.transparent,
          elevation: 0),
      bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: lightBgSurface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          modalElevation: 0),
      popupMenuTheme: const PopupMenuThemeData(
          color: lightBgSurface,
          surfaceTintColor: Colors.transparent,
          elevation: 0),
      inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: lightBgSurfaceElevated,
          hintStyle: const TextStyle(color: lightTextSecondary),
          labelStyle: const TextStyle(color: lightTextSecondary),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: lightBorderSubtle))),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
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
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: lightBorderSubtle, width: 1),
        ),
      ),
    );
  }

  // Noir AMOLED ThemeData Definition
  static ThemeData get amoledTheme {
    return darkTheme.copyWith(
      scaffoldBackgroundColor: const Color(0xFF000000),
      colorScheme: darkTheme.colorScheme.copyWith(
        surface: const Color(0xFF0A0A0A),
      ),
      cardTheme: darkTheme.cardTheme.copyWith(
        color: const Color(0xFF0A0A0A),
        elevation: 0,
        shadowColor: Colors.transparent,
      ),
    );
  }
}
