import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/network/bko_api.dart';
import '../../core/network/bko_telemetry.dart';
import '../../core/theme/bko_theme.dart';
import '../../core/theme/theme_provider.dart';
import '../auth/auth_controller.dart';
import '../downloads/download_manager.dart';
import '../player/full_audio_player_sheet.dart';
import '../shell/shell_providers.dart';
import 'widgets/hero_banner_slider.dart';
import 'widgets/bko_app_header.dart';
import 'widgets/bko_drawer.dart';
import 'widgets/episode_list_item.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import '../../core/widgets/bko_bounceable.dart';
import '../../core/widgets/bko_haptics.dart';
import '../../core/widgets/equalizer_loader.dart';
import '../../core/widgets/skeleton_loaders.dart';
import '../discovery/widgets/discovery_promotion_modal.dart';
import '../notifications/services/notification_destination_handler.dart';
import '../onboarding/widgets/preferences_catch_up_sheet.dart';
import 'home_providers.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String _filterMode = 'ALL';
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(homeDataProvider.notifier).fetchInitial();
      _checkDiscoveryPromotion();
      _checkPreferencesCatchUp();
      NotificationDestinationHandler.consumePending(context, ref: ref);
    });
  }

  Future<void> _checkPreferencesCatchUp() async {
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    PreferencesCatchUpSheet.checkAndShow(context, ref);
  }

  Future<void> _checkDiscoveryPromotion() async {
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    final homeData = ref.read(homeDataProvider).homeData;
    final sections = _asList(homeData?['sections']);
    final promoSec = sections.firstWhere(
      (s) => s is Map && (s['slug'] == 'editorial-selection' || s['sourceMode'] == 'MANUAL' || s['slug'] == 'for-you'),
      orElse: () => null,
    );
    if (promoSec is Map) {
      final secId = promoSec['id']?.toString() ?? promoSec['slug']?.toString() ?? 'editorial';
      final title = promoSec['title']?.toString() ?? 'Sélection Spéciale';
      final subtitle = promoSec['subtitle']?.toString() ?? 'Découvrez les contenus sélectionnés pour vous.';
      final items = _asList(promoSec['items']);
      String? cover;
      if (items.isNotEmpty && items.first is Map) {
        final firstItem = items.first as Map;
        cover = firstItem['podcast']?['cover'] ?? firstItem['episode']?['cover'];
      }
      DiscoveryPromotionModal.checkAndShow(
        context: context,
        ref: ref,
        campaignId: 'promo_$secId',
        title: title,
        description: subtitle,
        buttonLabel: 'Explorer la sélection',
        targetUrl: '/discovery/sections/$secId?title=${Uri.encodeComponent(title)}&type=${promoSec['type'] ?? 'EPISODE_ROW'}',
        coverUrl: cover,
      );
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 400) {
      ref.read(homeDataProvider.notifier).fetchMoreFeed();
    }
  }

  List<dynamic> _asList(dynamic value) {
    if (value is List) return List<dynamic>.from(value);
    if (value is Map && value['data'] is List) {
      return List<dynamic>.from(value['data'] as List);
    }
    return [];
  }

  void _triggerPlayEpisode(Map<String, dynamic> ep, {Map<String, dynamic>? attribution}) {
    final title = ep['title'] ?? 'Épisode';
    final podcastName = ep['podcast']?['name']?.toString() ?? ep['showName']?.toString() ?? '';
    final durationSeconds = ep['durationSeconds'] ?? 1800;
    final duration = '${(durationSeconds / 60).round()} min';
    final cover = ep['cover'] ?? ep['podcast']?['cover'] ?? '';
    final audioUrl = BkoApi.extractAudioUrl(ep);
    final videoUrl = BkoApi.extractVideoUrl(ep);
    final episodeId = '${ep['id'] ?? ''}';

    final downloads = ref.read(downloadProvider);
    final downloadTask = downloads.cast<DownloadTask?>().firstWhere(
          (t) => t?.episodeId == episodeId,
          orElse: () => null,
        );
    final localAudio = downloadTask?.status == DownloadStatus.completed
        ? downloadTask?.localPath
        : null;

    final batchId = attribution?['batchId']?.toString();
    final sectionId = attribution?['sectionId']?.toString();
    final sectionSlug = attribution?['sectionSlug']?.toString();

    final hasAudioTrack = audioUrl != null || localAudio != null;

    final active = ref.read(activeEpisodeProvider);
    final isAlreadyPlayingThis = active.hasActiveEpisode &&
        active.episodeId == episodeId &&
        active.isPlaying;

    ref.read(activeEpisodeProvider.notifier).handlePlayOrPause(
          title: title,
          showName: podcastName,
          duration: duration,
          coverUrl: cover,
          audioUrl: localAudio ?? audioUrl,
          videoUrl: videoUrl,
          hasAudio: hasAudioTrack,
          hasVideo: videoUrl != null,
          episodeId: episodeId,
          podcastSlug: '${ep['podcast']?['slug'] ?? ''}',
          episodeSlug: '${ep['slug'] ?? ''}',
          batchId: batchId,
          sectionId: sectionId,
          sectionSlug: sectionSlug,
        );

    if (!isAlreadyPlayingThis && mounted) {
      FullAudioPlayerSheet.show(context);
    }

    if (batchId != null) {
      BkoTelemetryService().trackInteraction(
        batchId: batchId,
        sectionId: sectionId ?? 'section',
        sectionSlug: sectionSlug ?? 'unknown',
        targetType: 'EPISODE',
        targetId: episodeId,
        action: 'PLAY_START',
        token: ref.read(authProvider).token,
      );
    }
  }

  // ignore: unused_element
  void _openUserProfileModal(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final bg = BkoTheme.getBgSurface(context);
        final border = BkoTheme.getBorderSubtle(context);
        final textPri = BkoTheme.getTextPrimary(context);
        final textSec = BkoTheme.getTextSecondary(context);
        final currentSetting = ref.read(themeSettingProvider);
        
        return Container(
          margin: const EdgeInsets.only(top: 40),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: textSec.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: BkoTheme.getBgSurfaceElevated(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: border),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: BkoTheme.getBgSurface(context),
                        border: Border.all(color: BkoTheme.goldAccent, width: 1.5),
                      ),
                      child: Center(
                        child: Text(
                          ref.read(authProvider).user?['fullName']?.toString().substring(0, 1).toUpperCase() ?? 'A',
                          style: BkoTheme.fontLato(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            color: BkoTheme.goldAccent,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ref.read(authProvider).user?['fullName'] ?? 'Auditeur Bamako',
                            style: BkoTheme.fontLato(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: textPri,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            ref.read(authProvider).user?['email'] ?? 'Membre Bamako Podcast',
                            style: BkoTheme.fontLato(
                              fontSize: 12,
                              color: textSec,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'COMPTE & PRÉFÉRENCES',
                  style: BkoTheme.fontLato(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: textSec,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _buildMenuRow(context, IconsaxPlusLinear.user, 'Mon Profil & Compte', 'Gérer vos informations personnelles', () {
                context.pop();
                context.go('/profile');
              }),
              _buildMenuRow(context, IconsaxPlusLinear.microphone_2, 'Studio Créateur', 'Publier et administrer vos podcasts', () {
                context.pop();
                context.push('/studio');
              }),
              _buildMenuRow(context, IconsaxPlusLinear.bookmark, 'Bibliothèque & Favoris', 'Retrouver vos sauvegardes', () {
                context.pop();
                context.go('/library');
              }),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'THÈME D\'AFFICHAGE',
                  style: BkoTheme.fontLato(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: textSec,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: BkoTheme.getBgSurfaceElevated(context),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: border),
                ),
                child: Row(
                  children: [
                    Expanded(child: _buildThemeSegment(context, 'Système', AppThemeSetting.system, currentSetting)),
                    Expanded(child: _buildThemeSegment(context, 'Clair', AppThemeSetting.light, currentSetting)),
                    Expanded(child: _buildThemeSegment(context, 'Sombre', AppThemeSetting.dark, currentSetting)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Divider(color: border, height: 1),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(IconsaxPlusLinear.info_circle, size: 18, color: textSec),
                    const SizedBox(width: 10),
                    Text('Aide & Support', style: BkoTheme.fontLato(fontSize: 13, fontWeight: FontWeight.w600, color: textPri)),
                    const Spacer(),
                    Icon(IconsaxPlusLinear.arrow_right_3, size: 14, color: textSec),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Builder(
                  builder: (context) {
                    final errColor = Theme.of(context).colorScheme.error;
                    return TextButton.icon(
                      onPressed: () {
                        context.pop();
                        ref.read(authProvider.notifier).logout();
                      },
                      icon: Icon(IconsaxPlusLinear.logout, size: 18, color: errColor),
                      label: Text('Se déconnecter', style: BkoTheme.fontLato(fontSize: 13, fontWeight: FontWeight.w700, color: errColor)),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        backgroundColor: errColor.withValues(alpha: 0.1),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    );
                  },
                ),
              ),
              SizedBox(height: bottomInset + 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMenuRow(BuildContext context, IconData icon, String title, String subtitle, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: BkoTheme.getBgSurfaceElevated(context),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: BkoTheme.getBorderSubtle(context)),
              ),
              child: Icon(icon, color: BkoTheme.goldAccent, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: BkoTheme.fontLato(fontSize: 14, fontWeight: FontWeight.w700, color: BkoTheme.getTextPrimary(context))),
                  const SizedBox(height: 2),
                  Text(subtitle, style: BkoTheme.fontLato(fontSize: 11.5, color: BkoTheme.getTextSecondary(context))),
                ],
              ),
            ),
            Icon(IconsaxPlusLinear.arrow_right_3, color: BkoTheme.getTextSecondary(context), size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeSegment(BuildContext context, String label, AppThemeSetting mode, AppThemeSetting current) {
    final isSelected = current == mode;
    return GestureDetector(
      onTap: () {
        ref.read(themeSettingProvider.notifier).setThemeSetting(mode);
        context.pop();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? BkoTheme.goldAccent : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: BkoTheme.fontLato(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
            color: isSelected ? BkoTheme.darkBgObsidian : BkoTheme.getTextSecondary(context),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bgSurf = BkoTheme.getBgSurface(context);
    final bgElevated = BkoTheme.getBgSurfaceElevated(context);
    final borderSub = BkoTheme.getBorderSubtle(context);
    final textPri = BkoTheme.getTextPrimary(context);
    final textSec = BkoTheme.getTextSecondary(context);

    final homeState = ref.watch(homeDataProvider);
    final data = homeState.homeData ?? {};
    final categories = homeState.categories;
    final historyData = homeState.historyData;

    if (homeState.isLoading && !homeState.hasData) {
      return Scaffold(
        backgroundColor: BkoTheme.getBgObsidian(context),
        drawer: const BkoDrawer(),
        body: const Column(
          children: [
            BkoAppHeader(),
            Expanded(child: BkoHomeSkeleton()),
          ],
        ),
      );
    }

    if (!homeState.hasData && homeState.error != null) {
      return Scaffold(
        backgroundColor: BkoTheme.getBgObsidian(context),
        drawer: const BkoDrawer(),
        body: Column(
          children: [
            const BkoAppHeader(),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(IconsaxPlusLinear.wifi_square, size: 52, color: BkoTheme.goldAccent),
                      const SizedBox(height: 16),
                      Text(
                        'Impossible de charger les données',
                        textAlign: TextAlign.center,
                        style: BkoTheme.fontPoppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: textPri,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        homeState.error ?? 'Veuillez vérifier votre connexion internet.',
                        textAlign: TextAlign.center,
                        style: BkoTheme.fontLato(
                          fontSize: 13,
                          color: textSec,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () => ref.read(homeDataProvider.notifier).refresh(),
                        icon: const Icon(IconsaxPlusLinear.refresh_2, size: 16),
                        label: const Text('Réessayer'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: BkoTheme.goldAccent,
                          foregroundColor: BkoTheme.darkBgObsidian,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
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
      );
    }

    final heroEpisode = data['heroEpisode'];
    final rawHeroSlides = _asList(data['heroSlides']);
    final latestEpisodesRaw = _asList(data['latestEpisodes']);
    final dynamicSections = _asList(data['sections']);

    // Build heroSlides with fallbacks matching web HeroBanner logic
    final List<dynamic> heroSlides = rawHeroSlides.isNotEmpty
        ? rawHeroSlides
        : [
            if (heroEpisode != null) {'kind': 'featured', 'label': 'À la une', 'episode': heroEpisode},
            ...latestEpisodesRaw.take(4).map((ep) => {'kind': 'latest', 'label': 'Nouveauté', 'episode': ep}),
          ];

    // Filter latestEpisodes based on mode (Audio/Video)
    final latestEpisodes = latestEpisodesRaw.where((ep) {
      if (_filterMode == 'ALL') return true;
      final hasVideo = BkoApi.extractVideoUrl(ep as Map<String, dynamic>) != null;
      if (_filterMode == 'VIDEO') return hasVideo;
      if (_filterMode == 'AUDIO') return !hasVideo; // Simplification
      return true;
    }).toList();

    final feedEpisodes = homeState.feedItems.isNotEmpty
        ? homeState.feedItems
        : latestEpisodes;

    return Scaffold(
      backgroundColor: BkoTheme.getBgObsidian(context),
      drawer: const BkoDrawer(),
      body: Column(
        children: [
          const BkoAppHeader(),
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                // Carousels and horizontal shelves must never collapse the
                // page header, including their automatic page animations.
                if (notification.metrics.axis != Axis.vertical ||
                    notification.depth != 0) {
                  return false;
                }
                if (notification is ScrollUpdateNotification) {
                  if (notification.dragDetails == null) return false;
                  final delta = notification.scrollDelta ?? 0.0;
                  final pixels = notification.metrics.pixels;
                  if (pixels <= 10) {
                    if (ref.read(homeHeaderCollapsedProvider)) {
                      ref.read(homeHeaderCollapsedProvider.notifier).state = false;
                    }
                    ref.read(shellNavVisibilityProvider.notifier).setVisible(true);
                  } else if (delta > 2.5 && pixels > 25) {
                    if (!ref.read(homeHeaderCollapsedProvider)) {
                      ref.read(homeHeaderCollapsedProvider.notifier).state = true;
                    }
                    ref.read(shellNavVisibilityProvider.notifier).setVisible(false);
                  } else if (delta < -2.5) {
                    if (ref.read(homeHeaderCollapsedProvider)) {
                      ref.read(homeHeaderCollapsedProvider.notifier).state = false;
                    }
                    ref.read(shellNavVisibilityProvider.notifier).setVisible(true);
                  }
                } else if (notification is UserScrollNotification) {
                  if (notification.direction == ScrollDirection.forward) {
                    if (ref.read(homeHeaderCollapsedProvider)) {
                      ref.read(homeHeaderCollapsedProvider.notifier).state = false;
                    }
                    ref.read(shellNavVisibilityProvider.notifier).setVisible(true);
                  } else if (notification.direction == ScrollDirection.reverse &&
                      notification.metrics.pixels > 25) {
                    if (!ref.read(homeHeaderCollapsedProvider)) {
                      ref.read(homeHeaderCollapsedProvider.notifier).state = true;
                    }
                    ref.read(shellNavVisibilityProvider.notifier).setVisible(false);
                  }
                }
                return false;
              },
              child: RefreshIndicator(
        color: BkoTheme.goldAccent,
        onRefresh: () async {
          BkoHaptics.light();
          await ref.read(homeDataProvider.notifier).refresh();
          BkoHaptics.select();
        },
        child: SingleChildScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Hero Banner Slider (auto-sliding & swipeable carousel matching web HeroBanner)
              if (heroSlides.isNotEmpty) ...[
                const SizedBox(height: 6),
                HeroBannerSlider(
                  slides: heroSlides,
                  onPlay: (ep) => _triggerPlayEpisode(ep),
                ),
                const SizedBox(height: 16),
              ],

              // 2. Filtres Rapides (Barre de pills minimaliste et épurée)
              SizedBox(
                height: 34,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    BkoBounceable(
                      onTap: () {
                        BkoHaptics.light();
                        ref.read(homeDataProvider.notifier).selectCategory('all');
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: homeState.selectedCategory == 'all'
                              ? BkoTheme.getActivePillBg(context)
                              : bgSurf,
                          borderRadius: BorderRadius.circular(17),
                          border: Border.all(
                            color: homeState.selectedCategory == 'all'
                                ? BkoTheme.getActivePillBg(context)
                                : borderSub,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          'Tout explorer',
                          style: BkoTheme.fontLato(
                            fontSize: 12,
                            fontWeight: homeState.selectedCategory == 'all' ? FontWeight.w800 : FontWeight.w600,
                            color: homeState.selectedCategory == 'all'
                                ? BkoTheme.getActivePillText(context)
                                : textPri,
                          ),
                        ),
                      ),
                    ),
                    ...categories.map((cat) {
                      final catSlug = (cat['slug'] ?? cat['id'] ?? cat['name'])?.toString() ?? '';
                      final isActive = homeState.selectedCategory == catSlug ||
                          homeState.selectedCategory == cat['id']?.toString() ||
                          homeState.selectedCategory == cat['slug']?.toString();
                      return BkoBounceable(
                        onTap: () {
                          BkoHaptics.light();
                          ref.read(homeDataProvider.notifier).selectCategory(catSlug);
                        },
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isActive ? BkoTheme.getActivePillBg(context) : bgSurf,
                            borderRadius: BorderRadius.circular(17),
                            border: Border.all(
                              color: isActive ? BkoTheme.getActivePillBg(context) : borderSub,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            '${cat['name']}',
                            style: BkoTheme.fontLato(
                              fontSize: 12,
                              fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                              color: isActive ? BkoTheme.getActivePillText(context) : textPri,
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // 3. Sections Personnalisées du Moteur (avec fallback si sections vide)
              if (dynamicSections.isNotEmpty) ...[
                ...dynamicSections.map((sec) {
                  final secSlug = sec['slug']?.toString() ?? '';
                  final secType = sec['type']?.toString() ?? '';
                  final secTitle = sec['title']?.toString() ?? '';
                  final secSubtitle = sec['subtitle']?.toString();
                  final items = _asList(sec['items']);

                  if (items.isEmpty) return const SizedBox.shrink();

                  // A. Continuer l'écoute (Reprendre)
                  if (secSlug == 'continue-listening' || secType == 'RESUME_GRID') {
                    final destination = _sectionDedicatedDestination(sec, 'EPISODE_ROW');
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: BkoBounceable(
                                  onTap: () {
                                    BkoHaptics.light();
                                    context.push(destination);
                                  },
                                  child: Row(
                                    children: [
                                      const Icon(IconsaxPlusBold.play, color: BkoTheme.goldAccent, size: 16),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          secTitle.isNotEmpty ? secTitle : 'Reprendre l\'écoute',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: BkoTheme.fontLato(fontSize: 18, fontWeight: FontWeight.w800, color: textPri),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(IconsaxPlusLinear.arrow_right_3, size: 14, color: textSec),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _buildDiscoverMoreButton(destination),
                            ],
                          ),
                        ),
                        if (secSubtitle != null && secSubtitle.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(secSubtitle, style: BkoTheme.fontLato(fontSize: 12, color: textSec)),
                          ),
                        ],
                        const SizedBox(height: 14),
                        SizedBox(
                          height: 110,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: items.length > 6 ? 6 : items.length,
                            itemBuilder: (context, index) {
                              final item = items[index];
                              final ep = item['episode'] is Map ? Map<String, dynamic>.from(item['episode']) : <String, dynamic>{};
                              final pos = (item['positionSeconds'] as num?)?.toInt() ?? 0;
                              final dur = (ep['durationSeconds'] as num?)?.toInt() ?? 1800;
                              final percent = (dur > 0 ? (pos / dur) : 0.0).clamp(0.0, 1.0);
                              final cover = ep['cover'] ?? ep['podcast']?['cover'] ?? '';

                              return BkoBounceable(
                                onTap: () => _triggerPlayEpisode(
                                  ep,
                                  attribution: item['attribution'] is Map ? Map<String, dynamic>.from(item['attribution']) : null,
                                ),
                                child: Container(
                                  width: 260,
                                  margin: const EdgeInsets.only(right: 12),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: bgSurf,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: borderSub),
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(8),
                                            child: CachedNetworkImage(
                                              imageUrl: cover,
                                              width: 44,
                                              height: 44,
                                              fit: BoxFit.cover,
                                              errorWidget: (context, url, error) => Container(
                                                width: 44,
                                                height: 44,
                                                color: bgElevated,
                                                child: const Center(
                                                  child: Icon(IconsaxPlusLinear.microphone_2, color: BkoTheme.goldAccent, size: 18),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Text(ep['title'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                                                    style: BkoTheme.fontLato(fontSize: 13, fontWeight: FontWeight.w700, color: textPri)),
                                                const SizedBox(height: 3),
                                                Text(ep['podcast']?['name'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                                                    style: BkoTheme.fontLato(fontSize: 11, color: textSec)),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Spacer(),
                                      LinearProgressIndicator(
                                        value: percent,
                                        backgroundColor: bgElevated,
                                        color: BkoTheme.goldAccent,
                                        minHeight: 2.5,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    );
                  }

                  // B. Épisodes recommandés (EPISODE_ROW ou items d'épisodes)
                  if (secType == 'EPISODE_ROW' || (items.isNotEmpty && items.first['targetType'] == 'EPISODE')) {
                    final destination = _sectionDedicatedDestination(sec, 'EPISODE_ROW');
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: BkoBounceable(
                                  onTap: () {
                                    BkoHaptics.light();
                                    context.push(destination);
                                  },
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(secTitle,
                                                style: BkoTheme.fontLato(fontSize: 18, fontWeight: FontWeight.w800, color: textPri)),
                                          ),
                                          const SizedBox(width: 4),
                                          Icon(IconsaxPlusLinear.arrow_right_3, size: 14, color: textSec),
                                        ],
                                      ),
                                      if (secSubtitle != null && secSubtitle.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(secSubtitle, style: BkoTheme.fontLato(fontSize: 12, color: textSec)),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _buildDiscoverMoreButton(destination),
                            ],
                          ),
                        ),
                        if (secSlug == 'for-you') ...[
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                _buildFilterBtn('Tous', 'ALL'),
                                const SizedBox(width: 8),
                                _buildFilterBtn('Audio', 'AUDIO'),
                                const SizedBox(width: 8),
                                _buildFilterBtn('Vidéo', 'VIDEO'),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            children: items.take(8).map((item) {
                              final ep = item['episode'] is Map ? Map<String, dynamic>.from(item['episode']) : <String, dynamic>{};
                              if (ep.isEmpty) return const SizedBox.shrink();

                              if (secSlug == 'for-you') {
                                if (_filterMode == 'VIDEO' && BkoApi.extractVideoUrl(ep) == null) {
                                  return const SizedBox.shrink();
                                }
                                if (_filterMode == 'AUDIO' && BkoApi.extractVideoUrl(ep) != null) {
                                  return const SizedBox.shrink();
                                }
                              }

                              final attribution = item['attribution'] is Map ? Map<String, dynamic>.from(item['attribution']) : null;
                              final batchId = attribution?['batchId']?.toString();

                              final epCard = EpisodeListItem(
                                episode: ep,
                                recommendationReason: item['reason']?.toString(),
                                onPlay: () => _triggerPlayEpisode(
                                  ep,
                                  attribution: attribution,
                                ),
                              );

                              if (batchId != null) {
                                return TrackedVisibilityCard(
                                  batchId: batchId,
                                  sectionId: sec['id']?.toString() ?? '',
                                  sectionSlug: sec['slug']?.toString() ?? '',
                                  targetType: 'EPISODE',
                                  targetId: ep['id']?.toString() ?? '',
                                  position: (item['position'] as num?)?.toInt() ?? 0,
                                  reason: item['reason']?.toString(),
                                  token: ref.read(authProvider).token,
                                  child: epCard,
                                );
                              }

                              return epCard;
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    );
                  }

                  // C. Émissions recommandées (PODCAST_ROW ou items de podcasts)
                  final destination = _sectionDedicatedDestination(sec, 'PODCAST_ROW');
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: BkoBounceable(
                                onTap: () {
                                  BkoHaptics.light();
                                  context.push(destination);
                                },
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(secTitle, style: BkoTheme.fontLato(fontSize: 18, fontWeight: FontWeight.w800, color: textPri)),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(IconsaxPlusLinear.arrow_right_3, size: 14, color: textSec),
                                      ],
                                    ),
                                    if (secSubtitle != null && secSubtitle.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(secSubtitle, style: BkoTheme.fontLato(fontSize: 12, color: textSec)),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _buildDiscoverMoreButton(destination),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 220,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final item = items[index];
                            final p = item['podcast'] is Map ? Map<String, dynamic>.from(item['podcast']) : <String, dynamic>{};
                            if (p.isEmpty) return const SizedBox.shrink();
                            final pSlug = p['slug'] ?? '';
                            final reason = item['reason']?.toString();

                            final attribution = item['attribution'] is Map ? Map<String, dynamic>.from(item['attribution']) : null;
                            final batchId = attribution?['batchId']?.toString();

                            final podCard = BkoBounceable(
                              onTap: () {
                                BkoHaptics.light();
                                if (attribution != null) {
                                  BkoTelemetryService().trackInteraction(
                                    batchId: batchId ?? '',
                                    sectionId: sec['id']?.toString() ?? '',
                                    sectionSlug: sec['slug']?.toString() ?? '',
                                    targetType: 'PODCAST',
                                    targetId: p['id']?.toString() ?? '',
                                    action: 'CLICK',
                                    token: ref.read(authProvider).token,
                                  );
                                }
                                context.push('/podcasts/$pSlug');
                              },
                              child: Container(
                                width: 140,
                                margin: const EdgeInsets.only(right: 12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(14),
                                      child: AspectRatio(
                                        aspectRatio: 1,
                                        child: CachedNetworkImage(
                                          imageUrl: p['cover'] ?? '',
                                          fit: BoxFit.cover,
                                          errorWidget: (context, url, error) => Container(
                                            color: bgElevated,
                                            child: const Center(
                                              child: Icon(IconsaxPlusLinear.microphone_2, color: BkoTheme.goldAccent, size: 28),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    if (reason != null && reason.isNotEmpty) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: bgElevated,
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: borderSub),
                                        ),
                                        child: Text(
                                          reason,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: BkoTheme.fontLato(fontSize: 10, fontWeight: FontWeight.w700, color: BkoTheme.goldAccent),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                    ],
                                    Text(p['name'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                                        style: BkoTheme.fontLato(fontSize: 13, fontWeight: FontWeight.w800, color: textPri)),
                                    const SizedBox(height: 2),
                                    Builder(
                                      builder: (context) {
                                        final authorCandidate = p['author']?['name'] ??
                                            p['author']?['fullName'] ??
                                            p['organization']?['name'];
                                        final authorStr = (authorCandidate != null &&
                                                authorCandidate.toString().trim().isNotEmpty &&
                                                authorCandidate.toString().trim().toLowerCase() != 'bamako podcast')
                                            ? authorCandidate.toString().trim()
                                            : null;
                                        final lang = p['primaryLanguage']?['name']?.toString();
                                        final count = p['_count']?['episodes'] ?? p['episodesCount'];
                                        final countStr = (count != null && count is num && count > 0)
                                            ? '$count ${count == 1 ? 'épisode' : 'épisodes'}'
                                            : null;
                                        final subtitleParts = [
                                          if (authorStr != null) authorStr,
                                          if (lang != null && lang.isNotEmpty) lang,
                                          if (authorStr == null && lang == null && countStr != null) countStr,
                                        ];
                                        final subtitle = subtitleParts.isNotEmpty
                                            ? subtitleParts.take(2).join(' • ')
                                            : '';
                                        if (subtitle.isEmpty) return const SizedBox.shrink();
                                        return Text(
                                          subtitle,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: BkoTheme.fontLato(fontSize: 11, color: textSec),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );

                            if (batchId != null) {
                              return TrackedVisibilityCard(
                                batchId: batchId,
                                sectionId: sec['id']?.toString() ?? '',
                                sectionSlug: sec['slug']?.toString() ?? '',
                                targetType: 'PODCAST',
                                targetId: p['id']?.toString() ?? '',
                                position: (item['position'] as num?)?.toInt() ?? index,
                                reason: reason,
                                token: ref.read(authProvider).token,
                                child: podCard,
                              );
                            }

                            return podCard;
                          },
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  );
                }),
              ] else ...[
                // Fallback hérité : Historique de lecture
                if (historyData.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        const Icon(IconsaxPlusBold.play, color: BkoTheme.goldAccent, size: 16),
                        const SizedBox(width: 8),
                        Text('Historique de lecture', style: BkoTheme.fontLato(fontSize: 18, fontWeight: FontWeight.w800, color: textPri)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 110,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: historyData.length > 4 ? 4 : historyData.length,
                      itemBuilder: (context, index) {
                        final item = historyData[index];
                        final ep = item['episode'] ?? {};
                        final pos = item['positionSeconds'] ?? 0;
                        final dur = ep['durationSeconds'] ?? 1800;
                        final percent = (dur > 0 ? (pos / dur) : 0.0).clamp(0.0, 1.0);
                        final cover = ep['cover'] ?? ep['podcast']?['cover'] ?? '';

                        return BkoBounceable(
                          onTap: () {
                            BkoHaptics.light();
                            _triggerPlayEpisode(ep);
                          },
                          child: Container(
                            width: 280,
                            margin: const EdgeInsets.only(right: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: bgSurf,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: borderSub),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: CachedNetworkImage(
                                        imageUrl: cover,
                                        width: 48,
                                        height: 48,
                                        fit: BoxFit.cover,
                                        errorWidget: (context, url, error) => Container(
                                          color: bgElevated,
                                          child: const Center(
                                            child: Icon(IconsaxPlusLinear.play, color: BkoTheme.goldAccent, size: 20),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(ep['title'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: BkoTheme.fontLato(fontSize: 13, fontWeight: FontWeight.w800, color: textPri)),
                                          const SizedBox(height: 4),
                                          Text(ep['podcast']?['name'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: BkoTheme.fontLato(fontSize: 11, color: textSec)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const Spacer(),
                                LinearProgressIndicator(
                                  value: percent,
                                  backgroundColor: BkoTheme.getBgObsidian(context),
                                  color: BkoTheme.goldAccent,
                                  minHeight: 4,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 32),
                ],

                // Fallback hérité : Fraîchement publiés
                if (latestEpisodesRaw.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Fraîchement publiés', style: BkoTheme.fontLato(fontSize: 18, fontWeight: FontWeight.w800, color: textPri)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        _buildFilterBtn('Tous', 'ALL'),
                        const SizedBox(width: 8),
                        _buildFilterBtn('Audio', 'AUDIO'),
                        const SizedBox(width: 8),
                        _buildFilterBtn('Vidéo', 'VIDEO'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: latestEpisodes.take(6).map((ep) {
                        return EpisodeListItem(
                          episode: Map<String, dynamic>.from(ep),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ],

              // 6. Flux continu d'épisodes (Défilement infini & Recommandations)
              if (feedEpisodes.isNotEmpty) ...[
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              homeState.selectedCategory == 'all'
                                  ? 'Flux continu d\'épisodes'
                                  : 'Flux : ${homeState.selectedCategory}',
                              style: BkoTheme.fontLato(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: textPri,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Recommandations & nouveautés',
                              style: BkoTheme.fontLato(
                                fontSize: 11.5,
                                color: textSec,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildDiscoverMoreButton(
                        homeState.selectedCategory == 'all'
                            ? '/explore?view=episodes'
                            : '/explore?view=episodes&category=${homeState.selectedCategory}',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: feedEpisodes.map((item) {
                      final epData = (item is Map && item['episode'] is Map)
                          ? Map<String, dynamic>.from(item['episode'] as Map)
                          : (item is Map ? Map<String, dynamic>.from(item) : <String, dynamic>{});
                      if (epData.isEmpty) return const SizedBox.shrink();

                      final reason = item is Map ? item['reason']?.toString() : null;
                      final attribution = (item is Map && item['attribution'] is Map)
                          ? Map<String, dynamic>.from(item['attribution'] as Map)
                          : null;

                      return EpisodeListItem(
                        episode: epData,
                        recommendationReason: reason,
                        onPlay: () => _triggerPlayEpisode(epData, attribution: attribution),
                      );
                    }).toList(),
                  ),
                ),
              ],

              // Message si catégorie vide
              if (!homeState.isLoading && feedEpisodes.isEmpty && homeState.selectedCategory != 'all') ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(IconsaxPlusLinear.search_status, color: textSec, size: 36),
                        const SizedBox(height: 12),
                        Text(
                          'Aucun épisode disponible pour la thématique "${homeState.selectedCategory}".',
                          textAlign: TextAlign.center,
                          style: BkoTheme.fontLato(fontSize: 13, color: textSec, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 16),
                        BkoBounceable(
                          onTap: () {
                            BkoHaptics.light();
                            ref.read(homeDataProvider.notifier).selectCategory('all');
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                            decoration: BoxDecoration(
                              color: BkoTheme.goldAccent,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              'Tout explorer',
                              style: BkoTheme.fontLato(fontSize: 12, fontWeight: FontWeight.w800, color: BkoTheme.darkBgObsidian),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              // Indicateur d'erreur avec bouton Réessayer
              if (homeState.feedError != null) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                  child: Center(
                    child: Column(
                      children: [
                        Text(
                          homeState.feedError!,
                          style: BkoTheme.fontLato(fontSize: 12, color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 10),
                        BkoBounceable(
                          onTap: () => ref.read(homeDataProvider.notifier).fetchMoreFeed(),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: BkoTheme.goldAccent),
                            ),
                            child: Text(
                              'Réessayer',
                              style: BkoTheme.fontLato(fontSize: 12, fontWeight: FontWeight.w800, color: BkoTheme.goldAccent),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              // Indicateur de chargement ou fin de flux
              if (homeState.isLoadingMore) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: EqualizerLoader(
                      bars: 4,
                      size: 22,
                      color: BkoTheme.goldAccent,
                    ),
                  ),
                ),
              ] else if (!homeState.hasMore && feedEpisodes.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      'Vous êtes à jour dans le catalogue.',
                      style: BkoTheme.fontLato(fontSize: 11.5, color: textSec),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // 7. Footer CTA Studio Minimaliste & Élégant
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: bgSurf,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderSub),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: BkoTheme.getBgSurfaceElevated(context),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderSub),
                      ),
                      child: const Center(
                        child: Icon(IconsaxPlusLinear.microphone_2, color: BkoTheme.goldAccent, size: 20),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Vous animez un podcast ?',
                            style: BkoTheme.fontLato(fontSize: 14, fontWeight: FontWeight.w800, color: textPri),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Rejoignez Bamako Podcast Studio.',
                            style: BkoTheme.fontLato(fontSize: 11.5, color: textSec),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    BkoBounceable(
                      onTap: () {
                        BkoHaptics.light();
                        context.push('/studio');
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: BkoTheme.goldAccent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Studio',
                          style: BkoTheme.fontLato(fontSize: 12, fontWeight: FontWeight.w800, color: BkoTheme.darkBgObsidian),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 120),
            ],
          ),
        ),
      ),
    ),
  ),
],
),
);
  }

  Widget _buildFilterBtn(String label, String mode) {
    final isSelected = _filterMode == mode;
    return BkoBounceable(
      onTap: () => setState(() => _filterMode = mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? BkoTheme.getActivePillBg(context) : BkoTheme.getBgSurface(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? BkoTheme.getActivePillBg(context) : BkoTheme.getBorderSubtle(context),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: BkoTheme.fontLato(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? BkoTheme.getActivePillText(context) : BkoTheme.getTextPrimary(context),
          ),
        ),
      ),
    );
  }

  String _sectionDedicatedDestination(Map section, String defaultType) {
    final secId = (section['id'] ?? section['slug'])?.toString() ?? '';
    final secSlug = section['slug']?.toString() ?? secId;
    final secTitle = section['title']?.toString() ?? '';
    final secSubtitle = section['subtitle']?.toString() ?? '';
    final secType = section['type']?.toString() ?? defaultType;

    final selectedCat = ref.read(homeDataProvider).selectedCategory;
    final discoveryContext = section['discoveryContext'];
    final category = selectedCat != 'all'
        ? selectedCat
        : (discoveryContext is Map ? discoveryContext['category']?.toString() : null);

    return Uri(
      path: '/discovery/sections/$secId',
      queryParameters: {
        if (secSlug.isNotEmpty) 'slug': secSlug,
        if (secTitle.isNotEmpty) 'title': secTitle,
        if (secSubtitle.isNotEmpty) 'subtitle': secSubtitle,
        'type': secType,
        if (ref.read(homeDataProvider).homeData?['batchId'] != null)
          'batchId': '${ref.read(homeDataProvider).homeData!['batchId']}',
        if (category != null && category.isNotEmpty) 'category': category,
      },
    ).toString();
  }

  Widget _buildDiscoverMoreButton(String? targetUrl, {String? defaultTarget}) {
    final destination = (targetUrl != null && targetUrl.isNotEmpty) ? targetUrl : defaultTarget;
    if (destination == null || destination.isEmpty) return const SizedBox.shrink();

    return BkoBounceable(
      onTap: () {
        BkoHaptics.light();
        context.push(destination);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: BkoTheme.getBgSurfaceElevated(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: BkoTheme.getBorderSubtle(context)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Découvrir davantage',
              style: BkoTheme.fontLato(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: BkoTheme.getTextPrimary(context),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              IconsaxPlusLinear.arrow_right_3,
              size: 11,
              color: BkoTheme.getTextSecondary(context),
            ),
          ],
        ),
      ),
    );
  }
}

/// Wrapper to safely handle impression tracking on recommendation items.
class TrackedVisibilityCard extends StatefulWidget {
  final String batchId;
  final String sectionId;
  final String sectionSlug;
  final String targetType;
  final String targetId;
  final int position;
  final String? reason;
  final String? token;
  final Widget child;

  const TrackedVisibilityCard({
    super.key,
    required this.batchId,
    required this.sectionId,
    required this.sectionSlug,
    required this.targetType,
    required this.targetId,
    required this.position,
    this.reason,
    this.token,
    required this.child,
  });

  @override
  State<TrackedVisibilityCard> createState() => _TrackedVisibilityCardState();
}

class _TrackedVisibilityCardState extends State<TrackedVisibilityCard> {
  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
