import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persistance chiffrée du jeton d'accès et du profil utilisateur.
class TokenStorage {
  static const _kToken = 'bko_access_token';
  static const _kUser = 'bko_user';
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static Future<void> save(String token, Map<String, dynamic>? user) async {
    await _storage.write(key: _kToken, value: token);
    if (user == null) {
      await _storage.delete(key: _kUser);
    } else {
      await _storage.write(key: _kUser, value: jsonEncode(user));
    }
  }

  static Future<({String? token, Map<String, dynamic>? user})> load() async {
    final token = await _storage.read(key: _kToken);
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
    return (token: token, user: user);
  }

  static Future<void> clear() => _storage.deleteAll();
}
