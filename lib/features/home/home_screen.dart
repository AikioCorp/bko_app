import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/network/bko_api.dart';
import '../../core/theme/bko_theme.dart';
import '../../core/theme/theme_provider.dart';
import '../auth/auth_controller.dart';
import '../shell/shell_providers.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Map<String, dynamic>? _homeData;
  List<dynamic> _categories = [];
  List<dynamic> _historyData = [];
  bool _isLoading = true;
  String _filterMode = 'ALL';

  @override
  void initState() {
    super.initState();
    _fetchHomeData();
  }

  Future<void> _fetchHomeData() async {
    try {
      final auth = ref.read(authProvider);
      final userId = auth.user?['id'] ?? 'guest';

      final homeData = await BkoApi.get('/home?country=all&u=$userId');
      final categoriesData = await BkoApi.get('/categories');
      
      List<dynamic> history = [];
      if (auth.isAuthenticated && auth.token != null) {
        try {
          final h = await BkoApi.get('/me/continue-listening', token: auth.token);
          history = _asList(h);
        } catch (_) {}
      }

      if (!mounted) return;
      setState(() {
        _homeData = homeData is Map ? Map<String, dynamic>.from(homeData) : null;
        _categories = _asList(categoriesData);
        _historyData = history;
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

  void _triggerPlayEpisode(Map<String, dynamic> ep) {
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

    if (_isLoading) {
      return Scaffold(
        backgroundColor: BkoTheme.getBgObsidian(context),
        body: const Center(child: CircularProgressIndicator(color: BkoTheme.goldAccent)),
      );
    }

    final data = _homeData ?? {};
    final heroEpisode = data['heroEpisode'];
    final latestEpisodesRaw = _asList(data['latestEpisodes']);
    final categoryShelves = _asList(data['categoryShelves']);

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
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: () => _openUserProfileModal(context),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: BkoTheme.getBgSurfaceElevated(context),
                  border: Border.all(color: borderSub, width: 1.5),
                ),
                child: Center(
                  child: Text(
                    ref.read(authProvider).isAuthenticated 
                      ? (ref.read(authProvider).user?['fullName']?.toString().substring(0, 1).toUpperCase() ?? 'U')
                      : '?',
                    style: BkoTheme.fontLato(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: BkoTheme.goldAccent,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: RefreshIndicator(
        color: BkoTheme.goldAccent,
        onRefresh: _fetchHomeData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Hero Banner
              if (heroEpisode != null) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: GestureDetector(
                    onTap: () => _triggerPlayEpisode(heroEpisode),
                    child: Container(
                      height: 280,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: borderSub),
                        image: DecorationImage(
                          image: CachedNetworkImageProvider(
                            heroEpisode['cover'] ?? heroEpisode['podcast']?['cover'] ?? '',
                          ),
                          fit: BoxFit.cover,
                        ),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          gradient: LinearGradient(
                            colors: [Colors.black.withValues(alpha: 0.1), Colors.black.withValues(alpha: 0.8)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: BkoTheme.goldAccent,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text('Nouveauté', style: BkoTheme.fontLato(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.black)),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              heroEpisode['title'] ?? '',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: BkoTheme.fontLato(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white, height: 1.1),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: const BoxDecoration(
                                    color: BkoTheme.goldAccent,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Text('Écouter l\'épisode', style: BkoTheme.fontLato(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
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
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: BkoTheme.goldAccent,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text('Tout explorer', style: BkoTheme.fontLato(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.black)),
                    ),
                    ...categoryShelves.map((shelf) {
                      return Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: bgSurf,
                          border: Border.all(color: borderSub),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Text('${shelf['name']}', style: BkoTheme.fontLato(fontSize: 12, fontWeight: FontWeight.w800, color: textPri)),
                      );
                    }),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // 3. Historique de lecture
              if (_historyData.isNotEmpty) ...[
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
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _historyData.length > 4 ? 4 : _historyData.length,
                    itemBuilder: (context, index) {
                      final item = _historyData[index];
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

              // 4. Fraîchement publiés
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
                      final cover = ep['cover'] ?? ep['podcast']?['cover'] ?? '';
                      return GestureDetector(
                        onTap: () => _triggerPlayEpisode(ep),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.transparent),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: CachedNetworkImage(
                                  imageUrl: cover,
                                  width: 64,
                                  height: 64,
                                  fit: BoxFit.cover,
                                  errorWidget: (context, url, error) => Container(color: Colors.grey.shade900),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(ep['podcast']?['name'] ?? 'Bamako Podcast', style: BkoTheme.fontLato(fontSize: 10, fontWeight: FontWeight.w900, color: BkoTheme.goldAccent)),
                                    const SizedBox(height: 4),
                                    Text(ep['title'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: BkoTheme.fontLato(fontSize: 14, fontWeight: FontWeight.w800, color: textPri, height: 1.2)),
                                    const SizedBox(height: 6),
                                    Text('${(ep['durationSeconds'] ?? 1800) ~/ 60} min', style: BkoTheme.fontLato(fontSize: 11, color: textSec, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                              const Icon(Icons.more_vert_rounded, color: Colors.grey),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // 5. Category Shelves
              ...categoryShelves.map((shelf) {
                final podcasts = _asList(shelf['podcasts']);
                if (podcasts.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text('${shelf['name']}', style: BkoTheme.fontLato(fontSize: 20, fontWeight: FontWeight.w900, color: textPri)),
                    ),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text('${podcasts.length} séries actives', style: BkoTheme.fontLato(fontSize: 12, color: textSec)),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 180,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: podcasts.length,
                        itemBuilder: (context, index) {
                          final p = podcasts[index];
                          return GestureDetector(
                            onTap: () => context.push('/podcasts/${p['slug']}'),
                            child: Container(
                              width: 140,
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
                                  Text(p['name'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: BkoTheme.fontLato(fontSize: 13, fontWeight: FontWeight.w800, color: textPri)),
                                  const SizedBox(height: 2),
                                  Text(p['author']?['name'] ?? 'Bamako Podcast', maxLines: 1, overflow: TextOverflow.ellipsis, style: BkoTheme.fontLato(fontSize: 11, color: textSec)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                );
              }),

              // 6. Toutes les Catégories Officielles
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Icon(Icons.menu_book_rounded, color: BkoTheme.goldAccent, size: 16),
                    const SizedBox(width: 8),
                    Text('Toutes les Catégories', style: BkoTheme.fontLato(fontSize: 18, fontWeight: FontWeight.w900, color: textPri)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _categories.map((cat) {
                    return Container(
                      width: (MediaQuery.of(context).size.width - 44) / 2,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: bgSurf,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: borderSub),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: BkoTheme.getBgObsidian(context),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.explore_rounded, color: Colors.grey, size: 18),
                          ),
                          const SizedBox(height: 12),
                          Text('${cat['name']}', style: BkoTheme.fontLato(fontSize: 14, fontWeight: FontWeight.w800, color: textPri)),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              
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
}
