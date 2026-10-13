import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import '../theme/bko_theme.dart';
import 'bko_bounceable.dart';
import 'bko_haptics.dart';

/// Notification toast élégante et discrète lors du lancement d'un téléchargement.
/// Conforme au design system Bamako Podcast (Iconsax uniquement, 0 ombre, 0 dégradé, micro-haptique).
class BkoDownloadToast {
  static void show(
    BuildContext context, {
    required String title,
    String? podcastName,
  }) {
    BkoHaptics.light();

    final scaffoldMessenger = ScaffoldMessenger.maybeOf(context);
    if (scaffoldMessenger == null) return;

    scaffoldMessenger.hideCurrentSnackBar();

    final textPri = BkoTheme.getTextPrimary(context);
    final textSec = BkoTheme.getTextSecondary(context);
    final surfaceElevated = BkoTheme.getBgSurfaceElevated(context);

    scaffoldMessenger.showSnackBar(
      SnackBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 88),
        padding: EdgeInsets.zero,
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: surfaceElevated,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: BkoTheme.goldAccent.withValues(alpha: 0.35),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              // Badge icône Iconsax avec fond or subtil
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: BkoTheme.goldAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: Icon(
                    IconsaxPlusBold.document_download,
                    color: BkoTheme.goldAccent,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Libellés titre et sous-titre
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Téléchargement lancé',
                      style: BkoTheme.fontPoppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: textPri,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      title.isNotEmpty ? title : (podcastName ?? 'Disponible hors connexion'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: BkoTheme.fontLato(
                        fontSize: 11.5,
                        color: textSec,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),

              // Bouton d'action direct vers les Téléchargements
              BkoBounceable(
                onTap: () {
                  BkoHaptics.select();
                  scaffoldMessenger.hideCurrentSnackBar();
                  try {
                    context.push('/downloads');
                  } catch (_) {}
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: BkoTheme.goldAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: BkoTheme.goldAccent.withValues(alpha: 0.4),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Voir',
                        style: BkoTheme.fontPoppins(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: BkoTheme.goldAccent,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        IconsaxPlusLinear.arrow_right_3,
                        size: 13,
                        color: BkoTheme.goldAccent,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
