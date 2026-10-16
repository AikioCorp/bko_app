import 'dart:math' as math;
import 'package:country_picker/country_picker.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/bko_theme.dart';
import '../../core/widgets/bko_bounceable.dart';
import '../../core/widgets/bko_haptics.dart';
import '../../core/widgets/capitalize_words_input_formatter.dart';
import 'auth_controller.dart';
import '../../core/routing/auth_navigation.dart';
import 'widgets/auth_legal_sheets.dart';

class PhoneNumberTextInputFormatter extends TextInputFormatter {
  final String countryCode;

  const PhoneNumberTextInputFormatter(this.countryCode);

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final rawDigits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final formatted = formatNumber(rawDigits, countryCode);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  static String formatNumber(String digits, String countryCode) {
    if (digits.isEmpty) return '';
    final cc = countryCode.toUpperCase();

    // 1. Mali, Burkina Faso, Niger (8 chiffres : 2-2-2-2, ex: 70 00 00 90)
    if (cc == 'ML' || cc == 'BF' || cc == 'NE') {
      final buffer = StringBuffer();
      for (int i = 0; i < digits.length && i < 8; i++) {
        if (i > 0 && i % 2 == 0) buffer.write(' ');
        buffer.write(digits[i]);
      }
      return buffer.toString();
    }

    // 2. Ghana (10 chiffres ex: 050 706 6762, ou 9 chiffres: 50 706 6762)
    if (cc == 'GH') {
      final buffer = StringBuffer();
      if (digits.startsWith('0')) {
        for (int i = 0; i < digits.length && i < 10; i++) {
          if (i == 3 || i == 6) buffer.write(' ');
          buffer.write(digits[i]);
        }
      } else {
        for (int i = 0; i < digits.length && i < 9; i++) {
          if (i == 2 || i == 5) buffer.write(' ');
          buffer.write(digits[i]);
        }
      }
      return buffer.toString();
    }

    // 3. Côte d'Ivoire & France (10 chiffres : 2-2-2-2-2, ex: 07 00 00 00 00 ou 06 12 34 56 78)
    if (cc == 'CI' || cc == 'FR') {
      final buffer = StringBuffer();
      for (int i = 0; i < digits.length && i < 10; i++) {
        if (i > 0 && i % 2 == 0) buffer.write(' ');
        buffer.write(digits[i]);
      }
      return buffer.toString();
    }

    // 4. Sénégal (9 chiffres : 2-3-2-2, ex: 77 123 45 67)
    if (cc == 'SN') {
      final buffer = StringBuffer();
      for (int i = 0; i < digits.length && i < 9; i++) {
        if (i == 2 || i == 5 || i == 7) buffer.write(' ');
        buffer.write(digits[i]);
      }
      return buffer.toString();
    }

    // 5. Guinée (9 chiffres : 3-2-2-2, ex: 620 00 00 00)
    if (cc == 'GN') {
      final buffer = StringBuffer();
      for (int i = 0; i < digits.length && i < 9; i++) {
        if (i == 3 || i == 5 || i == 7) buffer.write(' ');
        buffer.write(digits[i]);
      }
      return buffer.toString();
    }

    // Défaut : groupements de 3 chiffres
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length && i < 15; i++) {
      if (i > 0 && i % 3 == 0) buffer.write(' ');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }
}

enum AuthTab { login, register }

class AuthScreen extends ConsumerStatefulWidget {
  final AuthTab initialTab;
  final String? redirect;

  const AuthScreen({
    super.key,
    this.initialTab = AuthTab.login,
    this.redirect,
  });

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  late AuthTab _activeTab;

  // Login form controllers
  final _loginIdentifier = TextEditingController();
  final _loginPassword = TextEditingController();
  bool _showLoginPassword = false;
  bool _isOtpLoginMode = false;
  bool _otpSent = false;
  final _otpCodeController = TextEditingController();

  // Register form controllers
  final _registerName = TextEditingController();
  final _registerEmail = TextEditingController();
  final _registerPhone = TextEditingController();
  final _registerPassword = TextEditingController();
  bool _showRegisterPassword = false;
  bool _acceptTerms = false;
  Country _phoneCountry = Country.parse('ML');
  final Map<TextEditingController, String> _fieldErrors = {};
  String? _termsError;

  void _selectPhoneCountry() {
    FocusScope.of(context).unfocus();
    showCountryPicker(
      context: context,
      showPhoneCode: true,
      searchAutofocus: false,
      favorite: const ['ML', 'CI', 'SN', 'BF', 'GN', 'NE', 'FR'],
      countryListTheme: CountryListThemeData(
        backgroundColor: BkoTheme.getBgSurface(context),
        textStyle: BkoTheme.fontPoppins(fontSize: 14, color: BkoTheme.getTextPrimary(context)),
        searchTextStyle: BkoTheme.fontPoppins(fontSize: 14, color: BkoTheme.getTextPrimary(context)),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        bottomSheetHeight: MediaQuery.of(context).size.height * 0.72,
        inputDecoration: InputDecoration(
          hintText: 'Rechercher un pays ou un indicatif...',
          hintStyle: BkoTheme.fontPoppins(fontSize: 13, color: BkoTheme.getTextMuted(context)),
          prefixIcon: Icon(IconsaxPlusLinear.search_normal_1, color: BkoTheme.getTextMuted(context), size: 18),
          filled: true,
          fillColor: BkoTheme.getBgObsidian(context),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: BkoTheme.getBorderSubtle(context)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: BkoTheme.getBorderSubtle(context)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: BkoTheme.goldAccent, width: 1.2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
      onSelect: (country) => setState(() {
        _phoneCountry = country;
        _fieldErrors.remove(_registerPhone);
        if (_registerPhone.text.isNotEmpty) {
          final rawDigits = _registerPhone.text.replaceAll(RegExp(r'\D'), '');
          _registerPhone.text = PhoneNumberTextInputFormatter.formatNumber(rawDigits, _phoneCountry.countryCode);
        }
      }),
    );
  }

  String _getPhoneHintForCountry(String countryCode) {
    switch (countryCode.toUpperCase()) {
      case 'ML':
        return '70 00 00 90';
      case 'GH':
        return '050 706 6762';
      case 'CI':
        return '07 00 00 00 00';
      case 'SN':
        return '77 123 45 67';
      case 'BF':
        return '70 00 00 00';
      case 'GN':
        return '620 00 00 00';
      case 'FR':
        return '06 12 34 56 78';
      default:
        return 'Numéro national';
    }
  }

  Widget _buildPhoneInputRow() {
    final error = _fieldErrors[_registerPhone];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Sélecteur de pays compact (Drapeau + Indicatif + flèche)
            InkWell(
              onTap: _isSubmitting ? null : _selectPhoneCountry,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: BkoTheme.getBgObsidian(context),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: error != null
                        ? Theme.of(context).colorScheme.error
                        : BkoTheme.getBorderSubtle(context),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _phoneCountry.flagEmoji,
                      style: const TextStyle(fontSize: 18),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '+${_phoneCountry.phoneCode}',
                      style: BkoTheme.fontPoppins(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: BkoTheme.getTextPrimary(context),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      IconsaxPlusLinear.arrow_down_1,
                      size: 14,
                      color: BkoTheme.getTextMuted(context),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Champ de saisie du numéro national sur la même ligne (hauteur 52)
            Expanded(
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  color: BkoTheme.getBgObsidian(context),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: error != null
                        ? Theme.of(context).colorScheme.error
                        : BkoTheme.getBorderSubtle(context),
                  ),
                ),
                child: TextField(
                  controller: _registerPhone,
                  keyboardType: TextInputType.phone,
                  autofillHints: const [AutofillHints.telephoneNumber],
                  textInputAction: TextInputAction.next,
                  inputFormatters: [
                    PhoneNumberTextInputFormatter(_phoneCountry.countryCode),
                  ],
                  onChanged: (value) {
                    if (_fieldErrors.containsKey(_registerPhone)) {
                      setState(() => _fieldErrors.remove(_registerPhone));
                    }
                  },
                  style: BkoTheme.fontPoppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: BkoTheme.getTextPrimary(context),
                  ),
                  decoration: InputDecoration(
                    hintText: _getPhoneHintForCountry(_phoneCountry.countryCode),
                    hintStyle: BkoTheme.fontPoppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: BkoTheme.getTextMuted(context),
                    ),
                    prefixIcon: Icon(
                      IconsaxPlusLinear.call,
                      color: BkoTheme.getTextMuted(context),
                      size: 18,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
            ),
          ],
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 6),
            child: Semantics(
              liveRegion: true,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    IconsaxPlusLinear.info_circle,
                    size: 13,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      error,
                      style: BkoTheme.fontPoppins(
                        fontSize: 12,
                        height: 1.3,
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // Local feedback state
  String? _localError;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _activeTab = widget.initialTab;
  }

  @override
  void didUpdateWidget(covariant AuthScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab) {
      setState(() {
        _activeTab = widget.initialTab;
      });
    }
  }

  @override
  void dispose() {
    _loginIdentifier.dispose();
    _loginPassword.dispose();
    _otpCodeController.dispose();
    _registerName.dispose();
    _registerEmail.dispose();
    _registerPhone.dispose();
    _registerPassword.dispose();
    super.dispose();
  }

  void _navigatePostLogin({Map<String, dynamic>? user, bool isNewUser = false}) {
    final currentUser = user ?? ref.read(authProvider).user;
    final decision = resolvePostAuthDecision(
      currentUser,
      explicitTarget: widget.redirect,
      isNewUser: isNewUser,
    );
    context.go(decision.path);
  }

  void _switchTab(AuthTab tab) {
    if (_activeTab == tab) return;
    ref.read(authProvider.notifier).clearError();
    setState(() {
      _activeTab = tab;
      _localError = null;
      _fieldErrors.clear();
      _termsError = null;
    });
  }

  int _calculatePasswordStrength(String password) {
    if (password.isEmpty) return 0;
    int score = 0;
    if (password.length >= 8) score++;
    if (RegExp(r'[A-Z]').hasMatch(password)) score++;
    if (RegExp(r'[0-9]').hasMatch(password)) score++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(password)) score++;
    return score;
  }

  Future<void> _handleLogin() async {
    FocusScope.of(context).unfocus();
    setState(() { _localError = null; _fieldErrors.clear(); });

    final identifier = _loginIdentifier.text.trim();
    final password = _loginPassword.text;

    if (identifier.isEmpty || password.isEmpty) {
      setState(() {
        if (identifier.isEmpty) _fieldErrors[_loginIdentifier] = 'Renseignez votre identifiant.';
        if (password.isEmpty) _fieldErrors[_loginPassword] = 'Renseignez votre mot de passe.';
      });
      return;
    }

    setState(() => _isSubmitting = true);
    final res = await ref.read(authProvider.notifier).login(identifier, password);
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (res.ok) {
      _navigatePostLogin(isNewUser: !res.onboardingCompleted);
    } else if (res.isNotVerified) {
      // Compte non vérifié -> proposer de valider l'OTP
      setState(() {
        _localError = 'Ce compte n\'est pas encore vérifié. Veuillez saisir le code OTP envoyé.';
      });
    } else {
      setState(() {
        _localError = res.error ?? 'Identifiant ou mot de passe incorrect.';
      });
    }
  }

  Future<void> _handleRequestOtpLogin() async {
    FocusScope.of(context).unfocus();
    setState(() { _localError = null; _fieldErrors.clear(); });

    final identifier = _loginIdentifier.text.trim();
    if (identifier.isEmpty) {
      setState(() {
        _fieldErrors[_loginIdentifier] = 'Saisissez votre e-mail ou téléphone.';
      });
      return;
    }

    setState(() => _isSubmitting = true);
    final res = await ref.read(authProvider.notifier).requestOtpLogin(identifier: identifier);
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (res.ok) {
      BkoHaptics.success();
      setState(() {
        _otpSent = true;
      });
    } else {
      BkoHaptics.error();
      setState(() {
        _localError = res.error ?? 'Impossible d\'envoyer le code de connexion.';
      });
    }
  }

  Future<void> _handleVerifyOtpLogin() async {
    FocusScope.of(context).unfocus();
    setState(() { _localError = null; });

    final identifier = _loginIdentifier.text.trim();
    final code = _otpCodeController.text.trim();

    if (code.length != 6) {
      setState(() {
        _localError = 'Veuillez saisir le code à 6 chiffres reçu.';
      });
      return;
    }

    setState(() => _isSubmitting = true);
    final res = await ref.read(authProvider.notifier).verifyOtpLogin(
      identifier: identifier,
      otpCode: code,
    );
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (res.ok) {
      BkoHaptics.success();
      _navigatePostLogin(isNewUser: !res.onboardingCompleted);
    } else {
      BkoHaptics.error();
      setState(() {
        _localError = res.error ?? 'Code de connexion incorrect ou expiré.';
      });
    }
  }

  Future<void> _handleGoogleLogin() async {
    FocusScope.of(context).unfocus();
    setState(() { _localError = null; _isSubmitting = true; });

    final res = await ref.read(authProvider.notifier).loginWithGoogle();
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (res.ok) {
      _navigatePostLogin(isNewUser: !res.onboardingCompleted);
    } else if (res.error != null) {
      setState(() => _localError = res.error);
    }
  }

  Future<void> _handleRegister() async {
    FocusScope.of(context).unfocus();
    setState(() { _localError = null; _fieldErrors.clear(); _termsError = null; });

    final fullName =
        CapitalizeWordsInputFormatter.capitalize(_registerName.text.trim());
    final email = _registerEmail.text.trim();
    final phone = _registerPhone.text.trim();
    final password = _registerPassword.text;

    String? normalizedPhone;
    if (fullName.isEmpty) _fieldErrors[_registerName] = 'Renseignez votre nom ou pseudo.';
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      _fieldErrors[_registerEmail] = 'Saisissez une adresse e-mail valide.';
    }
    if (password.length < 8 || password.length > 72) {
      _fieldErrors[_registerPassword] = 'Utilisez entre 8 et 72 caractères.';
    }
    if (phone.isNotEmpty) {
      final rawDigits = phone.replaceAll(RegExp(r'\D'), '');
      final cc = _phoneCountry.countryCode.toUpperCase();

      if (cc == 'ML') {
        if (rawDigits.length != 8) {
          _fieldErrors[_registerPhone] = 'Le numéro malien doit comporter 8 chiffres (ex. 70 00 00 90).';
        } else {
          normalizedPhone = '+223$rawDigits';
        }
      } else if (cc == 'GH') {
        if (rawDigits.length < 9 || rawDigits.length > 10) {
          _fieldErrors[_registerPhone] = 'Numéro invalide pour le Ghana (ex. 050 706 6762).';
        } else {
          final nsn = rawDigits.startsWith('0') ? rawDigits.substring(1) : rawDigits;
          normalizedPhone = '+233$nsn';
        }
      } else if (cc == 'CI' || cc == 'FR') {
        if (rawDigits.length != 10) {
          _fieldErrors[_registerPhone] = 'Le numéro doit comporter 10 chiffres (ex. ${cc == 'CI' ? '07 00 00 00 00' : '06 12 34 56 78'}).';
        } else {
          final nsn = rawDigits.startsWith('0') ? rawDigits.substring(1) : rawDigits;
          final pCode = cc == 'CI' ? '225' : '33';
          normalizedPhone = '+$pCode$nsn';
        }
      } else if (cc == 'SN' || cc == 'GN') {
        if (rawDigits.length != 9) {
          _fieldErrors[_registerPhone] = 'Le numéro doit comporter 9 chiffres (ex. ${cc == 'SN' ? '77 123 45 67' : '620 00 00 00'}).';
        } else {
          final pCode = cc == 'SN' ? '221' : '224';
          normalizedPhone = '+$pCode$rawDigits';
        }
      } else {
        try {
          final iso = IsoCode.values.byName(_phoneCountry.countryCode);
          final number = PhoneNumber.parse(rawDigits, destinationCountry: iso);
          if (!number.isValid() || number.isoCode != iso) {
            _fieldErrors[_registerPhone] = 'Numéro invalide pour ${_phoneCountry.name}.';
          } else {
            normalizedPhone = '+${number.countryCode}${number.nsn}';
          }
        } catch (_) {
          if (rawDigits.length < 7 || rawDigits.length > 15) {
            _fieldErrors[_registerPhone] = 'Numéro invalide pour ${_phoneCountry.name}.';
          } else {
            normalizedPhone = '+${_phoneCountry.phoneCode}$rawDigits';
          }
        }
      }
    }
    if (!_acceptTerms) _termsError = 'Acceptez les conditions pour continuer.';
    if (_fieldErrors.isNotEmpty || _termsError != null) { setState(() {}); return; }

    setState(() => _isSubmitting = true);
    final res = await ref.read(authProvider.notifier).register(
          fullName: fullName,
          email: email,
          password: password,
          phoneNumber: normalizedPhone,
        );
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (res.ok) {
      final cleanRedirect = sanitizeRedirect(widget.redirect);
      final queryRedirect = cleanRedirect.isNotEmpty ? '&redirect=${Uri.encodeQueryComponent(cleanRedirect)}' : '';
      final codeParam = (res.otpCode != null && res.otpCode!.isNotEmpty)
          ? '&code=${Uri.encodeQueryComponent(res.otpCode!)}'
          : '';
      context.go('/verify-otp?email=${Uri.encodeQueryComponent(email)}$queryRedirect$codeParam');
    } else {
      setState(() {
        _localError = res.error ?? 'Une erreur est survenue lors de l\'inscription.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    // If user is already authenticated
    if (authState.isAuthenticated && authState.user != null && !_isSubmitting) {
      return _buildAlreadyAuthenticated(context, authState.user!);
    }

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
        backgroundColor: BkoTheme.getBgObsidian(context),
        body: SafeArea(
          child: Column(
            children: [
              // Top Bar with Back, Logo, and Brand Name
              _buildTopBar(context),

              // Scrollable Content
              Expanded(
                child: SingleChildScrollView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Central Auth Card
                          Container(
                            padding: const EdgeInsets.all(22),
                            decoration: BoxDecoration(
                              color: BkoTheme.getBgSurface(context),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: BkoTheme.getBorderSubtle(context)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Tab Switcher
                                _buildTabSwitcher(),

                                const SizedBox(height: 20),

                                // Error Display (if any)
                                if (_localError != null || authState.error != null)
                                  _buildErrorBanner(_localError ?? authState.error!),

                                // Active Tab Form
                                AnimatedCrossFade(
                                  duration: const Duration(milliseconds: 220),
                                  crossFadeState: _activeTab == AuthTab.login
                                      ? CrossFadeState.showFirst
                                      : CrossFadeState.showSecond,
                                  firstChild: _buildLoginForm(),
                                  secondChild: _buildRegisterForm(),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Free Listening Card
                          _buildFreeListeningCard(),

                          const SizedBox(height: 20),

                          // Legal Footer Links
                          _buildLegalFooter(),

                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Back Button
          Semantics(
            button: true,
            label: 'Retour',
            child: SizedBox(
              width: 48,
              height: 48,
              child: IconButton(
                onPressed: () {
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  } else {
                    context.go('/');
                  }
                },
                icon: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: BkoTheme.getTextSecondary(context),
                  size: 20,
                ),
              ),
            ),
          ),

          // Logo & Brand Name
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: BkoTheme.getBgSurface(context),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: BkoTheme.getBorderSubtle(context)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: Image.asset(
                    'assets/brand/app_icon.png',
                    width: 32,
                    height: 32,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Icon(
                      Icons.mic_rounded,
                      color: BkoTheme.getAccent(context),
                      size: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'BAMAKO PODCAST',
                style: BkoTheme.fontPoppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  color: BkoTheme.getTextPrimary(context),
                ),
              ),
            ],
          ),

          // Symmetric spacer to keep the logo perfectly centered
          const SizedBox(width: 48, height: 48),
        ],
      ),
    );
  }

  Widget _buildTabSwitcher() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: BkoTheme.getBgSurface(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: BkoTheme.getBorderSubtle(context)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTabButton(
              tab: AuthTab.login,
              label: 'Connexion',
              icon: Icons.login_rounded,
              isActive: _activeTab == AuthTab.login,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _buildTabButton(
              tab: AuthTab.register,
              label: 'Inscription',
              icon: Icons.person_add_rounded,
              isActive: _activeTab == AuthTab.register,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required AuthTab tab,
    required String label,
    required IconData icon,
    required bool isActive,
  }) {
    return Semantics(
      button: true,
      selected: isActive,
      child: Material(
        color: isActive ? BkoTheme.goldAccent : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _switchTab(tab),
          child: Container(
            height: 42,
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: isActive ? Colors.black : BkoTheme.getTextSecondary(context),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: BkoTheme.fontPoppins(
                    fontSize: 13,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    color: isActive ? Colors.black : BkoTheme.getTextSecondary(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    final isUnverified = message.toLowerCase().contains('vérifié') || message.toLowerCase().contains('otp');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.errorContainer),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline_rounded, color: BkoTheme.getError(context), size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: BkoTheme.fontPoppins(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                    color: BkoTheme.getError(context),
                  ),
                ),
              ),
            ],
          ),
          if (isUnverified) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  final email = _loginIdentifier.text.trim();
                  final pwd = _loginPassword.text;
                  final testCode = (100000 + math.Random().nextInt(900000)).toString();
                  final pwdParam = pwd.isNotEmpty ? '&pwd=${Uri.encodeQueryComponent(pwd)}' : '';
                  context.push('/verify-otp?email=${Uri.encodeQueryComponent(email)}&code=$testCode$pwdParam');
                },
                style: TextButton.styleFrom(
                  foregroundColor: BkoTheme.goldAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                ),
                child: Text(
                  'Confirmer mon code OTP →',
                  style: BkoTheme.fontPoppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: BkoTheme.getAccent(context),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoginForm() {
    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Switcher Mode : Mot de passe vs Code instantané par e-mail
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: BkoTheme.getBgObsidian(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: BkoTheme.getBorderSubtle(context)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: BkoBounceable(
                    onTap: () => setState(() {
                      _isOtpLoginMode = false;
                      _localError = null;
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: !_isOtpLoginMode ? BkoTheme.getBgSurfaceElevated(context) : Colors.transparent,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Center(
                        child: Text(
                          'Mot de passe',
                          style: BkoTheme.fontPoppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: !_isOtpLoginMode ? BkoTheme.getTextPrimary(context) : BkoTheme.getTextMuted(context),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: BkoBounceable(
                    onTap: () => setState(() {
                      _isOtpLoginMode = true;
                      _localError = null;
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _isOtpLoginMode ? BkoTheme.getBgSurfaceElevated(context) : Colors.transparent,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              IconsaxPlusBold.magicpen,
                              size: 14,
                              color: _isOtpLoginMode ? BkoTheme.goldAccent : BkoTheme.getTextMuted(context),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'Code par email',
                              style: BkoTheme.fontPoppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: _isOtpLoginMode ? BkoTheme.goldAccent : BkoTheme.getTextMuted(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (!_isOtpLoginMode) ...[
            // Identifiant
            _buildInputLabel(
              label: 'Identifiant',
              subtitle: 'E-mail ou numéro',
            ),
            const SizedBox(height: 6),
            _buildTextField(
              controller: _loginIdentifier,
              hint: 'nom@exemple.com ou +00 000 000 000',
              icon: IconsaxPlusLinear.user,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [
                AutofillHints.username,
                AutofillHints.email,
                AutofillHints.telephoneNumber,
              ],
              textInputAction: TextInputAction.next,
            ),

            const SizedBox(height: 16),

            // Mot de passe
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    'Mot de passe',
                    style: BkoTheme.fontPoppins(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: BkoTheme.getTextPrimary(context),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Semantics(
                  button: true,
                  child: InkWell(
                    onTap: () => context.push('/forgot-password'),
                    child: Text(
                      'Mot de passe oublié ?',
                      style: BkoTheme.fontPoppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: BkoTheme.getAccent(context),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            _buildTextField(
              controller: _loginPassword,
              hint: '••••••••••••',
              icon: IconsaxPlusLinear.lock,
              obscureText: !_showLoginPassword,
              autofillHints: const [AutofillHints.password],
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _handleLogin(),
              suffixIcon: IconButton(
                icon: Icon(
                  _showLoginPassword ? IconsaxPlusLinear.eye_slash : IconsaxPlusLinear.eye,
                  color: BkoTheme.getTextMuted(context),
                  size: 20,
                ),
                onPressed: () {
                  setState(() => _showLoginPassword = !_showLoginPassword);
                },
              ),
            ),

            const SizedBox(height: 8),

            // Lien de récupération du mot de passe direct et accessible
            Align(
              alignment: Alignment.centerRight,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => context.push('/forgot-password'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(IconsaxPlusLinear.key, size: 14, color: BkoTheme.getAccent(context)),
                      const SizedBox(width: 5),
                      Text(
                        'Mot de passe oublié ?',
                        style: BkoTheme.fontPoppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: BkoTheme.getAccent(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Session Information Badge
            Row(
              children: [
                Icon(IconsaxPlusLinear.shield_tick, color: BkoTheme.getAccent(context), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Session chiffrée & sécurisée sur cet appareil',
                    style: BkoTheme.fontPoppins(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w400,
                      color: BkoTheme.getTextSecondary(context),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 22),

            // Submit Button
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _handleLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: BkoTheme.goldAccent,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  disabledBackgroundColor: BkoTheme.goldAccent.withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.black),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.arrow_forward_rounded, size: 18, color: Colors.black),
                          const SizedBox(width: 8),
                          Text(
                            'Se connecter',
                            style: BkoTheme.fontPoppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ] else ...[
            // MODE OTP LOGIN SANS MOT DE PASSE
            if (!_otpSent) ...[
              _buildInputLabel(
                label: 'Adresse e-mail',
                subtitle: 'Sans mot de passe',
              ),
              const SizedBox(height: 6),
              _buildTextField(
                controller: _loginIdentifier,
                hint: 'votre.email@exemple.com',
                icon: IconsaxPlusLinear.sms,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _handleRequestOtpLogin(),
              ),
              const SizedBox(height: 8),
              Text(
                'Un code sécurisé à 6 chiffres vous sera envoyé par e-mail pour vous connecter instantanément.',
                style: BkoTheme.fontPoppins(
                  fontSize: 11.5,
                  color: BkoTheme.getTextMuted(context),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 22),

              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _handleRequestOtpLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BkoTheme.goldAccent,
                    foregroundColor: Colors.black,
                    elevation: 0,
                    disabledBackgroundColor: BkoTheme.goldAccent.withValues(alpha: 0.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.black),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(IconsaxPlusBold.magicpen, size: 18, color: Colors.black),
                            const SizedBox(width: 8),
                            Text(
                              'Recevoir mon code par e-mail',
                              style: BkoTheme.fontPoppins(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ] else ...[
              // OTP Déjà expédié -> Saisie du code à 6 chiffres
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: BkoTheme.getSuccess(context).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: BkoTheme.getSuccess(context).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(IconsaxPlusBold.tick_circle, color: BkoTheme.getSuccess(context), size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Code envoyé à ${_loginIdentifier.text.trim()}',
                        style: BkoTheme.fontPoppins(fontSize: 12, color: BkoTheme.getSuccess(context), fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    InkWell(
                      onTap: () => setState(() {
                        _otpSent = false;
                        _otpCodeController.clear();
                        _localError = null;
                      }),
                      child: Text(
                        'Modifier',
                        style: BkoTheme.fontPoppins(fontSize: 11, color: BkoTheme.getAccent(context), fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              _buildInputLabel(
                label: 'Code de sécurité',
                subtitle: '6 chiffres',
              ),
              const SizedBox(height: 6),
              _buildTextField(
                controller: _otpCodeController,
                hint: '123456',
                icon: IconsaxPlusLinear.key,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _handleVerifyOtpLogin(),
              ),

              const SizedBox(height: 22),

              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _handleVerifyOtpLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BkoTheme.goldAccent,
                    foregroundColor: Colors.black,
                    elevation: 0,
                    disabledBackgroundColor: BkoTheme.goldAccent.withValues(alpha: 0.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.black),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.arrow_forward_rounded, size: 18, color: Colors.black),
                            const SizedBox(width: 8),
                            Text(
                              'Valider et me connecter',
                              style: BkoTheme.fontPoppins(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                ),
              ),

              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: _isSubmitting ? null : _handleRequestOtpLogin,
                  child: Text(
                    'Renvoyer un nouveau code',
                    style: BkoTheme.fontPoppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: BkoTheme.getAccent(context),
                    ),
                  ),
                ),
              ),
            ],
          ],

          const SizedBox(height: 16),

          // Divider "OU"
          Row(
            children: [
              Expanded(child: Divider(color: BkoTheme.getBorderSubtle(context), thickness: 1)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'OU',
                  style: BkoTheme.fontPoppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: BkoTheme.getTextMuted(context),
                  ),
                ),
              ),
              Expanded(child: Divider(color: BkoTheme.getBorderSubtle(context), thickness: 1)),
            ],
          ),

          const SizedBox(height: 16),

          // Bouton Google
          _buildGoogleButton(),
        ],
      ),
    );
  }

  Widget _buildRegisterForm() {
    final password = _registerPassword.text;
    final strength = _calculatePasswordStrength(password);

    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Nom complet
          _buildInputLabel(
            label: 'Nom complet ou pseudo',
            badge: 'Requis',
          ),
          const SizedBox(height: 6),
          _buildTextField(
            controller: _registerName,
            hint: 'ex. Awa Traoré',
            icon: IconsaxPlusLinear.user,
            keyboardType: TextInputType.name,
            textCapitalization: TextCapitalization.words,
            inputFormatters: const [
              CapitalizeWordsInputFormatter(),
            ],
            autofillHints: const [AutofillHints.name],
            textInputAction: TextInputAction.next,
          ),

          const SizedBox(height: 14),

          // Adresse e-mail
          _buildInputLabel(
            label: 'Adresse e-mail',
            badge: 'Requis',
          ),
          const SizedBox(height: 6),
          _buildTextField(
            controller: _registerEmail,
            hint: 'ex. nom@exemple.com',
            icon: IconsaxPlusLinear.sms,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            textInputAction: TextInputAction.next,
          ),

          const SizedBox(height: 14),

          // Numéro de téléphone (optionnel)
          _buildInputLabel(
            label: 'Numéro de téléphone',
            subtitle: 'Optionnel',
          ),
          const SizedBox(height: 6),
          _buildPhoneInputRow(),

          const SizedBox(height: 14),

          // Mot de passe
          _buildInputLabel(
            label: 'Mot de passe',
            badge: '8+ caractères',
          ),
          const SizedBox(height: 6),
          _buildTextField(
            controller: _registerPassword,
            hint: '8+ caractères, majuscule, chiffre',
            icon: IconsaxPlusLinear.lock,
            obscureText: !_showRegisterPassword,
            autofillHints: const [AutofillHints.newPassword],
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _handleRegister(),
            suffixIcon: IconButton(
              icon: Icon(
                _showRegisterPassword ? IconsaxPlusLinear.eye_slash : IconsaxPlusLinear.eye,
                color: BkoTheme.getTextMuted(context),
                size: 20,
              ),
              onPressed: () {
                setState(() => _showRegisterPassword = !_showRegisterPassword);
              },
            ),
          ),

          const SizedBox(height: 8),

          // Password strength bar
          Row(
            children: List.generate(4, (index) {
              final active = strength > index;
              return Expanded(
                child: Container(
                  height: 4,
                  margin: EdgeInsets.only(right: index < 3 ? 4 : 0),
                  decoration: BoxDecoration(
                    color: active ? BkoTheme.goldAccent : BkoTheme.getBorderSubtle(context),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 4),
          Text(
            'Minimum 8 caractères (entre 8 et 72 caractères sur le serveur)',
            style: BkoTheme.fontPoppins(
              fontSize: 10.5,
              fontWeight: FontWeight.w400,
              color: BkoTheme.getTextMuted(context),
            ),
          ),

          const SizedBox(height: 14),

          // Terms Checkbox
          Semantics(
            checked: _acceptTerms,
            label: 'Accepter les conditions d\'utilisation et la politique de confidentialité',
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () {
                setState(() { _acceptTerms = !_acceptTerms; _termsError = null; });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: _acceptTerms,
                        activeColor: BkoTheme.goldAccent,
                        checkColor: Colors.black,
                        side: BorderSide(color: BkoTheme.getTextMuted(context), width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        onChanged: (val) {
                          setState(() { _acceptTerms = val ?? false; _termsError = null; });
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          style: BkoTheme.fontPoppins(
                            fontSize: 12,
                            height: 1.4,
                            color: BkoTheme.getTextSecondary(context),
                          ),
                          children: [
                            const TextSpan(text: 'J\'accepte les '),
                            WidgetSpan(
                              alignment: PlaceholderAlignment.middle,
                              child: GestureDetector(
                                onTap: () => AuthLegalSheets.showTerms(context),
                                child: Text(
                                  'Conditions d\'utilisation',
                                  style: BkoTheme.fontPoppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: BkoTheme.getAccent(context),
                                    letterSpacing: 0,
                                  ),
                                ),
                              ),
                            ),
                            const TextSpan(text: ' et la '),
                            WidgetSpan(
                              alignment: PlaceholderAlignment.middle,
                              child: GestureDetector(
                                onTap: () => AuthLegalSheets.showPrivacy(context),
                                child: Text(
                                  'Politique de confidentialité',
                                  style: BkoTheme.fontPoppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: BkoTheme.getAccent(context),
                                  ),
                                ),
                              ),
                            ),
                            const TextSpan(text: ' de Bamako Podcast.'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Submit Button
          if (_termsError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10, left: 4),
              child: Semantics(
                liveRegion: true,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      IconsaxPlusLinear.info_circle,
                      size: 13,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        _termsError!,
                        style: BkoTheme.fontPoppins(
                          fontSize: 12,
                          height: 1.3,
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _handleRegister,
              style: ElevatedButton.styleFrom(
                backgroundColor: BkoTheme.goldAccent,
                foregroundColor: Colors.black,
                elevation: 0,
                disabledBackgroundColor: BkoTheme.goldAccent.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.black),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.person_add_rounded, size: 18, color: Colors.black),
                        const SizedBox(width: 8),
                        Text(
                          'Créer mon compte',
                          style: BkoTheme.fontPoppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
            ),
          ),

          const SizedBox(height: 8),
          Center(
            child: Text(
              'Gratuit et sans engagement',
              style: BkoTheme.fontPoppins(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: BkoTheme.getTextMuted(context),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Divider "OU"
          Row(
            children: [
              Expanded(child: Divider(color: BkoTheme.getBorderSubtle(context), thickness: 1)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'OU',
                  style: BkoTheme.fontPoppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: BkoTheme.getTextMuted(context),
                  ),
                ),
              ),
              Expanded(child: Divider(color: BkoTheme.getBorderSubtle(context), thickness: 1)),
            ],
          ),

          const SizedBox(height: 16),

          // Bouton Google
          _buildGoogleButton(),
        ],
      ),
    );
  }

  Widget _buildGoogleButton() {
    return SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: _isSubmitting ? null : _handleGoogleLogin,
        style: OutlinedButton.styleFrom(
          backgroundColor: BkoTheme.getBgSurface(context),
          foregroundColor: BkoTheme.getTextPrimary(context),
          side: BorderSide(color: BkoTheme.getBorderSubtle(context), width: 1.2),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // G Google Icon
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: BkoTheme.getTextPrimary(context),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text(
                  'G',
                  style: TextStyle(
                    color: Color(0xFF4285F4),
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Roboto',
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Continuer avec Google',
              style: BkoTheme.fontPoppins(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: BkoTheme.getTextPrimary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputLabel({
    required String label,
    String? badge,
    String? subtitle,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: BkoTheme.fontPoppins(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: BkoTheme.getTextPrimary(context),
          ),
        ),
        if (badge != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: BkoTheme.getBgSurface(context),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: BkoTheme.goldAccent.withValues(alpha: 0.3)),
            ),
            child: Text(
              badge,
              style: BkoTheme.fontPoppins(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: BkoTheme.getAccent(context),
              ),
            ),
          )
        else if (subtitle != null)
          Text(
            subtitle,
            style: BkoTheme.fontPoppins(
              fontSize: 10.5,
              fontWeight: FontWeight.w400,
              color: BkoTheme.getTextMuted(context),
            ),
          ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.none,
    List<TextInputFormatter>? inputFormatters,
    List<String>? autofillHints,
    TextInputAction textInputAction = TextInputAction.next,
    ValueChanged<String>? onChanged,
    ValueChanged<String>? onSubmitted,
    Widget? suffixIcon,
  }) {
    final error = _fieldErrors[controller];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: BkoTheme.getBgObsidian(context),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: error != null
                  ? Theme.of(context).colorScheme.error
                  : BkoTheme.getBorderSubtle(context),
            ),
          ),
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            textCapitalization: textCapitalization,
            inputFormatters: inputFormatters,
            autofillHints: autofillHints,
            textInputAction: textInputAction,
            onChanged: (value) {
              if (_fieldErrors.containsKey(controller)) {
                setState(() => _fieldErrors.remove(controller));
              }
              onChanged?.call(value);
            },
            onSubmitted: onSubmitted,
            style: BkoTheme.fontPoppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: BkoTheme.getTextPrimary(context),
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: BkoTheme.fontPoppins(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: BkoTheme.getTextMuted(context),
              ),
              prefixIcon: Icon(icon, color: BkoTheme.getTextMuted(context), size: 18),
              suffixIcon: suffixIcon,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: InputBorder.none,
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: BkoTheme.goldAccent, width: 1.2),
              ),
            ),
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 6),
            child: Semantics(
              liveRegion: true,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    IconsaxPlusLinear.info_circle,
                    size: 13,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      error,
                      style: BkoTheme.fontPoppins(
                        fontSize: 12,
                        height: 1.3,
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFreeListeningCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BkoTheme.getBgObsidian(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: BkoTheme.getBorderSubtle(context)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: BkoTheme.getBgSurface(context),
              shape: BoxShape.circle,
              border: Border.all(color: BkoTheme.goldAccent.withValues(alpha: 0.3)),
            ),
            child: Icon(
              Icons.headphones_rounded,
              color: BkoTheme.getAccent(context),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Écoute libre immédiate',
                  style: BkoTheme.fontPoppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: BkoTheme.getTextPrimary(context),
                  ),
                ),
                Text(
                  'Sans inscription requise',
                  style: BkoTheme.fontPoppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: BkoTheme.getTextMuted(context),
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _navigatePostLogin(),
            style: TextButton.styleFrom(
              backgroundColor: BkoTheme.getBgSurface(context),
              foregroundColor: BkoTheme.getTextPrimary(context),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: BkoTheme.getBorderSubtle(context)),
              ),
            ),
            child: Text(
              'Continuer →',
              style: BkoTheme.fontPoppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: BkoTheme.getTextPrimary(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegalFooter() {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _buildFooterLink('Centre d\'aide', () => AuthLegalSheets.showHelp(context)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text('•', style: TextStyle(color: BkoTheme.getTextMuted(context), fontSize: 12)),
        ),
        _buildFooterLink('Conditions', () => AuthLegalSheets.showTerms(context)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text('•', style: TextStyle(color: BkoTheme.getTextMuted(context), fontSize: 12)),
        ),
        _buildFooterLink('Confidentialité', () => AuthLegalSheets.showPrivacy(context)),
      ],
    );
  }

  Widget _buildFooterLink(String label, VoidCallback onTap) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Text(
            label,
            style: BkoTheme.fontPoppins(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: BkoTheme.getTextMuted(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAlreadyAuthenticated(BuildContext context, Map<String, dynamic> user) {
    final name = (user['fullName'] as String?)?.trim();
    final email = (user['email'] as String?)?.trim() ?? '';
    final displayName = (name != null && name.isNotEmpty) ? name : email;

    return Scaffold(
      backgroundColor: BkoTheme.getBgObsidian(context),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: BkoTheme.getBgSurface(context),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: BkoTheme.getBorderSubtle(context)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: BkoTheme.getBgSurface(context),
                        shape: BoxShape.circle,
                        border: Border.all(color: BkoTheme.goldAccent.withValues(alpha: 0.4)),
                      ),
                      child: Icon(
                        Icons.verified_user_rounded,
                        color: BkoTheme.getAccent(context),
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Vous êtes déjà connecté',
                      textAlign: TextAlign.center,
                      style: BkoTheme.fontPoppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: BkoTheme.getTextPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Session active pour $displayName',
                      textAlign: TextAlign.center,
                      style: BkoTheme.fontPoppins(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w400,
                        color: BkoTheme.getTextSecondary(context),
                      ),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _navigatePostLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: BkoTheme.goldAccent,
                          foregroundColor: Colors.black,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text(
                          'Accéder à mon espace',
                          style: BkoTheme.fontPoppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton(
                        onPressed: () async {
                          await ref.read(authProvider.notifier).logout();
                        },
                        style: OutlinedButton.styleFrom(
                          backgroundColor: BkoTheme.getBgSurface(context),
                          foregroundColor: BkoTheme.getTextSecondary(context),
                          side: BorderSide(color: BkoTheme.getBorderSubtle(context)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text(
                          'Changer de compte',
                          style: BkoTheme.fontPoppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: BkoTheme.getTextSecondary(context),
                          ),
                        ),
                      ),
                    ),
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
