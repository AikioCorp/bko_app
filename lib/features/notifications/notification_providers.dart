import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/bko_api.dart';
import '../../core/services/push_notification_service.dart';
import '../auth/auth_controller.dart';

class UnreadNotificationsNotifier extends StateNotifier<int> with WidgetsBindingObserver {
  final Ref ref;
  String? _lastRequestedToken;
  DateTime? _lastFetchTime;
  Timer? _periodicTimer;
  bool _isAppInForeground = true;

  UnreadNotificationsNotifier(this.ref) : super(0) {
    WidgetsBinding.instance.addObserver(this);

    // Écouter les changements de session (connexion, déconnexion, restauration)
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (!next.isAuthenticated || next.token == null) {
        reset();
      } else if (previous?.token != next.token || previous?.isAuthenticated != next.isAuthenticated) {
        fetchCount();
      }
    });

    // Écouter l'arrivée d'un push au premier plan
    PushNotificationService.onForegroundMessageReceived = () {
      if (mounted) {
        fetchCount();
      }
    };

    // Premier chargement si déjà authentifié
    fetchCount();

    // Démarrer la surveillance périodique sobre
    _setupPeriodicRefresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isAppInForeground = state == AppLifecycleState.resumed;

    // Au retour de l'application au premier plan
    if (_isAppInForeground) {
      final now = DateTime.now();
      // Rafraîchir si le dernier appel date de plus de 10 secondes
      if (_lastFetchTime == null || now.difference(_lastFetchTime!).inSeconds > 10) {
        fetchCount();
      }
    }
  }

  void _setupPeriodicRefresh() {
    _periodicTimer?.cancel();
    // Interrogation sobre toutes les 60 secondes uniquement si utilisateur connecté et app active
    _periodicTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (_isAppInForeground && mounted) {
        final auth = ref.read(authProvider);
        if (auth.isAuthenticated && auth.token != null) {
          fetchCount();
        }
      }
    });
  }

  Future<void> fetchCount() async {
    final auth = ref.read(authProvider);
    final currentToken = auth.token;

    if (!auth.isAuthenticated || currentToken == null || currentToken.isEmpty) {
      if (mounted) state = 0;
      return;
    }

    _lastRequestedToken = currentToken;
    _lastFetchTime = DateTime.now();

    try {
      final res = await BkoApi.get('/me/notifications/unread-count', token: currentToken);

      // Protection stricte contre les réponses asynchrones obsolètes :
      // Si l'utilisateur s'est déconnecté ou a changé de compte entre-temps, abandonner la réponse.
      if (!mounted) return;
      final liveAuth = ref.read(authProvider);
      if (liveAuth.token != currentToken || _lastRequestedToken != currentToken) {
        return;
      }

      if (res is Map) {
        final count = res['unread'] ?? res['data']?['unread'];
        if (count is num) {
          state = count.toInt().clamp(0, 999);
          return;
        }
      }
    } catch (_) {
      // Conservation discrète de l'état précédent en cas d'erreur réseau temporaire
    }
  }

  /// Réconciliation directe du compteur lorsque la liste des notifications est chargée.
  void setCount(int count) {
    if (mounted) {
      state = count.clamp(0, 999);
      _lastFetchTime = DateTime.now();
    }
  }

  /// Décrémente immédiatement la pastille localement, puis réconcilie avec le serveur.
  void markAsReadLocally([int count = 1]) {
    if (!mounted) return;
    state = (state - count).clamp(0, 999);
  }

  void reset() {
    _lastRequestedToken = null;
    if (mounted) state = 0;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _periodicTimer?.cancel();
    PushNotificationService.onForegroundMessageReceived = null;
    super.dispose();
  }
}

final unreadNotificationsProvider = StateNotifierProvider<UnreadNotificationsNotifier, int>((ref) {
  return UnreadNotificationsNotifier(ref);
});
