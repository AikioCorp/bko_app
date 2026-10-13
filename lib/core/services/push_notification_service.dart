import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../network/bko_api.dart';
import '../storage/token_storage.dart';

/// Handler d'arrière-plan obligatoire pour FCM (exécuté hors UI).
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Optionnel : logs ou traitement d'arrière-plan
  debugPrint('[PushNotification] Message reçu en background : ${message.messageId}');
}

class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  bool _initialized = false;

  /// Initialise Firebase et le listener de notifications.
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // 1. Initialiser Firebase si disponible
      await Firebase.initializeApp();

      // 2. Déclarer le background handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // 3. Vérifier les permissions existantes SANS afficher de pop-up intempestif au démarrage
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.getNotificationSettings();

      final isAlreadyGranted = settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;

      if (isAlreadyGranted) {
        debugPrint('[PushNotification] Permission déjà accordée : ${settings.authorizationStatus}');

        // 4. Sur iOS : s'assurer que le token APNs est récupéré avant FCM
        if (Platform.isIOS) {
          final apnsToken = await messaging.getAPNSToken();
          debugPrint('[PushNotification] APNs Token : $apnsToken');
        }

        // 5. Récupérer et synchroniser le token FCM si l'utilisateur est connecté
        final fcmToken = await messaging.getToken();
        if (fcmToken != null) {
          await syncTokenWithBackend(fcmToken);
        }
      }

      // 6. Écouter le renouvellement de token
      messaging.onTokenRefresh.listen((newToken) {
        syncTokenWithBackend(newToken);
      });

      // 7. Écouter les notifications reçues lorsque l'application est au premier plan
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('[PushNotification] Reçu au premier plan : ${message.notification?.title}');
      });

      // 8. Écouter le clic d'ouverture de l'application depuis une notification
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('[PushNotification] Clic sur notification : ${message.data}');
      });

      _initialized = true;
    } catch (e) {
      debugPrint('[PushNotification] Initialisation ignorée : $e');
    }
  }

  /// Déclenche la demande de permission système native (iOS / Android 13+)
  /// et synchronise immédiatement le jeton avec le compte utilisateur.
  Future<bool> requestNativePermission() async {
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      final isGranted = settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;

      if (isGranted) {
        if (Platform.isIOS) {
          await messaging.getAPNSToken();
        }
        final fcmToken = await messaging.getToken();
        if (fcmToken != null) {
          await syncTokenWithBackend(fcmToken);
        }
      }
      return isGranted;
    } catch (e) {
      debugPrint('[PushNotification] Erreur requestNativePermission : $e');
      return false;
    }
  }

  /// Envoie le token au backend Bamako Podcast pour lier l'appareil au compte connecté.
  Future<void> syncTokenWithBackend(String token) async {
    try {
      final saved = await TokenStorage.load();
      if (saved.token == null) return; // Utilisateur non connecté

      final deviceType = Platform.isIOS ? 'IOS' : 'ANDROID';
      final deviceName = Platform.isIOS ? 'iPhone' : 'Appareil Android';

      await BkoApi.post(
        '/me/push-token',
        {
          'token': token,
          'deviceType': deviceType,
          'deviceName': deviceName,
        },
        token: saved.token,
      );
      debugPrint('[PushNotification] Token synchronisé avec le backend.');
    } catch (e) {
      debugPrint('[PushNotification] Erreur de synchronisation du token : $e');
    }
  }

  /// Déconnecte le token push du backend lors du logout.
  Future<void> unregisterToken() async {
    try {
      final saved = await TokenStorage.load();
      if (saved.token == null) return;

      final messaging = FirebaseMessaging.instance;
      final fcmToken = await messaging.getToken();
      if (fcmToken != null) {
        await BkoApi.delete(
          '/me/push-token',
          token: saved.token,
          body: {'token': fcmToken},
        );
        debugPrint('[PushNotification] Token supprimé du backend.');
      }
    } catch (_) {}
  }
}
