import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/bko_theme.dart';
import 'auth_controller.dart';

class VerifyOtpScreen extends ConsumerStatefulWidget {
  final String email;
  final String? redirect;

  const VerifyOtpScreen({
    super.key,
    required this.email,
    this.redirect,
  });

  @override
  ConsumerState<VerifyOtpScreen> createState() => _VerifyOtpScreenState();
}

class _VerifyOtpScreenState extends ConsumerState<VerifyOtpScreen> {
  final _codeController = TextEditingController();
  bool _loading = false;
  bool _resending = false;
  bool _success = false;
  String? _error;
  String? _infoMessage;

  int _resendCooldown = 60;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _resendCooldown = 60);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCooldown > 1) {
        if (mounted) setState(() => _resendCooldown--);
      } else {
        timer.cancel();
        if (mounted) setState(() => _resendCooldown = 0);
      }
    });
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _error = null;
      _infoMessage = null;
    });

    final code = _codeController.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Veuillez saisir le code complet à 6 chiffres.');
      return;
    }

    setState(() => _loading = true);
    final res = await ref.read(authProvider.notifier).verifyOtp(
          email: widget.email,
          otpCode: code,
        );
    if (!mounted) return;
    setState(() => _loading = false);

    if (res.ok) {
      setState(() => _success = true);
      Future.delayed(const Duration(milliseconds: 1400), () {
        if (!mounted) return;
        final queryParams = <String, String>{
          'tab': 'login',
        };
        if (widget.redirect != null && widget.redirect!.isNotEmpty) {
          queryParams['redirect'] = widget.redirect!;
        }
        final uri = Uri(path: '/login', queryParameters: queryParams).toString();
        context.go(uri);
      });
    } else {
      setState(() => _error = res.error ?? 'Code invalide ou expiré.');
    }
  }

  Future<void> _handleResend() async {
    if (_resendCooldown > 0 || _resending) return;

    setState(() {
      _resending = true;
      _error = null;
      _infoMessage = null;
    });

    final res = await ref.read(authProvider.notifier).resendOtp(email: widget.email);
    if (!mounted) return;
    setState(() => _resending = false);

    if (res.ok) {
      setState(() {
        _infoMessage = res.message ?? 'Nouveau code envoyé par e-mail.';
      });
      _startCooldown();
    } else {
      setState(() {
        _error = res.error ?? 'Impossible de renvoyer le code. Réessayez plus tard.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0B0B),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFFB8B8B8), size: 20),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/login');
            }
          },
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF121212),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFF262626)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Icon
                    Center(
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1A11),
                          shape: BoxShape.circle,
                          border: Border.all(color: BkoTheme.goldAccent.withValues(alpha: 0.3)),
                        ),
                        child: const Icon(
                          Icons.mark_email_read_rounded,
                          color: BkoTheme.goldAccent,
                          size: 28,
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Title
                    Text(
                      'Vérification du compte',
                      textAlign: TextAlign.center,
                      style: BkoTheme.fontPoppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Destination explanation
                    Text(
                      'Un code à 6 chiffres a été envoyé à l\'adresse :\n${widget.email}',
                      textAlign: TextAlign.center,
                      style: BkoTheme.fontPoppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        height: 1.45,
                        color: const Color(0xFFB8B8B8),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Feedback banners
                    if (_success) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0E2818),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF15803D)),
                        ),
                        child: Text(
                          'Compte vérifié avec succès ✓\nRedirection vers la connexion...',
                          textAlign: TextAlign.center,
                          style: BkoTheme.fontPoppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF86EFAC),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ] else ...[
                      if (_error != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF3B1214),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF7F1D1D)),
                          ),
                          child: Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: BkoTheme.fontPoppins(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFFFECACA),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (_infoMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1A11),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: BkoTheme.goldAccent.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            _infoMessage!,
                            textAlign: TextAlign.center,
                            style: BkoTheme.fontPoppins(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              color: BkoTheme.goldAccent,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Code Input Field
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF0E0E0E),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF262626)),
                        ),
                        child: TextField(
                          controller: _codeController,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          textAlign: TextAlign.center,
                          style: BkoTheme.fontPoppins(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 10,
                            color: Colors.white,
                          ),
                          decoration: InputDecoration(
                            counterText: '',
                            hintText: '000000',
                            hintStyle: BkoTheme.fontPoppins(
                              fontSize: 26,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 10,
                              color: const Color(0xFF444444),
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Verify Button
                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: BkoTheme.goldAccent,
                            foregroundColor: Colors.black,
                            elevation: 0,
                            disabledBackgroundColor: BkoTheme.goldAccent.withValues(alpha: 0.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: _loading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.black),
                                )
                              : Text(
                                  'Valider le code',
                                  style: BkoTheme.fontPoppins(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Resend Code Action
                      Center(
                        child: _resendCooldown > 0
                            ? Text(
                                'Renvoyer le code dans $_resendCooldown s',
                                style: BkoTheme.fontPoppins(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF757575),
                                ),
                              )
                            : TextButton(
                                onPressed: _resending ? null : _handleResend,
                                child: Text(
                                  _resending ? 'Envoi en cours...' : 'Renvoyer un nouveau code',
                                  style: BkoTheme.fontPoppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: BkoTheme.goldAccent,
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
