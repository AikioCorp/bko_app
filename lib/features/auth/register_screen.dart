import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'auth_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  @override
  Widget build(BuildContext context) {
    final state = GoRouterState.of(context);
    final redirect = state.uri.queryParameters['redirect'];
    final tab = state.uri.queryParameters['tab'];

    return AuthScreen(
      initialTab: tab == 'login' ? AuthTab.login : AuthTab.register,
      redirect: redirect,
    );
  }
}
