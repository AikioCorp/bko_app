import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../../core/network/bko_api.dart';
import '../../core/theme/bko_theme.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/widgets/bko_bounceable.dart';
import '../../core/widgets/bko_haptics.dart';
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

  @override
  void initState() {
    super.initState();
    _fetchPodcasts();
  }

  @override
  void dispose() {
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
    if (!auth.isAuthenticated || auth.token == null) return;
    try {
      final list = await BkoApi.get('/creator/podcasts', token: auth.token);
      if (!mounted) return;
      setState(() {
        _podcasts = (list as List?) ?? [];
        if (_podcasts.isNotEmpty) {
          _selectedPodcastId =
              _podcasts.any((p) => '${p['id']}' == widget.initialPodcastId)
                  ? widget.initialPodcastId
                  : '${_podcasts.first['id']}';
        }
        _loadingPodcasts = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingPodcasts = false);
    }
  }

  Future<void> _submit({bool isDraft = false}) async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPodcastId == null || _selectedPodcastId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Veuillez sélectionner une émission.'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    final auth = ref.read(authProvider);
    if (!auth.isAuthenticated || auth.token == null) return;

    setState(() => _submitting = true);

    try {
      final body = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        if (_coverUrlController.text.trim().isNotEmpty)
          'cover': _coverUrlController.text.trim(),
        if (_episodeNumController.text.trim().isNotEmpty)
          'episodeNumber': int.tryParse(_episodeNumController.text.trim()),
      };

      final episodeRes = await BkoApi.post(
          '/creator/podcasts/$_selectedPodcastId/episodes', body,
          token: auth.token);
      final episodeId = episodeRes is Map
          ? (episodeRes['id'] ??
              (episodeRes['data'] is Map ? episodeRes['data']['id'] : null))
          : null;

      if (episodeId != null) {
        // Associer la source audio
        final audioUrl = _audioUrlController.text.trim();
        if (audioUrl.isNotEmpty) {
          try {
            await BkoApi.post(
              '/creator/episodes/$episodeId/media-sources',
              {
                'rawUrl': audioUrl,
                'mediaTypePreference': 'AUDIO',
                'isPrimaryAudio': true,
              },
              token: auth.token,
            );
          } catch (_) {}
        }

        // Associer la source vidéo
        final videoUrl = _videoUrlController.text.trim();
        if (videoUrl.isNotEmpty) {
          try {
            await BkoApi.post(
              '/creator/episodes/$episodeId/media-sources',
              {
                'rawUrl': videoUrl,
                'mediaTypePreference': 'VIDEO',
                'isPrimaryVideo': true,
              },
              token: auth.token,
            );
          } catch (_) {}
        }

        // Publication si demandée
        String message = 'Épisode enregistré en brouillon.';
        if (!isDraft) {
          try {
            final published = await BkoApi.post(
                '/creator/episodes/$episodeId/publish', {},
                token: auth.token);
            message =
                published is Map && published['status'] == 'PENDING_REVIEW'
                    ? 'Épisode envoyé pour validation.'
                    : 'Épisode publié avec succès !';
          } catch (e) {
            message = e is ApiException
                ? 'Brouillon conservé. ${e.message}'
                : 'Brouillon conservé. Publication non confirmée : vérifiez votre Studio.';
          }
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            behavior: SnackBarBehavior.floating,
            backgroundColor: BkoTheme.goldAccent,
          ),
        );
        context.pop();
        return;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              isDraft ? 'Épisode enregistré en brouillon.' : 'Épisode créé.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: BkoTheme.goldAccent,
        ),
      );
      context.pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Impossible de publier l\'épisode.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
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
        backgroundColor: bgSurf,
        elevation: 0,
        leading: const AppBackButton(),
        title: Text(
          'Nouvel Épisode',
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
                        decoration: _inputDecoration('', borderSub, bgElevated),
                        items: _podcasts.map((p) {
                          final map = p as Map;
                          return DropdownMenuItem<String>(
                            value: '${map['id']}',
                            child: Text('${map['name']}',
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: (val) =>
                            setState(() => _selectedPodcastId = val),
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
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _mediaTypeOption('AUDIO', 'Audio (MP3/AAC)',
                            IconsaxPlusLinear.headphone),
                        const SizedBox(width: 12),
                        _mediaTypeOption('VIDEO', 'Vidéo (YouTube/MP4)',
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
                      style: BkoTheme.fontLato(fontSize: 14, color: textPri),
                      decoration: _inputDecoration(
                          'Ex: Épisode #12 - Entretien Exclusif',
                          borderSub,
                          bgElevated),
                      validator: (val) => val == null || val.trim().isEmpty
                          ? 'Le titre est obligatoire.'
                          : null,
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
                      style: BkoTheme.fontLato(fontSize: 14, color: textPri),
                      decoration: _inputDecoration(
                          'Résumez le sujet abordé dans cet épisode...',
                          borderSub,
                          bgElevated),
                    ),

                    const SizedBox(height: 20),

                    // Audio Source Link
                    Text(
                      'URL SOURCE AUDIO (MP3/HLS)',
                      style: BkoTheme.fontLato(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: textSec,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _audioUrlController,
                      style: BkoTheme.fontLato(fontSize: 14, color: textPri),
                      decoration: _inputDecoration(
                          'https://mon-storage.com/media.mp3',
                          borderSub,
                          bgElevated),
                    ),
                    const SizedBox(height: 20),

                    // Video Source Link
                    Text(
                      'LIEN VIDÉO (YOUTUBE OU MP4 DIRECT)',
                      style: BkoTheme.fontLato(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: textSec,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _videoUrlController,
                      style: BkoTheme.fontLato(fontSize: 14, color: textPri),
                      decoration: _inputDecoration(
                          'https://www.youtube.com/watch?v=...',
                          borderSub,
                          bgElevated),
                    ),
                    const SizedBox(height: 20),

                    // Cover URL
                    Text(
                      'URL POCHETTE D\'ÉPISODE (OPTIONNEL)',
                      style: BkoTheme.fontLato(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: textSec,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _coverUrlController,
                      style: BkoTheme.fontLato(fontSize: 14, color: textPri),
                      decoration: _inputDecoration(
                          'https://exemple.com/episode-cover.jpg',
                          borderSub,
                          bgElevated),
                    ),

                    const SizedBox(height: 20),

                    // Season & Episode Number
                    Row(
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
                                style: BkoTheme.fontLato(
                                    fontSize: 14, color: textPri),
                                decoration: _inputDecoration(
                                    'Ex: 1', borderSub, bgElevated),
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
                                style: BkoTheme.fontLato(
                                    fontSize: 14, color: textPri),
                                decoration: _inputDecoration(
                                    'Ex: 5', borderSub, bgElevated),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // Submit Buttons
                    if (_submitting)
                      const Center(
                        child: CircularProgressIndicator.adaptive(
                          valueColor:
                              AlwaysStoppedAnimation(BkoTheme.goldAccent),
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
                                  'PUBLIER',
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

  Widget _mediaTypeOption(String key, String label, IconData icon) {
    final selected = _mediaType == key;
    final bgElevated = BkoTheme.getBgSurfaceElevated(context);
    final borderSub = BkoTheme.getBorderSubtle(context);

    return Expanded(
      child: BkoBounceable(
        onTap: () {
          BkoHaptics.select();
          setState(() => _mediaType = key);
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

  InputDecoration _inputDecoration(String hint, Color border, Color bg) {
    return InputDecoration(
      hintText: hint,
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
    );
  }
}
