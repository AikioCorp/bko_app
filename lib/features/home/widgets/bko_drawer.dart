import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/bko_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../auth/auth_controller.dart';

class BkoDrawer extends ConsumerWidget {
  const BkoDrawer({super.key});

  void _showPreferencesSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final currentSetting = ref.watch(themeSettingProvider);
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Color(0xFF161616),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(top: BorderSide(color: Color(0xFF262626))),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Préférences d\'affichage',
                    style: BkoTheme.fontPoppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.grey),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildThemeOptionTile(
                ctx,
                ref,
                icon: Icons.dark_mode_rounded,
                title: 'Mode Sombre (Obsidienne)',
                setting: AppThemeSetting.dark,
                currentSetting: currentSetting,
              ),
              const SizedBox(height: 8),
              _buildThemeOptionTile(
                ctx,
                ref,
                icon: Icons.brightness_auto_rounded,
                title: 'Thème Système',
                setting: AppThemeSetting.system,
                currentSetting: currentSetting,
              ),
            ],
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
  }) {
    final isSelected = currentSetting == setting;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        ref.read(themeSettingProvider.notifier).setThemeSetting(setting);
        Navigator.pop(ctx);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF222222) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? BkoTheme.goldAccent.withValues(alpha: 0.5) : const Color(0xFF262626),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? BkoTheme.goldAccent : Colors.grey, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: BkoTheme.fontLato(
                  color: Colors.white,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_rounded, color: BkoTheme.goldAccent, size: 20),
          ],
        ),
      ),
    );
  }

  void _showSecurityDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161616),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF262626)),
        ),
        title: Text(
          'Sécurité & Appareils',
          style: BkoTheme.fontPoppins(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        content: Text(
          'Vous êtes connecté sur cet appareil mobile en session sécurisée.\n\nPour réinitialiser votre mot de passe, vous pouvez utiliser la fonction "Mot de passe oublié" ou modifier vos identifiants depuis votre profil.',
          style: BkoTheme.fontLato(fontSize: 13, color: const Color(0xFFAAAAAA), height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Fermer',
              style: BkoTheme.fontPoppins(
                fontWeight: FontWeight.w600,
                color: BkoTheme.goldAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161616),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF262626)),
        ),
        title: Text(
          'Aide & Support',
          style: BkoTheme.fontPoppins(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bamako Podcast est la plateforme de référence pour découvrir et publier des podcasts au Mali et dans toute la diaspora.',
              style: BkoTheme.fontLato(fontSize: 13, color: const Color(0xFFAAAAAA), height: 1.4),
            ),
            const SizedBox(height: 12),
            Text(
              'Contact : contact@bamakopodcast.studio\nSite web : bamakopodcast.studio',
              style: BkoTheme.fontLato(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: BkoTheme.goldAccent,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Compris',
              style: BkoTheme.fontPoppins(
                fontWeight: FontWeight.w600,
                color: BkoTheme.goldAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161616),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF262626)),
        ),
        title: Text(
          'Déconnexion',
          style: BkoTheme.fontPoppins(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        content: Text(
          'Êtes-vous sûr de vouloir vous déconnecter de votre compte ? Vos favoris et historiques synchronisés seront fermés sur cet appareil.',
          style: BkoTheme.fontLato(fontSize: 13, color: const Color(0xFFAAAAAA), height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Annuler',
              style: BkoTheme.fontPoppins(color: Colors.grey, fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(
              'Se déconnecter',
              style: BkoTheme.fontPoppins(fontWeight: FontWeight.w700),
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
    final role = user['role']?.toString().toUpperCase() ?? 'USER';
    final isCreator = user['isCreator'] == true || role == 'CREATOR' || role == 'ADMIN';

    final textPri = BkoTheme.getTextPrimary(context);
    final textSec = BkoTheme.getTextSecondary(context);

    return Drawer(
      backgroundColor: const Color(0xFF0E0E0E),
      elevation: 0,
      child: SafeArea(
        child: Column(
          children: [
            // User Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFF1E1E1E))),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF1E1E1E),
                      border: Border.all(color: const Color(0xFF2E2E2E), width: 1.5),
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
                          style: BkoTheme.fontPoppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
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
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isCreator
                                ? BkoTheme.goldAccent.withValues(alpha: 0.15)
                                : const Color(0xFF222222),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isCreator ? 'Créateur Studio' : 'Auditeur',
                            style: BkoTheme.fontPoppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isCreator ? BkoTheme.goldAccent : Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Navigation Entries
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                children: [
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.person_outline_rounded,
                    label: 'Mon compte',
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/profile');
                    },
                  ),

                  if (isCreator)
                    _buildDrawerItem(
                      context: context,
                      icon: Icons.mic_none_rounded,
                      label: 'Mon studio',
                      accentColor: BkoTheme.goldAccent,
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/studio');
                      },
                    ),

                  _buildDrawerItem(
                    context: context,
                    icon: Icons.tune_rounded,
                    label: 'Préférences',
                    onTap: () {
                      Navigator.pop(context);
                      _showPreferencesSheet(context, ref);
                    },
                  ),

                  _buildDrawerItem(
                    context: context,
                    icon: Icons.shield_outlined,
                    label: 'Sécurité et appareils',
                    onTap: () {
                      Navigator.pop(context);
                      _showSecurityDialog(context, ref);
                    },
                  ),

                  _buildDrawerItem(
                    context: context,
                    icon: Icons.help_outline_rounded,
                    label: 'Aide & Support',
                    onTap: () {
                      Navigator.pop(context);
                      _showHelpDialog(context);
                    },
                  ),
                ],
              ),
            ),

            // Bottom Logout Entry
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFF1E1E1E))),
              ),
              child: _buildDrawerItem(
                context: context,
                icon: Icons.logout_rounded,
                label: 'Déconnexion',
                accentColor: Colors.red.shade400,
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
        style: BkoTheme.fontPoppins(
          fontSize: 20,
          fontWeight: FontWeight.w700,
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
    final color = accentColor ?? Colors.white;
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Icon(icon, color: color, size: 22),
        title: Text(
          label,
          style: BkoTheme.fontPoppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        onTap: onTap,
        dense: true,
      ),
    );
  }
}
