import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/bko_theme.dart';
import '../core/theme/theme_provider.dart';
import '../core/routing/app_router.dart';

/// Global fluid scroll behavior providing authentic Apple rubber-band bounce
/// across all scrollable views, lists, and sheets on mobile platforms.
class BkoScrollBehavior extends MaterialScrollBehavior {
  const BkoScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics(
      parent: AlwaysScrollableScrollPhysics(),
    );
  }
}

class BkoPodcastApp extends ConsumerWidget {
  const BkoPodcastApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeSetting = ref.watch(themeSettingProvider);

    final ThemeMode mode = switch (themeSetting) {
      AppThemeSetting.system => ThemeMode.system,
      AppThemeSetting.dark => ThemeMode.dark,
      AppThemeSetting.amoled => ThemeMode.dark,
      AppThemeSetting.light => ThemeMode.light,
    };

    final ThemeData darkTheme = themeSetting == AppThemeSetting.amoled
        ? BkoTheme.amoledTheme
        : BkoTheme.darkTheme;

    return MaterialApp.router(
      title: 'Bamako Podcast',
      debugShowCheckedModeBanner: false,
      theme: BkoTheme.lightTheme,
      darkTheme: darkTheme,
      themeMode: mode,
      scrollBehavior: const BkoScrollBehavior(),
      routerConfig: appRouter,
      builder: (context, child) {
        final dark = Theme.of(context).brightness == Brightness.dark;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: (dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
              .copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: Theme.of(context).scaffoldBackgroundColor,
            systemNavigationBarIconBrightness:
                dark ? Brightness.light : Brightness.dark,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
