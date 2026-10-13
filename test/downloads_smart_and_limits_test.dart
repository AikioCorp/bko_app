import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bko_app/core/widgets/bko_download_toast.dart';
import 'package:bko_app/features/downloads/download_manager.dart';
import 'package:bko_app/features/downloads/widgets/download_limit_modal.dart';

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

    testWidgets('6. BkoDownloadToast renders sleek notification with episode title and action button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  BkoDownloadToast.show(
                    context,
                    title: 'Épisode 42 - Innovation Digitale',
                    podcastName: 'Bamako Tech',
                  );
                },
                child: const Text('Lancer'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Lancer'));
      await tester.pump();

      expect(find.text('Téléchargement lancé'), findsOneWidget);
      expect(find.text('Épisode 42 - Innovation Digitale'), findsOneWidget);
      expect(find.text('Voir'), findsOneWidget);
    });

    testWidgets('7. DownloadLimitModal displays clear guest limit information and benefits', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DownloadLimitModal(),
          ),
        ),
      );

      expect(find.text('Téléchargements illimités'), findsOneWidget);
      expect(find.textContaining('épisode d\'essai hors-ligne'), findsOneWidget);
      expect(find.text('Écoute hors-ligne illimitée'), findsOneWidget);
      expect(find.text('Synchronisation automatique'), findsOneWidget);
      expect(find.text('Se connecter ou créer un compte'), findsOneWidget);
      expect(find.text('Gérer mes téléchargements'), findsOneWidget);
    });
  });
}
