import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../network/bko_api.dart';

enum MediaTransferStage {
  idle,
  selecting,
  validating,
  uploading,
  processing,
  ready,
  cancelled,
  error,
}

class MediaUploadService {
  static final ImagePicker _picker = ImagePicker();

  static const int maxImageBytes = 10 * 1024 * 1024; // 10 Mo
  static const int maxAudioBytes = 250 * 1024 * 1024; // 250 Mo
  static const int maxVideoBytes = 2000 * 1024 * 1024; // 2 Go

  static const Set<String> allowedImageMimes = {
    'image/jpeg',
    'image/png',
    'image/webp',
    'image/gif',
  };

  static const Set<String> allowedAudioMimes = {
    'audio/mpeg',
    'audio/mp4',
    'audio/x-m4a',
    'audio/wav',
    'audio/x-wav',
  };

  static const Set<String> allowedVideoMimes = {
    'video/mp4',
    'video/quicktime',
  };

  /// Déduit le type MIME d'une image à partir de son nom ou type.
  static String inferImageMimeType(String pathOrName, {String? rawMime}) {
    final cleaned = (rawMime ?? '').toLowerCase().trim();
    if (allowedImageMimes.contains(cleaned)) return cleaned;
    final lower = pathOrName.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }

  /// Déduit le type MIME d'un fichier audio ou vidéo à partir de son nom.
  static String? inferMediaMimeType(String filename, {required String mediaType, String? rawMime}) {
    final cleaned = (rawMime ?? '').toLowerCase().trim();
    if (mediaType == 'AUDIO' && allowedAudioMimes.contains(cleaned)) return cleaned;
    if (mediaType == 'VIDEO' && allowedVideoMimes.contains(cleaned)) return cleaned;

    final lower = filename.toLowerCase();
    if (mediaType == 'AUDIO') {
      if (lower.endsWith('.mp3')) return 'audio/mpeg';
      if (lower.endsWith('.m4a') || lower.endsWith('.mp4')) return 'audio/mp4';
      if (lower.endsWith('.wav')) return 'audio/wav';
      return null;
    } else {
      if (lower.endsWith('.mp4') || lower.endsWith('.m4v')) return 'video/mp4';
      if (lower.endsWith('.mov')) return 'video/quicktime';
      return null;
    }
  }

  /// Ouvre le sélecteur pour choisir une image (Caméra ou Galerie).
  /// Compresse à une taille maximale de 1200x1200 avec une qualité de 85%.
  static Future<XFile?> pickImage({ImageSource source = ImageSource.gallery}) async {
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

  /// Ouvre le sélecteur pour choisir une vidéo depuis la galerie ou la caméra.
  static Future<XFile?> pickVideo({ImageSource source = ImageSource.gallery}) async {
    try {
      return await _picker.pickVideo(source: source);
    } catch (e) {
      debugPrint('[MediaUploadService] pickVideo error: $e');
      return null;
    }
  }

  static String _rewriteLocalStorageUrl(String rawUrl) {
    final apiUri = Uri.tryParse(BkoApi.baseUrl);
    final targetUri = Uri.tryParse(rawUrl);
    if (apiUri != null && targetUri != null) {
      if (targetUri.host == 'localhost' || targetUri.host == '127.0.0.1') {
        return targetUri
            .replace(
              scheme: apiUri.scheme,
              host: apiUri.host,
              port: apiUri.hasPort ? apiUri.port : (apiUri.scheme == 'https' ? 443 : 80),
            )
            .toString();
      }
    }
    return rawUrl;
  }

  /// Téléverse une image vers le stockage Bamako Podcast (Cloudflare R2 / Local Mock)
  /// et retourne l'URL publique finale accessible.
  static Future<String> uploadImage({
    required Uint8List bytes,
    required String mimeType,
    String folder = 'avatars',
    required String token,
    void Function(int sent, int total)? onProgress,
    void Function(MediaTransferStage stage)? onStageChanged,
    CancelToken? cancelToken,
  }) async {
    onStageChanged?.call(MediaTransferStage.validating);

    if (bytes.isEmpty) {
      throw const ApiException('Le fichier image sélectionné est vide.');
    }
    if (bytes.length > maxImageBytes) {
      throw const ApiException('L\'image dépasse la taille maximale autorisée (10 Mo).');
    }
    final normalizedMime = mimeType.toLowerCase().trim();
    if (!allowedImageMimes.contains(normalizedMime)) {
      throw const ApiException('Format d\'image refusé. Utilisez JPEG, PNG, WebP ou GIF.');
    }

    // 1. Demande d'URL de téléversement pré-signée au backend
    final initRes = await BkoApi.post(
      '/media/images/upload-url',
      {
        'mimeType': normalizedMime,
        'folder': folder,
        'sizeBytes': bytes.length,
      },
      token: token,
    );

    if (initRes is! Map || initRes['uploadUrl'] == null || initRes['publicUrl'] == null) {
      throw const ApiException("Impossible d'obtenir l'autorisation de téléversement.");
    }

    final uploadUrl = _rewriteLocalStorageUrl('${initRes['uploadUrl']}');
    final publicUrl = _rewriteLocalStorageUrl('${initRes['publicUrl']}');

    // 2. Envoi direct des octets vers l'URL pré-signée avec le client configuré (compatible sslip.io)
    onStageChanged?.call(MediaTransferStage.uploading);
    final uploadClient = BkoApi.createConfiguredDio();
    uploadClient.options
      ..baseUrl = ''
      ..connectTimeout = const Duration(seconds: 30)
      ..sendTimeout = const Duration(minutes: 5)
      ..receiveTimeout = const Duration(seconds: 60);

    try {
      final response = await uploadClient.put<dynamic>(
        uploadUrl,
        data: bytes,
        cancelToken: cancelToken,
        onSendProgress: onProgress,
        options: Options(
          headers: {
            'Content-Type': normalizedMime,
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
      if (CancelToken.isCancel(dioErr)) {
        onStageChanged?.call(MediaTransferStage.cancelled);
        throw const ApiException('Téléversement annulé.');
      }
      debugPrint('[MediaUploadService] Direct storage upload failed: $dioErr');
      final code = dioErr.response?.statusCode;
      throw ApiException(
        'Impossible de transférer l\'image vers le serveur de stockage (${code ?? dioErr.type.name}).',
      );
    }

    onStageChanged?.call(MediaTransferStage.ready);
    return publicUrl;
  }

  /// Téléverse un fichier média (AUDIO ou VIDEO) rattaché à un épisode via une session d'upload complète :
  /// Sélection → Validation → Transfert (progression mesurable) → Traitement serveur → Prêt.
  static Future<Map<String, dynamic>> uploadMediaAsset({
    required Uint8List bytes,
    required String originalFilename,
    required String mimeType,
    required String mediaType, // 'AUDIO' | 'VIDEO'
    required String episodeId,
    required String token,
    void Function(int sent, int total)? onProgress,
    void Function(MediaTransferStage stage)? onStageChanged,
    CancelToken? cancelToken,
  }) async {
    onStageChanged?.call(MediaTransferStage.validating);

    if (bytes.isEmpty) {
      throw const ApiException('Le fichier sélectionné est vide.');
    }

    final normalizedMime = inferMediaMimeType(
      originalFilename,
      mediaType: mediaType,
      rawMime: mimeType,
    );
    if (normalizedMime == null) {
      throw ApiException(
        mediaType == 'AUDIO'
            ? 'Format audio refusé. Utilisez MP3, M4A ou WAV.'
            : 'Format vidéo refusé. Utilisez MP4 ou MOV.',
      );
    }

    if (mediaType == 'AUDIO' && bytes.length > maxAudioBytes) {
      throw const ApiException('Le fichier audio dépasse la limite de 250 Mo.');
    }
    if (mediaType == 'VIDEO' && bytes.length > maxVideoBytes) {
      throw const ApiException('Le fichier vidéo dépasse la limite de 2 Go.');
    }

    // 1. Créer la session d'upload
    final sessionRes = await BkoApi.post(
      '/creator/uploads',
      {
        'originalFilename': originalFilename,
        'mimeType': normalizedMime,
        'sizeBytes': bytes.length,
        'mediaType': mediaType,
        'episodeId': episodeId,
      },
      token: token,
    );

    if (sessionRes is! Map ||
        sessionRes['uploadSessionId'] == null ||
        sessionRes['uploadUrl'] == null) {
      throw const ApiException("Impossible d'initialiser la session de téléversement.");
    }

    final uploadSessionId = '${sessionRes['uploadSessionId']}';
    final uploadUrl = _rewriteLocalStorageUrl('${sessionRes['uploadUrl']}');

    // 2. Transférer le fichier avec délai adapté aux fichiers volumineux
    onStageChanged?.call(MediaTransferStage.uploading);
    final uploadClient = BkoApi.createConfiguredDio();
    uploadClient.options
      ..baseUrl = ''
      ..connectTimeout = const Duration(seconds: 30)
      ..sendTimeout = const Duration(minutes: 30)
      ..receiveTimeout = const Duration(minutes: 5);

    try {
      final putRes = await uploadClient.put<dynamic>(
        uploadUrl,
        data: bytes,
        cancelToken: cancelToken,
        onSendProgress: onProgress,
        options: Options(
          headers: {
            'Content-Type': normalizedMime,
            'Content-Length': bytes.length,
          },
        ),
      );

      if (putRes.statusCode != null &&
          (putRes.statusCode! < 200 || putRes.statusCode! >= 300)) {
        throw ApiException(
          'Le transfert vers le stockage a échoué (HTTP ${putRes.statusCode}).',
        );
      }
    } on DioException catch (dioErr) {
      if (CancelToken.isCancel(dioErr)) {
        onStageChanged?.call(MediaTransferStage.cancelled);
        throw const ApiException('Transfert annulé.');
      }
      final code = dioErr.response?.statusCode;
      throw ApiException(
        'Échec du transfert média vers le serveur (${code ?? dioErr.type.name}). Vérifiez votre connexion et réessayez.',
      );
    }

    // 3. Confirmer la fin du transfert et lancer le traitement serveur
    onStageChanged?.call(MediaTransferStage.processing);
    final completeRes = await BkoApi.post(
      '/creator/uploads/$uploadSessionId/complete',
      {},
      token: token,
    );

    // 4. Suivre l'état réel du traitement serveur (PROCESSING -> READY ou FAILED)
    for (int attempt = 0; attempt < 25; attempt++) {
      if (cancelToken?.isCancelled == true) {
        onStageChanged?.call(MediaTransferStage.cancelled);
        throw const ApiException('Opération annulée.');
      }
      await Future<void>.delayed(const Duration(seconds: 2));
      final statusRes = await BkoApi.get(
        '/creator/uploads/$uploadSessionId',
        token: token,
      );
      if (statusRes is Map) {
        final asset = statusRes['mediaAsset'];
        if (asset is Map) {
          final assetStatus = '${asset['status'] ?? ''}';
          if (assetStatus == 'READY') {
            onStageChanged?.call(MediaTransferStage.ready);
            return Map<String, dynamic>.from(statusRes);
          }
          if (assetStatus == 'FAILED') {
            onStageChanged?.call(MediaTransferStage.error);
            throw const ApiException(
              'Le traitement du fichier a échoué (format illisible ou corrompu).',
            );
          }
        }
      }
    }

    onStageChanged?.call(MediaTransferStage.ready);
    return completeRes is Map
        ? Map<String, dynamic>.from(completeRes)
        : <String, dynamic>{'uploadSessionId': uploadSessionId, 'status': 'PROCESSING'};
  }
}
