import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/network/bko_api.dart';
import '../../core/theme/bko_theme.dart';
import '../auth/auth_controller.dart';
import '../home/widgets/episode_actions_sheet.dart';
import '../player/widgets/bko_play_button.dart';
import '../shell/shell_providers.dart';

class PlaylistDetailsScreen extends ConsumerStatefulWidget {
  final String playlistId;
  const PlaylistDetailsScreen({super.key, required this.playlistId});

  @override
  ConsumerState<PlaylistDetailsScreen> createState() =>
      _PlaylistDetailsScreenState();
}

class _PlaylistDetailsScreenState
    extends ConsumerState<PlaylistDetailsScreen> {
  bool _loading = true;
  String? _errorMessage;
  Map<String, dynamic>? _playlist;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final token = ref.read(authProvider).token;
      final data =
          await BkoApi.get('/playlists/${widget.playlistId}', token: token);
      if (mounted) {
        setState(() {
          _playlist = data is Map ? Map<String, dynamic>.from(data) : null;
          _loading = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.message;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Impossible de charger la playlist.';
          _loading = false;
        });
      }
    }
  }

  void _play(Map ep) {
    final podcast = ep['podcast'] as Map?;
    final d = ep['durationSeconds'];
    final label = d is int ? '${(d / 60).round()} min' : '';

    final audioUrl = ep['primaryAudioSource']?['externalUrl'] ??
        BkoApi.extractAudioUrl(Map<String, dynamic>.from(ep));
    final videoUrl = ep['primaryVideoSource']?['embedUrl'] ??
        ep['primaryVideoSource']?['externalUrl'];
    final cover = '${ep['cover'] ?? podcast?['cover'] ?? ''}';

    ref.read(activeEpisodeProvider.notifier).handlePlayOrPause(
          title: '${ep['title'] ?? ''}',
          showName: '${podcast?['name'] ?? ''}',
          duration: label,
          coverUrl: cover,
          audioUrl: audioUrl,
          videoUrl: videoUrl,
          hasAudio: audioUrl != null,
          hasVideo: videoUrl != null,
          episodeId: '${ep['id'] ?? ''}',
          podcastSlug: '${podcast?['slug'] ?? ''}',
          episodeSlug: '${ep['slug'] ?? ''}',
        );
  }

  void _playAll() {
    final items = (_playlist?['items'] as List?) ?? [];
    if (items.isEmpty) return;

    final List<Map<String, dynamic>> episodes = [];
    for (var item in items) {
      final ep = (item is Map && item['episode'] is Map)
          ? Map<String, dynamic>.from(item['episode'] as Map)
          : (item is Map ? Map<String, dynamic>.from(item) : null);
      if (ep != null) episodes.add(ep);
    }
    if (episodes.isEmpty) return;

    final first = episodes.first;
    final rest = episodes.sublist(1);

    final List<QueueItem> queueItems = rest.map((ep) {
      final podcast = ep['podcast'] as Map?;
      final d = ep['durationSeconds'] as num? ?? 0;
      final label = d > 0 ? '${(d / 60).round()} min' : '';
      final audioUrl = BkoApi.extractAudioUrl(ep);
      final videoUrl = BkoApi.extractVideoUrl(ep);
      return QueueItem(
        episodeId: '${ep['id'] ?? ''}',
        title: '${ep['title'] ?? ''}',
        showName: '${podcast?['name'] ?? ''}',
        duration: label,
        coverUrl: '${ep['cover'] ?? podcast?['cover'] ?? ''}',
        audioUrl: audioUrl,
        videoUrl: videoUrl,
        hasAudio: audioUrl != null,
        hasVideo: videoUrl != null,
        podcastSlug: '${podcast?['slug'] ?? ''}',
        episodeSlug: '${ep['slug'] ?? ''}',
      );
    }).toList();

    final podcast = first['podcast'] as Map?;
    final d = first['durationSeconds'] as num? ?? 0;
    final label = d > 0 ? '${(d / 60).round()} min' : '';
    final audioUrl = BkoApi.extractAudioUrl(first);
    final videoUrl = BkoApi.extractVideoUrl(first);

    ref.read(activeEpisodeProvider.notifier).playEpisode(
          title: '${first['title'] ?? ''}',
          showName: '${podcast?['name'] ?? ''}',
          duration: label,
          coverUrl: '${first['cover'] ?? podcast?['cover'] ?? ''}',
          audioUrl: audioUrl,
          videoUrl: videoUrl,
          hasAudio: audioUrl != null,
          hasVideo: videoUrl != null,
          episodeId: '${first['id'] ?? ''}',
          podcastSlug: '${podcast?['slug'] ?? ''}',
          episodeSlug: '${first['slug'] ?? ''}',
          newQueue: queueItems,
        );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Lecture lancée : ${episodes.length} épisodes dans la file.',
          style: const TextStyle(
              color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: BkoTheme.goldAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _removeItem(String episodeId) async {
    final token = ref.read(authProvider).token;
    if (token == null) return;

    try {
      await BkoApi.delete(
          '/playlists/${widget.playlistId}/items/$episodeId',
          token: token);
      _fetch();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Épisode retiré de la playlist.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible de retirer l’épisode.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _deletePlaylist() async {
    final token = ref.read(authProvider).token;
    if (token == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF18181C),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'Supprimer cette playlist ?',
          style: BkoTheme.fontLato(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        content: Text(
          'Cette action supprimera définitivement cette playlist.',
          style: BkoTheme.fontLato(fontSize: 13, color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler',
                style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await BkoApi.delete('/playlists/${widget.playlistId}', token: token);
      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Playlist supprimée.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible de supprimer la playlist.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textPri = BkoTheme.getTextPrimary(context);
    final textSec = BkoTheme.getTextSecondary(context);
    final surface = BkoTheme.getBgSurface(context);
    final border = BkoTheme.getBorderSubtle(context);

    return Scaffold(
      backgroundColor: BkoTheme.getBgObsidian(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: textPri, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text(
          _playlist?['name'] ?? 'Playlist',
          style: BkoTheme.fontLato(
              fontSize: 18, fontWeight: FontWeight.w800, color: textPri),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: textPri),
            color: const Color(0xFF1E1E24),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            onSelected: (val) {
              if (val == 'delete') _deletePlaylist();
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline_rounded,
                        color: Colors.redAccent, size: 20),
                    SizedBox(width: 10),
                    Text('Supprimer la playlist',
                        style: TextStyle(color: Colors.redAccent)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: BkoTheme.goldAccent))
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_errorMessage!,
                          style: BkoTheme.fontLato(
                              fontSize: 13, color: Colors.red.shade300)),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _fetch,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: BkoTheme.goldAccent,
                            foregroundColor: Colors.black),
                        child: Text('Réessayer',
                            style: BkoTheme.fontLato(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Colors.black)),
                      ),
                    ],
                  ),
                )
              : _buildList(surface, border, textPri, textSec),
    );
  }

  Widget _buildList(
      Color surface, Color border, Color textPri, Color textSec) {
    final items = (_playlist?['items'] as List?) ?? [];
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.queue_music, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              Text(
                'Cette playlist est vide',
                style: BkoTheme.fontLato(
                    fontSize: 16, fontWeight: FontWeight.w800, color: textPri),
              ),
              const SizedBox(height: 4),
              Text(
                'Ajoutez des épisodes à partir de leur fiche pour les retrouver ici.',
                textAlign: TextAlign.center,
                style: BkoTheme.fontLato(fontSize: 12.5, color: textSec),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Play All Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${items.length} ÉPISODES',
                style: BkoTheme.fontLato(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  color: BkoTheme.goldAccent,
                ),
              ),
              ElevatedButton.icon(
                onPressed: _playAll,
                icon: const Icon(Icons.play_arrow_rounded,
                    color: Colors.black, size: 20),
                label: Text(
                  'TOUT LIRE',
                  style: BkoTheme.fontLato(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: BkoTheme.goldAccent,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFF222228)),

        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final ep = (item is Map && item['episode'] is Map)
                  ? Map<String, dynamic>.from(item['episode'] as Map)
                  : (item is Map ? Map<String, dynamic>.from(item) : {});
              final podcast = ep['podcast'] as Map?;
              final cover = '${ep['cover'] ?? podcast?['cover'] ?? ''}';
              final episodeId = '${ep['id'] ?? ''}';

              final d = ep['durationSeconds'];
              final label = d is int ? '${(d / 60).round()} min' : '';
              final audioUrl = ep['primaryAudioSource']?['externalUrl'] ??
                  BkoApi.extractAudioUrl(Map<String, dynamic>.from(ep));
              final videoUrl = ep['primaryVideoSource']?['embedUrl'] ??
                  ep['primaryVideoSource']?['externalUrl'];

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: border),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: cover.startsWith('http')
                          ? CachedNetworkImage(
                              imageUrl: cover,
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => _fallback(),
                            )
                          : _fallback(),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          final pSlug = podcast?['slug'] ?? '';
                          final epSlug = ep['slug'] ?? '';
                          if (pSlug.isNotEmpty && epSlug.isNotEmpty) {
                            context.push('/podcasts/$pSlug/episodes/$epSlug');
                          } else {
                            _play(ep);
                          }
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${ep['title'] ?? ''}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: BkoTheme.fontLato(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: textPri,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${podcast?['name'] ?? ''}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: BkoTheme.fontLato(
                                  fontSize: 11, color: textSec),
                            ),
                          ],
                        ),
                      ),
                    ),
                    BkoPlayButton(
                      episodeId: episodeId,
                      title: '${ep['title'] ?? ''}',
                      showName: '${podcast?['name'] ?? ''}',
                      duration: label,
                      coverUrl: cover,
                      audioUrl: audioUrl,
                      videoUrl: videoUrl,
                      hasAudio: audioUrl != null,
                      hasVideo: videoUrl != null,
                      podcastSlug: '${podcast?['slug'] ?? ''}',
                      episodeSlug: '${ep['slug'] ?? ''}',
                      size: 34,
                      iconSize: 20,
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert_rounded,
                          color: Colors.white60, size: 20),
                      color: const Color(0xFF1E1E24),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      onSelected: (val) {
                        if (val == 'options') {
                          EpisodeActionsSheet.show(
                              context, Map<String, dynamic>.from(ep));
                        } else if (val == 'remove') {
                          _removeItem(episodeId);
                        }
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(
                          value: 'options',
                          child: Row(
                            children: [
                              Icon(Icons.more_horiz_rounded,
                                  color: Colors.white70, size: 18),
                              SizedBox(width: 8),
                              Text('Options de l’épisode',
                                  style: TextStyle(color: Colors.white)),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'remove',
                          child: Row(
                            children: [
                              Icon(Icons.playlist_remove_rounded,
                                  color: Colors.redAccent, size: 18),
                              SizedBox(width: 8),
                              Text('Retirer de la playlist',
                                  style: TextStyle(color: Colors.redAccent)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _fallback() => Container(
        width: 48,
        height: 48,
        color: BkoTheme.goldAccent.withValues(alpha: 0.12),
        child: const Icon(Icons.podcasts, color: BkoTheme.goldAccent),
      );
}
