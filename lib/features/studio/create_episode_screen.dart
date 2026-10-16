import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/network/bko_api.dart';
import '../../core/services/media_upload_service.dart';
import '../../core/theme/bko_theme.dart';
import '../../core/utils/youtube_url_parser.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/widgets/app_header_actions.dart';
import '../../core/widgets/bko_bounceable.dart';
import '../../core/widgets/bko_haptics.dart';
import '../../core/widgets/bko_toast.dart';
import '../auth/auth_controller.dart';

class CreateEpisodeScreen extends ConsumerStatefulWidget {
  final String? initialPodcastId;
  const CreateEpisodeScreen({super.key, this.initialPodcastId});

  @override
  ConsumerState<CreateEpisodeScreen> createState() =>
      _CreateEpisodeScreenState();
}

class _CreateEpisodeScreenState extends ConsumerState<CreateEpisodeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _audioUrlController = TextEditingController();
  final _videoUrlController = TextEditingController();
  final _coverUrlController = TextEditingController();
  final _seasonController = TextEditingController();
  final _episodeNumController = TextEditingController();

  List<dynamic> _podcasts = [];
  String? _selectedPodcastId;
  String _mediaType = 'AUDIO'; // AUDIO or VIDEO
  bool _loadingPodcasts = true;
  bool _submitting = false;

  // Conservation du brouillon et des sources déjà rattachées en cas d'échec partiel
  String? _createdEpisodeId;
  String? _attachedAudioUrl;
  String? _attachedVideoUrl;
  bool _uploadedVideoReady = false;

  // Téléversement de pochette
  MediaTransferStage _coverStage = MediaTransferStage.idle;
  double _coverProgress = 0.0;
  CancelToken? _coverCancelToken;

  // Téléversement de fichier vidéo natif
  Uint8List? _selectedVideoBytes;
  String? _selectedVideoName;
  String? _selectedVideoMime;
  MediaTransferStage _videoUploadStage = MediaTransferStage.idle;
  double _videoUploadProgress = 0.0;
  CancelToken? _videoCancelToken;

  // Erreurs par champ et erreur globale
  String? _podcastError;
  String? _titleError;
  String? _descriptionError;
  String? _audioError;
  String? _videoError;
  String? _coverError;
  String? _seasonError;
  String? _episodeNumError;
  String? _generalError;

  @override
  void initState() {
    super.initState();
    _fetchPodcasts();
  }

  @override
  void dispose() {
    _coverCancelToken?.cancel();
    _videoCancelToken?.cancel();
    _titleController.dispose();
    _descriptionController.dispose();
    _audioUrlController.dispose();
    _videoUrlController.dispose();
    _coverUrlController.dispose();
    _seasonController.dispose();
    _episodeNumController.dispose();
    super.dispose();
  }

  Future<void> _fetchPodcasts() async {
    final auth = ref.read(authProvider);
    if (!auth.isAuthenticated || auth.token == null) {
      if (mounted) setState(() => _loadingPodcasts = false);
      return;
    }
    try {
      final list = await BkoApi.get('/creator/podcasts', token: auth.token);
      if (!mounted) return;
      setState(() {
        _podcasts = (list is List)
            ? list
            : (list is Map && list['data'] is List
                ? list['data'] as List
                : <dynamic>[]);
        if (_podcasts.isNotEmpty) {
          _selectedPodcastId =
              _podcasts.any((p) => '${p['id']}' == widget.initialPodcastId)
                  ? widget.initialPodcastId
                  : '${_podcasts.first['id']}';
        }
        _loadingPodcasts = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingPodcasts = false;
          _generalError = e is ApiException
              ? e.message
              : 'Impossible de charger vos émissions.';
        });
      }
    }
  }

  bool _isValidHttpUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null) return false;
    if (uri.scheme != 'http' && uri.scheme != 'https') return false;
    if (uri.host.isEmpty || !uri.host.contains('.')) return false;
    return true;
  }

  String? _validateAudioSourceUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    if (!_isValidHttpUrl(trimmed)) {
      return 'Saisissez une adresse http(s) valide vers votre fichier audio.';
    }
    if (YoutubeUrlParser.isDeceptiveYoutubeDomain(trimmed) ||
        YoutubeUrlParser.isYoutubeDomain(trimmed)) {
      return 'Les liens YouTube sont des vidéos : renseignez ce lien dans le champ Vidéo.';
    }
    return null;
  }

  String? _validateVideoSourceUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    if (!_isValidHttpUrl(trimmed)) {
      return 'Saisissez une adresse http(s) valide (YouTube ou fichier MP4/MOV).';
    }
    if (YoutubeUrlParser.isDeceptiveYoutubeDomain(trimmed)) {
      return 'Ce domaine contient « youtube » mais n’est pas un domaine officiel YouTube.';
    }
    if (YoutubeUrlParser.isYoutubeDomain(trimmed)) {
      final videoId = YoutubeUrlParser.tryParseVideoId(trimmed);
      if (videoId == null) {
        if (YoutubeUrlParser.isYoutubeChannelInput(trimmed)) {
          return 'Ce lien pointe vers une chaîne YouTube. Utilisez l’import de chaîne du Studio ou saisissez le lien d’une vidéo.';
        }
        return 'Lien vidéo YouTube invalide (formats acceptés : watch?v=, youtu.be/, shorts/, live/, embed/).';
      }
    }
    return null;
  }

  bool _validateAllFields({required bool isDraft}) {
    String? podcastErr;
    String? titleErr;
    String? descErr;
    String? audioErr;
    String? videoErr;
    String? coverErr;
    String? seasonErr;
    String? epNumErr;

    if (_selectedPodcastId == null || _selectedPodcastId!.isEmpty) {
      podcastErr = 'Veuillez sélectionner une émission.';
    }

    final title = _titleController.text.trim();
    if (title.isEmpty) {
      titleErr = 'Le titre de l’épisode est obligatoire.';
    } else if (title.toLowerCase() == 'nouvel épisode') {
      titleErr = 'Veuillez choisir un titre distinct de « Nouvel épisode ».';
    }

    final description = _descriptionController.text.trim();
    if (description.isEmpty) {
      descErr = 'La description est obligatoire.';
    }

    final audioUrl = _audioUrlController.text.trim();
    final videoUrl = _videoUrlController.text.trim();
    final coverUrl = _coverUrlController.text.trim();
    final seasonRaw = _seasonController.text.trim();
    final epNumRaw = _episodeNumController.text.trim();

    audioErr = _validateAudioSourceUrl(audioUrl);
    videoErr = _validateVideoSourceUrl(videoUrl);

    if (coverUrl.isNotEmpty && !_isValidHttpUrl(coverUrl)) {
      coverErr = 'L’URL de la pochette doit être une adresse http(s) valide.';
    }

    if (seasonRaw.isNotEmpty) {
      final s = int.tryParse(seasonRaw);
      if (s == null || s <= 0) {
        seasonErr = 'Numéro de saison invalide (entier positif requis).';
      }
    }

    if (epNumRaw.isNotEmpty) {
      final n = int.tryParse(epNumRaw);
      if (n == null || n <= 0) {
        epNumErr = 'Numéro d’épisode invalide (entier positif requis).';
      }
    }

    final hasAudioSource = audioUrl.isNotEmpty;
    final hasVideoSource = videoUrl.isNotEmpty ||
        _selectedVideoBytes != null ||
        _uploadedVideoReady;

    if (!isDraft) {
      if (_coverStage == MediaTransferStage.uploading ||
          _videoUploadStage == MediaTransferStage.uploading ||
          _videoUploadStage == MediaTransferStage.processing) {
        _generalError =
            'Un transfert ou traitement média est encore en cours. Patientez jusqu’à l’état « Prêt » avant de publier.';
      }
      if (_mediaType == 'AUDIO' && !hasAudioSource) {
        audioErr ??=
            'Une source audio principale est obligatoire pour publier un épisode Audio.';
      } else if (_mediaType == 'VIDEO' && !hasVideoSource) {
        videoErr ??=
            'Une source vidéo principale (lien YouTube/MP4 ou fichier vidéo) est obligatoire pour publier un épisode Vidéo.';
      }
    }

    setState(() {
      _podcastError = podcastErr;
      _titleError = titleErr;
      _descriptionError = descErr;
      _audioError = audioErr;
      _videoError = videoErr;
      _coverError = coverErr;
      _seasonError = seasonErr;
      _episodeNumError = epNumErr;
    });

    return podcastErr == null &&
        titleErr == null &&
        descErr == null &&
        audioErr == null &&
        videoErr == null &&
        coverErr == null &&
        seasonErr == null &&
        epNumErr == null;
  }

  Future<void> _pickAndUploadCover() async {
    final auth = ref.read(authProvider);
    if (!auth.isAuthenticated || auth.token == null) return;

    setState(() {
      _coverError = null;
      _coverStage = MediaTransferStage.selecting;
    });

    final file = await MediaUploadService.pickImage(source: ImageSource.gallery);
    if (file == null) {
      if (mounted) setState(() => _coverStage = MediaTransferStage.idle);
      return;
    }

    try {
      final bytes = await file.readAsBytes();
      final mime = MediaUploadService.inferImageMimeType(
        file.name.isNotEmpty ? file.name : file.path,
        rawMime: file.mimeType,
      );
      _coverCancelToken?.cancel();
      _coverCancelToken = CancelToken();

      final publicUrl = await MediaUploadService.uploadImage(
        bytes: bytes,
        mimeType: mime,
        folder: 'covers',
        token: auth.token!,
        cancelToken: _coverCancelToken,
        onStageChanged: (stage) {
          if (mounted) setState(() => _coverStage = stage);
        },
        onProgress: (sent, total) {
          if (mounted && total > 0) {
            setState(() => _coverProgress = sent / total);
          }
        },
      );

      if (!mounted) return;
      setState(() {
        _coverUrlController.text = publicUrl;
        _coverStage = MediaTransferStage.ready;
        _coverProgress = 1.0;
      });
      BkoHaptics.light();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (_coverStage != MediaTransferStage.cancelled) {
          _coverStage = MediaTransferStage.error;
          _coverError = e is ApiException
              ? e.message
              : 'Échec du téléversement de la pochette.';
        }
      });
    }
  }

  Future<void> _pickLocalVideoFile() async {
    setState(() {
      _videoError = null;
      _videoUploadStage = MediaTransferStage.selecting;
    });

    final file = await MediaUploadService.pickVideo(source: ImageSource.gallery);
    if (file == null) {
      if (mounted) setState(() => _videoUploadStage = MediaTransferStage.idle);
      return;
    }

    try {
      final bytes = await file.readAsBytes();
      final name = file.name.isNotEmpty ? file.name : 'video.mp4';
      final mime = MediaUploadService.inferMediaMimeType(
        name,
        mediaType: 'VIDEO',
        rawMime: file.mimeType,
      );
      if (mime == null) {
        setState(() {
          _videoUploadStage = MediaTransferStage.error;
          _videoError = 'Format vidéo refusé. Utilisez un fichier MP4 ou MOV.';
        });
        return;
      }
      if (bytes.length > MediaUploadService.maxVideoBytes) {
        setState(() {
          _videoUploadStage = MediaTransferStage.error;
          _videoError = 'Le fichier vidéo dépasse la limite autorisée (2 Go).';
        });
        return;
      }

      if (!mounted) return;
      setState(() {
        _selectedVideoBytes = bytes;
        _selectedVideoName = name;
        _selectedVideoMime = mime;
        _uploadedVideoReady = false;
        _videoUploadStage = MediaTransferStage.validating;
        _videoUploadProgress = 0.0;
      });
      BkoHaptics.light();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _videoUploadStage = MediaTransferStage.error;
        _videoError = 'Impossible de lire le fichier vidéo sélectionné.';
      });
    }
  }

  Future<void> _submit({bool isDraft = false}) async {
    if (_submitting) return;
    setState(() => _generalError = null);

    if (!_validateAllFields(isDraft: isDraft)) {
      BkoHaptics.light();
      return;
    }

    final auth = ref.read(authProvider);
    if (!auth.isAuthenticated || auth.token == null) return;

    setState(() => _submitting = true);

    try {
      final seasonNum = int.tryParse(_seasonController.text.trim());
      final epNum = int.tryParse(_episodeNumController.text.trim());
      final coverUrl = _coverUrlController.text.trim();

      final body = <String, dynamic>{
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        if (coverUrl.isNotEmpty) 'cover': coverUrl,
        if (seasonNum != null && seasonNum > 0) 'seasonNumber': seasonNum,
        if (epNum != null && epNum > 0) 'episodeNumber': epNum,
      };

      // 1. Créer le brouillon OU mettre à jour le brouillon déjà créé lors d'une tentative précédente
      String? episodeId = _createdEpisodeId;
      if (episodeId == null) {
        final episodeRes = await BkoApi.post(
          '/creator/podcasts/$_selectedPodcastId/episodes',
          body,
          token: auth.token,
        );
        episodeId = episodeRes is Map
            ? '${episodeRes['id'] ?? (episodeRes['data'] is Map ? episodeRes['data']['id'] : '')}'
            : null;
        if (episodeId == null || episodeId.isEmpty) {
          throw const ApiException('Impossible de créer le brouillon de l’épisode.');
        }
        _createdEpisodeId = episodeId;
      } else {
        await BkoApi.patch(
          '/creator/episodes/$episodeId',
          body,
          token: auth.token,
        );
      }

      final rawAudioUrl = _audioUrlController.text.trim();
      final rawVideoUrl = _videoUrlController.text.trim();
      final normalizedVideoUrl = YoutubeUrlParser.isYoutubeDomain(rawVideoUrl)
          ? (YoutubeUrlParser.normalizeWatchUrl(rawVideoUrl) ?? rawVideoUrl)
          : rawVideoUrl;

      final hasBoth = rawAudioUrl.isNotEmpty &&
          (normalizedVideoUrl.isNotEmpty ||
              _selectedVideoBytes != null ||
              _uploadedVideoReady);

      // 2. Associer la source audio (sans ignorer les erreurs ni dupliquer si déjà associée)
      if (rawAudioUrl.isNotEmpty && _attachedAudioUrl != rawAudioUrl) {
        try {
          await BkoApi.post(
            '/creator/episodes/$episodeId/media-sources',
            {
              'rawUrl': rawAudioUrl,
              'mediaTypePreference': 'AUDIO',
              'isPrimaryAudio': _mediaType == 'AUDIO' || !hasBoth,
              'isPrimaryVideo': false,
            },
            token: auth.token,
          );
          _attachedAudioUrl = rawAudioUrl;
        } catch (e) {
          final msg = e is ApiException
              ? e.message
              : 'Impossible d’associer la source audio.';
          if (mounted) {
            setState(() {
              _audioError = msg;
              _generalError =
                  'Brouillon conservé, mais la source audio a été refusée : $msg';
              _submitting = false;
            });
          }
          return;
        }
      }

      // 3. Associer la source vidéo par lien (sans ignorer les erreurs ni dupliquer)
      if (normalizedVideoUrl.isNotEmpty &&
          _attachedVideoUrl != normalizedVideoUrl) {
        try {
          await BkoApi.post(
            '/creator/episodes/$episodeId/media-sources',
            {
              'rawUrl': normalizedVideoUrl,
              'mediaTypePreference': 'VIDEO',
              'isPrimaryVideo': _mediaType == 'VIDEO' || !hasBoth,
              'isPrimaryAudio': false,
            },
            token: auth.token,
          );
          _attachedVideoUrl = normalizedVideoUrl;
        } catch (e) {
          final msg = e is ApiException
              ? e.message
              : 'Impossible d’associer la source vidéo.';
          if (mounted) {
            setState(() {
              _videoError = msg;
              _generalError =
                  'Brouillon conservé, mais la source vidéo a été refusée : $msg';
              _submitting = false;
            });
          }
          return;
        }
      }

      // 4. Téléverser le fichier vidéo local si sélectionné et non encore prêt
      if (_selectedVideoBytes != null && !_uploadedVideoReady) {
        _videoCancelToken?.cancel();
        _videoCancelToken = CancelToken();
        try {
          await MediaUploadService.uploadMediaAsset(
            bytes: _selectedVideoBytes!,
            originalFilename: _selectedVideoName ?? 'video.mp4',
            mimeType: _selectedVideoMime ?? 'video/mp4',
            mediaType: 'VIDEO',
            episodeId: episodeId,
            token: auth.token!,
            cancelToken: _videoCancelToken,
            onStageChanged: (stage) {
              if (mounted) setState(() => _videoUploadStage = stage);
            },
            onProgress: (sent, total) {
              if (mounted && total > 0) {
                setState(() => _videoUploadProgress = sent / total);
              }
            },
          );
          _uploadedVideoReady = true;
        } catch (e) {
          final msg = e is ApiException
              ? e.message
              : 'Le téléversement du fichier vidéo a échoué.';
          if (mounted) {
            setState(() {
              _videoError = msg;
              _generalError =
                  'Brouillon conservé. Corrigez ou relancez le transfert vidéo : $msg';
              _submitting = false;
            });
          }
          return;
        }
      }

      // 5. Enregistrement simple en brouillon
      if (isDraft) {
        if (!mounted) return;
        setState(() => _submitting = false);
        BkoToast.showSuccess(
          context,
          title: 'Brouillon enregistré',
          message: 'Votre épisode a été enregistré en brouillon.',
        );
        context.pop(true);
        return;
      }

      // 6. Publication (uniquement lorsque toutes les sources sont prêtes et validées)
      try {
        final published = await BkoApi.post(
          '/creator/episodes/$episodeId/publish',
          {},
          token: auth.token,
        );
        if (!mounted) return;
        setState(() => _submitting = false);

        final status =
            published is Map ? '${published['status'] ?? 'PUBLISHED'}' : 'PUBLISHED';
        if (status == 'PENDING_REVIEW') {
          BkoToast.showInfo(
            context,
            title: 'En attente de validation',
            message:
                'Votre épisode a été soumis à la modération avant mise en ligne.',
          );
        } else {
          BkoToast.showSuccess(
            context,
            title: 'Épisode publié',
            message: 'Votre épisode est maintenant en ligne.',
          );
        }
        context.pop(true);
      } catch (e) {
        final msg = e is ApiException
            ? e.message
            : 'La publication a été refusée par le serveur.';
        if (!mounted) return;
        setState(() {
          _submitting = false;
          _generalError =
              'Brouillon conservé (non publié) : $msg Vous pouvez corriger et réessayer sans dupliquer l’épisode.';
        });
        BkoToast.showError(
          context,
          title: 'Publication refusée',
          message: msg,
        );
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _generalError = e.message;
      });
      BkoToast.showError(
        context,
        title: 'Erreur',
        message: e.message,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _generalError =
            'Une erreur réseau est survenue. Vos saisies sont conservées.';
      });
      BkoToast.showError(
        context,
        title: 'Action impossible',
        message: 'Vérifiez votre connexion et réessayez.',
      );
    }
  }

  String _stageLabel(MediaTransferStage stage, double progress) {
    switch (stage) {
      case MediaTransferStage.selecting:
        return 'Sélection du fichier...';
      case MediaTransferStage.validating:
        return 'Validation du format et de la taille...';
      case MediaTransferStage.uploading:
        return 'Transfert en cours (${(progress * 100).round()}%)...';
      case MediaTransferStage.processing:
        return 'Traitement et vérification serveur...';
      case MediaTransferStage.ready:
        return 'Média prêt et rattaché';
      case MediaTransferStage.cancelled:
        return 'Transfert annulé';
      case MediaTransferStage.error:
        return 'Échec du transfert';
      case MediaTransferStage.idle:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final textPri = BkoTheme.getTextPrimary(context);
    final textSec = BkoTheme.getTextSecondary(context);
    final bgSurf = BkoTheme.getBgSurface(context);
    final bgElevated = BkoTheme.getBgSurfaceElevated(context);
    final borderSub = BkoTheme.getBorderSubtle(context);

    return Scaffold(
      backgroundColor: bgSurf,
      appBar: AppBar(
        actions: const [AppHeaderActions()],
        backgroundColor: bgSurf,
        elevation: 0,
        leading: const AppBackButton(),
        title: Text(
          _createdEpisodeId != null ? 'Compléter l’épisode' : 'Nouvel Épisode',
          style: BkoTheme.fontLato(
              fontSize: 18, fontWeight: FontWeight.w800, color: textPri),
        ),
      ),
      body: _loadingPodcasts
          ? const Center(
              child: CircularProgressIndicator.adaptive(
                valueColor: AlwaysStoppedAnimation(BkoTheme.goldAccent),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_generalError != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: BkoTheme.errorColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: BkoTheme.errorColor.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              IconsaxPlusLinear.info_circle,
                              color: BkoTheme.errorColor,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _generalError!,
                                style: BkoTheme.fontLato(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: BkoTheme.errorColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    if (_createdEpisodeId != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: BkoTheme.goldAccent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: BkoTheme.goldAccent.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              IconsaxPlusLinear.document_text,
                              color: BkoTheme.goldAccent,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Brouillon enregistré. Toute nouvelle tentative mettra à jour cet épisode sans créer de doublon.',
                                style: BkoTheme.fontLato(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: textPri,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Select Podcast
                    Text(
                      'ÉMISSION DE RATTACHEMENT',
                      style: BkoTheme.fontLato(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: textSec,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_podcasts.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: BkoTheme.goldAccent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color:
                                  BkoTheme.goldAccent.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          'Aucune émission disponible. Créez d\'abord une émission.',
                          style: BkoTheme.fontLato(
                              fontSize: 13, color: BkoTheme.goldAccent),
                        ),
                      )
                    else
                      DropdownButtonFormField<String>(
                        initialValue: _selectedPodcastId,
                        dropdownColor: bgElevated,
                        style: BkoTheme.fontLato(fontSize: 14, color: textPri),
                        decoration: _inputDecoration(
                          '',
                          borderSub,
                          bgElevated,
                          errorText: _podcastError,
                        ),
                        items: _podcasts.map((p) {
                          final map = p as Map;
                          return DropdownMenuItem<String>(
                            value: '${map['id']}',
                            child: Text('${map['name']}',
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: _createdEpisodeId != null
                            ? null
                            : (val) => setState(() {
                                  _selectedPodcastId = val;
                                  _podcastError = null;
                                }),
                      ),

                    const SizedBox(height: 20),

                    // Media Type Selection
                    Text(
                      'FORMAT DU MÉDIA PRINCIPAL',
                      style: BkoTheme.fontLato(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: textSec,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Vous pouvez renseigner à la fois une source audio et une source vidéo ; ce choix définit le média principal requis pour la publication.',
                      style: BkoTheme.fontLato(fontSize: 11.5, color: textSec),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _mediaTypeOption('AUDIO', 'Audio principal',
                            IconsaxPlusLinear.headphone),
                        const SizedBox(width: 12),
                        _mediaTypeOption('VIDEO', 'Vidéo principale',
                            IconsaxPlusLinear.video),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Title
                    Text(
                      'TITRE DE L\'ÉPISODE',
                      style: BkoTheme.fontLato(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: textSec,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _titleController,
                      onChanged: (_) {
                        if (_titleError != null) {
                          setState(() => _titleError = null);
                        }
                      },
                      style: BkoTheme.fontLato(fontSize: 14, color: textPri),
                      decoration: _inputDecoration(
                        'Ex: Épisode #12 - Entretien Exclusif',
                        borderSub,
                        bgElevated,
                        errorText: _titleError,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Description
                    Text(
                      'DESCRIPTION & NOTES DE L\'ÉPISODE',
                      style: BkoTheme.fontLato(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: textSec,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 4,
                      onChanged: (_) {
                        if (_descriptionError != null) {
                          setState(() => _descriptionError = null);
                        }
                      },
                      style: BkoTheme.fontLato(fontSize: 14, color: textPri),
                      decoration: _inputDecoration(
                        'Résumez le sujet abordé dans cet épisode...',
                        borderSub,
                        bgElevated,
                        errorText: _descriptionError,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Audio Source Link
                    Row(
                      children: [
                        Text(
                          'SOURCE AUDIO (URL MP3 / M4A / WAV)',
                          style: BkoTheme.fontLato(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: textSec,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (_mediaType == 'AUDIO')
                          _buildRequiredBadge('Requis pour publier')
                        else
                          _buildOptionalBadge('Optionnel', textSec, borderSub),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _audioUrlController,
                      onChanged: (_) {
                        if (_audioError != null) {
                          setState(() => _audioError = null);
                        }
                      },
                      style: BkoTheme.fontLato(fontSize: 14, color: textPri),
                      decoration: _inputDecoration(
                        'https://mon-storage.com/episode.mp3',
                        borderSub,
                        bgElevated,
                        errorText: _audioError,
                        suffixIcon: _attachedAudioUrl != null &&
                                _attachedAudioUrl ==
                                    _audioUrlController.text.trim()
                            ? const Icon(IconsaxPlusBold.tick_circle,
                                color: BkoTheme.successColor, size: 18)
                            : null,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Video Source (YouTube URL, direct MP4 URL, or local video file upload)
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'SOURCE VIDÉO (LIEN YOUTUBE / MP4 OU FICHIER)',
                            style: BkoTheme.fontLato(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                              color: textSec,
                            ),
                          ),
                        ),
                        if (_mediaType == 'VIDEO')
                          _buildRequiredBadge('Requis pour publier')
                        else
                          _buildOptionalBadge('Optionnel', textSec, borderSub),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ajoutez une vidéo YouTube existante (watch, youtu.be, shorts, live, embed) ou téléversez un fichier vidéo dans Bamako Podcast.',
                      style: BkoTheme.fontLato(fontSize: 11, color: textSec),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _videoUrlController,
                      onChanged: (_) {
                        if (_videoError != null) {
                          setState(() => _videoError = null);
                        }
                      },
                      style: BkoTheme.fontLato(fontSize: 14, color: textPri),
                      decoration: _inputDecoration(
                        'https://www.youtube.com/watch?v=...',
                        borderSub,
                        bgElevated,
                        errorText: _videoError,
                        suffixIcon: _attachedVideoUrl != null &&
                                _attachedVideoUrl ==
                                    (YoutubeUrlParser.normalizeWatchUrl(
                                            _videoUrlController.text.trim()) ??
                                        _videoUrlController.text.trim())
                            ? const Icon(IconsaxPlusBold.tick_circle,
                                color: BkoTheme.successColor, size: 18)
                            : null,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        BkoBounceable(
                          onTap: _submitting ? null : _pickLocalVideoFile,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: bgElevated,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: borderSub),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  IconsaxPlusLinear.document_upload,
                                  color: BkoTheme.goldAccent,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _selectedVideoName != null
                                      ? 'Changer le fichier vidéo'
                                      : 'Téléverser un fichier vidéo (MP4/MOV)',
                                  style: BkoTheme.fontLato(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: textPri,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (_selectedVideoName != null) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _selectedVideoName!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: BkoTheme.fontLato(
                                  fontSize: 11.5, color: textSec),
                            ),
                          ),
                          IconButton(
                            onPressed: _submitting
                                ? null
                                : () {
                                    _videoCancelToken?.cancel();
                                    setState(() {
                                      _selectedVideoBytes = null;
                                      _selectedVideoName = null;
                                      _selectedVideoMime = null;
                                      _uploadedVideoReady = false;
                                      _videoUploadStage =
                                          MediaTransferStage.idle;
                                    });
                                  },
                            icon: const Icon(IconsaxPlusLinear.close_circle,
                                color: BkoTheme.errorColor, size: 18),
                          ),
                        ],
                      ],
                    ),
                    if (_videoUploadStage != MediaTransferStage.idle) ...[
                      const SizedBox(height: 8),
                      _buildTransferStatusBox(
                        stage: _videoUploadStage,
                        progress: _videoUploadProgress,
                        onCancel: _videoUploadStage ==
                                    MediaTransferStage.uploading ||
                                _videoUploadStage ==
                                    MediaTransferStage.processing
                            ? () {
                                _videoCancelToken?.cancel();
                                setState(() {
                                  _videoUploadStage =
                                      MediaTransferStage.cancelled;
                                  _submitting = false;
                                });
                              }
                            : null,
                        textPri: textPri,
                        textSec: textSec,
                        borderSub: borderSub,
                        bgElevated: bgElevated,
                      ),
                    ],

                    const SizedBox(height: 20),

                    // Cover URL & Upload
                    Text(
                      'POCHETTE DE L\'ÉPISODE (OPTIONNEL)',
                      style: BkoTheme.fontLato(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: textSec,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _coverUrlController,
                            onChanged: (_) {
                              if (_coverError != null) {
                                setState(() => _coverError = null);
                              }
                            },
                            style:
                                BkoTheme.fontLato(fontSize: 14, color: textPri),
                            decoration: _inputDecoration(
                              'https://exemple.com/episode-cover.jpg',
                              borderSub,
                              bgElevated,
                              errorText: _coverError,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        BkoBounceable(
                          onTap: _coverStage == MediaTransferStage.uploading
                              ? null
                              : _pickAndUploadCover,
                          child: Container(
                            height: 48,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: bgElevated,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: borderSub),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  IconsaxPlusLinear.gallery_export,
                                  color: BkoTheme.goldAccent,
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Image',
                                  style: BkoTheme.fontLato(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: textPri,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_coverStage != MediaTransferStage.idle) ...[
                      const SizedBox(height: 8),
                      _buildTransferStatusBox(
                        stage: _coverStage,
                        progress: _coverProgress,
                        onCancel: _coverStage == MediaTransferStage.uploading
                            ? () {
                                _coverCancelToken?.cancel();
                                setState(() =>
                                    _coverStage = MediaTransferStage.cancelled);
                              }
                            : null,
                        textPri: textPri,
                        textSec: textSec,
                        borderSub: borderSub,
                        bgElevated: bgElevated,
                      ),
                    ],

                    const SizedBox(height: 20),

                    // Season & Episode Number
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'SAISON',
                                style: BkoTheme.fontLato(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                  color: textSec,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _seasonController,
                                keyboardType: TextInputType.number,
                                onChanged: (_) {
                                  if (_seasonError != null) {
                                    setState(() => _seasonError = null);
                                  }
                                },
                                style: BkoTheme.fontLato(
                                    fontSize: 14, color: textPri),
                                decoration: _inputDecoration(
                                  'Ex: 1',
                                  borderSub,
                                  bgElevated,
                                  errorText: _seasonError,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'NUMÉRO D\'ÉPISODE',
                                style: BkoTheme.fontLato(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                  color: textSec,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _episodeNumController,
                                keyboardType: TextInputType.number,
                                onChanged: (_) {
                                  if (_episodeNumError != null) {
                                    setState(() => _episodeNumError = null);
                                  }
                                },
                                style: BkoTheme.fontLato(
                                    fontSize: 14, color: textPri),
                                decoration: _inputDecoration(
                                  'Ex: 5',
                                  borderSub,
                                  bgElevated,
                                  errorText: _episodeNumError,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // Submit Buttons
                    if (_submitting)
                      Center(
                        child: Column(
                          children: [
                            const CircularProgressIndicator.adaptive(
                              valueColor:
                                  AlwaysStoppedAnimation(BkoTheme.goldAccent),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Validation et enregistrement en cours...',
                              style: BkoTheme.fontLato(
                                  fontSize: 12, color: textSec),
                            ),
                          ],
                        ),
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: BkoBounceable(
                              onTap: () {
                                BkoHaptics.light();
                                _submit(isDraft: true);
                              },
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: bgElevated,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: borderSub),
                                ),
                                child: Text(
                                  'BROUILLON',
                                  style: BkoTheme.fontLato(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                    color: textPri,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: BkoBounceable(
                              onTap: () {
                                BkoHaptics.light();
                                _submit(isDraft: false);
                              },
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: BkoTheme.goldAccent,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Text(
                                  _createdEpisodeId != null
                                      ? 'RÉESSAYER & PUBLIER'
                                      : 'PUBLIER',
                                  style: BkoTheme.fontLato(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                    color: BkoTheme.darkBgObsidian,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildRequiredBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: BkoTheme.goldAccent.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: BkoTheme.fontLato(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: BkoTheme.goldAccent,
        ),
      ),
    );
  }

  Widget _buildOptionalBadge(String text, Color textSec, Color borderSub) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderSub),
      ),
      child: Text(
        text,
        style: BkoTheme.fontLato(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: textSec,
        ),
      ),
    );
  }

  Widget _buildTransferStatusBox({
    required MediaTransferStage stage,
    required double progress,
    required VoidCallback? onCancel,
    required Color textPri,
    required Color textSec,
    required Color borderSub,
    required Color bgElevated,
  }) {
    final isIndeterminate = stage == MediaTransferStage.validating ||
        stage == MediaTransferStage.processing;
    final isUploading = stage == MediaTransferStage.uploading;
    final isReady = stage == MediaTransferStage.ready;
    final isError = stage == MediaTransferStage.error ||
        stage == MediaTransferStage.cancelled;

    final accent = isReady
        ? BkoTheme.successColor
        : isError
            ? BkoTheme.errorColor
            : BkoTheme.goldAccent;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bgElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderSub),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isReady
                    ? IconsaxPlusBold.tick_circle
                    : isError
                        ? IconsaxPlusLinear.info_circle
                        : IconsaxPlusLinear.cloud_add,
                color: accent,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _stageLabel(stage, progress),
                  style: BkoTheme.fontLato(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: textPri,
                  ),
                ),
              ),
              if (onCancel != null)
                TextButton(
                  onPressed: onCancel,
                  child: Text(
                    'Annuler',
                    style: BkoTheme.fontLato(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: BkoTheme.errorColor,
                    ),
                  ),
                ),
            ],
          ),
          if (isUploading || isIndeterminate) ...[
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: isUploading ? progress.clamp(0.0, 1.0) : null,
                minHeight: 5,
                backgroundColor: borderSub,
                color: BkoTheme.goldAccent,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _mediaTypeOption(String key, String label, IconData icon) {
    final selected = _mediaType == key;
    final bgElevated = BkoTheme.getBgSurfaceElevated(context);
    final borderSub = BkoTheme.getBorderSubtle(context);

    return Expanded(
      child: BkoBounceable(
        onTap: () {
          BkoHaptics.select();
          setState(() {
            _mediaType = key;
            _audioError = null;
            _videoError = null;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? BkoTheme.goldAccent.withValues(alpha: 0.15)
                : bgElevated,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? BkoTheme.goldAccent : borderSub,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: selected
                    ? BkoTheme.goldAccent
                    : BkoTheme.getTextSecondary(context),
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: BkoTheme.fontLato(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected
                      ? BkoTheme.goldAccent
                      : BkoTheme.getTextPrimary(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(
    String hint,
    Color border,
    Color bg, {
    String? errorText,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      errorText: errorText,
      errorMaxLines: 3,
      suffixIcon: suffixIcon,
      hintStyle: BkoTheme.fontLato(
          fontSize: 13, color: BkoTheme.getTextMuted(context)),
      filled: true,
      fillColor: bg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: BkoTheme.goldAccent),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: BkoTheme.errorColor),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: BkoTheme.errorColor, width: 1.5),
      ),
    );
  }
}
