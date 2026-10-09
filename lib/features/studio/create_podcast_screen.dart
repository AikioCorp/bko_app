import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/network/bko_api.dart';
import '../../core/theme/bko_theme.dart';
import '../auth/auth_controller.dart';

class CreatePodcastScreen extends ConsumerStatefulWidget {
  const CreatePodcastScreen({super.key});

  @override
  ConsumerState<CreatePodcastScreen> createState() => _CreatePodcastScreenState();
}

class _CreatePodcastScreenState extends ConsumerState<CreatePodcastScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _coverUrlController = TextEditingController();

  String _format = 'AUDIO_AND_VIDEO'; // AUDIO, VIDEO, AUDIO_AND_VIDEO
  String _language = 'fr';
  bool _submitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _coverUrlController.dispose();
    super.dispose();
  }

  Future<void> _submit({bool isDraft = false}) async {
    if (!_formKey.currentState!.validate()) return;
    final auth = ref.read(authProvider);
    if (!auth.isAuthenticated || auth.token == null) return;

    setState(() => _submitting = true);

    try {
      final body = {
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'format': _format,
        'language': _language,
        if (_coverUrlController.text.trim().isNotEmpty) 'cover': _coverUrlController.text.trim(),
        'status': isDraft ? 'DRAFT' : 'PUBLISHED',
      };

      await BkoApi.post('/creator/podcasts', body, token: auth.token);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isDraft ? 'Brouillon enregistré avec succès.' : 'Émission créée et publiée avec succès !'),
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
        const SnackBar(content: Text('Impossible de créer l\'émission.'), behavior: SnackBarBehavior.floating, backgroundColor: Colors.red),
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
        title: Text('Nouvelle Émission', style: BkoTheme.fontLato(fontSize: 18, fontWeight: FontWeight.w900, color: textPri)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Format Selection
              Text('FORMAT DE L\'ÉMISSION', style: BkoTheme.fontLato(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.4, color: textSec)),
              const SizedBox(height: 10),
              Row(
                children: [
                  _formatOption('AUDIO', 'Audio seul', Icons.headphones_rounded),
                  const SizedBox(width: 8),
                  _formatOption('VIDEO', 'Vidéo seule', Icons.videocam_rounded),
                  const SizedBox(width: 8),
                  _formatOption('AUDIO_AND_VIDEO', 'Audio & Vidéo', Icons.podcasts_rounded),
                ],
              ),

              const SizedBox(height: 24),

              // Name
              Text('NOM DE L\'ÉMISSION', style: BkoTheme.fontLato(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.4, color: textSec)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                style: BkoTheme.fontLato(fontSize: 14, color: textPri),
                decoration: _inputDecoration('Ex: Les Voix du Mali', borderSub, bgSurf),
                validator: (val) => val == null || val.trim().isEmpty ? 'Le nom est obligatoire.' : null,
              ),

              const SizedBox(height: 20),

              // Description
              Text('DESCRIPTION & PRÉSENTATION', style: BkoTheme.fontLato(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.4, color: textSec)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                maxLines: 4,
                style: BkoTheme.fontLato(fontSize: 14, color: textPri),
                decoration: _inputDecoration('Présentez votre émission aux auditeurs...', borderSub, bgSurf),
                validator: (val) => val == null || val.trim().isEmpty ? 'La description est obligatoire.' : null,
              ),

              const SizedBox(height: 20),

              // Cover URL or File
              Text('URL POCHETTE (OU FICHIER)', style: BkoTheme.fontLato(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.4, color: textSec)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _coverUrlController,
                style: BkoTheme.fontLato(fontSize: 14, color: textPri),
                decoration: _inputDecoration('https://exemple.com/pochette.jpg', borderSub, bgSurf),
              ),

              const SizedBox(height: 20),

              // Language
              Text('LANGUE PRINCIPALE', style: BkoTheme.fontLato(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.4, color: textSec)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _language,
                dropdownColor: BkoTheme.getBgSurfaceElevated(context),
                style: BkoTheme.fontLato(fontSize: 14, color: textPri),
                decoration: _inputDecoration('', borderSub, bgSurf),
                items: const [
                  DropdownMenuItem(value: 'fr', child: Text('Français')),
                  DropdownMenuItem(value: 'bm', child: Text('Bambara (Bamanankan)')),
                  DropdownMenuItem(value: 'ff', child: Text('Foulfouldé (Peul)')),
                  DropdownMenuItem(value: 'en', child: Text('Anglais')),
                ],
                onChanged: (val) => setState(() => _language = val ?? 'fr'),
              ),

              const SizedBox(height: 36),

              // Submit Action Buttons
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
                        child: Text('PUBLIER', style: BkoTheme.fontLato(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.black)),
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

  Widget _formatOption(String key, String label, IconData icon) {
    final selected = _format == key;
    final bgElevated = BkoTheme.getBgSurfaceElevated(context);
    final borderSub = BkoTheme.getBorderSubtle(context);

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _format = key),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? BkoTheme.goldAccent.withValues(alpha: 0.15) : bgElevated,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? BkoTheme.goldAccent : borderSub, width: selected ? 1.5 : 1),
          ),
          child: Column(
            children: [
              Icon(icon, color: selected ? BkoTheme.goldAccent : BkoTheme.getTextSecondary(context), size: 20),
              const SizedBox(height: 4),
              Text(
                label,
                style: BkoTheme.fontLato(
                  fontSize: 11,
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
