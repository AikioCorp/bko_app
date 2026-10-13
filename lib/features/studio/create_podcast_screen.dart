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
        'primaryLanguageCode': _language,
        'countryId': 'ML',
        'cover': _coverUrlController.text.trim().isNotEmpty
            ? _coverUrlController.text.trim()
            : 'https://d3t3ozftmdmh3i.cloudfront.net/staging/podcast_uploaded_nologo/placeholder.jpg',
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
          content: const Text('Impossible de créer l\'émission.'),
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
          'Nouvelle Émission',
          style: BkoTheme.fontLato(fontSize: 18, fontWeight: FontWeight.w800, color: textPri),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Format Selection
              Text(
                'FORMAT DE L\'ÉMISSION',
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
                  _formatOption('AUDIO', 'Audio seul', IconsaxPlusLinear.headphone),
                  const SizedBox(width: 8),
                  _formatOption('VIDEO', 'Vidéo seule', IconsaxPlusLinear.video),
                  const SizedBox(width: 8),
                  _formatOption('AUDIO_AND_VIDEO', 'Audio & Vidéo', IconsaxPlusLinear.radio),
                ],
              ),

              const SizedBox(height: 24),

              // Name
              Text(
                'NOM DE L\'ÉMISSION',
                style: BkoTheme.fontLato(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: textSec,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                style: BkoTheme.fontLato(fontSize: 14, color: textPri),
                decoration: _inputDecoration('Ex: Les Voix du Mali', borderSub, bgElevated),
                validator: (val) => val == null || val.trim().isEmpty ? 'Le nom est obligatoire.' : null,
              ),

              const SizedBox(height: 20),

              // Description
              Text(
                'DESCRIPTION & PRÉSENTATION',
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
                decoration: _inputDecoration('Présentez votre émission aux auditeurs...', borderSub, bgElevated),
                validator: (val) => val == null || val.trim().isEmpty ? 'La description est obligatoire.' : null,
              ),

              const SizedBox(height: 20),

              // Cover URL
              Text(
                'URL DE LA POCHETTE',
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
                decoration: _inputDecoration('https://exemple.com/pochette.jpg', borderSub, bgElevated),
              ),

              const SizedBox(height: 20),

              // Language
              Text(
                'LANGUE PRINCIPALE',
                style: BkoTheme.fontLato(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: textSec,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _language,
                dropdownColor: bgElevated,
                style: BkoTheme.fontLato(fontSize: 14, color: textPri),
                decoration: _inputDecoration('', borderSub, bgElevated),
                items: const [
                  DropdownMenuItem(value: 'fr', child: Text('Français')),
                  DropdownMenuItem(value: 'bm', child: Text('Bambara (Bamanankan)')),
                  DropdownMenuItem(value: 'ff', child: Text('Foulfouldé (Peul)')),
                  DropdownMenuItem(value: 'en', child: Text('Anglais')),
                ],
                onChanged: (val) => setState(() => _language = val ?? 'fr'),
              ),

              const SizedBox(height: 32),

              // Submit Action Buttons
              if (_submitting)
                const Center(
                  child: CircularProgressIndicator.adaptive(
                    valueColor: AlwaysStoppedAnimation(BkoTheme.goldAccent),
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
                          padding: const EdgeInsets.symmetric(vertical: 14),
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
                          padding: const EdgeInsets.symmetric(vertical: 14),
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

  Widget _formatOption(String key, String label, IconData icon) {
    final selected = _format == key;
    final bgElevated = BkoTheme.getBgSurfaceElevated(context);
    final borderSub = BkoTheme.getBorderSubtle(context);

    return Expanded(
      child: BkoBounceable(
        onTap: () {
          BkoHaptics.select();
          setState(() => _format = key);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? BkoTheme.goldAccent.withValues(alpha: 0.15) : bgElevated,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? BkoTheme.goldAccent : borderSub,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: selected ? BkoTheme.goldAccent : BkoTheme.getTextSecondary(context),
                size: 20,
              ),
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
      hintStyle: BkoTheme.fontLato(fontSize: 13, color: BkoTheme.getTextMuted(context)),
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
