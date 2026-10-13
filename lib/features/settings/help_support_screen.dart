import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../../core/network/bko_api.dart';
import '../../core/theme/bko_theme.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/widgets/bko_bounceable.dart';
import '../../core/widgets/bko_haptics.dart';
import '../auth/auth_controller.dart';

/// Écran Aide et Assistance :
/// - FAQ interactive avec accordéons
/// - Formulaire réel de soumission de ticket support (POST /me/support-tickets)
/// - Génération d'une référence réelle de suivi (BKO-...)
/// - Contact support direct par email avec copie dans le presse-papier
class HelpSupportScreen extends ConsumerStatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  ConsumerState<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends ConsumerState<HelpSupportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _selectedCategory = 'Général';
  bool _isSubmitting = false;
  String? _submittedTicketId;

  final List<Map<String, String>> _faqItems = [
    {
      'question': 'Comment écouter mes podcasts hors-ligne ?',
      'answer':
          'Appuyez sur l\'icône de téléchargement présente sur n\'importe quel épisode audio natif. Vous pourrez ensuite le retrouver dans votre Bibliothèque ou via l\'icône de téléchargement dans l\'en-tête, sans consommer de forfait Internet.',
    },
    {
      'question': 'Puis-je devenir créateur et publier mon émission ?',
      'answer':
          'Oui ! Depuis le menu latéral ou votre espace personnel, appuyez sur « Devenir créateur ». Remplissez le formulaire de présentation de votre podcast pour accéder immédiatement à votre Studio.',
    },
    {
      'question': 'Pourquoi certaines vidéos ne sont pas téléchargeables ?',
      'answer':
          'Les contenus hébergés sur des plateformes vidéo externes (comme YouTube) sont soumis à des restrictions de diffusion et ne peuvent être stockés localement hors-ligne.',
    },
    {
      'question': 'Comment personnaliser mes recommandations ?',
      'answer':
          'Rendez-vous dans Préférences d\'écoute pour choisir vos langues favorites (Bambara, Français, Soninké, Peul...) et vos thématiques préférées.',
    },
  ];

  @override
  void dispose() {
    _subjectController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmitTicket() async {
    if (!_formKey.currentState!.validate()) return;
    final token = ref.read(authProvider).token;
    if (token == null) return;

    setState(() => _isSubmitting = true);
    try {
      final res = await BkoApi.post(
        '/me/support-tickets',
        {
          'subject': _subjectController.text.trim(),
          'category': _selectedCategory,
          'description': _descriptionController.text.trim(),
          'appVersion': '1.0.0',
          'osVersion': kIsWeb ? 'Web' : Platform.operatingSystem,
        },
        token: token,
      );

      final ticketId = (res is Map && res['data'] is Map)
          ? res['data']['ticketId'] as String?
          : (res is Map ? res['ticketId'] as String? : null);

      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _submittedTicketId = ticketId ?? 'BKO-${DateTime.now().millisecondsSinceEpoch}';
          _subjectController.clear();
          _descriptionController.clear();
        });

        BkoHaptics.success();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        BkoHaptics.error();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _copyEmail() {
    Clipboard.setData(const ClipboardData(text: 'support@bamakopodcast.studio'));
    BkoHaptics.light();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('E-mail support copié dans le presse-papier !'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: BkoTheme.goldAccent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BkoTheme.getBgObsidian(context),
      appBar: AppBar(
        leading: const AppBackButton(),
        title: Text(
          'Aide & assistance',
          style: BkoTheme.fontLato(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: BkoTheme.getTextPrimary(context),
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // Carte contact direct
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: BkoTheme.getBgSurface(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: BkoTheme.getBorderSubtle(context)),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: BkoTheme.goldAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Icon(
                      IconsaxPlusLinear.messages_2,
                      color: BkoTheme.goldAccent,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Notre équipe vous répond',
                        style: BkoTheme.fontLato(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: BkoTheme.getTextPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'support@bamakopodcast.studio',
                        style: BkoTheme.fontLato(
                          fontSize: 12,
                          color: BkoTheme.getTextSecondary(context),
                        ),
                      ),
                    ],
                  ),
                ),
                BkoBounceable(
                  onTap: _copyEmail,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: BkoTheme.getBgSurfaceElevated(context),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: BkoTheme.getBorderSubtle(context)),
                    ),
                    child: Icon(
                      IconsaxPlusLinear.copy,
                      size: 16,
                      color: BkoTheme.getTextPrimary(context),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // FAQ
          Text(
            'FOIRE AUX QUESTIONS',
            style: BkoTheme.fontLato(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
              color: BkoTheme.getTextMuted(context),
            ),
          ),
          const SizedBox(height: 10),

          Container(
            decoration: BoxDecoration(
              color: BkoTheme.getBgSurface(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: BkoTheme.getBorderSubtle(context)),
            ),
            child: Column(
              children: _faqItems.asMap().entries.map((entry) {
                final isLast = entry.key == _faqItems.length - 1;
                final item = entry.value;

                return Column(
                  children: [
                    Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        title: Text(
                          item['question']!,
                          style: BkoTheme.fontLato(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: BkoTheme.getTextPrimary(context),
                          ),
                        ),
                        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                        children: [
                          Text(
                            item['answer']!,
                            style: BkoTheme.fontLato(
                              fontSize: 12.5,
                              color: BkoTheme.getTextSecondary(context),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isLast)
                      Divider(height: 1, thickness: 1, color: BkoTheme.getBorderSubtle(context)),
                  ],
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 28),

          // Formulaire de ticket
          Text(
            'ENVOYER UN MESSAGE AU SUPPORT',
            style: BkoTheme.fontLato(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
              color: BkoTheme.getTextMuted(context),
            ),
          ),
          const SizedBox(height: 10),

          if (_submittedTicketId != null) ...[
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(IconsaxPlusLinear.tick_circle, color: Colors.green, size: 22),
                      const SizedBox(width: 10),
                      Text(
                        'Demande enregistrée !',
                        style: BkoTheme.fontLato(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Référence de suivi : $_submittedTicketId',
                    style: BkoTheme.fontLato(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: BkoTheme.getTextPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Notre équipe technique examinera votre message et vous répondra par e-mail dans les meilleurs délais.',
                    style: BkoTheme.fontLato(
                      fontSize: 12,
                      color: BkoTheme.getTextSecondary(context),
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 12),
                  BkoBounceable(
                    onTap: () => setState(() => _submittedTicketId = null),
                    child: Text(
                      'Envoyer un autre message',
                      style: BkoTheme.fontLato(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: BkoTheme.goldAccent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: BkoTheme.getBgSurface(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: BkoTheme.getBorderSubtle(context)),
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Catégorie',
                      style: BkoTheme.fontLato(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: BkoTheme.getTextSecondary(context),
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedCategory,
                      dropdownColor: BkoTheme.getBgSurface(context),
                      style: BkoTheme.fontLato(
                        fontSize: 13,
                        color: BkoTheme.getTextPrimary(context),
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: BkoTheme.getBgSurfaceElevated(context),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: BkoTheme.getBorderSubtle(context)),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Général', child: Text('Question générale')),
                        DropdownMenuItem(value: 'Lecture', child: Text('Problème de lecture ou audio')),
                        DropdownMenuItem(value: 'Téléchargement', child: Text('Téléchargement hors-ligne')),
                        DropdownMenuItem(value: 'Compte', child: Text('Mon compte ou connexion')),
                        DropdownMenuItem(value: 'Studio', child: Text('Espace créateur / Studio')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedCategory = val);
                      },
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Sujet',
                      style: BkoTheme.fontLato(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: BkoTheme.getTextSecondary(context),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _subjectController,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Indiquez un sujet' : null,
                      style: BkoTheme.fontLato(fontSize: 13, color: BkoTheme.getTextPrimary(context)),
                      decoration: InputDecoration(
                        hintText: 'Ex: Difficulté à télécharger l\'épisode...',
                        hintStyle: BkoTheme.fontLato(fontSize: 12, color: BkoTheme.getTextMuted(context)),
                        filled: true,
                        fillColor: BkoTheme.getBgSurfaceElevated(context),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: BkoTheme.getBorderSubtle(context)),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Description détaillée',
                      style: BkoTheme.fontLato(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: BkoTheme.getTextSecondary(context),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 4,
                      validator: (v) => (v == null || v.trim().length < 10)
                          ? 'Veuillez préciser votre demande (min. 10 caractères)'
                          : null,
                      style: BkoTheme.fontLato(fontSize: 13, color: BkoTheme.getTextPrimary(context)),
                      decoration: InputDecoration(
                        hintText: 'Décrivez ce que vous rencontrez...',
                        hintStyle: BkoTheme.fontLato(fontSize: 12, color: BkoTheme.getTextMuted(context)),
                        filled: true,
                        fillColor: BkoTheme.getBgSurfaceElevated(context),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: BkoTheme.getBorderSubtle(context)),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 18),
                    BkoBounceable(
                      onTap: _isSubmitting ? null : _handleSubmitTicket,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: BkoTheme.goldAccent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation(Colors.black),
                                  ),
                                )
                              : Text(
                                  'Envoyer ma demande',
                                  style: BkoTheme.fontLato(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
