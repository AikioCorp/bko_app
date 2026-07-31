import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/shell/app_shell.dart';
import '../../features/home/home_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    ShellRoute(
      builder: (context, state, child) {
        return AppShell(child: child);
      },
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: '/explore',
          builder: (context, state) => const Scaffold(
            body: Center(child: Text('Explorer Bko Podcast', style: TextStyle(color: Colors.white))),
          ),
        ),
        GoRoute(
          path: '/search',
          builder: (context, state) => const Scaffold(
            body: Center(child: Text('Recherche Bko Podcast', style: TextStyle(color: Colors.white))),
          ),
        ),
        GoRoute(
          path: '/library',
          builder: (context, state) => const Scaffold(
            body: Center(child: Text('Bibliothèque Bko Podcast', style: TextStyle(color: Colors.white))),
          ),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const Scaffold(
            body: Center(child: Text('Profil Bko Podcast', style: TextStyle(color: Colors.white))),
          ),
        ),
      ],
    ),
  ],
);
