import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import '../theme/bko_theme.dart';
import 'bko_bounceable.dart';
import 'bko_haptics.dart';
import '../../features/notifications/services/notification_destination_handler.dart';

/// Notification toast élégante, native et discrète lorsqu'un push ou une alerte
/// arrive pendant que l'application est au premier plan (foreground).
/// Respecte le design system Bamako Podcast (Iconsax uniquement, 0 ombre, 0 dégradé, micro-haptique).
class BkoNotificationToast {
  static void show(
    BuildContext context, {
    required String title,
    String? body,
    String? destination,
  }) {
    BkoHaptics.light();

    final scaffoldMessenger = ScaffoldMessenger.maybeOf(context);
    if (scaffoldMessenger == null) return;

    scaffoldMessenger.hideCurrentSnackBar();

    final textPri = BkoTheme.getTextPrimary(context);
    final textSec = BkoTheme.getTextSecondary(context);
    final surfaceElevated = BkoTheme.getBgSurfaceElevated(context);

    void onTap() {
      scaffoldMessenger.hideCurrentSnackBar();
      if (destination != null && destination.isNotEmpty) {
        NotificationDestinationHandler.navigate(context, destination);
      }
    }

    scaffoldMessenger.showSnackBar(
      SnackBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 88),
        padding: EdgeInsets.zero,
        content: BkoBounceable(
          onTap: onTap,
          child: Container(
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
                      IconsaxPlusBold.notification_1,
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
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: BkoTheme.fontPoppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: textPri,
                        ),
                      ),
                      if (body != null && body.trim().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          body,
                          maxLines: 2,
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
                const SizedBox(width: 8),

                if (destination != null && destination.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: BkoTheme.goldAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
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
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: BkoTheme.goldAccent,
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(
                          IconsaxPlusLinear.arrow_right_3,
                          size: 11,
                          color: BkoTheme.goldAccent,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
