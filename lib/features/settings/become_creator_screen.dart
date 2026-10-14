import '../../core/widgets/app_header_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../../core/network/bko_api.dart';
import '../../core/theme/bko_theme.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/widgets/bko_bounceable.dart';
import '../../core/widgets/bko_haptics.dart';
import '../auth/auth_controller.dart';
import '../studio/studio_access_gate.dart';

/// Écran « Devenir créateur » pour les auditeurs souhaitant lancer leur émission.
/// - Présentation des fonctionnalités du studio (publication d'épisodes, monétisation, statistiques)
/// - Formulaire réel de création de profil créateur (POST /me/creator-profile)
/// - Attribution automatique du rôle CREATOR
/// - Redirection immédiate vers le Studio une fois créé
class BecomeCreatorScreen extends ConsumerStatefulWidget {
  const BecomeCreatorScreen({super.key});

  @override
  ConsumerState<BecomeCreatorScreen> createState() =>
      _BecomeCreatorScreenState();
}

class _BecomeCreatorScreenState extends ConsumerState<BecomeCreatorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _websiteController = TextEditingController();

  bool _isSubmitting = false;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    _nameController.text = (user?['fullName'] as String?) ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _websiteController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    final token = ref.read(authProvider).token;
    if (token == null) {
      context.push('/login?redirect=%2Fbecome-creator');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });
    try {
      await BkoApi.post(
        '/me/creator-profile',
        {
          'displayName': _nameController.text.trim(),
          'bio': _bioController.text.trim(),
          'website': _websiteController.text.trim().isEmpty
              ? null
              : _websiteController.text.trim(),
          'createPerson': true,
        },
        token: token,
      );

      // Rafraîchir les informations et rôles de l'utilisateur
      final me = await BkoApi.get('/me', token: token);
      if (me is! Map) throw const FormatException('Compte non synchronisé');
      await ref
          .read(authProvider.notifier)
          .updateUser(Map<String, dynamic>.from(me));
      ref.invalidate(studioAccessProvider);

      if (mounted) {
        setState(() => _isSubmitting = false);
        BkoHaptics.success();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Votre Studio est activé. Préparez votre première émission.'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: BkoTheme.goldAccent,
          ),
        );

        // Navigation vers le Studio
        context.go('/studio');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        BkoHaptics.error();
        setState(() => _submitError = e is ApiException
            ? e.message
            : 'Impossible de synchroniser votre Studio. Réessayez.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final alreadyCreator = user?['creatorProfile'] != null;

    if (alreadyCreator) {
      return Scaffold(
        backgroundColor: BkoTheme.getBgObsidian(context),
        appBar: AppBar(
        actions: const [AppHeaderActions()],
          leading: const AppBackButton(),
          title: Text(
            'Espace Créateur',
            style: BkoTheme.fontLato(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: BkoTheme.getTextPrimary(context),
            ),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: BkoTheme.goldAccent.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      IconsaxPlusLinear.crown_1,
                      color: BkoTheme.goldAccent,
                      size: 34,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Vous êtes déjà créateur !',
                  style: BkoTheme.fontLato(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: BkoTheme.getTextPrimary(context),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Accédez dès maintenant à votre espace Studio pour gérer vos podcasts, importer des épisodes et suivre votre audience.',
                  textAlign: TextAlign.center,
                  style: BkoTheme.fontLato(
                    fontSize: 13,
                    color: BkoTheme.getTextSecondary(context),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                BkoBounceable(
                  onTap: () {
                    BkoHaptics.light();
                    context.go('/studio');
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 12),
                    decoration: BoxDecoration(
                      color: BkoTheme.goldAccent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Ouvrir mon Studio',
                      style: BkoTheme.fontLato(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
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

    return Scaffold(
      backgroundColor: BkoTheme.getBgObsidian(context),
      appBar: AppBar(
        actions: const [AppHeaderActions()],
        leading: const AppBackButton(),
        title: Text(
          'Devenir créateur',
          style: BkoTheme.fontLato(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: BkoTheme.getTextPrimary(context),
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // Bannière avantages
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: BkoTheme.getBgSurface(context),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: BkoTheme.getBorderSubtle(context)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: BkoTheme.goldAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Icon(
                          IconsaxPlusLinear.microphone_2,
                          color: BkoTheme.goldAccent,
                          size: 24,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Faites entendre vos histoires',
                            style: BkoTheme.fontLato(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: BkoTheme.getTextPrimary(context),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Un Studio gratuit pour commencer',
                            style: BkoTheme.fontLato(
                              fontSize: 11.5,
                              color: BkoTheme.getTextSecondary(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _buildBenefitRow(
                  context,
                  IconsaxPlusLinear.cloud_add,
                  'Préparez vos émissions audio et vidéo',
                ),
                const SizedBox(height: 10),
                _buildBenefitRow(
                  context,
                  IconsaxPlusLinear.chart_2,
                  'Statistiques d\'écoutes détaillées par pays et langues',
                ),
                const SizedBox(height: 10),
                _buildBenefitRow(
                  context,
                  IconsaxPlusLinear.wallet_money,
                  'Publication selon les droits disponibles pour votre compte',
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Formulaire d'inscription créateur
          Text(
            'VOTRE PROFIL CRÉATEUR',
            style: BkoTheme.fontLato(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
              color: BkoTheme.getTextMuted(context),
            ),
          ),
          const SizedBox(height: 10),

          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: BkoTheme.getBgSurface(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: BkoTheme.getBorderSubtle(context)),
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nom public du créateur *',
                    style: BkoTheme.fontLato(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: BkoTheme.getTextSecondary(context),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _nameController,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty || v.trim().length > 100)
                            ? 'Indiquez un nom public (100 caractères maximum)'
                            : null,
                    style: BkoTheme.fontLato(
                      fontSize: 13.5,
                      color: BkoTheme.getTextPrimary(context),
                    ),
                    decoration: InputDecoration(
                      hintText: 'Ex: Studio Bamako, Fatou Diarra...',
                      filled: true,
                      fillColor: BkoTheme.getBgSurfaceElevated(context),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                            color: BkoTheme.getBorderSubtle(context)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Présentation (facultative)',
                    style: BkoTheme.fontLato(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: BkoTheme.getTextSecondary(context),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _bioController,
                    maxLines: 3,
                    validator: (v) => (v != null && v.trim().length > 2000)
                        ? 'Présentation trop longue (2 000 caractères maximum)'
                        : null,
                    style: BkoTheme.fontLato(
                      fontSize: 13.5,
                      color: BkoTheme.getTextPrimary(context),
                    ),
                    decoration: InputDecoration(
                      hintText:
                          'De quoi parlent vos émissions ? Quel est votre public ?',
                      filled: true,
                      fillColor: BkoTheme.getBgSurfaceElevated(context),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                            color: BkoTheme.getBorderSubtle(context)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Site web ou réseau social (facultatif)',
                    style: BkoTheme.fontLato(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: BkoTheme.getTextSecondary(context),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _websiteController,
                    keyboardType: TextInputType.url,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return null;
                      final url = Uri.tryParse(value.trim());
                      return url != null &&
                              url.host.isNotEmpty &&
                              ['http', 'https'].contains(url.scheme)
                          ? null
                          : 'Indiquez un lien complet https://…';
                    },
                    style: BkoTheme.fontLato(
                      fontSize: 13.5,
                      color: BkoTheme.getTextPrimary(context),
                    ),
                    decoration: InputDecoration(
                      hintText: 'https://...',
                      filled: true,
                      fillColor: BkoTheme.getBgSurfaceElevated(context),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                            color: BkoTheme.getBorderSubtle(context)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_submitError != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(_submitError!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error)),
                    ),
                  BkoBounceable(
                    onTap: _isSubmitting ? null : _handleSubmit,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: BkoTheme.goldAccent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor:
                                      AlwaysStoppedAnimation(Colors.black),
                                ),
                              )
                            : Text(
                                'Activer mon profil créateur',
                                style: BkoTheme.fontLato(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black,
                                ),
                              ),
                      ),
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

  Widget _buildBenefitRow(BuildContext context, IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: BkoTheme.goldAccent),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: BkoTheme.fontLato(
              fontSize: 12.5,
              color: BkoTheme.getTextSecondary(context),
            ),
          ),
        ),
      ],
    );
  }
}
