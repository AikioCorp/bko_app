import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/bko_theme.dart';
import 'auth_controller.dart';

class VerifyOtpScreen extends ConsumerStatefulWidget {
  final String email;
  const VerifyOtpScreen({super.key, required this.email});

  @override
  ConsumerState<VerifyOtpScreen> createState() => _VerifyOtpScreenState();
}

class _VerifyOtpScreenState extends ConsumerState<VerifyOtpScreen> {
  final _code = TextEditingController();
  bool _loading = false;
  bool _success = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (_code.text.trim().length != 6) {
      setState(() => _error = 'Le code doit comporter 6 chiffres.');
      return;
    }
    setState(() => _loading = true);
    final res = await ref.read(authProvider.notifier).verifyOtp(
          email: widget.email,
          otpCode: _code.text.trim(),
        );
    if (!mounted) return;
    setState(() => _loading = false);

    if (res.ok) {
      setState(() => _success = true);
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) context.go('/login');
      });
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
              Center(
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: BkoTheme.goldAccent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.verified_user_outlined, color: BkoTheme.goldAccent),
                ),
              ),
              const SizedBox(height: 20),
              Text('Vérifiez votre compte',
                  textAlign: TextAlign.center,
                  style: BkoTheme.fontLato(fontSize: 24, fontWeight: FontWeight.w800, color: textPri)),
              const SizedBox(height: 6),
              Text('Saisissez le code à 6 chiffres envoyé à ${widget.email}',
                  textAlign: TextAlign.center,
                  style: BkoTheme.fontLato(fontSize: 13, color: textSec)),
              const SizedBox(height: 28),

              if (_success)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                  ),
                  child: Text('Compte vérifié ✓ Redirection vers la connexion…',
                      textAlign: TextAlign.center,
                      style: BkoTheme.fontLato(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.green.shade300)),
                )
              else ...[
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                    ),
                    child: Text(_error!,
                        textAlign: TextAlign.center,
                        style: BkoTheme.fontLato(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.red.shade300)),
                  ),
                  const SizedBox(height: 16),
                ],
                TextField(
                  controller: _code,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: BkoTheme.fontLato(
                      fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: 12, color: textPri),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '000000',
                    hintStyle: BkoTheme.fontLato(fontSize: 28, letterSpacing: 12, color: textSec),
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
                ),
                const SizedBox(height: 16),
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
                      : Text('VÉRIFIER',
                          style: BkoTheme.fontLato(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.black)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
