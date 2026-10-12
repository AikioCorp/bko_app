import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'bko_api.dart';

class BkoTelemetryService {
  static final BkoTelemetryService _instance = BkoTelemetryService._internal();
  factory BkoTelemetryService() => _instance;
  BkoTelemetryService._internal() {
    _initPersistence();
  }

  static const String _storageKey = 'bko_offline_telemetry_events_v2';
  final List<Map<String, dynamic>> _pendingListeningEvents = [];
  final Set<String> _recordedImpressionKeys = {};
  Timer? _flushTimer;
  bool _isFlushing = false;
  bool _isInitialized = false;

  Future<void> _initPersistence() async {
    if (_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          _pendingListeningEvents.addAll(
            decoded.map((e) => Map<String, dynamic>.from(e as Map)),
          );
        }
      }
    } catch (_) {}
    _isInitialized = true;
  }

  Future<void> _saveToDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, jsonEncode(_pendingListeningEvents));
    } catch (_) {}
  }

  String generateEventId(String sessionId) {
    final rand = Random().nextInt(999999);
    return 'evt_${sessionId}_${DateTime.now().millisecondsSinceEpoch}_$rand';
  }

  String generateSessionId() {
    final rand = Random().nextInt(999999);
    return 'sess_mob_${DateTime.now().millisecondsSinceEpoch}_$rand';
  }

  /// Appelé lors de la déconnexion ou du changement d'utilisateur
  /// Garantit l'isolation absolue des comptes : aucune télémétrie en attente
  /// de l'ancien compte ne fuira vers le nouveau compte.
  Future<void> onUserSwitched(String? newUserId) async {
    _flushTimer?.cancel();
    _recordedImpressionKeys.clear();
    // Supprimer tout événement n'appartenant pas au nouvel utilisateur
    _pendingListeningEvents.removeWhere(
      (evt) => evt['userId'] != null && evt['userId'] != newUserId,
    );
    await _saveToDisk();
  }

  /// Enregistre un événement de session d'écoute dans la file d'attente persistée
  Future<void> trackListeningEvent({
    required String sessionId,
    required String episodeId,
    required String eventType, // 'start' | 'progress' | 'pause' | 'seek' | 'complete'
    required int positionSeconds,
    int deltaSeconds = 0,
    double playbackRate = 1.0,
    String? recommendationId,
    String? sectionId,
    String? token,
    String? userId,
  }) async {
    if (episodeId.isEmpty || episodeId.startsWith('mock_')) return;

    final clientEventId = generateEventId(sessionId);
    final payload = {
      'clientEventId': clientEventId,
      'sessionId': sessionId,
      'episodeId': episodeId,
      'eventType': eventType,
      'positionSeconds': positionSeconds,
      'deltaSeconds': deltaSeconds,
      'playbackRate': playbackRate,
      'recommendationId': recommendationId,
      'sectionId': sectionId,
      'userId': userId,
      'occurredAtClient': DateTime.now().toIso8601String(),
    };

    _pendingListeningEvents.add(payload);
    await _saveToDisk();

    // Démarrage ou fin : flush immédiat ; progression : par lots
    if (eventType == 'start' || eventType == 'complete' || eventType == 'pause') {
      flushListeningEvents(token: token, currentUserId: userId);
    } else {
      _scheduleFlush(token: token, currentUserId: userId);
    }
  }

  void _scheduleFlush({String? token, String? currentUserId}) {
    _flushTimer?.cancel();
    _flushTimer = Timer(const Duration(seconds: 5), () {
      flushListeningEvents(token: token, currentUserId: currentUserId);
    });
  }

  /// Vide la file d'attente d'événements d'écoute vers le backend en respectant l'isolation de compte
  Future<void> flushListeningEvents({String? token, String? currentUserId}) async {
    if (_isFlushing || _pendingListeningEvents.isEmpty) return;
    _isFlushing = true;

    // Filtrer les événements appartenant au compte actuel ou anonymes
    final eventsToSend = _pendingListeningEvents.where((e) {
      if (currentUserId == null) return e['userId'] == null;
      return e['userId'] == currentUserId || e['userId'] == null;
    }).toList();

    if (eventsToSend.isEmpty) {
      _isFlushing = false;
      return;
    }

    // Retirer temporairement les événements à envoyer
    for (final ev in eventsToSend) {
      _pendingListeningEvents.remove(ev);
    }
    await _saveToDisk();

    try {
      // Envoyer le lot avec les identifiants d'événements uniques (idempotent côté backend)
      await BkoApi.post(
        '/recommendations/events/listening',
        {
          'events': eventsToSend.map((e) {
            final copy = Map<String, dynamic>.from(e);
            copy.remove('userId'); // Ne pas transmettre ce champ interne au payload API
            return copy;
          }).toList(),
        },
        token: token,
      );
    } catch (_) {
      // En cas de perte réseau, réinsérer en tête pour nouvel essai avec les mêmes clientEventId
      _pendingListeningEvents.insertAll(0, eventsToSend);
      await _saveToDisk();
    } finally {
      _isFlushing = false;
    }
  }

  /// Enregistre une impression d'exposition réelle (carte visible >= 50% pendant 1s)
  Future<void> trackImpression({
    required String batchId,
    required String sectionId,
    required String sectionSlug,
    required String targetType, // 'EPISODE' | 'PODCAST'
    required String targetId,
    required int position,
    String? reason,
    String? token,
  }) async {
    final dedupKey = '${batchId}_${sectionId}_${targetType}_${targetId}_$position';
    if (_recordedImpressionKeys.contains(dedupKey)) return;
    _recordedImpressionKeys.add(dedupKey);

    try {
      await BkoApi.post(
        '/recommendations/events/impressions',
        {
          'impressions': [
            {
              'batchId': batchId,
              'sectionId': sectionId,
              'sectionSlug': sectionSlug,
              'targetType': targetType,
              'targetId': targetId,
              'position': position,
              'reason': reason,
              'visibleAt': DateTime.now().toIso8601String(),
            }
          ]
        },
        token: token,
      );
    } catch (_) {}
  }

  /// Enregistre une interaction attribuée à une recommandation (clic ou démarrage lecture)
  Future<void> trackInteraction({
    required String batchId,
    required String sectionId,
    required String sectionSlug,
    required String targetType,
    required String targetId,
    required String action, // 'CLICK' | 'PLAY_START' | 'FAVORITE' | 'LIKE'
    int? position,
    String? token,
  }) async {
    try {
      await BkoApi.post(
        '/recommendations/events/interactions',
        {
          'batchId': batchId,
          'sectionId': sectionId,
          'sectionSlug': sectionSlug,
          'targetType': targetType,
          'targetId': targetId,
          'action': action,
          'position': position,
        },
        token: token,
      );
    } catch (_) {}
  }
}
