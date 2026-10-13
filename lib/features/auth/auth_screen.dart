import 'dart:math' as math;
import 'package:country_picker/country_picker.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/bko_theme.dart';
import 'auth_controller.dart';
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
          hintStyle: BkoTheme.fontPoppins(fontSize: 13, color: const Color(0xFF757575)),
          prefixIcon: const Icon(IconsaxPlusLinear.search_normal_1, color: Color(0xFF757575), size: 18),
          filled: true,
          fillColor: const Color(0xFF0E0E0E),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sélecteur de pays compact (Drapeau + Indicatif + flèche)
            InkWell(
              onTap: _isSubmitting ? null : _selectPhoneCountry,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0E0E0E),
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
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      IconsaxPlusLinear.arrow_down_1,
                      size: 14,
                      color: Color(0xFF757575),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Champ de saisie du numéro national
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0E0E0E),
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
                    color: Colors.white,
                  ),
                  decoration: InputDecoration(
                    hintText: _getPhoneHintForCountry(_phoneCountry.countryCode),
                    hintStyle: BkoTheme.fontPoppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF555555),
                    ),
                    prefixIcon: const Icon(
                      IconsaxPlusLinear.call,
                      color: Color(0xFF757575),
                      size: 18,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    border: InputBorder.none,
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: BkoTheme.goldAccent, width: 1.2),
                    ),
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
    _registerName.dispose();
    _registerEmail.dispose();
    _registerPhone.dispose();
    _registerPassword.dispose();
    super.dispose();
  }

  String? _sanitizeRedirect(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final decoded = Uri.decodeComponent(raw).trim();
    if (decoded.contains('://') || decoded.startsWith('//') || decoded.contains('\\')) {
      return null;
    }
    if (!decoded.startsWith('/')) return null;
    if (decoded.startsWith('/login') || decoded.startsWith('/register')) return null;
    return decoded;
  }

  void _navigatePostLogin() {
    final clean = _sanitizeRedirect(widget.redirect);
    if (clean != null && clean != '/') {
      context.go(clean);
    } else {
      context.go('/');
    }
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
      _navigatePostLogin();
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

  Future<void> _handleRegister() async {
    FocusScope.of(context).unfocus();
    setState(() { _localError = null; _fieldErrors.clear(); _termsError = null; });

    final fullName = _registerName.text.trim();
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
          _fieldErrors[_registerPhone] = 'Numéro invalide pour ${_phoneCountry.name}.';
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
      final cleanRedirect = _sanitizeRedirect(widget.redirect);
      final queryRedirect = cleanRedirect != null ? '&redirect=${Uri.encodeQueryComponent(cleanRedirect)}' : '';
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
        backgroundColor: const Color(0xFF0B0B0B),
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
                              color: const Color(0xFF121212),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: const Color(0xFF262626)),
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
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Color(0xFFB8B8B8),
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
                  color: const Color(0xFF121212),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF262626)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: Image.asset(
                    'assets/brand/app_icon.png',
                    width: 32,
                    height: 32,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.mic_rounded,
                      color: BkoTheme.goldAccent,
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
                  color: Colors.white,
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
        color: const Color(0xFF181818),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF262626)),
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
                  color: isActive ? Colors.black : const Color(0xFFB8B8B8),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: BkoTheme.fontPoppins(
                    fontSize: 13,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    color: isActive ? Colors.black : const Color(0xFFB8B8B8),
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
        color: const Color(0xFF3B1214),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF7F1D1D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.error_outline_rounded, color: Color(0xFFF87171), size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: BkoTheme.fontPoppins(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                    color: const Color(0xFFFECACA),
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
                    color: BkoTheme.goldAccent,
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
                    color: Colors.white,
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
                      color: BkoTheme.goldAccent,
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
                color: const Color(0xFF757575),
                size: 20,
              ),
              onPressed: () {
                setState(() => _showLoginPassword = !_showLoginPassword);
              },
            ),
          ),

          const SizedBox(height: 14),

          // Session Information Badge
          Row(
            children: [
              const Icon(IconsaxPlusLinear.shield_tick, color: BkoTheme.goldAccent, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Session chiffrée & sécurisée sur cet appareil',
                  style: BkoTheme.fontPoppins(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFFB8B8B8),
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
                color: const Color(0xFF757575),
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
                    color: active ? BkoTheme.goldAccent : const Color(0xFF262626),
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
              color: const Color(0xFF757575),
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
                        side: const BorderSide(color: Color(0xFF757575), width: 1.5),
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
                            color: const Color(0xFFB8B8B8),
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
                                    color: BkoTheme.goldAccent,
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
                                    color: BkoTheme.goldAccent,
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
                color: const Color(0xFF757575),
              ),
            ),
          ),
        ],
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
            color: Colors.white,
          ),
        ),
        if (badge != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1A11),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: BkoTheme.goldAccent.withValues(alpha: 0.3)),
            ),
            child: Text(
              badge,
              style: BkoTheme.fontPoppins(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: BkoTheme.goldAccent,
              ),
            ),
          )
        else if (subtitle != null)
          Text(
            subtitle,
            style: BkoTheme.fontPoppins(
              fontSize: 10.5,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF757575),
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
            color: const Color(0xFF0E0E0E),
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
              color: Colors.white,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: BkoTheme.fontPoppins(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: const Color(0xFF555555),
              ),
              prefixIcon: Icon(icon, color: const Color(0xFF757575), size: 18),
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
        color: const Color(0xFF0E0E0E),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF262626)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF1E1A11),
              shape: BoxShape.circle,
              border: Border.all(color: BkoTheme.goldAccent.withValues(alpha: 0.3)),
            ),
            child: const Icon(
              Icons.headphones_rounded,
              color: BkoTheme.goldAccent,
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
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Sans inscription requise',
                  style: BkoTheme.fontPoppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF757575),
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              final clean = _sanitizeRedirect(widget.redirect);
              if (clean != null && clean != '/') {
                context.go(clean);
              } else {
                context.go('/');
              }
            },
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFF1A1A1A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xFF2E2E2E)),
              ),
            ),
            child: Text(
              'Continuer →',
              style: BkoTheme.fontPoppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
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
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text('•', style: TextStyle(color: Color(0xFF555555), fontSize: 12)),
        ),
        _buildFooterLink('Conditions', () => AuthLegalSheets.showTerms(context)),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text('•', style: TextStyle(color: Color(0xFF555555), fontSize: 12)),
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
              color: const Color(0xFF888888),
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
      backgroundColor: const Color(0xFF0B0B0B),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: const Color(0xFF121212),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFF262626)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1A11),
                        shape: BoxShape.circle,
                        border: Border.all(color: BkoTheme.goldAccent.withValues(alpha: 0.4)),
                      ),
                      child: const Icon(
                        Icons.verified_user_rounded,
                        color: BkoTheme.goldAccent,
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
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Session active pour $displayName',
                      textAlign: TextAlign.center,
                      style: BkoTheme.fontPoppins(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w400,
                        color: const Color(0xFFB8B8B8),
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
                          backgroundColor: const Color(0xFF1A1A1A),
                          foregroundColor: const Color(0xFFB8B8B8),
                          side: const BorderSide(color: Color(0xFF262626)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text(
                          'Changer de compte',
                          style: BkoTheme.fontPoppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFB8B8B8),
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
