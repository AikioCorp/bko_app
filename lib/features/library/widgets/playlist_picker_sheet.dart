import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/bko_api.dart';
import '../../../core/theme/bko_theme.dart';
import '../../../core/widgets/bko_toast.dart';
import '../../auth/auth_controller.dart';
import '../../auth/auth_modal.dart';
import '../library_screen.dart';

class PlaylistPickerSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> episode;

  const PlaylistPickerSheet({
    super.key,
    required this.episode,
  });

  static Future<void> show(BuildContext context, Map<String, dynamic> episode) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PlaylistPickerSheet(episode: episode),
    );
  }

  @override
  ConsumerState<PlaylistPickerSheet> createState() => _PlaylistPickerSheetState();
}

class _PlaylistPickerSheetState extends ConsumerState<PlaylistPickerSheet> {
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _playlists = [];
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchPlaylists();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchPlaylists() async {
    final auth = ref.read(authProvider);
    if (!auth.isAuthenticated || auth.token == null) {
      if (mounted) {
        Navigator.pop(context);
        AuthRequiredModal.show(context, actionTitle: 'gérer vos playlists');
      }
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await BkoApi.get('/me/playlists', token: auth.token);
      if (!mounted) return;
      if (res is List) {
        setState(() {
          _playlists = res.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _playlists = [];
          _isLoading = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Impossible de charger vos playlists.';
        _isLoading = false;
      });
    }
  }

  Future<void> _addToPlaylist(Map<String, dynamic> playlist) async {
    final playlistId = '${playlist['id'] ?? ''}';
    final playlistName = '${playlist['name'] ?? 'Playlist'}';
    final episodeId = '${widget.episode['id'] ?? ''}';
    final token = ref.read(authProvider).token;

    if (playlistId.isEmpty || episodeId.isEmpty || token == null) return;

    try {
      await BkoApi.post(
        '/playlists/$playlistId/items',
        {'episodeId': episodeId},
        token: token,
      );

      if (!mounted) return;
      ref.read(libraryUpdateSignalProvider.notifier).state++;
      Navigator.pop(context);
      BkoToast.showPlaylist(
        context,
        playlistName: playlistName,
        episodeTitle: '${widget.episode['title'] ?? ''}',
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      BkoToast.showError(
        context,
        title: 'Ajout impossible',
        message: e.message,
      );
    } catch (_) {
      if (!mounted) return;
      BkoToast.showError(
        context,
        title: 'Ajout impossible',
        message: 'Impossible d’ajouter l’épisode à cette playlist.',
      );
    }
  }

  Future<void> _showCreatePlaylistDialog() async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    bool isPublic = true;

    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final surface = BkoTheme.getBgSurface(ctx);
          final textPri = BkoTheme.getTextPrimary(ctx);
          final textSec = BkoTheme.getTextSecondary(ctx);

          return AlertDialog(
            backgroundColor: surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              'Créer une playlist',
              style: BkoTheme.fontLato(fontSize: 18, fontWeight: FontWeight.w800, color: textPri),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameCtrl,
                    autofocus: true,
                    style: BkoTheme.fontLato(fontSize: 14, color: textPri),
                    decoration: InputDecoration(
                      labelText: 'Nom de la playlist *',
                      labelStyle: TextStyle(color: textSec, fontSize: 13),
                      hintText: 'Ex: Mes favoris tech...',
                      hintStyle: TextStyle(color: textSec.withValues(alpha: 0.5), fontSize: 13),
                      filled: true,
                      fillColor: BkoTheme.getTextPrimary(context).withValues(alpha: 0.05),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: descCtrl,
                    maxLines: 2,
                    style: BkoTheme.fontLato(fontSize: 14, color: textPri),
                    decoration: InputDecoration(
                      labelText: 'Description (optionnel)',
                      labelStyle: TextStyle(color: textSec, fontSize: 13),
                      filled: true,
                      fillColor: BkoTheme.getTextPrimary(context).withValues(alpha: 0.05),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Playlist publique',
                        style: BkoTheme.fontLato(fontSize: 13, fontWeight: FontWeight.w600, color: textPri),
                      ),
                      Switch(
                        value: isPublic,
                        activeThumbColor: BkoTheme.goldAccent,
                        onChanged: (val) => setDialogState(() => isPublic = val),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('Annuler', style: BkoTheme.fontLato(fontSize: 13, color: textSec)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: BkoTheme.goldAccent,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Créer', style: BkoTheme.fontLato(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black)),
              ),
            ],
          );
        },
      ),
    );

    if (created == true && nameCtrl.text.trim().isNotEmpty) {
      final token = ref.read(authProvider).token;
      if (token == null) return;
      try {
        final newPlaylist = await BkoApi.post(
          '/playlists',
          {
            'name': nameCtrl.text.trim(),
            'description': descCtrl.text.trim(),
            'visibility': isPublic ? 'PUBLIC' : 'PRIVATE',
            'isPublic': isPublic,
          },
          token: token,
        );

        if (newPlaylist is Map) {
          // Immediately add current episode to the newly created playlist
          await _addToPlaylist(Map<String, dynamic>.from(newPlaylist));
        } else {
          ref.read(libraryUpdateSignalProvider.notifier).state++;
          _fetchPlaylists();
        }
      } catch (_) {
        if (mounted) {
          BkoToast.showError(
            context,
            title: 'Création impossible',
            message: 'Impossible de créer la playlist.',
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgSurface = BkoTheme.getBgSurface(context);
    final textPri = BkoTheme.getTextPrimary(context);
    final textSec = BkoTheme.getTextSecondary(context);
    final border = BkoTheme.getBorderSubtle(context);

    final filtered = _searchQuery.isEmpty
        ? _playlists
        : _playlists.where((p) {
            final name = '${p['name'] ?? ''}'.toLowerCase();
            return name.contains(_searchQuery.toLowerCase());
          }).toList();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: BoxDecoration(
        color: bgSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: border),
      ),
      padding: EdgeInsets.only(
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: BkoTheme.getBorderStrong(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Ajouter à une playlist',
                  style: BkoTheme.fontLato(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: textPri,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: BkoTheme.getTextSecondary(context)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Search & New Playlist Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: BkoTheme.getBgSurface(context),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: border),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: BkoTheme.fontLato(fontSize: 13, color: textPri),
                      onChanged: (val) => setState(() => _searchQuery = val),
                      decoration: InputDecoration(
                        hintText: 'Rechercher une playlist...',
                        hintStyle: BkoTheme.fontLato(fontSize: 13, color: textSec),
                        prefixIcon: Icon(Icons.search_rounded, size: 20, color: BkoTheme.getTextSecondary(context)),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: _showCreatePlaylistDialog,
                    icon: const Icon(Icons.add_rounded, size: 18, color: Colors.black),
                    label: Text(
                      'Créer',
                      style: BkoTheme.fontLato(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: BkoTheme.goldAccent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),
          Divider(height: 1, color: BkoTheme.getBorderSubtle(context)),

          // Playlists List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: BkoTheme.goldAccent))
                : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_errorMessage!, style: TextStyle(color: BkoTheme.getTextSecondary(context))),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: _fetchPlaylists,
                              child: Text('Réessayer', style: TextStyle(color: BkoTheme.getAccent(context))),
                            ),
                          ],
                        ),
                      )
                    : filtered.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.queue_music_rounded, size: 44, color: BkoTheme.getTextSecondary(context)),
                                  const SizedBox(height: 10),
                                  Text(
                                    _searchQuery.isNotEmpty
                                        ? 'Aucune playlist ne correspond à votre recherche.'
                                        : 'Vous n’avez aucune playlist pour le moment.',
                                    textAlign: TextAlign.center,
                                    style: BkoTheme.fontLato(fontSize: 13.5, color: textSec),
                                  ),
                                  const SizedBox(height: 16),
                                  OutlinedButton.icon(
                                    onPressed: _showCreatePlaylistDialog,
                                    icon: Icon(Icons.add_rounded, color: BkoTheme.getAccent(context)),
                                    label: Text(
                                      'Créer ma première playlist',
                                      style: BkoTheme.fontLato(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: BkoTheme.getAccent(context),
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: BkoTheme.goldAccent),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => Divider(height: 1, color: BkoTheme.getBgSurfaceElevated(context)),
                            itemBuilder: (context, index) {
                              final item = filtered[index];
                              final itemCount = item['_count']?['items'] ?? item['items']?.length ?? 0;
                              final isPrivate = item['visibility'] == 'PRIVATE' || item['isPublic'] == false;

                              return Material(
                                color: Colors.transparent,
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  leading: Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: BkoTheme.getBgSurface(context),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: border),
                                    ),
                                    child: Icon(Icons.queue_music_rounded, color: BkoTheme.getAccent(context), size: 22),
                                  ),
                                  title: Text(
                                    item['name'] ?? 'Playlist',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: BkoTheme.fontLato(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w700,
                                      color: textPri,
                                    ),
                                  ),
                                  subtitle: Row(
                                    children: [
                                      if (isPrivate) ...[
                                        Icon(Icons.lock_rounded, size: 12, color: BkoTheme.getTextSecondary(context)),
                                        const SizedBox(width: 4),
                                      ],
                                      Text(
                                        '$itemCount épisodes',
                                        style: BkoTheme.fontLato(fontSize: 12, color: textSec),
                                      ),
                                    ],
                                  ),
                                  trailing: Icon(Icons.add_circle_outline_rounded, color: BkoTheme.getAccent(context), size: 24),
                                  onTap: () => _addToPlaylist(item),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
