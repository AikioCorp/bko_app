import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/shell/app_shell.dart';
import '../../features/home/home_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
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
          builder: (context, state) => const Scaffold(body: Center(child: Text('Explorer Bko Podcast'))),
        ),
        GoRoute(
          path: '/search',
          builder: (context, state) => const Scaffold(body: Center(child: Text('Recherche Bko Podcast'))),
        ),
        GoRoute(
          path: '/library',
          builder: (context, state) => const Scaffold(body: Center(child: Text('Bibliothèque Bko Podcast'))),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const Scaffold(body: Center(child: Text('Profil Bko Podcast'))),
        ),
      ],
    ),
  ],
);
