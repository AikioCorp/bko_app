import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/bko_theme.dart';
import 'auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _identifier = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final ok = await ref.read(authProvider.notifier).login(
          _identifier.text.trim(),
          _password.text,
        );
    if (ok && mounted) {
      final redirect =
          GoRouterState.of(context).uri.queryParameters['redirect'];
      context.go(redirect != null && redirect.startsWith('/') ? redirect : '/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final textPri = BkoTheme.getTextPrimary(context);
    final textSec = BkoTheme.getTextSecondary(context);
    final surface = BkoTheme.getBgSurface(context);
    final border = BkoTheme.getBorderSubtle(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: BkoTheme.goldAccent,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    alignment: Alignment.center,
                    child: const Text('🎙️', style: TextStyle(fontSize: 30)),
                  ),
                ),
                const SizedBox(height: 20),
                Text('Connexion',
                    textAlign: TextAlign.center,
                    style: BkoTheme.fontLato(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: textPri)),
                const SizedBox(height: 6),
                Text('Accédez à votre bibliothèque et vos abonnements',
                    textAlign: TextAlign.center,
                    style: BkoTheme.fontLato(fontSize: 13, color: textSec)),
                const SizedBox(height: 28),
                if (auth.error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: Colors.red.withValues(alpha: 0.3)),
                    ),
                    child: Text(auth.error!,
                        textAlign: TextAlign.center,
                        style: BkoTheme.fontLato(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.red.shade300)),
                  ),
                  const SizedBox(height: 16),
                ],
                _field(_identifier, 'Email ou téléphone', Icons.person_outline,
                    surface, border, textPri, textSec),
                const SizedBox(height: 12),
                _field(_password, 'Mot de passe', Icons.lock_outline, surface,
                    border, textPri, textSec,
                    obscure: true),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: auth.isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BkoTheme.goldAccent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: auth.isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.black))
                      : Text('SE CONNECTER',
                          style: BkoTheme.fontLato(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Colors.black)),
                ),
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: () => context.go('/register'),
                    child: Text('Pas encore de compte ? Créer un compte',
                        style: BkoTheme.fontLato(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: BkoTheme.goldAccent)),
                  ),
                ),
                Center(
                  child: TextButton(
                    onPressed: () => context.go('/'),
                    child: Text('Continuer sans compte',
                        style: BkoTheme.fontLato(fontSize: 12, color: textSec)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String hint,
    IconData icon,
    Color surface,
    Color border,
    Color textPri,
    Color textSec, {
    bool obscure = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: BkoTheme.fontLato(fontSize: 14, color: textPri),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: BkoTheme.fontLato(fontSize: 14, color: textSec),
        prefixIcon: Icon(icon, color: textSec, size: 20),
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: BkoTheme.goldAccent),
        ),
      ),
    );
  }
}
