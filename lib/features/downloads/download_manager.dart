import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/network/bko_api.dart';
import '../auth/auth_controller.dart';
import '../shell/shell_providers.dart';

/// Exception levée lorsqu'un utilisateur non connecté tente de télécharger plus d'un épisode.
class DownloadLimitException implements Exception {
  final String message;
  const DownloadLimitException(this.message);

  @override
  String toString() => message;
}

enum DownloadStatus {
  pending,
  downloading,
  completed,
  error,
  unsupported,
}

/// Paramètres de téléchargements intelligents (style Netflix & Apple Podcasts)
class SmartDownloadSettings {
  final bool smartDownloadsEnabled;
  final bool autoDeleteCompleted;
  final bool autoDownloadNext;
  final bool wifiOnly;

  const SmartDownloadSettings({
    this.smartDownloadsEnabled = true,
    this.autoDeleteCompleted = true,
    this.autoDownloadNext = true,
    this.wifiOnly = false,
  });

  SmartDownloadSettings copyWith({
    bool? smartDownloadsEnabled,
    bool? autoDeleteCompleted,
    bool? autoDownloadNext,
    bool? wifiOnly,
  }) {
    return SmartDownloadSettings(
      smartDownloadsEnabled: smartDownloadsEnabled ?? this.smartDownloadsEnabled,
      autoDeleteCompleted: autoDeleteCompleted ?? this.autoDeleteCompleted,
      autoDownloadNext: autoDownloadNext ?? this.autoDownloadNext,
      wifiOnly: wifiOnly ?? this.wifiOnly,
    );
  }

  Map<String, dynamic> toJson() => {
        'smartDownloadsEnabled': smartDownloadsEnabled,
        'autoDeleteCompleted': autoDeleteCompleted,
        'autoDownloadNext': autoDownloadNext,
        'wifiOnly': wifiOnly,
      };

  factory SmartDownloadSettings.fromJson(Map<String, dynamic> json) {
    return SmartDownloadSettings(
      smartDownloadsEnabled: json['smartDownloadsEnabled'] as bool? ?? true,
      autoDeleteCompleted: json['autoDeleteCompleted'] as bool? ?? true,
      autoDownloadNext: json['autoDownloadNext'] as bool? ?? true,
      wifiOnly: json['wifiOnly'] as bool? ?? false,
    );
  }
}

class DownloadTask {
  final String episodeId;
  final String podcastSlug;
  final String episodeSlug;
  final String title;
  final String podcastName;
  final String coverUrl;
  final String audioUrl;
  final DownloadStatus status;
  final double progress; // 0.0 to 1.0
  final String? localPath;
  final int? fileSize;
  final String? errorMessage;
  final DateTime createdAt;

  const DownloadTask({
    required this.episodeId,
    required this.podcastSlug,
    required this.episodeSlug,
    required this.title,
    required this.podcastName,
    required this.coverUrl,
    required this.audioUrl,
    required this.status,
    this.progress = 0.0,
    this.localPath,
    this.fileSize,
    this.errorMessage,
    required this.createdAt,
  });

  String get formattedSize {
    if (fileSize == null || fileSize == 0) return '';
    final mb = fileSize! / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} Mo';
  }

  DownloadTask copyWith({
    DownloadStatus? status,
    double? progress,
    String? localPath,
    int? fileSize,
    String? errorMessage,
  }) {
    return DownloadTask(
      episodeId: episodeId,
      podcastSlug: podcastSlug,
      episodeSlug: episodeSlug,
      title: title,
      podcastName: podcastName,
      coverUrl: coverUrl,
      audioUrl: audioUrl,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      localPath: localPath ?? this.localPath,
      fileSize: fileSize ?? this.fileSize,
      errorMessage: errorMessage ?? this.errorMessage,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'episodeId': episodeId,
        'podcastSlug': podcastSlug,
        'episodeSlug': episodeSlug,
        'title': title,
        'podcastName': podcastName,
        'coverUrl': coverUrl,
        'audioUrl': audioUrl,
        'status': status.name,
        'progress': progress,
        'localPath': localPath,
        'fileSize': fileSize,
        'errorMessage': errorMessage,
        'createdAt': createdAt.toIso8601String(),
      };

  factory DownloadTask.fromJson(Map<String, dynamic> json) {
    return DownloadTask(
      episodeId: json['episodeId'] ?? '',
      podcastSlug: json['podcastSlug'] ?? '',
      episodeSlug: json['episodeSlug'] ?? '',
      title: json['title'] ?? '',
      podcastName: json['podcastName'] ?? '',
      coverUrl: json['coverUrl'] ?? '',
      audioUrl: json['audioUrl'] ?? '',
      status: DownloadStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => DownloadStatus.error,
      ),
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
      localPath: json['localPath'],
      fileSize: json['fileSize'] as int?,
      errorMessage: json['errorMessage'],
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt']) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class DownloadNotifier extends StateNotifier<List<DownloadTask>> {
  static const _storageKey = 'bko_download_tasks_v1';
  static const _smartSettingsKey = 'bko_smart_downloads_settings_v1';

  final Ref? _ref;
  final Map<String, CancelToken> _cancelTokens = {};
  final Dio _dio = Dio();
  SmartDownloadSettings _smartSettings = const SmartDownloadSettings();
  bool _isSyncingRemote = false;

  DownloadNotifier([this._ref]) : super([]) {
    _loadPersistedTasks();
    _loadSmartSettings();
  }

  SmartDownloadSettings get smartSettings => _smartSettings;

  int get totalDownloadedBytes => state
      .where((t) => t.status == DownloadStatus.completed)
      .fold(0, (sum, t) => sum + (t.fileSize ?? 0));

  String get formattedTotalStorage {
    final mb = totalDownloadedBytes / (1024 * 1024);
    if (mb >= 1024) {
      final gb = mb / 1024;
      return '${gb.toStringAsFixed(2)} Go';
    }
    return '${mb.toStringAsFixed(1)} Mo';
  }

  Future<void> _loadSmartSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_smartSettingsKey);
      if (raw != null) {
        _smartSettings = SmartDownloadSettings.fromJson(jsonDecode(raw));
      }
    } catch (_) {}
  }

  Future<void> updateSmartSettings({
    bool? smartDownloadsEnabled,
    bool? autoDeleteCompleted,
    bool? autoDownloadNext,
    bool? wifiOnly,
  }) async {
    _smartSettings = _smartSettings.copyWith(
      smartDownloadsEnabled: smartDownloadsEnabled,
      autoDeleteCompleted: autoDeleteCompleted,
      autoDownloadNext: autoDownloadNext,
      wifiOnly: wifiOnly,
    );
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_smartSettingsKey, jsonEncode(_smartSettings.toJson()));
    } catch (_) {}
  }

  Future<void> _loadPersistedTasks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null) return;
      final List<dynamic> list = jsonDecode(raw);
      final tasks = list.map((item) => DownloadTask.fromJson(item)).toList();

      // Vérifier l'existence physique des fichiers pour les tâches terminées
      final verifiedTasks = <DownloadTask>[];
      for (final t in tasks) {
        if (t.status == DownloadStatus.completed && t.localPath != null) {
          final file = File(t.localPath!);
          if (await file.exists()) {
            final size = await file.length();
            verifiedTasks.add(t.copyWith(fileSize: size));
          } else {
            verifiedTasks.add(t.copyWith(
              status: DownloadStatus.error,
              errorMessage: 'Fichier local introuvable',
            ));
          }
        } else if (t.status == DownloadStatus.downloading) {
          verifiedTasks.add(t.copyWith(
            status: DownloadStatus.error,
            errorMessage: 'Téléchargement interrompu',
          ));
        } else {
          verifiedTasks.add(t);
        }
      }

      state = verifiedTasks;
    } catch (_) {}
  }

  Future<void> _savePersistedTasks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = jsonEncode(state.map((t) => t.toJson()).toList());
      await prefs.setString(_storageKey, raw);
    } catch (_) {}
  }

  /// Vérifie la règle de limitation pour les utilisateurs invités (max 1 épisode sans compte)
  void _checkDownloadAllowance() {
    final auth = _ref?.read(authProvider);
    final isAuthenticated = auth?.isAuthenticated ?? false;

    if (!isAuthenticated) {
      final activeCount = state
          .where((t) =>
              t.status == DownloadStatus.completed ||
              t.status == DownloadStatus.downloading)
          .length;

      if (activeCount >= 1) {
        throw const DownloadLimitException(
          'Limite de téléchargement sans compte atteinte : Vous pouvez télécharger 1 épisode maximum sans compte. Créez un compte gratuit pour des téléchargements illimités !',
        );
      }
    }
  }

  /// Démarre le téléchargement d'un épisode
  Future<void> startDownload(Map<String, dynamic> episode, {bool isSmartTrigger = false}) async {
    final episodeId = '${episode['id'] ?? ''}';
    if (episodeId.isEmpty) return;

    // Vérifier la règle de limitation des invités
    _checkDownloadAllowance();

    // Vérification du flux audio direct
    final audioUrl = BkoApi.extractAudioUrl(episode);
    final videoUrl = BkoApi.extractVideoUrl(episode);

    if (audioUrl == null || audioUrl.isEmpty) {
      final bool isYoutube = videoUrl != null &&
          (videoUrl.contains('youtube.com') || videoUrl.contains('youtu.be'));
      final task = DownloadTask(
        episodeId: episodeId,
        podcastSlug: '${episode['podcast']?['slug'] ?? ''}',
        episodeSlug: '${episode['slug'] ?? ''}',
        title: episode['title'] ?? 'Épisode',
        podcastName: episode['podcast']?['name'] ?? '',
        coverUrl: episode['cover'] ?? episode['podcast']?['cover'] ?? '',
        audioUrl: '',
        status: DownloadStatus.unsupported,
        errorMessage: isYoutube
            ? 'Ce contenu est hébergé sur YouTube et ne peut être téléchargé hors ligne.'
            : 'Aucun flux audio direct téléchargeable pour cet épisode.',
        createdAt: DateTime.now(),
      );
      state = [task, ...state.where((t) => t.episodeId != episodeId)];
      await _savePersistedTasks();
      return;
    }

    // Déjà téléchargé
    final existingIndex = state.indexWhere((t) => t.episodeId == episodeId);
    if (existingIndex >= 0 && state[existingIndex].status == DownloadStatus.completed) {
      return;
    }

    final task = DownloadTask(
      episodeId: episodeId,
      podcastSlug: '${episode['podcast']?['slug'] ?? ''}',
      episodeSlug: '${episode['slug'] ?? ''}',
      title: episode['title'] ?? 'Épisode',
      podcastName: episode['podcast']?['name'] ?? '',
      coverUrl: episode['cover'] ?? episode['podcast']?['cover'] ?? '',
      audioUrl: audioUrl,
      status: DownloadStatus.downloading,
      progress: 0.0,
      createdAt: DateTime.now(),
    );

    state = [task, ...state.where((t) => t.episodeId != episodeId)];
    await _savePersistedTasks();

    _executeDownload(task);
  }

  Future<void> _executeDownload(DownloadTask task) async {
    final cancelToken = CancelToken();
    _cancelTokens[task.episodeId] = cancelToken;

    try {
      final dir = await getApplicationDocumentsDirectory();
      final downloadsDir = Directory('${dir.path}/bko_downloads');
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }

      final safeName = task.episodeId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final targetPath = '${downloadsDir.path}/$safeName.mp3';

      await _dio.download(
        task.audioUrl,
        targetPath,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            final progress = (received / total).clamp(0.0, 1.0);
            _updateTask(task.episodeId, (t) => t.copyWith(
                  progress: progress,
                  fileSize: total,
                ));
          }
        },
      );

      final file = File(targetPath);
      final size = await file.length();

      _updateTask(task.episodeId, (t) => t.copyWith(
            status: DownloadStatus.completed,
            progress: 1.0,
            localPath: targetPath,
            fileSize: size,
            errorMessage: null,
          ));
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) return;
      _updateTask(task.episodeId, (t) => t.copyWith(
            status: DownloadStatus.error,
            errorMessage: 'Échec du téléchargement : ${e.message ?? "erreur réseau"}',
          ));
    } catch (e) {
      _updateTask(task.episodeId, (t) => t.copyWith(
            status: DownloadStatus.error,
            errorMessage: 'Erreur inattendue : $e',
          ));
    } finally {
      _cancelTokens.remove(task.episodeId);
      await _savePersistedTasks();
    }
  }

  void _updateTask(String episodeId, DownloadTask Function(DownloadTask) updater) {
    state = state.map((t) {
      if (t.episodeId == episodeId) return updater(t);
      return t;
    }).toList();
  }

  Future<void> cancelDownload(String episodeId) async {
    final token = _cancelTokens[episodeId];
    if (token != null && !token.isCancelled) {
      token.cancel('Annulé par l\'utilisateur');
    }
    _cancelTokens.remove(episodeId);

    final task = state.firstWhere((t) => t.episodeId == episodeId, orElse: () => throw 'Not found');
    if (task.localPath != null) {
      final file = File(task.localPath!);
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {}
      }
    }

    state = state.where((t) => t.episodeId != episodeId).toList();
    await _savePersistedTasks();
  }

  Future<void> retryDownload(String episodeId) async {
    final index = state.indexWhere((t) => t.episodeId == episodeId);
    if (index < 0) return;
    final task = state[index];
    if (task.audioUrl.isEmpty) return;

    final updated = task.copyWith(
      status: DownloadStatus.downloading,
      progress: 0.0,
      errorMessage: null,
    );
    state = [
      for (final t in state)
        if (t.episodeId == episodeId) updated else t
    ];
    await _savePersistedTasks();
    _executeDownload(updated);
  }

  Future<void> deleteDownload(String episodeId) async {
    final index = state.indexWhere((t) => t.episodeId == episodeId);
    if (index < 0) return;
    final task = state[index];

    if (task.localPath != null) {
      final file = File(task.localPath!);
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {}
      }
    }

    state = state.where((t) => t.episodeId != episodeId).toList();
    await _savePersistedTasks();
  }

  Future<void> deleteTask(String episodeId) => deleteDownload(episodeId);

  bool isDownloaded(String episodeId) {
    return state.any((t) => t.episodeId == episodeId && t.status == DownloadStatus.completed);
  }

  bool isDownloading(String episodeId) {
    return state.any((t) => t.episodeId == episodeId && t.status == DownloadStatus.downloading);
  }

  void playDownloadedEpisode(WidgetRef ref, DownloadTask task) {
    if (task.status != DownloadStatus.completed || task.localPath == null) return;
    ref.read(activeEpisodeProvider.notifier).handlePlayOrPause(
          title: task.title,
          showName: task.podcastName,
          duration: task.formattedSize,
          coverUrl: task.coverUrl,
          audioUrl: task.localPath,
          videoUrl: null,
          hasAudio: true,
          hasVideo: false,
          episodeId: task.episodeId,
          podcastSlug: task.podcastSlug,
          episodeSlug: task.episodeSlug,
        );
  }

  /// Synchronisation de la présence de l'appareil mobile et récupération des ordres
  /// de téléchargement émis à distance depuis le web.
  Future<void> syncRemoteQueue() async {
    if (_isSyncingRemote) return;
    final auth = _ref?.read(authProvider);
    final token = auth?.token;
    if (token == null || !auth!.isAuthenticated) return;

    _isSyncingRemote = true;
    try {
      // 1. Signaler l'appareil actif
      final platformName = kIsWeb ? 'Web' : Platform.operatingSystem;
      await BkoApi.post(
        '/downloads/device-sync',
        {
          'deviceType': 'MOBILE',
          'deviceName': 'BKO Mobile ($platformName)',
          'osVersion': platformName,
          'appVersion': '1.0.0',
        },
        token: token,
      ).catchError((_) => null);

      // 2. Récupérer les ordres distants en attente
      final res = await BkoApi.get('/downloads/remote-queue', token: token);
      if (res is List && res.isNotEmpty) {
        for (final item in res) {
          if (item is! Map) continue;
          final queueId = '${item['queueId'] ?? ''}';
          final ep = item['episode'];
          if (queueId.isNotEmpty && ep is Map) {
            try {
              final epMap = Map<String, dynamic>.from(ep);
              final epId = '${epMap['id'] ?? ''}';
              if (epId.isNotEmpty && !isDownloaded(epId) && !isDownloading(epId)) {
                await startDownload(epMap);
              }
              // Acquitter au serveur
              await BkoApi.post(
                '/downloads/remote-queue/$queueId/ack',
                {'status': 'COMPLETED'},
                token: token,
              );
            } catch (err) {
              debugPrint('[DownloadNotifier] Erreur sync ordre distant: $err');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[DownloadNotifier] Erreur sync remote queue: $e');
    } finally {
      _isSyncingRemote = false;
    }
  }

  /// Appelé lorsqu'un épisode se termine (Téléchargements intelligents Netflix & Apple Podcasts)
  Future<void> onEpisodePlaybackCompleted(String episodeId, {String? podcastSlug}) async {
    if (!_smartSettings.smartDownloadsEnabled) return;

    // 1. Suppression automatique après écoute complète (libère l'espace de stockage)
    if (_smartSettings.autoDeleteCompleted && isDownloaded(episodeId)) {
      debugPrint('[SmartDownloads] Suppression auto de l\'épisode écouté: $episodeId');
      await deleteDownload(episodeId);
    }

    // 2. Téléchargement automatique de l'épisode suivant de l'émission
    if (_smartSettings.autoDownloadNext && podcastSlug != null && podcastSlug.isNotEmpty) {
      try {
        final token = _ref?.read(authProvider).token;
        final podcastData = await BkoApi.get('/podcasts/$podcastSlug', token: token);
        if (podcastData is Map) {
          final episodes = (podcastData['episodes'] as List?) ?? [];
          if (episodes.isNotEmpty) {
            final currentIndex = episodes.indexWhere((e) => e is Map && '${e['id']}' == episodeId);
            if (currentIndex >= 0 && currentIndex + 1 < episodes.length) {
              final nextEp = Map<String, dynamic>.from(episodes[currentIndex + 1] as Map);
              final nextEpId = '${nextEp['id'] ?? ''}';
              if (nextEpId.isNotEmpty && !isDownloaded(nextEpId) && !isDownloading(nextEpId)) {
                debugPrint('[SmartDownloads] Téléchargement auto de l\'épisode suivant: $nextEpId');
                await startDownload(nextEp, isSmartTrigger: true);
              }
            }
          }
        }
      } catch (err) {
        debugPrint('[SmartDownloads] Erreur téléchargement épisode suivant: $err');
      }
    }
  }
}

final downloadProvider = StateNotifierProvider<DownloadNotifier, List<DownloadTask>>((ref) {
  final notifier = DownloadNotifier(ref);
  // Déclencher la synchronisation des téléchargements distants au démarrage
  Future.microtask(() => notifier.syncRemoteQueue());
  return notifier;
});

class DownloadLimitDialog {
  static void show(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF18181C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.offline_bolt_rounded, color: Color(0xFFFFBF00), size: 24),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Limite hors-ligne',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
              ),
            ),
          ],
        ),
        content: const Text(
          'Les auditeurs sans compte peuvent télécharger 1 épisode maximum pour tester. Créez un compte gratuit pour profiter de téléchargements illimités et écouter partout hors-ligne !',
          style: TextStyle(fontSize: 13.5, color: Colors.white70, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Plus tard', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ctx.push('/login');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFBF00),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Créer un compte', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black)),
          ),
        ],
      ),
    );
  }
}
