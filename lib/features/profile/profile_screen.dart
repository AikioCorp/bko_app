import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../../core/network/bko_api.dart';
import '../../core/theme/bko_theme.dart';
import '../../core/widgets/bko_bounceable.dart';
import '../../core/widgets/bko_haptics.dart';
import '../auth/auth_controller.dart';
import '../downloads/download_manager.dart';
import '../home/widgets/bko_drawer.dart';
import '../library/library_screen.dart';
import '../shell/shell_providers.dart';

/// Dashboard « Mon espace » personnel de l'auditeur connecté.
/// Conçu selon les règles strictes mobile-designer et les directives du projet :
/// - En-tête : Avatar, Nom affiché, badge vérifié discret (isVerified), bouton « Modifier mon profil », réglages
/// - Aucun e-mail ni téléphone affiché publiquement
/// - Bloc « Reprendre l’écoute » : épisodes commencés non terminés avec progression et lecture globale
/// - 4 Raccourcis avec compteurs réels (Enregistrés, Suivis, Playlists, Téléchargements)
/// - Bloc « Du nouveau dans vos émissions » (émissions suivies)
/// - Bloc « Votre activité » réelle calculée depuis l'historique
/// - Bloc « Pour vous » avec invitation aux goûts pour nouveaux comptes
/// - Bas de page : Aide, Devenir créateur / Mon studio, Réglages
/// - Zéro dégradé, zéro ombre, surfaces nettes BkoTheme
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  int _followingCount = 0;
  int _savedCount = 0;
  int _playlistsCount = 0;
  List<Map<String, dynamic>> _history = [];
  List<Map<String, dynamic>> _followedPodcasts = [];
  List<Map<String, dynamic>> _recommendations = [];
  List<Map<String, dynamic>> _saved = [];
  List<Map<String, dynamic>> _playlists = [];
  List<Map<String, dynamic>> _latestEpisodes = [];
  String? _loadError;
  int _generation = 0;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    final auth = ref.read(authProvider);
    if (!auth.isAuthenticated || auth.token == null) return;
    final generation = ++_generation;

    if (mounted) setState(() => _isLoading = true);

    try {
      final results = await Future.wait([
        BkoApi.get('/me/following', token: auth.token),
        BkoApi.get('/me/saved', token: auth.token),
        BkoApi.get('/me/playlists', token: auth.token),
        BkoApi.get('/me/history', token: auth.token),
        BkoApi.get('/trending?country=all', token: auth.token),
      ]);

      if (!mounted ||
          generation != _generation ||
          ref.read(authProvider).user?['id'] != auth.user?['id']) {
        return;
      }

      final followingData = (results[0] is List) ? results[0] as List : [];
      final savedData = (results[1] is List) ? results[1] as List : [];
      final playlistsData = (results[2] is List) ? results[2] as List : [];
      final historyData = (results[3] is List) ? results[3] as List : [];
      final trendingData = (results[4] is List)
          ? results[4] as List
          : ((results[4] is Map && results[4]['data'] is List)
              ? results[4]['data'] as List
              : []);

      setState(() {
        _followingCount = followingData.length;
        _savedCount = savedData.length;
        _playlistsCount = playlistsData.length;
        _saved = savedData
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _playlists = playlistsData
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _loadError = null;
        _followedPodcasts = followingData
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _history = historyData
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _recommendations = trendingData
            .take(6)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _isLoading = false;
      });
      final latest =
          await Future.wait(_followedPodcasts.take(6).map((podcast) async {
        try {
          final slug = Uri.encodeComponent('${podcast['slug']}');
          final details = await BkoApi.get(
              '/podcasts/$slug?episodeLimit=1&episodeOffset=0&episodeSort=recent',
              token: auth.token);
          if (details is Map && details['episodes'] is List) {
            return (details['episodes'] as List)
                .whereType<Map>()
                .map((ep) => <String, dynamic>{
                      ...Map<String, dynamic>.from(ep),
                      'podcast': podcast
                    })
                .toList();
          }
        } catch (_) {
          // Keep the followed-show shortcut available if its latest episode fails.
        }
        return <Map<String, dynamic>>[];
      }));
      if (mounted && generation == _generation) {
        setState(
            () => _latestEpisodes = latest.expand((items) => items).toList());
      }
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() {
          _isLoading = false;
          _loadError = 'Impossible de charger votre espace. Réessayez.';
        });
      }
    }
  }

  String _formatTotalListeningTime(int totalSeconds) {
    if (totalSeconds <= 0) return '0 min';
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    if (hours > 0) {
      return '$hours h ${minutes > 0 ? '$minutes min' : ''}';
    }
    return '$minutes min';
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    ref.listen(authProvider.select((state) => state.user?['id']),
        (previous, next) {
      if (previous == next) return;
      _generation++;
      setState(() {
        _history = [];
        _saved = [];
        _playlists = [];
        _latestEpisodes = [];
        _followedPodcasts = [];
        _recommendations = [];
        _savedCount = _followingCount = _playlistsCount = 0;
        _loadError = null;
        _isLoading = false;
      });
      if (next != null) _loadDashboardData();
    });

    if (!auth.isAuthenticated) {
      return _buildGuestPlaceholder(context);
    }

    final user = auth.user ?? {};
    final fullName = (user['fullName'] ?? user['name'] ?? 'Auditeur') as String;
    final avatarUrl = (user['avatar'] as String?)?.trim() ?? '';
    final isVerified = user['isVerified'] == true;
    final roles =
        (user['roles'] as List?)?.map((r) => '$r'.toUpperCase()).toList() ?? [];
    final isCreator =
        roles.contains('CREATOR') || user['creatorProfile'] != null;

    final downloads = ref.watch(downloadProvider);
    final downloadCount =
        downloads.where((t) => t.status == DownloadStatus.completed).length;

    // Épisodes commencés et non terminés
    final inProgressEpisodes = _history.where((item) {
      final completed = item['completed'] == true;
      final pos = (item['positionSeconds'] as num?)?.toInt() ?? 0;
      return !completed && pos > 10;
    }).toList();

    // Statistiques d'écoute réelles
    final completedCount =
        _history.where((item) => item['completed'] == true).length;
    final totalListeningSeconds = _history.fold<int>(
      0,
      (sum, item) => sum + ((item['positionSeconds'] as num?)?.toInt() ?? 0),
    );

    // Vérifier si l'utilisateur a personnalisé ses goûts
    final hasTastePreferences = (user['languagePreferences'] is List &&
            (user['languagePreferences'] as List).isNotEmpty) ||
        user['recommendationProfile']?['onboardingCompleted'] == true;

    ref.listen(libraryUpdateSignalProvider, (_, __) {
      _loadDashboardData();
    });

    return Scaffold(
      backgroundColor: BkoTheme.getBgObsidian(context),
      drawer: const BkoDrawer(),
      appBar: AppBar(
        leading: auth.isAuthenticated
            ? BkoBounceable(
                onTap: () {
                  BkoHaptics.light();
                  Scaffold.of(context).openDrawer();
                },
                child: Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  child: Icon(
                    IconsaxPlusLinear.menu_1,
                    size: 22,
                    color: BkoTheme.getTextPrimary(context),
                  ),
                ),
              )
            : null,
        title: Text(
          'Mon espace',
          style: BkoTheme.fontLato(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: BkoTheme.getTextPrimary(context),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              IconsaxPlusLinear.setting_2,
              color: BkoTheme.getTextPrimary(context),
              size: 22,
            ),
            tooltip: 'Réglages',
            onPressed: () {
              BkoHaptics.light();
              context.push('/settings/playback');
            },
          ),
        ],
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: RefreshIndicator(
        color: BkoTheme.goldAccent,
        backgroundColor: BkoTheme.getBgSurface(context),
        onRefresh: () async {
          BkoHaptics.light();
          await _loadDashboardData();
          BkoHaptics.select();
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
              18, 12, 18, MediaQuery.of(context).padding.bottom + 180),
          children: [
            if (_loadError != null)
              ListTile(
                title: Text(_loadError!),
                trailing: TextButton(
                    onPressed: _loadDashboardData,
                    child: const Text('Réessayer')),
              ),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: LinearProgressIndicator(
                  minHeight: 2,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation(BkoTheme.goldAccent),
                ),
              ),
            // 1. En-tête : Avatar, Nom affiché, Indication de vérification, Bouton Modifier
            _buildProfileHeader(
              context: context,
              fullName: fullName,
              avatarUrl: avatarUrl,
              isVerified: isVerified,
            ),
            const SizedBox(height: 20),

            // 2. Raccourcis Bibliothèque & Téléchargements avec compteurs réels
            _buildShortcutsGrid(
              context: context,
              savedCount: _savedCount,
              followingCount: _followingCount,
              playlistsCount: _playlistsCount,
              downloadCount: downloadCount,
            ),
            const SizedBox(height: 24),

            if (inProgressEpisodes.isEmpty)
              _emptySection(
                  context,
                  'Reprendre l’écoute',
                  'Vos épisodes commencés apparaîtront ici.',
                  'Découvrir',
                  '/explore'),
            _buildSectionHeader(context,
                title: 'À ÉCOUTER PLUS TARD',
                actionLabel: 'Tout voir',
                onAction: () => context.go('/library?tab=0')),
            if (_saved.isEmpty)
              _emptySection(
                  context,
                  'Gardez une découverte',
                  'Enregistrez un épisode pour le retrouver ici.',
                  'Découvrir',
                  '/explore')
            else
              ..._saved
                  .take(3)
                  .map((ep) => _buildResumeCard(context, {'episode': ep})),
            const SizedBox(height: 24),
            _buildSectionHeader(context,
                title: 'MES PLAYLISTS',
                actionLabel: 'Gérer',
                onAction: () => context.go('/library?tab=3')),
            if (_playlists.isEmpty)
              _emptySection(
                  context,
                  'Votre sélection, votre rythme',
                  'Rassemblez vos épisodes dans une playlist.',
                  'Créer une playlist',
                  '/library?tab=3')
            else
              ..._playlists.take(3).map((pl) => ListTile(
                    leading: const Icon(IconsaxPlusLinear.music_playlist),
                    title: Text('${pl['name'] ?? 'Playlist'}'),
                    trailing:
                        const Icon(IconsaxPlusLinear.arrow_right_3, size: 16),
                    onTap: () => context.push('/playlists/${pl['id']}'),
                  )),
            const SizedBox(height: 24),
            _buildSectionHeader(context,
                title: 'RÉCEMMENT ÉCOUTÉS',
                actionLabel: 'Historique',
                onAction: () => context.go('/library?tab=2')),
            if (_history.isEmpty)
              _emptySection(
                  context,
                  'Votre histoire d’écoute',
                  'Retrouvez ici vos dernières écoutes.',
                  'Explorer',
                  '/explore')
            else
              ..._history
                  .take(3)
                  .map((item) => _buildResumeCard(context, item)),
            const SizedBox(height: 24),

            // 3. Bloc « Reprendre l’écoute » (masqué lorsqu'il est vide)
            if (inProgressEpisodes.isNotEmpty) ...[
              _buildSectionHeader(
                context,
                title: 'REPRENDRE L\'ÉCOUTE',
                actionLabel: '${inProgressEpisodes.length} en cours',
              ),
              const SizedBox(height: 10),
              ...inProgressEpisodes
                  .take(3)
                  .map((item) => _buildResumeCard(context, item)),
              const SizedBox(height: 24),
            ],

            // 4. Bloc « Du nouveau dans vos émissions » (émissions suivies)
            if (_followedPodcasts.isNotEmpty) ...[
              _buildSectionHeader(context,
                  title: 'NOUVEAUTÉS DE MES ÉMISSIONS'),
              if (_latestEpisodes.isNotEmpty)
                ..._latestEpisodes
                    .take(3)
                    .map((ep) => _buildResumeCard(context, {'episode': ep}))
              else
                Text(
                    'Ouvrez une émission suivie pour consulter ses derniers épisodes.',
                    style: BkoTheme.fontLato(
                        color: BkoTheme.getTextSecondary(context))),
              const SizedBox(height: 16),
              _buildSectionHeader(
                context,
                title: 'MES ÉMISSIONS SUIVIES',
                actionLabel: 'Tout voir',
                onAction: () => context.go('/library?tab=1'),
              ),
              const SizedBox(height: 12),
              _buildFollowedPodcastsScroll(context, _followedPodcasts),
              const SizedBox(height: 24),
            ],

            // 5. Bloc « Votre activité » réelle
            if (_history.isNotEmpty) ...[
              _buildSectionHeader(context, title: 'VOTRE ACTIVITÉ D\'ÉCOUTE'),
              const SizedBox(height: 10),
              _buildActivityCard(
                context: context,
                historyCount: _history.length,
                completedCount: completedCount,
                totalSeconds: totalListeningSeconds,
              ),
              const SizedBox(height: 24),
            ],

            // 6. Bloc « Pour vous » (Recommandations ou Onboarding)
            if (_followedPodcasts.isEmpty)
              _emptySection(
                  context,
                  'Mes émissions suivies',
                  'Suivez une émission pour la retrouver rapidement.',
                  'Découvrir',
                  '/explore'),
            _buildSectionHeader(context, title: 'MES DÉCOUVERTES'),
            const SizedBox(height: 10),
            if (!hasTastePreferences) _buildOnboardingInviteCard(context),
            if (_recommendations.isNotEmpty)
              _buildFollowedPodcastsScroll(context, _recommendations)
            else
              _buildEmptyRecommendationsCard(context),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(IconsaxPlusLinear.music_filter),
              title: const Text('Mes langues et mes centres d’intérêt'),
              trailing: const Icon(IconsaxPlusLinear.arrow_right_3, size: 16),
              onTap: () => context.push('/taste-onboarding?mode=edit'),
            ),

            const SizedBox(height: 32),

            // 7. Bas de page : Aide, Devenir créateur, Réglages
            _buildFooterActions(context, isCreator),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader({
    required BuildContext context,
    required String fullName,
    required String avatarUrl,
    required bool isVerified,
  }) {
    return Row(children: [
      Semantics(
        label: 'Voir et modifier mon profil',
        button: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => context.push('/profile/edit'),
          child: SizedBox(
            width: 48,
            height: 48,
            child: ClipOval(
                child: avatarUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: avatarUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) =>
                            _buildAvatarInitial(fullName))
                    : _buildAvatarInitial(fullName)),
          ),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
          child: Text(fullName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: BkoTheme.fontLato(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: BkoTheme.getTextPrimary(context)))),
      if (isVerified)
        const Icon(IconsaxPlusLinear.verify,
            size: 18, color: BkoTheme.goldAccent),
    ]);
  }

  Widget _emptySection(BuildContext context, String title, String description,
      String action, String path) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: BkoTheme.fontLato(
                fontWeight: FontWeight.w700,
                color: BkoTheme.getTextPrimary(context))),
        const SizedBox(height: 6),
        Text(description,
            style: BkoTheme.fontLato(
                fontSize: 13, color: BkoTheme.getTextSecondary(context))),
        TextButton(
            onPressed: () => path.startsWith('/library')
                ? context.go(path)
                : context.push(path),
            child: Text(action)),
      ]),
    );
  }

  Widget _buildAvatarInitial(String name) {
    final initial = name.trim().isNotEmpty
        ? name.trim().substring(0, 1).toUpperCase()
        : 'A';
    return Center(
      child: Text(
        initial,
        style: BkoTheme.fontLato(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: BkoTheme.goldAccent,
        ),
      ),
    );
  }

  Widget _buildShortcutsGrid({
    required BuildContext context,
    required int savedCount,
    required int followingCount,
    required int playlistsCount,
    required int downloadCount,
  }) {
    return Row(
      children: [
        Expanded(
          child: _buildShortcutCard(
            context: context,
            title: 'Enregistrés',
            count: savedCount,
            icon: IconsaxPlusLinear.archive_add,
            onTap: () => context.go('/library?tab=0'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildShortcutCard(
            context: context,
            title: 'Suivis',
            count: followingCount,
            icon: IconsaxPlusLinear.heart,
            onTap: () => context.go('/library?tab=1'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildShortcutCard(
            context: context,
            title: 'Playlists',
            count: playlistsCount,
            icon: IconsaxPlusLinear.music_playlist,
            onTap: () => context.go('/library?tab=3'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildShortcutCard(
            context: context,
            title: 'Hors-ligne',
            count: downloadCount,
            icon: IconsaxPlusLinear.document_download,
            onTap: () => context.push('/downloads'),
          ),
        ),
      ],
    );
  }

  Widget _buildShortcutCard({
    required BuildContext context,
    required String title,
    required int count,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return BkoBounceable(
      onTap: () {
        BkoHaptics.light();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: BkoTheme.getBgSurface(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: BkoTheme.getBorderSubtle(context)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: BkoTheme.goldAccent),
            const SizedBox(height: 6),
            Text(
              '$count',
              style: BkoTheme.fontLato(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: BkoTheme.getTextPrimary(context),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: BkoTheme.fontLato(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: BkoTheme.getTextSecondary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required String title,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: BkoTheme.fontLato(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
            color: BkoTheme.getTextMuted(context),
          ),
        ),
        if (actionLabel != null)
          BkoBounceable(
            onTap: onAction,
            child: Text(
              actionLabel,
              style: BkoTheme.fontLato(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: BkoTheme.goldAccent,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildResumeCard(BuildContext context, Map<String, dynamic> item) {
    final episode = item['episode'] is Map ? item['episode'] as Map : {};
    final podcast = episode['podcast'] is Map ? episode['podcast'] as Map : {};

    final title = (episode['title'] ?? 'Épisode en cours') as String;
    final showName = (podcast['name'] ?? '') as String;
    final coverUrl = (episode['cover'] ?? podcast['cover'] ?? '') as String;
    final episodeId = '${episode['id'] ?? ''}';
    final podcastSlug = '${podcast['slug'] ?? ''}';
    final episodeSlug = '${episode['slug'] ?? ''}';

    final pos = (item['positionSeconds'] as num?)?.toInt() ?? 0;
    final duration = (episode['durationSeconds'] as num?)?.toInt() ?? 1;
    final progress = (pos / (duration > 0 ? duration : 1)).clamp(0.0, 1.0);

    final activeState = ref.watch(activeEpisodeProvider);
    final isCurrentlyActive = activeState.episodeId == episodeId;
    final isPlaying = isCurrentlyActive && activeState.isPlaying;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: BkoTheme.getBgSurface(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: BkoTheme.getBorderSubtle(context)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 50,
                  height: 50,
                  child: coverUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: coverUrl,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(
                            color: BkoTheme.getBgSurfaceElevated(context),
                            child: const Icon(IconsaxPlusLinear.music,
                                color: BkoTheme.goldAccent),
                          ),
                        )
                      : Container(
                          color: BkoTheme.getBgSurfaceElevated(context),
                          child: const Icon(IconsaxPlusLinear.music,
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
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: BkoTheme.getTextPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      showName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: BkoTheme.fontLato(
                        fontSize: 11.5,
                        color: BkoTheme.getTextSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              BkoBounceable(
                onTap: () {
                  BkoHaptics.light();
                  final audioUrl = BkoApi.extractAudioUrl(
                      Map<String, dynamic>.from(episode));
                  final videoUrl = BkoApi.extractVideoUrl(
                      Map<String, dynamic>.from(episode));

                  ref.read(activeEpisodeProvider.notifier).handlePlayOrPause(
                        title: title,
                        showName: showName,
                        duration: '${duration ~/ 60} min',
                        coverUrl: coverUrl,
                        audioUrl: audioUrl,
                        videoUrl: videoUrl,
                        hasAudio: audioUrl != null && audioUrl.isNotEmpty,
                        hasVideo: videoUrl != null && videoUrl.isNotEmpty,
                        episodeId: episodeId,
                        podcastSlug: podcastSlug,
                        episodeSlug: episodeSlug,
                      );
                },
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: BkoTheme.goldAccent,
                  ),
                  child: Center(
                    child: Icon(
                      isPlaying
                          ? IconsaxPlusLinear.pause
                          : IconsaxPlusLinear.play,
                      size: 18,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: BkoTheme.getBgSurfaceElevated(context),
              valueColor: const AlwaysStoppedAnimation(BkoTheme.goldAccent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFollowedPodcastsScroll(
    BuildContext context,
    List<Map<String, dynamic>> podcasts,
  ) {
    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: podcasts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (ctx, i) {
          final p = podcasts[i];
          final name = (p['name'] ?? 'Émission') as String;
          final cover = (p['cover'] ?? '') as String;
          final slug = (p['slug'] ?? '') as String;

          return BkoBounceable(
            onTap: () {
              BkoHaptics.light();
              context.push('/podcasts/$slug');
            },
            child: SizedBox(
              width: 84,
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(
                      width: 72,
                      height: 72,
                      child: cover.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: cover,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => Container(
                                color: BkoTheme.getBgSurfaceElevated(context),
                                child:
                                    const Icon(IconsaxPlusLinear.microphone_2),
                              ),
                            )
                          : Container(
                              color: BkoTheme.getBgSurfaceElevated(context),
                              child: const Icon(IconsaxPlusLinear.microphone_2),
                            ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    name,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: BkoTheme.fontLato(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: BkoTheme.getTextPrimary(context),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildActivityCard({
    required BuildContext context,
    required int historyCount,
    required int completedCount,
    required int totalSeconds,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BkoTheme.getBgSurface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BkoTheme.getBorderSubtle(context)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildActivityMetric(
            context,
            label: 'Épisodes écoutés',
            value: '$historyCount',
            icon: IconsaxPlusLinear.music_dashboard,
          ),
          Container(
            height: 36,
            width: 1,
            color: BkoTheme.getBorderSubtle(context),
          ),
          _buildActivityMetric(
            context,
            label: 'Terminés',
            value: '$completedCount',
            icon: IconsaxPlusLinear.tick_circle,
          ),
          Container(
            height: 36,
            width: 1,
            color: BkoTheme.getBorderSubtle(context),
          ),
          _buildActivityMetric(
            context,
            label: 'Temps d\'écoute',
            value: _formatTotalListeningTime(totalSeconds),
            icon: IconsaxPlusLinear.clock,
          ),
        ],
      ),
    );
  }

  Widget _buildActivityMetric(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Column(
      children: [
        Icon(icon, size: 18, color: BkoTheme.goldAccent),
        const SizedBox(height: 6),
        Text(
          value,
          style: BkoTheme.fontLato(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: BkoTheme.getTextPrimary(context),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: BkoTheme.fontLato(
            fontSize: 10.5,
            color: BkoTheme.getTextSecondary(context),
          ),
        ),
      ],
    );
  }

  Widget _buildOnboardingInviteCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: BkoTheme.getBgSurface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BkoTheme.getBorderSubtle(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: BkoTheme.goldAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: Icon(
                    IconsaxPlusLinear.magicpen,
                    color: BkoTheme.goldAccent,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Personnalisez vos recommandations',
                  style: BkoTheme.fontLato(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: BkoTheme.getTextPrimary(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Choisissez vos langues (Bambara, Français, Peul...) et vos thématiques favorites pour découvrir des podcasts sur mesure.',
            style: BkoTheme.fontLato(
              fontSize: 12.5,
              color: BkoTheme.getTextSecondary(context),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          BkoBounceable(
            onTap: () {
              BkoHaptics.light();
              context.push('/taste-onboarding?mode=edit');
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: BkoTheme.goldAccent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Choisir mes langues & intérêts',
                style: BkoTheme.fontLato(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyRecommendationsCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BkoTheme.getBgSurface(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: BkoTheme.getBorderSubtle(context)),
      ),
      child: Center(
        child: Text(
          'Écoutez vos premiers podcasts pour affiner vos recommandations.',
          style: BkoTheme.fontLato(
            fontSize: 12.5,
            color: BkoTheme.getTextSecondary(context),
          ),
        ),
      ),
    );
  }

  Widget _buildFooterActions(BuildContext context, bool isCreator) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildFooterButton(
                  context,
                  title: isCreator ? 'Mon Studio' : 'Devenir créateur',
                  icon: IconsaxPlusLinear.microphone_2,
                  onTap: () {
                    if (isCreator) {
                      context.push('/studio');
                    } else {
                      context.push('/become-creator');
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildFooterButton(
                  context,
                  title: 'Aide & Support',
                  icon: IconsaxPlusLinear.message_question,
                  onTap: () => context.push('/settings/help'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildFooterButton(
            context,
            title: 'Préférences & réglages de l\'application',
            icon: IconsaxPlusLinear.setting_2,
            onTap: () => context.push('/settings/playback'),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterButton(
    BuildContext context, {
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return BkoBounceable(
      onTap: () {
        BkoHaptics.light();
        onTap();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          color: BkoTheme.getBgSurface(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: BkoTheme.getBorderSubtle(context)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: BkoTheme.getTextPrimary(context)),
            const SizedBox(width: 8),
            Text(
              title,
              style: BkoTheme.fontLato(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: BkoTheme.getTextPrimary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuestPlaceholder(BuildContext context) {
    return Scaffold(
      backgroundColor: BkoTheme.getBgObsidian(context),
      appBar: AppBar(
        title: Text(
          'Mon espace',
          style: BkoTheme.fontLato(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: BkoTheme.getTextPrimary(context),
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: BkoTheme.goldAccent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    IconsaxPlusLinear.user,
                    color: BkoTheme.goldAccent,
                    size: 30,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Connectez-vous à Bamako Podcast',
                style: BkoTheme.fontLato(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: BkoTheme.getTextPrimary(context),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Créez un compte gratuit pour synchroniser vos favoris, reprendre vos écoutes et télécharger vos épisodes.',
                textAlign: TextAlign.center,
                style: BkoTheme.fontLato(
                  fontSize: 13,
                  color: BkoTheme.getTextSecondary(context),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 22),
              BkoBounceable(
                onTap: () {
                  BkoHaptics.light();
                  context.push('/login');
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                  decoration: BoxDecoration(
                    color: BkoTheme.goldAccent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Se connecter ou s\'inscrire',
                    style: BkoTheme.fontLato(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
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

