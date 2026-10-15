import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

/// Bridges the app player with Android and iOS system media controls.
class BkoAudioHandler extends BaseAudioHandler with SeekHandler {
  BkoAudioHandler() {
    _initAudioSession();
    _player.playbackEventStream.listen(
      (event) {
        playbackState.add(_toPlaybackState(event));
      },
      onError: (Object e, StackTrace st) {
        debugPrint('[BkoAudioHandler] playbackEventStream error: $e');
        playbackState.add(
          playbackState.value.copyWith(
            processingState: AudioProcessingState.error,
            playing: false,
          ),
        );
      },
    );

    // Mettre à jour mediaItem dès que la durée réelle est résolue par ExoPlayer/AVPlayer
    _player.durationStream.listen((d) {
      if (d != null && d > Duration.zero) {
        final current = mediaItem.value;
        if (current != null && current.duration != d) {
          mediaItem.add(current.copyWith(duration: d));
        }
      }
    });

    // Mettre à jour le PlaybackState au rythme de la lecture pour le widget / lockscreen Android
    _player.positionStream.listen((pos) {
      if (_player.playing) {
        final last = _lastNotifiedSec;
        if (last == null || pos.inSeconds != last) {
          _lastNotifiedSec = pos.inSeconds;
          playbackState.add(_toPlaybackState());
        }
      }
    });
  }

  int? _lastNotifiedSec;

  Future<void> _initAudioSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
      session.interruptionEventStream.listen((event) {
        if (event.begin) {
          switch (event.type) {
            case AudioInterruptionType.duck:
              _player.setVolume(0.5);
              break;
            case AudioInterruptionType.pause:
            case AudioInterruptionType.unknown:
              pause();
              break;
          }
        } else {
          switch (event.type) {
            case AudioInterruptionType.duck:
              _player.setVolume(1.0);
              break;
            case AudioInterruptionType.pause:
              play();
              break;
            case AudioInterruptionType.unknown:
              break;
          }
        }
      });
      session.becomingNoisyEventStream.listen((_) {
        pause();
      });
    } catch (e) {
      debugPrint('[BkoAudioHandler] Error configuring AudioSession: $e');
    }
  }

  final AudioPlayer _player = AudioPlayer();

  Duration? get duration => _player.duration;
  Duration get position => _player.position;

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;

  Future<void> load({
    required MediaItem item,
    required Uri source,
    Duration initialPosition = Duration.zero,
    bool autoplay = true,
  }) async {
    mediaItem.add(item);
    try {
      debugPrint('[BkoAudioHandler] load() source: $source, autoplay: $autoplay');
      try {
        final session = await AudioSession.instance;
        await session.setActive(true);
      } catch (e) {
        debugPrint('[BkoAudioHandler] AudioSession setActive warning: $e');
      }

      final resolvedDuration = await _player.setAudioSource(
        AudioSource.uri(
          source,
          headers: const {
            'User-Agent': 'BamakoPodcast/1.0 (Android; Mobile)',
            'Accept': '*/*',
          },
        ),
        initialPosition: initialPosition,
      );
      await _player.setVolume(1.0);
      debugPrint('[BkoAudioHandler] Loaded successfully. Duration: ${_player.duration}');

      final finalDuration = resolvedDuration ?? _player.duration;
      if (finalDuration != null && finalDuration > Duration.zero) {
        mediaItem.add(item.copyWith(duration: finalDuration));
      }

      if (autoplay) {
        await play();
      }
    } catch (e, st) {
      debugPrint('[BkoAudioHandler] ERROR loading audio source: $e\n$st');
      rethrow;
    }
  }

  @override
  Future<void> play() async {
    try {
      try {
        final session = await AudioSession.instance;
        await session.setActive(true);
      } catch (_) {}
      await _player.play();
      playbackState.add(_toPlaybackState());
    } catch (e) {
      debugPrint('[BkoAudioHandler] play error: $e');
    }
  }

  @override
  Future<void> pause() async {
    try {
      await _player.pause();
      playbackState.add(_toPlaybackState());
    } catch (_) {}
  }

  @override
  Future<void> seek(Duration position) async {
    try {
      await _player.seek(position);
      playbackState.add(_toPlaybackState());
    } catch (_) {}
  }

  @override
  Future<void> fastForward() async {
    try {
      final cur = _player.position;
      await seek(cur + const Duration(seconds: 30));
    } catch (_) {}
  }

  @override
  Future<void> rewind() async {
    try {
      final cur = _player.position;
      final target = cur - const Duration(seconds: 15);
      await seek(target < Duration.zero ? Duration.zero : target);
    } catch (_) {}
  }

  @override
  Future<void> setSpeed(double speed) async {
    try {
      await _player.setSpeed(speed);
      playbackState.add(_toPlaybackState());
    } catch (_) {}
  }

  @override
  Future<void> stop() async {
    try {
      await _player.stop();
      playbackState.add(_toPlaybackState());
    } catch (_) {}
  }

  Future<void> disposePlayer() async {
    try {
      await _player.dispose();
    } catch (_) {}
  }

  PlaybackState _toPlaybackState([PlaybackEvent? event]) {
    const processingStateMap = {
      ProcessingState.idle: AudioProcessingState.idle,
      ProcessingState.loading: AudioProcessingState.loading,
      ProcessingState.buffering: AudioProcessingState.buffering,
      ProcessingState.ready: AudioProcessingState.ready,
      ProcessingState.completed: AudioProcessingState.completed,
    };

    return PlaybackState(
      controls: [
        MediaControl.rewind,
        if (_player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
        MediaControl.fastForward,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekBackward,
        MediaAction.seekForward,
        MediaAction.setSpeed,
      },
      androidCompactActionIndices: const [0, 1, 3],
      processingState:
          processingStateMap[_player.processingState] ?? AudioProcessingState.idle,
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      updateTime: DateTime.now(),
    );
  }
}
