
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import '../../core/network/bko_api.dart';
import '../../core/theme/bko_theme.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/widgets/bko_bounceable.dart';
import '../../core/widgets/bko_haptics.dart';
import '../../core/widgets/equalizer_loader.dart';
import '../../core/widgets/skeleton_loaders.dart';
import '../shell/shell_providers.dart';
import '../auth/auth_controller.dart';
import '../auth/auth_modal.dart';
import '../player/full_audio_player_sheet.dart';
import '../player/widgets/bko_play_button.dart';
import '../library/library_screen.dart';
import 'widgets/episode_actions_sheet.dart';
import 'widgets/episode_list_item.dart';

class PodcastDetailsScreen extends ConsumerStatefulWidget {
  final String slug;
  const PodcastDetailsScreen({super.key, required this.slug});

  @override
  ConsumerState<PodcastDetailsScreen> createState() =>
      _PodcastDetailsScreenState();
}

class _PodcastDetailsScreenState extends ConsumerState<PodcastDetailsScreen> {
  Map<String, dynamic>? _podcast;
  List<dynamic> _episodes = [];
  List<dynamic> _similarPodcasts = [];
  String? _categoryName;
  bool _isLoading = true;
  bool _isFollowing = false;
  bool _hasMoreEpisodes = false;
  bool _loadingMoreEpisodes = false;
  String? _episodesError;
  int _episodeOffset = 0;
  bool _descriptionExpanded = false;
  bool _gridView = false;
  String _episodeSort = 'recent';
  String _episodeType = 'ALL';
  int _episodeGeneration = 0;
  bool _changingFilter = false;
  final ScrollController _pageScrollController = ScrollController();
  bool _showBackToTop = false;

  @override
  void dispose() {
    _pageScrollController.dispose();
    super.dispose();
  }

  String _episodeUrl(int offset) => Uri(
    path: '/podcasts/${Uri.encodeComponent(widget.slug)}',
    queryParameters: {
      'episodeLimit': '30', 'episodeOffset': '$offset',
      'episodeSort': _episodeSort,
      if (_episodeType != 'ALL') 'episodeType': _episodeType,
    },
  ).toString();

  Future<void> _changeEpisodeFilter({String? sort, String? type}) async {
    if ((sort ?? _episodeSort) == _episodeSort &&
        (type ?? _episodeType) == _episodeType) {
      return;
    }
    setState(() {
      _changingFilter = true;
      _episodeSort = sort ?? _episodeSort;
      _episodeType = type ?? _episodeType;
      _episodeOffset = 0;
      _hasMoreEpisodes = false;
      _episodesError = null;
      _loadingMoreEpisodes = false;
      _episodes = [];
    });
    await _loadPodcastFromApi();
  }

  @override
  void initState() {
    super.initState();
    _fetchPodcastDetails();
  }

  Future<void> _fetchPodcastDetails() => _loadPodcastFromApi();

  Widget _episodeGridCard(Map<String, dynamic> ep) {
    final cover = '${ep['cover'] ?? _podcast?['cover'] ?? ''}';
    final seconds = ep['durationSeconds'] as num? ?? 0;
    return Container(
      decoration: BoxDecoration(
        color: BkoTheme.getBgSurfaceElevated(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BkoTheme.getBorderSubtle(context)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: InkWell(
            onTap: () => context.push('/podcasts/${widget.slug}/episodes/${ep['slug'] ?? ep['id']}'),
            child: SizedBox.expand(child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: cover, fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Icon(IconsaxPlusLinear.music, color: BkoTheme.getTextSecondary(context)),
              ),
            )),
          )),
          const SizedBox(height: 8),
          Text('${ep['title'] ?? ''}', maxLines: 2, overflow: TextOverflow.ellipsis,
            style: BkoTheme.fontPoppins(fontSize: 13, fontWeight: FontWeight.w600, color: BkoTheme.getTextPrimary(context))),
          Row(children: [
            Expanded(child: Text(seconds > 0 ? '${(seconds / 60).round()} min' : '',
              style: BkoTheme.fontPoppins(fontSize: 12, color: BkoTheme.getTextSecondary(context)))),
            IconButton(tooltip: 'Actions de l’épisode',
              icon: Icon(IconsaxPlusLinear.more, color: BkoTheme.getTextSecondary(context)),
              onPressed: () => EpisodeActionsSheet.show(context, ep)),
            BkoPlayButton(
              episodeId: '${ep['id'] ?? ''}', title: '${ep['title'] ?? ''}',
              showName: '${_podcast?['name'] ?? ''}', duration: seconds > 0 ? '${(seconds / 60).round()} min' : '',
              coverUrl: cover, audioUrl: BkoApi.extractAudioUrl(ep), videoUrl: BkoApi.extractVideoUrl(ep),
              podcastSlug: widget.slug, episodeSlug: '${ep['slug'] ?? ''}',
              size: 40,
            ),
          ]),
        ]),
      ),
    );
  }

  Future<void> _loadPodcastFromApi() async {
    final generation = ++_episodeGeneration;
    try {
      final token = ref.read(authProvider).token;
      final data = await BkoApi.get(
        _episodeUrl(0),
        token: token,
      );
      if (!mounted || generation != _episodeGeneration) return;
      final podcast = data is Map ? Map<String, dynamic>.from(data) : null;
      final viewer = podcast?['viewer'] is Map ? podcast!['viewer'] as Map : null;

      final categories = podcast?['categories'] as List? ?? [];
      final firstCategory = categories.isNotEmpty && categories.first['category'] != null
          ? categories.first['category'] as Map
          : null;
      final categorySlug = firstCategory?['slug'] as String?;
      final categoryName = firstCategory?['name'] as String?;

      setState(() {
        _podcast = podcast;
        _categoryName = categoryName;
        _isFollowing = viewer?['isFollowing'] == true;
        _episodes = podcast?['episodes'] is List
            ? List<dynamic>.from(podcast!['episodes'] as List)
            : [];
        _isLoading = false;
        _changingFilter = false;
        _hasMoreEpisodes = podcast?['episodesPage']?['hasMore'] == true;
        _episodeOffset = (podcast?['episodesPage']?['nextOffset'] as num?)?.toInt() ?? _episodes.length;
      });

      _loadSimilarPodcasts(categorySlug: categorySlug);
    } catch (_) {
      if (mounted && generation == _episodeGeneration) {
        setState(() {
          _isLoading = false;
          _changingFilter = false;
          _episodesError = 'Impossible de charger les épisodes.';
        });
      }
    }
  }

  Future<void> _loadMoreEpisodes() async {
    if (_loadingMoreEpisodes || !_hasMoreEpisodes) return;
    final generation = _episodeGeneration;
    setState(() { _loadingMoreEpisodes = true; _episodesError = null; });
    try {
      final data = await BkoApi.get(
        _episodeUrl(_episodeOffset),
        token: ref.read(authProvider).token,
      );
      if (!mounted || generation != _episodeGeneration) return;
      if (data is! Map || data['episodes'] is! List) throw const FormatException('Liste invalide');
      final seen = _episodes.map((item) => item['id']).toSet();
      setState(() {
        _episodes.addAll((data['episodes'] as List).where((item) => seen.add(item['id'])));
        _hasMoreEpisodes = data['episodesPage']?['hasMore'] == true;
        _episodeOffset = (data['episodesPage']?['nextOffset'] as num?)?.toInt() ?? _episodes.length;
      });
    } catch (_) {
      if (mounted && generation == _episodeGeneration) setState(() => _episodesError = 'Impossible de charger les épisodes suivants.');
    } finally {
      if (mounted && generation == _episodeGeneration) setState(() => _loadingMoreEpisodes = false);
    }
  }

  Future<void> _loadSimilarPodcasts({String? categorySlug}) async {
    try {
      dynamic res;
      if (categorySlug != null && categorySlug.isNotEmpty) {
        res = await BkoApi.get('/podcasts?categorySlug=${Uri.encodeComponent(categorySlug)}&limit=8');
      }

      List<dynamic> list = [];
      if (res is Map && res['data'] is List) {
        list = res['data'] as List;
      } else if (res is List) {
        list = res;
      }

      // If category returned empty or none specified, load trending/general podcasts
      if (list.isEmpty) {
        final fallback = await BkoApi.get('/podcasts?limit=8');
        if (fallback is Map && fallback['data'] is List) {
          list = fallback['data'] as List;
        } else if (fallback is List) {
          list = fallback;
        }
      }

      final currentId = '${_podcast?['id'] ?? ''}';
      final filtered = list.where((p) {
        if (p is! Map) return false;
        final pId = '${p['id'] ?? ''}';
        final pSlug = '${p['slug'] ?? ''}';
        return pId != currentId && pSlug != widget.slug;
      }).toList();

      if (mounted) {
        setState(() {
          _similarPodcasts = filtered;
        });
      }
    } catch (_) {}
  }



  Future<void> _playEpisode(Map<String, dynamic> ep) async {
    final audioUrl = BkoApi.extractAudioUrl(ep);
    final videoUrl = BkoApi.extractVideoUrl(ep);
    final durationSeconds = ep['durationSeconds'] as num? ?? 0;
    final episodeId = '${ep['id'] ?? ''}';

    final active = ref.read(activeEpisodeProvider);
    final isAlreadyPlayingThis = active.hasActiveEpisode &&
        active.episodeId == episodeId &&
        active.isPlaying;

    await ref.read(activeEpisodeProvider.notifier).handlePlayOrPause(
          title: '${ep['title'] ?? ''}',
          showName: '${_podcast?['name'] ?? ''}',
          duration: durationSeconds > 0
              ? '${(durationSeconds / 60).round()} min'
              : '',
          coverUrl: '${ep['cover'] ?? _podcast?['cover'] ?? ''}',
          audioUrl: audioUrl,
          videoUrl: videoUrl,
          hasAudio: audioUrl != null,
          hasVideo: videoUrl != null,
          episodeId: episodeId,
          podcastSlug: '${_podcast?['slug'] ?? widget.slug}',
          episodeSlug: '${ep['slug'] ?? ''}',
        );

    if (!isAlreadyPlayingThis && mounted) {
      FullAudioPlayerSheet.show(context);
    }
  }

  Future<void> _toggleFollow() async {
    final podcastId = _podcast?['id'];
    final auth = ref.read(authProvider);
    if (podcastId is! String || podcastId.isEmpty) return;
    if (!auth.isAuthenticated || auth.token == null) {
      AuthRequiredModal.show(context, actionTitle: 'suivre ce podcast');
      return;
    }
    try {
      if (_isFollowing) {
        await BkoApi.delete('/podcasts/$podcastId/follow', token: auth.token);
      } else {
        await BkoApi.post('/podcasts/$podcastId/follow', {}, token: auth.token);
      }
      if (mounted) {
        setState(() => _isFollowing = !_isFollowing);
        ref.read(libraryUpdateSignalProvider.notifier).state++;
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Action impossible pour le moment.')),
        );
      }
    }
  }



  @override
  Widget build(BuildContext context) {
    final textPri = BkoTheme.getTextPrimary(context);
    final textSec = BkoTheme.getTextSecondary(context);
    final bgSurf = BkoTheme.getBgSurface(context);
    final borderSub = BkoTheme.getBorderSubtle(context);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: bgSurf,
        appBar: AppBar(
          backgroundColor: bgSurf,
          elevation: 0,
          leading: const AppBackButton(size: 18),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            children: [
              Center(
                child: BkoSkeletonBox(
                  width: 160,
                  height: 160,
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: BkoSkeletonBox(
                  width: 200,
                  height: 20,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: BkoSkeletonBox(
                  width: 120,
                  height: 14,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: BkoSkeletonBox(
                      height: 48,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  const SizedBox(width: 12),
                  BkoSkeletonBox(
                    width: 110,
                    height: 48,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Column(
                children: List.generate(
                  3,
                  (index) => const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: BkoEpisodeRowSkeleton(),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final name = _podcast?['name'] ?? widget.slug.toUpperCase();
    final description = _podcast?['description'] ??
        'Découvrez ce podcast d\'exception sur Bamako Podcast.';
    final coverUrl = _podcast?['cover'] ?? '';
    final countryFlag = _podcast?['country']?['flagEmoji'] ?? '🇲🇱';
    final countryName = _podcast?['country']?['name'] ?? 'Mali';

    final firstEpisodeId =
        _episodes.isNotEmpty ? '${_episodes.first['id'] ?? ''}' : '';

    return Scaffold(
      backgroundColor: bgSurf,
      floatingActionButton: _showBackToTop
          ? Padding(
              padding: EdgeInsets.only(
                bottom: ref.watch(activeEpisodeProvider).hasActiveEpisode ? 88 : 12,
              ),
              child: FloatingActionButton.small(
                materialTapTargetSize: MaterialTapTargetSize.padded,
                heroTag: null,
                tooltip: 'Retour en haut',
                elevation: 0,
                backgroundColor: BkoTheme.goldAccent,
                foregroundColor: BkoTheme.getBgObsidian(context),
                onPressed: () {
                  if (!_pageScrollController.hasClients) return;
                  if (MediaQuery.of(context).disableAnimations) {
                    _pageScrollController.jumpTo(0);
                  } else {
                    _pageScrollController.animateTo(0,
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeOutCubic);
                  }
                },
                child: const Icon(IconsaxPlusLinear.arrow_up_1, size: 18),
              ),
            )
          : null,
      appBar: AppBar(
        backgroundColor: bgSurf,
        elevation: 0,
        leading: const AppBackButton(size: 18),
        title: Text(
          name,
          style: BkoTheme.fontLato(
              fontSize: 16, fontWeight: FontWeight.w900, color: textPri),
        ),
        actions: [
          IconButton(
            icon: Icon(IconsaxPlusLinear.share, color: textPri, size: 20),
            onPressed: () {
              BkoHaptics.select();
            },
          ),
        ],
      ),
      body: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.depth == 0 && notification.metrics.axis == Axis.vertical) {
            final visible = notification.metrics.pixels > 500;
            if (visible != _showBackToTop) setState(() => _showBackToTop = visible);
          }
          if (notification.metrics.extentAfter < 500 && _episodesError == null) _loadMoreEpisodes();
          return handleShellScrollNotification(notification, ref);
        },
        child: CustomScrollView(
          controller: _pageScrollController,
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [            // Header Artwork & Bio
            Center(
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        color: BkoTheme.getBgSurfaceElevated(context),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: borderSub),
                      ),
                      child: coverUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: coverUrl,
                              fit: BoxFit.cover,
                              errorWidget: (context, url, error) => const Icon(
                                Icons.graphic_eq_rounded,
                                color: BkoTheme.goldAccent,
                                size: 64,
                              ),
                            )
                          : const Icon(
                              Icons.graphic_eq_rounded,
                              color: BkoTheme.goldAccent,
                              size: 64,
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    name,
                    textAlign: TextAlign.center,
                    style: BkoTheme.fontLato(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: textPri,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(countryFlag, style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                      Text(
                        countryName,
                        style: BkoTheme.fontLato(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: BkoTheme.goldAccent,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('•', style: TextStyle(color: textSec)),
                      const SizedBox(width: 8),
                      Text(
                        '${_podcast?['_count']?['episodes'] ?? _episodes.length} Épisodes',
                        style: BkoTheme.fontLato(fontSize: 12, color: textSec),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: Consumer(
                    builder: (context, ref, _) {
                      final isFirstPlaying = firstEpisodeId.isNotEmpty &&
                          ref.watch(
                            activeEpisodeProvider.select(
                              (s) =>
                                  s.hasActiveEpisode &&
                                  s.episodeId == firstEpisodeId &&
                                  s.isPlaying,
                            ),
                          );
                      return BkoBounceable(
                        onTap: () {
                          if (_episodes.isNotEmpty) {
                            _playEpisode(_episodes.first);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: BkoTheme.goldAccent,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isFirstPlaying
                                    ? IconsaxPlusBold.pause
                                    : IconsaxPlusBold.play,
                                color: Colors.black,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isFirstPlaying ? 'PAUSE' : 'ÉCOUTER',
                                style: BkoTheme.fontLato(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.0,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                BkoBounceable(
                  onTap: _toggleFollow,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: BkoTheme.getBgSurface(context),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderSub),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isFollowing
                              ? IconsaxPlusBold.tick_circle
                              : IconsaxPlusLinear.add_circle,
                          color: _isFollowing ? BkoTheme.goldAccent : textPri,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _isFollowing ? 'SUIVI' : 'SUIVRE',
                          style: BkoTheme.fontLato(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: _isFollowing ? BkoTheme.goldAccent : textPri,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Bio / Description
            Text(
              'À PROPOS',
              style: BkoTheme.fontLato(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                color: textSec,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              maxLines: _descriptionExpanded ? null : 4,
              overflow: _descriptionExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
              style: BkoTheme.fontLato(
                fontSize: 13.5,
                color: textPri,
                height: 1.4,
              ),
            ),

            if (description.length > 180)
              TextButton(
                onPressed: () => setState(() => _descriptionExpanded = !_descriptionExpanded),
                child: Text(_descriptionExpanded ? 'Masquer' : 'Afficher plus'),
              ),

            const SizedBox(height: 28),

            // Episodes List Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(
                  'ÉPISODES (${_podcast?['_count']?['episodes'] ?? _episodes.length})',
                  style: BkoTheme.fontLato(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    color: BkoTheme.goldAccent,
                  ),
                )),
                PopupMenuButton<String>(
                  tooltip: 'Format : ${_episodeType == 'ALL' ? 'Tout' : _episodeType == 'AUDIO' ? 'Audio' : 'Vidéo'}',
                  initialValue: _episodeType,
                  onSelected: (value) => _changeEpisodeFilter(type: value),
                  icon: Icon(IconsaxPlusLinear.filter,
                    color: _episodeType == 'ALL' ? textSec : BkoTheme.goldAccent, size: 20),
                  itemBuilder: (_) => ['ALL', 'AUDIO', 'VIDEO'].map((type) => CheckedPopupMenuItem<String>(
                    value: type, checked: _episodeType == type,
                    child: Text(type == 'ALL' ? 'Tous les formats' : type == 'AUDIO' ? 'Audio' : 'Vidéo'),
                  )).toList(),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Trier les épisodes',
                  icon: Icon(IconsaxPlusLinear.sort, color: textSec, size: 20),
                  initialValue: _episodeSort,
                  onSelected: (value) => _changeEpisodeFilter(sort: value),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'recent', child: Text('Plus récents')),
                    PopupMenuItem(value: 'oldest', child: Text('Plus anciens')),
                  ],
                ),
                IconButton(
                  tooltip: _gridView ? 'Afficher en liste' : 'Afficher en grille',
                  onPressed: () => setState(() => _gridView = !_gridView),
                  icon: Icon(_gridView ? IconsaxPlusLinear.row_vertical : IconsaxPlusLinear.grid_1,
                    color: textSec, size: 20),
                ),
              ],
            ),

            if (_episodeType != 'ALL' || _episodeSort != 'recent')
              Text(
                '${_episodeType == 'ALL' ? 'Tous les formats' : _episodeType == 'AUDIO' ? 'Audio' : 'Vidéo'} · ${_episodeSort == 'recent' ? 'Plus récents' : 'Plus anciens'}',
                style: BkoTheme.fontPoppins(fontSize: 12, color: textSec),
              ),

            const SizedBox(height: 14),

                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: _episodes.isEmpty
                  ? SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Text(_changingFilter ? 'Chargement des épisodes…' : 'Aucun épisode pour ces filtres.',
                          style: BkoTheme.fontLato(fontSize: 13, color: textSec)),
                      ),
                    )
                  : _gridView
                      ? SliverGrid(
                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 260,
                            mainAxisExtent: 300,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          delegate: SliverChildBuilderDelegate((context, index) {
                            final ep = Map<String, dynamic>.from(_episodes[index]);
                            ep['podcast'] ??= _podcast;
                            return _episodeGridCard(ep);
                          }, childCount: _episodes.length),
                        )
                      : SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final ep = Map<String, dynamic>.from(_episodes[index]);
                        ep['podcast'] ??= {
                          'id': _podcast?['id'],
                          'name': _podcast?['name'],
                          'slug': _podcast?['slug'],
                          'cover': _podcast?['cover'],
                        };
                        return EpisodeListItem(
                          key: ValueKey(ep['id']),
                          episode: ep,
                          showPodcastName: false,
                        );
                      }, childCount: _episodes.length),
                    ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [                        if (_loadingMoreEpisodes) const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: EqualizerLoader(
                  bars: 4,
                  size: 22,
                  color: BkoTheme.goldAccent,
                ),
              ),
            ),
            if (_hasMoreEpisodes && !_loadingMoreEpisodes) TextButton(
              onPressed: _loadMoreEpisodes,
              child: Text(_episodesError ?? 'Charger les épisodes suivants'),
            ),// Similar / Recommended Podcasts Section
            if (_similarPodcasts.isNotEmpty) ...[
              const SizedBox(height: 36),
              Row(
                children: [
                  const Icon(IconsaxPlusBold.magic_star,
                      color: BkoTheme.goldAccent, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _categoryName != null
                          ? 'DANS LA MÊME THÉMATIQUE ($_categoryName)'
                          : 'VOUS POURRIEZ AUSSI AIMER',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: BkoTheme.fontLato(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        color: BkoTheme.goldAccent,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 185,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _similarPodcasts.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 14),
                  itemBuilder: (context, index) {
                    final item =
                        Map<String, dynamic>.from(_similarPodcasts[index]);
                    final simSlug = '${item['slug'] ?? ''}';
                    final simName = '${item['name'] ?? ''}';
                    final simCover = '${item['cover'] ?? ''}';
                    final epCount = item['_count']?['episodes'] ?? 0;

                    return GestureDetector(
                      onTap: () {
                        if (simSlug.isNotEmpty) {
                          context.push('/podcasts/$simSlug');
                        }
                      },
                      child: Container(
                        width: 130,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF141416),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: borderSub),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                width: 114,
                                height: 114,
                                color: const Color(0xFF1E1E24),
                                child: simCover.isNotEmpty
                                    ? CachedNetworkImage(
                                        imageUrl: simCover,
                                        fit: BoxFit.cover,
                                        errorWidget: (_, __, ___) => const Icon(
                                          Icons.podcasts_rounded,
                                          color: BkoTheme.goldAccent,
                                          size: 32,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.podcasts_rounded,
                                        color: BkoTheme.goldAccent,
                                        size: 32,
                                      ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              simName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: BkoTheme.fontLato(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: textPri,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$epCount épisodes',
                              maxLines: 1,
                              style: BkoTheme.fontLato(
                                fontSize: 11,
                                color: textSec,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],

                    const SizedBox(height: 180),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
