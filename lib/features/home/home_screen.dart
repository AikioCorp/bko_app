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
import 'widgets/tracked_visibility_card.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import '../../core/widgets/bko_bounceable.dart';
import '../../core/widgets/bko_haptics.dart';
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
    });
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
    final podcastName = ep['podcast']?['name'] ?? 'Bamako Podcast';
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
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 30,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 14),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: textSec.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: BkoTheme.getBgSurfaceElevated(context),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: border),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF8B5CF6),
                        border: Border.all(color: BkoTheme.goldAccent, width: 2),
                      ),
                      child: Center(
                        child: Text(
                          ref.read(authProvider).user?['fullName']?.toString().substring(0, 1).toUpperCase() ?? 'A',
                          style: BkoTheme.fontLato(
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ref.read(authProvider).user?['fullName'] ?? 'Auditeur Bamako',
                            style: BkoTheme.fontLato(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: textPri,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            ref.read(authProvider).user?['email'] ?? 'Membre du club',
                            style: BkoTheme.fontLato(
                              fontSize: 12.5,
                              color: textSec,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'COMPTE & PRÉFÉRENCES',
                  style: BkoTheme.fontLato(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    color: textSec,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _buildMenuRow(context, Icons.person_outline_rounded, 'Mon Profil & Compte', 'Gérer vos informations personnelles', () {
                context.pop();
                context.push('/profile');
              }),
              _buildMenuRow(context, Icons.mic_external_on_rounded, 'Studio Créateur & Admin', 'Publier et administrer vos épisodes', () {
                context.pop();
                context.push('/studio');
              }),
              _buildMenuRow(context, Icons.bookmark_outline_rounded, 'Bibliothèque & Favoris', 'Retrouver vos sauvegardes', () {
                context.pop();
                context.go('/library');
              }),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'APPARENCE (THÈME)',
                  style: BkoTheme.fontLato(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    color: textSec,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: BkoTheme.getBgSurfaceElevated(context),
                  borderRadius: BorderRadius.circular(16),
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
              const SizedBox(height: 28),
              const Divider(color: Color(0xFF242424), height: 1),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Icon(Icons.help_outline_rounded, size: 20, color: textSec),
                    const SizedBox(width: 12),
                    Text('Aide & Support', style: BkoTheme.fontLato(fontSize: 14, fontWeight: FontWeight.w600, color: textPri)),
                    const Spacer(),
                    Icon(Icons.chevron_right_rounded, size: 18, color: textSec),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextButton.icon(
                  onPressed: () {
                    context.pop();
                    ref.read(authProvider.notifier).logout();
                  },
                  icon: const Icon(Icons.logout_rounded, size: 18, color: Colors.red),
                  label: Text('Se déconnecter', style: BkoTheme.fontLato(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.red)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    backgroundColor: Colors.red.withValues(alpha: 0.1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              SizedBox(height: bottomInset + 32),
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
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: BkoTheme.getBgSurfaceElevated(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: BkoTheme.getBorderSubtle(context)),
              ),
              child: Icon(icon, color: BkoTheme.goldAccent, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: BkoTheme.fontLato(fontSize: 15, fontWeight: FontWeight.w800, color: BkoTheme.getTextPrimary(context))),
                  const SizedBox(height: 2),
                  Text(subtitle, style: BkoTheme.fontLato(fontSize: 12.5, color: BkoTheme.getTextSecondary(context))),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: BkoTheme.getTextSecondary(context), size: 20),
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
            color: isSelected ? Colors.black : BkoTheme.getTextSecondary(context),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bgSurf = BkoTheme.getBgSurface(context);
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
        body: const Center(child: CircularProgressIndicator(color: BkoTheme.goldAccent)),
      );
    }

    if (!homeState.hasData && homeState.error != null) {
      return Scaffold(
        backgroundColor: BkoTheme.getBgObsidian(context),
        drawer: const BkoDrawer(),
        appBar: const BkoAppHeader(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.cloud_off_rounded, size: 52, color: BkoTheme.goldAccent),
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
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Réessayer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BkoTheme.goldAccent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ],
            ),
          ),
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

    return Scaffold(
      backgroundColor: BkoTheme.getBgObsidian(context),
      drawer: const BkoDrawer(),
      body: Column(
        children: [
          const BkoAppHeader(),
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification is ScrollUpdateNotification) {
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
        onRefresh: () => ref.read(homeDataProvider.notifier).refresh(),
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
                const SizedBox(height: 20),
              ],

              // 2. Filtres Rapides
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Icon(Icons.tune_rounded, color: BkoTheme.goldAccent, size: 18),
                    const SizedBox(width: 8),
                    Text('Filtres Rapides par Thématique', style: BkoTheme.fontLato(fontSize: 16, fontWeight: FontWeight.w900, color: textPri)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    GestureDetector(
                      onTap: () => ref.read(homeDataProvider.notifier).selectCategory('all'),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: homeState.selectedCategory == 'all' ? BkoTheme.goldAccent : bgSurf,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: homeState.selectedCategory == 'all' ? BkoTheme.goldAccent : borderSub,
                          ),
                        ),
                        child: Text(
                          'Tout explorer',
                          style: BkoTheme.fontLato(
                            fontSize: 12,
                            fontWeight: homeState.selectedCategory == 'all' ? FontWeight.w900 : FontWeight.w800,
                            color: homeState.selectedCategory == 'all' ? Colors.black : textPri,
                          ),
                        ),
                      ),
                    ),
                    ...categories.map((cat) {
                      final catSlug = (cat['slug'] ?? cat['id'] ?? cat['name'])?.toString() ?? '';
                      final isActive = homeState.selectedCategory == catSlug ||
                          homeState.selectedCategory == cat['id']?.toString() ||
                          homeState.selectedCategory == cat['slug']?.toString();
                      return GestureDetector(
                        onTap: () => ref.read(homeDataProvider.notifier).selectCategory(catSlug),
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isActive ? BkoTheme.goldAccent : bgSurf,
                            border: Border.all(color: isActive ? BkoTheme.goldAccent : borderSub),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Text(
                            '${cat['name']}',
                            style: BkoTheme.fontLato(
                              fontSize: 12,
                              fontWeight: isActive ? FontWeight.w900 : FontWeight.w800,
                              color: isActive ? Colors.black : textPri,
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
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.play_arrow_rounded, color: BkoTheme.goldAccent, size: 20),
                                  const SizedBox(width: 8),
                                  Text(secTitle.isNotEmpty ? secTitle : 'Reprendre l\'écoute',
                                      style: BkoTheme.fontLato(fontSize: 18, fontWeight: FontWeight.w900, color: textPri)),
                                ],
                              ),
                              _buildDiscoverMoreButton(
                                sec['discoveryContext']?['targetUrl']?.toString(),
                                defaultTarget: '/library',
                              ),
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

                              return GestureDetector(
                                onTap: () => _triggerPlayEpisode(
                                  ep,
                                  attribution: item['attribution'] is Map ? Map<String, dynamic>.from(item['attribution']) : null,
                                ),
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
                                              errorWidget: (context, url, error) => Container(color: Colors.grey.shade900),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Text(ep['title'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                                                    style: BkoTheme.fontLato(fontSize: 13, fontWeight: FontWeight.w800, color: textPri)),
                                                const SizedBox(height: 4),
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
                    );
                  }

                  // B. Épisodes recommandés (EPISODE_ROW ou items d'épisodes)
                  if (secType == 'EPISODE_ROW' || (items.isNotEmpty && items.first['targetType'] == 'EPISODE')) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        if (secSlug == 'for-you') ...[
                                          const Icon(Icons.auto_awesome, color: BkoTheme.goldAccent, size: 20),
                                          const SizedBox(width: 8),
                                        ],
                                        Expanded(
                                          child: Text(secTitle,
                                              style: BkoTheme.fontLato(fontSize: 22, fontWeight: FontWeight.w900, color: textPri)),
                                        ),
                                      ],
                                    ),
                                    if (secSubtitle != null && secSubtitle.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(secSubtitle, style: BkoTheme.fontLato(fontSize: 12, color: textSec)),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              _buildDiscoverMoreButton(
                                sec['discoveryContext']?['targetUrl']?.toString(),
                                defaultTarget: '/explore?view=episodes',
                              ),
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
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(secTitle, style: BkoTheme.fontLato(fontSize: 20, fontWeight: FontWeight.w900, color: textPri)),
                                  if (secSubtitle != null && secSubtitle.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(secSubtitle, style: BkoTheme.fontLato(fontSize: 12, color: textSec)),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            _buildDiscoverMoreButton(
                              sec['discoveryContext']?['targetUrl']?.toString(),
                              defaultTarget: '/explore?view=podcasts',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 235,
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

                            final podCard = GestureDetector(
                              onTap: () {
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
                                width: 144,
                                margin: const EdgeInsets.only(right: 14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
                                      child: AspectRatio(
                                        aspectRatio: 1,
                                        child: CachedNetworkImage(
                                          imageUrl: p['cover'] ?? '',
                                          fit: BoxFit.cover,
                                          errorWidget: (context, url, error) => Container(color: Colors.grey.shade900),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    if (reason != null && reason.isNotEmpty) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF1E1E22),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: const Color(0xFF2C2C30)),
                                        ),
                                        child: Text(
                                          reason,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: BkoTheme.fontLato(fontSize: 9, fontWeight: FontWeight.w700, color: BkoTheme.goldAccent),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                    ],
                                    Text(p['name'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                                        style: BkoTheme.fontLato(fontSize: 13, fontWeight: FontWeight.w800, color: textPri)),
                                    const SizedBox(height: 2),
                                    Text(p['author']?['name'] ?? 'Bamako Podcast', maxLines: 1, overflow: TextOverflow.ellipsis,
                                        style: BkoTheme.fontLato(fontSize: 11, color: textSec)),
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
                        const Icon(Icons.play_arrow_rounded, color: BkoTheme.goldAccent, size: 20),
                        const SizedBox(width: 8),
                        Text('Historique de lecture', style: BkoTheme.fontLato(fontSize: 18, fontWeight: FontWeight.w900, color: textPri)),
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

                        return GestureDetector(
                          onTap: () => _triggerPlayEpisode(ep),
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
                                        errorWidget: (context, url, error) => Container(color: Colors.grey.shade900),
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
                        Text('Fraîchement publiés', style: BkoTheme.fontLato(fontSize: 22, fontWeight: FontWeight.w900, color: textPri)),
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

              // 6. Flux continu d'épisodes (Défilement infini)
              if (homeState.feedItems.isNotEmpty) ...[
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            const Icon(Icons.stream_rounded, color: BkoTheme.goldAccent, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                homeState.selectedCategory == 'all'
                                    ? 'Flux Continu d\'Épisodes'
                                    : 'Flux : ${homeState.selectedCategory}',
                                style: BkoTheme.fontLato(fontSize: 20, fontWeight: FontWeight.w900, color: textPri),
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
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: homeState.feedItems.map((ep) {
                      return EpisodeListItem(
                        episode: Map<String, dynamic>.from(ep),
                      );
                    }).toList(),
                  ),
                ),
              ],

              // Message si catégorie vide
              if (!homeState.isLoading && homeState.feedItems.isEmpty && homeState.selectedCategory != 'all') ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(Icons.search_off_rounded, color: Colors.grey, size: 40),
                        const SizedBox(height: 12),
                        Text(
                          'Aucun épisode disponible pour la thématique "${homeState.selectedCategory}".',
                          textAlign: TextAlign.center,
                          style: BkoTheme.fontLato(fontSize: 14, color: textSec, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: BkoTheme.goldAccent,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          ),
                          onPressed: () => ref.read(homeDataProvider.notifier).selectCategory('all'),
                          child: Text('Revenir à Tout explorer', style: BkoTheme.fontLato(fontSize: 12, fontWeight: FontWeight.w800)),
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
                          style: BkoTheme.fontLato(fontSize: 12, color: Colors.redAccent, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: BkoTheme.goldAccent),
                            foregroundColor: BkoTheme.goldAccent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          ),
                          onPressed: () => ref.read(homeDataProvider.notifier).fetchMoreFeed(),
                          child: Text('Réessayer', style: BkoTheme.fontLato(fontSize: 12, fontWeight: FontWeight.w800)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              // Indicateur de chargement ou fin de flux
              if (homeState.isLoadingMore) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: BkoTheme.goldAccent),
                    ),
                  ),
                ),
              ] else if (!homeState.hasMore && homeState.feedItems.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'Vous avez atteint la fin des recommandations actuelles.',
                      style: BkoTheme.fontLato(fontSize: 12, color: textSec),
                    ),
                  ),
                ),
              ],
              
              const SizedBox(height: 32),
              
              const SizedBox(height: 48),
              
              // 7. Footer CTA
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: bgSurf,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: borderSub),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: BkoTheme.goldAccent,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.mic_rounded, color: Colors.black, size: 32),
                    ),
                    const SizedBox(height: 16),
                    Text('Vous animez un podcast ?', textAlign: TextAlign.center, style: BkoTheme.fontLato(fontSize: 20, fontWeight: FontWeight.w900, color: textPri)),
                    const SizedBox(height: 8),
                    Text('Intégrez le catalogue Bamako Podcast.', textAlign: TextAlign.center, style: BkoTheme.fontLato(fontSize: 13, color: textSec)),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: BkoTheme.goldAccent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      onPressed: () => context.push('/studio'),
                      child: Text('Accéder au Studio', style: BkoTheme.fontLato(fontSize: 14, fontWeight: FontWeight.w800)),
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
    return GestureDetector(
      onTap: () => setState(() => _filterMode = mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? BkoTheme.getBgSurfaceElevated(context) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? BkoTheme.getBorderSubtle(context) : Colors.transparent),
        ),
        child: Text(
          label,
          style: BkoTheme.fontLato(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
            color: isSelected ? Colors.white : Colors.grey,
          ),
        ),
      ),
    );
  }

  Widget _buildDiscoverMoreButton(String? targetUrl, {String? defaultTarget}) {
    final url = (targetUrl != null && targetUrl.isNotEmpty) ? targetUrl : defaultTarget;
    if (url == null || url.isEmpty) return const SizedBox.shrink();

    return BkoBounceable(
      onTap: () {
        BkoHaptics.light();
        final discoveryUrl = url.startsWith('/explore')
            ? url.replaceFirst('/explore', '/discovery')
            : url;
        context.push(discoveryUrl);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF141414),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF262626)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Découvrir davantage',
              style: BkoTheme.fontLato(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: const Color(0xFFD4D4D4),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              IconsaxPlusLinear.arrow_right_3,
              size: 11,
              color: Color(0xFF888888),
            ),
          ],
        ),
      ),
    );
  }
}
