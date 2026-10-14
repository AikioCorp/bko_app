import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/push_notification_service.dart';
import '../theme/bko_theme.dart';
import 'bko_bounceable.dart';
import 'bko_haptics.dart';
import 'bko_toast.dart';

/// Composant d'autorisation de notifications en 2 étapes (Permission Primer) :
/// 1. Écran personnalisé expliquant la valeur ajoutée aux auditeurs selon les règles mobile-designer
///    (zéro dégradé, zéro ombre, surfaces solides, Iconsax).
/// 2. Déclenchement de la demande native système (Android / iOS) lorsque l'auditeur clique « Activer ».
///
/// Ne s'affiche qu'après la création du compte / onboarding, jamais au démarrage brutal de l'app.
class NotificationPermissionPrimer {
  static const String _prefKey = 'bko_push_permission_prompted_v1';

  /// Affiche le dialogue personnalisé si l'utilisateur ne l'a pas encore vu ou si [force] est vrai.
  /// Retourne `true` si les notifications ont été activées au niveau système.
  static Future<bool> show(
    BuildContext context, {
    bool force = false,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (!force) {
        final alreadyPrompted = prefs.getBool(_prefKey) ?? false;
        if (alreadyPrompted) return false;

        // Si déjà autorisé sur l'appareil, pas besoin d'afficher le dialogue
        final settings = await FirebaseMessaging.instance.getNotificationSettings();
        if (settings.authorizationStatus == AuthorizationStatus.authorized) {
          await prefs.setBool(_prefKey, true);
          return true;
        }
      }

      // Marquer comme sollicité pour ne pas déranger l'utilisateur à chaque visite
      await prefs.setBool(_prefKey, true);

      if (!context.mounted) return false;

      final bool? userWantsEnable = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => const _NotificationPrimerSheet(),
      );

      if (userWantsEnable == true) {
        // Étape 2 : Déclenchement du dialogue natif du système d'exploitation
        final granted = await PushNotificationService.instance.requestNativePermission();
        if (granted) {
          if (context.mounted) {
            BkoToast.showSuccess(
              context,
              title: 'Notifications activées',
              message: 'Vous serez alerté des nouveaux épisodes.',
            );
          }
        }
        return granted;
      }

      return false;
    } catch (e) {
      debugPrint('[NotificationPermissionPrimer] Erreur : $e');
      return false;
    }
  }
}

class _NotificationPrimerSheet extends StatelessWidget {
  const _NotificationPrimerSheet();

  @override
  Widget build(BuildContext context) {
    final surface = BkoTheme.getBgSurface(context);
    final border = BkoTheme.getBorderSubtle(context);
    final textPri = BkoTheme.getTextPrimary(context);
    final textSec = BkoTheme.getTextSecondary(context);

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: border),
      ),
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Poignée de glissement supérieure
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 22),

          // Icône d'alerte personnalisée
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: BkoTheme.goldAccent.withValues(alpha: 0.15),
              border: Border.all(color: BkoTheme.goldAccent.withValues(alpha: 0.3)),
            ),
            child: const Center(
              child: Icon(
                IconsaxPlusLinear.notification_bing,
                color: BkoTheme.goldAccent,
                size: 32,
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Titre personnalisé
          Text(
            'Ne manquez aucun nouvel épisode',
            textAlign: TextAlign.center,
            style: BkoTheme.fontLato(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: textPri,
            ),
          ),
          const SizedBox(height: 8),

          // Description
          Text(
            'Votre compte est prêt ! Activez les alertes pour être prévenu dès la sortie d\'un épisode de vos créateurs et émissions favorites.',
            textAlign: TextAlign.center,
            style: BkoTheme.fontLato(
              fontSize: 13,
              color: textSec,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 20),

          // Liste des avantages concrets
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: BkoTheme.getBgSurfaceElevated(context),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: border),
            ),
            child: Column(
              children: [
                _buildBenefitItem(
                  context,
                  icon: IconsaxPlusLinear.play_circle,
                  title: 'Émissions suivies',
                  subtitle: 'Alerte immédiate lors d\'une nouvelle publication.',
                ),
                const SizedBox(height: 12),
                _buildBenefitItem(
                  context,
                  icon: IconsaxPlusLinear.star_1,
                  title: 'Recommandations ciblées',
                  subtitle: 'Podcasts adaptés à vos langues et centres d\'intérêt.',
                ),
                const SizedBox(height: 12),
                _buildBenefitItem(
                  context,
                  icon: IconsaxPlusLinear.shield_tick,
                  title: 'Respect de votre attention',
                  subtitle: 'Zéro spam. Fréquence paramétrable à tout instant.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Bouton principal (déclenche la permission native)
          BkoBounceable(
            onTap: () {
              BkoHaptics.light();
              Navigator.of(context).pop(true);
            },
            child: Container(
              width: double.infinity,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: BkoTheme.goldAccent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Activer les notifications',
                style: BkoTheme.fontLato(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Bouton discret "Plus tard"
          BkoBounceable(
            onTap: () {
              BkoHaptics.light();
              Navigator.of(context).pop(false);
            },
            child: Container(
              width: double.infinity,
              height: 44,
              alignment: Alignment.center,
              child: Text(
                'Plus tard',
                style: BkoTheme.fontLato(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: textSec,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: BkoTheme.goldAccent),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: BkoTheme.fontLato(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: BkoTheme.getTextPrimary(context),
                ),
              ),
              Text(
                subtitle,
                style: BkoTheme.fontLato(
                  fontSize: 11.5,
                  color: BkoTheme.getTextSecondary(context),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
