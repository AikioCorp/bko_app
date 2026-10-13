
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  const ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

/// Client HTTP unique.
class BkoApi {
  static const String _envBaseUrl = String.fromEnvironment('BKO_API_BASE_URL');

  static String _resolveDefaultBaseUrl() {
    if (_envBaseUrl.isNotEmpty) return _envBaseUrl;
    return 'http://c0mq60vovgz6xkdvi8hkyejk.194.31.52.77.sslip.io/api/v1';
  }

  static String _baseUrl = _resolveDefaultBaseUrl();

  static final Dio _dio = _createDio();

  static Dio _createDio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
        sendTimeout: const Duration(seconds: 20),
        headers: const {'Accept': 'application/json'},
      ),
    );

    if (!kIsWeb) {
      dio.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () {
          final client = HttpClient();
          client.connectionFactory = (Uri uri, String? proxyHost, int? proxyPort) async {
            // Contournement du blocage DNS mobile : si l'hôte est sur sslip.io ou pointe vers le VPS,
            // connecte le socket directement à l'adresse IP 194.31.52.77 sans résolution DNS dépendante de l'opérateur.
            if (uri.host.contains('sslip.io') || uri.host.contains('194.31.52.77')) {
              return Socket.startConnect('194.31.52.77', uri.port);
            }
            return Socket.startConnect(uri.host, uri.port);
          };
          return client;
        },
      );
    }

    return dio;
  }

  static String get baseUrl => _baseUrl;
  static Dio get dio => _dio;
  static Dio createConfiguredDio() => _createDio();

  /// Callback appelé lorsqu'une requête authentifiée expire (401 / SESSION_EXPIRED).
  /// Retourne le nouveau token d'accès après refresh ou `null` si le refresh a échoué.
  static Future<String?> Function()? tokenRefreshHandler;

  /// Callback appelé lorsque la session est irrémédiablement révoquée ou expirée.
  static VoidCallback? onSessionExpired;

  static void setBaseUrl(String url) {
    _baseUrl = url;
    _dio.options.baseUrl = url;
  }

  static String _buildUrl(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    final base = _baseUrl.replaceAll(RegExp(r'/+$'), '');
    final cleanPath = path.replaceAll(RegExp(r'^/+'), '');
    return '$base/$cleanPath';
  }

  static Future<dynamic> get(String path, {String? token}) =>
      _request('GET', path, token: token);

  static Future<dynamic> post(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) =>
      _request('POST', path, body: body, token: token);

  static Future<dynamic> patch(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) =>
      _request('PATCH', path, body: body, token: token);

  static Future<dynamic> delete(
    String path, {
    Map<String, dynamic>? body,
    String? token,
  }) =>
      _request('DELETE', path, body: body, token: token);

  static Future<dynamic> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    String? token,
    bool isRetry = false,
  }) async {
    final fullUrl = _buildUrl(path);
    try {
      final response = await _dio.request<dynamic>(
        fullUrl,
        data: body,
        options: Options(
          method: method,
          headers: {
            if (token != null && token.isNotEmpty)
              'Authorization': 'Bearer $token',
          },
        ),
      );
      final payload = response.data;
      if (payload is Map && payload['success'] == true) {
        return payload['data'];
      }
      final error = payload is Map ? payload['error'] : null;
      final code = error is Map ? error['code']?.toString() : null;
      final message = error is Map && error['message'] is String
          ? error['message'] as String
          : 'Une erreur est survenue. Réessayez dans un instant.';

      if ((response.statusCode == 401 || code == 'SESSION_EXPIRED') &&
          !isRetry &&
          token != null &&
          token.isNotEmpty &&
          tokenRefreshHandler != null &&
          !path.contains('/auth/')) {
        try {
          final newToken = await tokenRefreshHandler!();
          if (newToken != null && newToken.isNotEmpty) {
            return _request(method, path, body: body, token: newToken, isRetry: true);
          }
        } catch (_) {}
        onSessionExpired?.call();
      }

      throw ApiException(message, statusCode: response.statusCode);
    } on DioException catch (error) {
      debugPrint('[BkoApi ERROR] $method $fullUrl -> ${error.type} ${error.message} (status: ${error.response?.statusCode})');
      final payload = error.response?.data;
      final apiError = payload is Map ? payload['error'] : null;
      final code = apiError is Map ? apiError['code']?.toString() : null;
      final statusCode = error.response?.statusCode;
      final isSessionExpired = statusCode == 401 || code == 'SESSION_EXPIRED';

      if (isSessionExpired &&
          !isRetry &&
          token != null &&
          token.isNotEmpty &&
          tokenRefreshHandler != null &&
          !path.contains('/auth/')) {
        try {
          final newToken = await tokenRefreshHandler!();
          if (newToken != null && newToken.isNotEmpty) {
            return _request(method, path, body: body, token: newToken, isRetry: true);
          }
        } catch (_) {}
        onSessionExpired?.call();
      } else if (isSessionExpired && !path.contains('/auth/')) {
        onSessionExpired?.call();
      }

      final message = apiError is Map && apiError['message'] is String
          ? apiError['message'] as String
          : 'Impossible de joindre Bamako Podcast pour le moment.';
      throw ApiException(message, statusCode: statusCode);
    }
  }

  static String? sanitizeMediaUrl(dynamic raw) {
    if (raw == null) return null;
    var str = raw.toString().trim();
    if (str.isEmpty) return null;

    // Unescape HTML entities commonly injected by RSS parsers
    str = str
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');

    if (str.startsWith('http://') ||
        str.startsWith('https://') ||
        str.startsWith('file://')) {
      return str;
    }

    // Relative path support: e.g. /uploads/media/xyz.mp3
    if (str.startsWith('/')) {
      final baseOrigin = _baseUrl.replaceAll(RegExp(r'/api/v\d+/?$'), '');
      return '$baseOrigin$str';
    }

    return null;
  }

  static String? extractAudioUrl(Map<String, dynamic> episode) {
    // 1. Direct fields on episode map
    final direct = episode['audioUrl'] ??
        episode['mediaUrl'] ??
        episode['enclosureUrl'] ??
        episode['fileUrl'] ??
        episode['url'];
    final sanitizedDirect = sanitizeMediaUrl(direct);
    if (sanitizedDirect != null) return sanitizedDirect;

    // 2. Primary audio source object
    final primary = episode['primaryAudioSource'];
    if (primary is Map) {
      final url = primary['externalUrl'] ??
          primary['embedUrl'] ??
          primary['url'] ??
          (primary['mediaAsset'] is Map ? primary['mediaAsset']['url'] : null);
      final sanitized = sanitizeMediaUrl(url);
      if (sanitized != null) return sanitized;
    }

    // 3. Media sources array
    final sources = episode['mediaSources'] ??
        episode['sources'] ??
        episode['media_sources'];
    if (sources is List) {
      // First pass: look for explicit primary audio
      for (final source in sources) {
        if (source is Map && source['isPrimaryAudio'] == true) {
          final url = source['externalUrl'] ??
              source['embedUrl'] ??
              source['url'] ??
              (source['mediaAsset'] is Map ? source['mediaAsset']['url'] : null);
          final sanitized = sanitizeMediaUrl(url);
          if (sanitized != null) return sanitized;
        }
      }
      // Second pass: look for any AUDIO type source
      for (final source in sources) {
        if (source is Map &&
            (source['type'] == 'AUDIO' || source['type'] == null)) {
          final url = source['externalUrl'] ??
              source['embedUrl'] ??
              source['url'] ??
              (source['mediaAsset'] is Map ? source['mediaAsset']['url'] : null);
          final sanitized = sanitizeMediaUrl(url);
          if (sanitized != null) return sanitized;
        }
      }
    }
    return null;
  }

  static String? extractVideoUrl(Map<String, dynamic> episode) {
    // 1. Direct fields on episode map
    final direct = episode['videoUrl'];
    final sanitizedDirect = sanitizeMediaUrl(direct);
    if (sanitizedDirect != null) return sanitizedDirect;

    // 2. Primary video source object
    final primary = episode['primaryVideoSource'];
    if (primary is Map) {
      final url = primary['embedUrl'] ??
          primary['externalUrl'] ??
          primary['url'] ??
          (primary['mediaAsset'] is Map ? primary['mediaAsset']['url'] : null);
      final sanitized = sanitizeMediaUrl(url);
      if (sanitized != null) return sanitized;
    }

    // 3. Media sources array
    final sources = episode['mediaSources'] ??
        episode['sources'] ??
        episode['media_sources'];
    if (sources is List) {
      for (final source in sources) {
        if (source is Map && source['isPrimaryVideo'] == true) {
          final url = source['embedUrl'] ??
              source['externalUrl'] ??
              source['url'] ??
              (source['mediaAsset'] is Map ? source['mediaAsset']['url'] : null);
          final sanitized = sanitizeMediaUrl(url);
          if (sanitized != null) return sanitized;
        }
      }
      for (final source in sources) {
        if (source is Map && source['type'] == 'VIDEO') {
          final url = source['embedUrl'] ??
              source['externalUrl'] ??
              source['url'] ??
              (source['mediaAsset'] is Map ? source['mediaAsset']['url'] : null);
          final sanitized = sanitizeMediaUrl(url);
          if (sanitized != null) return sanitized;
        }
      }
    }
    return null;
  }
}
