import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/bko_theme.dart';
import '../../auth/auth_controller.dart';
import '../../notifications/notification_providers.dart';
import '../home_providers.dart';

class BkoAppHeader extends ConsumerWidget implements PreferredSizeWidget {
  final bool? isCollapsed;
  const BkoAppHeader({super.key, this.isCollapsed});

  @override
  Size get preferredSize => const Size.fromHeight(116);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool collapsed = (isCollapsed ?? ref.watch(homeHeaderCollapsedProvider)) == true;
    final auth = ref.watch(authProvider);
    final unreadCount = ref.watch(unreadNotificationsProvider);

    final textPri = BkoTheme.getTextPrimary(context);
    final textSec = BkoTheme.getTextSecondary(context);
    final borderSub = BkoTheme.getBorderSubtle(context);

    const animDuration = Duration(milliseconds: 280);
    const appleCurve = Cubic(0.2, 0.9, 0.2, 1.0);

    final Color normalBg = BkoTheme.getBgObsidian(context);
    // When collapsed: elevated sleek solid dark surface (#18181C)
    const Color collapsedBg = Color(0xFF18181C);
    final Color currentBg = collapsed ? collapsedBg : normalBg;

    final Color bottomBorderColor =
        collapsed ? const Color(0xFF28282D) : Colors.transparent;

    return AnimatedContainer(
      duration: animDuration,
      curve: appleCurve,
      decoration: BoxDecoration(
        color: currentBg,
        border: Border(
          bottom: BorderSide(
            color: bottomBorderColor,
            width: 1.0,
          ),
        ),
        boxShadow: collapsed
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ]
            : const [],
      ),
      child: SafeArea(
        bottom: false,
        child: AnimatedContainer(
          duration: animDuration,
          curve: appleCurve,
          padding: EdgeInsets.fromLTRB(16, 4, 16, collapsed ? 6 : 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // -----------------------------------------------------------------
              // 1. TOP BAR ROW
              // -----------------------------------------------------------------
              SizedBox(
                height: 48,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Hamburger Menu (visible only when authenticated)
                    if (auth.isAuthenticated) ...[
                      Semantics(
                        label: 'Ouvrir le menu principal',
                        button: true,
                        child: SizedBox(
                          width: 48,
                          height: 48,
                          child: IconButton(
                            icon: const Icon(Icons.menu_rounded, size: 24, color: Colors.white),
                            tooltip: 'Menu principal',
                            padding: EdgeInsets.zero,
                            onPressed: () {
                              Scaffold.of(context).openDrawer();
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],

                    // Bamako Podcast Logo & Branding
                    Semantics(
                      label: 'Accueil Bamako Podcast',
                      button: true,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          ref.read(homeHeaderCollapsedProvider.notifier).state = false;
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 1. Logo box (always visible, accent border when collapsed)
                            AnimatedContainer(
                              duration: animDuration,
                              curve: appleCurve,
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: collapsed
                                    ? const Color(0xFF1E1E24)
                                    : const Color(0xFF141414),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: collapsed
                                      ? BkoTheme.goldAccent.withValues(alpha: 0.65)
                                      : borderSub,
                                  width: 1,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(9),
                                child: Image.asset(
                                  'assets/brand/app_icon.png',
                                  width: 38,
                                  height: 38,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) => const Icon(
                                    Icons.mic_rounded,
                                    color: BkoTheme.goldAccent,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),

                            // 2. Title text "Bamako Podcast" (collapses smoothly on scroll down)
                            ClipRect(
                              child: AnimatedSize(
                                duration: animDuration,
                                curve: appleCurve,
                                alignment: Alignment.centerLeft,
                                child: SizedBox(
                                  width: collapsed ? 0 : null,
                                  child: AnimatedOpacity(
                                    duration: const Duration(milliseconds: 180),
                                    curve: Curves.easeOut,
                                    opacity: collapsed ? 0.0 : 1.0,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const SizedBox(width: 10),
                                        Text(
                                          'Bamako Podcast',
                                          maxLines: 1,
                                          overflow: TextOverflow.clip,
                                          softWrap: false,
                                          style: BkoTheme.fontPoppins(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                            letterSpacing: -0.2,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const Spacer(),

                    // Quick Search Button (smoothly slides and fades in when collapsed)
                    ClipRect(
                      child: AnimatedSize(
                        duration: animDuration,
                        curve: appleCurve,
                        alignment: Alignment.centerRight,
                        child: SizedBox(
                          width: collapsed ? 44 : 0,
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOut,
                            opacity: collapsed ? 1.0 : 0.0,
                            child: Semantics(
                              label: 'Rechercher',
                              button: true,
                              child: SizedBox(
                                width: 44,
                                height: 48,
                                child: IconButton(
                                  icon: const Icon(
                                    CupertinoIcons.search,
                                    size: 22,
                                    color: BkoTheme.goldAccent,
                                  ),
                                  tooltip: 'Rechercher',
                                  padding: EdgeInsets.zero,
                                  onPressed: () => context.go('/explore'),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Downloads Button (Left of Notifications)
                    Semantics(
                      label: 'Téléchargements hors connexion',
                      button: true,
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: IconButton(
                          icon: const Icon(
                            Icons.download_for_offline_outlined,
                            size: 24,
                            color: Colors.white,
                          ),
                          tooltip: 'Téléchargements',
                          padding: EdgeInsets.zero,
                          onPressed: () => context.push('/downloads'),
                        ),
                      ),
                    ),

                    // Notifications Button
                    Semantics(
                      label: 'Notifications',
                      button: true,
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.notifications_none_rounded,
                                size: 24,
                                color: Colors.white,
                              ),
                              tooltip: 'Notifications',
                              padding: EdgeInsets.zero,
                              onPressed: () {
                                if (!auth.isAuthenticated) {
                                  context.push('/login');
                                } else {
                                  context.push('/notifications');
                                }
                              },
                            ),
                            // Unread notification badge dot
                            if (unreadCount > 0)
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  width: 9,
                                  height: 9,
                                  decoration: const BoxDecoration(
                                    color: BkoTheme.goldAccent,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // -----------------------------------------------------------------
              // 2. APPLE-STYLE PREMIUM SEARCH BUTTON (Collapses on scroll down)
              // -----------------------------------------------------------------
              ClipRect(
                child: AnimatedSize(
                  duration: animDuration,
                  curve: appleCurve,
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    height: collapsed ? 0 : null,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      opacity: collapsed ? 0.0 : 1.0,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 8),
                          Semantics(
                            label: 'Rechercher des podcasts, épisodes et thèmes',
                            button: true,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => context.go('/explore'),
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  height: 44,
                                  padding: const EdgeInsets.symmetric(horizontal: 14),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF161618),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: const Color(0xFF28282B),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        CupertinoIcons.search,
                                        color: BkoTheme.goldAccent,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          'Rechercher des podcasts, épisodes, thèmes...',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: BkoTheme.fontPoppins(
                                            fontSize: 13,
                                            color: textSec,
                                            fontWeight: FontWeight.w400,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF222224),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          'Explorer',
                                          style: BkoTheme.fontPoppins(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w600,
                                            color: textPri,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
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
}
