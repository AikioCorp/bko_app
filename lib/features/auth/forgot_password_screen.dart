import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import '../../core/network/bko_api.dart';
import '../../core/theme/bko_theme.dart';

class ForgotPasswordScreen extends StatefulWidget {
  final String? initialEmail;
  final String? initialCode;

  const ForgotPasswordScreen({
    super.key,
    this.initialEmail,
    this.initialCode,
  });

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  final _requestFormKey = GlobalKey<FormState>();
  final _resetFormKey = GlobalKey<FormState>();

  int _step = 1; // 1: Email, 2: OTP + Nouveau mot de passe, 3: Succès
  bool _loading = false;
  String? _error;
  String? _infoMessage;

  bool _showPassword = false;
  bool _showConfirm = false;

  Timer? _resendTimer;
  int _resendCooldown = 0;

  @override
  void initState() {
    super.initState();
    if (widget.initialEmail != null && widget.initialEmail!.isNotEmpty) {
      _emailController.text = widget.initialEmail!;
    }
    if (widget.initialCode != null && widget.initialCode!.isNotEmpty) {
      _otpController.text = widget.initialCode!;
      _step = 2;
    }
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _emailController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _startResendCooldown([int seconds = 60]) {
    _resendTimer?.cancel();
    setState(() => _resendCooldown = seconds);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendCooldown <= 1) {
        timer.cancel();
        setState(() => _resendCooldown = 0);
      } else {
        setState(() => _resendCooldown--);
      }
    });
  }

  // Étape 1 : Demande de code OTP
  Future<void> _handleRequestOtp() async {
    if (!_requestFormKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
      _infoMessage = null;
    });

    final email = _emailController.text.trim();
    try {
      final res = await BkoApi.post('/auth/forgot-password', {
        'email': email,
      });

      // Si mode test, auto-remplir l'OTP
      if (res is Map) {
        final devCode = res['testOtpCode'] ?? res['otpCode'];
        if (devCode != null && devCode.toString().isNotEmpty) {
          _otpController.text = devCode.toString();
        }
      }

      if (mounted) {
        setState(() {
          _loading = false;
          _step = 2;
          _infoMessage = 'Un code OTP à 6 chiffres a été envoyé à votre adresse email.';
        });
        _startResendCooldown(60);
      }
    } on ApiException catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.message; });
    } catch (_) {
      if (mounted) setState(() { _loading = false; _error = 'Impossible de contacter le serveur.'; });
    }
  }

  // Renvoi du code OTP
  Future<void> _handleResendOtp() async {
    if (_resendCooldown > 0 || _loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final email = _emailController.text.trim();
    try {
      final res = await BkoApi.post('/auth/forgot-password', {
        'email': email,
      });
      if (res is Map) {
        final devCode = res['testOtpCode'] ?? res['otpCode'];
        if (devCode != null && devCode.toString().isNotEmpty) {
          _otpController.text = devCode.toString();
        }
      }
      if (mounted) {
        setState(() {
          _loading = false;
          _infoMessage = 'Un nouveau code a été envoyé avec succès.';
        });
        _startResendCooldown(60);
      }
    } on ApiException catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.message; });
    } catch (_) {
      if (mounted) setState(() { _loading = false; _error = 'Erreur lors du renvoi.'; });
    }
  }

  // Étape 2 : Réinitialisation avec Code OTP et Nouveau mot de passe
  Future<void> _handleResetPassword() async {
    if (!_resetFormKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final email = _emailController.text.trim();
    final otpCode = _otpController.text.trim();
    final password = _passwordController.text;

    try {
      await BkoApi.post('/auth/reset-password', {
        'email': email,
        'otpCode': otpCode,
        'password': password,
      });

      if (mounted) {
        setState(() {
          _loading = false;
          _step = 3;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.message; });
    } catch (_) {
      if (mounted) setState(() { _loading = false; _error = 'Erreur lors de la réinitialisation.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textPri = BkoTheme.getTextPrimary(context);
    final textSec = BkoTheme.getTextSecondary(context);
    final surface = BkoTheme.getBgSurface(context);
    final border = BkoTheme.getBorderSubtle(context);

    return Scaffold(
      backgroundColor: BkoTheme.getBgObsidian(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(IconsaxPlusLinear.arrow_left_1, color: textPri, size: 22),
          onPressed: () {
            if (_step == 2) {
              setState(() {
                _step = 1;
                _error = null;
                _infoMessage = null;
              });
            } else {
              context.pop();
            }
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Icon
              Center(
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: BkoTheme.getBgSurface(context),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: BkoTheme.goldAccent.withValues(alpha: 0.3)),
                  ),
                  child: Icon(IconsaxPlusLinear.key, color: BkoTheme.getAccent(context), size: 28),
                ),
              ),
              const SizedBox(height: 20),

              // Titre dynamique
              Text(
                _step == 3
                    ? 'Mot de passe modifié !'
                    : _step == 2
                        ? 'Nouveau mot de passe'
                        : 'Mot de passe oublié',
                textAlign: TextAlign.center,
                style: BkoTheme.fontPoppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: textPri,
                ),
              ),
              const SizedBox(height: 8),

              // Description dynamique
              Text(
                _step == 3
                    ? 'Votre compte est sécurisé. Vous pouvez désormais vous connecter avec votre nouveau mot de passe.'
                    : _step == 2
                        ? 'Saisissez le code à 6 chiffres reçu par email et définissez votre nouveau mot de passe.'
                        : 'Saisissez votre email. Nous vous enverrons un code de vérification OTP à 6 chiffres.',
                textAlign: TextAlign.center,
                style: BkoTheme.fontLato(
                  fontSize: 13,
                  color: textSec,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 24),

              // Feedback Erreur
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(IconsaxPlusLinear.info_circle, color: Colors.redAccent, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _error!,
                          style: BkoTheme.fontLato(fontSize: 12.5, color: Colors.redAccent),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Feedback Info / Succès
              if (_infoMessage != null && _step == 2) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: BkoTheme.getSuccess(context).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: BkoTheme.getSuccess(context).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(IconsaxPlusLinear.tick_circle, color: BkoTheme.getSuccess(context), size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _infoMessage!,
                          style: BkoTheme.fontLato(fontSize: 12.5, color: BkoTheme.getSuccess(context)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // ==============================================================
              // ÉTAPE 1 : DEMANDE DE CODE OTP (EMAIL)
              // ==============================================================
              if (_step == 1)
                Form(
                  key: _requestFormKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Adresse email',
                        style: BkoTheme.fontPoppins(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: textPri,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: BkoTheme.fontLato(fontSize: 14.5, color: textPri),
                        decoration: InputDecoration(
                          hintText: 'amadou@mail.com',
                          hintStyle: BkoTheme.fontLato(fontSize: 13.5, color: textSec),
                          prefixIcon: Icon(IconsaxPlusLinear.sms, color: BkoTheme.getTextMuted(context), size: 19),
                          filled: true,
                          fillColor: surface,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: border)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: border)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: BkoTheme.goldAccent)),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty || !val.contains('@')) {
                            return 'Veuillez saisir une adresse email valide.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      ElevatedButton(
                        onPressed: _loading ? null : _handleRequestOtp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: BkoTheme.goldAccent,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: _loading
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                            : Text(
                                'RECEVOIR LE CODE OTP',
                                style: BkoTheme.fontPoppins(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.black),
                              ),
                      ),
                    ],
                  ),
                ),

              // ==============================================================
              // ÉTAPE 2 : CODE OTP + NOUVEAU MOT DE PASSE
              // ==============================================================
              if (_step == 2)
                Form(
                  key: _resetFormKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Badge email avec option modifier
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: border),
                        ),
                        child: Row(
                          children: [
                            Icon(IconsaxPlusLinear.sms, size: 16, color: BkoTheme.getAccent(context)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _emailController.text.trim(),
                                style: BkoTheme.fontLato(fontSize: 13, fontWeight: FontWeight.bold, color: textPri),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            InkWell(
                              onTap: () {
                                setState(() {
                                  _step = 1;
                                  _error = null;
                                  _infoMessage = null;
                                });
                              },
                              child: Text(
                                'Modifier',
                                style: BkoTheme.fontLato(fontSize: 12, fontWeight: FontWeight.bold, color: BkoTheme.getAccent(context)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Code OTP
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Code OTP (6 chiffres)',
                            style: BkoTheme.fontPoppins(fontSize: 12.5, fontWeight: FontWeight.w700, color: textPri),
                          ),
                          InkWell(
                            onTap: _resendCooldown > 0 || _loading ? null : _handleResendOtp,
                            child: Text(
                              _resendCooldown > 0 ? 'Renvoyer ($_resendCooldown s)' : 'Renvoyer le code',
                              style: BkoTheme.fontLato(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: _resendCooldown > 0 ? textSec : BkoTheme.goldAccent,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _otpController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        maxLength: 6,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        style: BkoTheme.fontPoppins(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 8,
                          color: BkoTheme.getAccent(context),
                        ),
                        decoration: InputDecoration(
                          hintText: '000000',
                          counterText: '',
                          hintStyle: BkoTheme.fontPoppins(fontSize: 20, letterSpacing: 8, color: textSec.withValues(alpha: 0.4)),
                          filled: true,
                          fillColor: surface,
                          contentPadding: const EdgeInsets.symmetric(vertical: 14),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: border)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: border)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: BkoTheme.goldAccent)),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().length != 6) {
                            return 'Veuillez saisir les 6 chiffres du code OTP.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Nouveau mot de passe
                      Text(
                        'Nouveau mot de passe',
                        style: BkoTheme.fontPoppins(fontSize: 12.5, fontWeight: FontWeight.w700, color: textPri),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: !_showPassword,
                        style: BkoTheme.fontLato(fontSize: 14.5, color: textPri),
                        decoration: InputDecoration(
                          hintText: 'Au moins 8 caractères',
                          hintStyle: BkoTheme.fontLato(fontSize: 13.5, color: textSec),
                          prefixIcon: Icon(IconsaxPlusLinear.lock, color: BkoTheme.getTextMuted(context), size: 19),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _showPassword ? IconsaxPlusLinear.eye_slash : IconsaxPlusLinear.eye,
                              color: BkoTheme.getTextMuted(context),
                              size: 19,
                            ),
                            onPressed: () => setState(() => _showPassword = !_showPassword),
                          ),
                          filled: true,
                          fillColor: surface,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: border)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: border)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: BkoTheme.goldAccent)),
                        ),
                        validator: (val) {
                          if (val == null || val.length < 8) {
                            return 'Le mot de passe doit comporter au moins 8 caractères.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // Confirmation
                      Text(
                        'Confirmer le mot de passe',
                        style: BkoTheme.fontPoppins(fontSize: 12.5, fontWeight: FontWeight.w700, color: textPri),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _confirmController,
                        obscureText: !_showConfirm,
                        style: BkoTheme.fontLato(fontSize: 14.5, color: textPri),
                        decoration: InputDecoration(
                          hintText: 'Répétez le mot de passe',
                          hintStyle: BkoTheme.fontLato(fontSize: 13.5, color: textSec),
                          prefixIcon: Icon(IconsaxPlusLinear.lock, color: BkoTheme.getTextMuted(context), size: 19),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _showConfirm ? IconsaxPlusLinear.eye_slash : IconsaxPlusLinear.eye,
                              color: BkoTheme.getTextMuted(context),
                              size: 19,
                            ),
                            onPressed: () => setState(() => _showConfirm = !_showConfirm),
                          ),
                          filled: true,
                          fillColor: surface,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: border)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: border)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: BkoTheme.goldAccent)),
                        ),
                        validator: (val) {
                          if (val != _passwordController.text) {
                            return 'Les deux mots de passe ne correspondent pas.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      ElevatedButton(
                        onPressed: _loading ? null : _handleResetPassword,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: BkoTheme.goldAccent,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: _loading
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                            : Text(
                                'RÉINITIALISER LE MOT DE PASSE',
                                style: BkoTheme.fontPoppins(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.black),
                              ),
                      ),
                    ],
                  ),
                ),

              // ==============================================================
              // ÉTAPE 3 : CONFIRMATION SUCCÈS
              // ==============================================================
              if (_step == 3)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: BkoTheme.getSuccess(context).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(color: BkoTheme.getSuccess(context).withValues(alpha: 0.35)),
                        ),
                        child: Icon(IconsaxPlusLinear.tick_circle, color: BkoTheme.getSuccess(context), size: 38),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Toutes les anciennes sessions actives ont été déconnectées par mesure de sécurité.',
                      textAlign: TextAlign.center,
                      style: BkoTheme.fontLato(fontSize: 13, color: textSec, height: 1.4),
                    ),
                    const SizedBox(height: 28),

                    ElevatedButton(
                      onPressed: () => context.go('/login'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: BkoTheme.goldAccent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: Text(
                        'SE CONNECTER MAINTENANT',
                        style: BkoTheme.fontPoppins(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.black),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
