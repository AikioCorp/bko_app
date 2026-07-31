import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/network/bko_api.dart';
import '../../core/theme/bko_theme.dart';
import '../../core/theme/theme_provider.dart';
import '../shell/shell_providers.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  List<dynamic> _podcasts = [];
  List<dynamic> _episodes = [];
  List<dynamic> _categories = [];
  bool _isLoading = true;
  String _selectedCategorySlug = 'all';
  final Set<String> _myList = {};

  @override
  void initState() {
    super.initState();
    _fetchHomeData();
  }

  Future<void> _fetchHomeData() => _loadHomeFromApi();

  // ignore: unused_element
  Future<void> _fetchHomeDataLegacy() async {
    final candidateHosts = [
      '127.0.0.1',
      '192.168.1.2',
      'localhost',
      '10.0.2.2'
    ];

    for (final host in candidateHosts) {
      try {
        final client = HttpClient()
          ..connectionTimeout = const Duration(seconds: 2);
        List<dynamic> fetchedCategories = [];
        List<dynamic> allPodcasts = [];
        List<dynamic> extractedEps = [];

        // 1. Fetch Explore (Categories)
        try {
          final exploreReq = await client
              .getUrl(Uri.parse('http://$host:8080/api/v1/explore'));
          final exploreRes = await exploreReq.close();
          if (exploreRes.statusCode == 200) {
            final body = await exploreRes.transform(utf8.decoder).join();
            final json = jsonDecode(body);
            if (json['success'] == true &&
                json['data'] != null &&
                json['data']['categories'] != null) {
              fetchedCategories = json['data']['categories'];
            }
          }
        } catch (_) {}

        // 2. Fetch Podcasts (Filtered by Category if selected)
        try {
          final podUrl = _selectedCategorySlug == 'all'
              ? 'http://$host:8080/api/v1/podcasts?limit=100'
              : 'http://$host:8080/api/v1/podcasts?categorySlug=$_selectedCategorySlug&limit=100';

          final podsReq = await client.getUrl(Uri.parse(podUrl));
          final podsRes = await podsReq.close();

          if (podsRes.statusCode == 200) {
            final body = await podsRes.transform(utf8.decoder).join();
            final json = jsonDecode(body);
            if (json['success'] == true && json['data'] != null) {
              final list = (json['data'] is List)
                  ? json['data']
                  : (json['data']['data'] as List<dynamic>? ?? []);
              allPodcasts = List.from(list);
              for (var p in allPodcasts) {
                if (p['episodes'] != null && p['episodes'] is List) {
                  for (var ep in p['episodes']) {
                    extractedEps.add({
                      ...ep,
                      'podcast': {
                        'name': p['name'],
                        'cover': p['cover'],
                        'slug': p['slug']
                      },
                    });
                  }
                }
              }
            }
          }
        } catch (_) {}

        // 3. Fetch Home Sections
        try {
          final homeReq = await client
              .getUrl(Uri.parse('http://$host:8080/api/v1/home?country=all'));
          final homeRes = await homeReq.close();
          if (homeRes.statusCode == 200) {
            final body = await homeRes.transform(utf8.decoder).join();
            final json = jsonDecode(body);
            if (json['success'] == true && json['data'] != null) {
              final trending = json['data']['trending'] as List<dynamic>?;
              final sections = json['data']['sections'] as List<dynamic>?;

              if (trending != null && _selectedCategorySlug == 'all') {
                for (var t in trending) {
                  if (!allPodcasts.any((p) => p['id'] == t['id'])) {
                    allPodcasts.add(t);
                  }
                }
              }

              if (sections != null) {
                for (var sec in sections) {
                  if (sec['items'] != null) {
                    for (var item in sec['items']) {
                      if (item['podcast'] != null &&
                          _selectedCategorySlug == 'all') {
                        if (!allPodcasts
                            .any((p) => p['id'] == item['podcast']['id'])) {
                          allPodcasts.add(item['podcast']);
                        }
                      }
                      if (item['episode'] != null) {
                        if (!extractedEps
                            .any((e) => e['id'] == item['episode']['id'])) {
                          extractedEps.add(item['episode']);
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        } catch (_) {}

        if (allPodcasts.isNotEmpty || extractedEps.isNotEmpty) {
          debugPrint(
              'Host $host success: ${allPodcasts.length} podcasts, ${extractedEps.length} episodes');
          if (mounted) {
            setState(() {
              _categories = fetchedCategories;
              _podcasts = allPodcasts;
              _episodes = extractedEps;
              _isLoading = false;
            });
          }
          return;
        }
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadHomeFromApi() async {
    try {
      final explore = await BkoApi.get('/explore');
      final podcasts = await BkoApi.get(
        _selectedCategorySlug == 'all'
            ? '/podcasts?limit=100'
            : '/podcasts?categorySlug=${Uri.encodeQueryComponent(_selectedCategorySlug)}&limit=100',
      );
      final recent = await BkoApi.get('/episodes/recent?limit=30');
      if (!mounted) return;
      setState(() {
        _categories = explore is Map && explore['categories'] is List
            ? List<dynamic>.from(explore['categories'] as List)
            : [];
        _podcasts = _asList(podcasts);
        _episodes = recent is Map && recent['episodes'] is List
            ? List<dynamic>.from(recent['episodes'] as List)
            : _asList(recent);
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<dynamic> _asList(dynamic value) {
    if (value is List) return List<dynamic>.from(value);
    if (value is Map && value['data'] is List) {
      return List<dynamic>.from(value['data'] as List);
    }
    return [];
  }

  void _triggerPlayEpisode(
      String title, String show, String duration, String cover,
      {String? audioUrl, String? videoUrl, bool? hasAudio, bool? hasVideo}) {
    ref.read(activeEpisodeProvider.notifier).playEpisode(
          title: title,
          showName: show,
          duration: duration,
          coverUrl: cover,
          audioUrl: audioUrl,
          videoUrl: videoUrl,
          hasAudio: hasAudio,
          hasVideo: hasVideo,
        );
  }

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
          padding: EdgeInsets.fromLTRB(
              20, 16, 20, bottomInset > 0 ? bottomInset + 16 : 24),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(32),
              topRight: Radius.circular(32),
            ),
            border: Border.all(color: border, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
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
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: textSec.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // User Info Header Card
              Container(
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
                        border:
                            Border.all(color: BkoTheme.goldAccent, width: 2),
                      ),
                      child: Center(
                        child: Text(
                          'S',
                          style: BkoTheme.fontLato(
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Salika Famanta',
                                style: BkoTheme.fontLato(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: textPri,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: BkoTheme.goldAccent
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                      color: BkoTheme.goldAccent
                                          .withValues(alpha: 0.4)),
                                ),
                                child: Text(
                                  'ADMIN',
                                  style: BkoTheme.fontLato(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w900,
                                    color: BkoTheme.goldAccent,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'salika.famanta@gmail.com',
                            style:
                                BkoTheme.fontLato(fontSize: 12, color: textSec),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              Text(
                'COMPTE & ESPACES',
                style: BkoTheme.fontLato(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.8,
                  color: textSec,
                ),
              ),
              const SizedBox(height: 12),

              _buildProfileMenuItem(
                context,
                icon: Icons.person_outline_rounded,
                title: 'Mon Profil & Compte',
                subtitle: 'Gérer vos informations personnelles',
                onTap: () {
                  Navigator.pop(context);
                  context.go('/profile');
                },
              ),
              const SizedBox(height: 10),

              _buildProfileMenuItem(
                context,
                icon: Icons.mic_external_on_outlined,
                title: 'Studio Créateur & Admin',
                subtitle: 'Publier et administrer vos épisodes',
                badgeText: 'STUDIO',
                onTap: () {
                  Navigator.pop(context);
                  context.go('/studio');
                },
              ),
              const SizedBox(height: 10),

              _buildProfileMenuItem(
                context,
                icon: Icons.bookmark_border_rounded,
                title: 'Bibliothèque & Favoris',
                subtitle: 'Retrouver vos sauvegardes',
                onTap: () {
                  Navigator.pop(context);
                  context.go('/library');
                },
              ),

              const SizedBox(height: 22),

              Text(
                'THÈME DE L\'APPLICATION',
                style: BkoTheme.fontLato(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.8,
                  color: textSec,
                ),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _buildCompactThemePill(
                      context,
                      label: 'Auto',
                      icon: Icons.phone_android_rounded,
                      isSelected: currentSetting == AppThemeSetting.system,
                      onTap: () {
                        ref
                            .read(themeSettingProvider.notifier)
                            .setThemeSetting(AppThemeSetting.system);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildCompactThemePill(
                      context,
                      label: 'Sombre',
                      icon: Icons.dark_mode_rounded,
                      isSelected: currentSetting == AppThemeSetting.dark,
                      onTap: () {
                        ref
                            .read(themeSettingProvider.notifier)
                            .setThemeSetting(AppThemeSetting.dark);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildCompactThemePill(
                      context,
                      label: 'Clair',
                      icon: Icons.light_mode_rounded,
                      isSelected: currentSetting == AppThemeSetting.light,
                      onTap: () {
                        ref
                            .read(themeSettingProvider.notifier)
                            .setThemeSetting(AppThemeSetting.light);
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProfileMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    String? badgeText,
    required VoidCallback onTap,
  }) {
    final textPri = BkoTheme.getTextPrimary(context);
    final textSec = BkoTheme.getTextSecondary(context);
    final border = BkoTheme.getBorderSubtle(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: BkoTheme.getBgSurfaceElevated(context),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border, width: 1),
        ),
        child: Row(
          children: [
            Icon(icon, color: BkoTheme.goldAccent, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: BkoTheme.fontLato(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: textPri,
                        ),
                      ),
                      if (badgeText != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: BkoTheme.goldAccent,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badgeText,
                            style: BkoTheme.fontLato(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w900,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: BkoTheme.fontLato(fontSize: 11, color: textSec),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: textSec, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactThemePill(
    BuildContext context, {
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? BkoTheme.goldAccent
              : BkoTheme.getBgSurfaceElevated(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? BkoTheme.goldAccent
                : BkoTheme.getBorderSubtle(context),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? Colors.black
                  : BkoTheme.getTextSecondary(context),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: BkoTheme.fontLato(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                color: isSelected
                    ? Colors.black
                    : BkoTheme.getTextSecondary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textSec = BkoTheme.getTextSecondary(context);
    final bgSurf = BkoTheme.getBgSurface(context);
    final borderSub = BkoTheme.getBorderSubtle(context);

    final podcastsList = _podcasts;
    final episodesList = _episodes;

    final categoryItems = [
      {'name': 'Tous', 'slug': 'all'},
      ..._categories.map(
          (c) => {'name': '${c['name'] ?? ''}', 'slug': '${c['slug'] ?? ''}'}),
    ];

    return Scaffold(
      backgroundColor: BkoTheme.getBgObsidian(context),
      appBar: AppBar(
        titleSpacing: 16,
        title: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: bgSurf,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderSub, width: 1),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: Image.asset(
              'assets/brand/app_icon.png',
              width: 38,
              height: 38,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.mic_rounded,
                color: BkoTheme.goldAccent,
                size: 22,
              ),
            ),
          ),
        ),
        actions: [
          // Right: Clean Professional Avatar Circle
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: () => _openUserProfileModal(context),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF8B5CF6),
                  border: Border.all(color: BkoTheme.goldAccent, width: 1.5),
                ),
                child: Center(
                  child: Text(
                    'S',
                    style: BkoTheme.fontLato(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? _buildSkeletonLoading(context)
          : NotificationListener<ScrollNotification>(
              onNotification: (scrollNotification) {
                final hasActiveEpisode =
                    ref.read(activeEpisodeProvider).hasActiveEpisode;

                if (scrollNotification.metrics.pixels >=
                    scrollNotification.metrics.maxScrollExtent - 20) {
                  ref
                      .read(shellNavVisibilityProvider.notifier)
                      .setVisible(true);
                  return false;
                }

                if (scrollNotification is UserScrollNotification) {
                  if (scrollNotification.direction == ScrollDirection.reverse) {
                    if (hasActiveEpisode) {
                      ref
                          .read(shellNavVisibilityProvider.notifier)
                          .setVisible(false);
                    } else {
                      ref
                          .read(shellNavVisibilityProvider.notifier)
                          .setVisible(true);
                    }
                  } else if (scrollNotification.direction ==
                      ScrollDirection.forward) {
                    ref
                        .read(shellNavVisibilityProvider.notifier)
                        .setVisible(true);
                  }
                }
                return false;
              },
              child: RefreshIndicator(
                onRefresh: _fetchHomeData,
                color: BkoTheme.goldAccent,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. TOP FILTER PILLS SYSTEM (Spotify Style)
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: categoryItems.map((cat) {
                            final slug = cat['slug'] ?? 'all';
                            final name = cat['name'] ?? 'Tous';
                            final isSelected = _selectedCategorySlug == slug;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: GestureDetector(
                                onTap: () {
                                  if (_selectedCategorySlug != slug) {
                                    setState(() {
                                      _selectedCategorySlug = slug;
                                      _isLoading = true;
                                    });
                                    _fetchHomeData();
                                  }
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 18, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? BkoTheme.getActivePillBg(context)
                                        : bgSurf,
                                    borderRadius: BorderRadius.circular(22),
                                    border: Border.all(
                                      color: isSelected
                                          ? BkoTheme.getActivePillBg(context)
                                          : borderSub,
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    name,
                                    style: BkoTheme.fontLato(
                                      fontSize: 12.5,
                                      fontWeight: isSelected
                                          ? FontWeight.w900
                                          : FontWeight.w700,
                                      color: isSelected
                                          ? BkoTheme.getActivePillText(context)
                                          : textSec,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // 2. SECTION "LANCER LA LECTURE" (Spotify Quick Launch)
                      _buildSectionHeader(context,
                          badge: 'SESSIONS', title: 'Lancer la lecture'),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          children: [
                            _buildQuickLaunchItem(
                              context,
                              title: 'Victoire',
                              artist: 'DJ KEROZEN',
                              coverUrl:
                                  'https://img.youtube.com/vi/KWhVBP8YQaM/maxresdefault.jpg',
                              onPlay: () {
                                _triggerPlayEpisode(
                                    'Victoire',
                                    'DJ KEROZEN',
                                    '3:45',
                                    'https://img.youtube.com/vi/KWhVBP8YQaM/maxresdefault.jpg');
                              },
                            ),
                            _buildQuickLaunchItem(
                              context,
                              title: 'What A Beautiful Name',
                              artist: 'Hillsong Worship, Brooke Ligertwood',
                              coverUrl:
                                  'https://img.youtube.com/vi/Rr6vUM3pKqc/maxresdefault.jpg',
                              onPlay: () {
                                _triggerPlayEpisode(
                                    'What A Beautiful Name',
                                    'Hillsong Worship',
                                    '5:42',
                                    'https://img.youtube.com/vi/Rr6vUM3pKqc/maxresdefault.jpg');
                              },
                            ),
                            _buildQuickLaunchItem(
                              context,
                              title: 'Tu es digne',
                              artist: 'Pasteur Yves Castanou',
                              coverUrl:
                                  'https://img.youtube.com/vi/xS_Z1P6pUwo/maxresdefault.jpg',
                              onPlay: () {
                                _triggerPlayEpisode(
                                    'Tu es digne',
                                    'Pasteur Yves Castanou',
                                    '8:12',
                                    'https://img.youtube.com/vi/xS_Z1P6pUwo/maxresdefault.jpg');
                              },
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 28),

                      // 3. SECTION "ÉPISODES POUR VOUS" (Spotify Rich Tinted Cards)
                      _buildSectionHeader(context,
                          badge: 'RECOMMANDATION', title: 'Épisodes pour vous'),
                      const SizedBox(height: 14),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          children: episodesList.map((ep) {
                            final title = ep['title'] as String;
                            final podcastName =
                                ep['podcast']?['name'] ?? 'Bko Podcast';
                            final date = ep['date'] ?? 'il y a 6 jours';
                            final duration =
                                '${((ep['durationSeconds'] ?? 1800) / 60).round()} min';
                            final desc = ep['description'] ??
                                'Découvrez cet épisode exclusif sur Bamako Podcast.';
                            final cover = ep['cover'] ??
                                'https://img.youtube.com/vi/KWhVBP8YQaM/maxresdefault.jpg';
                            final bgColor = ep['bgColor'] as Color? ??
                                const Color(0xFF2E0854);
                            final isInList = _myList.contains(title);

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: _buildSpotifyTintedEpisodeCard(
                                context,
                                title: title,
                                podcastName: podcastName,
                                dateAndDuration: '$date • $duration',
                                description: desc,
                                coverUrl: cover,
                                cardBgColor: bgColor,
                                isInList: isInList,
                                onAddToList: () {
                                  setState(() {
                                    if (isInList) {
                                      _myList.remove(title);
                                    } else {
                                      _myList.add(title);
                                    }
                                  });
                                },
                                onPlay: () {
                                  _triggerPlayEpisode(
                                      title, podcastName, duration, cover);
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // 4. SECTION "EXPLOREZ VOS GENRES" (Spotify Vertical Poster Grid)
                      _buildSectionHeader(context,
                          badge: 'GENRES', title: 'Explorez vos genres'),
                      const SizedBox(height: 14),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            _buildGenrePosterCard(
                              context,
                              hashtag: '#congolese hip hop',
                              coverUrl:
                                  'https://img.youtube.com/vi/xS_Z1P6pUwo/maxresdefault.jpg',
                            ),
                            const SizedBox(width: 14),
                            _buildGenrePosterCard(
                              context,
                              hashtag: '#gospel',
                              coverUrl:
                                  'https://img.youtube.com/vi/Rr6vUM3pKqc/maxresdefault.jpg',
                            ),
                            const SizedBox(width: 14),
                            _buildGenrePosterCard(
                              context,
                              hashtag: '#afrobeat latino',
                              coverUrl:
                                  'https://img.youtube.com/vi/dNr-ffzV3C0/maxresdefault.jpg',
                            ),
                            const SizedBox(width: 14),
                            _buildGenrePosterCard(
                              context,
                              hashtag: '#mali culture',
                              coverUrl:
                                  'https://img.youtube.com/vi/KWhVBP8YQaM/maxresdefault.jpg',
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // 5. SECTION "RADIO TENDANCE"
                      _buildSectionHeader(context,
                          badge: 'RADIO', title: 'Radio tendance'),
                      const SizedBox(height: 14),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            _buildRadioCard(
                              context,
                              title: 'Fatim Diabate',
                              artists:
                                  'Djelykaba bintou, Yama Sega, Mah Kouyaté...',
                              bgColor: const Color(0xFFC0ED43),
                            ),
                            const SizedBox(width: 14),
                            _buildRadioCard(
                              context,
                              title: 'Djoss Saramani',
                              artists: 'Adji One Centhiago, Fatô Diamatigui...',
                              bgColor: const Color(0xFFFCD34D),
                            ),
                            const SizedBox(width: 14),
                            _buildRadioCard(
                              context,
                              title: 'Young Po',
                              artists: 'Bg, Leviz, Iba One, Sidiki Diabaté...',
                              bgColor: const Color(0xFFF87171),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // 6. SECTION "POPULAIRES À BAMAKO"
                      _buildSectionHeader(context,
                          badge: 'TENDANCES', title: 'Populaires à Bamako'),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: podcastsList.asMap().entries.map((entry) {
                            final rank = entry.key + 1;
                            final p = entry.value;
                            return Padding(
                              padding: const EdgeInsets.only(right: 14),
                              child: _buildPopularPodcastCard(
                                context,
                                rank: '#$rank',
                                title: p['name'] ?? 'Podcast',
                                creator: p['country']?['name'] ?? 'Mali',
                                coverUrl: p['cover'],
                                slug: p['slug'] ?? 'podcast',
                              ),
                            );
                          }).toList(),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // 7. SECTION "ARTISTES POPULAIRES"
                      _buildSectionHeader(context,
                          badge: 'CRÉATEURS', title: 'Artistes populaires'),
                      const SizedBox(height: 14),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            _buildHostAvatar(context,
                                name: 'Mohamed Traoré',
                                role: 'Voix de Bamako',
                                initial: 'M'),
                            const SizedBox(width: 16),
                            _buildHostAvatar(context,
                                name: 'Aminata Diallo',
                                role: 'Tech & Innovation',
                                initial: 'A'),
                            const SizedBox(width: 16),
                            _buildHostAvatar(context,
                                name: 'Oumar Coulibaly',
                                role: 'Histoires & Terroirs',
                                initial: 'O'),
                            const SizedBox(width: 16),
                            _buildHostAvatar(context,
                                name: 'Fatoumata Sissoko',
                                role: 'Femmes d\'Impact',
                                initial: 'F'),
                          ],
                        ),
                      ),

                      const SizedBox(height: 180),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildSectionHeader(BuildContext context,
      {required String badge, required String title}) {
    final textPri = BkoTheme.getTextPrimary(context);
    final textMut = BkoTheme.getTextMuted(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            badge,
            style: BkoTheme.fontLato(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.0,
              color: textMut,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: BkoTheme.fontLato(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
              color: textPri,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickLaunchItem(
    BuildContext context, {
    required String title,
    required String artist,
    required String coverUrl,
    required VoidCallback onPlay,
  }) {
    final textPri = BkoTheme.getTextPrimary(context);
    final textSec = BkoTheme.getTextSecondary(context);

    return GestureDetector(
      onTap: onPlay,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: coverUrl,
                width: 44,
                height: 44,
                fit: BoxFit.cover,
                errorWidget: (context, url, error) => Container(
                  width: 44,
                  height: 44,
                  color: BkoTheme.getBgSurfaceElevated(context),
                  child: const Icon(Icons.music_note_rounded,
                      color: BkoTheme.goldAccent),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: BkoTheme.fontLato(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: textPri),
                  ),
                  const SizedBox(height: 2),
                  GestureDetector(
                    onTap: () {
                      final slug = artist
                          .toLowerCase()
                          .replaceAll(RegExp(r'[^a-z0-9]+'), '-');
                      context.push('/podcasts/$slug');
                    },
                    child: Text(
                      artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: BkoTheme.fontLato(
                          fontSize: 11.5, color: BkoTheme.goldAccent),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.more_horiz_rounded, color: textSec, size: 20),
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpotifyTintedEpisodeCard(
    BuildContext context, {
    required String title,
    required String podcastName,
    required String dateAndDuration,
    required String description,
    required String coverUrl,
    required Color cardBgColor,
    required VoidCallback onPlay,
    required VoidCallback onAddToList,
    required bool isInList,
  }) {
    final podSlug = podcastName
        .toLowerCase()
        .replaceAll("'", "")
        .replaceAll("’", "")
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    final epSlug = title
        .toLowerCase()
        .replaceAll("'", "")
        .replaceAll("’", "")
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-');

    return GestureDetector(
      onTap: () {
        context.push('/podcasts/$podSlug/episodes/$epSlug');
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: cardBgColor,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: CachedNetworkImage(
                    imageUrl: coverUrl,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorWidget: (context, url, error) => Container(
                      width: 56,
                      height: 56,
                      color: Colors.black26,
                      child: const Icon(Icons.graphic_eq_rounded,
                          color: Colors.white),
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
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: BkoTheme.fontLato(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: () {
                          final slug = podcastName
                              .toLowerCase()
                              .replaceAll(RegExp(r'[^a-z0-9]+'), '-');
                          context.push('/podcasts/$slug');
                        },
                        child: Text(
                          '$podcastName • $dateAndDuration',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: BkoTheme.fontLato(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: BkoTheme.goldAccent,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                  icon: const Icon(Icons.more_horiz_rounded,
                      color: Colors.white70, size: 22),
                  onPressed: () {},
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: BkoTheme.fontLato(
                fontSize: 12.5,
                fontWeight: FontWeight.w400,
                color: Colors.white.withValues(alpha: 0.85),
                height: 1.35,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(16),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.share_outlined,
                          color: Colors.white, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        'Aperçu de l\'épisode',
                        style: BkoTheme.fontLato(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    GestureDetector(
                      onTap: onAddToList,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white38, width: 1.5),
                        ),
                        child: Icon(
                          isInList ? Icons.check_rounded : Icons.add_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: onPlay,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.black,
                          size: 24,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenrePosterCard(
    BuildContext context, {
    required String hashtag,
    required String coverUrl,
  }) {
    return GestureDetector(
      onTap: () {
        _triggerPlayEpisode(hashtag, 'Genre Radio', '45 min', coverUrl);
      },
      child: Container(
        width: 140,
        height: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              Positioned.fill(
                child: CachedNetworkImage(
                  imageUrl: coverUrl,
                  fit: BoxFit.cover,
                  errorWidget: (context, url, error) => Container(
                    color: BkoTheme.getBgSurfaceElevated(context),
                    child: const Icon(Icons.image_not_supported_rounded,
                        color: BkoTheme.goldAccent),
                  ),
                ),
              ),
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.transparent, Colors.black87],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 12,
                left: 12,
                right: 12,
                child: Text(
                  hashtag,
                  style: BkoTheme.fontLato(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRadioCard(
    BuildContext context, {
    required String title,
    required String artists,
    required Color bgColor,
  }) {
    return GestureDetector(
      onTap: () {
        _triggerPlayEpisode('Radio $title', artists, 'Direct Live',
            'https://img.youtube.com/vi/KWhVBP8YQaM/maxresdefault.jpg');
      },
      child: Container(
        width: 160,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'RADIO',
                  style: BkoTheme.fontLato(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    color: Colors.black54,
                  ),
                ),
                const Icon(Icons.graphic_eq_rounded,
                    color: Colors.black87, size: 20),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: BkoTheme.fontLato(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              artists,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: BkoTheme.fontLato(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPopularPodcastCard(
    BuildContext context, {
    required String rank,
    required String title,
    required String creator,
    String? coverUrl,
    required String slug,
  }) {
    final bgSurf = BkoTheme.getBgSurface(context);
    final borderSub = BkoTheme.getBorderSubtle(context);
    final textPri = BkoTheme.getTextPrimary(context);
    final textSec = BkoTheme.getTextSecondary(context);

    return GestureDetector(
      onTap: () {
        final targetSlug = (slug.isNotEmpty && slug != 'podcast')
            ? slug
            : title
                .toLowerCase()
                .replaceAll("'", "")
                .replaceAll("’", "")
                .replaceAll(RegExp(r'[^a-z0-9]+'), '-');
        context.push('/podcasts/$targetSlug');
      },
      child: SizedBox(
        width: 140,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: borderSub),
                    color: bgSurf,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(19),
                    child: coverUrl != null
                        ? CachedNetworkImage(
                            imageUrl: coverUrl,
                            fit: BoxFit.cover,
                            errorWidget: (context, url, error) => const Icon(
                                Icons.graphic_eq_rounded,
                                color: BkoTheme.goldAccent,
                                size: 48),
                          )
                        : const Icon(Icons.graphic_eq_rounded,
                            color: BkoTheme.goldAccent, size: 48),
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: BkoTheme.goldAccent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      rank,
                      style: BkoTheme.fontLato(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: Colors.black),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: BkoTheme.fontLato(
                  fontSize: 13, fontWeight: FontWeight.w800, color: textPri),
            ),
            Text(
              creator,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: BkoTheme.fontLato(fontSize: 11, color: textSec),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHostAvatar(BuildContext context,
      {required String name, required String role, required String initial}) {
    final textPri = BkoTheme.getTextPrimary(context);
    final textSec = BkoTheme.getTextSecondary(context);
    final slug = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');

    return GestureDetector(
      onTap: () => context.push('/podcasts/$slug'),
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: BkoTheme.getBgSurfaceElevated(context),
              border: Border.all(color: BkoTheme.goldAccent, width: 1.5),
            ),
            child: Center(
              child: Text(
                initial,
                style: BkoTheme.fontLato(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: BkoTheme.goldAccent),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            name,
            style: BkoTheme.fontLato(
                fontSize: 12, fontWeight: FontWeight.w800, color: textPri),
          ),
          Text(
            role,
            style: BkoTheme.fontLato(fontSize: 10, color: textSec),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonLoading(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              color: BkoTheme.getBgSurfaceElevated(context),
              borderRadius: BorderRadius.circular(26),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            height: 20,
            width: 140,
            color: BkoTheme.getBgSurfaceElevated(context),
          ),
          const SizedBox(height: 12),
          Container(
            height: 100,
            width: double.infinity,
            decoration: BoxDecoration(
              color: BkoTheme.getBgSurfaceElevated(context),
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ],
      ),
    );
  }
}
