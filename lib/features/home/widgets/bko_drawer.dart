import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../../../core/theme/bko_theme.dart';
import '../../../core/widgets/bko_bounceable.dart';
import '../../../core/widgets/bko_haptics.dart';
import '../../auth/auth_controller.dart';

/// Menu tiroir (Hamburger Drawer) pour auditeur connecté.
/// Respecte scrupuleusement les exigences du projet et les règles mobile-designer :
/// - En-tête : Avatar, Nom affiché, « Voir mon profil »
/// - 9 Entrées dédiées ouvrant des pages réellement fonctionnelles :
///   1. Mon compte (/account)
///   2. Préférences d’écoute (/settings/playback)
///   3. Apparence (/settings/appearance)
///   4. Téléchargements et stockage (/settings/downloads)
///   5. Préférences de notifications (/settings/notifications)
///   6. Sécurité et appareils (/settings/security)
///   7. Confidentialité et données (/settings/privacy)
///   8. Aide et assistance (/settings/help)
///   9. À propos (/settings/about)
/// - Actions séparées en bas :
///   * Devenir créateur (/become-creator) ou Mon studio (/studio) si autorisé
///   * Se déconnecter
/// - Fermeture propre du panneau avant toute navigation
/// - Zéro ombre, zéro dégradé, cibles tactiles >= 48px
class BkoDrawer extends ConsumerWidget {
  const BkoDrawer({super.key});

  void _navigateTo(BuildContext context, String path) {
    Navigator.of(context).pop();
    BkoHaptics.light();
    context.push(path);
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final surfaceElevated = BkoTheme.getBgSurfaceElevated(context);
    final border = BkoTheme.getBorderSubtle(context);
    final textPri = BkoTheme.getTextPrimary(context);
    final textSec = BkoTheme.getTextSecondary(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: border),
        ),
        title: Row(
          children: [
            Icon(IconsaxPlusLinear.logout, color: Theme.of(context).colorScheme.error, size: 22),
            const SizedBox(width: 10),
            Text(
              'Déconnexion',
              style: BkoTheme.fontLato(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: textPri,
              ),
            ),
          ],
        ),
        content: Text(
          'Êtes-vous sûr de vouloir vous déconnecter de votre compte ? Vos favoris et playlists synchronisés restent sauvegardés sur le serveur.',
          style: BkoTheme.fontLato(fontSize: 13, color: textSec, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Annuler',
              style: BkoTheme.fontLato(color: textSec, fontWeight: FontWeight.w700),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              'Se déconnecter',
              style: BkoTheme.fontLato(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(authProvider.notifier).logout();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final user = auth.user ?? {};
    final fullName = user['fullName'] ?? user['name'] ?? 'Auditeur';
    final avatarUrl = (user['avatar'] as String?)?.trim() ?? '';
    final roles = (user['roles'] as List?)?.map((r) => '$r'.toUpperCase()).toList() ?? [];
    final isCreator = roles.contains('CREATOR') || user['creatorProfile'] != null;

    final textPri = BkoTheme.getTextPrimary(context);
    final surfaceElevated = BkoTheme.getBgSurfaceElevated(context);
    final border = BkoTheme.getBorderSubtle(context);

    return Drawer(
      backgroundColor: BkoTheme.getBgObsidian(context),
      elevation: 0,
      child: SafeArea(
        child: Column(
          children: [
            // En-tête : Avatar, Nom affiché, et « Voir mon profil »
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: border)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: surfaceElevated,
                      border: Border.all(color: border, width: 1.5),
                    ),
                    child: ClipOval(
                      child: avatarUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: avatarUrl,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => _buildAvatarInitial(fullName),
                            )
                          : _buildAvatarInitial(fullName),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: BkoTheme.fontLato(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: textPri,
                          ),
                        ),
                        const SizedBox(height: 4),
                        BkoBounceable(
                          onTap: () {
                            Navigator.of(context).pop();
                            BkoHaptics.light();
                            context.go('/profile');
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Voir mon profil',
                                style: BkoTheme.fontLato(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: BkoTheme.goldAccent,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                IconsaxPlusLinear.arrow_right_3,
                                size: 12,
                                color: BkoTheme.goldAccent,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Entrées de navigation (9 pages fonctionnelles)
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                children: [
                  _buildDrawerItem(
                    context: context,
                    icon: IconsaxPlusLinear.user,
                    label: 'Mon compte',
                    onTap: () => _navigateTo(context, '/account'),
                  ),
                  _buildDrawerItem(
                    context: context,
                    icon: IconsaxPlusLinear.music_filter,
                    label: 'Préférences d\'écoute',
                    onTap: () => _navigateTo(context, '/settings/playback'),
                  ),
                  _buildDrawerItem(
                    context: context,
                    icon: IconsaxPlusLinear.colorfilter,
                    label: 'Apparence',
                    onTap: () => _navigateTo(context, '/settings/appearance'),
                  ),
                  _buildDrawerItem(
                    context: context,
                    icon: IconsaxPlusLinear.document_download,
                    label: 'Téléchargements et stockage',
                    onTap: () => _navigateTo(context, '/settings/downloads'),
                  ),
                  _buildDrawerItem(
                    context: context,
                    icon: IconsaxPlusLinear.notification_bing,
                    label: 'Préférences de notifications',
                    onTap: () => _navigateTo(context, '/settings/notifications'),
                  ),
                  _buildDrawerItem(
                    context: context,
                    icon: IconsaxPlusLinear.shield_security,
                    label: 'Sécurité et appareils',
                    onTap: () => _navigateTo(context, '/settings/security'),
                  ),
                  _buildDrawerItem(
                    context: context,
                    icon: IconsaxPlusLinear.lock,
                    label: 'Confidentialité et données',
                    onTap: () => _navigateTo(context, '/settings/privacy'),
                  ),
                  _buildDrawerItem(
                    context: context,
                    icon: IconsaxPlusLinear.message_question,
                    label: 'Aide et assistance',
                    onTap: () => _navigateTo(context, '/settings/help'),
                  ),
                  _buildDrawerItem(
                    context: context,
                    icon: IconsaxPlusLinear.info_circle,
                    label: 'À propos',
                    onTap: () => _navigateTo(context, '/settings/about'),
                  ),
                ],
              ),
            ),

            // Actions séparées en bas : Devenir créateur / Mon studio, et Se déconnecter
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: border)),
              ),
              child: Column(
                children: [
                  if (isCreator)
                    _buildDrawerItem(
                      context: context,
                      icon: IconsaxPlusLinear.microphone_2,
                      label: 'Mon studio créateur',
                      accentColor: BkoTheme.goldAccent,
                      onTap: () => _navigateTo(context, '/studio'),
                    )
                  else
                    _buildDrawerItem(
                      context: context,
                      icon: IconsaxPlusLinear.microphone_2,
                      label: 'Devenir créateur',
                      accentColor: BkoTheme.goldAccent,
                      onTap: () => _navigateTo(context, '/become-creator'),
                    ),
                  _buildDrawerItem(
                    context: context,
                    icon: IconsaxPlusLinear.logout,
                    label: 'Se déconnecter',
                    accentColor: Theme.of(context).colorScheme.error,
                    onTap: () async {
                      Navigator.of(context).pop();
                      await _confirmLogout(context, ref);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarInitial(String name) {
    final initial = name.trim().isNotEmpty ? name.trim().substring(0, 1).toUpperCase() : 'A';
    return Center(
      child: Text(
        initial,
        style: BkoTheme.fontLato(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: BkoTheme.goldAccent,
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? accentColor,
  }) {
    final color = accentColor ?? BkoTheme.getTextPrimary(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            BkoHaptics.light();
            onTap();
          },
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(icon, color: color, size: 21),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: BkoTheme.fontLato(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
                Icon(
                  IconsaxPlusLinear.arrow_right_3,
                  size: 15,
                  color: color.withValues(alpha: 0.35),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
