import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/bko_theme.dart';
import '../../core/widgets/bko_bounceable.dart';
import '../../core/widgets/bko_haptics.dart';
import '../../core/widgets/bko_toast.dart';
import 'auth_controller.dart';

class SuspendedScreen extends StatelessWidget {
  final Map<String, dynamic>? details;

  const SuspendedScreen({super.key, this.details});

  String _formatDate(String? rawDate) {
    if (rawDate == null || rawDate.isEmpty) return '';
    try {
      final dt = DateTime.parse(rawDate).toLocal();
      final day = dt.day.toString().padLeft(2, '0');
      final month = dt.month.toString().padLeft(2, '0');
      final year = dt.year.toString();
      return '$day/$month/$year';
    } catch (_) {
      return rawDate;
    }
  }

  Future<void> _contactSupport(BuildContext context) async {
    BkoHaptics.light();
    final uri = Uri.parse(
      'mailto:support@bamakopodcast.com?subject=Demande%20d%27assistance%20-%20Compte%20suspendu',
    );
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (context.mounted) {
          BkoToast.showInfo(
            context,
            title: 'Support',
            message: 'support@bamakopodcast.com',
            icon: IconsaxPlusBold.sms,
          );
        }
      }
    } catch (_) {}
  }

  void _returnHome(BuildContext context) {
    BkoHaptics.light();
    AuthNotifier.resetSuspensionHandled();
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final bgObsidian = BkoTheme.getBgObsidian(context);
    final bgSurface = BkoTheme.getBgSurface(context);
    final bgElevated = BkoTheme.getBgSurfaceElevated(context);
    final borderSubtle = BkoTheme.getBorderSubtle(context);
    final textPrimary = BkoTheme.getTextPrimary(context);
    final textSecondary = BkoTheme.getTextSecondary(context);
    final textMuted = BkoTheme.getTextMuted(context);

    final reason = (details?['reason']?.toString().trim().isNotEmpty == true)
        ? details!['reason'].toString()
        : 'Non-respect des conditions d\'utilisation de la plateforme.';
    final isPermanent = details?['isPermanent'] ?? true;
    final suspendedAtFormatted = _formatDate(details?['suspendedAt']?.toString());
    final suspendedUntilFormatted = _formatDate(details?['suspendedUntil']?.toString());

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _returnHome(context);
        }
      },
      child: Scaffold(
        backgroundColor: bgObsidian,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Icône Shield Cross sobre (zéro gradient, zéro ombre)
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: const Color(0x1FEF4444),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0x3DEF4444),
                        width: 1.5,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      IconsaxPlusLinear.shield_cross,
                      color: Color(0xFFEF4444),
                      size: 34,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Titre
                  Text(
                    'Votre compte a été suspendu',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Explication courte
                  Text(
                    'L\'accès aux fonctionnalités connectées de votre compte a été restreint par l\'administration de Bamako Podcast.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Carte Motif public
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: bgSurface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderSubtle, width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              IconsaxPlusLinear.info_circle,
                              size: 16,
                              color: BkoTheme.goldAccent,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Motif de la décision',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          reason,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: textPrimary,
                            height: 1.4,
                          ),
                        ),
                        if (suspendedAtFormatted.isNotEmpty || (!isPermanent && suspendedUntilFormatted.isNotEmpty)) ...[
                          const SizedBox(height: 12),
                          Divider(color: borderSubtle, height: 1),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              if (suspendedAtFormatted.isNotEmpty)
                                Text(
                                  'Appliqué le : $suspendedAtFormatted',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: textMuted,
                                  ),
                                ),
                              if (!isPermanent && suspendedUntilFormatted.isNotEmpty)
                                Text(
                                  'Fin prévue le : $suspendedUntilFormatted',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: BkoTheme.goldAccent,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Bouton Contacter l'assistance (Gold Accent)
                  BkoBounceable(
                    onTap: () => _contactSupport(context),
                    child: Container(
                      width: double.infinity,
                      height: 50,
                      decoration: BoxDecoration(
                        color: BkoTheme.goldAccent,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            IconsaxPlusLinear.sms,
                            color: Colors.black,
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Contacter l\'assistance',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Bouton Retour à l'accueil
                  BkoBounceable(
                    onTap: () => _returnHome(context),
                    child: Container(
                      width: double.infinity,
                      height: 50,
                      decoration: BoxDecoration(
                        color: bgElevated,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: borderSubtle, width: 1),
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            IconsaxPlusLinear.home_2,
                            color: textSecondary,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Retour à l\'accueil',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Reassurance footer
                  Text(
                    'Si vous estimez qu\'il s\'agit d\'une erreur, notre équipe support répond sous 24 à 48 heures. Vos téléchargements hors-ligne demeurent sauvegardés.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.45,
                      color: textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
