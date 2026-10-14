import '../../core/widgets/app_header_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../../core/theme/bko_theme.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/widgets/bko_bounceable.dart';
import '../../core/widgets/bko_haptics.dart';

/// Écran des paramètres d'apparence selon les règles strictes de design mobile :
/// - Thèmes : Système, Clair, Sombre, Noir AMOLED
/// - Aperçu visuel en direct du thème choisi
/// - Zéro dégradé, zéro ombre, surfaces nettes
/// - Enregistrement immédiat et persistant
class AppearanceSettingsScreen extends ConsumerWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentSetting = ref.watch(themeSettingProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: BkoTheme.getBgObsidian(context),
      appBar: AppBar(
        actions: const [AppHeaderActions()],
        leading: const AppBackButton(),
        title: Text(
          'Apparence',
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
          // Section Titre
          Text(
            'THÈME DE L\'APPLICATION',
            style: BkoTheme.fontLato(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
              color: BkoTheme.getTextMuted(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Choisissez le mode d\'affichage qui correspond à vos habitudes d\'écoute.',
            style: BkoTheme.fontLato(
              fontSize: 13,
              color: BkoTheme.getTextSecondary(context),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),

          // Aperçu visuel
          _buildLivePreview(context, currentSetting, isDark),
          const SizedBox(height: 24),

          // Options de sélection
          Container(
            decoration: BoxDecoration(
              color: BkoTheme.getBgSurface(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: BkoTheme.getBorderSubtle(context)),
            ),
            child: Column(
              children: [
                _buildThemeTile(
                  context: context,
                  ref: ref,
                  setting: AppThemeSetting.system,
                  current: currentSetting,
                  title: 'Système',
                  subtitle: 'S\'adapte automatiquement aux réglages de votre appareil.',
                  icon: IconsaxPlusLinear.mobile,
                  isFirst: true,
                ),
                Divider(height: 1, thickness: 1, color: BkoTheme.getBorderSubtle(context)),
                _buildThemeTile(
                  context: context,
                  ref: ref,
                  setting: AppThemeSetting.light,
                  current: currentSetting,
                  title: 'Clair',
                  subtitle: 'Fond blanc épuré avec typographie contrastée.',
                  icon: IconsaxPlusLinear.sun_1,
                ),
                Divider(height: 1, thickness: 1, color: BkoTheme.getBorderSubtle(context)),
                _buildThemeTile(
                  context: context,
                  ref: ref,
                  setting: AppThemeSetting.dark,
                  current: currentSetting,
                  title: 'Sombre',
                  subtitle: 'Gris obsidienne profond, idéal pour une écoute nocturne.',
                  icon: IconsaxPlusLinear.moon,
                ),
                Divider(height: 1, thickness: 1, color: BkoTheme.getBorderSubtle(context)),
                _buildThemeTile(
                  context: context,
                  ref: ref,
                  setting: AppThemeSetting.amoled,
                  current: currentSetting,
                  title: 'Noir AMOLED',
                  subtitle: 'Noir absolu (0% d\'émission sur dalles OLED), économie maximale de batterie.',
                  icon: IconsaxPlusLinear.lamp_charge,
                  isLast: true,
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // Note d'accessibilité système
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: BkoTheme.getBgSurfaceElevated(context),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: BkoTheme.getBorderSubtle(context)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  IconsaxPlusLinear.info_circle,
                  size: 20,
                  color: BkoTheme.goldAccent,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'L\'application respecte automatiquement la taille de police agrandie et les préférences d\'animation réduite définies dans les paramètres de votre téléphone.',
                    style: BkoTheme.fontLato(
                      fontSize: 12.5,
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

  Widget _buildLivePreview(
    BuildContext context,
    AppThemeSetting setting,
    bool isDarkEffective,
  ) {
    // Calcul de l'aperçu
    final Color previewBg = switch (setting) {
      AppThemeSetting.system => isDarkEffective ? const Color(0xFF0B0B0B) : const Color(0xFFF8F9FA),
      AppThemeSetting.light => const Color(0xFFF8F9FA),
      AppThemeSetting.dark => const Color(0xFF0B0B0B),
      AppThemeSetting.amoled => const Color(0xFF000000),
    };

    final Color previewCard = switch (setting) {
      AppThemeSetting.system => isDarkEffective ? const Color(0xFF121212) : const Color(0xFFFFFFFF),
      AppThemeSetting.light => const Color(0xFFFFFFFF),
      AppThemeSetting.dark => const Color(0xFF121212),
      AppThemeSetting.amoled => const Color(0xFF0A0A0A),
    };

    final Color previewText = switch (setting) {
      AppThemeSetting.system => isDarkEffective ? Colors.white : const Color(0xFF0F172A),
      AppThemeSetting.light => const Color(0xFF0F172A),
      AppThemeSetting.dark => Colors.white,
      AppThemeSetting.amoled => Colors.white,
    };

    final Color previewSub = switch (setting) {
      AppThemeSetting.system => isDarkEffective ? Colors.white60 : const Color(0xFF64748B),
      AppThemeSetting.light => const Color(0xFF64748B),
      AppThemeSetting.dark => Colors.white60,
      AppThemeSetting.amoled => Colors.white54,
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: previewBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BkoTheme.getBorderSubtle(context), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Aperçu du rendu',
                style: BkoTheme.fontLato(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: previewSub,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: BkoTheme.goldAccent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  setting.name.toUpperCase(),
                  style: BkoTheme.fontLato(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: previewCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: setting == AppThemeSetting.light
                    ? const Color(0xFFE2E8F0)
                    : const Color(0xFF262626),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: BkoTheme.goldAccent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: Icon(
                      IconsaxPlusLinear.music,
                      color: BkoTheme.goldAccent,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bamako Podcast Matin',
                        style: BkoTheme.fontLato(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: previewText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Épisode en cours d\'écoute • 42 min',
                        style: BkoTheme.fontLato(
                          fontSize: 11,
                          color: previewSub,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeTile({
    required BuildContext context,
    required WidgetRef ref,
    required AppThemeSetting setting,
    required AppThemeSetting current,
    required String title,
    required String subtitle,
    required IconData icon,
    bool isFirst = false,
    bool isLast = false,
  }) {
    final isSelected = current == setting;

    return BkoBounceable(
      onTap: () {
        BkoHaptics.selection();
        ref.read(themeSettingProvider.notifier).setThemeSetting(setting);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? BkoTheme.goldAccent.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.vertical(
            top: isFirst ? const Radius.circular(16) : Radius.zero,
            bottom: isLast ? const Radius.circular(16) : Radius.zero,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSelected
                    ? BkoTheme.goldAccent
                    : BkoTheme.getBgSurfaceElevated(context),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Icon(
                  icon,
                  size: 20,
                  color: isSelected ? Colors.black : BkoTheme.getTextPrimary(context),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: BkoTheme.fontLato(
                      fontSize: 14.5,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
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
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? BkoTheme.goldAccent : BkoTheme.getBorderStrong(context),
                  width: 2,
                ),
                color: isSelected ? BkoTheme.goldAccent : Colors.transparent,
              ),
              child: isSelected
                  ? const Center(
                      child: Icon(
                        IconsaxPlusLinear.tick_circle,
                        size: 14,
                        color: Colors.black,
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
