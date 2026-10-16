import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:bko_app/core/utils/youtube_url_parser.dart';
import 'package:bko_app/core/widgets/app_header_actions.dart';
import 'package:bko_app/features/notifications/notification_providers.dart';
import 'package:bko_app/features/player/bko_audio_handler.dart';
import 'package:bko_app/features/shell/bko_mini_player.dart';
import 'package:bko_app/features/shell/shell_providers.dart';

class _TestUnreadNotifier extends UnreadNotificationsNotifier {
  _TestUnreadNotifier(super.ref) {
    state = 2;
  }
}

class FakeBkoAudioHandler extends Fake implements BkoAudioHandler {
  final _positionController = StreamController<Duration>.broadcast();
  final _durationController = StreamController<Duration?>.broadcast();
  final _playerStateController = StreamController<PlayerState>.broadcast();
  Duration? _currentDuration;

  @override
  Stream<Duration> get positionStream => _positionController.stream;

  @override
  Stream<Duration?> get durationStream => _durationController.stream;

  @override
  Stream<PlayerState> get playerStateStream => _playerStateController.stream;

  @override
  Duration? get duration => _currentDuration;

  @override
  Future<void> pause() async {}

  @override
  Future<void> play() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> load({
    required MediaItem item,
    required Uri source,
    Duration initialPosition = Duration.zero,
    bool autoplay = true,
  }) async {
    _currentDuration = item.duration;
  }

  @override
  Future<void> setSpeed(double speed) async {}

  void dispose() {
    _positionController.close();
    _durationController.close();
    _playerStateController.close();
  }
}

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  group('YouTube URL Parsing & Normalization', () {
    test('extracts videoId from standard watch URL', () {
      final id = YoutubeUrlParser.tryParseVideoId('https://www.youtube.com/watch?v=dQw4w9WgXcQ');
      expect(id, equals('dQw4w9WgXcQ'));
    });

    test('extracts videoId from youtu.be short URL', () {
      final id = YoutubeUrlParser.tryParseVideoId('https://youtu.be/dQw4w9WgXcQ?t=42');
      expect(id, equals('dQw4w9WgXcQ'));
    });

    test('extracts videoId from shorts URL', () {
      final id = YoutubeUrlParser.tryParseVideoId('https://www.youtube.com/shorts/dQw4w9WgXcQ');
      expect(id, equals('dQw4w9WgXcQ'));
    });

    test('extracts videoId from live URL', () {
      final id = YoutubeUrlParser.tryParseVideoId('https://www.youtube.com/live/dQw4w9WgXcQ');
      expect(id, equals('dQw4w9WgXcQ'));
    });

    test('extracts videoId from embed URL', () {
      final id = YoutubeUrlParser.tryParseVideoId('https://www.youtube-nocookie.com/embed/dQw4w9WgXcQ');
      expect(id, equals('dQw4w9WgXcQ'));
    });

    test('returns null for non-YouTube video files (native MP4/MOV)', () {
      final id = YoutubeUrlParser.tryParseVideoId('https://storage.bamakopodcast.ml/media/episodes/video.mp4');
      expect(id, isNull);
    });
  });

  group('ActiveEpisodeNotifier Video Playback Synchronization', () {
    late FakeBkoAudioHandler fakeAudio;
    late ProviderContainer container;

    setUp(() {
      fakeAudio = FakeBkoAudioHandler();
      container = ProviderContainer(
        overrides: [
          audioHandlerProvider.overrideWithValue(fakeAudio),
        ],
      );
    });

    tearDown(() {
      fakeAudio.dispose();
      container.dispose();
    });

    test('playEpisode in VIDEO mode starts with loading state and not playing until confirmed', () async {
      final notifier = container.read(activeEpisodeProvider.notifier);

      final ok = await notifier.playEpisode(
        title: 'Vidéo Test',
        showName: 'Bamako Studio',
        duration: '10:00',
        coverUrl: 'https://example.com/cover.jpg',
        videoUrl: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
        hasVideo: true,
        initialMode: 'VIDEO',
        episodeId: 'ep-vid-1',
      );

      expect(ok, isTrue);
      final state = container.read(activeEpisodeProvider);
      expect(state.hasActiveEpisode, isTrue);
      expect(state.mode, equals('VIDEO'));
      expect(state.isPlaying, isFalse);
      expect(state.playbackStatus, equals(PlaybackStatus.loading));
    });

    test('onVideoStateChanged updates isPlaying and playbackStatus', () async {
      final notifier = container.read(activeEpisodeProvider.notifier);
      await notifier.playEpisode(
        title: 'Vidéo Test',
        showName: 'Bamako Studio',
        duration: '10:00',
        coverUrl: 'https://example.com/cover.jpg',
        videoUrl: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
        hasVideo: true,
        initialMode: 'VIDEO',
        episodeId: 'ep-vid-1',
      );

      notifier.onVideoStateChanged(isPlaying: true, status: PlaybackStatus.playing);
      var state = container.read(activeEpisodeProvider);
      expect(state.isPlaying, isTrue);
      expect(state.playbackStatus, equals(PlaybackStatus.playing));

      notifier.onVideoStateChanged(isPlaying: false, status: PlaybackStatus.paused);
      state = container.read(activeEpisodeProvider);
      expect(state.isPlaying, isFalse);
      expect(state.playbackStatus, equals(PlaybackStatus.paused));
    });

    test('onVideoProgress updates position and progress bar', () async {
      final notifier = container.read(activeEpisodeProvider.notifier);
      await notifier.playEpisode(
        title: 'Vidéo Test',
        showName: 'Bamako Studio',
        duration: '10:00',
        coverUrl: 'https://example.com/cover.jpg',
        videoUrl: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
        hasVideo: true,
        initialMode: 'VIDEO',
        episodeId: 'ep-vid-1',
      );

      notifier.onVideoProgress(
        const Duration(seconds: 150),
        const Duration(minutes: 10),
      );

      final state = container.read(activeEpisodeProvider);
      expect(state.currentPosition, equals(const Duration(seconds: 150)));
      expect(state.totalDuration, equals(const Duration(minutes: 10)));
      expect(state.progress, closeTo(0.25, 0.001));
    });

    test('seek increments videoSeekRequestId and sets videoSeekTarget', () async {
      final notifier = container.read(activeEpisodeProvider.notifier);
      await notifier.playEpisode(
        title: 'Vidéo Test',
        showName: 'Bamako Studio',
        duration: '10:00',
        coverUrl: 'https://example.com/cover.jpg',
        videoUrl: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
        hasVideo: true,
        initialMode: 'VIDEO',
        episodeId: 'ep-vid-1',
      );

      final initialSeekId = container.read(activeEpisodeProvider).videoSeekRequestId;

      await notifier.seek(const Duration(minutes: 3));

      final state = container.read(activeEpisodeProvider);
      expect(state.videoSeekRequestId, equals(initialSeekId + 1));
      expect(state.videoSeekTarget, equals(const Duration(minutes: 3)));
      expect(state.currentPosition, equals(const Duration(minutes: 3)));
    });

    test('switching between AUDIO and VIDEO preserves playback position', () async {
      final notifier = container.read(activeEpisodeProvider.notifier);
      await notifier.playEpisode(
        title: 'Épisode Mixte',
        showName: 'Bamako Studio',
        duration: '10:00',
        coverUrl: 'https://example.com/cover.jpg',
        audioUrl: 'https://example.com/audio.mp3',
        videoUrl: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
        hasAudio: true,
        hasVideo: true,
        initialMode: 'VIDEO',
        episodeId: 'ep-mix-1',
      );

      notifier.onVideoProgress(
        const Duration(seconds: 90),
        const Duration(minutes: 10),
      );

      // Switch to AUDIO
      final switchedToAudio = await notifier.setMode('AUDIO');
      expect(switchedToAudio, isTrue);
      var state = container.read(activeEpisodeProvider);
      expect(state.mode, equals('AUDIO'));
      expect(state.currentPosition, equals(const Duration(seconds: 90)));

      // Switch back to VIDEO
      final switchedToVideo = await notifier.setMode('VIDEO');
      expect(switchedToVideo, isTrue);
      state = container.read(activeEpisodeProvider);
      expect(state.mode, equals('VIDEO'));
      expect(state.videoSeekTarget, equals(const Duration(seconds: 90)));
    });

    test('onVideoEnded advances to next track and resets state', () async {
      final notifier = container.read(activeEpisodeProvider.notifier);
      await notifier.playEpisode(
        title: 'Vidéo Finie',
        showName: 'Bamako Studio',
        duration: '01:00',
        coverUrl: 'https://example.com/cover.jpg',
        videoUrl: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
        hasVideo: true,
        initialMode: 'VIDEO',
        episodeId: 'ep-vid-end',
      );

      notifier.onVideoEnded();

      final state = container.read(activeEpisodeProvider);
      expect(state.isPlaying, isFalse);
      expect(state.playbackStatus, equals(PlaybackStatus.completed));
    });
  });

  group('Full Player Visibility Coordination', () {
    testWidgets('AppHeaderActions is hidden when full player is open', (tester) async {
      final fakeAudio = FakeBkoAudioHandler();
      final container = ProviderContainer(
        overrides: [
          audioHandlerProvider.overrideWithValue(fakeAudio),
          unreadNotificationsProvider.overrideWith((ref) => _TestUnreadNotifier(ref)),
        ],
      );
      addTearDown(() {
        fakeAudio.dispose();
        container.dispose();
      });

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              appBar: PreferredSize(
                preferredSize: Size.fromHeight(56),
                child: AppHeaderActions(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially full player is closed, actions visible
      expect(find.byType(IconButton), findsWidgets);

      // Open full player
      container.read(isFullPlayerOpenProvider.notifier).state = true;
      await tester.pumpAndSettle();

      // AppHeaderActions returns SizedBox.shrink()
      expect(find.byType(IconButton), findsNothing);
    });
  });
}
