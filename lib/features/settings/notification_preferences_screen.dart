import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../../core/network/bko_api.dart';
import '../../core/theme/bko_theme.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/widgets/bko_bounceable.dart';
import '../../core/widgets/bko_haptics.dart';
import '../../core/widgets/notification_permission_primer.dart';
import '../auth/auth_controller.dart';

/// Écran des préférences de notifications selon les exigences du projet :
/// - Catégories : Nouveaux épisodes des émissions suivies, recommandations & temps forts, communications éditoriales
/// - Canaux réels : Notifications push, E-mails de récapitulatif
/// - État de l'autorisation système distinct des préférences du compte
/// - Sauvegarde immédiate vers l'API backend (/me/preferences)
class NotificationPreferencesScreen extends ConsumerStatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  ConsumerState<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends ConsumerState<NotificationPreferencesScreen> {
  bool _emailNewEpisodes = true;
  bool _pushNewEpisodes = true;
  bool _editorialHighlights = true;
  bool _isSaving = false;
  AuthorizationStatus? _systemPermissionStatus;

  @override
  void initState() {
    super.initState();
    _loadInitialPreferences();
    _checkSystemPermission();
  }

  void _loadInitialPreferences() {
    final user = ref.read(authProvider).user;
    final notifPref = user?['notificationPreference'];
    if (notifPref is Map) {
      _emailNewEpisodes = notifPref['emailNewEpisodes'] as bool? ?? true;
      _pushNewEpisodes = notifPref['pushNewEpisodes'] as bool? ?? true;
      _editorialHighlights = notifPref['editorialHighlights'] as bool? ?? true;
    }
  }

  Future<void> _checkSystemPermission() async {
    try {
      final settings = await FirebaseMessaging.instance.getNotificationSettings();
      if (mounted) {
        setState(() => _systemPermissionStatus = settings.authorizationStatus);
      }
    } catch (_) {
      // Sur émulateur sans Google Play Services ou environnement web
    }
  }

  Future<void> _requestSystemPermission() async {
    BkoHaptics.light();
    await NotificationPermissionPrimer.show(context, force: true);
    if (mounted) {
      final settings = await FirebaseMessaging.instance.getNotificationSettings();
      setState(() => _systemPermissionStatus = settings.authorizationStatus);
    }
  }

  Future<void> _savePreferences() async {
    final token = ref.read(authProvider).token;
    if (token == null) return;

    setState(() => _isSaving = true);
    try {
      final res = await BkoApi.patch(
        '/me/preferences',
        {
          'notifications': {
            'emailNewEpisodes': _emailNewEpisodes,
            'pushNewEpisodes': _pushNewEpisodes,
            'editorialHighlights': _editorialHighlights,
          },
        },
        token: token,
      );

      final updatedUser = res is Map && res['data'] is Map
          ? Map<String, dynamic>.from(res['data'] as Map)
          : (res is Map ? Map<String, dynamic>.from(res) : null);

      if (updatedUser != null) {
        await ref.read(authProvider.notifier).updateUser(updatedUser);
      }

      if (mounted) {
        setState(() => _isSaving = false);
        BkoHaptics.light();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        BkoHaptics.error();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la sauvegarde : $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BkoTheme.getBgObsidian(context),
      appBar: AppBar(
        leading: const AppBackButton(),
        title: Text(
          'Notifications',
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
          // Statut du système (autorisations de l'appareil)
          _buildSystemPermissionCard(context),
          const SizedBox(height: 24),

          // Section Canaux
          Text(
            'CANAUX D\'ALERTE',
            style: BkoTheme.fontLato(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
              color: BkoTheme.getTextMuted(context),
            ),
          ),
          const SizedBox(height: 10),

          Container(
            decoration: BoxDecoration(
              color: BkoTheme.getBgSurface(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: BkoTheme.getBorderSubtle(context)),
            ),
            child: Column(
              children: [
                _buildSwitchTile(
                  context: context,
                  title: 'Notifications Push',
                  subtitle: 'Recevez les alertes en temps réel directement sur cet appareil.',
                  icon: IconsaxPlusLinear.notification_bing,
                  value: _pushNewEpisodes,
                  onChanged: (val) {
                    setState(() => _pushNewEpisodes = val);
                    _savePreferences();
                  },
                  isFirst: true,
                ),
                Divider(height: 1, thickness: 1, color: BkoTheme.getBorderSubtle(context)),
                _buildSwitchTile(
                  context: context,
                  title: 'E-mails de synthèse',
                  subtitle: 'Récapitulatif des nouveautés et temps forts dans votre boîte mail.',
                  icon: IconsaxPlusLinear.sms,
                  value: _emailNewEpisodes,
                  onChanged: (val) {
                    setState(() => _emailNewEpisodes = val);
                    _savePreferences();
                  },
                  isLast: true,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Section Catégories de contenu
          Text(
            'CATÉGORIES DE CONTENU',
            style: BkoTheme.fontLato(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
              color: BkoTheme.getTextMuted(context),
            ),
          ),
          const SizedBox(height: 10),

          Container(
            decoration: BoxDecoration(
              color: BkoTheme.getBgSurface(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: BkoTheme.getBorderSubtle(context)),
            ),
            child: Column(
              children: [
                _buildSwitchTile(
                  context: context,
                  title: 'Nouveaux épisodes suivis',
                  subtitle: 'Alerte dès qu\'une émission que vous suivez publie un nouvel épisode.',
                  icon: IconsaxPlusLinear.play_circle,
                  value: _pushNewEpisodes,
                  onChanged: (val) {
                    setState(() => _pushNewEpisodes = val);
                    _savePreferences();
                  },
                  isFirst: true,
                ),
                Divider(height: 1, thickness: 1, color: BkoTheme.getBorderSubtle(context)),
                _buildSwitchTile(
                  context: context,
                  title: 'Recommandations & Découvertes',
                  subtitle: 'Suggestions personnalisées selon vos langues et centres d\'intérêt.',
                  icon: IconsaxPlusLinear.star_1,
                  value: _editorialHighlights,
                  onChanged: (val) {
                    setState(() => _editorialHighlights = val);
                    _savePreferences();
                  },
                ),
                Divider(height: 1, thickness: 1, color: BkoTheme.getBorderSubtle(context)),
                _buildSwitchTile(
                  context: context,
                  title: 'Actualités & Communications du service',
                  subtitle: 'Nouveautés de la plateforme, mises à jour et événements au Mali.',
                  icon: IconsaxPlusLinear.info_circle,
                  value: _editorialHighlights,
                  onChanged: (val) {
                    setState(() => _editorialHighlights = val);
                    _savePreferences();
                  },
                  isLast: true,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Indicateur de sauvegarde automatique
          if (_isSaving)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(BkoTheme.goldAccent),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Enregistrement de vos préférences...',
                  style: BkoTheme.fontLato(
                    fontSize: 12,
                    color: BkoTheme.getTextSecondary(context),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildSystemPermissionCard(BuildContext context) {
    final isAuthorized =
        _systemPermissionStatus == AuthorizationStatus.authorized ||
        _systemPermissionStatus == AuthorizationStatus.provisional;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BkoTheme.getBgSurface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isAuthorized ? BkoTheme.getBorderSubtle(context) : BkoTheme.goldAccent.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isAuthorized
                      ? Colors.green.withValues(alpha: 0.15)
                      : BkoTheme.goldAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Icon(
                    isAuthorized
                        ? IconsaxPlusLinear.tick_circle
                        : IconsaxPlusLinear.notification_status,
                    size: 20,
                    color: isAuthorized ? Colors.green : BkoTheme.goldAccent,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Autorisation système',
                      style: BkoTheme.fontLato(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: BkoTheme.getTextPrimary(context),
                      ),
                    ),
                    Text(
                      isAuthorized
                          ? 'Autorisées sur cet appareil'
                          : 'Non autorisées ou en attente',
                      style: BkoTheme.fontLato(
                        fontSize: 12,
                        color: isAuthorized ? Colors.green : BkoTheme.goldAccent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!isAuthorized) ...[
            const SizedBox(height: 12),
            Text(
              'Pour recevoir les alertes même lorsque l\'application est fermée, autorisez les notifications au niveau du système.',
              style: BkoTheme.fontLato(
                fontSize: 12,
                color: BkoTheme.getTextSecondary(context),
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            BkoBounceable(
              onTap: _requestSystemPermission,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: BkoTheme.goldAccent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    'Activer les notifications système',
                    style: BkoTheme.fontLato(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool isFirst = false,
    bool isLast = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.vertical(
          top: isFirst ? const Radius.circular(16) : Radius.zero,
          bottom: isLast ? const Radius.circular(16) : Radius.zero,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: BkoTheme.getTextPrimary(context)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: BkoTheme.fontLato(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: BkoTheme.getTextPrimary(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: BkoTheme.fontLato(
                    fontSize: 11.5,
                    color: BkoTheme.getTextSecondary(context),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: (val) {
              BkoHaptics.selection();
              onChanged(val);
            },
            activeThumbColor: BkoTheme.goldAccent,
            activeTrackColor: BkoTheme.goldAccent.withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }
}
