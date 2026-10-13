import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import '../../core/theme/bko_theme.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/widgets/bko_bounceable.dart';
import '../../core/widgets/bko_haptics.dart';
import '../../core/widgets/equalizer_loader.dart';
import '../../core/widgets/notification_permission_primer.dart';
import 'auth_controller.dart';

class VerifyOtpScreen extends ConsumerStatefulWidget {
  final String email;
  final String? redirect;
  final String? initialCode;

  const VerifyOtpScreen({
    super.key,
    required this.email,
    this.redirect,
    this.initialCode,
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
  String? _devCode;
  String? _lastAttemptedCode;

  int _resendCooldown = 60;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialCode?.trim();
    if (initial != null && initial.isNotEmpty) {
      _devCode = initial;
    } else {
      _devCode = null;
    }
    // Champ vide : l'utilisateur saisit lui-même le code
    _codeController.text = '';
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
    if (_loading || _success) return;

    final code = _codeController.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Veuillez saisir le code complet à 6 chiffres.');
      return;
    }

    _lastAttemptedCode = code;
    FocusScope.of(context).unfocus();
    setState(() {
      _error = null;
      _infoMessage = null;
      _loading = true;
    });

    final res = await ref.read(authProvider.notifier).verifyOtp(
          email: widget.email,
          otpCode: code,
        );
    if (!mounted) return;
    setState(() => _loading = false);

    if (res.ok) {
      BkoHaptics.success();
      setState(() => _success = true);

      Future.delayed(const Duration(milliseconds: 900), () {
        if (!mounted) return;
        // Si l'utilisateur n'a pas encore complété son onboarding de goûts, on l'y dirige.
        if (!res.onboardingCompleted) {
          final queryRedirect = (widget.redirect != null &&
                  widget.redirect!.isNotEmpty &&
                  widget.redirect != '/login')
              ? '?redirect=${Uri.encodeQueryComponent(widget.redirect!)}'
              : '';
          context.go('/taste-onboarding$queryRedirect');
        } else {
          NotificationPermissionPrimer.show(context).then((_) {
            if (!mounted) return;
            final target = (widget.redirect != null &&
                    widget.redirect!.isNotEmpty &&
                    widget.redirect != '/login')
                ? widget.redirect!
                : '/';
            context.go(target);
          });
        }
      });
    } else {
      BkoHaptics.error();
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
        _devCode = (res.otpCode != null && res.otpCode!.isNotEmpty) ? res.otpCode : null;
        _codeController.text = '';
        _infoMessage = res.message ?? 'Nouveau code envoyé.';
      });
      _startCooldown();
    } else {
      setState(() {
        _error = res.error ?? 'Impossible de renvoyer le code.';
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
        leading: const AppBackButton(
          color: Color(0xFFB8B8B8),
          fallbackLocation: '/login',
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
                          'Compte vérifié avec succès ✓\nAccès à votre espace en cours...',
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

                      // Petit badge discret avec le code de test en haut (cliquable pour pré-remplir et valider directement)
                      if (_devCode != null && _devCode!.isNotEmpty) ...[
                        Center(
                          child: BkoBounceable(
                            onTap: () {
                              if (_devCode != null && _devCode!.isNotEmpty && !_loading && !_success) {
                                BkoHaptics.light();
                                _codeController.text = _devCode!;
                                _submit();
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(
                                color: const Color(0xFF19160E),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: BkoTheme.goldAccent.withValues(alpha: 0.35)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(IconsaxPlusBold.shield_security, color: BkoTheme.goldAccent, size: 12),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Code de test : ',
                                    style: BkoTheme.fontPoppins(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: const Color(0xFFB8B8B8),
                                    ),
                                  ),
                                  Text(
                                    _devCode!,
                                    style: BkoTheme.fontPoppins(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 2.0,
                                      color: BkoTheme.goldAccent,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(IconsaxPlusLinear.arrow_circle_right, color: BkoTheme.goldAccent, size: 12),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Code Input Field avec autovalidation dès 6 chiffres
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
                          autofocus: true,
                          onChanged: (val) {
                            final digits = val.replaceAll(RegExp(r'\D'), '');
                            if (digits != val) {
                              _codeController.value = TextEditingValue(
                                text: digits,
                                selection: TextSelection.collapsed(offset: digits.length),
                              );
                            }
                            // Autovalidation instantanée dès que les 6 chiffres sont saisis
                            if (digits.length == 6 && digits != _lastAttemptedCode && !_loading && !_success) {
                              BkoHaptics.light();
                              _submit();
                            }
                          },
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
                        child: BkoBounceable(
                          onTap: _loading
                              ? null
                              : () {
                                  BkoHaptics.light();
                                  _submit();
                                },
                          child: Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _loading
                                  ? BkoTheme.goldAccent.withValues(alpha: 0.5)
                                  : BkoTheme.goldAccent,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: _loading
                                ? const EqualizerLoader(size: 18, color: Colors.black)
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
