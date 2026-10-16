import '../../core/widgets/app_header_actions.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:country_picker/country_picker.dart';

import '../../core/network/bko_api.dart';
import '../../core/services/media_upload_service.dart';
import '../../core/theme/bko_theme.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/widgets/bko_bounceable.dart';
import '../../core/widgets/bko_haptics.dart';
import '../../core/widgets/bko_toast.dart';
import '../auth/auth_controller.dart';

class CreatePodcastScreen extends ConsumerStatefulWidget {
  const CreatePodcastScreen({super.key});

  @override
  ConsumerState<CreatePodcastScreen> createState() =>
      _CreatePodcastScreenState();
}

class _CreatePodcastScreenState extends ConsumerState<CreatePodcastScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _coverUrlController = TextEditingController();

  String _format = 'AUDIO_AND_VIDEO'; // AUDIO, VIDEO, AUDIO_AND_VIDEO
  String _language = 'fr';
  bool _submitting = false;
  Country? _country;

  // Cover upload state
  bool _uploadingCover = false;
  double _coverUploadProgress = 0.0;
  MediaTransferStage _coverTransferStage = MediaTransferStage.idle;
  String? _coverError;
  CancelToken? _coverCancelToken;

  @override
  void dispose() {
    _coverCancelToken?.cancel('Disposed');
    _nameController.dispose();
    _descriptionController.dispose();
    _coverUrlController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadCover() async {
    final auth = ref.read(authProvider);
    if (!auth.isAuthenticated || auth.token == null) return;

    final picked = await MediaUploadService.pickImage();
    if (picked == null) return;

    setState(() {
      _uploadingCover = true;
      _coverError = null;
      _coverUploadProgress = 0.0;
      _coverTransferStage = MediaTransferStage.validating;
    });

    final cancelToken = CancelToken();
    _coverCancelToken = cancelToken;

    try {
      final bytes = await picked.readAsBytes();
      final ext = picked.name.split('.').last.toLowerCase();
      final mimeType = ext == 'png'
          ? 'image/png'
          : ext == 'webp'
              ? 'image/webp'
              : ext == 'gif'
                  ? 'image/gif'
                  : 'image/jpeg';

      final publicUrl = await MediaUploadService.uploadImage(
        bytes: bytes,
        mimeType: mimeType,
        folder: 'covers',
        token: auth.token!,
        cancelToken: cancelToken,
        onStageChanged: (stage) {
          if (mounted) setState(() => _coverTransferStage = stage);
        },
        onProgress: (sent, total) {
          if (mounted && total > 0) {
            setState(() => _coverUploadProgress = sent / total);
          }
        },
      );

      if (!mounted) return;
      setState(() {
        _coverUrlController.text = publicUrl;
        _uploadingCover = false;
        _coverTransferStage = MediaTransferStage.ready;
      });
      BkoHaptics.success();
      BkoToast.showSuccess(
        context,
        title: 'Pochette prête',
        message: 'L\'image de couverture a été téléversée.',
      );
    } on DioException catch (e) {
      if (!mounted) return;
      if (CancelToken.isCancel(e)) {
        setState(() {
          _uploadingCover = false;
          _coverTransferStage = MediaTransferStage.cancelled;
          _coverError = 'Téléversement annulé.';
        });
        return;
      }
      setState(() {
        _uploadingCover = false;
        _coverTransferStage = MediaTransferStage.error;
        _coverError = 'Erreur réseau lors de l\'envoi de la pochette.';
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _uploadingCover = false;
        _coverTransferStage = MediaTransferStage.error;
        _coverError = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _uploadingCover = false;
        _coverTransferStage = MediaTransferStage.error;
        _coverError = 'Impossible de téléverser l\'image de couverture.';
      });
    }
  }

  Future<void> _submit({bool isDraft = false}) async {
    if (_submitting || _uploadingCover) return;
    setState(() => _coverError = null);
    if (!_formKey.currentState!.validate()) return;
    if (_country == null) {
      BkoToast.showError(
        context,
        title: 'Pays requis',
        message: 'Choisissez le pays de votre émission.',
      );
      return;
    }

    final coverText = _coverUrlController.text.trim();
    if (coverText.isNotEmpty) {
      final uri = Uri.tryParse(coverText);
      if (uri == null || (!uri.isScheme('http') && !uri.isScheme('https'))) {
        setState(() =>
            _coverError = 'Veuillez saisir une URL HTTP(S) valide ou téléverser une image.');
        return;
      }
    }

    final auth = ref.read(authProvider);
    if (!auth.isAuthenticated || auth.token == null) return;

    setState(() => _submitting = true);

    try {
      final body = {
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'format': _format,
        'primaryLanguageCode': _language,
        'countryId': _country!.countryCode,
        'cover': coverText,
        'status': 'DRAFT',
      };

      await BkoApi.post('/creator/podcasts', body, token: auth.token);

      if (!mounted) return;
      BkoToast.showSuccess(
        context,
        title: 'Émission créée',
        message: 'Émission enregistrée en brouillon. Ajoutez votre premier épisode.',
      );
      context.pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      BkoToast.showError(
        context,
        title: 'Erreur',
        message: e.message,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      BkoToast.showError(
        context,
        title: 'Création impossible',
        message: 'Impossible de créer l\'émission.',
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
        actions: const [AppHeaderActions()],
        backgroundColor: bgSurf,
        elevation: 0,
        leading: const AppBackButton(),
        title: Text(
          'Nouvelle Émission',
          style: BkoTheme.fontLato(
              fontSize: 18, fontWeight: FontWeight.w800, color: textPri),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              OutlinedButton.icon(
                icon: const Icon(IconsaxPlusLinear.global),
                label: Text(_country?.name ?? 'Choisir le pays de l’émission'),
                onPressed: () => showCountryPicker(
                    context: context,
                    showPhoneCode: false,
                    onSelect: (country) => setState(() => _country = country)),
              ),
              const SizedBox(height: 16),
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
                  _formatOption(
                      'AUDIO', 'Audio seul', IconsaxPlusLinear.headphone),
                  const SizedBox(width: 8),
                  _formatOption(
                      'VIDEO', 'Vidéo seule', IconsaxPlusLinear.video),
                  const SizedBox(width: 8),
                  _formatOption('AUDIO_AND_VIDEO', 'Audio & Vidéo',
                      IconsaxPlusLinear.radio),
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
                decoration: _inputDecoration(
                    'Ex: Les Voix du Mali', borderSub, bgElevated),
                validator: (val) => val == null || val.trim().isEmpty
                    ? 'Le nom est obligatoire.'
                    : null,
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
                decoration: _inputDecoration(
                    'Présentez votre émission aux auditeurs...',
                    borderSub,
                    bgElevated),
                validator: (val) => val == null || val.trim().isEmpty
                    ? 'La description est obligatoire.'
                    : null,
              ),

              const SizedBox(height: 20),

              // Cover Image Upload & URL
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'POCHETTE DE L\'ÉMISSION',
                    style: BkoTheme.fontLato(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: textSec,
                    ),
                  ),
                  BkoBounceable(
                    onTap: _uploadingCover ? null : _pickAndUploadCover,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: BkoTheme.goldAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: BkoTheme.goldAccent.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(IconsaxPlusLinear.gallery_export,
                              size: 15, color: BkoTheme.getAccent(context)),
                          const SizedBox(width: 6),
                          Text(
                            _uploadingCover
                                ? 'Envoi (${(_coverUploadProgress * 100).round()}%)...'
                                : 'Téléverser une image',
                            style: BkoTheme.fontLato(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: BkoTheme.getAccent(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_uploadingCover) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: bgElevated,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderSub),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _coverTransferStage ==
                                    MediaTransferStage.validating
                                ? 'Validation de l\'image...'
                                : 'Transfert (${(_coverUploadProgress * 100).round()}%)...',
                            style: BkoTheme.fontLato(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: textPri),
                          ),
                          BkoBounceable(
                            onTap: () =>
                                _coverCancelToken?.cancel('Cancelled by user'),
                            child: Text(
                              'Annuler',
                              style: BkoTheme.fontLato(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: _coverUploadProgress > 0
                              ? _coverUploadProgress
                              : null,
                          backgroundColor: borderSub,
                          valueColor: const AlwaysStoppedAnimation(
                              BkoTheme.goldAccent),
                          minHeight: 5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (_coverUrlController.text.trim().isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: CachedNetworkImage(
                          imageUrl: _coverUrlController.text.trim(),
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(
                            width: 56,
                            height: 56,
                            color: bgElevated,
                            child: Icon(IconsaxPlusLinear.image,
                                color: textSec, size: 22),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Image de couverture associée',
                          style: BkoTheme.fontLato(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: textPri),
                        ),
                      ),
                      IconButton(
                        icon: Icon(IconsaxPlusLinear.trash,
                            size: 18,
                            color: Theme.of(context).colorScheme.error),
                        onPressed: () =>
                            setState(() => _coverUrlController.clear()),
                      ),
                    ],
                  ),
                ),
              ],
              TextFormField(
                controller: _coverUrlController,
                onChanged: (_) => setState(() => _coverError = null),
                style: BkoTheme.fontLato(fontSize: 14, color: textPri),
                decoration: _inputDecoration(
                    'Ou collez une URL (https://exemple.com/pochette.jpg)',
                    borderSub,
                    bgElevated),
              ),
              if (_coverError != null) ...[
                const SizedBox(height: 6),
                Text(
                  _coverError!,
                  style: BkoTheme.fontLato(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],

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
                  DropdownMenuItem(
                      value: 'bm', child: Text('Bambara (Bamanankan)')),
                  DropdownMenuItem(
                      value: 'ff', child: Text('Foulfouldé (Peul)')),
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
                            'CRÉER LE BROUILLON',
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
            color: selected
                ? BkoTheme.goldAccent.withValues(alpha: 0.15)
                : bgElevated,
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
                color: selected
                    ? BkoTheme.goldAccent
                    : BkoTheme.getTextSecondary(context),
                size: 20,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: BkoTheme.fontLato(
                  fontSize: 11,
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
