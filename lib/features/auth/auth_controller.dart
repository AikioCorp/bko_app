import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/bko_api.dart';
import '../../core/storage/token_storage.dart';

/// État d'authentification.
///
/// Le token est persisté via [TokenStorage] (shared_preferences) : restauré au
/// démarrage (`_restoreSession`), sauvé au login, effacé au logout.
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
          isAuthenticated: true, token: saved.token, user: saved.user);
    }
  }

  Future<bool> login(String identifier, String password) async {
    state = const AuthState(isLoading: true);

    try {
      final data = await BkoApi.post('/auth/login', {
        'identifier': identifier,
        'password': password,
        'deviceType': 'MOBILE',
        'deviceName': 'Application Flutter',
      });
      if (data is! Map) {
        state = const AuthState(error: 'RÃ©ponse de connexion invalide.');
        return false;
      }
      final user = data['user'] is Map
          ? Map<String, dynamic>.from(data['user'] as Map)
          : null;
      final token = data['accessToken'] as String?;
      if (token == null || token.isEmpty) {
        state = const AuthState(error: 'Connexion incomplÃ¨te. RÃ©essayez.');
        return false;
      }
      await TokenStorage.save(token, user);
      state = AuthState(isAuthenticated: true, token: token, user: user);
      return true;
    } on ApiException catch (error) {
      state = AuthState(error: error.message);
      return false;
    } catch (_) {
      state = const AuthState(error: 'Impossible de contacter le serveur.');
      return false;
    }
  }

  /// Inscription. Ne connecte PAS l'utilisateur (le compte doit d'abord être
  /// vérifié par OTP). Retourne (ok, message d'erreur éventuel).
  Future<({bool ok, String? error})> register({
    required String fullName,
    required String email,
    required String password,
    String? phoneNumber,
  }) async {
    try {
      await BkoApi.post('/auth/register', {
        'fullName': fullName,
        'email': email,
        'password': password,
        if (phoneNumber != null && phoneNumber.trim().isNotEmpty)
          'phoneNumber': phoneNumber.trim(),
      });
      return (ok: true, error: null);
    } on ApiException catch (error) {
      return (ok: false, error: error.message);
    } catch (_) {
      return (ok: false, error: 'Impossible de contacter le serveur.');
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
      return (ok: false, error: 'Impossible de contacter le serveur.');
    }

    // ignore: dead_code
    final res = await BkoApi.post('/auth/verify-otp', {
      'email': email,
      'otpCode': otpCode,
    });
    if (res == null) {
      return (ok: false, error: 'Impossible de contacter le serveur.');
    }
    if (res['success'] == true) return (ok: true, error: null);
    final err = res['error'];
    final msg = err is Map && err['message'] is String
        ? err['message'] as String
        : 'Code invalide ou expiré';
    return (ok: false, error: msg);
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
    await TokenStorage.clear();
    state = const AuthState();
  }
}

final authProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) => AuthNotifier());
