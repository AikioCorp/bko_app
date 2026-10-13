import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import '../../../core/theme/bko_theme.dart';
import '../../../core/widgets/bko_bounceable.dart';
import '../../../core/widgets/bko_haptics.dart';

/// Modal bottom sheet élégant expliquant la limite de téléchargement pour les invités
/// et invitant à créer un compte gratuit pour des téléchargements illimités.
class DownloadLimitModal extends StatelessWidget {
  const DownloadLimitModal({super.key});

  static void show(BuildContext context) {
    BkoHaptics.warning();

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const DownloadLimitModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textPri = BkoTheme.getTextPrimary(context);
    final textSec = BkoTheme.getTextSecondary(context);
    final surfaceElevated = BkoTheme.getBgSurfaceElevated(context);
    final border = BkoTheme.getBorderSubtle(context);

    return Container(
      decoration: BoxDecoration(
        color: surfaceElevated,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: border),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        14,
        24,
        MediaQuery.of(context).padding.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: textSec.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Badge icône or
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: BkoTheme.goldAccent.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(
                color: BkoTheme.goldAccent.withValues(alpha: 0.35),
                width: 1.5,
              ),
            ),
            child: const Center(
              child: Icon(
                IconsaxPlusBold.document_download,
                color: BkoTheme.goldAccent,
                size: 28,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Titre
          Text(
            'Téléchargements illimités',
            textAlign: TextAlign.center,
            style: BkoTheme.fontPoppins(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: textPri,
            ),
          ),
          const SizedBox(height: 8),

          // Message clair
          Text(
            'Vous profitez déjà d\'un épisode d\'essai hors-ligne sans compte. Connectez-vous ou créez votre compte gratuit en 30 secondes pour télécharger tous vos épisodes et les écouter partout sans réseau !',
            textAlign: TextAlign.center,
            style: BkoTheme.fontLato(
              fontSize: 13,
              color: textSec,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 20),

          // Avantages du compte
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: BkoTheme.getBgSurface(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: border),
            ),
            child: Column(
              children: [
                _buildBenefitRow(
                  context,
                  icon: IconsaxPlusLinear.flash_1,
                  title: 'Écoute hors-ligne illimitée',
                  subtitle: 'Téléchargez autant d\'épisodes que vous voulez',
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Divider(color: border, height: 1),
                ),
                _buildBenefitRow(
                  context,
                  icon: IconsaxPlusLinear.refresh_2,
                  title: 'Synchronisation automatique',
                  subtitle: 'Retrouvez votre bibliothèque sur tous vos appareils',
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Divider(color: border, height: 1),
                ),
                _buildBenefitRow(
                  context,
                  icon: IconsaxPlusLinear.shield_tick,
                  title: '100% gratuit & sans abonnement',
                  subtitle: 'Accès libre à l\'ensemble des émissions Bamako Podcast',
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // CTA Principal : Se connecter / Créer un compte
          SizedBox(
            width: double.infinity,
            height: 48,
            child: BkoBounceable(
              onTap: () {
                BkoHaptics.select();
                final router = GoRouter.of(context);
                String currentUri = '/';
                try {
                  currentUri = router.routeInformationProvider.value.uri.toString();
                } catch (_) {}
                final redirect = Uri.encodeComponent(currentUri);
                Navigator.pop(context);
                router.push('/login?redirect=$redirect');
              },
              child: Container(
                decoration: BoxDecoration(
                  color: BkoTheme.getPrimaryButtonBg(context),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Se connecter ou créer un compte',
                  style: BkoTheme.fontPoppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: BkoTheme.getPrimaryButtonText(context),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // CTA Secondaire : Voir mes téléchargements
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: () {
                  BkoHaptics.light();
                  Navigator.pop(context);
                  try {
                    context.push('/downloads');
                  } catch (_) {}
                },
                child: Text(
                  'Gérer mes téléchargements',
                  style: BkoTheme.fontLato(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: BkoTheme.goldAccent,
                  ),
                ),
              ),
              Text(
                '•',
                style: TextStyle(color: textSec.withValues(alpha: 0.5)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Plus tard',
                  style: BkoTheme.fontLato(
                    fontSize: 13,
                    color: textSec,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final textPri = BkoTheme.getTextPrimary(context);
    final textSec = BkoTheme.getTextSecondary(context);

    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: BkoTheme.goldAccent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Icon(icon, color: BkoTheme.goldAccent, size: 16),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: BkoTheme.fontPoppins(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: textPri,
                ),
              ),
              Text(
                subtitle,
                style: BkoTheme.fontLato(
                  fontSize: 11,
                  color: textSec,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
