import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/bko_theme.dart';
import '../../../core/widgets/bko_bounceable.dart';
import '../../../core/widgets/bko_haptics.dart';
import '../../shell/shell_providers.dart';

/// Modal discret de mise en avant d'une découverte / campagne éditoriale
/// avec limitation stricte de fréquence (frequency capping via SharedPreferences)
/// et respect des règles de design (zéro ombre, zéro dégradé, Iconsax uniquement).
class DiscoveryPromotionModal extends StatelessWidget {
  final String title;
  final String description;
  final String? coverUrl;
  final String buttonLabel;
  final String targetUrl;
  final String campaignId;

  const DiscoveryPromotionModal({
    super.key,
    required this.title,
    required this.description,
    this.coverUrl,
    required this.buttonLabel,
    required this.targetUrl,
    required this.campaignId,
  });

  static const String _prefKeyPrefix = 'discovery_promo_last_shown_';

  /// Vérifie l'éligibilité et affiche le modal si les conditions sont réunies.
  /// Ne s'affiche jamais si le lecteur plein écran est ouvert ou si la fréquence est dépassée.
  static Future<void> checkAndShow({
    required BuildContext context,
    required WidgetRef ref,
    required String campaignId,
    required String title,
    required String description,
    required String buttonLabel,
    required String targetUrl,
    String? coverUrl,
  }) async {
    // 1. Ne jamais afficher si le lecteur audio plein écran est ouvert
    final isFullPlayerOpen = ref.read(isFullPlayerOpenProvider);
    if (isFullPlayerOpen) return;

    // 2. Frequency capping : 24 heures minimum entre deux affichages
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastShown = prefs.getInt('$_prefKeyPrefix$campaignId') ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      const twentyFourHours = 24 * 60 * 60 * 1000;

      if (now - lastShown < twentyFourHours) {
        return;
      }

      // Enregistrer immédiatement l'horodatage
      await prefs.setInt('$_prefKeyPrefix$campaignId', now);
    } catch (_) {
      // Ignorer si les préférences échouent silencieusement
    }

    if (!context.mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (ctx) => DiscoveryPromotionModal(
        campaignId: campaignId,
        title: title,
        description: description,
        buttonLabel: buttonLabel,
        targetUrl: targetUrl,
        coverUrl: coverUrl,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bgSurf = BkoTheme.getBgSurface(context);
    final bgElev = BkoTheme.getBgSurfaceElevated(context);
    final borderSub = BkoTheme.getBorderSubtle(context);
    final textPri = BkoTheme.getTextPrimary(context);
    final textSec = BkoTheme.getTextSecondary(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      elevation: 0,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 380),
        decoration: BoxDecoration(
          color: bgSurf,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: borderSub, width: 1.2),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Close Button Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: bgElev,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: borderSub),
                  ),
                  child: Text(
                    'À découvrir',
                    style: BkoTheme.fontLato(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: BkoTheme.getAccent(context),
                    ),
                  ),
                ),
                BkoBounceable(
                  onTap: () {
                    BkoHaptics.light();
                    Navigator.of(context).pop();
                  },
                  child: Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    child: Icon(
                      IconsaxPlusLinear.close_circle,
                      size: 20,
                      color: textSec,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Optional Cover Artwork
            if (coverUrl != null && coverUrl!.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: CachedNetworkImage(
                    imageUrl: coverUrl!,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(
                      color: bgElev,
                      alignment: Alignment.center,
                      child: Icon(
                        IconsaxPlusLinear.headphone,
                        color: textSec,
                        size: 32,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Title
            Text(
              title,
              textAlign: TextAlign.center,
              style: BkoTheme.fontPoppins(
                fontSize: 19,
                fontWeight: FontWeight.w900,
                color: textPri,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 8),

            // Description
            Text(
              description,
              textAlign: TextAlign.center,
              style: BkoTheme.fontLato(
                fontSize: 13,
                color: textSec,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),

            // Primary CTA Button
            BkoBounceable(
              onTap: () {
                BkoHaptics.light();
                Navigator.of(context).pop();
                context.push(targetUrl);
              },
              child: Container(
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: BkoTheme.goldAccent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      buttonLabel,
                      style: BkoTheme.fontLato(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      IconsaxPlusLinear.arrow_right_3,
                      size: 16,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Secondary Ghost Button: Plus tard
            BkoBounceable(
              onTap: () {
                BkoHaptics.light();
                Navigator.of(context).pop();
              },
              child: Container(
                height: 40,
                alignment: Alignment.center,
                child: Text(
                  'Plus tard',
                  style: BkoTheme.fontLato(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: textSec,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
