import 'package:flutter/material.dart';
import 'bko_toast.dart';

/// Notification toast élégante et discrète lors du lancement d'un téléchargement.
/// Conforme au design system Bamako Podcast (Iconsax uniquement, 0 ombre, 0 dégradé, micro-haptique).
class BkoDownloadToast {
  static void show(
    BuildContext context, {
    required String title,
    String? podcastName,
  }) {
    BkoToast.showDownload(
      context,
      title: title,
      podcastName: podcastName,
    );
  }
}
