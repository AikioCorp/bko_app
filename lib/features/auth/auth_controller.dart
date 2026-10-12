import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  /// vérifié par OTP). Retourne (ok, message d'erreur éventuel, message de confirmation).
  Future<({bool ok, String? error, String? message})> register({
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
      return (ok: true, error: null, message: msg);
    } on ApiException catch (error) {
      return (ok: false, error: error.message, message: null);
    } catch (_) {
      return (
        ok: false,
        error: 'Impossible de contacter le serveur. Vérifiez votre connexion.',
        message: null,
      );
    }
  }

  /// Renvoi d'un code OTP pour un compte non vérifié.
  Future<({bool ok, String? error, String? message})> resendOtp({
    required String email,
  }) async {
    try {
      final data = await BkoApi.post('/auth/register', {
        'email': email,
        'fullName': 'Auditeur',
        'password': 'TemporaryResendPassword123!',
      });
      final msg = data is Map && data['message'] is String
          ? data['message'] as String
          : 'Nouveau code envoyé si le compte existe.';
      return (ok: true, error: null, message: msg);
    } on ApiException catch (error) {
      return (ok: false, error: error.message, message: null);
    } catch (_) {
      return (
        ok: false,
        error: 'Impossible de contacter le serveur.',
        message: null,
      );
    }
  }

  /// Vérification du code OTP reçu après inscription.
  Future<({bool ok, String? error})> verifyOtp({
    required String email,
    required String otpCode,
  }) async {
    try {
      await BkoApi.post('/auth/verify-otp', {
        'email': email,
        'otpCode': otpCode,
      });
      return (ok: true, error: null);
    } on ApiException catch (error) {
      return (ok: false, error: error.message);
    } catch (_) {
      return (
        ok: false,
        error: 'Impossible de contacter le serveur. Vérifiez votre connexion.',
      );
    }
  }

  Future<void> updateUser(Map<String, dynamic> newUser) async {
    if (state.token != null) {
      await TokenStorage.save(state.token!, newUser);
      state = AuthState(
        isAuthenticated: true,
        token: state.token,
        user: newUser,
      );
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
