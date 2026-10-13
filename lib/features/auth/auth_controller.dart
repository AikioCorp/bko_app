import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../core/network/bko_api.dart';
import '../../core/network/bko_telemetry.dart';
import '../../core/storage/token_storage.dart';

/// État d'authentification.
///
/// Le token est persisté de manière chiffrée via [TokenStorage] (FlutterSecureStorage) :
/// restauré au démarrage (`_restoreSession`), sauvegardé au login, effacé au logout.
class AuthState {
  final bool isAuthenticated;
  final String? token;
  final Map<String, dynamic>? user;
  final bool isLoading;
  final String? error;

  const AuthState({
    this.isAuthenticated = false,
    this.token,
    this.user,
    this.isLoading = false,
    this.error,
  });
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState()) {
    _restoreSession();
  }

  /// Restaure une session persistée au démarrage de l'app.
  Future<void> _restoreSession() async {
    final saved = await TokenStorage.load();
    if (saved.token != null) {
      state = AuthState(
        isAuthenticated: true,
        token: saved.token,
        user: saved.user,
      );
    }
  }

  void clearError() {
    if (state.error != null) {
      state = AuthState(
        isAuthenticated: state.isAuthenticated,
        token: state.token,
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
    state = AuthState(isLoading: true, token: state.token, user: state.user);

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
      if (token == null || token.isEmpty) {
        const err = 'Connexion incomplète. Réessayez.';
        state = const AuthState(error: err);
        return (ok: false, error: err, isNotVerified: false);
      }
      await TokenStorage.save(token, user);
      await BkoTelemetryService().onUserSwitched(user?['id']?.toString());
      state = AuthState(isAuthenticated: true, token: token, user: user);
      return (ok: true, error: null, isNotVerified: false);
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
        final user = data['user'] is Map
            ? Map<String, dynamic>.from(data['user'] as Map)
            : null;

        if (token == null || token.isEmpty || user == null || user['id'] == null) {
          return (ok: false, error: 'Compte vérifié, mais session non reçue. Connectez-vous pour continuer.', onboardingCompleted: false);
        }
        if (token.isNotEmpty) {
          await TokenStorage.save(token, user);
          await BkoTelemetryService().onUserSwitched(user['id']?.toString());
          state = AuthState(isAuthenticated: true, token: token, user: user);
        }

        final onboardingDone = user['onboardingCompleted'] == true;
        return (ok: true, error: null, onboardingCompleted: onboardingDone);
      }

      return (ok: false, error: 'Réponse de vérification invalide. Réessayez.', onboardingCompleted: false);
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
      await TokenStorage.save(state.token!, merged);
      state = AuthState(
        isAuthenticated: true,
        token: state.token,
        user: merged,
      );
    }
  }

  Future<({bool ok, String? error, bool onboardingCompleted})> loginWithGoogle() async {
    state = AuthState(isLoading: true, token: state.token, user: state.user);
    try {
      final googleSignIn = GoogleSignIn.instance;
      await googleSignIn.initialize(
        serverClientId: '336909810836-pqrofnv72svi1te1uak9beimdbe1r3st.apps.googleusercontent.com',
      );

      final GoogleSignInAccount account = await googleSignIn.authenticate();
      final String? idToken = account.authentication.idToken;

      if (idToken == null || idToken.isEmpty) {
        state = AuthState(isAuthenticated: state.isAuthenticated, token: state.token, user: state.user, isLoading: false);
        return (ok: false, error: 'Jeton Google introuvable', onboardingCompleted: false);
      }

      final data = await BkoApi.post('/auth/google', {
        'idToken': idToken,
        'deviceType': 'ANDROID',
        'deviceName': 'Application Android',
      });

      if (data is Map) {
        final token = data['accessToken'] as String?;
        final user = data['user'] is Map
            ? Map<String, dynamic>.from(data['user'] as Map)
            : null;

        if (token == null || token.isEmpty || user == null || user['id'] == null) {
          state = const AuthState(isAuthenticated: false, error: 'Réponse serveur invalide');
          return (ok: false, error: 'Réponse serveur invalide', onboardingCompleted: false);
        }

        await TokenStorage.save(token, user);
        await BkoTelemetryService().onUserSwitched(user['id']?.toString());
        state = AuthState(isAuthenticated: true, token: token, user: user);

        final onboardingDone = user['onboardingCompleted'] == true;
        return (ok: true, error: null, onboardingCompleted: onboardingDone);
      }

      state = const AuthState(isAuthenticated: false, error: 'Échec de connexion Google');
      return (ok: false, error: 'Échec de connexion Google', onboardingCompleted: false);
    } on ApiException catch (error) {
      state = AuthState(isAuthenticated: false, error: error.message);
      return (ok: false, error: error.message, onboardingCompleted: false);
    } catch (e) {
      state = const AuthState(isAuthenticated: false, error: 'Erreur lors de la connexion Google');
      return (ok: false, error: 'Erreur lors de la connexion Google : $e', onboardingCompleted: false);
    }
  }

  Future<void> logout() async {
    await BkoTelemetryService().onUserSwitched(null);
    await TokenStorage.clear();
    state = const AuthState();
  }
}

final authProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) => AuthNotifier());
