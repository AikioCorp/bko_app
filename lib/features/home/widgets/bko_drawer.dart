import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../../../core/theme/bko_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/widgets/bko_bounceable.dart';
import '../../../core/widgets/bko_haptics.dart';
import '../../auth/auth_controller.dart';

/// Tiroir de navigation latéral (Drawer) pour Bamako Podcast.
/// Conçu selon les règles mobile-designer : Iconsax uniquement, cibles tactiles >= 48px,
/// zéro ombre, couleurs dynamiques BkoTheme, badges réservés aux créateurs/admins.
class BkoDrawer extends ConsumerWidget {
  const BkoDrawer({super.key});

  void _showPreferencesSheet(BuildContext context, WidgetRef ref) {
    final surface = BkoTheme.getBgSurface(context);
    final surfaceElevated = BkoTheme.getBgSurfaceElevated(context);
    final textPri = BkoTheme.getTextPrimary(context);
    final textSec = BkoTheme.getTextSecondary(context);
    final border = BkoTheme.getBorderSubtle(context);

    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      backgroundColor: surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final currentSetting = ref.watch(themeSettingProvider);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Préférences d\'affichage',
                      style: BkoTheme.fontLato(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: textPri,
                      ),
                    ),
                    IconButton(
                      icon: Icon(IconsaxPlusLinear.close_circle, color: textSec, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildThemeOptionTile(
                  ctx,
                  ref,
                  icon: IconsaxPlusLinear.moon,
                  title: 'Mode Sombre (Obsidienne)',
                  setting: AppThemeSetting.dark,
                  currentSetting: currentSetting,
                  surface: surface,
                  border: border,
                  textPri: textPri,
                ),
                const SizedBox(height: 10),
                _buildThemeOptionTile(
                  ctx,
                  ref,
                  icon: IconsaxPlusLinear.sun_1,
                  title: 'Thème Système',
                  setting: AppThemeSetting.system,
                  currentSetting: currentSetting,
                  surface: surface,
                  border: border,
                  textPri: textPri,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildThemeOptionTile(
    BuildContext ctx,
    WidgetRef ref, {
    required IconData icon,
    required String title,
    required AppThemeSetting setting,
    required AppThemeSetting currentSetting,
    required Color surface,
    required Color border,
    required Color textPri,
  }) {
    final isSelected = currentSetting == setting;
    return BkoBounceable(
      onTap: () {
        BkoHaptics.select();
        ref.read(themeSettingProvider.notifier).setThemeSetting(setting);
        Navigator.pop(ctx);
      },
      child: Container(
        constraints: const BoxConstraints(minHeight: 50),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? BkoTheme.goldAccent.withValues(alpha: 0.12) : surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? BkoTheme.goldAccent.withValues(alpha: 0.5) : border,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? BkoTheme.goldAccent : BkoTheme.getTextSecondary(ctx),
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: BkoTheme.fontLato(
                  fontSize: 14,
                  color: isSelected ? BkoTheme.goldAccent : textPri,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
            if (isSelected)
              const Icon(IconsaxPlusLinear.tick_circle, color: BkoTheme.goldAccent, size: 20),
          ],
        ),
      ),
    );
  }

  void _showSecuritySheet(BuildContext context) {
    final surfaceElevated = BkoTheme.getBgSurfaceElevated(context);
    final surface = BkoTheme.getBgSurface(context);
    final textPri = BkoTheme.getTextPrimary(context);
    final textSec = BkoTheme.getTextSecondary(context);
    final border = BkoTheme.getBorderSubtle(context);

    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      backgroundColor: surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Sécurité & Session',
                    style: BkoTheme.fontLato(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: textPri,
                    ),
                  ),
                  IconButton(
                    icon: Icon(IconsaxPlusLinear.close_circle, color: textSec, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: border),
                ),
                child: Row(
                  children: [
                    const Icon(IconsaxPlusLinear.shield_tick, color: BkoTheme.goldAccent, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Session mobile sécurisée',
                            style: BkoTheme.fontLato(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: textPri,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Chiffrement JWT actif et jeton vérifié par l\'API Bamako Podcast.',
                            style: BkoTheme.fontLato(fontSize: 11.5, color: textSec),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              BkoBounceable(
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/profile/edit');
                },
                child: Container(
                  constraints: const BoxConstraints(minHeight: 48),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(IconsaxPlusLinear.user_edit, size: 18, color: textPri),
                      const SizedBox(width: 8),
                      Text(
                        'Modifier mes informations personnelles',
                        style: BkoTheme.fontLato(fontSize: 13, fontWeight: FontWeight.w700, color: textPri),
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

  void _showHelpSheet(BuildContext context) {
    final surfaceElevated = BkoTheme.getBgSurfaceElevated(context);
    final surface = BkoTheme.getBgSurface(context);
    final textPri = BkoTheme.getTextPrimary(context);
    final textSec = BkoTheme.getTextSecondary(context);
    final border = BkoTheme.getBorderSubtle(context);

    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      backgroundColor: surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Aide & Support Bamako Podcast',
                    style: BkoTheme.fontLato(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: textPri,
                    ),
                  ),
                  IconButton(
                    icon: Icon(IconsaxPlusLinear.close_circle, color: textSec, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Plateforme audio de référence pour découvrir, écouter et publier des podcasts au Mali et dans toute la diaspora.',
                style: BkoTheme.fontLato(fontSize: 13, color: textSec, height: 1.4),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: border),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(IconsaxPlusLinear.sms, color: BkoTheme.goldAccent, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: SelectableText(
                            'contact@bamakopodcast.studio',
                            style: BkoTheme.fontLato(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: textPri,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(IconsaxPlusLinear.global, color: BkoTheme.goldAccent, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: SelectableText(
                            'bamakopodcast.studio',
                            style: BkoTheme.fontLato(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: textPri,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              BkoBounceable(
                onTap: () {
                  Clipboard.setData(const ClipboardData(text: 'contact@bamakopodcast.studio'));
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('E-mail de support copié dans le presse-papiers.'),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: BkoTheme.goldAccent,
                    ),
                  );
                },
                child: Container(
                  constraints: const BoxConstraints(minHeight: 48),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: BkoTheme.goldAccent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'COPIER L\'E-MAIL DE SUPPORT',
                    style: BkoTheme.fontLato(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                      color: BkoTheme.darkBgObsidian,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
          'Êtes-vous sûr de vouloir vous déconnecter de votre compte ? Vos favoris et historiques synchronisés seront fermés sur cet appareil.',
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
    final fullName = user['fullName'] ?? user['name'] ?? 'Utilisateur';
    final email = user['email'] ?? '';
    final avatarUrl = user['avatar'] ?? user['profileImage'] ?? '';
    final roles = user['roles'] as List?;
    final isAdmin = roles != null && roles.any((r) => r.toString().toUpperCase().contains('ADMIN'));
    final isCreator = user['isCreator'] == true ||
        (roles != null && roles.any((r) => r.toString().toUpperCase().contains('CREATOR'))) ||
        user['creatorProfile'] != null;

    final String? roleBadgeText = isAdmin
        ? 'ADMINISTRATEUR'
        : isCreator
            ? 'CRÉATEUR STUDIO'
            : null;

    final textPri = BkoTheme.getTextPrimary(context);
    final textSec = BkoTheme.getTextSecondary(context);
    final surfaceElevated = BkoTheme.getBgSurfaceElevated(context);
    final border = BkoTheme.getBorderSubtle(context);

    return Drawer(
      backgroundColor: BkoTheme.getBgObsidian(context),
      elevation: 0,
      child: SafeArea(
        child: Column(
          children: [
            // User Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
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
                        if (email.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: BkoTheme.fontLato(
                              fontSize: 12,
                              color: textSec,
                            ),
                          ),
                        ],
                        if (roleBadgeText != null) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: BkoTheme.goldAccent.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              roleBadgeText,
                              style: BkoTheme.fontLato(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                                color: BkoTheme.goldAccent,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Navigation Entries (Spacious, min 48px height)
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                children: [
                  _buildDrawerItem(
                    context: context,
                    icon: IconsaxPlusLinear.user,
                    label: 'Mon profil & compte',
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/profile');
                    },
                  ),

                  if (isCreator)
                    _buildDrawerItem(
                      context: context,
                      icon: IconsaxPlusLinear.microphone_2,
                      label: 'Mon studio créateur',
                      accentColor: BkoTheme.goldAccent,
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/studio');
                      },
                    ),

                  _buildDrawerItem(
                    context: context,
                    icon: IconsaxPlusLinear.setting_2,
                    label: 'Préférences d\'affichage',
                    onTap: () {
                      Navigator.pop(context);
                      _showPreferencesSheet(context, ref);
                    },
                  ),

                  _buildDrawerItem(
                    context: context,
                    icon: IconsaxPlusLinear.shield_security,
                    label: 'Sécurité et session',
                    onTap: () {
                      Navigator.pop(context);
                      _showSecuritySheet(context);
                    },
                  ),

                  _buildDrawerItem(
                    context: context,
                    icon: IconsaxPlusLinear.info_circle,
                    label: 'Aide & Support',
                    onTap: () {
                      Navigator.pop(context);
                      _showHelpSheet(context);
                    },
                  ),
                ],
              ),
            ),

            // Bottom Logout Entry
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: border)),
              ),
              child: _buildDrawerItem(
                context: context,
                icon: IconsaxPlusLinear.logout,
                label: 'Se déconnecter',
                accentColor: Theme.of(context).colorScheme.error,
                onTap: () async {
                  Navigator.pop(context);
                  await _confirmLogout(context, ref);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarInitial(String name) {
    final initial = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'U';
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
      padding: const EdgeInsets.only(bottom: 4),
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
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                Icon(icon, color: color, size: 21),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: BkoTheme.fontLato(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
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
