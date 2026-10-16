import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import '../../core/theme/bko_theme.dart';
import '../../core/widgets/bko_bounceable.dart';
import '../../core/widgets/bko_haptics.dart';
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
    final effectiveDetails = details ?? AuthNotifier.lastSuspendedDetails;
    context.push('/support?context=suspension', extra: effectiveDetails);
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

    final effectiveDetails = details ?? AuthNotifier.lastSuspendedDetails;
    final fullName = effectiveDetails?['fullName']?.toString().trim();
    final email = effectiveDetails?['email']?.toString().trim();
    final avatar = effectiveDetails?['avatar']?.toString().trim();
    final hasUserIdentity =
        (fullName != null && fullName.isNotEmpty) || (email != null && email.isNotEmpty);

    final reason = (effectiveDetails?['reason']?.toString().trim().isNotEmpty == true)
        ? effectiveDetails!['reason'].toString()
        : 'Non-respect des conditions d\'utilisation de la plateforme.';
    final isPermanent = effectiveDetails?['isPermanent'] ?? true;
    final suspendedAtFormatted =
        _formatDate(effectiveDetails?['suspendedAt']?.toString());
    final suspendedUntilFormatted =
        _formatDate(effectiveDetails?['suspendedUntil']?.toString());

    final initials = (fullName != null && fullName.isNotEmpty)
        ? fullName
            .split(' ')
            .where((p) => p.isNotEmpty)
            .map((p) => p[0])
            .take(2)
            .join('')
            .toUpperCase()
        : (email != null && email.isNotEmpty ? email[0].toUpperCase() : 'U');

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
                  const SizedBox(height: 20),

                  // Badge Compte suspendu
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0x28EF4444),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0x45EF4444), width: 1),
                    ),
                    child: const Text(
                      'COMPTE SUSPENDU',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: Color(0xFFEF4444),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Titre
                  Text(
                    'Accès au compte restreint',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 8),

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

                  // Carte Profil utilisateur bloqué
                  if (hasUserIdentity) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: bgSurface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderSubtle, width: 1),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: bgElevated,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: borderSubtle, width: 1),
                            ),
                            clipBehavior: Clip.antiAlias,
                            alignment: Alignment.center,
                            child: (avatar != null && avatar.isNotEmpty)
                                ? Image.network(
                                    avatar,
                                    width: 44,
                                    height: 44,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Text(
                                      initials,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: textPrimary,
                                      ),
                                    ),
                                  )
                                : Text(
                                    initials,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: textPrimary,
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        fullName ?? 'Utilisateur',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: textPrimary,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0x1FEF4444),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                            color: const Color(0x3DEF4444), width: 1),
                                      ),
                                      child: const Text(
                                        'Bloqué',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFFEF4444),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (email != null && email.isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      Icon(
                                        IconsaxPlusLinear.sms,
                                        size: 13,
                                        color: textMuted,
                                      ),
                                      const SizedBox(width: 5),
                                      Flexible(
                                        child: Text(
                                          email,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: textSecondary,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        IconsaxPlusLinear.verify,
                                        size: 13,
                                        color: BkoTheme.getSuccess(context),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

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
                            Icon(
                              IconsaxPlusLinear.info_circle,
                              size: 16,
                              color: BkoTheme.getAccent(context),
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
                        if (suspendedAtFormatted.isNotEmpty ||
                            (!isPermanent &&
                                suspendedUntilFormatted.isNotEmpty)) ...[
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
                              if (!isPermanent &&
                                  suspendedUntilFormatted.isNotEmpty)
                                Text(
                                  'Fin prévue le : $suspendedUntilFormatted',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: BkoTheme.getAccent(context),
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
