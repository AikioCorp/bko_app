import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bko_app/features/downloads/download_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SmartDownloadSettings Tests', () {
    test('1. Default settings are enabled with auto-delete and auto-download next', () {
      const settings = SmartDownloadSettings();
      expect(settings.smartDownloadsEnabled, isTrue);
      expect(settings.autoDeleteCompleted, isTrue);
      expect(settings.autoDownloadNext, isTrue);
      expect(settings.wifiOnly, isFalse);
    });

    test('2. copyWith correctly updates individual flags', () {
      const settings = SmartDownloadSettings();
      final updated = settings.copyWith(
        smartDownloadsEnabled: false,
        wifiOnly: true,
      );
      expect(updated.smartDownloadsEnabled, isFalse);
      expect(updated.autoDeleteCompleted, isTrue); // preserved
      expect(updated.autoDownloadNext, isTrue); // preserved
      expect(updated.wifiOnly, isTrue);
    });

    test('3. JSON serialization and deserialization roundtrip', () {
      const original = SmartDownloadSettings(
        smartDownloadsEnabled: true,
        autoDeleteCompleted: false,
        autoDownloadNext: true,
        wifiOnly: true,
      );
      final json = original.toJson();
      final restored = SmartDownloadSettings.fromJson(json);

      expect(restored.smartDownloadsEnabled, equals(original.smartDownloadsEnabled));
      expect(restored.autoDeleteCompleted, equals(original.autoDeleteCompleted));
      expect(restored.autoDownloadNext, equals(original.autoDownloadNext));
      expect(restored.wifiOnly, equals(original.wifiOnly));
    });
  });

  group('Download Limits and Offline Rules Tests', () {
    test('4. DownloadLimitException formats message correctly', () {
      const ex = DownloadLimitException('Limite atteinte : 1 épisode max sans compte');
      expect(ex.toString(), contains('1 épisode max'));
    });

    test('5. SharedPreferences correctly stores and restores download tasks', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final task = DownloadTask(
        episodeId: 'ep_guest_1',
        podcastSlug: 'podcast-test',
        episodeSlug: 'ep-1',
        title: 'Episode Invité 1',
        podcastName: 'Podcast Test',
        coverUrl: 'https://example.com/cover.jpg',
        audioUrl: 'https://example.com/audio.mp3',
        status: DownloadStatus.completed,
        progress: 1.0,
        localPath: '/mock/path/ep_guest_1.mp3',
        fileSize: 15000000,
        createdAt: DateTime.now(),
      );

      final taskJson = jsonEncode([task.toJson()]);
      await prefs.setString('bko_downloads_meta', taskJson);

      final retrieved = prefs.getString('bko_downloads_meta');
      expect(retrieved, isNotNull);

      final list = jsonDecode(retrieved!) as List;
      expect(list.length, equals(1));
      final decoded = DownloadTask.fromJson(list[0] as Map<String, dynamic>);
      expect(decoded.episodeId, equals('ep_guest_1'));
      expect(decoded.status, equals(DownloadStatus.completed));
      expect(decoded.fileSize, equals(15000000));
    });
  });
}
