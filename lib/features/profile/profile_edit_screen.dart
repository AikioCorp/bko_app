import 'package:cached_network_image/cached_network_image.dart';
import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/network/bko_api.dart';
import '../../core/services/media_upload_service.dart';
import '../../core/theme/bko_theme.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/widgets/bko_bounceable.dart';
import '../../core/widgets/bko_haptics.dart';
import '../../core/widgets/capitalize_words_input_formatter.dart';
import '../../core/widgets/phone_number_formatter.dart';
import '../auth/auth_controller.dart';

/// Écran moderne et épuré de modification du profil utilisateur.
/// Conçu selon les règles mobile-designer et les directives strictes de style :
/// Iconsax uniquement, pays + numéro sur la même ligne (Mali par défaut),
/// upload photo haute fiabilité, zéro dégradé, zéro ombre.
class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _bioController;

  Country _phoneCountry = Country.parse('ML');
  String? _avatarUrl;
  bool _isLoading = false;
  bool _isUploadingAvatar = false;
  String? _phoneError;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    _nameController = TextEditingController(text: user?['fullName'] ?? '');
    _emailController = TextEditingController(text: user?['email'] ?? '');
    _avatarUrl = user?['avatar'] as String?;

    // Initialisation du numéro et pays
    final rawPhone = (user?['phoneNumber'] ?? '') as String;
    String initialDigits = '';
    if (rawPhone.isNotEmpty) {
      if (rawPhone.startsWith('+223')) {
        _phoneCountry = Country.parse('ML');
        initialDigits = rawPhone.substring(4);
      } else if (rawPhone.startsWith('+233')) {
        _phoneCountry = Country.parse('GH');
        initialDigits = rawPhone.substring(4);
      } else if (rawPhone.startsWith('+225')) {
        _phoneCountry = Country.parse('CI');
        initialDigits = rawPhone.substring(4);
      } else if (rawPhone.startsWith('+221')) {
        _phoneCountry = Country.parse('SN');
        initialDigits = rawPhone.substring(4);
      } else if (rawPhone.startsWith('+33')) {
        _phoneCountry = Country.parse('FR');
        initialDigits = rawPhone.substring(3);
      } else {
        initialDigits = rawPhone.replaceAll(RegExp(r'\D'), '');
      }
    }
    _phoneController = TextEditingController(
      text: PhoneNumberTextInputFormatter.formatNumber(
        initialDigits,
        _phoneCountry.countryCode,
      ),
    );

    final creatorProfile = user?['creatorProfile'];
    final bioText = creatorProfile is Map ? (creatorProfile['bio'] ?? '') : '';
    _bioController = TextEditingController(text: bioText as String);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  String _getInitial() {
    final name = _nameController.text.trim();
    if (name.isNotEmpty) return name[0].toUpperCase();
    final user = ref.read(authProvider).user;
    final fullName = user?['fullName'] as String? ?? 'A';
    return fullName.isNotEmpty ? fullName[0].toUpperCase() : 'A';
  }

  void _selectPhoneCountry() {
    FocusScope.of(context).unfocus();
    BkoHaptics.light();
    showCountryPicker(
      context: context,
      showPhoneCode: true,
      searchAutofocus: false,
      favorite: const ['ML', 'CI', 'SN', 'BF', 'GN', 'NE', 'FR', 'GH'],
      countryListTheme: CountryListThemeData(
        backgroundColor: BkoTheme.getBgSurface(context),
        textStyle: BkoTheme.fontLato(fontSize: 14, color: BkoTheme.getTextPrimary(context)),
        searchTextStyle: BkoTheme.fontLato(fontSize: 14, color: BkoTheme.getTextPrimary(context)),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        bottomSheetHeight: MediaQuery.sizeOf(context).height * 0.72,
        inputDecoration: InputDecoration(
          hintText: 'Rechercher un pays ou un indicatif...',
          hintStyle: BkoTheme.fontLato(fontSize: 13, color: BkoTheme.getTextSecondary(context)),
          prefixIcon: Icon(IconsaxPlusLinear.search_normal_1, color: BkoTheme.getTextSecondary(context), size: 18),
          filled: true,
          fillColor: BkoTheme.getBgSurfaceElevated(context),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: BkoTheme.getBorderSubtle(context)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: BkoTheme.getBorderSubtle(context)),
          ),
          focusedBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(color: BkoTheme.goldAccent, width: 1.2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
      onSelect: (country) => setState(() {
        _phoneCountry = country;
        _phoneError = null;
        if (_phoneController.text.isNotEmpty) {
          final rawDigits = _phoneController.text.replaceAll(RegExp(r'\D'), '');
          _phoneController.text = PhoneNumberTextInputFormatter.formatNumber(
            rawDigits,
            _phoneCountry.countryCode,
          );
        }
      }),
    );
  }

  Future<void> _pickAndUploadAvatar(ImageSource source) async {
    final token = ref.read(authProvider).token;
    if (token == null) return;

    final picked = await MediaUploadService.pickImage(source: source);
    if (picked == null) return;

    setState(() => _isUploadingAvatar = true);

    try {
      final bytes = await picked.readAsBytes();
      final ext = picked.name.split('.').last.toLowerCase();
      final mimeType = ext == 'png'
          ? 'image/png'
          : ext == 'webp'
              ? 'image/webp'
              : ext == 'gif'
                  ? 'image/gif'
                  : 'image/jpeg';

      final publicUrl = await MediaUploadService.uploadImage(
        bytes: bytes,
        mimeType: mimeType,
        folder: 'avatars',
        token: token,
      );

      final res = await BkoApi.patch(
        '/me',
        {'avatar': publicUrl},
        token: token,
      );

      final userMap = res is Map && res['data'] is Map
          ? Map<String, dynamic>.from(res['data'] as Map)
          : (res is Map ? Map<String, dynamic>.from(res) : {'avatar': publicUrl});

      await ref.read(authProvider.notifier).updateUser(userMap);

      if (mounted) {
        setState(() {
          _avatarUrl = publicUrl;
          _isUploadingAvatar = false;
        });

        BkoHaptics.success();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo de profil mise à jour avec succès !'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: BkoTheme.goldAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingAvatar = false);
        BkoHaptics.error();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du téléversement : $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _removeAvatar() async {
    final token = ref.read(authProvider).token;
    if (token == null) return;

    setState(() => _isUploadingAvatar = true);

    try {
      final res = await BkoApi.patch(
        '/me',
        {'avatar': ''},
        token: token,
      );

      final userMap = res is Map && res['data'] is Map
          ? Map<String, dynamic>.from(res['data'] as Map)
          : (res is Map ? Map<String, dynamic>.from(res) : {'avatar': null});

      await ref.read(authProvider.notifier).updateUser(userMap);

      if (mounted) {
        setState(() {
          _avatarUrl = null;
          _isUploadingAvatar = false;
        });

        BkoHaptics.light();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo de profil supprimée.'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: BkoTheme.goldAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingAvatar = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la suppression : $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _showAvatarPickerModal() {
    BkoHaptics.light();
    final surface = BkoTheme.getBgSurface(context);
    final surfaceElevated = BkoTheme.getBgSurfaceElevated(context);
    final textPri = BkoTheme.getTextPrimary(context);
    final border = BkoTheme.getBorderSubtle(context);

    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      backgroundColor: surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                'Photo de profil',
                style: BkoTheme.fontLato(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: textPri,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    IconsaxPlusLinear.camera,
                    color: BkoTheme.goldAccent,
                    size: 20,
                  ),
                ),
                title: Text(
                  'Prendre une photo',
                  style: BkoTheme.fontLato(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: textPri,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUploadAvatar(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    IconsaxPlusLinear.gallery,
                    color: BkoTheme.goldAccent,
                    size: 20,
                  ),
                ),
                title: Text(
                  'Choisir dans la galerie',
                  style: BkoTheme.fontLato(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: textPri,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUploadAvatar(ImageSource.gallery);
                },
              ),
              if (_avatarUrl != null && _avatarUrl!.trim().isNotEmpty) ...[
                ListTile(
                  leading: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      IconsaxPlusLinear.trash,
                      color: Theme.of(context).colorScheme.error,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    'Supprimer la photo actuelle',
                    style: BkoTheme.fontLato(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _removeAvatar();
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final token = ref.read(authProvider).token;
    if (token == null) return;

    final phone = _phoneController.text.trim();
    String? normalizedPhone;
    if (phone.isNotEmpty) {
      final rawDigits = phone.replaceAll(RegExp(r'\D'), '');
      final cc = _phoneCountry.countryCode.toUpperCase();
      if (cc == 'ML') {
        if (rawDigits.length != 8) {
          setState(() {
            _phoneError = 'Le numéro malien doit comporter 8 chiffres (ex. 70 00 00 90).';
          });
          return;
        }
        normalizedPhone = '+223$rawDigits';
      } else if (cc == 'GH') {
        if (rawDigits.length < 9 || rawDigits.length > 10) {
          setState(() {
            _phoneError = 'Numéro invalide pour le Ghana (ex. 050 706 6762).';
          });
          return;
        }
        final nsn = rawDigits.startsWith('0') ? rawDigits.substring(1) : rawDigits;
        normalizedPhone = '+233$nsn';
      } else {
        normalizedPhone = '+${_phoneCountry.phoneCode}$rawDigits';
      }
    }

    setState(() {
      _phoneError = null;
      _isLoading = true;
    });

    try {
      final payload = <String, dynamic>{
        'fullName': _nameController.text.trim(),
        if (normalizedPhone != null) 'phoneNumber': normalizedPhone,
        if (_bioController.text.trim().isNotEmpty) 'bio': _bioController.text.trim(),
      };

      final res = await BkoApi.patch(
        '/me',
        payload,
        token: token,
      );

      if (mounted) {
        final userMap = res is Map && res['data'] is Map
            ? Map<String, dynamic>.from(res['data'] as Map)
            : (res is Map ? Map<String, dynamic>.from(res) : payload);

        await ref.read(authProvider.notifier).updateUser(userMap);

        if (!mounted) return;

        BkoHaptics.success();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profil mis à jour avec succès.'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: BkoTheme.goldAccent,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        BkoHaptics.error();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la mise à jour : $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textPri = BkoTheme.getTextPrimary(context);
    final textSec = BkoTheme.getTextSecondary(context);
    final surface = BkoTheme.getBgSurface(context);
    final surfaceElevated = BkoTheme.getBgSurfaceElevated(context);
    final border = BkoTheme.getBorderSubtle(context);

    final hasAvatar = _avatarUrl != null && _avatarUrl!.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Modifier mon profil',
          style: BkoTheme.fontLato(fontSize: 17, fontWeight: FontWeight.w800, color: textPri),
        ),
        backgroundColor: BkoTheme.getBgObsidian(context),
        elevation: 0,
        leading: const AppBackButton(),
      ),
      backgroundColor: BkoTheme.getBgObsidian(context),
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Avatar Center Picker
                Center(
                  child: Column(
                    children: [
                      BkoBounceable(
                        onTap: _isUploadingAvatar ? null : _showAvatarPickerModal,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 96,
                              height: 96,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: surfaceElevated,
                                border: Border.all(color: border, width: 2),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: hasAvatar
                                  ? CachedNetworkImage(
                                      imageUrl: _avatarUrl!,
                                      memCacheWidth: 200,
                                      fit: BoxFit.cover,
                                      placeholder: (_, __) => Center(
                                        child: Text(
                                          _getInitial(),
                                          style: BkoTheme.fontLato(
                                            fontSize: 32,
                                            fontWeight: FontWeight.w800,
                                            color: BkoTheme.goldAccent,
                                          ),
                                        ),
                                      ),
                                      errorWidget: (_, __, ___) => Center(
                                        child: Text(
                                          _getInitial(),
                                          style: BkoTheme.fontLato(
                                            fontSize: 32,
                                            fontWeight: FontWeight.w800,
                                            color: BkoTheme.goldAccent,
                                          ),
                                        ),
                                      ),
                                    )
                                  : Center(
                                      child: Text(
                                        _getInitial(),
                                        style: BkoTheme.fontLato(
                                          fontSize: 32,
                                          fontWeight: FontWeight.w800,
                                          color: BkoTheme.goldAccent,
                                        ),
                                      ),
                                    ),
                            ),
                            if (_isUploadingAvatar)
                              Container(
                                width: 96,
                                height: 96,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: BkoTheme.darkBgObsidian.withValues(alpha: 0.75),
                                ),
                                child: const Center(
                                  child: SizedBox(
                                    width: 26,
                                    height: 26,
                                    child: CircularProgressIndicator.adaptive(
                                      valueColor: AlwaysStoppedAnimation(BkoTheme.goldAccent),
                                      strokeWidth: 2.5,
                                    ),
                                  ),
                                ),
                              ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: BkoTheme.goldAccent,
                                ),
                                child: const Icon(
                                  IconsaxPlusLinear.camera,
                                  size: 16,
                                  color: BkoTheme.darkBgObsidian,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      BkoBounceable(
                        onTap: _isUploadingAvatar ? null : _showAvatarPickerModal,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          child: Text(
                            _isUploadingAvatar
                                ? 'Téléversement en cours...'
                                : 'Changer la photo de profil',
                            style: BkoTheme.fontLato(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: BkoTheme.goldAccent,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // Section: Informations personnelles
                _buildFieldLabel('Nom complet *', textSec),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _nameController,
                  style: BkoTheme.fontLato(fontSize: 14.5, color: textPri),
                  keyboardType: TextInputType.name,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.name],
                  textCapitalization: TextCapitalization.words,
                  inputFormatters: const [CapitalizeWordsInputFormatter()],
                  onTapOutside: (_) => FocusScope.of(context).unfocus(),
                  decoration: _buildInputDecoration(
                    hint: 'Votre prénom et nom',
                    prefixIcon: IconsaxPlusLinear.user,
                    surface: surface,
                    border: border,
                    context: context,
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Le nom complet est requis.';
                    return null;
                  },
                ),
                const SizedBox(height: 18),

                // Section: Adresse e-mail (Lecture seule)
                _buildFieldLabel('Adresse e-mail', textSec, badge: 'Non modifiable'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _emailController,
                  readOnly: true,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  style: BkoTheme.fontLato(fontSize: 14.5, color: textSec),
                  decoration: _buildInputDecoration(
                    hint: 'votre.email@exemple.com',
                    prefixIcon: IconsaxPlusLinear.sms,
                    suffixIcon: Icon(IconsaxPlusLinear.lock, size: 16, color: textSec),
                    surface: surfaceElevated,
                    border: border,
                    context: context,
                  ),
                ),
                const SizedBox(height: 18),

                // Section: Pays et Numéro de téléphone sur la même ligne (Mali par défaut)
                _buildFieldLabel('Numéro de téléphone', textSec, badge: 'Optionnel'),
                const SizedBox(height: 6),
                _buildPhoneRow(surface, border, textPri, textSec),
                if (_phoneError != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    _phoneError!,
                    style: BkoTheme.fontLato(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 18),

                // Section: Bio / Présentation
                _buildFieldLabel('Présentation / Bio', textSec, badge: 'Optionnel'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _bioController,
                  maxLines: 3,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.done,
                  style: BkoTheme.fontLato(fontSize: 14, color: textPri),
                  onTapOutside: (_) => FocusScope.of(context).unfocus(),
                  decoration: InputDecoration(
                    hintText: 'Quelques mots sur vous, vos centres d\'intérêt ou vos émissions...',
                    hintStyle: BkoTheme.fontLato(fontSize: 13, color: textSec),
                    filled: true,
                    fillColor: surface,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: border),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(14)),
                      borderSide: BorderSide(color: BkoTheme.goldAccent, width: 1.2),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Submit Button
                BkoBounceable(
                  onTap: _isLoading
                      ? null
                      : () {
                          BkoHaptics.light();
                          _save();
                        },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _isLoading
                          ? BkoTheme.goldAccent.withValues(alpha: 0.5)
                          : BkoTheme.goldAccent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator.adaptive(
                              valueColor: AlwaysStoppedAnimation(BkoTheme.darkBgObsidian),
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            'ENREGISTRER LES MODIFICATIONS',
                            style: BkoTheme.fontLato(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                              color: BkoTheme.darkBgObsidian,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label, Color color, {String? badge}) {
    return Row(
      children: [
        Text(
          label,
          style: BkoTheme.fontLato(fontSize: 13, fontWeight: FontWeight.w700, color: color),
        ),
        if (badge != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: BkoTheme.getBgSurfaceElevated(context),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              badge,
              style: BkoTheme.fontLato(fontSize: 10.5, fontWeight: FontWeight.w600, color: color),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPhoneRow(Color surface, Color border, Color textPri, Color textSec) {
    final hasError = _phoneError != null;
    final borderColor = hasError ? Theme.of(context).colorScheme.error : border;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Sélecteur de pays compact (Drapeau + Indicatif + Flèche)
        BkoBounceable(
          onTap: _selectPhoneCountry,
          child: Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor),
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
                  style: BkoTheme.fontLato(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: textPri,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  IconsaxPlusLinear.arrow_down_1,
                  size: 14,
                  color: textSec,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),

        // Champ de saisie du numéro sur la même ligne avec auto-formatage
        Expanded(
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor),
            ),
            child: TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.telephoneNumber],
              inputFormatters: [
                PhoneNumberTextInputFormatter(_phoneCountry.countryCode),
              ],
              onChanged: (_) {
                if (_phoneError != null) setState(() => _phoneError = null);
              },
              style: BkoTheme.fontLato(fontSize: 14, fontWeight: FontWeight.w600, color: textPri),
              decoration: InputDecoration(
                hintText: PhoneNumberTextInputFormatter.getPhoneHint(_phoneCountry.countryCode),
                hintStyle: BkoTheme.fontLato(fontSize: 13, color: textSec),
                prefixIcon: Icon(IconsaxPlusLinear.call, color: textSec, size: 18),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                border: InputBorder.none,
              ),
            ),
          ),
        ),
      ],
    );
  }

  InputDecoration _buildInputDecoration({
    required String hint,
    required IconData prefixIcon,
    Widget? suffixIcon,
    required Color surface,
    required Color border,
    required BuildContext context,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: BkoTheme.fontLato(fontSize: 13, color: BkoTheme.getTextSecondary(context)),
      prefixIcon: Icon(prefixIcon, color: BkoTheme.getTextSecondary(context), size: 18),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: border),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide(color: BkoTheme.goldAccent, width: 1.2),
      ),
    );
  }
}
