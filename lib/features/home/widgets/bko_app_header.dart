import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../../../core/theme/bko_theme.dart';
import '../../../core/widgets/bko_bounceable.dart';
import '../../auth/auth_controller.dart';
import '../../notifications/notification_providers.dart';
import '../home_providers.dart';

/// Ultra-smooth, Apple-grade fluid responsive header for BKO Podcast.
/// Adheres strictly to:
/// - apple-design: Interruptible motion from current value, Cubic(0.2, 0.9, 0.2, 1.0),
///   velocity-aware return (20-30% faster), tactile direct manipulation.
/// - mobile-designer: Iconsax ONLY, zero shadows (Rule 11), solid surface separation,
///   transform + opacity animations, 60/120fps smoothness without layout thrashing.
class BkoAppHeader extends ConsumerStatefulWidget implements PreferredSizeWidget {
  final bool? isCollapsed;
  const BkoAppHeader({super.key, this.isCollapsed});

  @override
  Size get preferredSize => const Size.fromHeight(108);

  @override
  ConsumerState<BkoAppHeader> createState() => _BkoAppHeaderState();
}

class _BkoAppHeaderState extends ConsumerState<BkoAppHeader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  static const _forwardDuration = Duration(milliseconds: 260);
  static const _reverseDuration = Duration(milliseconds: 210);
  static const _appleCurve = Cubic(0.2, 0.9, 0.2, 1.0);

  @override
  void initState() {
    super.initState();
    final initialCollapsed = (widget.isCollapsed ?? false);

    _controller = AnimationController(
      vsync: this,
      value: initialCollapsed ? 1.0 : 0.0,
      duration: _forwardDuration,
      reverseDuration: _reverseDuration,
    );

    _animation = CurvedAnimation(
      parent: _controller,
      curve: _appleCurve,
      reverseCurve: Curves.easeOutCubic,
    );
  }

  @override
  void didUpdateWidget(covariant BkoAppHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isCollapsed != null && widget.isCollapsed != oldWidget.isCollapsed) {
      _syncCollapse(widget.isCollapsed!);
    }
  }

  void _syncCollapse(bool collapsed) {
    if (collapsed) {
      if (_controller.value < 1.0) _controller.forward();
    } else {
      if (_controller.value > 0.0) _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Listen to global collapsed state when not explicitly overridden
    if (widget.isCollapsed == null) {
      ref.listen<bool>(homeHeaderCollapsedProvider, (_, next) {
        _syncCollapse(next);
      });
    }

    final auth = ref.watch(authProvider);
    final unreadCount = ref.watch(unreadNotificationsProvider);

    final textPri = BkoTheme.getTextPrimary(context);
    final textSec = BkoTheme.getTextSecondary(context);
    final borderSub = BkoTheme.getBorderSubtle(context);
    final Color normalBg = BkoTheme.getBgObsidian(context);
    final Color elevatedSurfaceBg = BkoTheme.getBgSurfaceElevated(context);
    final Color bottomBorderActive = borderSub;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        final double t = _animation.value;

        final Color currentBg = Color.lerp(normalBg, elevatedSurfaceBg, t)!;
        final Color bottomBorderColor = Color.lerp(Colors.transparent, bottomBorderActive, t)!;

        // Compact search button in top bar: emerges smoothly as bottom bar folds
        final double searchProgress = ((t - 0.35) / 0.65).clamp(0.0, 1.0);
        final double searchOpacity = searchProgress;
        final double searchScale = lerpDouble(0.82, 1.0, searchProgress)!;
        final double searchOffset = lerpDouble(8.0, 0.0, searchProgress)!;
        final double searchSlotWidth = lerpDouble(0.0, 44.0, t)!;

        // Brand title: fades and slides out swiftly before header finishes collapsing
        final double titleOpacity = (1.0 - t * 2.2).clamp(0.0, 1.0);
        final double titleWidth = lerpDouble(156.0, 0.0, t)!;

        // Bottom search bar: scale + translate upwards into top bar
        final double bottomBarHeight = lerpDouble(48.0, 0.0, t)!;
        final double bottomBarOpacity = (1.0 - t * 2.0).clamp(0.0, 1.0);
        final double bottomBarScale = lerpDouble(1.0, 0.95, t)!;
        final double bottomBarTranslateY = -10.0 * t;

        return Container(
          decoration: BoxDecoration(
            color: currentBg,
            border: Border(
              bottom: BorderSide(
                color: bottomBorderColor,
                width: 1.0,
              ),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: ClipRect(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 4, 16, lerpDouble(8.0, 6.0, t)!),
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                  // -------------------------------------------------------------
                  // 1. TOP BAR ROW (48px fixed height)
                  // -------------------------------------------------------------
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
                            child: BkoBounceable(
                              onTap: () => Scaffold.of(context).openDrawer(),
                              child: Container(
                                width: 44,
                                height: 44,
                                alignment: Alignment.center,
                                child: Icon(
                                  IconsaxPlusLinear.menu_1,
                                  size: 22,
                                  color: textPri,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                        ],

                        // Bamako Podcast Logo & Branding
                        Semantics(
                          label: 'Accueil Bamako Podcast',
                          button: true,
                          child: BkoBounceable(
                            onTap: () {
                              ref.read(homeHeaderCollapsedProvider.notifier).state = false;
                              _syncCollapse(false);
                            },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Logo icon box with subtle reactive accent border
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: Color.lerp(
                                      BkoTheme.getBgSurface(context),
                                      elevatedSurfaceBg,
                                      t,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: Color.lerp(
                                        borderSub,
                                        BkoTheme.goldAccent.withValues(alpha: 0.65),
                                        t,
                                      )!,
                                      width: 1.0,
                                    ),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(9),
                                    child: Image.asset(
                                      'assets/brand/app_icon.png',
                                      width: 38,
                                      height: 38,
                                      fit: BoxFit.contain,
                                      errorBuilder: (context, error, stackTrace) => Icon(
                                        IconsaxPlusLinear.microphone_2,
                                        color: BkoTheme.getAccent(context),
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ),

                                // Brand text "Bamako Podcast" smoothly fades and translates left (Zero RenderFlex overflow)
                                ClipRect(
                                  child: SizedBox(
                                    width: titleWidth,
                                    child: Opacity(
                                      opacity: titleOpacity,
                                      child: OverflowBox(
                                        alignment: Alignment.centerLeft,
                                        minWidth: 0,
                                        maxWidth: double.infinity,
                                        minHeight: 0,
                                        maxHeight: 48,
                                        child: Transform.translate(
                                          offset: Offset(-8.0 * t, 0),
                                          child: Padding(
                                            padding: const EdgeInsets.only(left: 10),
                                            child: Text(
                                              'Bamako Podcast',
                                              maxLines: 1,
                                              overflow: TextOverflow.clip,
                                              softWrap: false,
                                              style: BkoTheme.fontPoppins(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                                color: textPri,
                                                letterSpacing: -0.2,
                                              ),
                                            ),
                                          ),
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

                        // Quick Search Icon in top bar (Apple recipe: unfolds as bottom bar folds)
                        ClipRect(
                          child: SizedBox(
                            width: searchSlotWidth,
                            child: Opacity(
                              opacity: searchOpacity,
                              child: OverflowBox(
                                alignment: Alignment.centerRight,
                                minWidth: 0,
                                maxWidth: 44,
                                minHeight: 0,
                                maxHeight: 44,
                                child: Transform.scale(
                                  scale: searchScale,
                                  child: Transform.translate(
                                    offset: Offset(searchOffset, 0),
                                    child: Semantics(
                                      label: 'Rechercher',
                                      button: true,
                                      child: BkoBounceable(
                                        onTap: () => context.go('/explore'),
                                        child: Container(
                                          width: 44,
                                          height: 44,
                                          alignment: Alignment.center,
                                          child: Icon(
                                            IconsaxPlusLinear.search_normal_1,
                                            size: 21,
                                            color: BkoTheme.getAccent(context),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Offline Downloads Button
                        Semantics(
                          label: 'Téléchargements hors connexion',
                          button: true,
                          child: BkoBounceable(
                            onTap: () => context.push('/downloads'),
                            child: Container(
                              width: 44,
                              height: 44,
                              alignment: Alignment.center,
                              child: Icon(
                                IconsaxPlusLinear.document_download,
                                size: 22,
                                color: textPri,
                              ),
                            ),
                          ),
                        ),

                        // Notifications Button with Unread Badge
                        Semantics(
                          label: 'Notifications',
                          button: true,
                          child: BkoBounceable(
                            onTap: () {
                              if (!auth.isAuthenticated) {
                                context.push('/login');
                              } else {
                                context.push('/notifications');
                              }
                            },
                            child: Container(
                              width: 44,
                              height: 44,
                              alignment: Alignment.center,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Icon(
                                    IconsaxPlusLinear.notification,
                                    size: 22,
                                    color: textPri,
                                  ),
                                  if (unreadCount > 0)
                                    Positioned(
                                      top: 9,
                                      right: 9,
                                      child: Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: BkoTheme.goldAccent,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: currentBg,
                                            width: 1.5,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // -------------------------------------------------------------
                  // 2. BOTTOM SEARCH BAR ROW (Fluid collapse & glide upwards)
                  // -------------------------------------------------------------
                  ClipRect(
                    child: SizedBox(
                      height: bottomBarHeight,
                      child: Opacity(
                        opacity: bottomBarOpacity,
                        child: OverflowBox(
                          alignment: Alignment.topCenter,
                          minHeight: 0,
                          maxHeight: 52,
                          child: Transform.translate(
                            offset: Offset(0, bottomBarTranslateY),
                            child: Transform.scale(
                              scale: bottomBarScale,
                              child: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Semantics(
                                  label: 'Rechercher des podcasts, épisodes et thèmes',
                                  button: true,
                                  child: BkoBounceable(
                                    onTap: () => context.go('/explore'),
                                  child: Container(
                                    height: 44,
                                    padding: const EdgeInsets.symmetric(horizontal: 14),
                                    decoration: BoxDecoration(
                                      color: elevatedSurfaceBg,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: borderSub,
                                        width: 1.0,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          IconsaxPlusLinear.search_normal_1,
                                          color: BkoTheme.getAccent(context),
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
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3.5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: BkoTheme.getBgSurface(context),
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
                          ),
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
  );
      },
    );
  }
}
