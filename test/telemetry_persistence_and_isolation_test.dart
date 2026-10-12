import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bko_app/core/network/bko_telemetry.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BkoTelemetryService Mobile Real Lifecycle & Isolation Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    test('1. Events survive app restart / disk persistence in SharedPreferences', () async {
      final telemetry = BkoTelemetryService();
      await telemetry.onUserSwitched(null); // clean slate

      // Simuler l'enregistrement d'un événement d'écoute hors ligne
      telemetry.trackListeningEvent(
        sessionId: 'sess_pers_123',
        episodeId: 'ep_test_456',
        eventType: 'progress',
        positionSeconds: 120,
        deltaSeconds: 15,
        playbackRate: 1.0,
        userId: 'user_alice',
      );

      // Vérifier que l'événement a bien été persisté dans SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('bko_offline_telemetry_events_v2');
      expect(raw, isNotNull);

      final list = jsonDecode(raw!) as List;
      expect(list.length, equals(1));
      expect(list[0]['sessionId'], equals('sess_pers_123'));
      expect(list[0]['episodeId'], equals('ep_test_456'));
      expect(list[0]['deltaSeconds'], equals(15));
      expect(list[0]['userId'], equals('user_alice'));
    });

    test('2. Account isolation: logging out or switching to User B purges User A events', () async {
      final telemetry = BkoTelemetryService();

      // Alice enregistre des événements
      await telemetry.trackListeningEvent(
        sessionId: 'sess_alice',
        episodeId: 'ep_alice_1',
        eventType: 'progress',
        positionSeconds: 60,
        deltaSeconds: 15,
        userId: 'user_alice',
      );

      final prefs = await SharedPreferences.getInstance();
      var raw = prefs.getString('bko_offline_telemetry_events_v2');
      var list = jsonDecode(raw!) as List;
      expect(list.any((e) => e['userId'] == 'user_alice'), isTrue);

      // Changement de compte vers Bob
      await telemetry.onUserSwitched('user_bob');

      // Vérifier que la file persistée sur disque ne contient PLUS AUCUN événement d'Alice
      raw = prefs.getString('bko_offline_telemetry_events_v2');
      list = jsonDecode(raw!) as List;
      expect(list.any((e) => e['userId'] == 'user_alice'), isFalse);

      // Bob enregistre son propre événement
      await telemetry.trackListeningEvent(
        sessionId: 'sess_bob',
        episodeId: 'ep_bob_1',
        eventType: 'start',
        positionSeconds: 0,
        userId: 'user_bob',
      );

      raw = prefs.getString('bko_offline_telemetry_events_v2');
      list = jsonDecode(raw!) as List;
      expect(list.length, equals(1));
      expect(list[0]['userId'], equals('user_bob'));

      // Déconnexion complète (null)
      await telemetry.onUserSwitched(null);
      raw = prefs.getString('bko_offline_telemetry_events_v2');
      list = jsonDecode(raw!) as List;
      expect(list.any((e) => e['userId'] == 'user_bob'), isFalse);
    });
  });
}
