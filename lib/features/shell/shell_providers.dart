import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../player/bko_audio_handler.dart';
import '../../core/network/bko_telemetry.dart';

class QueueItem {
  final String episodeId;
  final String title;
  final String showName;
  final String duration;
  final String coverUrl;
  final String? audioUrl;
  final String? videoUrl;
  final bool hasAudio;
  final bool hasVideo;
  final String podcastSlug;
  final String episodeSlug;

  const QueueItem({
    required this.episodeId,
    required this.title,
    required this.showName,
    required this.duration,
    required this.coverUrl,
    this.audioUrl,
    this.videoUrl,
    this.hasAudio = false,
    this.hasVideo = false,
    this.podcastSlug = '',
    this.episodeSlug = '',
  });

  Map<String, dynamic> toMap() => {
        'id': episodeId,
        'title': title,
        'showName': showName,
        'duration': duration,
        'cover': coverUrl,
        'audioUrl': audioUrl,
        'videoUrl': videoUrl,
        'podcast': {'name': showName, 'slug': podcastSlug},
        'podcastSlug': podcastSlug,
        'slug': episodeSlug,
      };
}

enum PlaybackStatus {
  idle,
  loading,
  playing,
  paused,
  completed,
  error,
}

// State for Active Playback Episode
class ActiveEpisodeState {
  final bool hasActiveEpisode;
  final bool isPlaying;
  final PlaybackStatus playbackStatus;
  final String title;
  final String showName;
  final String duration;
  final String coverUrl;
  final String audioUrl;
  final String videoUrl;
  final String mode; // 'AUDIO' | 'VIDEO'
  final bool hasAudio;
  final bool hasVideo;
  final double progress;
  final Duration currentPosition;
  final Duration totalDuration;
  final String episodeId;
  final String podcastSlug;
  final String episodeSlug;
  final double playbackSpeed;
  final DateTime? sleepTimerEndsAt;
  final List<QueueItem> queue;
  final String? errorMessage;

  bool get isLoading => isBuffering;
  bool get isBuffering => playbackStatus == PlaybackStatus.loading;
  bool get isPlaybackActive => playbackStatus == PlaybackStatus.playing;

  const ActiveEpisodeState({
    this.hasActiveEpisode = false,
    this.isPlaying = false,
    this.playbackStatus = PlaybackStatus.idle,
    this.title = '',
    this.showName = '',
    this.duration = '',
    this.coverUrl = '',
    this.audioUrl = '',
    this.videoUrl = '',
    this.mode = 'AUDIO',
    this.hasAudio = false,
    this.hasVideo = false,
    this.progress = 0.0,
    this.currentPosition = Duration.zero,
    this.totalDuration = Duration.zero,
    this.episodeId = '',
    this.podcastSlug = '',
    this.episodeSlug = '',
    this.playbackSpeed = 1.0,
    this.sleepTimerEndsAt,
    this.queue = const [],
    this.errorMessage,
  });

  ActiveEpisodeState copyWith({
    bool? hasActiveEpisode,
    bool? isPlaying,
    PlaybackStatus? playbackStatus,
    String? title,
    String? showName,
    String? duration,
    String? coverUrl,
    String? audioUrl,
    String? videoUrl,
    String? mode,
    bool? hasAudio,
    bool? hasVideo,
    double? progress,
    Duration? currentPosition,
    Duration? totalDuration,
    String? episodeId,
    String? podcastSlug,
    String? episodeSlug,
    double? playbackSpeed,
    DateTime? sleepTimerEndsAt,
    bool clearSleepTimer = false,
    List<QueueItem>? queue,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ActiveEpisodeState(
      hasActiveEpisode: hasActiveEpisode ?? this.hasActiveEpisode,
      isPlaying: isPlaying ?? this.isPlaying,
      playbackStatus: playbackStatus ?? this.playbackStatus,
      title: title ?? this.title,
      showName: showName ?? this.showName,
      duration: duration ?? this.duration,
      coverUrl: coverUrl ?? this.coverUrl,
      audioUrl: audioUrl ?? this.audioUrl,
      videoUrl: videoUrl ?? this.videoUrl,
      mode: mode ?? this.mode,
      hasAudio: hasAudio ?? this.hasAudio,
      hasVideo: hasVideo ?? this.hasVideo,
      progress: progress ?? this.progress,
      currentPosition: currentPosition ?? this.currentPosition,
      totalDuration: totalDuration ?? this.totalDuration,
      episodeId: episodeId ?? this.episodeId,
      podcastSlug: podcastSlug ?? this.podcastSlug,
      episodeSlug: episodeSlug ?? this.episodeSlug,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      sleepTimerEndsAt: clearSleepTimer
          ? null
          : (sleepTimerEndsAt ?? this.sleepTimerEndsAt),
      queue: queue ?? this.queue,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ActiveEpisodeState &&
        other.hasActiveEpisode == hasActiveEpisode &&
        other.isPlaying == isPlaying &&
        other.playbackStatus == playbackStatus &&
        other.title == title &&
        other.showName == showName &&
        other.duration == duration &&
        other.coverUrl == coverUrl &&
        other.audioUrl == audioUrl &&
        other.videoUrl == videoUrl &&
        other.mode == mode &&
        other.hasAudio == hasAudio &&
        other.hasVideo == hasVideo &&
        other.progress == progress &&
        other.currentPosition == currentPosition &&
        other.totalDuration == totalDuration &&
        other.episodeId == episodeId &&
        other.podcastSlug == podcastSlug &&
        other.episodeSlug == episodeSlug &&
        other.playbackSpeed == playbackSpeed &&
        other.sleepTimerEndsAt == sleepTimerEndsAt &&
        other.errorMessage == errorMessage;
  }

  @override
  int get hashCode => Object.hash(
        hasActiveEpisode,
        isPlaying,
        playbackStatus,
        episodeId,
        currentPosition,
        totalDuration,
        mode,
      );
}

final audioHandlerProvider = Provider<BkoAudioHandler>((ref) {
  throw StateError(
      'BkoAudioHandler must be provided during application startup.');
});

class ActiveEpisodeNotifier extends StateNotifier<ActiveEpisodeState> {
  final BkoAudioHandler _audioHandler;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  Timer? _sleepTimer;
  Timer? _heartbeatTimer;
  String? _telemetrySessionId;
  int _lastProgressSec = 0;
  DateTime? _lastTickTime;

  ActiveEpisodeNotifier(this._audioHandler)
      : super(const ActiveEpisodeState()) {
    _subscriptions.add(_audioHandler.positionStream.listen(_onPosition, onError: (_) {}));
    _subscriptions.add(_audioHandler.durationStream.listen(_onDuration, onError: (_) {}));
    _subscriptions.add(_audioHandler.playerStateStream.listen(
      (playerState) {
        if (!mounted) return;
        if (state.mode == 'AUDIO' && state.hasActiveEpisode) {
          PlaybackStatus newStatus;
          if (playerState.processingState == ProcessingState.loading ||
              playerState.processingState == ProcessingState.buffering) {
            newStatus = PlaybackStatus.loading;
          } else if (playerState.processingState == ProcessingState.completed) {
            newStatus = PlaybackStatus.completed;
            if (_telemetrySessionId != null && state.episodeId.isNotEmpty) {
              BkoTelemetryService().trackListeningEvent(
                sessionId: _telemetrySessionId!,
                episodeId: state.episodeId,
                eventType: 'complete',
                positionSeconds: state.currentPosition.inSeconds,
                playbackRate: state.playbackSpeed,
              );
            }
          } else if (playerState.processingState == ProcessingState.idle) {
            newStatus = PlaybackStatus.idle;
          } else if (playerState.playing) {
            newStatus = PlaybackStatus.playing;
            _lastTickTime ??= DateTime.now();
          } else {
            newStatus = PlaybackStatus.paused;
            _lastTickTime = null;
          }

          if (playerState.processingState == ProcessingState.completed) {
            _lastTickTime = null;
          }

          state = state.copyWith(
            isPlaying: playerState.playing,
            playbackStatus: newStatus,
          );
          // Auto-advance to next queued track on completion
          if (playerState.processingState == ProcessingState.completed) {
            playNextInQueue();
          }
        }
      },
      onError: (_) {
        if (!mounted) return;
        if (state.mode == 'AUDIO' && state.hasActiveEpisode) {
          state = state.copyWith(
            isPlaying: false,
            playbackStatus: PlaybackStatus.error,
            errorMessage: 'Erreur de lecture audio. Réessayez.',
          );
        }
      },
    ));
  }

  void _onPosition(Duration position) {
    if (!mounted) return;
    if (state.mode != 'AUDIO' || !state.hasActiveEpisode) return;
    if (position.inSeconds == state.currentPosition.inSeconds) return;
    state = state.copyWith(
      currentPosition: position,
      progress: _progress(position, state.totalDuration),
    );
  }

  void _onDuration(Duration? duration) {
    if (!mounted) return;
    if (duration == null || !state.hasActiveEpisode) return;
    if (duration == state.totalDuration) return;
    state = state.copyWith(
      totalDuration: duration,
      progress: _progress(state.currentPosition, duration),
    );
  }

  void _startHeartbeat(String epId, {String? recommendationId, String? sectionId}) {
    _heartbeatTimer?.cancel();
    _lastTickTime = DateTime.now();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (!state.isPlaying || !state.hasActiveEpisode || _telemetrySessionId == null) {
        _lastTickTime = null;
        return;
      }
      final curPos = state.currentPosition.inSeconds;
      final now = DateTime.now();
      if (_lastTickTime == null) {
        _lastTickTime = now;
        _lastProgressSec = curPos;
        return;
      }

      final wallClockSec = now.difference(_lastTickTime!).inMilliseconds / 1000.0;
      final contentDelta = curPos - _lastProgressSec;
      final speed = state.playbackSpeed > 0 ? state.playbackSpeed : 1.0;

      // Seul un défilement continu normal (0 < contentDelta <= 25) est comptabilisé
      if (contentDelta > 0 && contentDelta <= 25 && wallClockSec > 0) {
        // Le temps écouté réel est strictement borné par l'horloge murale ET le contenu / vitesse
        final wallClockDelta = min(wallClockSec, contentDelta / speed).round();
        if (wallClockDelta > 0) {
          BkoTelemetryService().trackListeningEvent(
            sessionId: _telemetrySessionId!,
            episodeId: epId,
            eventType: 'progress',
            positionSeconds: curPos,
            deltaSeconds: wallClockDelta,
            playbackRate: speed,
            recommendationId: recommendationId,
            sectionId: sectionId,
          );
        }
      }
      _lastTickTime = now;
      _lastProgressSec = curPos;
    });
  }

  Future<bool> playEpisode({
    required String title,
    required String showName,
    required String duration,
    required String coverUrl,
    String? audioUrl,
    String? videoUrl,
    bool? hasAudio,
    bool? hasVideo,
    String? initialMode,
    String? episodeId,
    String? podcastSlug,
    String? episodeSlug,
    List<QueueItem>? newQueue,
    String? batchId,
    String? sectionId,
    String? sectionSlug,
    String? recommendationId,
  }) async {
    final audioSource = _validUri(audioUrl);
    final videoSource = _validUri(videoUrl);
    final bool audioAvail = hasAudio ?? audioSource != null;
    final bool videoAvail = hasVideo ?? videoSource != null;
    final String targetMode = initialMode ?? (audioAvail ? 'AUDIO' : 'VIDEO');

    if ((targetMode == 'AUDIO' && audioSource == null) ||
        (targetMode == 'VIDEO' && videoSource == null)) {
      state = ActiveEpisodeState(
        title: title,
        showName: showName,
        duration: duration,
        coverUrl: coverUrl,
        audioUrl: audioUrl ?? '',
        videoUrl: videoUrl ?? '',
        hasAudio: audioAvail,
        hasVideo: videoAvail,
        episodeId: episodeId ?? '',
        podcastSlug: podcastSlug ?? '',
        episodeSlug: episodeSlug ?? '',
        queue: newQueue ?? state.queue,
        playbackSpeed: state.playbackSpeed,
        errorMessage: targetMode == 'AUDIO'
            ? 'Cet épisode ne propose pas de piste audio disponible.'
            : 'Cet épisode ne propose pas de vidéo disponible.',
      );
      return false;
    }

    final totalDur = _parseDuration(duration);
    final epId = episodeId ?? '';

    // Initialiser une nouvelle session d'écoute pour la télémétrie
    _telemetrySessionId = BkoTelemetryService().generateSessionId();
    _lastProgressSec = 0;

    if (epId.isNotEmpty) {
      BkoTelemetryService().trackListeningEvent(
        sessionId: _telemetrySessionId!,
        episodeId: epId,
        eventType: 'start',
        positionSeconds: 0,
        playbackRate: state.playbackSpeed,
        recommendationId: recommendationId,
        sectionId: sectionId,
      );
      _startHeartbeat(epId, recommendationId: recommendationId, sectionId: sectionId);
    }

    state = ActiveEpisodeState(
      hasActiveEpisode: true,
      isPlaying: targetMode == 'VIDEO',
      playbackStatus: targetMode == 'VIDEO'
          ? PlaybackStatus.playing
          : PlaybackStatus.loading,
      title: title,
      showName: showName,
      duration: duration,
      coverUrl: coverUrl,
      audioUrl: audioUrl ?? '',
      videoUrl: videoUrl ?? '',
      mode: targetMode,
      hasAudio: audioAvail,
      hasVideo: videoAvail,
      progress: 0,
      currentPosition: Duration.zero,
      totalDuration: totalDur,
      episodeId: epId,
      podcastSlug: podcastSlug ?? '',
      episodeSlug: episodeSlug ?? '',
      playbackSpeed: state.playbackSpeed,
      sleepTimerEndsAt: state.sleepTimerEndsAt,
      queue: newQueue ?? state.queue,
      errorMessage: null,
    );

    if (targetMode == 'AUDIO') {
      try {
        debugPrint('[ActiveEpisodeNotifier] Loading audio for "$title" from $audioSource');
        await _audioHandler.load(
          item: MediaItem(
            id: epId.isNotEmpty ? epId : audioSource.toString(),
            album: showName,
            title: title,
            artist: showName,
            duration: totalDur == Duration.zero ? null : totalDur,
            artUri: _validUri(coverUrl),
          ),
          source: audioSource!,
        );
        if (state.playbackSpeed != 1.0) {
          await _audioHandler.setSpeed(state.playbackSpeed);
        }
      } catch (e, st) {
        debugPrint('[ActiveEpisodeNotifier] Playback load error: $e\n$st');
        state = state.copyWith(
          hasActiveEpisode: false,
          isPlaying: false,
          playbackStatus: PlaybackStatus.error,
          errorMessage:
              'Impossible de lire cette piste audio. Réessayez dans un instant.',
        );
        return false;
      }
    } else {
      await _audioHandler.pause();
    }
    return true;
  }

  /// Inserts an episode immediately after the current playing track ("Lire ensuite")
  void playNext(QueueItem item) {
    state = state.copyWith(
      queue: [item, ...state.queue],
    );
  }

  /// Adds an episode to the end of the playback queue ("Ajouter à la file")
  void addToQueue(QueueItem item) {
    state = state.copyWith(
      queue: [...state.queue, item],
    );
  }

  /// Removes an item from the queue by index
  void removeFromQueue(int index) {
    if (index < 0 || index >= state.queue.length) return;
    final updated = List<QueueItem>.from(state.queue)..removeAt(index);
    state = state.copyWith(queue: updated);
  }

  /// Reorders items in the queue
  void reorderQueue(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= state.queue.length) return;
    final updated = List<QueueItem>.from(state.queue);
    int destIndex = newIndex;
    if (destIndex > oldIndex) destIndex -= 1;
    final item = updated.removeAt(oldIndex);
    updated.insert(destIndex, item);
    state = state.copyWith(queue: updated);
  }

  /// Clears all upcoming items in the queue
  void clearQueue() {
    state = state.copyWith(queue: const []);
  }

  /// Plays the next item in the queue, or stops if queue is empty
  Future<bool> playNextInQueue() async {
    if (state.queue.isEmpty) {
      return false;
    }
    final nextItem = state.queue.first;
    final remainingQueue = state.queue.sublist(1);
    return playEpisode(
      title: nextItem.title,
      showName: nextItem.showName,
      duration: nextItem.duration,
      coverUrl: nextItem.coverUrl,
      audioUrl: nextItem.audioUrl,
      videoUrl: nextItem.videoUrl,
      hasAudio: nextItem.hasAudio,
      hasVideo: nextItem.hasVideo,
      episodeId: nextItem.episodeId,
      podcastSlug: nextItem.podcastSlug,
      episodeSlug: nextItem.episodeSlug,
      newQueue: remainingQueue,
    );
  }

  /// Sets playback speed (e.g. 0.75, 1.0, 1.25, 1.5, 2.0)
  Future<void> setPlaybackSpeed(double speed) async {
    _lastTickTime = state.isPlaying ? DateTime.now() : null;
    state = state.copyWith(playbackSpeed: speed);
    if (state.mode == 'AUDIO') {
      await _audioHandler.setSpeed(speed);
    }
  }

  /// Relative seek forward or backward in seconds (e.g. -15 or +30)
  Future<void> seekRelative(int seconds) async {
    final current = state.currentPosition;
    final target = current + Duration(seconds: seconds);
    final bounded = target < Duration.zero
        ? Duration.zero
        : (state.totalDuration > Duration.zero && target > state.totalDuration
            ? state.totalDuration
            : target);
    await seek(bounded);
  }

  /// Sets a sleep timer that will pause playback when elapsed
  void setSleepTimer(Duration? duration) {
    _sleepTimer?.cancel();
    _sleepTimer = null;

    if (duration == null || duration <= Duration.zero) {
      state = state.copyWith(clearSleepTimer: true);
      return;
    }

    state = state.copyWith(
      sleepTimerEndsAt: DateTime.now().add(duration),
    );

    _sleepTimer = Timer(duration, () async {
      await togglePlayPause();
      state = state.copyWith(clearSleepTimer: true);
    });
  }

  Future<bool> setMode(String newMode) async {
    if (newMode == state.mode) return true;
    if (newMode == 'VIDEO' && !state.hasVideo) return false;
    if (newMode == 'AUDIO' && !state.hasAudio) return false;

    if (newMode == 'AUDIO') {
      final source = _validUri(state.audioUrl);
      if (source == null) return false;
      state = state.copyWith(mode: 'AUDIO', clearError: true);
      try {
        await _audioHandler.load(
          item: MediaItem(
            id: source.toString(),
            album: state.showName,
            title: state.title,
            artist: state.showName,
            duration: state.totalDuration == Duration.zero
                ? null
                : state.totalDuration,
            artUri: _validUri(state.coverUrl),
          ),
          source: source,
          initialPosition: state.currentPosition,
        );
        if (state.playbackSpeed != 1.0) {
          await _audioHandler.setSpeed(state.playbackSpeed);
        }
      } catch (_) {
        state = state.copyWith(
          isPlaying: false,
          errorMessage:
              'La piste audio n’a pas pu être chargée. Réessayez plus tard.',
        );
        return false;
      }
    } else {
      await _audioHandler.pause();
      state = state.copyWith(mode: 'VIDEO', isPlaying: true, clearError: true);
    }
    return true;
  }

  void pauseVideo() {
    if (state.mode == 'VIDEO' && state.isPlaying) {
      state = state.copyWith(
        isPlaying: false,
        playbackStatus: PlaybackStatus.paused,
      );
    }
  }

  Future<void> pause() async {
    if (!state.hasActiveEpisode || !state.isPlaying) return;
    if (state.mode == 'VIDEO') {
      pauseVideo();
    } else {
      await _audioHandler.pause();
      _lastTickTime = null;
      if (_telemetrySessionId != null && state.episodeId.isNotEmpty) {
        BkoTelemetryService().trackListeningEvent(
          sessionId: _telemetrySessionId!,
          episodeId: state.episodeId,
          eventType: 'pause',
          positionSeconds: state.currentPosition.inSeconds,
          deltaSeconds: 0,
          playbackRate: state.playbackSpeed,
        );
      }
      state = state.copyWith(
        isPlaying: false,
        playbackStatus: PlaybackStatus.paused,
      );
    }
  }

  Future<void> togglePlayPause() async {
    if (!state.hasActiveEpisode) return;
    if (state.mode == 'VIDEO') {
      final nextPlaying = !state.isPlaying;
      state = state.copyWith(
        isPlaying: nextPlaying,
        playbackStatus: nextPlaying ? PlaybackStatus.playing : PlaybackStatus.paused,
      );
    } else {
      if (state.isPlaying) {
        await _audioHandler.pause();
        _lastTickTime = null;
        if (_telemetrySessionId != null && state.episodeId.isNotEmpty) {
          BkoTelemetryService().trackListeningEvent(
            sessionId: _telemetrySessionId!,
            episodeId: state.episodeId,
            eventType: 'pause',
            positionSeconds: state.currentPosition.inSeconds,
            deltaSeconds: 0,
            playbackRate: state.playbackSpeed,
          );
        }
        state = state.copyWith(
          isPlaying: false,
          playbackStatus: PlaybackStatus.paused,
        );
      } else {
        _lastTickTime = DateTime.now();
        await _audioHandler.play();
        state = state.copyWith(
          isPlaying: true,
          playbackStatus: PlaybackStatus.playing,
        );
      }
    }
  }

  /// Unified action handler for all play/pause buttons across the app.
  /// Guarantees that:
  /// - Current playing episode -> pauses without reloading
  /// - Current paused episode -> resumes at exact position without reloading
  /// - Current buffering episode -> ignores repeated taps to prevent race conditions
  /// - Current errored episode -> retries loading
  /// - Different episode -> stops previous and loads new track cleanly
  Future<void> handlePlayOrPause({
    required String episodeId,
    required String title,
    required String showName,
    required String duration,
    required String coverUrl,
    String? audioUrl,
    String? videoUrl,
    bool? hasAudio,
    bool? hasVideo,
    String? initialMode,
    String? podcastSlug,
    String? episodeSlug,
    List<QueueItem>? newQueue,
    String? batchId,
    String? sectionId,
    String? sectionSlug,
    String? recommendationId,
  }) async {
    // 1. If currently active episode
    if (state.hasActiveEpisode &&
        state.episodeId.isNotEmpty &&
        state.episodeId == episodeId) {
      if (state.playbackStatus == PlaybackStatus.loading) {
        // Buffering / loading in progress: ignore to prevent race condition
        return;
      }
      if (state.playbackStatus == PlaybackStatus.error) {
        // Retry
        await playEpisode(
          title: title,
          showName: showName,
          duration: duration,
          coverUrl: coverUrl,
          audioUrl: audioUrl ?? state.audioUrl,
          videoUrl: videoUrl ?? state.videoUrl,
          hasAudio: hasAudio ?? state.hasAudio,
          hasVideo: hasVideo ?? state.hasVideo,
          initialMode: initialMode ?? state.mode,
          episodeId: episodeId,
          podcastSlug: podcastSlug ?? state.podcastSlug,
          episodeSlug: episodeSlug ?? state.episodeSlug,
          newQueue: newQueue,
          batchId: batchId,
          sectionId: sectionId,
          sectionSlug: sectionSlug,
          recommendationId: recommendationId,
        );
        return;
      }
      // Toggle at exact current position
      await togglePlayPause();
      return;
    }

    // 2. Different episode or none active: start loading and playing
    await playEpisode(
      title: title,
      showName: showName,
      duration: duration,
      coverUrl: coverUrl,
      audioUrl: audioUrl,
      videoUrl: videoUrl,
      hasAudio: hasAudio,
      hasVideo: hasVideo,
      initialMode: initialMode,
      episodeId: episodeId,
      podcastSlug: podcastSlug,
      episodeSlug: episodeSlug,
      newQueue: newQueue,
      batchId: batchId,
      sectionId: sectionId,
      sectionSlug: sectionSlug,
      recommendationId: recommendationId,
    );
  }

  Future<void> seek(Duration position) async {
    final bounded =
        state.totalDuration == Duration.zero || position <= state.totalDuration
            ? position
            : state.totalDuration;
    _lastProgressSec = bounded.inSeconds;
    _lastTickTime = state.isPlaying ? DateTime.now() : null;
    if (_telemetrySessionId != null && state.episodeId.isNotEmpty) {
      BkoTelemetryService().trackListeningEvent(
        sessionId: _telemetrySessionId!,
        episodeId: state.episodeId,
        eventType: 'seek',
        positionSeconds: bounded.inSeconds,
        deltaSeconds: 0,
        playbackRate: state.playbackSpeed,
      );
    }
    state = state.copyWith(
      currentPosition: bounded,
      progress: _progress(bounded, state.totalDuration),
    );
    if (state.mode == 'AUDIO') {
      await _audioHandler.seek(bounded);
    }
  }

  Future<void> stop() async {
    _heartbeatTimer?.cancel();
    _lastTickTime = null;
    if (_telemetrySessionId != null && state.episodeId.isNotEmpty) {
      BkoTelemetryService().trackListeningEvent(
        sessionId: _telemetrySessionId!,
        episodeId: state.episodeId,
        eventType: 'pause',
        positionSeconds: state.currentPosition.inSeconds,
        deltaSeconds: 0,
        playbackRate: state.playbackSpeed,
      );
    }
    await _audioHandler.stop();
    state = const ActiveEpisodeState();
  }

  static Uri? _validUri(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final clean = raw
        .trim()
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'");
    final uri = Uri.tryParse(clean);
    if (uri != null &&
        (uri.scheme == 'https' ||
            uri.scheme == 'http' ||
            uri.scheme == 'file')) {
      return uri;
    }
    try {
      final file = File(clean);
      if (file.existsSync()) {
        return file.uri;
      }
    } catch (_) {}
    return null;
  }

  static Duration _parseDuration(String value) {
    final minutes =
        RegExp(r'(\d+)\s*min', caseSensitive: false).firstMatch(value);
    if (minutes != null) return Duration(minutes: int.parse(minutes.group(1)!));
    final parts = value.split(':');
    if (parts.length == 2) {
      return Duration(
        minutes: int.tryParse(parts.first) ?? 0,
        seconds: int.tryParse(parts.last) ?? 0,
      );
    }
    return Duration.zero;
  }

  static double _progress(Duration position, Duration total) {
    if (total.inMilliseconds == 0) return 0;
    return (position.inMilliseconds / total.inMilliseconds)
        .clamp(0, 1)
        .toDouble();
  }

  @override
  void dispose() {
    _sleepTimer?.cancel();
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    super.dispose();
  }
}

final activeEpisodeProvider =
    StateNotifierProvider<ActiveEpisodeNotifier, ActiveEpisodeState>((ref) {
  return ActiveEpisodeNotifier(ref.watch(audioHandlerProvider));
});

// State for Scroll Navigation Bar Visibility (true = visible, false = hidden on scroll down)
class ShellNavVisibilityNotifier extends StateNotifier<bool> {
  ShellNavVisibilityNotifier() : super(true);

  void setVisible(bool isVisible) {
    if (state != isVisible) {
      state = isVisible;
    }
  }
}

final shellNavVisibilityProvider =
    StateNotifierProvider<ShellNavVisibilityNotifier, bool>((ref) {
  return ShellNavVisibilityNotifier();
});

final isFullPlayerOpenProvider = StateProvider<bool>((ref) => false);

/// Smoothly hides/shows the navigation bar and animates the floating mini-player
/// on scroll up/down across screens in the application.
bool handleShellScrollNotification(ScrollNotification notification, WidgetRef ref) {
  if (notification is ScrollUpdateNotification) {
    final delta = notification.scrollDelta ?? 0.0;
    final pixels = notification.metrics.pixels;
    if (pixels <= 10) {
      ref.read(shellNavVisibilityProvider.notifier).setVisible(true);
    } else if (delta > 2.5 && pixels > 25) {
      ref.read(shellNavVisibilityProvider.notifier).setVisible(false);
    } else if (delta < -2.5) {
      ref.read(shellNavVisibilityProvider.notifier).setVisible(true);
    }
  } else if (notification is UserScrollNotification) {
    if (notification.direction == ScrollDirection.forward) {
      ref.read(shellNavVisibilityProvider.notifier).setVisible(true);
    } else if (notification.direction == ScrollDirection.reverse &&
        notification.metrics.pixels > 25) {
      ref.read(shellNavVisibilityProvider.notifier).setVisible(false);
    }
  }
  return false;
}

