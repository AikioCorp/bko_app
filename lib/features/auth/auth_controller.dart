import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../core/network/bko_api.dart';
import '../../core/network/bko_telemetry.dart';
import '../../core/storage/token_storage.dart';
import '../../core/routing/app_router.dart';
import '../shell/shell_providers.dart';
import '../downloads/download_manager.dart';
import '../../core/services/push_notification_service.dart';

/// État d'authentification.
///
/// Le token d'accès et le refresh token sont persistés de manière chiffrée via [TokenStorage] (FlutterSecureStorage) :
/// restaurés au démarrage (`_restoreSession`), sauvegardés au login, effacés au logout.
class AuthState {
  final bool isAuthenticated;
  final String? token;
  final String? refreshToken;
  final Map<String, dynamic>? user;
  final bool isLoading;
  final String? error;

  const AuthState({
    this.isAuthenticated = false,
    this.token,
    this.refreshToken,
    this.user,
    this.isLoading = false,
    this.error,
  });

  bool get isCreatorOrAdmin {
    final userMap = user;
    if (userMap == null) return false;
    final roles = (userMap['roles'] as List?)?.map((r) => '$r'.toUpperCase()).toList() ?? [];
    return roles.contains('CREATOR') ||
        roles.contains('ADMIN') ||
        roles.contains('SUPER_ADMIN') ||
        userMap['creatorProfile'] != null;
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final Ref? _ref;
  static bool _isSuspensionHandled = false;

  static void resetSuspensionHandled() {
    _isSuspensionHandled = false;
  }

  AuthNotifier({Ref? ref}) : _ref = ref, super(const AuthState()) {
    BkoApi.tokenRefreshHandler = () async {
      final success = await refreshSession();
      return success ? state.token : null;
    };
    BkoApi.onSessionExpired = () {
      handleSessionExpired();
    };
    BkoApi.onAccountSuspended = (AccountSuspendedException exception) {
      handleAccountSuspended(exception);
    };
    _restoreSession();
  }

  /// Traitement global et immédiat de la suspension de compte
  Future<void> handleAccountSuspended([AccountSuspendedException? exception]) async {
    if (_isSuspensionHandled) return;
    _isSuspensionHandled = true;

    // 1. Fermer la session et effacer les tokens persistés
    await TokenStorage.clear();
    await BkoTelemetryService().onUserSwitched(null);
    state = const AuthState();

    // 2. Arrêter la lecture en cours
    if (_ref != null) {
      try {
        await _ref!.read(activeEpisodeProvider.notifier).stopAndClear();
      } catch (_) {}
      // Annuler les transferts en cours
      try {
        _ref!.read(downloadProvider.notifier).cancelAllActiveDownloads();
      } catch (_) {}
    }

    final Map<String, dynamic> extra = {
      'reason': exception?.reason ?? 'Compte suspendu par l\'administration.',
      'isPermanent': exception?.isPermanent ?? true,
      if (exception?.suspendedAt != null)
        'suspendedAt': exception!.suspendedAt!.toIso8601String(),
      if (exception?.suspendedUntil != null)
        'suspendedUntil': exception!.suspendedUntil!.toIso8601String(),
    };

    try {
      appRouter.go('/suspended', extra: extra);
    } catch (_) {}
  }

  /// Restaure une session persistée au démarrage de l'app et effectue un contrôle serveur réel.
  Future<void> _restoreSession() async {
    final saved = await TokenStorage.load();
    if (saved.token != null) {
      state = AuthState(
        isAuthenticated: true,
        token: saved.token,
        refreshToken: saved.refreshToken,
        user: saved.user,
      );

      // Contrôle réel de validité et de suspension auprès du serveur
      try {
        final me = await BkoApi.get('/me', token: saved.token);
        if (me is Map) {
          state = AuthState(
            isAuthenticated: true,
            token: saved.token,
            refreshToken: saved.refreshToken,
            user: Map<String, dynamic>.from(me),
          );
          PushNotificationService.instance.syncTokenWithBackend(null, authToken: saved.token);
        }
      } on AccountSuspendedException catch (e) {
        await handleAccountSuspended(e);
      } catch (_) {
        // En mode hors-ligne, ne pas bloquer l'accès aux contenus téléchargés
      }
    }
  }

  void clearError() {
    if (state.error != null) {
      state = AuthState(
        isAuthenticated: state.isAuthenticated,
        token: state.token,
        refreshToken: state.refreshToken,
        user: state.user,
        isLoading: state.isLoading,
        error: null,
      );
    }
  }

  Future<({bool ok, String? error, bool isNotVerified})> login(
    String identifier,
    String password,
  ) async {
    AuthNotifier.resetSuspensionHandled();
    state = AuthState(
      isLoading: true,
      token: state.token,
      refreshToken: state.refreshToken,
      user: state.user,
    );

    try {
      final data = await BkoApi.post('/auth/login', {
        'identifier': identifier,
        'password': password,
        'deviceType': 'MOBILE',
        'deviceName': 'Application Flutter',
      });
      if (data is! Map) {
        const err = 'Réponse de connexion invalide du serveur.';
        state = const AuthState(error: err);
        return (ok: false, error: err, isNotVerified: false);
      }
      final user = data['user'] is Map
          ? Map<String, dynamic>.from(data['user'] as Map)
          : null;
      final token = data['accessToken'] as String?;
      final refreshToken = data['refreshToken'] as String?;
      if (token == null || token.isEmpty) {
        const err = 'Connexion incomplète. Réessayez.';
        state = const AuthState(error: err);
        return (ok: false, error: err, isNotVerified: false);
      }
      await TokenStorage.save(token, user, refreshToken: refreshToken);
      await BkoTelemetryService().onUserSwitched(user?['id']?.toString());
      state = AuthState(
        isAuthenticated: true,
        token: token,
        refreshToken: refreshToken,
        user: user,
      );
      PushNotificationService.instance.syncTokenWithBackend(null, authToken: token);
      return (ok: true, error: null, isNotVerified: false);
    } on AccountSuspendedException catch (error) {
      await handleAccountSuspended(error);
      return (ok: false, error: error.message, isNotVerified: false);
    } on ApiException catch (error) {
      final isNotVerified = error.statusCode == 403 ||
          error.message.toLowerCase().contains('non vérifié') ||
          error.message.toLowerCase().contains('otp');
      state = AuthState(error: error.message);
      return (ok: false, error: error.message, isNotVerified: isNotVerified);
    } catch (_) {
      const err = 'Impossible de contacter le serveur. Vérifiez votre connexion.';
      state = const AuthState(error: err);
      return (ok: false, error: err, isNotVerified: false);
    }
  }

  /// Inscription. Ne connecte PAS l'utilisateur (le compte doit d'abord être
  /// Inscription. Ne connecte PAS l'utilisateur (le compte doit d'abord être
  /// vérifié par OTP). Retourne (ok, message d'erreur éventuel, message de confirmation, code otp de test éventuel).
  Future<({bool ok, String? error, String? message, String? otpCode})> register({
    required String fullName,
    required String email,
    required String password,
    String? phoneNumber,
  }) async {
    try {
      final data = await BkoApi.post('/auth/register', {
        'fullName': fullName,
        'email': email,
        'password': password,
        if (phoneNumber != null && phoneNumber.trim().isNotEmpty)
          'phoneNumber': phoneNumber.trim(),
      });
      final msg = data is Map && data['message'] is String
          ? data['message'] as String
          : 'Un code de vérification a été envoyé à votre adresse e-mail.';
      final code = data is Map
          ? (data['testOtpCode'] ?? data['otpCode'])?.toString()
          : null;
      return (ok: true, error: null, message: msg, otpCode: code);
    } on ApiException catch (error) {
      return (ok: false, error: error.message, message: null, otpCode: null);
    } catch (_) {
      return (
        ok: false,
        error: 'Impossible de contacter le serveur. Vérifiez votre connexion.',
        message: null,
        otpCode: null,
      );
    }
  }

  /// Renvoi d'un code OTP pour un compte non vérifié.
  Future<({bool ok, String? error, String? message, String? otpCode})> resendOtp({
    required String email,
  }) async {
    try {
      final data = await BkoApi.post('/auth/resend-otp', {
        'email': email,
      });
      final msg = data is Map && data['message'] is String
          ? data['message'] as String
          : 'Un nouveau code de vérification a été envoyé.';
      final code = data is Map
          ? (data['testOtpCode'] ?? data['otpCode'])?.toString()
          : null;
      return (ok: true, error: null, message: msg, otpCode: code);
    } on ApiException catch (error) {
      return (ok: false, error: error.message, message: null, otpCode: null);
    } catch (_) {
      return (
        ok: false,
        error: 'Impossible de contacter le serveur.',
        message: null,
        otpCode: null,
      );
    }
  }

  /// Vérification du code OTP reçu après inscription.
  /// En cas de succès : le serveur valide le compte et délivre la session mobile.
  /// Flutter persiste la session et connecte l'utilisateur automatiquement.
  Future<({bool ok, String? error, bool onboardingCompleted})> verifyOtp({
    required String email,
    required String otpCode,
  }) async {
    try {
      final data = await BkoApi.post('/auth/verify-otp', {
        'email': email,
        'otpCode': otpCode.trim(),
        'deviceType': 'MOBILE',
        'deviceName': 'Application Flutter',
      });

      if (data is Map) {
        final token = data['accessToken'] as String?;
        final refreshToken = data['refreshToken'] as String?;
        final user = data['user'] is Map
            ? Map<String, dynamic>.from(data['user'] as Map)
            : null;

        if (token == null || token.isEmpty || user == null || user['id'] == null) {
          return (ok: false, error: 'Compte vérifié, mais session non reçue. Connectez-vous pour continuer.', onboardingCompleted: false);
        }
        if (token.isNotEmpty) {
          await TokenStorage.save(token, user, refreshToken: refreshToken);
          await BkoTelemetryService().onUserSwitched(user['id']?.toString());
          state = AuthState(
            isAuthenticated: true,
            token: token,
            refreshToken: refreshToken,
            user: user,
          );
          PushNotificationService.instance.syncTokenWithBackend(null, authToken: token);
        }

        final onboardingDone = user['onboardingCompleted'] == true;
        return (ok: true, error: null, onboardingCompleted: onboardingDone);
      }

      return (ok: false, error: 'Réponse de vérification invalide. Réessayez.', onboardingCompleted: false);
    } on AccountSuspendedException catch (error) {
      await handleAccountSuspended(error);
      return (ok: false, error: error.message, onboardingCompleted: false);
    } on ApiException catch (error) {
      return (ok: false, error: error.message, onboardingCompleted: false);
    } catch (_) {
      return (
        ok: false,
        error: 'Impossible de contacter le serveur. Vérifiez votre connexion.',
        onboardingCompleted: false,
      );
    }
  }

  /// Demande d'un code OTP pour une connexion instantanée sans mot de passe
  Future<({bool ok, String? error, String? message, String? otpCode})> requestOtpLogin({
    required String identifier,
  }) async {
    try {
      final data = await BkoApi.post('/auth/otp-login/send', {
        'identifier': identifier.trim(),
      });
      final msg = data is Map && data['message'] is String
          ? data['message'] as String
          : 'Un code de connexion a été envoyé.';
      final code = data is Map
          ? (data['testOtpCode'] ?? data['otpCode'])?.toString()
          : null;
      return (ok: true, error: null, message: msg, otpCode: code);
    } on AccountSuspendedException catch (error) {
      await handleAccountSuspended(error);
      return (ok: false, error: error.message, message: null, otpCode: null);
    } on ApiException catch (error) {
      return (ok: false, error: error.message, message: null, otpCode: null);
    } catch (_) {
      return (
        ok: false,
        error: 'Impossible de contacter le serveur. Vérifiez votre connexion.',
        message: null,
        otpCode: null,
      );
    }
  }

  /// Validation du code OTP pour connexion instantanée sans mot de passe
  Future<({bool ok, String? error, bool onboardingCompleted})> verifyOtpLogin({
    required String identifier,
    required String otpCode,
  }) async {
    try {
      final data = await BkoApi.post('/auth/otp-login/verify', {
        'identifier': identifier.trim(),
        'otpCode': otpCode.trim(),
        'deviceType': 'MOBILE',
        'deviceName': 'Application Flutter',
      });

      if (data is Map) {
        final token = data['accessToken'] as String?;
        final refreshToken = data['refreshToken'] as String?;
        final user = data['user'] is Map
            ? Map<String, dynamic>.from(data['user'] as Map)
            : null;

        if (token == null || token.isEmpty || user == null || user['id'] == null) {
          return (ok: false, error: 'Connexion réussie mais session invalide.', onboardingCompleted: false);
        }

        await TokenStorage.save(token, user, refreshToken: refreshToken);
        state = AuthState(
          isAuthenticated: true,
          token: token,
          refreshToken: refreshToken,
          user: user,
        );
        PushNotificationService.instance.syncTokenWithBackend(null, authToken: token);

        final onboardingDone = user['onboardingCompleted'] == true;
        return (ok: true, error: null, onboardingCompleted: onboardingDone);
      }
      return (ok: false, error: 'Réponse inattendue du serveur.', onboardingCompleted: false);
    } on AccountSuspendedException catch (error) {
      await handleAccountSuspended(error);
      return (ok: false, error: error.message, onboardingCompleted: false);
    } on ApiException catch (error) {
      return (ok: false, error: error.message, onboardingCompleted: false);
    } catch (_) {
      return (
        ok: false,
        error: 'Impossible de contacter le serveur. Vérifiez votre connexion.',
        onboardingCompleted: false,
      );
    }
  }

  Future<void> updateUser(Map<String, dynamic> newUser) async {
    if (state.token != null) {
      final merged = {
        if (state.user != null) ...state.user!,
        ...newUser,
      };
      await TokenStorage.save(state.token!, merged, refreshToken: state.refreshToken);
      state = AuthState(
        isAuthenticated: true,
        token: state.token,
        refreshToken: state.refreshToken,
        user: merged,
      );
    }
  }

  Future<void> fetchMe() async {
    if (state.token != null) {
      try {
        final res = await BkoApi.get('/me', token: state.token);
        final user = res is Map && res['data'] is Map
            ? Map<String, dynamic>.from(res['data'] as Map)
            : (res is Map ? Map<String, dynamic>.from(res) : null);
        if (user != null) {
          await updateUser(user);
        }
      } catch (_) {}
    }
  }

  Future<({bool ok, String? error, bool onboardingCompleted})> loginWithGoogle() async {
    state = AuthState(
      isLoading: true,
      token: state.token,
      refreshToken: state.refreshToken,
      user: state.user,
    );
    try {
      final googleSignIn = GoogleSignIn.instance;
      await googleSignIn.initialize(
        serverClientId: '336909810836-pqrofnv72svi1te1uak9beimdbe1r3st.apps.googleusercontent.com',
      );

      final GoogleSignInAccount account = await googleSignIn.authenticate();
      final String? idToken = account.authentication.idToken;

      if (idToken == null || idToken.isEmpty) {
        state = AuthState(
          isAuthenticated: state.isAuthenticated,
          token: state.token,
          refreshToken: state.refreshToken,
          user: state.user,
          isLoading: false,
        );
        return (ok: false, error: 'Jeton Google introuvable', onboardingCompleted: false);
      }

      final data = await BkoApi.post('/auth/google', {
        'idToken': idToken,
        'deviceType': 'ANDROID',
        'deviceName': 'Application Android',
      });

      if (data is Map) {
        final token = data['accessToken'] as String?;
        final refreshToken = data['refreshToken'] as String?;
        final user = data['user'] is Map
            ? Map<String, dynamic>.from(data['user'] as Map)
            : null;

        if (token == null || token.isEmpty || user == null || user['id'] == null) {
          state = const AuthState(isAuthenticated: false, error: 'Réponse serveur invalide');
          return (ok: false, error: 'Réponse serveur invalide', onboardingCompleted: false);
        }

        await TokenStorage.save(token, user, refreshToken: refreshToken);
        await BkoTelemetryService().onUserSwitched(user['id']?.toString());
        state = AuthState(
          isAuthenticated: true,
          token: token,
          refreshToken: refreshToken,
          user: user,
        );
        PushNotificationService.instance.syncTokenWithBackend(null, authToken: token);

        final onboardingDone = user['onboardingCompleted'] == true;
        return (ok: true, error: null, onboardingCompleted: onboardingDone);
      }

      state = const AuthState(isAuthenticated: false, error: 'Échec de connexion Google');
      return (ok: false, error: 'Échec de connexion Google', onboardingCompleted: false);
    } on AccountSuspendedException catch (error) {
      await handleAccountSuspended(error);
      return (ok: false, error: error.message, onboardingCompleted: false);
    } on ApiException catch (error) {
      state = AuthState(isAuthenticated: false, error: error.message);
      return (ok: false, error: error.message, onboardingCompleted: false);
    } catch (e) {
      state = const AuthState(isAuthenticated: false, error: 'Erreur lors de la connexion Google');
      return (ok: false, error: 'Erreur lors de la connexion Google : $e', onboardingCompleted: false);
    }
  }

  /// Renouvelle le jeton d'accès de manière transparente via le refresh token.
  Future<bool> refreshSession() async {
    final curRefresh = state.refreshToken;
    if (curRefresh == null || curRefresh.isEmpty) {
      return false;
    }

    try {
      final data = await BkoApi.post('/auth/refresh', {
        'refreshToken': curRefresh,
      });

      if (data is Map) {
        final newAccessToken = data['accessToken'] as String?;
        final newRefreshToken = (data['refreshToken'] as String?) ?? curRefresh;
        if (newAccessToken != null && newAccessToken.isNotEmpty) {
          await TokenStorage.save(
            newAccessToken,
            state.user,
            refreshToken: newRefreshToken,
          );
          state = AuthState(
            isAuthenticated: true,
            token: newAccessToken,
            refreshToken: newRefreshToken,
            user: state.user,
          );
          return true;
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Réinitialise la session locale en cas de session expirée ou révoquée.
  Future<void> handleSessionExpired() async {
    if (state.isAuthenticated || state.token != null) {
      await logout();
    }
  }

  Future<void> logout() async {
    final curToken = state.token;
    try {
      await PushNotificationService.instance.unregisterToken(authToken: curToken);
    } catch (_) {}
    await BkoTelemetryService().onUserSwitched(null);
    await TokenStorage.clear();
    state = const AuthState();
  }
}

final authProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) => AuthNotifier(ref: ref));
