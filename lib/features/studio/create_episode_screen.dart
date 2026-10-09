import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/network/bko_api.dart';
import '../../core/theme/bko_theme.dart';
import '../auth/auth_controller.dart';

class CreateEpisodeScreen extends ConsumerStatefulWidget {
  const CreateEpisodeScreen({super.key});

  @override
  ConsumerState<CreateEpisodeScreen> createState() => _CreateEpisodeScreenState();
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
          _selectedPodcastId = '${_podcasts.first['id']}';
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
        const SnackBar(content: Text('Veuillez sélectionner une émission.'), backgroundColor: Colors.red),
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
        'status': isDraft ? 'DRAFT' : 'PUBLISHED',
        if (_audioUrlController.text.trim().isNotEmpty) 'audioUrl': _audioUrlController.text.trim(),
        if (_videoUrlController.text.trim().isNotEmpty) 'videoUrl': _videoUrlController.text.trim(),
        if (_coverUrlController.text.trim().isNotEmpty) 'cover': _coverUrlController.text.trim(),
        if (_seasonController.text.trim().isNotEmpty) 'seasonNumber': int.tryParse(_seasonController.text.trim()),
        if (_episodeNumController.text.trim().isNotEmpty) 'episodeNumber': int.tryParse(_episodeNumController.text.trim()),
      };

      await BkoApi.post('/creator/podcasts/$_selectedPodcastId/episodes', body, token: auth.token);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isDraft ? 'Épisode enregistré en brouillon.' : 'Épisode publié avec succès !'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: BkoTheme.goldAccent,
        ),
      );
      context.pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), behavior: SnackBarBehavior.floating, backgroundColor: Colors.red),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de publier l\'épisode.'), behavior: SnackBarBehavior.floating, backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textPri = BkoTheme.getTextPrimary(context);
    final textSec = BkoTheme.getTextSecondary(context);
    final bgSurf = BkoTheme.getBgSurface(context);
    final borderSub = BkoTheme.getBorderSubtle(context);

    return Scaffold(
      backgroundColor: bgSurf,
      appBar: AppBar(
        backgroundColor: bgSurf,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textPri, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text('Nouvel Épisode', style: BkoTheme.fontLato(fontSize: 18, fontWeight: FontWeight.w900, color: textPri)),
      ),
      body: _loadingPodcasts
          ? const Center(child: CircularProgressIndicator(color: BkoTheme.goldAccent))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Select Podcast
                    Text('ÉMISSION DE RATTACHEMENT', style: BkoTheme.fontLato(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.4, color: textSec)),
                    const SizedBox(height: 8),
                    if (_podcasts.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.orange.withValues(alpha: 0.3))),
                        child: Text('Aucune émission disponible. Créez d\'abord une émission.', style: BkoTheme.fontLato(fontSize: 13, color: Colors.orange.shade300)),
                      )
                    else
                      DropdownButtonFormField<String>(
                        initialValue: _selectedPodcastId,
                        dropdownColor: BkoTheme.getBgSurfaceElevated(context),
                        style: BkoTheme.fontLato(fontSize: 14, color: textPri),
                        decoration: _inputDecoration('', borderSub, bgSurf),
                        items: _podcasts.map((p) {
                          final map = p as Map;
                          return DropdownMenuItem<String>(
                            value: '${map['id']}',
                            child: Text('${map['name']}', maxLines: 1, overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: (val) => setState(() => _selectedPodcastId = val),
                      ),

                    const SizedBox(height: 20),

                    // Media Type Selection
                    Text('FORMAT DU MÉDIA PRINCIPAL', style: BkoTheme.fontLato(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.4, color: textSec)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _mediaTypeOption('AUDIO', 'Audio (MP3/AAC)', Icons.headphones_rounded),
                        const SizedBox(width: 12),
                        _mediaTypeOption('VIDEO', 'Vidéo (YouTube/MP4)', Icons.videocam_rounded),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Title
                    Text('TITRE DE L\'ÉPISODE', style: BkoTheme.fontLato(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.4, color: textSec)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _titleController,
                      style: BkoTheme.fontLato(fontSize: 14, color: textPri),
                      decoration: _inputDecoration('Ex: Épisode #12 - Entretien Exclusif', borderSub, bgSurf),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Le titre est obligatoire.' : null,
                    ),

                    const SizedBox(height: 20),

                    // Description
                    Text('DESCRIPTION & NOTES DE L\'ÉPISODE', style: BkoTheme.fontLato(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.4, color: textSec)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 4,
                      style: BkoTheme.fontLato(fontSize: 14, color: textPri),
                      decoration: _inputDecoration('Résumez le sujet abordé dans cet épisode...', borderSub, bgSurf),
                    ),

                    const SizedBox(height: 20),

                    // Audio Source Link / File
                    if (_mediaType == 'AUDIO' || true) ...[
                      Text('URL SOURCE AUDIO (MP3/HLS/R2)', style: BkoTheme.fontLato(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.4, color: textSec)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _audioUrlController,
                        style: BkoTheme.fontLato(fontSize: 14, color: textPri),
                        decoration: _inputDecoration('https://mon-storage.com/media.mp3', borderSub, bgSurf),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Video Source Link / File
                    if (_mediaType == 'VIDEO' || true) ...[
                      Text('LIEN VIDÉO (YOUTUBE OU DIRECT MP4)', style: BkoTheme.fontLato(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.4, color: textSec)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _videoUrlController,
                        style: BkoTheme.fontLato(fontSize: 14, color: textPri),
                        decoration: _inputDecoration('https://www.youtube.com/watch?v=...', borderSub, bgSurf),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Cover URL
                    Text('URL POCHETTE D\'ÉPISODE (OPTIONNEL)', style: BkoTheme.fontLato(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.4, color: textSec)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _coverUrlController,
                      style: BkoTheme.fontLato(fontSize: 14, color: textPri),
                      decoration: _inputDecoration('https://exemple.com/episode-cover.jpg', borderSub, bgSurf),
                    ),

                    const SizedBox(height: 20),

                    // Season & Episode Number
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('SAISON', style: BkoTheme.fontLato(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.4, color: textSec)),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _seasonController,
                                keyboardType: TextInputType.number,
                                style: BkoTheme.fontLato(fontSize: 14, color: textPri),
                                decoration: _inputDecoration('Ex: 1', borderSub, bgSurf),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('NUMÉRO ÉPISODE', style: BkoTheme.fontLato(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.4, color: textSec)),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _episodeNumController,
                                keyboardType: TextInputType.number,
                                style: BkoTheme.fontLato(fontSize: 14, color: textPri),
                                decoration: _inputDecoration('Ex: 5', borderSub, bgSurf),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 36),

                    // Submit Buttons
                    if (_submitting)
                      const Center(child: CircularProgressIndicator(color: BkoTheme.goldAccent))
                    else
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _submit(isDraft: true),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                side: BorderSide(color: borderSub),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              child: Text('ENREGISTRER BROUILLON', style: BkoTheme.fontLato(fontSize: 12, fontWeight: FontWeight.w800, color: textPri)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _submit(isDraft: false),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: BkoTheme.goldAccent,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              child: Text('PUBLIER L\'ÉPISODE', style: BkoTheme.fontLato(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.black)),
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
      child: GestureDetector(
        onTap: () => setState(() => _mediaType = key),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? BkoTheme.goldAccent.withValues(alpha: 0.15) : bgElevated,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? BkoTheme.goldAccent : borderSub, width: selected ? 1.5 : 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: selected ? BkoTheme.goldAccent : BkoTheme.getTextSecondary(context), size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: BkoTheme.fontLato(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected ? BkoTheme.goldAccent : BkoTheme.getTextPrimary(context),
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
      hintStyle: BkoTheme.fontLato(fontSize: 13, color: Colors.grey),
      filled: true,
      fillColor: BkoTheme.getBgSurfaceElevated(context),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: BkoTheme.goldAccent)),
    );
  }
}
