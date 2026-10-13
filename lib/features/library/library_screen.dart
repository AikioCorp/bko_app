import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../../core/network/bko_api.dart';
import '../../core/theme/bko_theme.dart';
import '../../core/widgets/bko_bounceable.dart';
import '../../core/widgets/bko_haptics.dart';
import '../../core/widgets/skeleton_loaders.dart';
import '../auth/auth_controller.dart';
import '../home/widgets/bko_drawer.dart';
import '../home/widgets/episode_list_item.dart';
import '../shell/shell_providers.dart';

/// Signal global pour forcer la synchronisation de la bibliothèque
/// (après un enregistrement, abonnement ou écoute d'épisode).
final libraryUpdateSignalProvider = StateProvider<int>((ref) => 0);

class LibraryScreen extends ConsumerStatefulWidget {
  final int initialTab;
  const LibraryScreen({super.key, this.initialTab = 0});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  int _tab = 0; // 0 = enregistrés, 1 = suivis, 2 = historique, 3 = playlists
  bool _loading = false;
  String? _errorMessage;

  List<dynamic> _saved = [];
  List<dynamic> _following = [];
  List<dynamic> _history = [];
  List<dynamic> _playlists = [];
  bool _loadedOnce = false;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab.clamp(0, 3);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ref.read(authProvider).isAuthenticated) {
        _fetchAll();
      }
    });
  }

  @override
  void didUpdateWidget(covariant LibraryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab) {
      _selectTab(widget.initialTab.clamp(0, 3));
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loadedOnce && ref.read(authProvider).isAuthenticated) {
      _loadedOnce = true;
      _fetchAll();
    }
  }

  /// Charge l'intégralité des 4 onglets de la bibliothèque en parallèle.
  /// Met à jour les compteurs en direct et garantit des transitions d'onglets instantanées.
  Future<void> _fetchAll({bool silent = false}) async {
    final token = ref.read(authProvider).token;
    if (token == null) return;

    if (!silent) {
      setState(() {
        _loading = true;
        _errorMessage = null;
      });
    }

    try {
      final results = await Future.wait([
        BkoApi.get('/me/saved', token: token),
        BkoApi.get('/me/following', token: token),
        BkoApi.get('/me/history', token: token),
        BkoApi.get('/me/playlists', token: token),
      ]);

      if (mounted) {
        setState(() {
          _saved = (results[0] as List?) ?? [];
          _following = (results[1] as List?) ?? [];
          _history = (results[2] as List?) ?? [];
          _playlists = (results[3] as List?) ?? [];
          _errorMessage = null;
        });
      }
    } on ApiException catch (e) {
      if (mounted && !silent) setState(() => _errorMessage = e.message);
    } catch (_) {
      if (mounted && !silent) {
        setState(
            () => _errorMessage = 'Erreur lors du chargement des données.');
      }
    } finally {
      if (mounted && !silent) setState(() => _loading = false);
    }
  }

  void _selectTab(int i) {
    BkoHaptics.select();
    setState(() => _tab = i);
  }

  void _play(Map ep, {int? resumePositionSeconds}) {
    final podcast = ep['podcast'] as Map?;
    final d = ep['durationSeconds'];
    final label = d is int ? '${(d / 60).round()} min' : '';

    final sources = (ep['mediaSources'] as List<dynamic>?) ?? [];
    String? audioUrl = ep['primaryAudioSource']?['externalUrl'] ??
        BkoApi.extractAudioUrl(Map<String, dynamic>.from(ep));
    String? videoUrl = ep['primaryVideoSource']?['embedUrl'] ??
        ep['primaryVideoSource']?['externalUrl'];

    if (videoUrl == null) {
      for (var s in sources) {
        if (s['type'] == 'VIDEO') {
          videoUrl = s['embedUrl'] ?? s['externalUrl'];
          break;
        }
      }
    }

    final cover = '${ep['cover'] ?? podcast?['cover'] ?? ''}';
    final bool hasAudio = audioUrl != null && audioUrl.isNotEmpty;
    final bool hasVideo = videoUrl != null && videoUrl.isNotEmpty;
    final episodeId = '${ep['id'] ?? ''}';

    ref.read(activeEpisodeProvider.notifier).handlePlayOrPause(
          title: '${ep['title'] ?? ''}',
          showName: '${podcast?['name'] ?? ''}',
          duration: label,
          coverUrl: cover,
          audioUrl: audioUrl,
          videoUrl: videoUrl,
          hasAudio: hasAudio,
          hasVideo: hasVideo,
          episodeId: episodeId,
          podcastSlug: '${podcast?['slug'] ?? ''}',
          episodeSlug: '${ep['slug'] ?? ''}',
        );

    if (resumePositionSeconds != null && resumePositionSeconds > 0) {
      final active = ref.read(activeEpisodeProvider);
      if (active.episodeId == episodeId &&
          active.currentPosition == Duration.zero) {
        ref
            .read(activeEpisodeProvider.notifier)
            .seek(Duration(seconds: resumePositionSeconds));
      }
    }
  }

  Future<void> _createPlaylistDialog() async {
    final controller = TextEditingController();
    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BkoTheme.getBgSurface(ctx),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Nouvelle playlist',
          style: BkoTheme.fontPoppins(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: BkoTheme.getTextPrimary(ctx),
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: BkoTheme.fontLato(
            fontSize: 14,
            color: BkoTheme.getTextPrimary(ctx),
          ),
          decoration: InputDecoration(
            hintText: 'Nom de la playlist',
            hintStyle: BkoTheme.fontLato(
              fontSize: 14,
              color: BkoTheme.getTextSecondary(ctx),
            ),
            filled: true,
            fillColor: BkoTheme.getBgSurfaceElevated(ctx),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: BkoTheme.getBorderSubtle(ctx)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Annuler',
              style: BkoTheme.fontLato(
                fontSize: 13,
                color: BkoTheme.getTextSecondary(ctx),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: BkoTheme.goldAccent,
              foregroundColor: Colors.black,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'Créer',
              style: BkoTheme.fontPoppins(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
          ),
        ],
      ),
    );

    if (created == true && controller.text.trim().isNotEmpty) {
      final token = ref.read(authProvider).token;
      if (token == null) return;
      try {
        await BkoApi.post(
          '/playlists',
          {'name': controller.text.trim(), 'isPublic': false},
          token: token,
        );
        BkoHaptics.success();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Playlist créée avec succès !'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: BkoTheme.goldAccent,
            ),
          );
        }
        _fetchAll(silent: true);
      } catch (e) {
        BkoHaptics.error();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e is ApiException
                  ? e.message
                  : 'Impossible de créer la playlist.'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _clearHistoryConfirm() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BkoTheme.getBgSurface(ctx),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Effacer l’historique d’écoute ?',
          style: BkoTheme.fontPoppins(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: BkoTheme.getTextPrimary(ctx),
          ),
        ),
        content: Text(
          'Tous vos épisodes en cours et positions d’écoute seront réinitialisés.',
          style: BkoTheme.fontLato(
            fontSize: 13,
            color: BkoTheme.getTextSecondary(ctx),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Annuler',
              style: BkoTheme.fontLato(
                fontSize: 13,
                color: BkoTheme.getTextSecondary(ctx),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'Effacer',
              style: BkoTheme.fontPoppins(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final token = ref.read(authProvider).token;
      if (token == null) return;
      try {
        await BkoApi.delete('/me/history', token: token);
        BkoHaptics.success();
        if (mounted) {
          setState(() => _history = []);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Historique d’écoute effacé.'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: BkoTheme.goldAccent,
            ),
          );
        }
      } catch (e) {
        BkoHaptics.error();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Impossible d’effacer l’historique pour le moment.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Écoute les signaux globaux pour rafraîchir automatiquement
    ref.listen(libraryUpdateSignalProvider, (_, __) {
      _fetchAll(silent: true);
    });

    ref.listen<AuthState>(authProvider, (prev, next) {
      if (next.isAuthenticated && !(prev?.isAuthenticated ?? false)) {
        _fetchAll();
      }
    });

    final auth = ref.watch(authProvider);
    final textPri = BkoTheme.getTextPrimary(context);
    final textSec = BkoTheme.getTextSecondary(context);
    final surface = BkoTheme.getBgSurface(context);
    final elevatedSurface = BkoTheme.getBgSurfaceElevated(context);
    final border = BkoTheme.getBorderSubtle(context);

    if (!auth.isAuthenticated) {
      return _LoginPrompt(textPri: textPri, textSec: textSec);
    }

    return Scaffold(
      backgroundColor: BkoTheme.getBgObsidian(context),
      drawer: const BkoDrawer(),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // -------------------------------------------------------------
            // 1. HEADER AVEC MENU HAMBURGER & ACTIONS D'ONGLETS
            // -------------------------------------------------------------
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: Row(
                children: [
                  // Hamburger Button (ouvre le BkoDrawer)
                  BkoBounceable(
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
                        color: textPri,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Ma bibliothèque',
                      style: BkoTheme.fontPoppins(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: textPri,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  // Actions contextuelles selon l'onglet
                  if (_tab == 3)
                    BkoBounceable(
                      onTap: _createPlaylistDialog,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: elevatedSurface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: border),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              IconsaxPlusLinear.add_circle,
                              color: BkoTheme.goldAccent,
                              size: 16,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Créer',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: BkoTheme.goldAccent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (_tab == 2 && _history.isNotEmpty)
                    IconButton(
                      icon: Icon(
                        IconsaxPlusLinear.trash,
                        color: textSec,
                        size: 20,
                      ),
                      tooltip: 'Effacer l’historique',
                      onPressed: _clearHistoryConfirm,
                    )
                  else
                    IconButton(
                      icon: Icon(
                        IconsaxPlusLinear.refresh_2,
                        color: textSec,
                        size: 20,
                      ),
                      tooltip: 'Rafraîchir',
                      onPressed: () {
                        BkoHaptics.light();
                        _fetchAll();
                      },
                    ),
                ],
              ),
            ),

            // -------------------------------------------------------------
            // 2. PILLS BAR D'ONGLETS AVEC COMPTEURS EN DIRECT
            // -------------------------------------------------------------
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _tabButton(
                      label: 'Enregistrés',
                      count: _saved.length,
                      index: 0,
                      icon: IconsaxPlusLinear.archive_add,
                      surface: surface,
                      border: border,
                      textSec: textSec,
                    ),
                    const SizedBox(width: 8),
                    _tabButton(
                      label: 'Émissions suivies',
                      count: _following.length,
                      index: 1,
                      icon: IconsaxPlusLinear.heart,
                      surface: surface,
                      border: border,
                      textSec: textSec,
                    ),
                    const SizedBox(width: 8),
                    _tabButton(
                      label: 'Historique',
                      count: _history.length,
                      index: 2,
                      icon: IconsaxPlusLinear.clock,
                      surface: surface,
                      border: border,
                      textSec: textSec,
                    ),
                    const SizedBox(width: 8),
                    _tabButton(
                      label: 'Playlists',
                      count: _playlists.length,
                      index: 3,
                      icon: IconsaxPlusLinear.music_playlist,
                      surface: surface,
                      border: border,
                      textSec: textSec,
                    ),
                  ],
                ),
              ),
            ),

            // -------------------------------------------------------------
            // 3. CONTENU SCROLLABLE & REFRESH INDICATOR
            // -------------------------------------------------------------
            Expanded(
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) =>
                    handleShellScrollNotification(notification, ref),
                child: _loading &&
                        _saved.isEmpty &&
                        _following.isEmpty &&
                        _history.isEmpty &&
                        _playlists.isEmpty
                    ? ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                        itemCount: 5,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, __) => const BkoEpisodeRowSkeleton(),
                      )
                    : _errorMessage != null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    IconsaxPlusLinear.wifi_square,
                                    size: 48,
                                    color: BkoTheme.goldAccent,
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    _errorMessage!,
                                    textAlign: TextAlign.center,
                                    style: BkoTheme.fontLato(
                                      fontSize: 13,
                                      color: Colors.red.shade300,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: _fetchAll,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: BkoTheme.goldAccent,
                                      foregroundColor: Colors.black,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: Text(
                                      'Réessayer',
                                      style: BkoTheme.fontPoppins(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : _buildTabContent(
                            surface, elevatedSurface, border, textPri, textSec),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent(
    Color surface,
    Color elevatedSurface,
    Color border,
    Color textPri,
    Color textSec,
  ) {
    // -------------------------------------------------------------------------
    // ONGLET 3 : PLAYLISTS
    // -------------------------------------------------------------------------
    if (_tab == 3) {
      if (_playlists.isEmpty) {
        return _buildEmptyState(
          icon: IconsaxPlusLinear.music_playlist,
          title: 'Aucune playlist créée',
          description:
              'Créez vos propres playlists thématiques pour organiser vos épisodes favoris et les écouter en continu.',
          ctaLabel: 'Créer une playlist',
          onCta: _createPlaylistDialog,
          textPri: textPri,
          textSec: textSec,
          surface: surface,
          border: border,
        );
      }
      return RefreshIndicator(
        color: BkoTheme.goldAccent,
        backgroundColor: surface,
        onRefresh: () => _fetchAll(silent: true),
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          itemCount: _playlists.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final pl = _playlists[index] as Map;
            final count = (pl['_count']?['items'] ?? 0).toString();
            final items = (pl['items'] as List?) ?? [];
            final firstItem =
                items.isNotEmpty && items.first is Map ? items.first as Map : null;
            final ep = firstItem?['episode'] as Map?;
            final cover =
                (ep?['cover'] ?? ep?['podcast']?['cover'] ?? '').toString();

            return BkoBounceable(
              onTap: () => context.push('/playlists/${pl['id']}'),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: elevatedSurface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: border),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 48,
                        height: 48,
                        color: surface,
                        child: cover.startsWith('http')
                            ? CachedNetworkImage(
                                imageUrl: cover,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => const Icon(
                                  IconsaxPlusLinear.music_playlist,
                                  color: BkoTheme.goldAccent,
                                  size: 22,
                                ),
                              )
                            : const Icon(
                                IconsaxPlusLinear.music_playlist,
                                color: BkoTheme.goldAccent,
                                size: 22,
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${pl['name'] ?? ''}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: BkoTheme.fontPoppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: textPri,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$count épisode${count != '1' ? 's' : ''}',
                            style: BkoTheme.fontLato(
                              fontSize: 12,
                              color: textSec,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      IconsaxPlusLinear.arrow_right_3,
                      color: textSec,
                      size: 18,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    }

    // -------------------------------------------------------------------------
    // ONGLET 1 : ÉMISSIONS SUIVIES
    // -------------------------------------------------------------------------
    if (_tab == 1) {
      if (_following.isEmpty) {
        return _buildEmptyState(
          icon: IconsaxPlusLinear.heart,
          title: 'Aucune émission suivie',
          description:
              'Abonnez-vous à vos podcasts préférés pour retrouver tous leurs nouveaux épisodes ici dès leur sortie.',
          ctaLabel: 'Découvrir des émissions',
          onCta: () => context.go('/explore'),
          textPri: textPri,
          textSec: textSec,
          surface: surface,
          border: border,
        );
      }
      return RefreshIndicator(
        color: BkoTheme.goldAccent,
        backgroundColor: surface,
        onRefresh: () => _fetchAll(silent: true),
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          itemCount: _following.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final raw = _following[index];
            final podcast = (raw is Map && raw['podcast'] is Map)
                ? raw['podcast'] as Map
                : (raw as Map);
            final cover = '${podcast['cover'] ?? ''}';
            final name = '${podcast['name'] ?? 'Émission'}';
            final authorCandidate = podcast['author']?['fullName'] ??
                podcast['author']?['name'] ??
                podcast['organization']?['name'];
            final authorStr = (authorCandidate != null &&
                    authorCandidate.toString().trim().isNotEmpty &&
                    authorCandidate.toString().trim().toLowerCase() !=
                        'bamako podcast')
                ? authorCandidate.toString().trim()
                : null;
            final count =
                podcast['_count']?['episodes'] ?? podcast['episodesCount'];
            final meta = authorStr ??
                (count != null && count is num && count > 0
                    ? '$count ${count == 1 ? 'épisode' : 'épisodes'}'
                    : 'Podcast officiel');
            final slug = '${podcast['slug'] ?? ''}';

            return BkoBounceable(
              onTap: () => context.push('/podcasts/$slug'),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: elevatedSurface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: border),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: cover.startsWith('http')
                          ? CachedNetworkImage(
                              imageUrl: cover,
                              width: 52,
                              height: 52,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => _fallbackCover(),
                            )
                          : _fallbackCover(),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: BkoTheme.fontPoppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: textPri,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            meta,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: BkoTheme.fontLato(
                              fontSize: 12,
                              color: textSec,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      IconsaxPlusLinear.arrow_right_3,
                      color: textSec,
                      size: 18,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    }

    // -------------------------------------------------------------------------
    // ONGLETS 0 (ENREGISTRÉS) & 2 (HISTORIQUE)
    // -------------------------------------------------------------------------
    final isHist = _tab == 2;
    final list = isHist ? _history : _saved;

    if (list.isEmpty) {
      return _buildEmptyState(
        icon: isHist ? IconsaxPlusLinear.clock : IconsaxPlusLinear.archive_add,
        title: isHist ? 'Aucun historique d’écoute' : 'Aucun épisode enregistré',
        description: isHist
            ? 'Vos épisodes commencés apparaîtront automatiquement ici pour vous permettre de reprendre là où vous vous êtes arrêté.'
            : 'Enregistrez vos épisodes préférés en touchant les options d’un épisode pour les retrouver et les écouter à tout instant.',
        ctaLabel: isHist ? 'Commencer une écoute' : 'Explorer les épisodes',
        onCta: () => isHist ? context.go('/') : context.go('/explore'),
        textPri: textPri,
        textSec: textSec,
        surface: surface,
        border: border,
      );
    }

    return RefreshIndicator(
      color: BkoTheme.goldAccent,
      backgroundColor: surface,
      onRefresh: () => _fetchAll(silent: true),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final raw = list[index];
          final rawMap = raw is Map ? raw : {};
          final ep = (isHist && rawMap['episode'] is Map)
              ? Map<String, dynamic>.from(rawMap['episode'] as Map)
              : Map<String, dynamic>.from(rawMap);
          final posSec = isHist && rawMap['positionSeconds'] is int
              ? rawMap['positionSeconds'] as int
              : null;

          return EpisodeListItem(
            episode: ep,
            onPlay: () => _play(ep, resumePositionSeconds: posSec),
          );
        },
      ),
    );
  }

  Widget _tabButton({
    required String label,
    required int count,
    required int index,
    required IconData icon,
    required Color surface,
    required Color border,
    required Color textSec,
  }) {
    final active = _tab == index;
    return BkoBounceable(
      onTap: () => _selectTab(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? BkoTheme.goldAccent : surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active ? BkoTheme.goldAccent : border,
            width: 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: active ? Colors.black : textSec,
            ),
            const SizedBox(width: 6),
            Text(
              count > 0 ? '$label ($count)' : label,
              style: BkoTheme.fontPoppins(
                fontSize: 12,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active ? Colors.black : textSec,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String description,
    required String ctaLabel,
    required VoidCallback onCta,
    required Color textPri,
    required Color textSec,
    required Color surface,
    required Color border,
  }) {
    return RefreshIndicator(
      color: BkoTheme.goldAccent,
      backgroundColor: surface,
      onRefresh: () => _fetchAll(silent: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        children: [
          Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: border),
              ),
              child: Icon(icon, size: 32, color: BkoTheme.goldAccent),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: BkoTheme.fontPoppins(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: textPri,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            textAlign: TextAlign.center,
            style: BkoTheme.fontLato(
              fontSize: 13,
              color: textSec,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: BkoBounceable(
              onTap: onCta,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: BkoTheme.goldAccent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  ctaLabel,
                  style: BkoTheme.fontPoppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallbackCover() => Container(
        width: 52,
        height: 52,
        color: BkoTheme.goldAccent.withValues(alpha: 0.12),
        alignment: Alignment.center,
        child: const Icon(
          IconsaxPlusLinear.microphone_2,
          color: BkoTheme.goldAccent,
          size: 22,
        ),
      );
}

class _LoginPrompt extends StatelessWidget {
  final Color textPri;
  final Color textSec;
  const _LoginPrompt({required this.textPri, required this.textSec});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BkoTheme.getBgObsidian(context),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(IconsaxPlusLinear.folder_2, size: 64, color: textSec),
                const SizedBox(height: 16),
                Text(
                  'Votre bibliothèque',
                  style: BkoTheme.fontPoppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: textPri,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Connectez-vous pour retrouver vos épisodes enregistrés, vos émissions suivies, votre historique et vos playlists.',
                  textAlign: TextAlign.center,
                  style: BkoTheme.fontLato(fontSize: 13, color: textSec),
                ),
                const SizedBox(height: 24),
                BkoBounceable(
                  onTap: () {
                    BkoHaptics.light();
                    context.go('/login');
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 14),
                    decoration: BoxDecoration(
                      color: BkoTheme.goldAccent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      'SE CONNECTER',
                      style: BkoTheme.fontPoppins(
                        fontSize: 13,
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
      ),
    );
  }
}
