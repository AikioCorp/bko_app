import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bko_app/core/network/bko_api.dart';
import 'package:bko_app/core/services/media_upload_service.dart';
import 'package:bko_app/core/utils/youtube_url_parser.dart';
import 'package:bko_app/features/auth/auth_controller.dart';
import 'package:bko_app/features/studio/create_episode_screen.dart';
import 'package:bko_app/features/studio/youtube_channel_import_screen.dart';

void main() {
  group('YoutubeUrlParser - Normalisation & Sécurité des liens YouTube', () {
    test('reconnaît toutes les variantes valides de vidéos YouTube', () {
      expect(
        YoutubeUrlParser.tryParseVideoId(
            'https://www.youtube.com/watch?v=dQw4w9WgXcQ'),
        'dQw4w9WgXcQ',
      );
      expect(
        YoutubeUrlParser.tryParseVideoId(
            'https://youtube.com/watch?feature=share&v=dQw4w9WgXcQ&t=42s'),
        'dQw4w9WgXcQ',
      );
      expect(
        YoutubeUrlParser.tryParseVideoId(
            'https://youtu.be/dQw4w9WgXcQ?si=abc123XYZ'),
        'dQw4w9WgXcQ',
      );
      expect(
        YoutubeUrlParser.tryParseVideoId(
            'https://www.youtube.com/shorts/dQw4w9WgXcQ?feature=share'),
        'dQw4w9WgXcQ',
      );
      expect(
        YoutubeUrlParser.tryParseVideoId(
            'https://www.youtube.com/live/dQw4w9WgXcQ?feature=share'),
        'dQw4w9WgXcQ',
      );
      expect(
        YoutubeUrlParser.tryParseVideoId(
            'https://www.youtube.com/embed/dQw4w9WgXcQ?autoplay=1'),
        'dQw4w9WgXcQ',
      );
      expect(
        YoutubeUrlParser.tryParseVideoId(
            'https://www.youtube-nocookie.com/embed/dQw4w9WgXcQ'),
        'dQw4w9WgXcQ',
      );
      expect(
        YoutubeUrlParser.tryParseVideoId(
            'https://m.youtube.com/watch?v=dQw4w9WgXcQ'),
        'dQw4w9WgXcQ',
      );
      expect(
        YoutubeUrlParser.tryParseVideoId(
            'https://music.youtube.com/watch?v=dQw4w9WgXcQ'),
        'dQw4w9WgXcQ',
      );
    });

    test('rejette les domaines trompeurs contenant le mot youtube', () {
      expect(
        YoutubeUrlParser.tryParseVideoId(
            'https://evil-youtube.com/watch?v=dQw4w9WgXcQ'),
        isNull,
      );
      expect(
        YoutubeUrlParser.tryParseVideoId(
            'https://youtube.com.attacker.org/watch?v=dQw4w9WgXcQ'),
        isNull,
      );
      expect(
        YoutubeUrlParser.tryParseVideoId('https://notyoutube.com/dQw4w9WgXcQ'),
        isNull,
      );
      expect(
        YoutubeUrlParser.isDeceptiveYoutubeDomain(
            'https://evil-youtube.com/watch?v=dQw4w9WgXcQ'),
        isTrue,
      );
      expect(
        YoutubeUrlParser.isYoutubeDomain('https://evil-youtube.com'),
        isFalse,
      );
    });

    test('rejette les identifiants de longueur invalide et les URLs de chaînes', () {
      expect(
        YoutubeUrlParser.tryParseVideoId('https://www.youtube.com/watch?v=short'),
        isNull,
      );
      expect(
        YoutubeUrlParser.tryParseVideoId(
            'https://www.youtube.com/watch?v=too_long_video_id_123'),
        isNull,
      );
      expect(
        YoutubeUrlParser.tryParseVideoId('https://www.youtube.com/@BamakoPodcast'),
        isNull,
      );
      expect(
        YoutubeUrlParser.isYoutubeChannelInput(
            'https://www.youtube.com/@BamakoPodcast'),
        isTrue,
      );
      expect(
        YoutubeUrlParser.isYoutubeChannelInput(
            'https://www.youtube.com/watch?v=dQw4w9WgXcQ'),
        isFalse,
      );
    });
  });

  group('MediaUploadService - Validation des fichiers et tailles', () {
    test('rejette les images vides, trop volumineuses ou au type MIME invalide',
        () async {
      await expectLater(
        MediaUploadService.uploadImage(
          bytes: Uint8List(0),
          mimeType: 'image/jpeg',
          folder: 'covers',
          token: 'test-token',
        ),
        throwsA(isA<ApiException>().having(
          (e) => e.message,
          'message',
          contains('vide'),
        )),
      );

      await expectLater(
        MediaUploadService.uploadImage(
          bytes: Uint8List(10),
          mimeType: 'application/pdf',
          folder: 'covers',
          token: 'test-token',
        ),
        throwsA(isA<ApiException>().having(
          (e) => e.message,
          'message',
          contains('Format d\'image refusé'),
        )),
      );

      await expectLater(
        MediaUploadService.uploadImage(
          bytes: Uint8List(MediaUploadService.maxImageBytes + 1),
          mimeType: 'image/png',
          folder: 'avatars',
          token: 'test-token',
        ),
        throwsA(isA<ApiException>().having(
          (e) => e.message,
          'message',
          contains('10 Mo'),
        )),
      );
    });
  });

  group('YoutubeChannelImportScreen - Réponses BkoApi désencapsulées', () {
    late Interceptor testInterceptor;

    tearDown(() {
      BkoApi.dio.interceptors.remove(testInterceptor);
    });

    testWidgets(
        'analyse une chaîne, pagine, filtre et connecte avec réponse BkoApi désencapsulée',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      bool isConnected = false;
      List<String>? connectedSelectedIds;

      testInterceptor = InterceptorsWrapper(
        onRequest: (options, handler) {
          final path = options.uri.path;
          if (path.contains('/notifications/unread-count')) {
            return handler.resolve(Response(
              requestOptions: options,
              statusCode: 200,
              data: {'success': true, 'data': {'unreadCount': 0}},
            ));
          }
          if (path.endsWith('/creator/podcasts') && options.method == 'GET') {
            return handler.resolve(Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'success': true,
                'data': [
                  {'id': 'pod-1', 'name': 'Les Voix de Bamako'}
                ],
              },
            ));
          }
          if (path.endsWith('/creator/podcasts/pod-1/youtube') &&
              options.method == 'GET') {
            if (!isConnected) {
              return handler.resolve(Response(
                requestOptions: options,
                statusCode: 200,
                data: {'success': true, 'data': null},
              ));
            }
            return handler.resolve(Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'success': true,
                'data': {
                  'channel': {
                    'channelId': 'UC1234567890123456789012',
                    'channelTitle': 'Bamako Studio TV',
                    'syncStatus': 'PARTIAL',
                    'syncEnabled': true,
                    'lastSyncError': '1 vidéo non intégrable ignorée',
                    'syncRuns': [
                      {
                        'id': 'run-1',
                        'status': 'PARTIAL',
                        'videosImported': 2,
                        'videosSkipped': 0,
                        'videosFailed': 1,
                        'errorMessage': 'Vidéo privée',
                      }
                    ],
                  },
                  'counts': {'importedVideos': 2},
                },
              },
            ));
          }
          if (path.endsWith('/creator/youtube/preview') &&
              options.method == 'POST') {
            final body = options.data as Map<String, dynamic>;
            final pageToken = body['pageToken'];
            if (pageToken == 'PAGE_2') {
              return handler.resolve(Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'success': true,
                  'data': {
                    'channel': {
                      'channelId': 'UC1234567890123456789012',
                      'title': 'Bamako Studio TV',
                    },
                    'items': [
                      {
                        'youtubeVideoId': 'vidPage2_11',
                        'title': 'Épisode Archive 2',
                        'durationSeconds': 1800,
                        'isLikelyShort': false,
                        'isAlreadyImported': false,
                        'embeddable': true,
                      }
                    ],
                    'nextPageToken': null,
                  },
                },
              ));
            }
            return handler.resolve(Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'success': true,
                'data': {
                  'channel': {
                    'channelId': 'UC1234567890123456789012',
                    'title': 'Bamako Studio TV',
                  },
                  'items': [
                    {
                      'youtubeVideoId': 'vidValid_01',
                      'title': 'Grand Entretien Bamako #1',
                      'durationSeconds': 2400,
                      'isLikelyShort': false,
                      'isAlreadyImported': false,
                      'embeddable': true,
                    },
                    {
                      'youtubeVideoId': 'vidAlrdy_02',
                      'title': 'Déjà sur Bamako Podcast',
                      'durationSeconds': 1500,
                      'isLikelyShort': false,
                      'isAlreadyImported': true,
                      'embeddable': true,
                    },
                  ],
                  'nextPageToken': 'PAGE_2',
                },
              },
            ));
          }
          if (path.endsWith('/creator/podcasts/pod-1/youtube/connect') &&
              options.method == 'POST') {
            final body = options.data as Map<String, dynamic>;
            connectedSelectedIds =
                (body['selectedVideoIds'] as List).cast<String>();
            isConnected = true;
            return handler.resolve(Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'success': true,
                'data': {'channelId': 'UC1234567890123456789012'},
              },
            ));
          }
          return handler.next(options);
        },
      );
      BkoApi.dio.interceptors.insert(0, testInterceptor);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(
              (ref) => AuthNotifier.withInitialState(
                const AuthState(isAuthenticated: true, token: 'test-token'),
              ),
            ),
          ],
          child: const MaterialApp(
            home: YoutubeChannelImportScreen(initialPodcastId: 'pod-1'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Saisir l'identifiant de la chaîne et analyser
      await tester.enterText(
          find.byType(TextField).first, '@BamakoStudioTV');
      await tester.tap(find.text('Analyser la chaîne'));
      await tester.pumpAndSettle();

      // Vérifie que l'aperçu s'affiche avec les vidéos
      expect(find.text('Bamako Studio TV'), findsOneWidget);
      expect(find.text('Grand Entretien Bamako #1'), findsOneWidget);
      expect(find.text('Déjà sur Bamako Podcast'), findsOneWidget);

      // Charger la page suivante (pagination)
      await tester.ensureVisible(
          find.text('Charger les vidéos suivantes / anciennes'));
      await tester.tap(find.text('Charger les vidéos suivantes / anciennes'));
      await tester.pumpAndSettle();

      expect(find.text('Épisode Archive 2'), findsOneWidget);

      // Sélectionner la vidéo de la page 2
      await tester.tap(find.text('Épisode Archive 2'));
      await tester.pumpAndSettle();

      // Continuer vers l'étape de configuration
      final continueBtn = find.textContaining('Continuer (');
      await tester.ensureVisible(continueBtn);
      await tester.tap(continueBtn);
      await tester.pumpAndSettle();

      // Confirmer et démarrer l'import
      final confirmBtn = find.text('Confirmer et démarrer l’importation');
      await tester.ensureVisible(confirmBtn);
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      // Seules les vidéos non importées doivent avoir été envoyées
      expect(connectedSelectedIds, isNotNull);
      expect(connectedSelectedIds, contains('vidValid_01'));
      expect(connectedSelectedIds, contains('vidPage2_11'));
      expect(connectedSelectedIds, isNot(contains('vidAlrdy_02')));

      // Le statut réel PARTIAL du serveur est affiché
      expect(find.text('Partiel'), findsWidgets);
    });
  });

  group(
      'CreateEpisodeScreen - Fiabilité du brouillon, erreur source et nouvelle tentative sans doublon',
      () {
    late Interceptor testInterceptor;

    tearDown(() {
      BkoApi.dio.interceptors.remove(testInterceptor);
    });

    testWidgets(
        'conserve le brouillon en cas d\'échec d\'association média, n\'affiche jamais "Épisode publié" à tort, et réessaie sans créer de doublon',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      int createEpisodeCalls = 0;
      int patchEpisodeCalls = 0;
      int attachSourceCalls = 0;
      int publishCalls = 0;
      bool shouldFailAttachSource = true;
      Map<String, dynamic>? lastCreatePayload;

      testInterceptor = InterceptorsWrapper(
        onRequest: (options, handler) {
          final path = options.uri.path;
          if (path.contains('/notifications/unread-count')) {
            return handler.resolve(Response(
              requestOptions: options,
              statusCode: 200,
              data: {'success': true, 'data': {'unreadCount': 0}},
            ));
          }
          if (path.endsWith('/creator/podcasts') && options.method == 'GET') {
            return handler.resolve(Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'success': true,
                'data': [
                  {'id': 'pod-1', 'name': 'Les Voix du Mali'}
                ],
              },
            ));
          }
          if (path.endsWith('/creator/podcasts/pod-1/episodes') &&
              options.method == 'POST') {
            createEpisodeCalls++;
            lastCreatePayload = Map<String, dynamic>.from(options.data as Map);
            return handler.resolve(Response(
              requestOptions: options,
              statusCode: 201,
              data: {
                'success': true,
                'data': {'id': 'ep-draft-42', 'status': 'DRAFT'},
              },
            ));
          }
          if (path.endsWith('/creator/episodes/ep-draft-42') &&
              options.method == 'PATCH') {
            patchEpisodeCalls++;
            return handler.resolve(Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'success': true,
                'data': {'id': 'ep-draft-42', 'status': 'DRAFT'},
              },
            ));
          }
          if (path.endsWith('/creator/episodes/ep-draft-42/media-sources') &&
              options.method == 'POST') {
            attachSourceCalls++;
            if (shouldFailAttachSource) {
              return handler.reject(
                DioException(
                  requestOptions: options,
                  response: Response(
                    requestOptions: options,
                    statusCode: 400,
                    data: {
                      'success': false,
                      'error': {
                        'code': 'INVALID_MEDIA_SOURCE',
                        'message':
                            'Serveur de média temporairement indisponible.',
                      },
                    },
                  ),
                  type: DioExceptionType.badResponse,
                ),
              );
            }
            return handler.resolve(Response(
              requestOptions: options,
              statusCode: 201,
              data: {
                'success': true,
                'data': {'id': 'source-1', 'type': 'AUDIO'},
              },
            ));
          }
          if (path.endsWith('/creator/episodes/ep-draft-42/publish') &&
              options.method == 'POST') {
            publishCalls++;
            return handler.resolve(Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'success': true,
                'data': {'id': 'ep-draft-42', 'status': 'PENDING_REVIEW'},
              },
            ));
          }
          return handler.next(options);
        },
      );
      BkoApi.dio.interceptors.insert(0, testInterceptor);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(
              (ref) => AuthNotifier.withInitialState(
                const AuthState(isAuthenticated: true, token: 'test-token'),
              ),
            ),
          ],
          child: const MaterialApp(
            home: CreateEpisodeScreen(initialPodcastId: 'pod-1'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Remplir le titre, la description, l'audio, la saison et le numéro d'épisode
      final fields = find.byType(TextFormField);
      // 0: title, 1: description, 2: audioUrl, 3: videoUrl, 4: coverUrl, 5: season, 6: episodeNumber
      await tester.enterText(fields.at(0), 'Épisode Test Résilience');
      await tester.enterText(
          fields.at(1), 'Description complète de l\'épisode.');
      await tester.enterText(
          fields.at(2), 'https://cdn.bamakopodcast.com/ep7.mp3');
      await tester.enterText(fields.at(5), '2');
      await tester.enterText(fields.at(6), '7');

      // 1re tentative de publication -> échoue sur l'association de la source
      final publishBtn = find.text('PUBLIER');
      await tester.ensureVisible(publishBtn);
      await tester.tap(publishBtn);
      await tester.pumpAndSettle();

      // Vérifie que l'épisode a été créé une seule fois avec seasonNumber et episodeNumber
      expect(createEpisodeCalls, 1);
      expect(lastCreatePayload?['seasonNumber'], 2);
      expect(lastCreatePayload?['episodeNumber'], 7);
      expect(attachSourceCalls, 1);
      expect(publishCalls, 0);

      // L'erreur est affichée sous le champ et "Épisode publié" n'est JAMAIS affiché
      expect(
          find.text('Serveur de média temporairement indisponible.'),
          findsWidgets);
      expect(find.text('Épisode publié'), findsNothing);
      expect(find.textContaining('Brouillon conservé'), findsOneWidget);

      // 2e tentative (nouvelle tentative après rétablissement du serveur)
      shouldFailAttachSource = false;
      final retryPublishBtn = find.text('RÉESSAYER & PUBLIER');
      await tester.ensureVisible(retryPublishBtn);
      await tester.tap(retryPublishBtn);
      await tester.pumpAndSettle(const Duration(seconds: 4));

      // Aucun nouvel épisode n'a été créé (createEpisodeCalls == 1), le brouillon existant a été mis à jour via PATCH
      expect(createEpisodeCalls, 1);
      expect(patchEpisodeCalls, 1);
      expect(attachSourceCalls, 2);
      expect(publishCalls, 1);
    });
  });
}
