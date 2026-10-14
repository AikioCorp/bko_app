import 'dart:async';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import '../network/bko_api.dart';
import '../routing/app_router.dart';
import '../storage/token_storage.dart';
import '../widgets/bko_notification_toast.dart';
import '../../features/notifications/services/notification_destination_handler.dart';

/// Handler d'arrière-plan obligatoire pour FCM (exécuté dans un isolat séparé).
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[PushNotification] Message reçu en arrière-plan : ${message.messageId}');
}

class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  bool _initialized = false;
  bool _listenersAttached = false;
  String? _cachedFcmToken;

  /// Callback notifié lorsqu'un message push arrive en premier plan.
  static VoidCallback? onForegroundMessageReceived;

  /// Clé globale de contexte pour afficher les toasts au premier plan.
  static BuildContext? get _currentContext => appRouter.routerDelegate.navigatorKey.currentContext;

  /// Initialise Firebase et configure les écouteurs de notifications.
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // 1. Initialiser Firebase si ce n'est pas déjà fait
      await Firebase.initializeApp();

      // 2. Déclarer le background handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      final messaging = FirebaseMessaging.instance;

      // 3. Gestion du clic qui démarre l'application fermée (Cold Start)
      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        final route = _extractRoute(initialMessage);
        if (route != null && route.isNotEmpty) {
          debugPrint('[PushNotification] Démarrage à froid via notification : $route');
          NotificationDestinationHandler.setPendingDestination(route);
        }
      }

      // 4. Attacher les écouteurs d'événements Firebase (une seule fois)
      if (!_listenersAttached) {
        // Renouvellement du token FCM
        messaging.onTokenRefresh.listen((newToken) {
          debugPrint('[PushNotification] Token FCM renouvelé.');
          _cachedFcmToken = newToken;
          syncTokenWithBackend(newToken);
        });

        // Réception au premier plan (Foreground)
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          debugPrint('[PushNotification] Message reçu au premier plan : ${message.notification?.title}');

          // Notifier les écouteurs de l'app (ex. actualiser le compteur de pastille)
          onForegroundMessageReceived?.call();

          // Afficher une bannière in-app élégante et discrète
          final context = _currentContext;
          if (context != null && context.mounted) {
            final title = message.notification?.title ?? 'Nouvelle notification';
            final body = message.notification?.body;
            final route = _extractRoute(message);

            BkoNotificationToast.show(
              context,
              title: title,
              body: body,
              destination: route,
            );
          }
        });

        // Clic sur notification lorsque l'application était en arrière-plan
        FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
          final route = _extractRoute(message);
          debugPrint('[PushNotification] Clic notification arrière-plan : $route');
          if (route != null && route.isNotEmpty) {
            final context = _currentContext;
            if (context != null && context.mounted) {
              NotificationDestinationHandler.navigate(context, route);
            } else {
              NotificationDestinationHandler.setPendingDestination(route);
            }
          }
        });

        _listenersAttached = true;
      }

      // 5. Vérifier les autorisations existantes sans pop-up intempestif
      final settings = await messaging.getNotificationSettings();
      final isAlreadyGranted = settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;

      if (isAlreadyGranted) {
        if (Platform.isIOS) {
          await messaging.getAPNSToken();
        }
        final token = await messaging.getToken();
        if (token != null) {
          _cachedFcmToken = token;
          await syncTokenWithBackend(token);
        }
      }

      _initialized = true;
    } catch (e) {
      debugPrint('[PushNotification] Initialisation Firebase ignorée ou indisponible : $e');
    }
  }

  /// Déclenche la demande de permission système native (iOS / Android 13+)
  /// et synchronise immédiatement le jeton avec le compte utilisateur connecté.
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
          _cachedFcmToken = fcmToken;
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
  Future<bool> syncTokenWithBackend(String? token, {String? authToken}) async {
    final effectiveToken = token ?? _cachedFcmToken;
    if (effectiveToken == null || effectiveToken.isEmpty) return false;
    _cachedFcmToken = effectiveToken;

    try {
      final tokenToUse = authToken ?? (await TokenStorage.load()).token;
      if (tokenToUse == null || tokenToUse.isEmpty) {
        // Utilisateur non connecté : le jeton est mis en mémoire pour synchronisation à la connexion
        return false;
      }

      final deviceType = Platform.isIOS ? 'IOS' : 'ANDROID';
      final deviceName = Platform.isIOS ? 'iPhone' : 'Appareil Android';

      final res = await BkoApi.post(
        '/me/push-token',
        {
          'token': effectiveToken,
          'deviceType': deviceType,
          'deviceName': deviceName,
        },
        token: tokenToUse,
      );

      if (res is Map && res['registered'] == true) {
        debugPrint('[PushNotification] Token synchronisé avec succès auprès du serveur.');
        return true;
      } else {
        debugPrint('[PushNotification] Avertissement : serveur a renvoyé ${res?.toString()}');
        return false;
      }
    } catch (e) {
      debugPrint('[PushNotification] Échec synchronisation token : $e');
      return false;
    }
  }

  /// Désassocie le token push du backend lors du logout ou du changement de compte.
  Future<void> unregisterToken({String? authToken}) async {
    final effectiveToken = _cachedFcmToken;
    if (effectiveToken == null) return;

    try {
      final tokenToUse = authToken ?? (await TokenStorage.load()).token;
      if (tokenToUse == null) return;

      await BkoApi.delete(
        '/me/push-token',
        token: tokenToUse,
        body: {'token': effectiveToken},
      );
      debugPrint('[PushNotification] Token désassocié du compte avec succès.');
    } catch (e) {
      debugPrint('[PushNotification] Erreur lors de la désinscription du push token : $e');
    }
  }

  /// Extrait le lien ou la route d'un message FCM.
  String? _extractRoute(RemoteMessage message) {
    final data = message.data;
    final route = data['route'] ?? data['link'] ?? data['path'];
    if (route != null && route.toString().trim().isNotEmpty) {
      return route.toString().trim();
    }
    return null;
  }
}
