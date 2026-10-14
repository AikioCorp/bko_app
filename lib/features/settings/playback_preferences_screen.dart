import '../../core/widgets/app_header_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/network/bko_api.dart';
import '../../core/theme/bko_theme.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/widgets/bko_bounceable.dart';
import '../../core/widgets/bko_haptics.dart';
import '../auth/auth_controller.dart';

class PlaybackPreferencesScreen extends ConsumerStatefulWidget {
  const PlaybackPreferencesScreen({super.key});

  @override
  ConsumerState<PlaybackPreferencesScreen> createState() => _PlaybackPreferencesScreenState();
}

class _PlaybackPreferencesScreenState extends ConsumerState<PlaybackPreferencesScreen> {
  bool _loading = true;
  bool _saving = false;

  // Préférences
  List<String> _selectedLanguages = ['bm', 'fr'];
  String _preferredFormat = 'any'; // 'audio', 'video', 'any'
  double _defaultPlaybackSpeed = 1.0;
  bool _autoPlayNext = true;
  bool _resumePosition = true;
  bool _personalizationEnabled = true;

  static const _kSpeedKey = 'bko_pref_default_playback_speed';
  static const _kAutoPlayKey = 'bko_pref_autoplay_next';
  static const _kResumeKey = 'bko_pref_resume_position';
  static const _kFormatKey = 'bko_pref_format';
  static const _kPersonalizationKey = 'bko_pref_personalization';

  final List<({String code, String name})> _availableLanguages = const [
    (code: 'bm', name: 'Bambara (Bamanankan)'),
    (code: 'fr', name: 'Français'),
    (code: 'ff', name: 'Peul / Fulfulde'),
    (code: 'snk', name: 'Soninké'),
    (code: 'wo', name: 'Wolof'),
    (code: 'en', name: 'Anglais'),
  ];

  final List<double> _speeds = const [0.8, 1.0, 1.25, 1.5, 2.0];

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _defaultPlaybackSpeed = prefs.getDouble(_kSpeedKey) ?? 1.0;
    _autoPlayNext = prefs.getBool(_kAutoPlayKey) ?? true;
    _resumePosition = prefs.getBool(_kResumeKey) ?? true;
    _preferredFormat = prefs.getString(_kFormatKey) ?? 'any';
    _personalizationEnabled = prefs.getBool(_kPersonalizationKey) ?? true;

    final auth = ref.read(authProvider);
    if (auth.isAuthenticated && auth.token != null) {
      try {
        final me = await BkoApi.get('/me', token: auth.token);
        if (me is Map && me['languagePreferences'] is List) {
          final langs = (me['languagePreferences'] as List)
              .map((l) => (l is Map ? l['languageCode'] ?? l['code'] : '').toString())
              .where((c) => c.isNotEmpty)
              .toList();
          if (langs.isNotEmpty) {
            _selectedLanguages = langs;
          }
        }
      } catch (_) {}
    }

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _savePreferences() async {
    setState(() => _saving = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kSpeedKey, _defaultPlaybackSpeed);
    await prefs.setBool(_kAutoPlayKey, _autoPlayNext);
    await prefs.setBool(_kResumeKey, _resumePosition);
    await prefs.setString(_kFormatKey, _preferredFormat);
    await prefs.setBool(_kPersonalizationKey, _personalizationEnabled);

    final auth = ref.read(authProvider);
    if (auth.isAuthenticated && auth.token != null) {
      try {
        await BkoApi.patch(
          '/me/preferences',
          {
            'languageCodes': _selectedLanguages,
          },
          token: auth.token,
        );
      } catch (_) {}
    }

    if (mounted) {
      setState(() => _saving = false);
      BkoHaptics.success();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Préférences d’écoute enregistrées.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: BkoTheme.goldAccent,
        ),
      );
    }
  }

  Future<void> _resetRecommendations() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BkoTheme.getBgSurfaceElevated(ctx),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: BkoTheme.getBorderSubtle(ctx)),
        ),
        title: Text(
          'Réinitialiser les recommandations',
          style: BkoTheme.fontLato(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: BkoTheme.getTextPrimary(ctx),
          ),
        ),
        content: Text(
          'Votre historique de suggestions sera remis à zéro. Vos préférences de langues et vos abonnements seront conservés.',
          style: BkoTheme.fontLato(
            fontSize: 13,
            color: BkoTheme.getTextSecondary(ctx),
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Annuler',
              style: BkoTheme.fontLato(color: BkoTheme.getTextSecondary(ctx), fontWeight: FontWeight.w700),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: BkoTheme.goldAccent,
              foregroundColor: Colors.black,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              'Réinitialiser',
              style: BkoTheme.fontLato(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final auth = ref.read(authProvider);
      if (auth.token != null) {
        try {
          await BkoApi.post('/taste-profile/reset', {}, token: auth.token);
        } catch (_) {}
      }
      BkoHaptics.success();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profil de recommandations réinitialisé.'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: BkoTheme.goldAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textPri = BkoTheme.getTextPrimary(context);
    final textSec = BkoTheme.getTextSecondary(context);
    final surface = BkoTheme.getBgSurface(context);
    final surfaceElevated = BkoTheme.getBgSurfaceElevated(context);
    final border = BkoTheme.getBorderSubtle(context);

    return Scaffold(
      backgroundColor: BkoTheme.getBgObsidian(context),
      appBar: AppBar(
        actions: const [AppHeaderActions()],
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const AppBackButton(),
        title: Text(
          'Préférences d\'écoute',
          style: BkoTheme.fontPoppins(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: textPri,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: BkoTheme.goldAccent))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
              children: [
                // 1. Langues d'écoute
                _sectionTitle('LANGUES D\'ÉCOUTE', textSec),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sélectionnez les langues que vous comprenez pour filtrer les émissions du catalogue.',
                        style: BkoTheme.fontLato(fontSize: 12.5, color: textSec, height: 1.4),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _availableLanguages.map((lang) {
                          final isSelected = _selectedLanguages.contains(lang.code);
                          return BkoBounceable(
                            onTap: () {
                              BkoHaptics.select();
                              setState(() {
                                if (isSelected) {
                                  if (_selectedLanguages.length > 1) {
                                    _selectedLanguages.remove(lang.code);
                                  }
                                } else {
                                  _selectedLanguages.add(lang.code);
                                }
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected ? BkoTheme.goldAccent.withValues(alpha: 0.15) : surfaceElevated,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected ? BkoTheme.goldAccent : border,
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              child: Text(
                                lang.name,
                                style: BkoTheme.fontLato(
                                  fontSize: 12.5,
                                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                  color: isSelected ? BkoTheme.goldAccent : textPri,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // 2. Vitesse audio par défaut
                _sectionTitle('VITESSE DE LECTURE PAR DÉFAUT', textSec),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Vitesse appliquée automatiquement au lancement d\'un nouvel épisode.',
                        style: BkoTheme.fontLato(fontSize: 12.5, color: textSec),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: _speeds.map((speed) {
                          final isCurrent = _defaultPlaybackSpeed == speed;
                          return BkoBounceable(
                            onTap: () {
                              BkoHaptics.select();
                              setState(() => _defaultPlaybackSpeed = speed);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: isCurrent ? BkoTheme.goldAccent : surfaceElevated,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isCurrent ? BkoTheme.goldAccent : border,
                                ),
                              ),
                              child: Text(
                                '${speed}x',
                                style: BkoTheme.fontLato(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: isCurrent ? Colors.black : textPri,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // 3. Comportement du lecteur
                _sectionTitle('COMPORTEMENT DU LECTEUR', textSec),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: border),
                  ),
                  child: Column(
                    children: [
                      SwitchListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        activeThumbColor: BkoTheme.goldAccent,
                        title: Text(
                          'Lecture automatique suivante',
                          style: BkoTheme.fontLato(fontSize: 13.5, fontWeight: FontWeight.w700, color: textPri),
                        ),
                        subtitle: Text(
                          'Enchaîne automatiquement sur l\'épisode suivant de l\'émission.',
                          style: BkoTheme.fontLato(fontSize: 11.5, color: textSec),
                        ),
                        value: _autoPlayNext,
                        onChanged: (val) {
                          BkoHaptics.select();
                          setState(() => _autoPlayNext = val);
                        },
                      ),
                      Divider(color: border, height: 1),
                      SwitchListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        activeThumbColor: BkoTheme.goldAccent,
                        title: Text(
                          'Reprendre à la dernière position',
                          style: BkoTheme.fontLato(fontSize: 13.5, fontWeight: FontWeight.w700, color: textPri),
                        ),
                        subtitle: Text(
                          'Mémorise l\'instant précis où vous avez interrompu l\'écoute.',
                          style: BkoTheme.fontLato(fontSize: 11.5, color: textSec),
                        ),
                        value: _resumePosition,
                        onChanged: (val) {
                          BkoHaptics.select();
                          setState(() => _resumePosition = val);
                        },
                      ),
                      Divider(color: border, height: 1),
                      SwitchListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        activeThumbColor: BkoTheme.goldAccent,
                        title: Text(
                          'Personnalisation algorithmique',
                          style: BkoTheme.fontLato(fontSize: 13.5, fontWeight: FontWeight.w700, color: textPri),
                        ),
                        subtitle: Text(
                          'Affine les suggestions de l\'accueil selon vos écoutes réelles.',
                          style: BkoTheme.fontLato(fontSize: 11.5, color: textSec),
                        ),
                        value: _personalizationEnabled,
                        onChanged: (val) {
                          BkoHaptics.select();
                          setState(() => _personalizationEnabled = val);
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // 4. Réinitialisation
                _sectionTitle('GESTION DE L\'ALGORITHME', textSec),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Remettre à zéro l\'algorithme',
                              style: BkoTheme.fontLato(fontSize: 13.5, fontWeight: FontWeight.w700, color: textPri),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Efface le profil d\'apprentissage sans affecter votre bibliothèque.',
                              style: BkoTheme.fontLato(fontSize: 11.5, color: textSec),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      BkoBounceable(
                        onTap: _resetRecommendations,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: surfaceElevated,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: border),
                          ),
                          child: Text(
                            'Réinitialiser',
                            style: BkoTheme.fontLato(fontSize: 12, fontWeight: FontWeight.w800, color: textPri),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Bouton Enregistrer
                BkoBounceable(
                  onTap: _saving ? () {} : _savePreferences,
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: BkoTheme.goldAccent,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    alignment: Alignment.center,
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                          )
                        : Text(
                            'Enregistrer les préférences',
                            style: BkoTheme.fontPoppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.black,
                            ),
                          ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _sectionTitle(String title, Color textSec) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        title,
        style: BkoTheme.fontLato(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: textSec,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
