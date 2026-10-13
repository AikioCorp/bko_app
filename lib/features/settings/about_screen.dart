import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/bko_theme.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/widgets/bko_bounceable.dart';
import '../../core/widgets/bko_haptics.dart';

/// Écran « À propos » de Bamako Podcast :
/// - Identité de marque et logo officiel
/// - Version de l'application
/// - Mission culturelle et médiatique au Mali
/// - Consultation des licences open-source (showLicensePage)
/// - Liens vers les conditions d'utilisation et politique de confidentialité
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  Future<void> _launchUrl(String urlString) async {
    final uri = Uri.tryParse(urlString);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BkoTheme.getBgObsidian(context),
      appBar: AppBar(
        leading: const AppBackButton(),
        title: Text(
          'À propos',
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
          // Logo & Version
          Center(
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: BkoTheme.getBgSurface(context),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: BkoTheme.getBorderSubtle(context)),
                  ),
                  child: Center(
                    child: Image.asset(
                      'assets/brand/logo_podcast.png',
                      width: 50,
                      height: 50,
                      errorBuilder: (_, __, ___) => const Icon(
                        IconsaxPlusLinear.microphone_2,
                        size: 38,
                        color: BkoTheme.goldAccent,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Bamako Podcast',
                  style: BkoTheme.fontLato(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: BkoTheme.getTextPrimary(context),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: BkoTheme.getBgSurfaceElevated(context),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: BkoTheme.getBorderSubtle(context)),
                  ),
                  child: Text(
                    'Version 1.0.0 (Build 2026.10)',
                    style: BkoTheme.fontLato(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: BkoTheme.getTextSecondary(context),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // Mission
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: BkoTheme.getBgSurface(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: BkoTheme.getBorderSubtle(context)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LA VOIX DU MALI ET DU SAHEL',
                  style: BkoTheme.fontLato(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    color: BkoTheme.goldAccent,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Bamako Podcast est la plateforme audio et vidéo de référence dédiée aux voix, cultures, débats et histoires du Mali et d\'Afrique de l\'Ouest. Conçue pour une écoute fluide en langues locales (Bambara, Soninké, Peul, Français...), elle valorise les créateurs indépendants et connecte les auditeurs à des récits inspirants.',
                  style: BkoTheme.fontLato(
                    fontSize: 13,
                    color: BkoTheme.getTextSecondary(context),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Liens Légaux et Licences
          Container(
            decoration: BoxDecoration(
              color: BkoTheme.getBgSurface(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: BkoTheme.getBorderSubtle(context)),
            ),
            child: Column(
              children: [
                _buildLinkTile(
                  context: context,
                  title: 'Conditions générales d\'utilisation',
                  icon: IconsaxPlusLinear.document_text,
                  onTap: () => _launchUrl('https://bamakopodcast.studio/terms'),
                  isFirst: true,
                ),
                Divider(height: 1, thickness: 1, color: BkoTheme.getBorderSubtle(context)),
                _buildLinkTile(
                  context: context,
                  title: 'Politique de confidentialité',
                  icon: IconsaxPlusLinear.shield_tick,
                  onTap: () => _launchUrl('https://bamakopodcast.studio/privacy'),
                ),
                Divider(height: 1, thickness: 1, color: BkoTheme.getBorderSubtle(context)),
                _buildLinkTile(
                  context: context,
                  title: 'Licences Open-Source',
                  icon: IconsaxPlusLinear.code_circle,
                  onTap: () {
                    BkoHaptics.light();
                    showLicensePage(
                      context: context,
                      applicationName: 'Bamako Podcast',
                      applicationVersion: '1.0.0',
                      applicationLegalese: '© 2026 Bamako Podcast. Tous droits réservés.',
                    );
                  },
                  isLast: true,
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          Center(
            child: Text(
              'Développé avec passion pour le Mali 🇲🇱',
              style: BkoTheme.fontLato(
                fontSize: 12,
                color: BkoTheme.getTextMuted(context),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkTile({
    required BuildContext context,
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    bool isFirst = false,
    bool isLast = false,
  }) {
    return BkoBounceable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.vertical(
            top: isFirst ? const Radius.circular(16) : Radius.zero,
            bottom: isLast ? const Radius.circular(16) : Radius.zero,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: BkoTheme.getTextPrimary(context)),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: BkoTheme.fontLato(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: BkoTheme.getTextPrimary(context),
                ),
              ),
            ),
            Icon(
              IconsaxPlusLinear.arrow_right_3,
              size: 16,
              color: BkoTheme.getTextMuted(context),
            ),
          ],
        ),
      ),
    );
  }
}
