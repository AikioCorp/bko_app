import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/bko_theme.dart';
import 'auth_controller.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _fullName.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _error = null;
    });

    if (_fullName.text.trim().isEmpty || _email.text.trim().isEmpty || _password.text.length < 8) {
      setState(() => _error = 'Nom, email et mot de passe (8+ caractères) requis.');
      return;
    }

    setState(() => _loading = true);
    final res = await ref.read(authProvider.notifier).register(
          fullName: _fullName.text.trim(),
          email: _email.text.trim(),
          password: _password.text,
          phoneNumber: _phone.text,
        );
    if (!mounted) return;
    setState(() => _loading = false);

    if (res.ok) {
      context.go('/verify-otp?email=${Uri.encodeQueryComponent(_email.text.trim())}');
    } else {
      setState(() => _error = res.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textPri = BkoTheme.getTextPrimary(context);
    final textSec = BkoTheme.getTextSecondary(context);
    final surface = BkoTheme.getBgSurface(context);
    final border = BkoTheme.getBorderSubtle(context);

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Créer un compte',
                  style: BkoTheme.fontLato(fontSize: 26, fontWeight: FontWeight.w800, color: textPri)),
              const SizedBox(height: 6),
              Text('Rejoignez Bamako Podcast et personnalisez votre écoute',
                  style: BkoTheme.fontLato(fontSize: 13, color: textSec)),
              const SizedBox(height: 24),

              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                  ),
                  child: Text(_error!,
                      style: BkoTheme.fontLato(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.red.shade300)),
                ),
                const SizedBox(height: 16),
              ],

              _field(_fullName, 'Nom complet', Icons.person_outline, surface, border, textPri, textSec),
              const SizedBox(height: 12),
              _field(_email, 'Email', Icons.mail_outline, surface, border, textPri, textSec,
                  keyboard: TextInputType.emailAddress),
              const SizedBox(height: 12),
              _field(_phone, 'Téléphone (optionnel)', Icons.phone_outlined, surface, border, textPri, textSec,
                  keyboard: TextInputType.phone),
              const SizedBox(height: 12),
              _field(_password, 'Mot de passe (8+ caractères)', Icons.lock_outline, surface, border, textPri, textSec,
                  obscure: true),
              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: BkoTheme.goldAccent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : Text("S'INSCRIRE",
                        style: BkoTheme.fontLato(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.black)),
              ),
              const SizedBox(height: 16),

              Center(
                child: TextButton(
                  onPressed: () => context.go('/login'),
                  child: Text('Déjà un compte ? Se connecter',
                      style: BkoTheme.fontLato(fontSize: 12, color: textSec)),
                ),
              ),
            ],
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
    TextInputType? keyboard,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboard,
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
