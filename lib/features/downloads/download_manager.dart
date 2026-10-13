import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/network/bko_api.dart';
import '../shell/shell_providers.dart';

enum DownloadStatus {
  pending,
  downloading,
  completed,
  error,
  unsupported,
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
  final Map<String, CancelToken> _cancelTokens = {};
  final Dio _dio = Dio();

  DownloadNotifier() : super([]) {
    _loadPersistedTasks();
  }

  Future<void> _loadPersistedTasks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null) return;
      final List<dynamic> list = jsonDecode(raw);
      final tasks = list.map((item) => DownloadTask.fromJson(item)).toList();

      // Verify physical existence of files for completed tasks
      final verifiedTasks = <DownloadTask>[];
      for (final t in tasks) {
        if (t.status == DownloadStatus.completed && t.localPath != null) {
          final file = File(t.localPath!);
          if (await file.exists()) {
            final size = await file.length();
            verifiedTasks.add(t.copyWith(fileSize: size));
          } else {
            // File was deleted outside the app
            verifiedTasks.add(t.copyWith(
              status: DownloadStatus.error,
              errorMessage: 'Fichier local introuvable',
            ));
          }
        } else if (t.status == DownloadStatus.downloading) {
          // If app closed during download, mark as interrupted
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

  /// Check if an episode is downloadable and start download
  Future<void> startDownload(Map<String, dynamic> episode) async {
    final episodeId = '${episode['id'] ?? ''}';
    if (episodeId.isEmpty) return;

    // Direct audio URL check
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

    // Check existing
    final existingIndex = state.indexWhere((t) => t.episodeId == episodeId);
    if (existingIndex >= 0 && state[existingIndex].status == DownloadStatus.completed) {
      return; // Already downloaded
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

      // Safe clean filename
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
      if (CancelToken.isCancel(e)) {
        // Canceled intentionally
        return;
      }
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
          audioUrl: task.localPath, // Local file path for just_audio!
          videoUrl: null,
          hasAudio: true,
          hasVideo: false,
          episodeId: task.episodeId,
          podcastSlug: task.podcastSlug,
          episodeSlug: task.episodeSlug,
        );
  }
}

final downloadProvider = StateNotifierProvider<DownloadNotifier, List<DownloadTask>>((ref) {
  return DownloadNotifier();
});
