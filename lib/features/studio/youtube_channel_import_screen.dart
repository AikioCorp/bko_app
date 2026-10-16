import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../../core/network/bko_api.dart';
import '../../core/theme/bko_theme.dart';
import '../../core/utils/youtube_url_parser.dart';
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
  final _podcastNameController = TextEditingController();
  final _podcastDescController = TextEditingController();
  final _includeKeywordsController = TextEditingController();
  final _excludeKeywordsController = TextEditingController();
  String _targetMode = 'new';
  String? _createdPodcastId;

  int _step =
      1; // 1: URL & Podcast, 2: Preview & Selection, 3: Settings & Confirm
  bool _analyzing = false;
  bool _loadingMore = false;
  bool _archivesMode = false;
  bool _futureOnly = false;
  String _discoveryMode = 'STANDARD';
  bool _matchesDiscovery(Map item) =>
      _discoveryMode == 'ALL' ||
      (_discoveryMode == 'SHORTS'
          ? item['isLikelyShort'] == true
          : item['isLikelyShort'] != true);
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
    _statusTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted && _selectedPodcastId != null && _step == 1) {
        _fetchChannelStatus(_selectedPodcastId!, silent: true);
      }
    });
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _urlController.dispose();
    _podcastNameController.dispose();
    _podcastDescController.dispose();
    _includeKeywordsController.dispose();
    _excludeKeywordsController.dispose();
    super.dispose();
  }

  String _extractVideoIdFromItem(Map item) {
    final id = item['youtubeVideoId'] ?? item['videoId'] ?? '';
    return '$id'.trim();
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
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingPodcasts = false;
          _loadingStatus = false;
          _errorMessage = e is ApiException
              ? e.message
              : 'Impossible de charger vos émissions.';
        });
      }
    }
  }

  Future<void> _fetchChannelStatus(String podcastId,
      {bool silent = false}) async {
    final auth = ref.read(authProvider);
    if (auth.token == null) return;

    if (mounted && _channelStatus == null && !silent) {
      setState(() => _loadingStatus = true);
    }

    try {
      final res = await BkoApi.get(
        '/creator/podcasts/$podcastId/youtube',
        token: auth.token,
      );
      if (!mounted || podcastId != _selectedPodcastId) return;

      setState(() {
        // BkoApi retourne déjà payload['data'] : soit null, soit { channel: {...}, counts: {...} }, soit l'objet chaîne directement
        Map<String, dynamic>? channelMap;
        Map<String, dynamic>? countsMap;

        if (res is Map) {
          if (res['channel'] is Map) {
            channelMap = Map<String, dynamic>.from(res['channel'] as Map);
            if (res['counts'] is Map) {
              countsMap = Map<String, dynamic>.from(res['counts'] as Map);
            }
          } else if (res['channelId'] != null || res['id'] != null) {
            channelMap = Map<String, dynamic>.from(res);
            if (res['counts'] is Map) {
              countsMap = Map<String, dynamic>.from(res['counts'] as Map);
            }
          }
        }

        if (channelMap != null) {
          if (countsMap != null) {
            channelMap['counts'] = countsMap;
          }
          _channelStatus = channelMap;
          final settings = channelMap['importSettings'] is Map
              ? Map<String, dynamic>.from(channelMap['importSettings'] as Map)
              : <String, dynamic>{};
          _autoPublish = settings['autoPublish'] == true;
          _keepManualEdits = settings['keepManualEdits'] != false;
          _autoSync = channelMap['syncEnabled'] == true;

          if (!silent) {
            final inc = (settings['includeKeywords'] as List?) ??
                (settings['filterKeywords'] as List?) ??
                const [];
            final exc = (settings['excludeKeywords'] as List?) ?? const [];
            _includeKeywordsController.text =
                inc.map((e) => '$e').where((s) => s.isNotEmpty).join(', ');
            _excludeKeywordsController.text =
                exc.map((e) => '$e').where((s) => s.isNotEmpty).join(', ');
          }
        } else {
          _channelStatus = null;
        }
        _loadingStatus = false;
      });
    } catch (e) {
      if (mounted && !silent) {
        setState(() {
          _errorMessage = e is ApiException
              ? e.message
              : 'Impossible de charger le statut de la chaîne YouTube.';
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

    if (YoutubeUrlParser.isDeceptiveYoutubeDomain(input)) {
      setState(() => _errorMessage =
          'Domaine non reconnu : utilisez une adresse officielle youtube.com ou un identifiant de chaîne (UC... / @nom).');
      return;
    }

    if (YoutubeUrlParser.tryParseVideoId(input) != null) {
      setState(() => _errorMessage =
          'Ceci est le lien d’une vidéo isolée, pas d’une chaîne. Pour ajouter une seule vidéo YouTube, utilisez l’écran « Nouvel épisode ». Pour connecter une chaîne, saisissez son adresse (ex: https://www.youtube.com/@MaChaine ou UC...).');
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
        {
          'url': input,
          if (_selectedPodcastId != null) 'podcastId': _selectedPodcastId,
          'mode': _discoveryMode,
        },
        token: auth.token,
      );

      // BkoApi retourne directement payload['data'] (ou lève ApiException en cas d'échec)
      final Map<String, dynamic> data;
      if (res is Map && res['data'] is Map && res['channel'] == null) {
        data = Map<String, dynamic>.from(res['data'] as Map);
      } else if (res is Map) {
        data = Map<String, dynamic>.from(res);
      } else {
        throw const ApiException('Impossible d’analyser cette chaîne YouTube.');
      }

      final rawItems =
          (data['items'] as List?) ?? (data['videos'] as List?) ?? [];
      final normalizedItems = <Map<String, dynamic>>[];
      final preselected = <String>{};

      for (final raw in rawItems) {
        if (raw is Map) {
          final item = Map<String, dynamic>.from(raw);
          final vid = _extractVideoIdFromItem(item);
          if (vid.isNotEmpty) {
            item['youtubeVideoId'] = vid;
            item['videoId'] = vid;
            normalizedItems.add(item);
            if (item['isAlreadyImported'] != true &&
                item['embeddable'] != false &&
                _matchesDiscovery(item)) {
              preselected.add(vid);
            }
          }
        }
      }

      data['items'] = normalizedItems;

      if (mounted) {
        final channel = data['channel'] as Map? ?? {};
        _podcastNameController.text = channel['title']?.toString() ??
            channel['channelTitle']?.toString() ??
            '';
        _podcastDescController.text = channel['description']?.toString() ??
            channel['channelDescription']?.toString() ??
            '';
        if (_selectedPodcastId == null || _podcasts.isEmpty) {
          _targetMode = 'new';
        }

        setState(() {
          _previewData = data;
          _archivesMode = false;
          _futureOnly = false;
          _selectedVideoIds
            ..clear()
            ..addAll(preselected);
          _step = 2;
          _analyzing = false;
        });
        BkoHaptics.light();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _analyzing = false;
          _errorMessage = e is ApiException
              ? e.message
              : e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<void> _loadMoreVideos({bool archives = false}) async {
    if (_loadingMore || _selectedPodcastId == null) return;
    final auth = ref.read(authProvider);
    if (auth.token == null) return;

    setState(() {
      _loadingMore = true;
      _errorMessage = null;
    });

    final podcastId = _selectedPodcastId!;
    final isArchiveFlow = archives || _archivesMode;
    final pageToken = (!archives && _previewData != null)
        ? _previewData!['nextPageToken'] as String?
        : null;

    try {
      final dynamic result;
      if (isArchiveFlow) {
        result = await BkoApi.post(
          '/creator/podcasts/$podcastId/youtube/historical-import',
          {
            'mode': _discoveryMode,
            if (pageToken != null) 'pageToken': pageToken,
          },
          token: auth.token,
        );
      } else {
        final channelUrl = (_previewData?['channel'] as Map?)?['channelId'] ??
            _urlController.text.trim();
        result = await BkoApi.post(
          '/creator/youtube/preview',
          {
            'url': channelUrl,
            'podcastId': podcastId,
            if (pageToken != null) 'pageToken': pageToken,
          },
          token: auth.token,
        );
      }

      final Map<String, dynamic> data;
      if (result is Map &&
          result['data'] is Map &&
          result['items'] == null &&
          result['videos'] == null) {
        data = Map<String, dynamic>.from(result['data'] as Map);
      } else if (result is Map) {
        data = Map<String, dynamic>.from(result);
      } else {
        throw const ApiException(
            'Impossible de charger les vidéos de la chaîne.');
      }

      if (!mounted || podcastId != _selectedPodcastId) return;

      final merged = <String, Map<String, dynamic>>{};
      if (!archives) {
        for (final raw in (_previewData?['items'] as List? ?? [])) {
          if (raw is Map) {
            final item = Map<String, dynamic>.from(raw);
            final id = _extractVideoIdFromItem(item);
            if (id.isNotEmpty) {
              item['youtubeVideoId'] = id;
              item['videoId'] = id;
              merged[id] = item;
            }
          }
        }
      }

      final newRawItems =
          (data['items'] as List?) ?? (data['videos'] as List?) ?? [];
      for (final raw in newRawItems) {
        if (raw is Map) {
          final item = Map<String, dynamic>.from(raw);
          final id = _extractVideoIdFromItem(item);
          if (id.isNotEmpty) {
            item['youtubeVideoId'] = id;
            item['videoId'] = id;
            merged[id] = item;
          }
        }
      }

      setState(() {
        _previewData = {
          ...(_previewData ?? const <String, dynamic>{}),
          ...data,
          'items': merged.values.toList(),
        };
        if (archives) {
          _archivesMode = true;
          _futureOnly = false;
          _selectedVideoIds.clear();
          _step = 2;
        }
      });
      BkoHaptics.light();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e is ApiException
              ? e.message
              : e.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _connectYoutubeChannel() async {
    if (_previewData == null || _selectedPodcastId == null) return;
    if (_selectedVideoIds.length > 500) {
      setState(() =>
          _errorMessage = 'Sélectionnez au maximum 500 vidéos par import.');
      return;
    }
    if (!_futureOnly && _selectedVideoIds.isEmpty) {
      setState(
          () => _errorMessage = 'Sélectionnez au moins une vidéo à importer.');
      return;
    }

    final auth = ref.read(authProvider);
    if (!auth.isAuthenticated || auth.token == null) return;

    setState(() {
      _connecting = true;
      _errorMessage = null;
      _infoMessage = null;
    });

    try {
      final channel = _previewData!['channel'] as Map? ?? {};
      final inc = _includeKeywordsController.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      final exc = _excludeKeywordsController.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      final selectedList =
          _futureOnly ? <String>[] : _selectedVideoIds.toList();

      String? podcastIdToUse = _targetMode == 'existing' ? _selectedPodcastId : _createdPodcastId;

      if (_targetMode == 'new' && podcastIdToUse == null) {
        final title = _podcastNameController.text.trim();
        if (title.isEmpty) {
          setState(() {
            _connecting = false;
            _errorMessage = 'Veuillez renseigner un titre pour l\'émission.';
          });
          return;
        }

        final createRes = await BkoApi.post(
          '/creator/podcasts',
          {
            'name': title,
            'description': _podcastDescController.text.trim(),
            'cover': channel['thumbnailUrl']?.toString() ?? '',
            'countryId': 'ML',
            'primaryLanguageCode': 'fr',
            'status': 'DRAFT',
          },
          token: auth.token,
        );

        final createMap = createRes is Map ? Map<String, dynamic>.from(createRes) : <String, dynamic>{};
        podcastIdToUse = '${createMap['id'] ?? createMap['data']?['id']}';
        _createdPodcastId = podcastIdToUse;
        _selectedPodcastId = podcastIdToUse;
      }

      if (podcastIdToUse == null) {
        setState(() {
          _connecting = false;
          _errorMessage = 'Veuillez sélectionner une émission de destination.';
        });
        return;
      }

      final payload = {
        'channelId': channel['channelId'],
        'channelTitle': channel['title'] ?? _podcastNameController.text.trim(),
        'channelDescription': channel['description'] ?? _podcastDescController.text.trim(),
        'thumbnailUrl': channel['thumbnailUrl'],
        'customUrl': channel['customUrl'],
        'uploadsPlaylistId': channel['uploadsPlaylistId'],
        'feedUrl': channel['feedUrl'],
        'selectedVideoIds': selectedList,
        'settings': {
          'autoPublish': _autoPublish,
          'excludeShorts': _discoveryMode == 'STANDARD',
          'initialImportMode': _futureOnly ? 'FUTURE_ONLY' : 'SELECT',
          'keepManualEdits': _keepManualEdits,
          'autoSyncFuture': _autoSync,
          'includeKeywords': inc,
          'filterKeywords': inc,
          'excludeKeywords': exc,
          'importScope': selectedList.isNotEmpty ? 'SELECT' : 'ALL',
        },
      };

      final res = await BkoApi.post(
        _archivesMode
            ? '/creator/podcasts/$podcastIdToUse/youtube/historical-import'
            : '/creator/podcasts/$podcastIdToUse/youtube/connect',
        _archivesMode ? {'selectedVideoIds': selectedList} : payload,
        token: auth.token,
      );

      final Map<String, dynamic> data = res is Map
          ? Map<String, dynamic>.from(
              res['data'] is Map ? res['data'] as Map : res)
          : <String, dynamic>{};

      final serverMessage = data['message']?.toString();
      final defaultMessage = _archivesMode
          ? 'Import de ${selectedList.length} vidéo(s) placé en file d’attente. Suivez la progression ci-dessous.'
          : (_futureOnly
              ? 'Chaîne YouTube enregistrée. Les prochaines publications seront synchronisées.'
              : 'Chaîne enregistrée et import de ${selectedList.length} vidéo(s) placé en file d’attente.');

      if (mounted) {
        setState(() {
          _connecting = false;
          _step = 1;
          _archivesMode = false;
          _previewData = null;
          _urlController.clear();
          _infoMessage = (serverMessage != null && serverMessage.isNotEmpty)
              ? serverMessage
              : defaultMessage;
        });
        BkoHaptics.light();
        await _fetchChannelStatus(_selectedPodcastId!);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _connecting = false;
          _errorMessage = e is ApiException
              ? e.message
              : e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<void> _syncNow() async {
    if (_selectedPodcastId == null || _syncingNow) return;
    final auth = ref.read(authProvider);
    if (auth.token == null) return;

    setState(() {
      _syncingNow = true;
      _errorMessage = null;
    });
    BkoHaptics.light();

    try {
      final res = await BkoApi.post(
        '/creator/podcasts/$_selectedPodcastId/youtube/sync',
        {},
        token: auth.token,
      );
      if (mounted) {
        final msg = res is Map && res['message'] != null
            ? '${res['message']}'
            : 'Synchronisation placée en file d’attente.';
        setState(() => _infoMessage = msg);
        await _fetchChannelStatus(_selectedPodcastId!);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e is ApiException
              ? e.message
              : 'Erreur lors du lancement de la synchronisation.';
        });
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
    final nextSync = !currentSync;
    setState(() => _errorMessage = null);

    try {
      await BkoApi.patch(
        '/creator/podcasts/$_selectedPodcastId/youtube/settings',
        {'syncEnabled': nextSync},
        token: auth.token,
      );
      BkoHaptics.light();
      if (mounted) {
        setState(() {
          _infoMessage = nextSync
              ? 'Synchronisation automatique reprise.'
              : 'Synchronisation automatique suspendue.';
        });
      }
      await _fetchChannelStatus(_selectedPodcastId!);
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e is ApiException
              ? e.message
              : 'Erreur de modification des réglages.';
        });
      }
    }
  }

  Future<void> _disconnectChannel() async {
    final bgSurface = BkoTheme.getBgSurface(context);
    final textPri = BkoTheme.getTextPrimary(context);
    final textSec = BkoTheme.getTextSecondary(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: bgSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Déconnecter la chaîne YouTube ?',
          style: TextStyle(color: textPri, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Vos épisodes déjà importés resteront sur Bamako Podcast. Seule la synchronisation automatique sera arrêtée.',
          style: TextStyle(color: textSec, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Annuler', style: TextStyle(color: textSec)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: BkoTheme.errorColor,
              foregroundColor: Colors.white,
              elevation: 0,
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
      final res = await BkoApi.delete(
        '/creator/podcasts/$_selectedPodcastId/youtube',
        token: auth.token,
      );
      if (mounted) {
        final msg = res is Map && res['message'] != null
            ? '${res['message']}'
            : 'Chaîne YouTube déconnectée.';
        setState(() {
          _channelStatus = null;
          _infoMessage = msg;
        });
        BkoHaptics.light();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage =
              e is ApiException ? e.message : 'Erreur lors de la déconnexion.';
        });
      }
    }
  }

  String _formatSyncStatusLabel(String rawStatus, bool isSyncEnabled) {
    if (!isSyncEnabled && rawStatus == 'PAUSED') return 'Suspendue';
    switch (rawStatus.toUpperCase()) {
      case 'PENDING':
      case 'QUEUED':
        return 'En attente';
      case 'SYNCING':
      case 'RUNNING':
        return 'En cours';
      case 'PAUSED':
        return 'Suspendue';
      case 'ERROR':
      case 'FAILED':
        return 'Échec';
      case 'PARTIAL':
        return 'Partiel';
      case 'IDLE':
      case 'SUCCESS':
      default:
        return isSyncEnabled ? 'Active' : 'Suspendue';
    }
  }

  Color _getSyncStatusColor(String rawStatus, bool isSyncEnabled) {
    final upper = rawStatus.toUpperCase();
    if (upper == 'ERROR' || upper == 'FAILED') return BkoTheme.errorColor;
    if (upper == 'PENDING' ||
        upper == 'QUEUED' ||
        upper == 'SYNCING' ||
        upper == 'RUNNING' ||
        upper == 'PARTIAL') {
      return BkoTheme.goldAccent;
    }
    if (!isSyncEnabled || upper == 'PAUSED') return Colors.grey;
    return BkoTheme.successColor;
  }

  String _formatRunStatusLabel(String rawStatus) {
    switch (rawStatus.toUpperCase()) {
      case 'RUNNING':
      case 'PENDING':
        return 'En cours';
      case 'SUCCESS':
      case 'COMPLETED':
        return 'Terminé';
      case 'PARTIAL':
        return 'Partiel';
      case 'FAILED':
      case 'ERROR':
        return 'Échoué';
      default:
        return rawStatus;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgObsidian = BkoTheme.getBgObsidian(context);
    final bgSurface = BkoTheme.getBgSurface(context);
    final textPri = BkoTheme.getTextPrimary(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: bgObsidian,
      appBar: AppBar(
        backgroundColor: bgSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: AppBackButton(
          fallbackLocation: '/studio',
          onPressed: _step > 1
              ? () => setState(() {
                    _step = _step - 1;
                    if (_step == 1) _archivesMode = false;
                  })
              : null,
        ),
        title: Text(
          _step == 1
              ? 'Chaîne YouTube'
              : _step == 2
                  ? (_archivesMode
                      ? 'Archives de la chaîne'
                      : 'Sélection des vidéos')
                  : 'Paramètres d’import',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: textPri,
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
        color: BkoTheme.successColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: BkoTheme.successColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(IconsaxPlusLinear.tick_circle,
              color: BkoTheme.successColor, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: BkoTheme.successColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _infoMessage = null),
            child: const Icon(IconsaxPlusLinear.close_circle,
                color: BkoTheme.successColor, size: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: BkoTheme.errorColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: BkoTheme.errorColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(IconsaxPlusLinear.info_circle,
              color: BkoTheme.errorColor, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: BkoTheme.errorColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _errorMessage = null),
            child: const Icon(IconsaxPlusLinear.close_circle,
                color: BkoTheme.errorColor, size: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectedChannelView(bool isDark) {
    final bgSurface = BkoTheme.getBgSurface(context);
    final bgObsidian = BkoTheme.getBgObsidian(context);
    final borderSub = BkoTheme.getBorderSubtle(context);
    final textPri = BkoTheme.getTextPrimary(context);
    final textSec = BkoTheme.getTextSecondary(context);

    final title = _channelStatus?['channelTitle'] ?? 'Chaîne connectée';
    final customUrl = '${_channelStatus?['customUrl'] ?? ''}';
    final thumb = _channelStatus?['thumbnailUrl'];
    final syncStatus = '${_channelStatus?['syncStatus'] ?? 'IDLE'}';
    final isSyncEnabled = _channelStatus?['syncEnabled'] == true;
    final counts = _channelStatus?['counts'] is Map
        ? _channelStatus!['counts'] as Map
        : null;
    final videosCount = counts?['imported'] ??
        _channelStatus?['_count']?['importedVideos'] ??
        0;
    final syncRuns = (_channelStatus?['syncRuns'] as List?) ?? const [];
    final latestRun = syncRuns.isNotEmpty && syncRuns.first is Map
        ? Map<String, dynamic>.from(syncRuns.first as Map)
        : null;
    final effectiveStatus =
        (latestRun != null && '${latestRun['status']}' == 'RUNNING')
            ? 'SYNCING'
            : syncStatus;
    final statusColor = _getSyncStatusColor(effectiveStatus, isSyncEnabled);
    final statusLabel = _formatSyncStatusLabel(effectiveStatus, isSyncEnabled);
    final isRunning = effectiveStatus == 'PENDING' ||
        effectiveStatus == 'SYNCING' ||
        effectiveStatus == 'RUNNING';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: bgSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderSub),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (thumb != null && thumb.toString().isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.network(
                    '$thumb',
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
                    color: BkoTheme.errorColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(IconsaxPlusLinear.video,
                      color: BkoTheme.errorColor, size: 28),
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
                            '$title',
                            style: TextStyle(
                              color: textPri,
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
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isRunning) ...[
                                SizedBox(
                                  width: 10,
                                  height: 10,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.8,
                                    color: statusColor,
                                  ),
                                ),
                                const SizedBox(width: 5),
                              ],
                              Text(
                                statusLabel,
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (customUrl.isNotEmpty)
                      Text(
                        customUrl,
                        style: TextStyle(
                          color: textSec,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (_channelStatus?['errorMessage'] != null &&
              '${_channelStatus!['errorMessage']}'.trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            _buildErrorBanner('${_channelStatus!['errorMessage']}'),
          ],
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bgObsidian,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderSub),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatColumn('Importées', '$videosCount', textPri, textSec),
                _buildStatColumn(
                  'Mode',
                  _autoPublish ? 'Direct' : 'Brouillon',
                  textPri,
                  textSec,
                ),
                _buildStatColumn(
                  'Suivi',
                  _channelStatus?['webSubStatus'] == 'ACTIVE'
                      ? 'WebSub'
                      : 'Périodique',
                  textPri,
                  textSec,
                ),
              ],
            ),
          ),
          if (syncRuns.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Historique des synchronisations',
              style: TextStyle(
                color: textPri,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ...syncRuns.take(3).map((rawRun) {
              final run = rawRun is Map
                  ? Map<String, dynamic>.from(rawRun)
                  : <String, dynamic>{};
              final rStatus = '${run['status'] ?? ''}';
              final rColor = _getSyncStatusColor(rStatus, true);
              final imported = run['videosImported'] ?? 0;
              final skipped = run['videosSkipped'] ?? 0;
              final failed = run['videosFailed'] ?? 0;
              final err = run['errorMessage']?.toString();
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: bgObsidian,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderSub),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatRunStatusLabel(rStatus),
                          style: TextStyle(
                            color: rColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '$imported importée(s) · $skipped ignorée(s) · $failed erreur(s)',
                          style: TextStyle(color: textSec, fontSize: 11),
                        ),
                      ],
                    ),
                    if (err != null && err.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        err,
                        style: const TextStyle(
                          color: BkoTheme.errorColor,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }),
          ],
          const SizedBox(height: 14),
          BkoBounceable(
            onTap: _loadingMore ? null : () => _loadMoreVideos(archives: true),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
              decoration: BoxDecoration(
                color: bgObsidian,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderSub),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_loadingMore)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: BkoTheme.goldAccent,
                      ),
                    )
                  else
                    const Icon(
                      IconsaxPlusLinear.archive_book,
                      color: BkoTheme.goldAccent,
                      size: 16,
                    ),
                  const SizedBox(width: 8),
                  Text(
                    _loadingMore
                        ? 'Chargement des archives...'
                        : 'Parcourir et importer les anciennes vidéos',
                    style: TextStyle(
                      color: textPri,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
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
                        if (_syncingNow)
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        else
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
                    color: bgObsidian,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderSub),
                  ),
                  child: Icon(
                    isSyncEnabled
                        ? IconsaxPlusLinear.pause
                        : IconsaxPlusLinear.play,
                    color: textPri,
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
                    color: BkoTheme.errorColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    IconsaxPlusLinear.trash,
                    color: BkoTheme.errorColor,
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

  Widget _buildStatColumn(
      String label, String value, Color textPri, Color textSec) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: textPri,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: textSec,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildInputStep(bool isDark) {
    final bgSurface = BkoTheme.getBgSurface(context);
    final bgObsidian = BkoTheme.getBgObsidian(context);
    final borderSub = BkoTheme.getBorderSubtle(context);
    final textPri = BkoTheme.getTextPrimary(context);
    final textSec = BkoTheme.getTextSecondary(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: bgSurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderSub),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Émission d’accueil',
                style: TextStyle(
                  color: textPri,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Choisissez l’émission qui recevra les épisodes vidéo de YouTube.',
                style: TextStyle(
                  color: textSec,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 12),
              if (_podcasts.isEmpty)
                const Text(
                  'Aucune émission disponible. Créez d’abord une émission dans le Studio.',
                  style: TextStyle(
                    color: BkoTheme.errorColor,
                    fontSize: 12,
                  ),
                )
              else
                DropdownButtonFormField<String>(
                  initialValue: _selectedPodcastId,
                  dropdownColor: bgSurface,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    filled: true,
                    fillColor: bgObsidian,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: borderSub),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: borderSub),
                    ),
                  ),
                  items: _podcasts.map<DropdownMenuItem<String>>((p) {
                    return DropdownMenuItem<String>(
                      value: '${p['id']}',
                      child: Text(
                        '${p['name']}',
                        style: TextStyle(
                          color: textPri,
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
                      _errorMessage = null;
                      _infoMessage = null;
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
            color: bgSurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderSub),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Lien ou identifiant de la chaîne YouTube',
                style: TextStyle(
                  color: textPri,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Connectez une chaîne entière (https://youtube.com/@MaChaine, @MaChaine ou UC...). Les vidéos sont lues via le lecteur officiel intégré YouTube.',
                style: TextStyle(
                  color: textSec,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _urlController,
                style: TextStyle(
                  color: textPri,
                  fontSize: 13,
                ),
                decoration: InputDecoration(
                  hintText: 'https://www.youtube.com/@MaChaine',
                  hintStyle: TextStyle(
                    color: textSec.withValues(alpha: 0.6),
                    fontSize: 13,
                  ),
                  filled: true,
                  fillColor: bgObsidian,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: borderSub),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: borderSub),
                  ),
                  prefixIcon: const Icon(
                    IconsaxPlusLinear.video,
                    color: BkoTheme.errorColor,
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

  String _formatVideoDuration(Map item) {
    final label = item['durationLabel']?.toString().trim();
    if (label != null && label.isNotEmpty) return label;
    final sec = item['durationSeconds'] ?? item['duration'];
    if (sec is num && sec > 0) {
      final mins = (sec / 60).floor();
      final rem = (sec % 60).round();
      if (mins > 0) {
        return '$mins min ${rem > 0 ? '${rem}s' : ''}'.trim();
      }
      return '${sec.round()}s';
    }
    return 'Durée non renseignée';
  }

  Widget _buildPreviewStep(bool isDark) {
    final bgSurface = BkoTheme.getBgSurface(context);
    final borderSub = BkoTheme.getBorderSubtle(context);
    final textPri = BkoTheme.getTextPrimary(context);
    final textSec = BkoTheme.getTextSecondary(context);

    final channel = _previewData?['channel'] as Map? ?? {};
    final title =
        channel['title'] ?? _channelStatus?['channelTitle'] ?? 'Chaîne YouTube';
    final thumb = channel['thumbnailUrl'] ?? _channelStatus?['thumbnailUrl'];
    final allItems = (_previewData?['items'] as List? ?? []);
    final items = allItems
        .where((item) => item is Map && _matchesDiscovery(item))
        .toList();
    final note = _previewData?['note']?.toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          initialValue: _discoveryMode,
          isExpanded: true,
          decoration:
              const InputDecoration(labelText: 'Publications recherchées'),
          items: const [
            DropdownMenuItem(
                value: 'STANDARD', child: Text('Vidéos hors Shorts présumés')),
            DropdownMenuItem(value: 'SHORTS', child: Text('Shorts présumés')),
            DropdownMenuItem(
                value: 'ALL', child: Text('Toutes les publications')),
          ],
          onChanged: _loadingMore
              ? null
              : (value) {
                  if (value == null) return;
                  setState(() {
                    _discoveryMode = value;
                    _selectedVideoIds.removeWhere((id) => !allItems.any(
                        (item) =>
                            item is Map &&
                            _extractVideoIdFromItem(item) == id &&
                            _matchesDiscovery(item)));
                  });
                },
        ),
        const SizedBox(height: 12),
        Text(
            '${allItems.length} parcourues · ${items.length} correspondantes · ${allItems.length - items.length} hors filtre · ${items.where((i) => i['embeddable'] != false && i['isAlreadyImported'] != true).length} admissibles · ${_selectedVideoIds.length} sélectionnées',
            style: TextStyle(color: textSec, fontSize: 12)),
        const SizedBox(height: 8),
        Text(
            'Shorts identifiés à titre indicatif. Chaque chargement parcourt au maximum 5 pages pour trouver 20 vidéos correspondantes.',
            style: TextStyle(color: textSec, fontSize: 12)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: bgSurface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderSub),
          ),
          child: Row(
            children: [
              if (thumb != null && '$thumb'.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    '$thumb',
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                      IconsaxPlusLinear.video,
                      color: BkoTheme.goldAccent,
                    ),
                  ),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$title',
                      style: TextStyle(
                        color: textPri,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      _futureOnly
                          ? 'Suivi des futures publications uniquement'
                          : '${items.length} vidéo(s) • ${_selectedVideoIds.length} sélectionnée(s)',
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
        if (_podcasts.isNotEmpty) ...[
          Text(
            'DESTINATION DE L’ÉMISSION',
            style: TextStyle(
              color: textSec,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: BkoBounceable(
                  onTap: () => setState(() => _targetMode = 'new'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _targetMode == 'new'
                          ? BkoTheme.goldAccent.withValues(alpha: 0.15)
                          : bgSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _targetMode == 'new'
                            ? BkoTheme.goldAccent
                            : borderSub,
                      ),
                    ),
                    child: Text(
                      'Créer une émission',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: _targetMode == 'new'
                            ? BkoTheme.goldAccent
                            : textPri,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: BkoBounceable(
                  onTap: () => setState(() => _targetMode = 'existing'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _targetMode == 'existing'
                          ? BkoTheme.goldAccent.withValues(alpha: 0.15)
                          : bgSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _targetMode == 'existing'
                            ? BkoTheme.goldAccent
                            : borderSub,
                      ),
                    ),
                    child: Text(
                      'Associer existante',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: _targetMode == 'existing'
                            ? BkoTheme.goldAccent
                            : textPri,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
        ],
        if (_targetMode == 'new' || _podcasts.isEmpty) ...[
          Text(
            'TITRE DE L’ÉMISSION',
            style: TextStyle(
              color: textSec,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _podcastNameController,
            style: TextStyle(fontSize: 13.5, color: textPri),
            decoration: InputDecoration(
              filled: true,
              fillColor: bgSurface,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: borderSub),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: BkoTheme.goldAccent),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'DESCRIPTION',
            style: TextStyle(
              color: textSec,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _podcastDescController,
            maxLines: 2,
            style: TextStyle(fontSize: 13, color: textPri),
            decoration: InputDecoration(
              filled: true,
              fillColor: bgSurface,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: borderSub),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: BkoTheme.goldAccent),
              ),
            ),
          ),
          const SizedBox(height: 14),
        ] else ...[
          Text(
            'ÉMISSION DE DESTINATION',
            style: TextStyle(
              color: textSec,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: _selectedPodcastId,
            dropdownColor: bgSurface,
            style: TextStyle(fontSize: 13.5, color: textPri),
            decoration: InputDecoration(
              filled: true,
              fillColor: bgSurface,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: borderSub),
              ),
            ),
            items: _podcasts.map<DropdownMenuItem<String>>((p) {
              return DropdownMenuItem<String>(
                value: '${p['id']}',
                child: Text(p['name'] ?? 'Émission',
                    overflow: TextOverflow.ellipsis),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _selectedPodcastId = val);
            },
          ),
          const SizedBox(height: 14),
        ],
        const SizedBox(height: 12),
        if (!_archivesMode)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: bgSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderSub),
            ),
            child: Material(
              color: Colors.transparent,
              child: SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                activeTrackColor: BkoTheme.goldAccent,
                value: _futureOnly,
                onChanged: (v) => setState(() {
                  _futureOnly = v;
                  if (v) _selectedVideoIds.clear();
                }),
                title: Text(
                  'Suivre uniquement les prochaines publications',
                  style: TextStyle(
                    color: textPri,
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  'Aucune ancienne vidéo ne sera importée maintenant.',
                  style: TextStyle(color: textSec, fontSize: 11),
                ),
              ),
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: _futureOnly
                  ? null
                  : () {
                      setState(() {
                        for (final raw in items) {
                          if (raw is Map) {
                            final id = _extractVideoIdFromItem(raw);
                            if (id.isNotEmpty &&
                                raw['isAlreadyImported'] != true &&
                                raw['embeddable'] != false &&
                                _matchesDiscovery(raw)) {
                              _selectedVideoIds.add(id);
                            }
                          }
                        }
                      });
                      BkoHaptics.light();
                    },
              child: const Text(
                'Tout sélectionner (éligibles)',
                style: TextStyle(
                  color: BkoTheme.goldAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                setState(() => _selectedVideoIds.clear());
                BkoHaptics.light();
              },
              child: Text(
                'Tout désélectionner',
                style: TextStyle(color: textSec, fontSize: 12),
              ),
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
            final videoId = _extractVideoIdFromItem(item);
            final videoTitle = '${item['title'] ?? ''}';
            final vThumb = item['thumbnailUrl'];
            final isImported = item['isAlreadyImported'] == true;
            final isEmbedBlocked = item['embeddable'] == false;
            final isShort = item['isLikelyShort'] == true;
            final canSelect = !isImported && !isEmbedBlocked && !_futureOnly;
            final isSelected = _selectedVideoIds.contains(videoId);

            return BkoBounceable(
              onTap: !canSelect
                  ? null
                  : () {
                      setState(() {
                        if (isSelected) {
                          _selectedVideoIds.remove(videoId);
                        } else if (videoId.isNotEmpty) {
                          _selectedVideoIds.add(videoId);
                        }
                      });
                      BkoHaptics.light();
                    },
              child: Opacity(
                opacity: canSelect ? 1.0 : 0.55,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? BkoTheme.goldAccent.withValues(alpha: 0.08)
                        : bgSurface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? BkoTheme.goldAccent.withValues(alpha: 0.45)
                          : borderSub,
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
                            : textSec.withValues(alpha: 0.4),
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      if (vThumb != null && '$vThumb'.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            '$vThumb',
                            width: 56,
                            height: 36,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 56,
                              height: 36,
                              color: borderSub,
                            ),
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
                                color: textPri,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  _formatVideoDuration(item),
                                  style: TextStyle(
                                    color: textSec,
                                    fontSize: 10,
                                  ),
                                ),
                                if (isImported)
                                  _buildBadge('Déjà importé', Colors.grey),
                                if (isShort)
                                  _buildBadge('Short', BkoTheme.goldAccent),
                                if (isEmbedBlocked)
                                  _buildBadge('Intégration désactivée',
                                      BkoTheme.errorColor),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 14),
        if (note != null && note.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              note,
              style: TextStyle(color: textSec, fontSize: 11.5),
            ),
          ),
        if (_previewData?['nextPageToken'] != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: BkoBounceable(
              onTap:
                  _loadingMore ? null : () => _loadMoreVideos(archives: false),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: bgSurface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderSub),
                ),
                alignment: Alignment.center,
                child: Text(
                  _loadingMore
                      ? 'Chargement des vidéos suivantes...'
                      : 'Charger les vidéos suivantes / anciennes',
                  style: TextStyle(
                    color: textPri,
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        BkoBounceable(
          onTap: (_selectedVideoIds.isEmpty && !_futureOnly)
              ? null
              : () {
                  setState(() {
                    _errorMessage = null;
                    _step = 3;
                  });
                  BkoHaptics.light();
                },
          child: Opacity(
            opacity: (_selectedVideoIds.isEmpty && !_futureOnly) ? 0.5 : 1.0,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: BkoTheme.goldAccent,
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Text(
                _futureOnly
                    ? 'Continuer (futures vidéos uniquement)'
                    : 'Continuer (${_selectedVideoIds.length} sélectionnée(s))',
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildSettingsStep(bool isDark) {
    final bgSurface = BkoTheme.getBgSurface(context);
    final bgObsidian = BkoTheme.getBgObsidian(context);
    final borderSub = BkoTheme.getBorderSubtle(context);
    final textPri = BkoTheme.getTextPrimary(context);
    final textSec = BkoTheme.getTextSecondary(context);

    if (_archivesMode) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: bgSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderSub),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Importer ${_selectedVideoIds.length} vidéo(s) d’archives',
              style: TextStyle(
                color: textPri,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Les réglages actuels de votre chaîne seront conservés. Les vidéos déjà présentes dans votre émission ne seront pas dupliquées.',
              style: TextStyle(color: textSec, fontSize: 12.5),
            ),
            const SizedBox(height: 20),
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
                    else
                      const Icon(IconsaxPlusBold.tick_circle,
                          color: Colors.black, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      _connecting
                          ? 'Mise en file d’attente...'
                          : 'Confirmer l’import des archives',
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
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: bgSurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderSub),
          ),
          child: Material(
            color: Colors.transparent,
            child: Column(
              children: [
                SwitchListTile.adaptive(
                  value: _autoSync,
                  activeTrackColor: BkoTheme.goldAccent,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Synchroniser les futures vidéos',
                    style: TextStyle(
                      color: textPri,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    'Vérifie périodiquement la chaîne et importe automatiquement les nouveaux épisodes.',
                    style: TextStyle(color: textSec, fontSize: 11),
                  ),
                  onChanged: (val) => setState(() => _autoSync = val),
                ),
                Divider(height: 24, color: borderSub),
                SwitchListTile.adaptive(
                  value: _autoPublish,
                  activeTrackColor: BkoTheme.goldAccent,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Publier directement',
                    style: TextStyle(
                      color: textPri,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    'Si désactivé, les vidéos seront créées à l’état de brouillon pour validation avant publication.',
                    style: TextStyle(color: textSec, fontSize: 11),
                  ),
                  onChanged: (val) => setState(() => _autoPublish = val),
                ),
                Divider(height: 24, color: borderSub),
                SwitchListTile.adaptive(
                  value: _keepManualEdits,
                  activeTrackColor: BkoTheme.goldAccent,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Protéger mes éditions locales',
                    style: TextStyle(
                      color: textPri,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    'Empêche la synchronisation d’écraser vos titres ou descriptions personnalisés.',
                    style: TextStyle(color: textSec, fontSize: 11),
                  ),
                  onChanged: (val) => setState(() => _keepManualEdits = val),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: bgSurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderSub),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Filtres par mots-clés (optionnel)',
                style: TextStyle(
                  color: textPri,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _includeKeywordsController,
                style: TextStyle(color: textPri, fontSize: 12.5),
                decoration: InputDecoration(
                  labelText: 'Mots-clés requis (séparés par une virgule)',
                  labelStyle: TextStyle(color: textSec, fontSize: 12),
                  filled: true,
                  fillColor: bgObsidian,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: borderSub),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: borderSub),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _excludeKeywordsController,
                style: TextStyle(color: textPri, fontSize: 12.5),
                decoration: InputDecoration(
                  labelText: 'Mots-clés exclus (séparés par une virgule)',
                  labelStyle: TextStyle(color: textSec, fontSize: 12),
                  filled: true,
                  fillColor: bgObsidian,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: borderSub),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: borderSub),
                  ),
                ),
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
