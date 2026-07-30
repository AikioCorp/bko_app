import 'package:flutter/material.dart';
import '../core/theme/bko_theme.dart';
import '../core/routing/app_router.dart';

class BkoPodcastApp extends StatelessWidget {
  const BkoPodcastApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Bamako Podcast',
      debugShowCheckedModeBanner: false,
      theme: BkoTheme.darkTheme,
      routerConfig: appRouter,
    );
  }
}
