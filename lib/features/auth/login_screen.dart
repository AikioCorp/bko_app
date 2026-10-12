import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'auth_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  @override
  Widget build(BuildContext context) {
    final state = GoRouterState.of(context);
    final redirect = state.uri.queryParameters['redirect'];
    final tab = state.uri.queryParameters['tab'];

    return AuthScreen(
      initialTab: tab == 'register' ? AuthTab.register : AuthTab.login,
      redirect: redirect,
    );
  }
}
