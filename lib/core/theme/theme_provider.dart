import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppThemeSetting {
  system,
  dark,
  light,
}

class ThemeModeNotifier extends StateNotifier<AppThemeSetting> {
  ThemeModeNotifier() : super(AppThemeSetting.system);

  void setThemeSetting(AppThemeSetting setting) {
    state = setting;
  }

  ThemeMode get currentThemeMode {
    switch (state) {
      case AppThemeSetting.system:
        return ThemeMode.system;
      case AppThemeSetting.dark:
        return ThemeMode.dark;
      case AppThemeSetting.light:
        return ThemeMode.light;
    }
  }
}

final themeSettingProvider = StateNotifierProvider<ThemeModeNotifier, AppThemeSetting>((ref) {
  return ThemeModeNotifier();
});
