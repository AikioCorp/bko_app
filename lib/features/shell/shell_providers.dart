import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../player/bko_audio_handler.dart';

// State for Active Playback Episode
class ActiveEpisodeState {
  final bool hasActiveEpisode;
  final bool isPlaying;
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
  final String? errorMessage;

  const ActiveEpisodeState({
    this.hasActiveEpisode = false,
    this.isPlaying = false,
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
    this.errorMessage,
  });

  ActiveEpisodeState copyWith({
    bool? hasActiveEpisode,
    bool? isPlaying,
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
    String? errorMessage,
    bool clearError = false,
  }) {
    return ActiveEpisodeState(
      hasActiveEpisode: hasActiveEpisode ?? this.hasActiveEpisode,
      isPlaying: isPlaying ?? this.isPlaying,
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
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

final audioHandlerProvider = Provider<BkoAudioHandler>((ref) {
  throw StateError(
      'BkoAudioHandler must be provided during application startup.');
});

class ActiveEpisodeNotifier extends StateNotifier<ActiveEpisodeState> {
  ActiveEpisodeNotifier(this._audioHandler)
      : super(const ActiveEpisodeState()) {
    _subscriptions.add(_audioHandler.positionStream.listen(_onPosition));
    _subscriptions.add(_audioHandler.durationStream.listen(_onDuration));
    _subscriptions.add(_audioHandler.playerStateStream.listen((playerState) {
      if (state.mode == 'AUDIO' && state.hasActiveEpisode) {
        state = state.copyWith(isPlaying: playerState.playing);
      }
    }));
  }

  final BkoAudioHandler _audioHandler;
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  void _onPosition(Duration position) {
    if (state.mode != 'AUDIO' || !state.hasActiveEpisode) return;
    state = state.copyWith(
      currentPosition: position,
      progress: _progress(position, state.totalDuration),
    );
  }

  void _onDuration(Duration? duration) {
    if (duration == null || !state.hasActiveEpisode) return;
    state = state.copyWith(
      totalDuration: duration,
      progress: _progress(state.currentPosition, duration),
    );
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
        errorMessage: targetMode == 'AUDIO'
            ? 'Cet épisode ne propose pas de piste audio disponible.'
            : 'Cet épisode ne propose pas de vidéo disponible.',
      );
      return false;
    }

    final totalDur = _parseDuration(duration);

    state = ActiveEpisodeState(
      hasActiveEpisode: true,
      isPlaying: targetMode == 'VIDEO',
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
      episodeId: episodeId ?? '',
      podcastSlug: podcastSlug ?? '',
      errorMessage: null,
    );

    if (targetMode == 'AUDIO') {
      try {
        await _audioHandler.load(
          item: MediaItem(
            id: audioSource.toString(),
            album: showName,
            title: title,
            artist: showName,
            duration: totalDur == Duration.zero ? null : totalDur,
            artUri: _validUri(coverUrl),
          ),
          source: audioSource!,
        );
      } catch (_) {
        state = state.copyWith(
          hasActiveEpisode: false,
          isPlaying: false,
          errorMessage:
              'La piste audio n’a pas pu être chargée. Réessayez plus tard.',
        );
        return false;
      }
    } else {
      await _audioHandler.pause();
    }
    return true;
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

  Future<void> togglePlayPause() async {
    if (!state.hasActiveEpisode) return;
    if (state.mode == 'VIDEO') {
      state = state.copyWith(isPlaying: !state.isPlaying);
    } else {
      if (state.isPlaying) {
        await _audioHandler.pause();
      } else {
        await _audioHandler.play();
      }
    }
  }

  Future<void> seek(Duration position) async {
    final bounded =
        state.totalDuration == Duration.zero || position <= state.totalDuration
            ? position
            : state.totalDuration;
    state = state.copyWith(
      currentPosition: bounded,
      progress: _progress(bounded, state.totalDuration),
    );
    if (state.mode == 'AUDIO') {
      await _audioHandler.seek(bounded);
    }
  }

  Future<void> stop() async {
    await _audioHandler.stop();
    state = const ActiveEpisodeState();
  }

  static Uri? _validUri(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final uri = Uri.tryParse(raw.trim());
    return uri != null && (uri.scheme == 'https' || uri.scheme == 'http')
        ? uri
        : null;
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
