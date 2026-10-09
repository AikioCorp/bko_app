import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/network/bko_api.dart';
import '../../core/theme/bko_theme.dart';
import '../shell/shell_providers.dart';

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  
  bool _isLoadingInit = true;
  bool _isSearching = false;
  
  String _query = '';
  String _activeTab = 'all'; // all, podcasts, episodes
  
  List<dynamic> _trending = [];
  List<dynamic> _categories = [];
  
  List<dynamic> _searchPodcasts = [];
  List<dynamic> _searchEpisodes = [];

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchInitialData() async {
    try {
      final exploreData = await BkoApi.get('/explore');
      final homeData = await BkoApi.get('/home?country=all');

      if (!mounted) return;
      setState(() {
        if (exploreData is Map) {
          _categories = (exploreData['categories'] as List?) ?? [];
          // Filter categories with > 0 podcasts like web
          _categories = _categories.where((c) => (c['_count']?['podcasts'] ?? 0) > 0).toList();
        }
        if (homeData is Map) {
          _trending = (homeData['trending'] as List?) ?? [];
        }
        _isLoadingInit = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingInit = false);
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      setState(() {
        _query = value.trim();
      });
      if (_query.length >= 2) {
        _performSearch();
      } else {
        setState(() {
          _searchPodcasts = [];
          _searchEpisodes = [];
        });
      }
    });
  }

  Future<void> _performSearch() async {
    setState(() => _isSearching = true);
    try {
      final data = await BkoApi.get('/search?q=${Uri.encodeQueryComponent(_query)}');
      if (!mounted) return;
      setState(() {
        if (data is Map) {
          _searchPodcasts = (data['podcasts'] as List?) ?? [];
          _searchEpisodes = (data['episodes'] as List?) ?? [];
        } else {
          _searchPodcasts = [];
          _searchEpisodes = [];
        }
        _isSearching = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _isSearching = false;
          _searchPodcasts = [];
          _searchEpisodes = [];
        });
      }
    }
  }

  void _playEpisode(Map<String, dynamic> ep) {
    final title = ep['title'] ?? 'Épisode';
    final podcastName = ep['podcast']?['name'] ?? 'Bamako Podcast';
    final durationSeconds = ep['durationSeconds'] ?? 1800;
    final duration = '${(durationSeconds / 60).round()} min';
    final cover = ep['cover'] ?? ep['podcast']?['cover'] ?? '';
    final audioUrl = BkoApi.extractAudioUrl(ep);
    final videoUrl = BkoApi.extractVideoUrl(ep);

    ref.read(activeEpisodeProvider.notifier).playEpisode(
          title: title,
          showName: podcastName,
          duration: duration,
          coverUrl: cover,
          audioUrl: audioUrl,
          videoUrl: videoUrl,
          hasAudio: audioUrl != null,
          hasVideo: videoUrl != null,
          episodeId: '${ep['id'] ?? ''}',
          podcastSlug: '${ep['podcast']?['slug'] ?? ''}',
        );
  }

  @override
  Widget build(BuildContext context) {
    final textPri = BkoTheme.getTextPrimary(context);
    final textSec = BkoTheme.getTextSecondary(context);
    final surface = BkoTheme.getBgSurface(context);
    final border = BkoTheme.getBorderSubtle(context);

    return Scaffold(
      backgroundColor: BkoTheme.getBgObsidian(context),
      body: SafeArea(
        child: _isLoadingInit
            ? const Center(child: CircularProgressIndicator(color: BkoTheme.goldAccent))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header & Search Bar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Explorer', style: BkoTheme.fontLato(fontSize: 28, fontWeight: FontWeight.w900, color: textPri)),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _searchController,
                          onChanged: _onSearchChanged,
                          style: BkoTheme.fontLato(fontSize: 15, color: textPri),
                          decoration: InputDecoration(
                            hintText: 'Rechercher une émission, un épisode...',
                            hintStyle: BkoTheme.fontLato(fontSize: 15, color: textSec),
                            prefixIcon: Icon(Icons.search_rounded, color: textSec),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: Icon(Icons.close_rounded, color: textSec),
                                    onPressed: () {
                                      _searchController.clear();
                                      _onSearchChanged('');
                                    },
                                  )
                                : null,
                            filled: true,
                            fillColor: surface,
                            contentPadding: const EdgeInsets.symmetric(vertical: 14),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: border)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: border)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: BkoTheme.goldAccent)),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Content Body
                  Expanded(
                    child: _query.length < 2
                        ? _buildExploreDefaultMode(textPri, textSec, surface, border)
                        : _buildSearchResultsMode(textPri, textSec, surface, border),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildExploreDefaultMode(Color textPri, Color textSec, Color surface, Color border) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_trending.isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.trending_up_rounded, color: BkoTheme.goldAccent, size: 20),
                const SizedBox(width: 8),
                Text('Tendances du moment', style: BkoTheme.fontLato(fontSize: 14, fontWeight: FontWeight.w900, color: BkoTheme.goldAccent, letterSpacing: 1.1)),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 160,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _trending.length > 6 ? 6 : _trending.length,
                itemBuilder: (context, index) {
                  final podcast = _trending[index];
                  return GestureDetector(
                    onTap: () => context.push('/podcasts/${podcast['slug']}'),
                    child: Container(
                      width: 120,
                      margin: const EdgeInsets.only(right: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: AspectRatio(
                              aspectRatio: 1,
                              child: CachedNetworkImage(
                                imageUrl: podcast['cover'] ?? '',
                                fit: BoxFit.cover,
                                errorWidget: (context, url, error) => Container(color: Colors.grey.shade900),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(podcast['name'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: BkoTheme.fontLato(fontSize: 13, fontWeight: FontWeight.w800, color: textPri)),
                          const SizedBox(height: 2),
                          Text(podcast['author']?['fullName'] ?? 'Bamako Podcast', maxLines: 1, overflow: TextOverflow.ellipsis, style: BkoTheme.fontLato(fontSize: 11, color: textSec)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 32),
          ],
          
          if (_categories.isNotEmpty) ...[
            Text('Parcourir par catégorie', style: BkoTheme.fontLato(fontSize: 14, fontWeight: FontWeight.w900, color: textPri, letterSpacing: 1.1)),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.8,
              ),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final cat = _categories[index];
                return GestureDetector(
                  onTap: () {
                    // For now on mobile, redirect to search with this category? Or we just set query to category name.
                    // Web has a dedicated /categories/[slug] page.
                    // If we don't have it, we can just trigger a search.
                    _searchController.text = cat['name'] ?? '';
                    _onSearchChanged(cat['name'] ?? '');
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: BkoTheme.getBgObsidian(context),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.radio_rounded, color: Colors.grey, size: 16),
                            ),
                            Text('${cat['_count']?['podcasts'] ?? 0}', style: BkoTheme.fontLato(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.grey)),
                          ],
                        ),
                        Text(cat['name'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: BkoTheme.fontLato(fontSize: 14, fontWeight: FontWeight.w800, color: textPri)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchResultsMode(Color textPri, Color textSec, Color surface, Color border) {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator(color: BkoTheme.goldAccent));
    }

    if (_searchPodcasts.isEmpty && _searchEpisodes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 48, color: textSec.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text('Aucun résultat pour "$_query"', style: BkoTheme.fontLato(fontSize: 15, color: textSec)),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tabs
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _buildTabBtn('Tous les résultats (${_searchPodcasts.length + _searchEpisodes.length})', 'all'),
              const SizedBox(width: 8),
              _buildTabBtn('Podcasts (${_searchPodcasts.length})', 'podcasts'),
              const SizedBox(width: 8),
              _buildTabBtn('Épisodes (${_searchEpisodes.length})', 'episodes'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
            children: [
              if ((_activeTab == 'all' || _activeTab == 'podcasts') && _searchPodcasts.isNotEmpty) ...[
                Text('Podcasts', style: BkoTheme.fontLato(fontSize: 16, fontWeight: FontWeight.w900, color: textPri)),
                const SizedBox(height: 12),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.8,
                  ),
                  itemCount: _searchPodcasts.length,
                  itemBuilder: (context, index) {
                    final p = _searchPodcasts[index];
                    return GestureDetector(
                      onTap: () => context.push('/podcasts/${p['slug']}'),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
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
                            Text(p['name'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: BkoTheme.fontLato(fontSize: 13, fontWeight: FontWeight.w800, color: textPri)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
              ],

              if ((_activeTab == 'all' || _activeTab == 'episodes') && _searchEpisodes.isNotEmpty) ...[
                Text('Épisodes', style: BkoTheme.fontLato(fontSize: 16, fontWeight: FontWeight.w900, color: textPri)),
                const SizedBox(height: 12),
                ..._searchEpisodes.map((ep) {
                  return GestureDetector(
                    onTap: () => _playEpisode(ep as Map<String, dynamic>),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: border),
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: CachedNetworkImage(
                              imageUrl: ep['cover'] ?? ep['podcast']?['cover'] ?? '',
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                              errorWidget: (context, url, error) => Container(color: Colors.grey.shade900),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(ep['title'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: BkoTheme.fontLato(fontSize: 14, fontWeight: FontWeight.w800, color: textPri)),
                                const SizedBox(height: 4),
                                Text('${ep['podcast']?['name'] ?? ''} • ${((ep['durationSeconds'] ?? 1800) / 60).round()} min', maxLines: 1, overflow: TextOverflow.ellipsis, style: BkoTheme.fontLato(fontSize: 12, color: textSec)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.play_circle_fill_rounded, color: BkoTheme.goldAccent, size: 36),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTabBtn(String label, String mode) {
    final isSelected = _activeTab == mode;
    return GestureDetector(
      onTap: () => setState(() => _activeTab = mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? BkoTheme.goldAccent : BkoTheme.getBgSurfaceElevated(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? BkoTheme.goldAccent : BkoTheme.getBorderSubtle(context)),
        ),
        child: Text(
          label,
          style: BkoTheme.fontLato(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
            color: isSelected ? Colors.black : Colors.grey,
          ),
        ),
      ),
    );
  }
}
