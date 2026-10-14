import '../../core/widgets/app_header_actions.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/network/bko_api.dart';
import '../../core/theme/bko_theme.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/widgets/bko_bounceable.dart';
import '../../core/widgets/bko_haptics.dart';
import '../auth/auth_controller.dart';

/// Écran complet de gestion de la confidentialité, des données personnelles et de la suppression du compte.
/// - Explications claires et transparentes
/// - Effacement de l'historique d'écoute (DELETE /me/history)
/// - Export de données RGPD / conformité (POST /me/export)
/// - Bloc distinct de suppression irréversible du compte avec vérification (DELETE /me)
class PrivacyDataScreen extends ConsumerStatefulWidget {
  const PrivacyDataScreen({super.key});

  @override
  ConsumerState<PrivacyDataScreen> createState() => _PrivacyDataScreenState();
}

class _PrivacyDataScreenState extends ConsumerState<PrivacyDataScreen> {
  bool _isClearingHistory = false;
  bool _isExporting = false;
  bool _isDeleting = false;

  Future<void> _handleClearHistory() async {
    final token = ref.read(authProvider).token;
    if (token == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BkoTheme.getBgSurface(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Effacer tout l\'historique d\'écoute ?',
          style: BkoTheme.fontLato(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Tous vos épisodes commencés, positions de reprise et statistiques d\'écoute seront réinitialisés.',
          style: BkoTheme.fontLato(fontSize: 13, color: BkoTheme.getTextSecondary(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('Effacer'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isClearingHistory = true);
      try {
        await BkoApi.delete('/me/history', token: token);
        if (mounted) {
          BkoHaptics.success();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Historique d\'écoute intégralement effacé.'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: BkoTheme.goldAccent,
            ),
          );
        }
      } catch (e) {
        BkoHaptics.error();
      } finally {
        if (mounted) setState(() => _isClearingHistory = false);
      }
    }
  }

  Future<void> _handleExportData() async {
    final token = ref.read(authProvider).token;
    if (token == null) return;

    setState(() => _isExporting = true);
    try {
      final res = await BkoApi.post('/me/export', {}, token: token);
      final jsonStr = const JsonEncoder.withIndent('  ').convert(res);

      if (mounted) {
        BkoHaptics.success();
        // ignore: deprecated_member_use
        await Share.share(
          jsonStr,
          subject: 'Export de mes données personnelles - Bamako Podcast',
        );
      }
    } catch (e) {
      if (mounted) {
        BkoHaptics.error();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'export : $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _handleDeleteAccount() async {
    final user = ref.read(authProvider).user;
    final token = ref.read(authProvider).token;
    if (token == null) return;

    final roles = (user?['roles'] as List?)?.map((e) => '$e').toList() ?? [];
    final isCreator = roles.contains('CREATOR') || roles.contains('ADMIN');

    final passwordCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BkoTheme.getBgSurface(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(IconsaxPlusLinear.warning_2, color: Theme.of(context).colorScheme.error, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Supprimer définitivement mon compte',
                style: BkoTheme.fontLato(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cette action est irréversible. Toutes vos données (playlists, favoris, historique, abonnements) seront supprimées.',
              style: BkoTheme.fontLato(fontSize: 13, color: BkoTheme.getTextSecondary(context), height: 1.4),
            ),
            if (isCreator) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Text(
                  'Attention : En tant que créateur, la suppression du compte archivera vos émissions et révoquera vos accès studio.',
                  style: BkoTheme.fontLato(fontSize: 11.5, color: Colors.red, fontWeight: FontWeight.w600),
                ),
              ),
            ],
            const SizedBox(height: 14),
            Text(
              'Confirmez votre mot de passe pour valider :',
              style: BkoTheme.fontLato(fontSize: 12, fontWeight: FontWeight.w600, color: BkoTheme.getTextPrimary(context)),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: passwordCtrl,
              obscureText: true,
              style: BkoTheme.fontLato(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Mot de passe...',
                filled: true,
                fillColor: BkoTheme.getBgSurfaceElevated(context),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('Supprimer mon compte'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isDeleting = true);
      try {
        await BkoApi.delete(
          '/me',
          body: {'passwordConfirm': passwordCtrl.text},
          token: token,
        );
        await ref.read(authProvider.notifier).logout();
        if (mounted) {
          BkoHaptics.success();
          context.go('/home');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Votre compte a été supprimé.'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.black,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          BkoHaptics.error();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Échec de la suppression : $e'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isDeleting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BkoTheme.getBgObsidian(context),
      appBar: AppBar(
        actions: const [AppHeaderActions()],
        leading: const AppBackButton(),
        title: Text(
          'Confidentialité & données',
          style: BkoTheme.fontLato(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: BkoTheme.getTextPrimary(context),
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // Carte Explication Personnalisation
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: BkoTheme.getBgSurface(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: BkoTheme.getBorderSubtle(context)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: BkoTheme.goldAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                        child: Icon(
                          IconsaxPlusLinear.lock,
                          color: BkoTheme.goldAccent,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Vos données vous appartiennent',
                        style: BkoTheme.fontLato(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: BkoTheme.getTextPrimary(context),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Bamako Podcast utilise uniquement vos préférences de langues et votre historique pour vous recommander des contenus pertinents. Nous ne vendons ni ne partageons vos données avec des tiers publicitaires.',
                  style: BkoTheme.fontLato(
                    fontSize: 12.5,
                    color: BkoTheme.getTextSecondary(context),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Gestion des données
          Text(
            'GESTION DE L\'HISTORIQUE & EXPORT',
            style: BkoTheme.fontLato(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
              color: BkoTheme.getTextMuted(context),
            ),
          ),
          const SizedBox(height: 10),

          Container(
            decoration: BoxDecoration(
              color: BkoTheme.getBgSurface(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: BkoTheme.getBorderSubtle(context)),
            ),
            child: Column(
              children: [
                _buildActionTile(
                  context: context,
                  title: 'Effacer l\'historique d\'écoute',
                  subtitle: 'Réinitialise les positions de lecture et les épisodes récents.',
                  icon: IconsaxPlusLinear.broom,
                  onTap: _isClearingHistory ? null : _handleClearHistory,
                  isLoading: _isClearingHistory,
                  isFirst: true,
                ),
                Divider(height: 1, thickness: 1, color: BkoTheme.getBorderSubtle(context)),
                _buildActionTile(
                  context: context,
                  title: 'Exporter mes données (JSON)',
                  subtitle: 'Téléchargez l\'intégralité de votre profil, favoris et playlists.',
                  icon: IconsaxPlusLinear.export_1,
                  onTap: _isExporting ? null : _handleExportData,
                  isLoading: _isExporting,
                  isLast: true,
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // Bloc distinct de suppression de compte
          Text(
            'ZONE SENSIBLE',
            style: BkoTheme.fontLato(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
          const SizedBox(height: 10),

          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: BkoTheme.getBgSurface(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context).colorScheme.error.withValues(alpha: 0.4),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Supprimer mon compte Bamako Podcast',
                  style: BkoTheme.fontLato(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Cette suppression est immédiate et irréversible. Elle supprime votre profil, vos playlists, vos avis et vos accès créateur associés.',
                  style: BkoTheme.fontLato(
                    fontSize: 12,
                    color: BkoTheme.getTextSecondary(context),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                BkoBounceable(
                  onTap: _isDeleting ? null : _handleDeleteAccount,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Theme.of(context).colorScheme.error),
                    ),
                    child: Center(
                      child: _isDeleting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              'Supprimer mon compte définitivement',
                              style: BkoTheme.fontLato(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback? onTap,
    required bool isLoading,
    bool isFirst = false,
    bool isLast = false,
  }) {
    return BkoBounceable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.vertical(
            top: isFirst ? const Radius.circular(16) : Radius.zero,
            bottom: isLast ? const Radius.circular(16) : Radius.zero,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: BkoTheme.getTextPrimary(context)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: BkoTheme.fontLato(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: BkoTheme.getTextPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: BkoTheme.fontLato(
                      fontSize: 11.5,
                      color: BkoTheme.getTextSecondary(context),
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (isLoading)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(
                IconsaxPlusLinear.arrow_right_3,
                size: 16,
                color: BkoTheme.getTextMuted(context),
              ),
          ],
        ),
      ),
    );
  }
}
