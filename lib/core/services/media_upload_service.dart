import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../network/bko_api.dart';

class MediaUploadService {
  static final ImagePicker _picker = ImagePicker();

  /// Ouvre le sélecteur pour choisir une image (Caméra ou Galerie).
  /// Compresse à une taille maximale de 1200x1200 avec une qualité de 85%.
  static Future<XFile?> pickImage({required ImageSource source}) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      return picked;
    } catch (e) {
      debugPrint('[MediaUploadService] pickImage error: $e');
      return null;
    }
  }

  /// Téléverse une image vers le stockage Bamako Podcast (Cloudflare R2 / Local Mock)
  /// et retourne l'URL publique finale accessible.
  static Future<String> uploadImage({
    required Uint8List bytes,
    required String mimeType,
    String folder = 'avatars',
    required String token,
  }) async {
    // 1. Demande d'URL de téléversement pré-signée au backend
    final initRes = await BkoApi.post(
      '/media/images/upload-url',
      {
        'mimeType': mimeType,
        'folder': folder,
        'sizeBytes': bytes.length,
      },
      token: token,
    );

    if (initRes is! Map || initRes['uploadUrl'] == null || initRes['publicUrl'] == null) {
      throw const ApiException("Impossible d'obtenir l'autorisation de téléversement.");
    }

    var uploadUrl = initRes['uploadUrl'] as String;
    var publicUrl = initRes['publicUrl'] as String;

    // Résolution d'origine : si le serveur renvoie localhost ou 127.0.0.1 (ex: en dev ou sur VPS sans variable d'hôte),
    // on réécrit le protocole et l'hôte avec ceux de BkoApi.baseUrl afin que le terminal mobile ou émulateur puisse joindre le serveur.
    final apiUri = Uri.tryParse(BkoApi.baseUrl);
    final uploadUri = Uri.tryParse(uploadUrl);
    if (apiUri != null && uploadUri != null) {
      if (uploadUri.host == 'localhost' || uploadUri.host == '127.0.0.1') {
        uploadUrl = uploadUri.replace(
          scheme: apiUri.scheme,
          host: apiUri.host,
          port: apiUri.hasPort ? apiUri.port : (apiUri.scheme == 'https' ? 443 : 80),
        ).toString();
      }
    }

    final pubUri = Uri.tryParse(publicUrl);
    if (apiUri != null && pubUri != null) {
      if (pubUri.host == 'localhost' || pubUri.host == '127.0.0.1') {
        publicUrl = pubUri.replace(
          scheme: apiUri.scheme,
          host: apiUri.host,
          port: apiUri.hasPort ? apiUri.port : (apiUri.scheme == 'https' ? 443 : 80),
        ).toString();
      }
    }

    // 2. Envoi direct des octets vers l'URL pré-signée (Cloudflare R2 / S3)
    final uploadClient = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(minutes: 5),
        receiveTimeout: const Duration(seconds: 30),
      ),
    );

    try {
      final response = await uploadClient.put<dynamic>(
        uploadUrl,
        data: bytes,
        options: Options(
          headers: {
            'Content-Type': mimeType,
            'Content-Length': bytes.length,
          },
        ),
      );

      if (response.statusCode != null &&
          (response.statusCode! < 200 || response.statusCode! >= 300)) {
        throw ApiException(
          'Échec du téléversement vers le serveur de médias (${response.statusCode}).',
        );
      }
    } on DioException catch (dioErr) {
      debugPrint('[MediaUploadService] Direct storage upload failed: $dioErr');
      final code = dioErr.response?.statusCode;
      throw ApiException(
        'Impossible de transférer l\'image vers le serveur de stockage (${code ?? dioErr.type.name}).',
      );
    }

    return publicUrl;
  }
}
