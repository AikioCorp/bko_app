import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persistance chiffrée des jetons d'authentification (accès + renouvellement) et du profil utilisateur.
class TokenStorage {
  static const _kToken = 'bko_access_token';
  static const _kRefreshToken = 'bko_refresh_token';
  static const _kUser = 'bko_user';
  static const _storage = FlutterSecureStorage();

  static Future<void> save(
    String token,
    Map<String, dynamic>? user, {
    String? refreshToken,
  }) async {
    await _storage.write(key: _kToken, value: token);
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await _storage.write(key: _kRefreshToken, value: refreshToken);
    }
    if (user == null) {
      await _storage.delete(key: _kUser);
    } else {
      await _storage.write(key: _kUser, value: jsonEncode(user));
    }
  }

  static Future<void> saveTokens({
    required String accessToken,
    String? refreshToken,
  }) async {
    await _storage.write(key: _kToken, value: accessToken);
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await _storage.write(key: _kRefreshToken, value: refreshToken);
    }
  }

  static Future<({String? token, String? refreshToken, Map<String, dynamic>? user})> load() async {
    final token = await _storage.read(key: _kToken);
    final refreshToken = await _storage.read(key: _kRefreshToken);
    final userJson = await _storage.read(key: _kUser);

    Map<String, dynamic>? user;
    if (userJson != null) {
      try {
        final decoded = jsonDecode(userJson);
        if (decoded is Map) user = Map<String, dynamic>.from(decoded);
      } catch (_) {
        await _storage.delete(key: _kUser);
      }
    }
    return (token: token, refreshToken: refreshToken, user: user);
  }

  static Future<void> clear() => _storage.deleteAll();
}
