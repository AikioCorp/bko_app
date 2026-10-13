import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import '../../core/network/bko_api.dart';
import '../../core/theme/bko_theme.dart';
import '../../core/widgets/bko_bounceable.dart';
import '../../core/widgets/bko_haptics.dart';
import '../../core/widgets/equalizer_loader.dart';
import '../../core/widgets/skeleton_loaders.dart';
import '../auth/auth_controller.dart';
import '../home/widgets/bko_drawer.dart';
import '../home/widgets/episode_list_item.dart';
import '../shell/shell_providers.dart';

class ExploreScreen extends ConsumerStatefulWidget {
  final String? initialQuery;
  final String? initialCategory;
  final String? initialLang;
  final String? initialDuration;
  final String? initialSort;
  final String? initialView;
  final bool isStandalone;

  const ExploreScreen({
    super.key,
    this.initialQuery,
    this.initialCategory,
    this.initialLang,
    this.initialDuration,
    this.initialSort,
    this.initialView,
    this.isStandalone = false,
  });

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  late final TextEditingController _searchController;
  Timer? _debounce;
  final ScrollController _scrollController = ScrollController();

  late String _activeView; // 'episodes' or 'podcasts'
  String? _selectedCategory; // category slug
  String? _selectedLang; // language code ('bm', 'fr', etc.)
  late String _selectedDuration; // 'ALL', 'SHORT', 'MEDIUM', 'LONG'
  late String _sortOrder; // 'recent', 'oldest', 'popular'
  String _query = '';

  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _errorMessage;
  int _offset = 0;

  List<dynamic> _episodes = [];
  List<dynamic> _podcasts = [];

  List<dynamic> _categories = [];
  List<dynamic> _languages = [];

  @override
  void initState() {
    super.initState();
    _query = widget.initialQuery ?? '';
    _searchController = TextEditingController(text: _query);
    _activeView = widget.initialView == 'podcasts' ? 'podcasts' : 'episodes';
    _selectedCategory = widget.initialCategory;
    _selectedLang = widget.initialLang;
    _selectedDuration = widget.initialDuration ?? 'ALL';
    _sortOrder = widget.initialSort ?? 'recent';

    _scrollController.addListener(_onScroll);
    _fetchTaxonomies();
    _fetchCatalog(reset: true);
  }

  @override
  void didUpdateWidget(covariant ExploreScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialCategory != widget.initialCategory ||
        oldWidget.initialDuration != widget.initialDuration ||
        oldWidget.initialLang != widget.initialLang ||
        oldWidget.initialSort != widget.initialSort ||
        oldWidget.initialView != widget.initialView ||
        oldWidget.initialQuery != widget.initialQuery) {
      setState(() {
        _query = widget.initialQuery ?? '';
        _searchController.text = _query;
        _activeView = widget.initialView == 'podcasts' ? 'podcasts' : 'episodes';
        _selectedCategory = widget.initialCategory;
        _selectedLang = widget.initialLang;
        _selectedDuration = widget.initialDuration ?? 'ALL';
        _sortOrder = widget.initialSort ?? 'recent';
      });
      _fetchCatalog(reset: true);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    if (currentScroll >= maxScroll - 350 && !_isLoading && !_isLoadingMore && _hasMore) {
      _fetchCatalog(reset: false);
    }
  }

  Future<void> _fetchTaxonomies() async {
    try {
      final exploreData = await BkoApi.get('/explore');

      if (!mounted) return;
      setState(() {
        if (exploreData is Map) {
          _categories = (exploreData['categories'] as List?) ?? [];
          _languages = (exploreData['languages'] as List?) ?? [];
        }
      });
    } catch (_) {}
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() {
        _query = value.trim();
      });
      _fetchCatalog(reset: true);
    });
  }

  Future<void> _fetchCatalog({bool reset = false}) async {
    if (reset) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _offset = 0;
        _hasMore = true;
      });
    } else {
      if (_isLoadingMore || !_hasMore) return;
      setState(() => _isLoadingMore = true);
    }

    try {
      if (_activeView == 'episodes') {
        final queryParams = <String, String>{
          'limit': '20',
          'offset': '$_offset',
          'sort': _sortOrder,
        };
        if (_query.isNotEmpty) queryParams['q'] = _query;
        if (_selectedCategory != null && _selectedCategory!.isNotEmpty) {
          queryParams['category'] = _selectedCategory!;
        }
        if (_selectedLang != null && _selectedLang!.isNotEmpty) {
          queryParams['lang'] = _selectedLang!;
        }
        if (_selectedDuration != 'ALL') {
          queryParams['duration'] = _selectedDuration;
        }

        final queryString = Uri(queryParameters: queryParams).query;
        final res = await BkoApi.get('/episodes/catalog?$queryString');

        if (!mounted) return;
        List<dynamic> newItems = [];
        bool more = false;

        if (res is Map) {
          newItems = (res['data'] as List?) ?? [];
          final meta = res['meta'];
          if (meta is Map && meta['hasMore'] != null) {
            more = meta['hasMore'] == true;
          } else {
            more = newItems.length >= 20;
          }
        } else if (res is List) {
          newItems = res;
          more = newItems.length >= 20;
        }

        setState(() {
          if (reset) {
            _episodes = newItems;
          } else {
            final existingIds = _episodes.map((e) => e['id']).toSet();
            final uniqueNew = newItems.where((e) => !existingIds.contains(e['id'])).toList();
            _episodes.addAll(uniqueNew);
          }
          _offset += newItems.length;
          _hasMore = more;
          _isLoading = false;
          _isLoadingMore = false;
        });
      } else {
        final queryParams = <String, String>{
          'limit': '20',
          'offset': '$_offset',
          'sort': _sortOrder,
        };
        if (_query.isNotEmpty) queryParams['q'] = _query;
        if (_selectedCategory != null && _selectedCategory!.isNotEmpty) {
          queryParams['category'] = _selectedCategory!;
        }
        if (_selectedLang != null && _selectedLang!.isNotEmpty) {
          queryParams['language'] = _selectedLang!;
        }

        final queryString = Uri(queryParameters: queryParams).query;
        final res = await BkoApi.get('/podcasts?$queryString');

        if (!mounted) return;
        List<dynamic> newItems = [];
        bool more = false;

        if (res is Map) {
          newItems = (res['data'] as List?) ?? [];
          final pagination = res['pagination'] ?? res['meta'];
          if (pagination is Map && pagination['hasMore'] != null) {
            more = pagination['hasMore'] == true;
          } else {
            more = newItems.length >= 20;
          }
        } else if (res is List) {
          newItems = res;
          more = newItems.length >= 20;
        }

        setState(() {
          if (reset) {
            _podcasts = newItems;
          } else {
            final existingIds = _podcasts.map((p) => p['id']).toSet();
            final uniqueNew = newItems.where((p) => !existingIds.contains(p['id'])).toList();
            _podcasts.addAll(uniqueNew);
          }
          _offset += newItems.length;
          _hasMore = more;
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Impossible de charger le catalogue';
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  void _triggerPlayEpisode(Map<String, dynamic> ep) {
    BkoHaptics.light();
    final title = ep['title'] ?? 'Épisode';
    final podcastName = ep['podcast']?['name']?.toString() ?? ep['showName']?.toString() ?? '';
    final durationSeconds = ep['durationSeconds'] ?? 1800;
    final duration = '${(durationSeconds / 60).round()} min';
    final cover = ep['cover'] ?? ep['podcast']?['cover'] ?? '';
    final audioUrl = BkoApi.extractAudioUrl(ep);
    final videoUrl = BkoApi.extractVideoUrl(ep);
    final episodeId = '${ep['id'] ?? ''}';

    ref.read(activeEpisodeProvider.notifier).handlePlayOrPause(
          title: title,
          showName: podcastName,
          duration: duration,
          coverUrl: cover,
          audioUrl: audioUrl,
          videoUrl: videoUrl,
          hasAudio: audioUrl != null,
          hasVideo: videoUrl != null,
          episodeId: episodeId,
          podcastSlug: '${ep['podcast']?['slug'] ?? ''}',
          episodeSlug: '${ep['slug'] ?? ''}',
        );
  }

  void _clearAllFilters() {
    BkoHaptics.light();
    _searchController.clear();
    setState(() {
      _query = '';
      _selectedCategory = null;
      _selectedLang = null;
      _selectedDuration = 'ALL';
      _sortOrder = 'recent';
    });
    _fetchCatalog(reset: true);
  }

  String _getCategoryName(String slug) {
    final cat = _categories.firstWhere(
      (c) => c['slug'] == slug,
      orElse: () => null,
    );
    return cat?['name'] ?? slug;
  }

  String _getLanguageName(String code) {
    if (code == 'bm') return 'Bambara';
    if (code == 'fr') return 'Français';
    final lang = _languages.firstWhere(
      (l) => l['code'] == code,
      orElse: () => null,
    );
    return lang?['name'] ?? code.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final textPri = BkoTheme.getTextPrimary(context);
    final textSec = BkoTheme.getTextSecondary(context);
    final surface = BkoTheme.getBgSurface(context);
    final border = BkoTheme.getBorderSubtle(context);
    final canPop = widget.isStandalone || Navigator.canPop(context);
    final auth = ref.watch(authProvider);

    final hasActiveFilters = (_selectedCategory != null && _selectedCategory!.isNotEmpty) ||
        (_selectedLang != null && _selectedLang!.isNotEmpty) ||
        _selectedDuration != 'ALL' ||
        _sortOrder != 'recent' ||
        _query.isNotEmpty;

    return Scaffold(
      backgroundColor: BkoTheme.getBgObsidian(context),
      drawer: const BkoDrawer(),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Header avec bouton retour et recherche
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (canPop) ...[
                        BkoBounceable(
                          onTap: () {
                            BkoHaptics.light();
                            context.pop();
                          },
                          child: Container(
                            width: 38,
                            height: 38,
                            margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              color: surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: border),
                            ),
                            child: const Center(
                              child: Icon(
                                IconsaxPlusLinear.arrow_left_1,
                                size: 18,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ] else if (auth.isAuthenticated) ...[
                        BkoBounceable(
                          onTap: () {
                            BkoHaptics.light();
                            Scaffold.of(context).openDrawer();
                          },
                          child: Container(
                            width: 44,
                            height: 44,
                            alignment: Alignment.center,
                            margin: const EdgeInsets.only(right: 6),
                            child: Icon(
                              IconsaxPlusLinear.menu_1,
                              size: 22,
                              color: textPri,
                            ),
                          ),
                        ),
                      ],
                      Expanded(
                        child: Text(
                          canPop ? 'Découverte' : 'Explorer',
                          style: BkoTheme.fontLato(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: textPri,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Search Bar
                  TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                    style: BkoTheme.fontLato(fontSize: 14, color: textPri),
                    decoration: InputDecoration(
                      hintText: 'Rechercher une émission, un épisode...',
                      hintStyle: BkoTheme.fontLato(fontSize: 14, color: textSec),
                      prefixIcon: Icon(IconsaxPlusLinear.search_normal_1, color: textSec, size: 18),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(IconsaxPlusLinear.close_circle, color: textSec, size: 18),
                              onPressed: () {
                                BkoHaptics.light();
                                _searchController.clear();
                                _onSearchChanged('');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: surface,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: BkoTheme.goldAccent),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 2. Switcher de Vues (Épisodes / Émissions) & Tri
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _buildViewTab('Épisodes', 'episodes'),
                  const SizedBox(width: 8),
                  _buildViewTab('Émissions', 'podcasts'),
                  const Spacer(),
                  // Tri dropdown chip
                  _buildSortSelector(surface, border, textPri, textSec),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // 3. Pastilles de Filtres Actifs (Chips dismissibles)
            if (hasActiveFilters) ...[
              SizedBox(
                height: 34,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    if (_selectedCategory != null && _selectedCategory!.isNotEmpty)
                      _buildFilterChip(
                        label: 'Thème: ${_getCategoryName(_selectedCategory!)}',
                        onRemove: () {
                          setState(() => _selectedCategory = null);
                          _fetchCatalog(reset: true);
                        },
                      ),
                    if (_selectedLang != null && _selectedLang!.isNotEmpty)
                      _buildFilterChip(
                        label: 'Langue: ${_getLanguageName(_selectedLang!)}',
                        onRemove: () {
                          setState(() => _selectedLang = null);
                          _fetchCatalog(reset: true);
                        },
                      ),
                    if (_selectedDuration != 'ALL')
                      _buildFilterChip(
                        label: 'Durée: ${_selectedDuration == 'SHORT' ? '< 20 min' : _selectedDuration == 'MEDIUM' ? '20-45 min' : '> 45 min'}',
                        onRemove: () {
                          setState(() => _selectedDuration = 'ALL');
                          _fetchCatalog(reset: true);
                        },
                      ),
                    if (_sortOrder != 'recent')
                      _buildFilterChip(
                        label: 'Tri: ${_sortOrder == 'popular' ? 'Populaires' : 'Anciens'}',
                        onRemove: () {
                          setState(() => _sortOrder = 'recent');
                          _fetchCatalog(reset: true);
                        },
                      ),
                    if (_query.isNotEmpty)
                      _buildFilterChip(
                        label: 'Recherche: "$_query"',
                        onRemove: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      ),
                    BkoBounceable(
                      onTap: _clearAllFilters,
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(IconsaxPlusLinear.trash, size: 12, color: Colors.redAccent),
                            const SizedBox(width: 4),
                            Text(
                              'Tout effacer',
                              style: BkoTheme.fontLato(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Colors.redAccent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],

            // 4. Corps de résultats paginé
            Expanded(
              child: _isLoading
                  ? _buildSkeletonList()
                  : _errorMessage != null
                      ? _buildErrorView()
                      : _buildResultsList(textPri, textSec, surface, border),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewTab(String label, String view) {
    final isActive = _activeView == view;
    return BkoBounceable(
      onTap: () {
        if (_activeView == view) return;
        BkoHaptics.select();
        setState(() => _activeView = view);
        _fetchCatalog(reset: true);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? BkoTheme.goldAccent : const Color(0xFF141414),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? BkoTheme.goldAccent : const Color(0xFF262626),
          ),
        ),
        child: Text(
          label,
          style: BkoTheme.fontLato(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: isActive ? Colors.black : const Color(0xFFA0A0A0),
          ),
        ),
      ),
    );
  }

  Widget _buildSortSelector(Color surface, Color border, Color textPri, Color textSec) {
    return PopupMenuButton<String>(
      onSelected: (value) {
        if (_sortOrder == value) return;
        BkoHaptics.light();
        setState(() => _sortOrder = value);
        _fetchCatalog(reset: true);
      },
      color: const Color(0xFF181818),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFF2C2C2C)),
      ),
      itemBuilder: (context) => [
        _buildPopupItem('recent', 'Plus récents'),
        _buildPopupItem('popular', 'Plus populaires'),
        _buildPopupItem('oldest', 'Plus anciens'),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(IconsaxPlusLinear.sort, size: 14, color: BkoTheme.goldAccent),
            const SizedBox(width: 6),
            Text(
              _sortOrder == 'popular'
                  ? 'Populaires'
                  : _sortOrder == 'oldest'
                      ? 'Anciens'
                      : 'Récents',
              style: BkoTheme.fontLato(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: textPri,
              ),
            ),
            const SizedBox(width: 4),
            Icon(IconsaxPlusLinear.arrow_down_1, size: 12, color: textSec),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<String> _buildPopupItem(String value, String label) {
    final isSelected = _sortOrder == value;
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: BkoTheme.fontLato(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
              color: isSelected ? BkoTheme.goldAccent : Colors.white,
            ),
          ),
          if (isSelected)
            const Icon(IconsaxPlusLinear.tick_circle, size: 14, color: BkoTheme.goldAccent),
        ],
      ),
    );
  }

  Widget _buildFilterChip({required String label, required VoidCallback onRemove}) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF181818),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: BkoTheme.fontLato(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 6),
          BkoBounceable(
            onTap: () {
              BkoHaptics.light();
              onRemove();
            },
            child: const Icon(
              IconsaxPlusLinear.close_circle,
              size: 14,
              color: Color(0xFF888888),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonList() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
      itemCount: 6,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) => const BkoEpisodeRowSkeleton(),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(IconsaxPlusLinear.warning_2, size: 44, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? 'Une erreur est survenue',
              style: BkoTheme.fontLato(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: BkoTheme.goldAccent,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () => _fetchCatalog(reset: true),
              child: Text('Réessayer', style: BkoTheme.fontLato(fontSize: 13, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsList(Color textPri, Color textSec, Color surface, Color border) {
    final Widget content;
    if (_activeView == 'episodes') {
      if (_episodes.isEmpty) {
        content = _buildEmptyState(textPri, textSec);
      } else {
        content = ListView.builder(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          itemCount: _episodes.length + (_hasMore ? 1 : 0),
          itemBuilder: (context, index) {
          if (index == _episodes.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: EqualizerLoader(
                  bars: 4,
                  size: 22,
                  color: BkoTheme.goldAccent,
                ),
              ),
            );
          }

          final ep = Map<String, dynamic>.from(_episodes[index]);
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: EpisodeListItem(
              episode: ep,
              onPlay: () => _triggerPlayEpisode(ep),
            ),
          );
        },
      );
    }
    } else {
      if (_podcasts.isEmpty) {
        content = _buildEmptyState(textPri, textSec);
      } else {
        content = GridView.builder(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.76,
        ),
        itemCount: _podcasts.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _podcasts.length) {
            return const Center(
              child: EqualizerLoader(
                bars: 4,
                size: 22,
                color: BkoTheme.goldAccent,
              ),
            );
          }

          final pod = Map<String, dynamic>.from(_podcasts[index]);
          final cover = pod['cover'] ?? '';
          final name = pod['name'] ?? 'Émission';
          final authorCandidate = pod['author']?['name'] ??
              pod['author']?['fullName'] ??
              pod['organization']?['name'];
          final authorStr = (authorCandidate != null &&
                  authorCandidate.toString().trim().isNotEmpty &&
                  authorCandidate.toString().trim().toLowerCase() != 'bamako podcast')
              ? authorCandidate.toString().trim()
              : null;
          final lang = pod['primaryLanguage']?['name']?.toString();
          final subtitleParts = [
            if (authorStr != null) authorStr,
            if (lang != null && lang.isNotEmpty) lang,
          ];
          final author = subtitleParts.join(' • ');
          final count = pod['_count']?['episodes'] as num? ?? 0;

          return BkoBounceable(
            onTap: () {
              BkoHaptics.select();
              context.push('/podcasts/${pod['slug']}');
            },
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CachedNetworkImage(
                            imageUrl: cover,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Container(color: Colors.grey.shade900),
                          ),
                          Positioned(
                            top: 6,
                            right: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '$count ép.',
                                style: BkoTheme.fontLato(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: BkoTheme.fontLato(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: textPri,
                    ),
                  ),
                  if (author.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: BkoTheme.fontLato(fontSize: 11, color: textSec),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      );
    }
    }

    return RefreshIndicator(
      color: BkoTheme.goldAccent,
      backgroundColor: surface,
      onRefresh: () async {
        BkoHaptics.light();
        await _fetchCatalog(reset: true);
        BkoHaptics.select();
      },
      child: content,
    );
  }

  Widget _buildEmptyState(Color textPri, Color textSec) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              IconsaxPlusLinear.search_status_1,
              size: 54,
              color: textSec.withValues(alpha: 0.35),
            ),
            const SizedBox(height: 16),
            Text(
              'Aucun résultat trouvé',
              style: BkoTheme.fontLato(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: textPri,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Essayez de modifier ou de retirer certains filtres actifs pour élargir votre recherche.',
              textAlign: TextAlign.center,
              style: BkoTheme.fontLato(fontSize: 13, color: textSec),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: BkoTheme.goldAccent,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              onPressed: _clearAllFilters,
              child: Text(
                'Réinitialiser les filtres',
                style: BkoTheme.fontLato(fontSize: 13, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
