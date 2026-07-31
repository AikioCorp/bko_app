import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/bko_theme.dart';
import '../core/theme/theme_provider.dart';
import '../core/routing/app_router.dart';

class BkoPodcastApp extends ConsumerWidget {
  const BkoPodcastApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeSetting = ref.watch(themeSettingProvider);

    final ThemeMode mode = switch (themeSetting) {
      AppThemeSetting.system => ThemeMode.system,
      AppThemeSetting.dark => ThemeMode.dark,
      AppThemeSetting.light => ThemeMode.light,
    };

    return MaterialApp.router(
      title: 'Bamako Podcast',
      debugShowCheckedModeBanner: false,
      theme: BkoTheme.lightTheme,
      darkTheme: BkoTheme.darkTheme,
      themeMode: mode,
      routerConfig: appRouter,
    );
  }
}
