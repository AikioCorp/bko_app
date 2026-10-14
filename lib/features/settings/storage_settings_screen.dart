import '../../core/widgets/app_header_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../../core/theme/bko_theme.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/widgets/bko_bounceable.dart';
import '../../core/widgets/bko_haptics.dart';
import '../downloads/download_manager.dart';

/// Écran des paramètres de stockage et des téléchargements hors-ligne.
/// Affiche la taille réelle occupée sur l'appareil, le nombre d'épisodes,
/// les réglages Wi-Fi uniquement, la suppression automatique après écoute,
/// et permet d'accéder à la liste des fichiers ou de libérer de l'espace.
class StorageSettingsScreen extends ConsumerStatefulWidget {
  const StorageSettingsScreen({super.key});

  @override
  ConsumerState<StorageSettingsScreen> createState() => _StorageSettingsScreenState();
}

class _StorageSettingsScreenState extends ConsumerState<StorageSettingsScreen> {
  bool _isCleaning = false;

  Future<void> _handleDeleteCompleted() async {
    final notifier = ref.read(downloadProvider.notifier);
    final confirmed = await _showConfirmDialog(
      title: 'Supprimer les épisodes terminés ?',
      message:
          'Seules les copies locales des épisodes que vous avez déjà écoutés seront supprimées. Vos favoris et playlists restent intacts.',
      confirmLabel: 'Supprimer',
      isDestructive: false,
    );

    if (confirmed == true && mounted) {
      setState(() => _isCleaning = true);
      await notifier.deleteCompletedDownloads();
      if (mounted) {
        setState(() => _isCleaning = false);
        BkoHaptics.success();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Épisodes terminés retirés de la mémoire locale.'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: BkoTheme.goldAccent,
          ),
        );
      }
    }
  }

  Future<void> _handleClearAll() async {
    final notifier = ref.read(downloadProvider.notifier);
    final confirmed = await _showConfirmDialog(
      title: 'Supprimer tous les fichiers locaux ?',
      message:
          'Toutes les copies hors-ligne sur cet appareil seront effacées pour libérer de l\'espace. Cela ne supprime aucun compte, favori ou historique.',
      confirmLabel: 'Tout effacer',
      isDestructive: true,
    );

    if (confirmed == true && mounted) {
      setState(() => _isCleaning = true);
      await notifier.clearAllDownloads();
      if (mounted) {
        setState(() => _isCleaning = false);
        BkoHaptics.success();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Toutes les copies locales ont été supprimées.'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: BkoTheme.goldAccent,
          ),
        );
      }
    }
  }

  Future<bool?> _showConfirmDialog({
    required String title,
    required String message,
    required String confirmLabel,
    required bool isDestructive,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BkoTheme.getBgSurface(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: BkoTheme.getBorderSubtle(context)),
        ),
        title: Text(
          title,
          style: BkoTheme.fontLato(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: BkoTheme.getTextPrimary(context),
          ),
        ),
        content: Text(
          message,
          style: BkoTheme.fontLato(
            fontSize: 13,
            color: BkoTheme.getTextSecondary(context),
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Annuler',
              style: BkoTheme.fontLato(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: BkoTheme.getTextSecondary(context),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDestructive
                  ? Theme.of(context).colorScheme.error
                  : BkoTheme.goldAccent,
              foregroundColor: isDestructive ? Colors.white : Colors.black,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              confirmLabel,
              style: BkoTheme.fontLato(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(downloadProvider);
    final notifier = ref.read(downloadProvider.notifier);
    final completedTasks = tasks.where((t) => t.status == DownloadStatus.completed).toList();
    final settings = notifier.smartSettings;

    return Scaffold(
      backgroundColor: BkoTheme.getBgObsidian(context),
      appBar: AppBar(
        actions: const [AppHeaderActions()],
        leading: const AppBackButton(),
        title: Text(
          'Téléchargements & stockage',
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
          // Carte d'espace occupé
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: BkoTheme.getBgSurface(context),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: BkoTheme.getBorderSubtle(context)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: BkoTheme.goldAccent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Center(
                            child: Icon(
                              IconsaxPlusLinear.folder_cloud,
                              color: BkoTheme.goldAccent,
                              size: 22,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Espace utilisé',
                              style: BkoTheme.fontLato(
                                fontSize: 11.5,
                                color: BkoTheme.getTextSecondary(context),
                              ),
                            ),
                            Text(
                              notifier.formattedTotalStorage,
                              style: BkoTheme.fontLato(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: BkoTheme.getTextPrimary(context),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: BkoTheme.getBgSurfaceElevated(context),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: BkoTheme.getBorderSubtle(context)),
                      ),
                      child: Text(
                        '${completedTasks.length} épisode${completedTasks.length > 1 ? 's' : ''}',
                        style: BkoTheme.fontLato(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: BkoTheme.goldAccent,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                BkoBounceable(
                  onTap: () {
                    BkoHaptics.light();
                    context.push('/downloads');
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: BkoTheme.getBgSurfaceElevated(context),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: BkoTheme.getBorderSubtle(context)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          IconsaxPlusLinear.document_download,
                          size: 18,
                          color: BkoTheme.getTextPrimary(context),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Gérer la liste des fichiers hors-ligne',
                          style: BkoTheme.fontLato(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: BkoTheme.getTextPrimary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Options de réseau et gestion
          Text(
            'RÉGLAGES DES TÉLÉCHARGEMENTS',
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
                _buildSwitchTile(
                  context: context,
                  title: 'Télécharger via Wi-Fi uniquement',
                  subtitle: 'Évite la consommation de votre forfait données mobiles.',
                  icon: IconsaxPlusLinear.wifi,
                  value: settings.wifiOnly,
                  onChanged: (val) {
                    BkoHaptics.selection();
                    notifier.updateSmartSettings(wifiOnly: val);
                    setState(() {});
                  },
                  isFirst: true,
                ),
                Divider(height: 1, thickness: 1, color: BkoTheme.getBorderSubtle(context)),
                _buildSwitchTile(
                  context: context,
                  title: 'Téléchargements intelligents',
                  subtitle: 'Télécharge automatiquement le prochain épisode de votre série en cours.',
                  icon: IconsaxPlusLinear.magicpen,
                  value: settings.smartDownloadsEnabled,
                  onChanged: (val) {
                    BkoHaptics.selection();
                    notifier.updateSmartSettings(smartDownloadsEnabled: val);
                    setState(() {});
                  },
                ),
                Divider(height: 1, thickness: 1, color: BkoTheme.getBorderSubtle(context)),
                _buildSwitchTile(
                  context: context,
                  title: 'Supprimer après écoute',
                  subtitle: 'Efface la copie locale dès que l\'épisode est écouté à plus de 90%.',
                  icon: IconsaxPlusLinear.trash,
                  value: settings.autoDeleteCompleted,
                  onChanged: (val) {
                    BkoHaptics.selection();
                    notifier.updateSmartSettings(autoDeleteCompleted: val);
                    setState(() {});
                  },
                  isLast: true,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Actions de nettoyage
          Text(
            'LIBÉRATION D\'ESPACE',
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
                  title: 'Supprimer les épisodes terminés',
                  subtitle: 'Conserve les épisodes non terminés et supprime les copies déjà écoutées.',
                  icon: IconsaxPlusLinear.broom,
                  onTap: _isCleaning ? null : _handleDeleteCompleted,
                  isDestructive: false,
                  isFirst: true,
                ),
                Divider(height: 1, thickness: 1, color: BkoTheme.getBorderSubtle(context)),
                _buildActionTile(
                  context: context,
                  title: 'Supprimer toutes les copies locales',
                  subtitle: 'Libère immédiatement l\'ensemble du stockage pris par l\'application.',
                  icon: IconsaxPlusLinear.trash,
                  onTap: _isCleaning ? null : _handleClearAll,
                  isDestructive: true,
                  isLast: true,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Mentions légales & limitations
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: BkoTheme.getBgSurfaceElevated(context),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: BkoTheme.getBorderSubtle(context)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  IconsaxPlusLinear.shield_tick,
                  size: 20,
                  color: BkoTheme.getTextSecondary(context),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Les flux vidéo tiers (dont YouTube) ne peuvent être téléchargés hors-ligne en raison des conditions générales de diffusion. Seuls les flux natifs audios hébergés sont disponibles au téléchargement.',
                    style: BkoTheme.fontLato(
                      fontSize: 12,
                      color: BkoTheme.getTextSecondary(context),
                      height: 1.4,
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

  Widget _buildSwitchTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool isFirst = false,
    bool isLast = false,
  }) {
    return Container(
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
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeThumbColor: BkoTheme.goldAccent,
            activeTrackColor: BkoTheme.goldAccent.withValues(alpha: 0.3),
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
    required bool isDestructive,
    bool isFirst = false,
    bool isLast = false,
  }) {
    final color = isDestructive
        ? Theme.of(context).colorScheme.error
        : BkoTheme.getTextPrimary(context);

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
            Icon(icon, size: 22, color: color),
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
                      color: color,
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
