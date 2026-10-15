import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../../core/network/bko_api.dart';
import '../../core/theme/bko_theme.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/widgets/bko_bounceable.dart';
import '../../core/widgets/bko_haptics.dart';
import '../auth/auth_controller.dart';

class YoutubeChannelImportScreen extends ConsumerStatefulWidget {
  final String? initialPodcastId;
  const YoutubeChannelImportScreen({super.key, this.initialPodcastId});

  @override
  ConsumerState<YoutubeChannelImportScreen> createState() =>
      _YoutubeChannelImportScreenState();
}

class _YoutubeChannelImportScreenState
    extends ConsumerState<YoutubeChannelImportScreen> {
  final _urlController = TextEditingController();
  final _includeKeywordsController = TextEditingController();
  final _excludeKeywordsController = TextEditingController();

  int _step =
      1; // 1: URL & Podcast, 2: Preview & Selection, 3: Settings & Confirm
  bool _analyzing = false;
  bool _loadingMore = false;
  bool _archivesMode = false;
  bool _futureOnly = false;
  Timer? _statusTimer;
  bool _connecting = false;
  bool _syncingNow = false;
  String? _errorMessage;
  String? _infoMessage;

  List<dynamic> _podcasts = [];
  String? _selectedPodcastId;
  bool _loadingPodcasts = true;

  Map<String, dynamic>? _previewData;
  Map<String, dynamic>? _channelStatus;
  bool _loadingStatus = true;

  final Set<String> _selectedVideoIds = {};
  bool _autoSync = true;
  bool _autoPublish = false;
  bool _keepManualEdits = true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _statusTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted && _selectedPodcastId != null && _step == 1) {
        _fetchChannelStatus(_selectedPodcastId!);
      }
    });
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _urlController.dispose();
    _includeKeywordsController.dispose();
    _excludeKeywordsController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    final auth = ref.read(authProvider);
    if (!auth.isAuthenticated || auth.token == null) {
      if (mounted) {
        setState(() {
          _loadingPodcasts = false;
          _loadingStatus = false;
        });
      }
      return;
    }

    try {
      final res = await BkoApi.get('/creator/podcasts', token: auth.token);
      final list = (res is List
          ? res
          : (res is Map && res['data'] is List ? res['data'] : [])) as List;

      if (!mounted) return;
      setState(() {
        _podcasts = list;
        if (_podcasts.isNotEmpty) {
          _selectedPodcastId =
              _podcasts.any((p) => '${p['id']}' == widget.initialPodcastId)
                  ? widget.initialPodcastId
                  : '${_podcasts.first['id']}';
        }
        _loadingPodcasts = false;
      });

      if (_selectedPodcastId != null) {
        await _fetchChannelStatus(_selectedPodcastId!);
      } else {
        if (mounted) setState(() => _loadingStatus = false);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadingPodcasts = false;
          _loadingStatus = false;
          _errorMessage = 'Impossible de charger vos émissions.';
        });
      }
    }
  }

  Future<void> _fetchChannelStatus(String podcastId) async {
    final auth = ref.read(authProvider);
    if (auth.token == null) return;

    if (mounted && _channelStatus == null) {
      setState(() => _loadingStatus = true);
    }

    try {
      final res = await BkoApi.get('/creator/podcasts/$podcastId/youtube',
          token: auth.token);
      if (mounted && podcastId == _selectedPodcastId) {
        setState(() {
          if (res is Map && res['success'] == true && res['data'] != null) {
            final data = Map<String, dynamic>.from(res['data'] as Map);
            _channelStatus = Map<String, dynamic>.from(
                data['channel'] is Map ? data['channel'] as Map : data);
            _channelStatus!['counts'] = data['counts'];
            _autoPublish =
                _channelStatus?['importSettings']?['autoPublish'] == true;
            _autoSync = _channelStatus?['syncEnabled'] == true;
          } else {
            _channelStatus = null;
          }
          _loadingStatus = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage =
              'Impossible de charger le statut. Réessayez avant de reconnecter la chaîne.';
          _loadingStatus = false;
        });
      }
    }
  }

  Future<void> _analyzeYoutubeChannel() async {
    final input = _urlController.text.trim();
    if (input.isEmpty) {
      setState(() => _errorMessage =
          'Veuillez saisir une URL ou un identifiant de chaîne YouTube.');
      return;
    }

    if (_selectedPodcastId == null) {
      setState(() => _errorMessage =
          'Veuillez sélectionner une émission pour y associer cette chaîne.');
      return;
    }

    final auth = ref.read(authProvider);
    if (!auth.isAuthenticated || auth.token == null) return;

    setState(() {
      _analyzing = true;
      _errorMessage = null;
      _infoMessage = null;
    });

    try {
      final res = await BkoApi.post(
        '/creator/youtube/preview',
        {'url': input, 'podcastId': _selectedPodcastId},
        token: auth.token,
      );

      if (res is Map && res['success'] == true && res['data'] != null) {
        final data = Map<String, dynamic>.from(res['data'] as Map);
        final items = (data['items'] as List? ?? []);

        final preselected = <String>{};
        for (final item in items) {
          if (item is Map &&
              item['isAlreadyImported'] != true &&
              item['embeddable'] != false &&
              item['isLikelyShort'] != true) {
            preselected.add('${item['youtubeVideoId']}');
          }
        }

        if (mounted) {
          setState(() {
            _previewData = data;
            _archivesMode = false;
            _selectedVideoIds.clear();
            _selectedVideoIds.addAll(preselected);
            _step = 2;
            _analyzing = false;
          });
          BkoHaptics.light();
        }
      } else {
        final errObj = res is Map ? res['error'] : null;
        final msg = res is Map
            ? (res['message'] ?? (errObj is Map ? errObj['message'] : null))
            : null;
        throw Exception(msg ?? 'Impossible d’analyser cette chaîne YouTube.');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _analyzing = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<void> _loadMoreVideos({bool archives = false}) async {
    if (_loadingMore || _selectedPodcastId == null) return;
    setState(() {
      _loadingMore = true;
      _errorMessage = null;
    });
    final podcastId = _selectedPodcastId;
    try {
      final result = await BkoApi.post(
          '/creator/youtube/preview',
          {
            'url': archives
                ? (_channelStatus?['channelId'])
                : ((_previewData?['channel'] as Map?)?['channelId']),
            'podcastId': podcastId,
            if (!archives && _previewData?['nextPageToken'] != null)
              'pageToken': _previewData!['nextPageToken'],
          },
          token: ref.read(authProvider).token);
      final data = Map<String, dynamic>.from(result['data'] as Map);
      if (!mounted || podcastId != _selectedPodcastId) return;
      final merged = <String, dynamic>{};
      if (!archives) {
        for (final item in (_previewData?['items'] as List? ?? [])) {
          merged['${item['videoId']}'] = item;
        }
      }
      for (final item in (data['items'] as List? ?? [])) {
        merged['${item['videoId']}'] = item;
      }
      setState(() {
        _previewData = {...data, 'items': merged.values.toList()};
        if (archives) {
          _archivesMode = true;
          _futureOnly = false;
          _selectedVideoIds.clear();
          _step = 2;
        }
      });
    } catch (e) {
      if (mounted) setState(() => _errorMessage = '$e');
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _connectYoutubeChannel() async {
    if (_previewData == null || _selectedPodcastId == null) return;
    if (_selectedVideoIds.length > 500) {
      setState(() =>
          _errorMessage = "Sélectionnez au maximum 500 vidéos par import.");
      return;
    }
    if (!_futureOnly && _selectedVideoIds.isEmpty) {
      setState(() => _errorMessage = "Sélectionnez au moins une vidéo.");
      return;
    }

    final auth = ref.read(authProvider);
    if (!auth.isAuthenticated || auth.token == null) return;

    setState(() {
      _connecting = true;
      _errorMessage = null;
    });

    try {
      final channel = _previewData!['channel'] as Map? ?? {};
      final inc = _includeKeywordsController.text
          .split(',')
          .map((s) => s.trim())
          .filter((s) => s.isNotEmpty)
          .toList();
      final exc = _excludeKeywordsController.text
          .split(',')
          .map((s) => s.trim())
          .filter((s) => s.isNotEmpty)
          .toList();

      final payload = {
        'channelId': channel['channelId'],
        'channelTitle': channel['title'],
        'channelDescription': channel['description'],
        'thumbnailUrl': channel['thumbnailUrl'],
        'customUrl': channel['customUrl'],
        'uploadsPlaylistId': channel['uploadsPlaylistId'],
        'feedUrl': channel['feedUrl'],
        'selectedVideoIds': _selectedVideoIds.toList(),
        'settings': {
          'autoPublish': _autoPublish,
          'initialImportMode': _futureOnly ? 'FUTURE_ONLY' : 'SELECT',
          'keepManualEdits': _keepManualEdits,
          'autoSyncFuture': _autoSync,
          'filterKeywords': inc,
          'excludeKeywords': exc,
          'importScope': _selectedVideoIds.isNotEmpty ? 'SELECT' : 'ALL',
        },
      };

      final res = await BkoApi.post(
        _archivesMode
            ? '/creator/podcasts/$_selectedPodcastId/youtube/historical-import'
            : '/creator/podcasts/$_selectedPodcastId/youtube/connect',
        _archivesMode
            ? {'selectedVideoIds': _selectedVideoIds.toList()}
            : payload,
        token: auth.token,
      );

      if (res is Map && res['success'] == true) {
        if (mounted) {
          setState(() {
            _connecting = false;
            _step = 1;
            _previewData = null;
            _urlController.clear();
            _infoMessage = _futureOnly && !_archivesMode
                ? 'Chaîne connectée sans import des anciennes vidéos.'
                : 'Import placé en file d’attente. Consultez le suivi pour voir le résultat.';
          });
          BkoHaptics.light();
          await _fetchChannelStatus(_selectedPodcastId!);
        }
      } else {
        final errObj = res is Map ? res['error'] : null;
        final msg = res is Map
            ? (res['message'] ?? (errObj is Map ? errObj['message'] : null))
            : null;
        throw Exception(msg ?? 'Erreur lors de la connexion de la chaîne.');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _connecting = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<void> _syncNow() async {
    if (_selectedPodcastId == null) return;
    final auth = ref.read(authProvider);
    if (auth.token == null) return;

    setState(() => _syncingNow = true);
    BkoHaptics.light();

    try {
      await BkoApi.post(
        '/creator/podcasts/$_selectedPodcastId/youtube/sync',
        {},
        token: auth.token,
      );
      if (mounted) {
        setState(() => _infoMessage = 'Synchronisation lancée.');
        await Future.delayed(const Duration(seconds: 2));
        await _fetchChannelStatus(_selectedPodcastId!);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Erreur lors de la synchronisation.');
      }
    } finally {
      if (mounted) setState(() => _syncingNow = false);
    }
  }

  Future<void> _toggleSyncStatus() async {
    if (_selectedPodcastId == null || _channelStatus == null) return;
    final auth = ref.read(authProvider);
    if (auth.token == null) return;

    final currentSync = _channelStatus?['syncEnabled'] == true;
    try {
      await BkoApi.patch(
        '/creator/podcasts/$_selectedPodcastId/youtube/settings',
        {'syncEnabled': !currentSync},
        token: auth.token,
      );
      BkoHaptics.light();
      await _fetchChannelStatus(_selectedPodcastId!);
    } catch (_) {
      if (mounted) {
        setState(() => _errorMessage = 'Erreur de modification des réglages.');
      }
    }
  }

  Future<void> _disconnectChannel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161A22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Déconnecter la chaîne YouTube ?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
          'Vos épisodes déjà importés resteront sur Bamako Podcast. Seule la synchronisation automatique sera arrêtée.',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child:
                const Text('Annuler', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Déconnecter'),
          ),
        ],
      ),
    );

    if (confirmed != true || _selectedPodcastId == null) return;
    final auth = ref.read(authProvider);
    if (auth.token == null) return;

    try {
      await BkoApi.delete(
        '/creator/podcasts/$_selectedPodcastId/youtube',
        token: auth.token,
      );
      if (mounted) {
        setState(() {
          _channelStatus = null;
          _infoMessage = 'Chaîne YouTube déconnectée.';
        });
        BkoHaptics.light();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _errorMessage = 'Erreur lors de la déconnexion.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0D1117) : const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF161A22) : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: AppBackButton(
          fallbackLocation: '/studio',
          onPressed: _step > 1 ? () => setState(() => _step = _step - 1) : null,
        ),
        title: Text(
          _step == 1
              ? 'Chaîne YouTube'
              : _step == 2
                  ? 'Aperçu des vidéos'
                  : 'Paramètres d’import',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        centerTitle: true,
      ),
      body: _loadingPodcasts || _loadingStatus
          ? const Center(
              child: CircularProgressIndicator(color: BkoTheme.goldAccent),
            )
          : SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_infoMessage != null) ...[
                      _buildInfoBanner(_infoMessage!),
                      const SizedBox(height: 14),
                    ],
                    if (_errorMessage != null) ...[
                      _buildErrorBanner(_errorMessage!),
                      const SizedBox(height: 14),
                    ],
                    if (_channelStatus != null && _step == 1)
                      _buildConnectedChannelView(isDark)
                    else if (_step == 1)
                      _buildInputStep(isDark)
                    else if (_step == 2)
                      _buildPreviewStep(isDark)
                    else
                      _buildSettingsStep(isDark),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildInfoBanner(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(IconsaxPlusLinear.tick_circle,
              color: Color(0xFF10B981), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF10B981),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _infoMessage = null),
            child: const Icon(IconsaxPlusLinear.close_circle,
                color: Color(0xFF10B981), size: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(IconsaxPlusLinear.info_circle,
              color: Colors.redAccent, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.redAccent,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _errorMessage = null),
            child: const Icon(IconsaxPlusLinear.close_circle,
                color: Colors.redAccent, size: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectedChannelView(bool isDark) {
    final title = _channelStatus?['channelTitle'] ?? 'Chaîne connectée';
    final customUrl = _channelStatus?['customUrl'] ?? '';
    final thumb = _channelStatus?['thumbnailUrl'];
    final syncStatus = _channelStatus?['syncStatus'] ?? 'IDLE';
    final isSyncEnabled = _channelStatus?['syncEnabled'] == true;
    final videosCount = _channelStatus?['_count']?['importedVideos'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161A22) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF222834) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextButton(
              onPressed:
                  _loadingMore ? null : () => _loadMoreVideos(archives: true),
              child: const Text('Parcourir et importer les anciennes vidéos')),
          if (_channelStatus?['errorMessage'] != null)
            Text(_channelStatus!['errorMessage'].toString(),
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ...((_channelStatus?['syncRuns'] as List?) ?? []).take(3).map((run) =>
              Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                      "${run['status']} · ${run['videosImported'] ?? 0} importées · ${run['videosFailed'] ?? 0} erreurs",
                      style: Theme.of(context).textTheme.bodySmall))),
          Row(
            children: [
              if (thumb != null && thumb.toString().isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.network(
                    thumb,
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                      IconsaxPlusLinear.video,
                      color: BkoTheme.goldAccent,
                      size: 28,
                    ),
                  ),
                )
              else
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(IconsaxPlusLinear.video,
                      color: Colors.redAccent, size: 28),
                ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isSyncEnabled
                                ? const Color(0xFF10B981)
                                    .withValues(alpha: 0.15)
                                : Colors.grey.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            syncStatus,
                            style: TextStyle(
                              color: isSyncEnabled
                                  ? const Color(0xFF10B981)
                                  : Colors.grey,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (customUrl.isNotEmpty)
                      Text(
                        customUrl,
                        style: TextStyle(
                          color: isDark ? Colors.white60 : Colors.black54,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatColumn('Vidéos', '$videosCount', isDark),
                _buildStatColumn(
                  'Mode',
                  _autoPublish ? 'Direct' : 'Brouillon',
                  isDark,
                ),
                _buildStatColumn(
                  'WebSub',
                  _channelStatus?['webSubStatus'] == 'ACTIVE'
                      ? 'Actif'
                      : 'Polling',
                  isDark,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: BkoBounceable(
                  onTap: _syncingNow ? null : _syncNow,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: BkoTheme.goldAccent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(IconsaxPlusLinear.refresh,
                            color: Colors.black, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          _syncingNow ? 'En cours...' : 'Synchroniser',
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              BkoBounceable(
                onTap: _toggleSyncStatus,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF222834)
                        : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    isSyncEnabled
                        ? IconsaxPlusLinear.pause
                        : IconsaxPlusLinear.play,
                    color: isDark ? Colors.white : Colors.black87,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              BkoBounceable(
                onTap: _disconnectChannel,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    IconsaxPlusLinear.trash,
                    color: Colors.redAccent,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, bool isDark) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: isDark ? Colors.white54 : Colors.black54,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildInputStep(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161A22) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? const Color(0xFF222834) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Émission d’accueil',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Choisissez l’émission qui recevra les épisodes vidéo de YouTube.',
                style: TextStyle(
                  color: isDark ? Colors.white54 : Colors.black54,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 12),
              if (_podcasts.isEmpty)
                Text(
                  'Aucune émission disponible. Créez d’abord une émission dans le Studio.',
                  style: TextStyle(
                    color: Colors.redAccent.shade200,
                    fontSize: 12,
                  ),
                )
              else
                DropdownButtonFormField<String>(
                  initialValue: _selectedPodcastId,
                  dropdownColor:
                      isDark ? const Color(0xFF161A22) : Colors.white,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    filled: true,
                    fillColor: isDark
                        ? const Color(0xFF0D1117)
                        : const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  items: _podcasts.map<DropdownMenuItem<String>>((p) {
                    return DropdownMenuItem<String>(
                      value: '${p['id']}',
                      child: Text(
                        '${p['name']}',
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                          fontSize: 13,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedPodcastId = val;
                      _previewData = null;
                      _selectedVideoIds.clear();
                      _channelStatus = null;
                      _step = 1;
                    });
                    if (val != null) _fetchChannelStatus(val);
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161A22) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? const Color(0xFF222834) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Lien ou identifiant de la chaîne YouTube',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Exemples : https://youtube.com/@MaChaine ou @MaChaine ou identifiant UC...',
                style: TextStyle(
                  color: isDark ? Colors.white54 : Colors.black54,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _urlController,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontSize: 13,
                ),
                decoration: InputDecoration(
                  hintText: 'https://youtube.com/@lespitchounestv',
                  hintStyle: TextStyle(
                    color: isDark ? Colors.white38 : Colors.black38,
                    fontSize: 13,
                  ),
                  filled: true,
                  fillColor: isDark
                      ? const Color(0xFF0D1117)
                      : const Color(0xFFF1F5F9),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: const Icon(
                    IconsaxPlusLinear.video,
                    color: Colors.redAccent,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              BkoBounceable(
                onTap: _analyzing ? null : _analyzeYoutubeChannel,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: BkoTheme.goldAccent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_analyzing)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      else ...[
                        const Icon(IconsaxPlusLinear.search_status,
                            color: Colors.black, size: 18),
                        const SizedBox(width: 8),
                        const Text(
                          'Analyser la chaîne',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewStep(bool isDark) {
    final channel = _previewData?['channel'] as Map? ?? {};
    final title = channel['title'] ?? 'Chaîne YouTube';
    final thumb = channel['thumbnailUrl'];
    final items = (_previewData?['items'] as List? ?? []);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161A22) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark ? const Color(0xFF222834) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            children: [
              if (thumb != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    thumb,
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                  ),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${items.length} vidéo(s) • ${_selectedVideoIds.length} sélectionnée(s)',
                      style: const TextStyle(
                        color: BkoTheme.goldAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: () {
                setState(() {
                  for (final item in items) {
                    if (item is Map) {
                      if (item['isAlreadyImported'] != true &&
                          item['embeddable'] != false &&
                          item['isLikelyShort'] != true) {
                        _selectedVideoIds.add('${item['youtubeVideoId']}');
                      }
                    }
                  }
                });
                BkoHaptics.light();
              },
              child: const Text('Tout sélectionner',
                  style: TextStyle(
                      color: BkoTheme.goldAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
            ),
            TextButton(
              onPressed: () {
                setState(() => _selectedVideoIds.clear());
                BkoHaptics.light();
              },
              child: Text('Tout désélectionner',
                  style: TextStyle(
                      color: isDark ? Colors.white60 : Colors.black54,
                      fontSize: 12)),
            ),
          ],
        ),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final item = items[index] as Map? ?? {};
            final videoId = '${item['youtubeVideoId']}';
            final videoTitle = '${item['title'] ?? ''}';
            final vThumb = item['thumbnailUrl'];
            final isSelected = _selectedVideoIds.contains(videoId);
            final isImported = item['isAlreadyImported'] == true;

            return BkoBounceable(
              onTap: () {
                setState(() {
                  if (isSelected) {
                    _selectedVideoIds.remove(videoId);
                  } else {
                    _selectedVideoIds.add(videoId);
                  }
                });
                BkoHaptics.light();
              },
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? BkoTheme.goldAccent.withValues(alpha: 0.08)
                      : (isDark ? const Color(0xFF161A22) : Colors.white),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected
                        ? BkoTheme.goldAccent.withValues(alpha: 0.4)
                        : (isDark
                            ? const Color(0xFF222834)
                            : const Color(0xFFE2E8F0)),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isSelected
                          ? IconsaxPlusBold.tick_circle
                          : IconsaxPlusLinear.tick_circle,
                      color: isSelected
                          ? BkoTheme.goldAccent
                          : (isDark ? Colors.white30 : Colors.black26),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    if (vThumb != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          vThumb,
                          width: 56,
                          height: 36,
                          fit: BoxFit.cover,
                        ),
                      ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            videoTitle,
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                item['duration'] != null &&
                                        (item['duration'] as num) > 0
                                    ? '${((item['duration'] as num) / 60).floor()} min'
                                    : 'Durée inconnue',
                                style: TextStyle(
                                  color:
                                      isDark ? Colors.white38 : Colors.black38,
                                  fontSize: 10,
                                ),
                              ),
                              if (isImported) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'Déjà importé',
                                    style: TextStyle(
                                        color: Colors.grey, fontSize: 9),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 18),
        Text(_previewData?['note']?.toString() ?? '',
            style: Theme.of(context).textTheme.bodySmall),
        if (_previewData?['nextPageToken'] != null)
          TextButton(
              onPressed: _loadingMore ? null : () => _loadMoreVideos(),
              child: Text(_loadingMore
                  ? 'Chargement…'
                  : 'Charger les vidéos suivantes / anciennes')),
        if (!_archivesMode)
          SwitchListTile.adaptive(
              value: _futureOnly,
              onChanged: (v) => setState(() => _futureOnly = v),
              title:
                  const Text('Suivre uniquement les prochaines publications'),
              subtitle: const Text('Aucune ancienne vidéo ne sera importée.')),
        BkoBounceable(
          onTap: _selectedVideoIds.isEmpty && !_futureOnly
              ? null
              : () {
                  setState(() => _step = 3);
                  BkoHaptics.light();
                },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: BkoTheme.goldAccent,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Text(
              'Continuer (${_selectedVideoIds.length} sélectionnées)',
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsStep(bool isDark) {
    if (_archivesMode) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text("Importer ${_selectedVideoIds.length} vidéos sélectionnées",
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        const Text(
            "Les réglages actuels de votre chaîne seront conservés. Les épisodes déjà importés ne seront pas dupliqués."),
        const SizedBox(height: 20),
        FilledButton(
            onPressed: _connecting ? null : _connectYoutubeChannel,
            child: Text(_connecting
                ? "Mise en file…"
                : "Confirmer l’import des archives"))
      ]);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161A22) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? const Color(0xFF222834) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Column(
            children: [
              SwitchListTile.adaptive(
                value: _autoSync,
                activeTrackColor: BkoTheme.goldAccent,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Synchroniser les futures vidéos',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  'Vérifie périodiquement la chaîne et importe automatiquement les nouveaux épisodes.',
                  style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.black54,
                    fontSize: 11,
                  ),
                ),
                onChanged: (val) => setState(() => _autoSync = val),
              ),
              const Divider(height: 24),
              SwitchListTile.adaptive(
                value: _autoPublish,
                activeTrackColor: BkoTheme.goldAccent,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Publier directement',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  'Si désactivé, les vidéos seront créées à l’état de brouillon pour validation avant publication.',
                  style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.black54,
                    fontSize: 11,
                  ),
                ),
                onChanged: (val) => setState(() => _autoPublish = val),
              ),
              const Divider(height: 24),
              SwitchListTile.adaptive(
                value: _keepManualEdits,
                activeTrackColor: BkoTheme.goldAccent,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Protéger mes éditions locales',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  'Empêche la synchronisation d’écraser vos titres ou descriptions personnalisés.',
                  style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.black54,
                    fontSize: 11,
                  ),
                ),
                onChanged: (val) => setState(() => _keepManualEdits = val),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        BkoBounceable(
          onTap: _connecting ? null : _connectYoutubeChannel,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: BkoTheme.goldAccent,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_connecting)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.black,
                    ),
                  )
                else ...[
                  const Icon(IconsaxPlusBold.tick_circle,
                      color: Colors.black, size: 18),
                  const SizedBox(width: 8),
                  const Text(
                    'Confirmer et démarrer l’importation',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

extension _IterableExt<T> on Iterable<T> {
  Iterable<T> filter(bool Function(T) test) => where(test);
}
