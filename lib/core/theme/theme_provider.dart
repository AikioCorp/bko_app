import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeSetting {
  system,
  dark,
  light,
  amoled,
}

class ThemeModeNotifier extends StateNotifier<AppThemeSetting> {
  static const _themePrefKey = 'bko_app_theme_setting_v1';

  ThemeModeNotifier() : super(AppThemeSetting.system) {
    _loadPersistedTheme();
  }

  Future<void> _loadPersistedTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_themePrefKey);
      if (saved != null) {
        final match = AppThemeSetting.values.where((e) => e.name == saved).firstOrNull;
        if (match != null) {
          state = match;
        }
      }
    } catch (_) {}
  }

  Future<void> setThemeSetting(AppThemeSetting setting) async {
    state = setting;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themePrefKey, setting.name);
    } catch (_) {}
  }

  ThemeMode get currentThemeMode {
    switch (state) {
      case AppThemeSetting.system:
        return ThemeMode.system;
      case AppThemeSetting.dark:
      case AppThemeSetting.amoled:
        return ThemeMode.dark;
      case AppThemeSetting.light:
        return ThemeMode.light;
    }
  }
}

final themeSettingProvider = StateNotifierProvider<ThemeModeNotifier, AppThemeSetting>((ref) {
  return ThemeModeNotifier();
});
