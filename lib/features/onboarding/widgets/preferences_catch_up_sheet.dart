import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import '../../../core/network/bko_api.dart';
import '../../../core/routing/auth_navigation.dart';
import '../../../core/theme/bko_theme.dart';
import '../../../core/widgets/bko_bounceable.dart';
import '../../../core/widgets/bko_haptics.dart';
import '../../auth/auth_controller.dart';
import '../../shell/shell_providers.dart';

/// Feuille du bas (Bottom Sheet) pour inviter les comptes existants
/// à personnaliser leurs écoutes (langues et centres d'intérêt).
class PreferencesCatchUpSheet extends ConsumerStatefulWidget {
  const PreferencesCatchUpSheet({super.key});

  static bool _isShowing = false;

  /// Vérifie l'éligibilité et affiche la feuille du bas si toutes les conditions sont réunies :
  /// 1. Utilisateur connecté
  /// 2. Compte non suspendu
  /// 3. Pas d'écoute audio active
  /// 4. Pas de lecteur plein écran ouvert
  /// 5. Profil requiert le rattrapage (onboardingState == 'NOT_PROMPTED')
  static Future<void> checkAndShow(BuildContext context, WidgetRef ref) async {
    if (_isShowing) return;

    final auth = ref.read(authProvider);
    if (!auth.isAuthenticated || auth.user == null) return;

    final user = auth.user!;
    if (user['isSuspended'] == true) return;

    // Ne jamais interrompre une lecture audio active ni un lecteur plein écran
    final activeEp = ref.read(activeEpisodeProvider);
    if (activeEp.isPlaybackActive) return;

    final isFullPlayerOpen = ref.read(isFullPlayerOpenProvider);
    if (isFullPlayerOpen) return;

    if (!shouldShowCatchUpInvitation(user)) return;

    _isShowing = true;

    // 1. Notifier immédiatement le serveur que la modal est présentée (PROMPTED)
    if (auth.token != null && auth.token!.isNotEmpty) {
      try {
        await BkoApi.post('/recommendations/onboarding/state', {
          'state': 'PROMPTED',
        }, token: auth.token);
      } catch (_) {}
    }

    if (!context.mounted) {
      _isShowing = false;
      return;
    }

    try {
      final result = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        enableDrag: true,
        builder: (ctx) => const PreferencesCatchUpSheet(),
      );

      // Si l'utilisateur n'a pas validé (fermé via glissement, tap extérieur ou bouton 'Plus tard')
      if (result != true && context.mounted) {
        final currentAuth = ref.read(authProvider);
        if (currentAuth.token != null && currentAuth.token!.isNotEmpty) {
          try {
            await BkoApi.post('/recommendations/onboarding/state', {
              'state': 'DISMISSED',
            }, token: currentAuth.token);
          } catch (_) {}
          await ref.read(authProvider.notifier).fetchMe();
        }
      }
    } finally {
      _isShowing = false;
    }
  }

  @override
  ConsumerState<PreferencesCatchUpSheet> createState() =>
      _PreferencesCatchUpSheetState();
}

class _PreferencesCatchUpSheetState extends ConsumerState<PreferencesCatchUpSheet> {
  bool _isDismissing = false;

  Future<void> _handleDismiss() async {
    if (_isDismissing) return;
    setState(() => _isDismissing = true);
    BkoHaptics.light();
    Navigator.of(context).pop(false);
  }

  void _handleAccept() {
    BkoHaptics.medium();
    Navigator.of(context).pop(true);
    context.push('/taste-onboarding');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF121212),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: Color(0xFF262626), width: 1),
          left: BorderSide(color: Color(0xFF262626), width: 1),
          right: BorderSide(color: Color(0xFF262626), width: 1),
        ),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 14,
        bottom: MediaQuery.of(context).padding.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF333333),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 22),

          // Central Icon
          Center(
            child: Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: const Color(0xFF1E1A11),
                shape: BoxShape.circle,
                border: Border.all(
                  color: BkoTheme.goldAccent.withValues(alpha: 0.35),
                  width: 1,
                ),
              ),
              child: const Icon(
                IconsaxPlusBold.headphone,
                color: BkoTheme.goldAccent,
                size: 28,
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Title
          Text(
            'Des écoutes qui vous ressemblent',
            textAlign: TextAlign.center,
            style: BkoTheme.fontPoppins(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 10),

          // Body text
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              'Choisissez vos langues d’écoute et vos centres d’intérêt pour que Bamako Podcast adapte votre accueil et vos suggestions.',
              textAlign: TextAlign.center,
              style: BkoTheme.fontPoppins(
                fontSize: 13.5,
                fontWeight: FontWeight.w400,
                color: const Color(0xFFB8B8B8),
                height: 1.45,
              ),
            ),
          ),
          const SizedBox(height: 26),

          // Primary button: "Personnaliser mes écoutes"
          SizedBox(
            height: 50,
            child: BkoBounceable(
              onTap: _handleAccept,
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: BkoTheme.goldAccent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      IconsaxPlusBold.setting_4,
                      size: 18,
                      color: Colors.black,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Personnaliser mes écoutes',
                      style: BkoTheme.fontPoppins(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Secondary button: "Plus tard"
          SizedBox(
            height: 46,
            child: BkoBounceable(
              onTap: _handleDismiss,
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF262626)),
                ),
                child: Text(
                  'Plus tard',
                  style: BkoTheme.fontPoppins(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF888888),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
