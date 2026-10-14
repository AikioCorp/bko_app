import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../routing/app_router.dart';
import '../theme/bko_theme.dart';
import 'bko_bounceable.dart';
import 'bko_haptics.dart';

enum BkoToastType {
  library,
  playlist,
  download,
  success,
  error,
  info,
}

/// Système d'alerte / toast unifié et haut de gamme de Bamako Podcast.
/// Conforme aux compétences `mobile-designer` et `apple-design` :
/// - Icônes Iconsax uniquement (Bold dans le badge, Linear pour les flèches)
/// - Zéro ombre, zéro dégradé, surfaces solides élégantes
/// - Support complet des thèmes (sombre / clair) via BkoTheme
/// - Micro-animations tactiles avec BkoBounceable et haptique calibrée
/// - Bouton d'action direct (« Voir », « Annuler », « Réessayer »)
class BkoToast {
  static void show(
    BuildContext context, {
    required String title,
    String? message,
    IconData? icon,
    Color? accentColor,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 4),
    BkoToastType type = BkoToastType.info,
  }) {
    BkoHaptics.light();

    final scaffoldMessenger = ScaffoldMessenger.maybeOf(context);
    if (scaffoldMessenger == null) return;

    scaffoldMessenger.hideCurrentSnackBar();

    final textPri = BkoTheme.getTextPrimary(context);
    final textSec = BkoTheme.getTextSecondary(context);
    final surfaceElevated = BkoTheme.getBgSurfaceElevated(context);

    // Résolution des couleurs et icônes selon le type
    final Color resolvedAccent = accentColor ?? _resolveAccentColor(type);
    final IconData resolvedIcon = icon ?? _resolveIcon(type);

    void handleTap() {
      scaffoldMessenger.hideCurrentSnackBar();
      if (onAction != null) {
        BkoHaptics.select();
        onAction();
      }
    }

    scaffoldMessenger.showSnackBar(
      SnackBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        behavior: SnackBarBehavior.floating,
        duration: duration,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 88),
        padding: EdgeInsets.zero,
        content: BkoBounceable(
          onTap: onAction != null ? handleTap : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: surfaceElevated,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: resolvedAccent.withValues(alpha: 0.35),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                // Badge icône Iconsax avec fond accentué
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: resolvedAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Icon(
                      resolvedIcon,
                      color: resolvedAccent,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Titre et message descriptif
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: BkoTheme.fontPoppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: textPri,
                        ),
                      ),
                      if (message != null && message.trim().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          message.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: BkoTheme.fontLato(
                            fontSize: 11.5,
                            color: textSec,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Bouton d'action direct (ex: « Voir »)
                if (actionLabel != null && actionLabel.isNotEmpty) ...[
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: handleTap,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: resolvedAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: resolvedAccent.withValues(alpha: 0.4),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            actionLabel,
                            style: BkoTheme.fontPoppins(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: resolvedAccent,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            IconsaxPlusLinear.arrow_right_3,
                            size: 13,
                            color: resolvedAccent,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- SHORTCUTS CONTEXTUELS ---

  /// Alerte bibliothèque : enregistrement ou retrait
  static void showLibrary(
    BuildContext context, {
    required String title,
    String? podcastName,
    bool isSaved = true,
  }) {
    void openLibrary() {
      try {
        appRouter.push('/library');
      } catch (_) {
        try {
          context.push('/library');
        } catch (_) {}
      }
    }

    show(
      context,
      type: BkoToastType.library,
      title: isSaved ? 'Enregistré dans la bibliothèque' : 'Retiré de la bibliothèque',
      message: title.isNotEmpty ? title : (podcastName ?? 'Disponible dans vos favoris'),
      icon: isSaved ? IconsaxPlusBold.archive_add : IconsaxPlusLinear.archive_minus,
      accentColor: BkoTheme.goldAccent,
      actionLabel: isSaved ? 'Voir' : null,
      onAction: isSaved ? openLibrary : null,
    );
  }

  /// Alerte playlist : ajout d'un épisode à une playlist
  static void showPlaylist(
    BuildContext context, {
    required String playlistName,
    String? episodeTitle,
  }) {
    void openLibrary() {
      try {
        appRouter.push('/library');
      } catch (_) {
        try {
          context.push('/library');
        } catch (_) {}
      }
    }

    show(
      context,
      type: BkoToastType.playlist,
      title: 'Ajouté à la playlist',
      message: '« $playlistName »',
      icon: IconsaxPlusBold.music_playlist,
      accentColor: BkoTheme.goldAccent,
      actionLabel: 'Voir',
      onAction: openLibrary,
    );
  }

  /// Alerte téléchargement : lancement d'un téléchargement hors connexion
  static void showDownload(
    BuildContext context, {
    required String title,
    String? podcastName,
  }) {
    void openDownloads() {
      try {
        appRouter.push('/downloads');
      } catch (_) {
        try {
          context.push('/downloads');
        } catch (_) {}
      }
    }

    show(
      context,
      type: BkoToastType.download,
      title: 'Téléchargement lancé',
      message: title.isNotEmpty ? title : (podcastName ?? 'Disponible hors connexion'),
      icon: IconsaxPlusBold.document_download,
      accentColor: BkoTheme.goldAccent,
      actionLabel: 'Voir',
      onAction: openDownloads,
    );
  }

  /// Alerte succès générique
  static void showSuccess(
    BuildContext context, {
    required String title,
    String? message,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 4),
  }) {
    show(
      context,
      type: BkoToastType.success,
      title: title,
      message: message,
      icon: IconsaxPlusBold.tick_circle,
      accentColor: const Color(0xFF22C55E), // Émeraude sobre
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
    );
  }

  /// Alerte erreur avec micro-haptique d'avertissement
  static void showError(
    BuildContext context, {
    required String title,
    String? message,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 4),
  }) {
    BkoHaptics.warning();
    show(
      context,
      type: BkoToastType.error,
      title: title,
      message: message,
      icon: IconsaxPlusBold.info_circle,
      accentColor: const Color(0xFFEF4444), // Rouge sobre
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
    );
  }

  /// Alerte informative générique
  static void showInfo(
    BuildContext context, {
    required String title,
    String? message,
    IconData? icon,
    Color? accentColor,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 3),
  }) {
    show(
      context,
      type: BkoToastType.info,
      title: title,
      message: message,
      icon: icon ?? IconsaxPlusBold.info_circle,
      accentColor: accentColor ?? BkoTheme.goldAccent,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
    );
  }

  static Color _resolveAccentColor(BkoToastType type) {
    switch (type) {
      case BkoToastType.library:
      case BkoToastType.playlist:
      case BkoToastType.download:
      case BkoToastType.info:
        return BkoTheme.goldAccent;
      case BkoToastType.success:
        return const Color(0xFF22C55E);
      case BkoToastType.error:
        return const Color(0xFFEF4444);
    }
  }

  static IconData _resolveIcon(BkoToastType type) {
    switch (type) {
      case BkoToastType.library:
        return IconsaxPlusBold.archive_add;
      case BkoToastType.playlist:
        return IconsaxPlusBold.music_playlist;
      case BkoToastType.download:
        return IconsaxPlusBold.document_download;
      case BkoToastType.success:
        return IconsaxPlusBold.tick_circle;
      case BkoToastType.error:
        return IconsaxPlusBold.info_circle;
      case BkoToastType.info:
        return IconsaxPlusBold.info_circle;
    }
  }
}
