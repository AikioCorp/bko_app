
import 'package:dio/dio.dart';

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

  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
      headers: const {'Accept': 'application/json'},
    ),
  );

  static String get baseUrl => _baseUrl;

  static void setBaseUrl(String url) {
    _baseUrl = url;
    _dio.options.baseUrl = url;
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

  static Future<dynamic> delete(String path, {String? token}) =>
      _request('DELETE', path, token: token);

  static Future<dynamic> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    String? token,
  }) async {
    try {
      final response = await _dio.request<dynamic>(
        path,
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
      final message = error is Map && error['message'] is String
          ? error['message'] as String
          : 'Une erreur est survenue. Réessayez dans un instant.';
      throw ApiException(message, statusCode: response.statusCode);
    } on DioException catch (error) {
      final payload = error.response?.data;
      final apiError = payload is Map ? payload['error'] : null;
      final message = apiError is Map && apiError['message'] is String
          ? apiError['message'] as String
          : 'Impossible de joindre Bamako Podcast pour le moment.';
      throw ApiException(message, statusCode: error.response?.statusCode);
    }
  }

  static String? extractAudioUrl(Map<String, dynamic> episode) {
    final primary = episode['primaryAudioSource'];
    if (primary is Map) {
      final url = primary['externalUrl'] ?? primary['embedUrl'];
      if (url is String && url.startsWith('http')) return url;
    }
    final sources = episode['mediaSources'];
    if (sources is List) {
      Map<String, dynamic>? pick;
      for (final source in sources) {
        if (source is Map &&
            (source['isPrimaryAudio'] == true || source['type'] == 'AUDIO')) {
          pick = Map<String, dynamic>.from(source);
          if (source['isPrimaryAudio'] == true) break;
        }
      }
      final asset = pick?['mediaAsset'];
      final url = pick?['externalUrl'] ??
          pick?['embedUrl'] ??
          (asset is Map ? asset['url'] : null);
      if (url is String && url.startsWith('http')) return url;
    }
    return null;
  }

  static String? extractVideoUrl(Map<String, dynamic> episode) {
    final primary = episode['primaryVideoSource'];
    if (primary is Map) {
      final url = primary['embedUrl'] ?? primary['externalUrl'];
      if (url is String && url.startsWith('http')) return url;
    }
    final sources = episode['mediaSources'];
    if (sources is List) {
      Map<String, dynamic>? pick;
      for (final source in sources) {
        if (source is Map &&
            (source['isPrimaryVideo'] == true || source['type'] == 'VIDEO')) {
          pick = Map<String, dynamic>.from(source);
          if (source['isPrimaryVideo'] == true) break;
        }
      }
      final asset = pick?['mediaAsset'];
      final url = pick?['embedUrl'] ??
          pick?['externalUrl'] ??
          (asset is Map ? asset['url'] : null);
      if (url is String && url.startsWith('http')) return url;
    }
    return null;
  }
}
