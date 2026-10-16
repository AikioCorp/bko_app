import '../../core/widgets/app_header_actions.dart';
import 'section_page.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import '../../core/network/bko_api.dart';
import '../../core/network/bko_telemetry.dart';
import '../../core/theme/bko_theme.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/widgets/bko_bounceable.dart';
import '../../core/widgets/bko_haptics.dart';
import '../../core/widgets/equalizer_loader.dart';
import '../../core/widgets/skeleton_loaders.dart';
import '../auth/auth_controller.dart';
import '../home/home_providers.dart';
import '../home/widgets/episode_list_item.dart';
import '../player/full_audio_player_sheet.dart';
import '../shell/shell_providers.dart';

/// Écran de découverte dédié et extensible prolongeant fidèlement un rayon
/// d'accueil (titre, sous-titre, filtres réels, pagination continue côté serveur).
class SectionDiscoveryScreen extends ConsumerStatefulWidget {
  final String sectionId;
  final String? initialSlug;
  final String? initialTitle;
  final String? initialSubtitle;
  final String? initialType;
  final String? category;
  final String? country;
  final String? batchId;

  const SectionDiscoveryScreen({
    super.key,
    required this.sectionId,
    this.initialSlug,
    this.initialTitle,
    this.initialSubtitle,
    this.initialType,
    this.category,
    this.country,
    this.batchId,
  });

  @override
  ConsumerState<SectionDiscoveryScreen> createState() =>
      _SectionDiscoveryScreenState();
}

class _SectionDiscoveryScreenState
    extends ConsumerState<SectionDiscoveryScreen> {
  final ScrollController _scrollController = ScrollController();

  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasError = false;
  String _errorMessage = '';

  Map<String, dynamic> _sectionMeta = {};
  final List<Map<String, dynamic>> _items = [];

  int _offset = 0;
  static const int _limit = 20;
  int _total = 0;
  bool _hasMore = false;

  // Filtre audio/vidéo pour les listes d'épisodes
  String _filterMode = 'ALL'; // 'ALL' | 'AUDIO' | 'VIDEO'

  @override
  void initState() {
    super.initState();
    _sectionMeta = {
      'id': widget.sectionId,
      'slug': widget.initialSlug ?? widget.sectionId,
      'title': widget.initialTitle ?? '',
      'subtitle': widget.initialSubtitle,
      'type': widget.initialType ?? 'EPISODE_ROW',
    };

    _loadFromHomeCache();
    _scrollController.addListener(_onScroll);
    _fetchSection(isRefresh: true);
  }

  void _loadFromHomeCache() {
    try {
      final homeState = ref.read(homeDataProvider);
      final homeData = homeState.homeData;
      if (homeData == null) return;

      final sections = homeData['sections'] is List ? homeData['sections'] as List : [];
      Map<String, dynamic>? match;
      for (final s in sections) {
        if (s is Map) {
          final sId = s['id']?.toString() ?? '';
          final sSlug = s['slug']?.toString() ?? '';
          if (sId == widget.sectionId ||
              sSlug == widget.sectionId ||
              (widget.initialSlug != null && (sSlug == widget.initialSlug || sId == widget.initialSlug))) {
            match = Map<String, dynamic>.from(s);
            break;
          }
        }
      }

      if (match != null) {
        final rawItems = match['items'] is List ? List<dynamic>.from(match['items']) : [];
        final parsedItems = rawItems
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();

        _sectionMeta = {
          ..._sectionMeta,
          ...match,
        };
        if (parsedItems.isNotEmpty) {
          _items.clear();
          _items.addAll(parsedItems);
          _offset = parsedItems.length;
          _total = parsedItems.length;
          _isLoading = false;
          _hasError = false;
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    if (maxScroll - currentScroll <= 300) {
      if (!_loadingFirstPage && !_isLoadingMore && _hasMore && _loadMoreError == null) {
        _fetchMore();
      }
    }
  }

  int _requestGeneration = 0;
  bool _loadingFirstPage = false;
  String? _loadMoreError;
  bool _serverPageLoaded = false;

  String _itemKey(Map<String, dynamic> item) =>
      '${item['targetType']}:${item['episode']?['id'] ?? item['podcast']?['id'] ?? item['collection']?['id'] ?? item['id']}';

  Future<SectionPage> _requestPage(int offset) async {
    final parameters = <String, String>{'offset': '$offset', 'limit': '$_limit'};
    if (widget.category != null && widget.category != 'all') parameters['category'] = widget.category!;
    if (widget.country != null) parameters['country'] = widget.country!;
    if (widget.batchId != null) parameters['batchId'] = widget.batchId!;
    final token = ref.read(authProvider).token;
    final slug = widget.initialSlug ?? widget.sectionId;
    Future<dynamic> request(String id) => BkoApi.get(
      Uri(path: '/home/sections/$id', queryParameters: parameters).toString(), token: token);
    dynamic payload;
    try {
      payload = await request(slug);
    } on ApiException catch (error) {
      if (error.statusCode != 404 || slug == widget.sectionId) rethrow;
      payload = await request(widget.sectionId);
    }
    return SectionPage.parse(payload);
  }

  Future<void> _fetchSection({bool isRefresh = false}) async {
    if (!mounted || _loadingFirstPage) return;
    final generation = ++_requestGeneration;
    setState(() {
      _loadingFirstPage = true;
      _isLoading = _items.isEmpty;
      _isLoadingMore = false;
      _hasError = false;
      _loadMoreError = null;
      _errorMessage = '';
    });
    try {
      final page = await _requestPage(0);
      if (!mounted || generation != _requestGeneration) return;
      final seen = <String>{};
      setState(() {
        _sectionMeta = {..._sectionMeta, ...page.section};
        _items.clear();
        _items.addAll(page.items.where((item) => seen.add(_itemKey(item))));
        _offset = page.nextOffset;
        _total = page.total;
        _hasMore = page.hasMore;
        _serverPageLoaded = true;
      });
    } catch (error) {
      if (!mounted || generation != _requestGeneration) return;
      setState(() {
        _hasError = true;
        _errorMessage = error is ApiException ? error.message
            : 'Impossible de charger cette sélection. Réessayez.';
      });
    } finally {
      if (mounted && generation == _requestGeneration) {
        setState(() { _isLoading = false; _loadingFirstPage = false; });
      }
    }
  }

  Future<void> _fetchMore() async {
    if (_isLoadingMore || _loadingFirstPage || !_hasMore) return;
    final generation = _requestGeneration;
    setState(() { _isLoadingMore = true; _loadMoreError = null; });
    try {
      final page = await _requestPage(_offset);
      if (!mounted || generation != _requestGeneration) return;
      if (page.nextOffset <= _offset && page.hasMore) {
        throw const FormatException('Pagination sans progression');
      }
      final seen = _items.map(_itemKey).toSet();
      setState(() {
        _items.addAll(page.items.where((item) => seen.add(_itemKey(item))));
        _offset = page.nextOffset;
        _total = page.total;
        _hasMore = page.hasMore;
      });
    } catch (_) {
      if (mounted && generation == _requestGeneration) {
        setState(() => _loadMoreError = 'Impossible de charger la suite. Réessayez.');
      }
    } finally {
      if (mounted && generation == _requestGeneration) {
        setState(() => _isLoadingMore = false);
      }
    }
  }
  void _triggerPlayEpisode(Map<String, dynamic> ep, {Map<String, dynamic>? attribution}) {
    if (ep.isEmpty) return;
    final podcastName = ep['podcast']?['name'] ??
        ep['showName'] ??
        ep['author'] ??
        ep['podcast']?['author'] ??
        'Podcast';
    final title = ep['title'] ?? 'Épisode';
    final durationSeconds = ep['durationSeconds'] ?? 1800;
    final duration = '${(durationSeconds / 60).round()} min';
    final cover = ep['cover'] ?? ep['podcast']?['cover'] ?? '';
    final audioUrl = BkoApi.extractAudioUrl(ep);
    final videoUrl = BkoApi.extractVideoUrl(ep);
    final episodeId = '${ep['id'] ?? ''}';
    final hasAudioTrack = audioUrl != null;

    final batchId = attribution?['batchId']?.toString();
    final sectionId = _sectionMeta['id']?.toString() ?? widget.sectionId;
    final sectionSlug = _sectionMeta['slug']?.toString() ?? '';

    ref.read(activeEpisodeProvider.notifier).handlePlayOrPause(
          title: title,
          showName: podcastName,
          duration: duration,
          coverUrl: cover,
          audioUrl: audioUrl,
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

    FullAudioPlayerSheet.show(context);

    if (batchId != null) {
      BkoTelemetryService().trackInteraction(
        batchId: batchId,
        sectionId: sectionId,
        sectionSlug: sectionSlug,
        targetType: 'EPISODE',
        targetId: episodeId,
        action: 'PLAY_START',
        token: ref.read(authProvider).token,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgObs = BkoTheme.getBgObsidian(context);
    final bgSurf = BkoTheme.getBgSurface(context);
    final borderSub = BkoTheme.getBorderSubtle(context);
    final textPri = BkoTheme.getTextPrimary(context);
    final textSec = BkoTheme.getTextSecondary(context);

    final title = _sectionMeta['title']?.toString() ?? widget.initialTitle ?? 'Découvrir';
    final subtitle = _sectionMeta['subtitle']?.toString() ?? widget.initialSubtitle;
    final type = _sectionMeta['type']?.toString() ?? widget.initialType ?? 'EPISODE_ROW';
    final isPodcastRow = type == 'PODCAST_ROW';

    final filteredItems = _items.where((item) {
      if (!isPodcastRow && _filterMode != 'ALL') {
        final ep = item['episode'] is Map ? Map<String, dynamic>.from(item['episode']) : null;
        if (ep != null) {
          final isVid = BkoApi.extractVideoUrl(ep) != null;
          if (_filterMode == 'VIDEO' && !isVid) return false;
          if (_filterMode == 'AUDIO' && isVid) return false;
        }
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: bgObs,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Top Bar
            _buildTopBar(context, textPri, borderSub),

            // Lazy Slivers Scroll Area
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => _fetchSection(isRefresh: true),
                color: BkoTheme.goldAccent,
                backgroundColor: bgSurf,
                child: _isLoading && _items.isEmpty
                    ? _buildLoadingState(isPodcastRow)
                    : _hasError && _items.isEmpty
                        ? _buildErrorState(textPri, textSec, bgSurf, borderSub)
                        : _items.isEmpty
                            ? _buildEmptyState(textPri, textSec, bgSurf, borderSub)
                            : CustomScrollView(
                                controller: _scrollController,
                                slivers: [
                                  // Section Header Banner
                                  SliverToBoxAdapter(
                                    child: _buildSectionHeader(
                                      title: title,
                                      subtitle: subtitle,
                                      totalCount: _serverPageLoaded ? _total : 0,
                                      isPodcast: isPodcastRow,
                                      textPri: textPri,
                                      textSec: textSec,
                                      bgSurf: bgSurf,
                                      borderSub: borderSub,
                                    ),
                                  ),

                                  // Format Filter Chips (Episodes only)
                                  if (_loadingFirstPage || _hasError)
                                    SliverToBoxAdapter(child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      child: _loadingFirstPage
                                          ? const Center(child: EqualizerLoader(size: 20))
                                          : Column(children: [
                                              Text(_errorMessage, style: BkoTheme.fontPoppins(fontSize: 13, color: textSec)),
                                              TextButton(onPressed: () => _fetchSection(isRefresh: true), child: const Text('Réessayer')),
                                            ]),
                                    )),
                                  if (!isPodcastRow)
                                    SliverToBoxAdapter(
                                      child: Padding(
                                        padding: const EdgeInsets.only(bottom: 16),
                                        child: _buildFormatChips(bgSurf, borderSub, textPri),
                                      ),
                                    ),

                                  // Content Grid or List
                                  if (isPodcastRow)
                                    SliverPadding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      sliver: SliverGrid(
                                        delegate: SliverChildBuilderDelegate(
                                          (context, index) {
                                            final item = filteredItems[index];
                                            final p = item['podcast'] is Map
                                                ? Map<String, dynamic>.from(item['podcast'])
                                                : <String, dynamic>{};
                                            if (p.isEmpty) return const SizedBox.shrink();
                                            return _buildPodcastCard(context, p, item);
                                          },
                                          childCount: filteredItems.length,
                                        ),
                                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: 2,
                                          crossAxisSpacing: 16,
                                          mainAxisSpacing: 16,
                                          childAspectRatio: 0.68,
                                        ),
                                      ),
                                    )
                                  else
                                    SliverPadding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      sliver: SliverList(
                                        delegate: SliverChildBuilderDelegate(
                                          (context, index) {
                                            final item = filteredItems[index];
                                            final ep = item['episode'] is Map
                                                ? Map<String, dynamic>.from(item['episode'])
                                                : <String, dynamic>{};
                                            if (ep.isEmpty) return const SizedBox.shrink();
                                            final attribution = item['attribution'] is Map
                                                ? Map<String, dynamic>.from(item['attribution'])
                                                : null;
                                            return Padding(
                                              padding: const EdgeInsets.only(bottom: 8),
                                              child: EpisodeListItem(
                                                episode: ep,
                                                recommendationReason: item['reason']?.toString(),
                                                onPlay: () => _triggerPlayEpisode(ep, attribution: attribution),
                                              ),
                                            );
                                          },
                                          childCount: filteredItems.length,
                                        ),
                                      ),
                                    ),

                                  // Pagination loading indicator
                                  if (_isLoadingMore)
                                    const SliverToBoxAdapter(
                                      child: Padding(
                                        padding: EdgeInsets.symmetric(vertical: 24),
                                        child: Center(child: EqualizerLoader(size: 20)),
                                      ),
                                    ),

                                  // End of list confirmation
                                  if (_hasMore && !_isLoadingMore && !_loadingFirstPage)
                                    SliverToBoxAdapter(child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(children: [
                                        if (_loadMoreError != null) Text(_loadMoreError!, style: BkoTheme.fontPoppins(fontSize: 13, color: textSec)),
                                        TextButton(onPressed: _fetchMore,
                                          child: Text(_loadMoreError == null ? 'Charger davantage' : 'Réessayer')),
                                      ]),
                                    )),
                                  if (_serverPageLoaded && !_hasMore && _items.isNotEmpty)
                                    SliverToBoxAdapter(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 32),
                                        child: Center(
                                          child: Text(
                                            'Vous avez parcouru l\'ensemble de cette sélection.',
                                            style: BkoTheme.fontLato(
                                              fontSize: 12,
                                              color: textSec.withValues(alpha: 0.7),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),

                                  // Bottom padding 120px for mini-player
                                  const SliverToBoxAdapter(
                                    child: SizedBox(height: 120),
                                  ),
                                ],
                              ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, Color textPri, Color borderSub) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: BkoTheme.getBgObsidian(context),
        border: Border(bottom: BorderSide(color: borderSub, width: 0.8)),
      ),
      child: Row(
        children: [
          const AppBackButton(),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _sectionMeta['title']?.toString() ?? widget.initialTitle ?? 'Découvrir',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: BkoTheme.fontPoppins(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: textPri,
              ),
            ),
          ),
          const AppHeaderActions(),
          BkoBounceable(
            onTap: () {
              BkoHaptics.light();
              _fetchSection(isRefresh: true);
            },
            child: Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              child: Icon(
                IconsaxPlusLinear.refresh_2,
                size: 20,
                color: textPri.withValues(alpha: 0.8),
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String? subtitle,
    required int totalCount,
    required bool isPodcast,
    required Color textPri,
    required Color textSec,
    required Color bgSurf,
    required Color borderSub,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: bgSurf,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: borderSub),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPodcast
                          ? IconsaxPlusLinear.microphone
                          : IconsaxPlusLinear.play_circle,
                      size: 14,
                      color: BkoTheme.getAccent(context),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isPodcast ? 'Émissions' : 'Épisodes',
                      style: BkoTheme.fontLato(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: BkoTheme.getAccent(context),
                      ),
                    ),
                  ],
                ),
              ),
              if (totalCount > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: bgSurf,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: borderSub),
                  ),
                  child: Text(
                    '$totalCount disponible${totalCount > 1 ? 's' : ''}',
                    style: BkoTheme.fontLato(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: textSec,
                    ),
                  ),
                ),
              ],
              if (widget.category != null && widget.category!.isNotEmpty && widget.category != 'all') ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: bgSurf,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: borderSub),
                  ),
                  child: Text(
                    widget.category!,
                    style: BkoTheme.fontLato(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: textSec,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: BkoTheme.fontPoppins(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: textPri,
              height: 1.25,
            ),
          ),
          if (subtitle != null && subtitle.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: BkoTheme.fontLato(
                fontSize: 13,
                color: textSec,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFormatChips(Color bgSurf, Color borderSub, Color textPri) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildFilterChip('Tous', 'ALL', bgSurf, borderSub, textPri),
          const SizedBox(width: 8),
          _buildFilterChip('Audio', 'AUDIO', bgSurf, borderSub, textPri),
          const SizedBox(width: 8),
          _buildFilterChip('Vidéo', 'VIDEO', bgSurf, borderSub, textPri),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    String label,
    String mode,
    Color bgSurf,
    Color borderSub,
    Color textPri,
  ) {
    final isSelected = _filterMode == mode;
    return BkoBounceable(
      onTap: () {
        BkoHaptics.select();
        setState(() => _filterMode = mode);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? BkoTheme.goldAccent : bgSurf,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? BkoTheme.goldAccent : borderSub,
          ),
        ),
        child: Text(
          label,
          style: BkoTheme.fontLato(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
            color: isSelected ? Theme.of(context).colorScheme.onPrimary : textPri,
          ),
        ),
      ),
    );
  }

  Widget _buildPodcastCard(
    BuildContext context,
    Map<String, dynamic> podcast,
    Map<String, dynamic> item,
  ) {
    final name = podcast['name']?.toString() ?? '';
    final slug = podcast['slug']?.toString() ?? '';
    final cover = podcast['cover']?.toString() ?? '';
    final author = podcast['author']?.toString() ??
        podcast['organization']?['name']?.toString() ??
        '';
    final epCount = (podcast['_count']?['episodes'] as num?)?.toInt() ??
        (podcast['episodesCount'] as num?)?.toInt() ??
        0;
    final lang = podcast['primaryLanguage']?['name']?.toString() ??
        podcast['primaryLanguageCode']?.toString() ??
        '';

    final bgSurf = BkoTheme.getBgSurface(context);
    final bgElev = BkoTheme.getBgSurfaceElevated(context);
    final borderSub = BkoTheme.getBorderSubtle(context);
    final textPri = BkoTheme.getTextPrimary(context);
    final textSec = BkoTheme.getTextSecondary(context);

    final attribution = item['attribution'] is Map ? Map<String, dynamic>.from(item['attribution']) : null;
    final batchId = attribution?['batchId']?.toString();

    return BkoBounceable(
      onTap: () {
        BkoHaptics.light();
        if (attribution != null) {
          BkoTelemetryService().trackInteraction(
            batchId: batchId ?? '',
            sectionId: _sectionMeta['id']?.toString() ?? widget.sectionId,
            sectionSlug: _sectionMeta['slug']?.toString() ?? '',
            targetType: 'PODCAST',
            targetId: podcast['id']?.toString() ?? '',
            action: 'CLICK',
            token: ref.read(authProvider).token,
          );
        }
        context.push('/podcasts/$slug');
      },
      child: Container(
        decoration: BoxDecoration(
          color: bgSurf,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderSub),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1.0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: cover,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(
                    color: bgElev,
                    alignment: Alignment.center,
                    child: Icon(
                      IconsaxPlusLinear.microphone,
                      color: textSec,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: BkoTheme.fontLato(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: textPri,
                height: 1.25,
              ),
            ),
            const Spacer(),
            Row(
              children: [
                if (epCount > 0) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: bgElev,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: borderSub),
                    ),
                    child: Text(
                      '$epCount ép.',
                      style: BkoTheme.fontLato(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: BkoTheme.getAccent(context),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    author.isNotEmpty ? author : (lang.isNotEmpty ? lang : 'BKO'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: BkoTheme.fontLato(
                      fontSize: 11,
                      color: textSec,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState(bool isPodcast) {
    return CustomScrollView(
      physics: const NeverScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BkoSkeletonBox(width: 180, height: 24, borderRadius: BorderRadius.circular(8)),
                const SizedBox(height: 8),
                BkoSkeletonBox(width: 256, height: 16, borderRadius: BorderRadius.circular(4)),
              ],
            ),
          ),
        ),
        if (isPodcast)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.68,
              ),
              delegate: SliverChildBuilderDelegate(
                (_, __) => BkoSkeletonBox(
                  width: double.infinity,
                  height: double.infinity,
                  borderRadius: BorderRadius.circular(16),
                ),
                childCount: 6,
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, __) => const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: BkoEpisodeRowSkeleton(),
                ),
                childCount: 6,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildErrorState(Color textPri, Color textSec, Color bgSurf, Color borderSub) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: bgSurf,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderSub),
              ),
              child: Icon(
                IconsaxPlusLinear.warning_2,
                color: Theme.of(context).colorScheme.error,
                size: 28,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Oups, impossible de charger',
              style: BkoTheme.fontPoppins(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: textPri,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage.isNotEmpty ? _errorMessage : 'Une erreur inattendue est survenue.',
              textAlign: TextAlign.center,
              style: BkoTheme.fontLato(fontSize: 13, color: textSec),
            ),
            const SizedBox(height: 24),
            BkoBounceable(
              onTap: () {
                BkoHaptics.light();
                _fetchSection(isRefresh: true);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: BkoTheme.goldAccent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'Réessayer',
                  style: BkoTheme.fontLato(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(Color textPri, Color textSec, Color bgSurf, Color borderSub) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: bgSurf,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderSub),
              ),
              child: Icon(
                IconsaxPlusLinear.document_text_1,
                color: textSec,
                size: 26,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Aucun contenu dans cette section',
              style: BkoTheme.fontPoppins(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: textPri,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Revenez bientôt ou découvrez les autres sélections de Bamako Podcast.',
              textAlign: TextAlign.center,
              style: BkoTheme.fontLato(fontSize: 13, color: textSec),
            ),
            const SizedBox(height: 24),
            BkoBounceable(
              onTap: () {
                BkoHaptics.light();
                context.pop();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: bgSurf,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderSub),
                ),
                child: Text(
                  'Retour à l\'accueil',
                  style: BkoTheme.fontLato(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: textPri,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
