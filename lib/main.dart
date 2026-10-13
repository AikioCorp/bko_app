import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/bko_app.dart';
import 'features/player/bko_audio_handler.dart';
import 'features/shell/shell_providers.dart';

import 'core/services/push_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialisation des Push Notifications (FCM / APNs)
  await PushNotificationService.instance.initialize();

  final audioHandler = await AudioService.init<BkoAudioHandler>(
    builder: BkoAudioHandler.new,
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'studio.bamakopodcast.app.playback',
      androidNotificationChannelName: 'Lecture Bamako Podcast',
    ),
  );
  runApp(
    ProviderScope(
      overrides: [
        audioHandlerProvider.overrideWithValue(audioHandler),
      ],
      child: const BkoPodcastApp(),
    ),
  );
}
