import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import '../../core/network/bko_api.dart';
import '../../core/theme/bko_theme.dart';
import '../../core/widgets/bko_bounceable.dart';
import '../../core/widgets/bko_haptics.dart';
import '../../core/widgets/equalizer_loader.dart';
import '../../core/widgets/notification_permission_primer.dart';
import '../auth/auth_controller.dart';

class UserTasteOnboardingScreen extends ConsumerStatefulWidget {
  final bool isEditing;
  final String? redirect;

  const UserTasteOnboardingScreen({
    super.key,
    this.isEditing = false,
    this.redirect,
  });

  @override
  ConsumerState<UserTasteOnboardingScreen> createState() =>
      _UserTasteOnboardingScreenState();
}

class _UserTasteOnboardingScreenState
    extends ConsumerState<UserTasteOnboardingScreen> {
  int _currentStep = 0; // 0: Langues, 1: Centres d'intérêt, 2: Émissions
  bool _isLoadingData = true;
  bool _isSubmitting = false;
  bool _referentialsReady = false;
  String? _errorMessage;

  // Données référentielles
  List<Map<String, dynamic>> _languages = [];
  List<Map<String, dynamic>> _topics = [];
  List<Map<String, dynamic>> _podcasts = [];

  // Sélections utilisateur
  final Set<String> _selectedLanguageCodes = {};
  final Set<String> _selectedTopicIds = {};
  final Set<String> _selectedPodcastIds = {};

  @override
  void initState() {
    super.initState();
    _loadReferentials();
  }

  List<Map<String, dynamic>> _referentialList(dynamic value) {
    final items = value is List
        ? value
        : value is Map && value['data'] is List
            ? value['data'] as List
            : throw const FormatException('Référentiel invalide');
    return items.whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item)).toList();
  }
  Future<void> _loadReferentials() async {
    setState(() {
      _isLoadingData = true;
      _referentialsReady = false;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        BkoApi.get('/languages?hasContent=true'),
        BkoApi.get('/topics?hasContent=true'),
        BkoApi.get('/podcasts?limit=25&hasContent=true'),
      ]);
      if (!mounted) return;
      // Conserver uniquement les langues ayant des podcasts
      _languages = _referentialList(results[0]).where((item) {
        final count = item['_count'];
        if (count is Map) {
          final primary = (count['primaryPodcasts'] as num?)?.toInt() ?? 0;
          final pods = (count['podcasts'] as num?)?.toInt() ?? 0;
          return (primary + pods) > 0;
        }
        return true;
      }).toList();

      // Conserver uniquement les sujets ayant des podcasts ou des épisodes
      _topics = _referentialList(results[1]).where((item) {
        final count = item['_count'];
        if (count is Map) {
          final podcasts = (count['podcasts'] as num?)?.toInt() ?? 0;
          final episodes = (count['episodes'] as num?)?.toInt() ?? 0;
          return (podcasts + episodes) > 0;
        }
        return true;
      }).toList();

      // Conserver uniquement les podcasts ayant des épisodes publiés
      _podcasts = _referentialList(results[2]).where((p) {
        final count = p['_count'];
        if (count is Map) {
          final episodes = (count['episodes'] as num?)?.toInt() ?? 0;
          return episodes > 0;
        }
        final episodesList = p['episodes'];
        if (episodesList is List) {
          return episodesList.isNotEmpty;
        }
        return true;
      }).toList();

      _selectedLanguageCodes.retainAll(_languages.map((item) => item['code'].toString()));
      _selectedTopicIds.retainAll(_topics.map((item) => item['id'].toString()));
      _selectedPodcastIds.retainAll(_podcasts.map((item) => item['id'].toString()));
      // Si mode édition, charger les préférences existantes de l'utilisateur
      if (widget.isEditing) {
        final auth = ref.read(authProvider);
        if (auth.token != null) {
          try {
            final me = await BkoApi.get('/me', token: auth.token);
            if (me is Map) {
              if (me['languagePreferences'] is List) {
                final lp = me['languagePreferences'] as List;
                _selectedLanguageCodes.clear();
                for (final item in lp) {
                  if (item is Map && item['languageCode'] != null) {
                    _selectedLanguageCodes.add(item['languageCode'].toString());
                  }
                }
              }
              if (me['topicPreferences'] is List) {
                final tp = me['topicPreferences'] as List;
                _selectedTopicIds.clear();
                for (final item in tp) {
                  if (item is Map && item['topicId'] != null) {
                    _selectedTopicIds.add(item['topicId'].toString());
                  }
                }
              }
            }
          } catch (_) {
            rethrow;
          }
        } else {
          throw const ApiException('Connectez-vous pour modifier vos préférences.', statusCode: 401);
        }
      }
      _referentialsReady = true;
    } catch (e) {
      if (!mounted) return;
      _errorMessage = 'Impossible de charger les langues et les thèmes depuis le serveur. Réessayez.';
    } finally {
      if (mounted) {
        setState(() => _isLoadingData = false);
      }
    }
  }

  void _nextStep() {
    BkoHaptics.light();
    if (_currentStep < 2) {
      setState(() => _currentStep++);
    } else {
      _complete();
    }
  }

  void _previousStep() {
    BkoHaptics.light();
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    } else if (widget.isEditing) {
      context.pop();
    }
  }

  Future<void> _complete() async {
    if (!_referentialsReady) {
      setState(() => _errorMessage = 'Rechargez les langues et les thèmes avant d\'enregistrer.');
      return;
    }
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final auth = ref.read(authProvider);
      if (!auth.isAuthenticated || auth.token == null || auth.token!.isEmpty) {
        throw const ApiException('Connectez-vous pour enregistrer vos préférences.', statusCode: 401);
      }
      await BkoApi.post('/recommendations/onboarding', {
        'languageCodes': _selectedLanguageCodes.toList(),
        'topicIds': _selectedTopicIds.toList(),
        'podcastIds': _selectedPodcastIds.toList(),
      }, token: auth.token);

      // Mettre à jour l'état local auth
      final currentUser = ref.read(authProvider).user;
      if (currentUser != null) {
        final updatedUser = Map<String, dynamic>.from(currentUser);
        updatedUser['onboardingCompleted'] = true;
        await ref.read(authProvider.notifier).updateUser(updatedUser);
      }

      if (!mounted) return;
      if (widget.isEditing) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vos préférences ont été mises à jour avec succès.'),
            backgroundColor: Color(0xFF15803D),
          ),
        );
        context.pop();
      } else {
        await NotificationPermissionPrimer.show(context);
        if (!mounted) return;
        final target = (widget.redirect != null &&
                widget.redirect!.isNotEmpty &&
                widget.redirect != '/login')
            ? widget.redirect!
            : '/';
        context.go(target);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = e is ApiException
            ? (e.statusCode == 401
                ? 'Votre session a expiré. Reconnectez-vous pour enregistrer vos préférences.'
                : e.message)
            : 'Impossible d\'enregistrer vos préférences. Réessayez.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0B0B),
        elevation: 0,
        leading: _currentStep > 0 || widget.isEditing
            ? IconButton(
                icon: const Icon(
                  IconsaxPlusLinear.arrow_left_1,
                  color: Color(0xFFB8B8B8),
                  size: 22,
                ),
                onPressed: _previousStep,
              )
            : null,
        title: Text(
          widget.isEditing ? 'Préférences d\'écoute' : 'Personnalisation',
          style: BkoTheme.fontPoppins(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        actions: [
          if (!widget.isEditing)
            TextButton(
              onPressed: _isSubmitting ? null : _complete,
              child: Text(
                'Passer',
                style: BkoTheme.fontPoppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF888888),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: _isLoadingData
            ? const Center(
                child: EqualizerLoader(size: 24, color: BkoTheme.goldAccent),
              )
            : Column(
                children: [
                  // Step Indicator
                  if (!widget.isEditing) _buildStepProgress(),

                  // Error banner if any
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B1214),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF7F1D1D)),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: BkoTheme.fontPoppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFFFECACA),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),

                  if (_errorMessage != null)
                    TextButton(
                      onPressed: _isSubmitting ? null : _loadReferentials,
                      child: const Text('Recharger les langues et les thèmes'),
                    ),

                  // Step Content
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: _buildCurrentStepContent(),
                    ),
                  ),

                  // Bottom Action Bar
                  _buildBottomBar(),
                ],
              ),
      ),
    );
  }

  Widget _buildStepProgress() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(3, (index) {
              final isActive = index <= _currentStep;
              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: index < 2 ? 8 : 0),
                  height: 4,
                  decoration: BoxDecoration(
                    color: isActive ? BkoTheme.goldAccent : const Color(0xFF262626),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          Text(
            'Étape ${_currentStep + 1} sur 3',
            style: BkoTheme.fontPoppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF888888),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildLanguagesStep();
      case 1:
        return _buildTopicsStep();
      case 2:
      default:
        return _buildPodcastsStep();
    }
  }

  // --- ÉTAPE 1 : LANGUES D'ÉCOUTE ---
  Widget _buildLanguagesStep() {
    return SingleChildScrollView(
      key: const ValueKey('step_languages'),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Quelles langues écoutez-vous ?',
            style: BkoTheme.fontPoppins(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Sélectionnez une ou plusieurs langues pour que nous puissions adapter les épisodes à vos préférences.',
            style: BkoTheme.fontPoppins(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              height: 1.45,
              color: const Color(0xFFB8B8B8),
            ),
          ),
          const SizedBox(height: 24),
          if (_languages.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF121212),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF262626)),
              ),
              child: Text(
                'Aucune langue avec du contenu disponible pour le moment.',
                textAlign: TextAlign.center,
                style: BkoTheme.fontPoppins(
                  fontSize: 13,
                  color: const Color(0xFF888888),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _languages.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final lang = _languages[index];
              final code = lang['code']?.toString() ?? '';
              final name = lang['name']?.toString() ?? code;
              final nativeName = lang['nativeName']?.toString();
              final isSelected = _selectedLanguageCodes.contains(code);

              return BkoBounceable(
                onTap: () {
                  BkoHaptics.light();
                  setState(() {
                    if (isSelected) {
                      if (_selectedLanguageCodes.length > 1) {
                        _selectedLanguageCodes.remove(code);
                      }
                    } else {
                      _selectedLanguageCodes.add(code);
                    }
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF19160E) : const Color(0xFF121212),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? BkoTheme.goldAccent : const Color(0xFF262626),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected ? BkoTheme.goldAccent : const Color(0xFF1E1E1E),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          code.toUpperCase(),
                          style: BkoTheme.fontPoppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: isSelected ? Colors.black : const Color(0xFFCCCCCC),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: BkoTheme.fontPoppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            if (nativeName != null && nativeName != name)
                              Text(
                                nativeName,
                                style: BkoTheme.fontPoppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                  color: const Color(0xFF888888),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Icon(
                        isSelected
                            ? IconsaxPlusBold.tick_circle
                            : IconsaxPlusLinear.add_circle,
                        color: isSelected ? BkoTheme.goldAccent : const Color(0xFF555555),
                        size: 22,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // --- ÉTAPE 2 : CENTRES D'INTÉRÊT ---
  Widget _buildTopicsStep() {
    return SingleChildScrollView(
      key: const ValueKey('step_topics'),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Vos centres d\'intérêt',
            style: BkoTheme.fontPoppins(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Choisissez les thèmes qui vous passionnent. Nous vous conseillons d\'en choisir au moins 3 pour personnaliser votre découverte.',
            style: BkoTheme.fontPoppins(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              height: 1.45,
              color: const Color(0xFFB8B8B8),
            ),
          ),
          const SizedBox(height: 20),
          if (_topics.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF121212),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF262626)),
              ),
              child: Text(
                'Aucun centre d\'intérêt avec du contenu disponible pour le moment.',
                textAlign: TextAlign.center,
                style: BkoTheme.fontPoppins(
                  fontSize: 13,
                  color: const Color(0xFF888888),
                ),
              ),
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _topics.map((topic) {
              final id = topic['id']?.toString() ?? topic['slug']?.toString() ?? '';
              final name = topic['name']?.toString() ?? 'Sujet';
              final isSelected = _selectedTopicIds.contains(id);

              return BkoBounceable(
                onTap: () {
                  BkoHaptics.light();
                  setState(() {
                    if (isSelected) {
                      _selectedTopicIds.remove(id);
                    } else {
                      _selectedTopicIds.add(id);
                    }
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF19160E) : const Color(0xFF141414),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? BkoTheme.goldAccent : const Color(0xFF262626),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isSelected ? IconsaxPlusBold.tick_circle : IconsaxPlusBold.hashtag,
                        size: 15,
                        color: isSelected ? BkoTheme.goldAccent : const Color(0xFF888888),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        name,
                        style: BkoTheme.fontPoppins(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? Colors.white : const Color(0xFFCCCCCC),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // --- ÉTAPE 3 : ÉMISSIONS À SUIVRE ---
  Widget _buildPodcastsStep() {
    return SingleChildScrollView(
      key: const ValueKey('step_podcasts'),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Émissions recommandées',
            style: BkoTheme.fontPoppins(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Suivez vos premières émissions pour que leurs nouveaux épisodes apparaissent directement dans votre flux.',
            style: BkoTheme.fontPoppins(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              height: 1.45,
              color: const Color(0xFFB8B8B8),
            ),
          ),
          const SizedBox(height: 20),
          if (_podcasts.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF121212),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF262626)),
              ),
              child: Text(
                'Aucune émission avec des épisodes disponible pour le moment. Vous pourrez suivre des émissions depuis l\'accueil à tout moment.',
                textAlign: TextAlign.center,
                style: BkoTheme.fontPoppins(
                  fontSize: 13,
                  color: const Color(0xFF888888),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _podcasts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final p = _podcasts[index];
                final id = p['id']?.toString() ?? '';
                final name = p['name']?.toString() ?? 'Émission';
                final desc = p['description']?.toString() ?? '';
                final cover = p['cover']?.toString();
                final isFollowed = _selectedPodcastIds.contains(id);
                final epCount = ((p['_count']?['episodes'] as num?)?.toInt()) ??
                    (p['episodes'] is List ? (p['episodes'] as List).length : null);

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF121212),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isFollowed ? BkoTheme.goldAccent.withValues(alpha: 0.5) : const Color(0xFF262626),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Cover
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: 52,
                          height: 52,
                          color: const Color(0xFF1E1E1E),
                          child: cover != null && cover.isNotEmpty
                              ? Image.network(
                                  cover,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    IconsaxPlusBold.microphone_2,
                                    color: BkoTheme.goldAccent,
                                    size: 24,
                                  ),
                                )
                              : const Icon(
                                  IconsaxPlusBold.microphone_2,
                                  color: BkoTheme.goldAccent,
                                  size: 24,
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: BkoTheme.fontPoppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            if (epCount != null && epCount > 0) ...[
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  const Icon(IconsaxPlusLinear.play, size: 10, color: BkoTheme.goldAccent),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$epCount ${epCount > 1 ? 'épisodes' : 'épisode'}',
                                    style: BkoTheme.fontPoppins(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: BkoTheme.goldAccent,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (desc.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                desc,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: BkoTheme.fontPoppins(
                                  fontSize: 11.5,
                                  color: const Color(0xFF888888),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Follow toggle button
                      BkoBounceable(
                        onTap: () {
                          BkoHaptics.light();
                          setState(() {
                            if (isFollowed) {
                              _selectedPodcastIds.remove(id);
                            } else {
                              _selectedPodcastIds.add(id);
                            }
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: isFollowed ? BkoTheme.goldAccent : const Color(0xFF1E1E1E),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isFollowed ? BkoTheme.goldAccent : const Color(0xFF333333),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isFollowed ? IconsaxPlusBold.tick_circle : IconsaxPlusLinear.add,
                                size: 13,
                                color: isFollowed ? Colors.black : Colors.white,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                isFollowed ? 'Suivi' : 'Suivre',
                                style: BkoTheme.fontPoppins(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: isFollowed ? Colors.black : Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // --- BARRE D'ACTION INFÉRIEURE ---
  Widget _buildBottomBar() {
    final isLastStep = _currentStep == 2;
    final actionLabel = widget.isEditing
        ? 'Enregistrer les modifications'
        : (isLastStep ? 'Découvrir mon accueil' : 'Continuer');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF0F0F0F),
        border: Border(top: BorderSide(color: Color(0xFF1E1E1E))),
      ),
      child: Row(
        children: [
          if (!widget.isEditing && !isLastStep)
            TextButton(
              onPressed: _isSubmitting ? null : _nextStep,
              child: Text(
                'Passer cette étape',
                style: BkoTheme.fontPoppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF777777),
                ),
              ),
            ),
          const Spacer(),
          SizedBox(
            height: 48,
            child: BkoBounceable(
              onTap: _isSubmitting ? null : (widget.isEditing ? _complete : _nextStep),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _isSubmitting
                      ? BkoTheme.goldAccent.withValues(alpha: 0.5)
                      : BkoTheme.goldAccent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: _isSubmitting
                    ? const EqualizerLoader(size: 16, color: Colors.black)
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            actionLabel,
                            style: BkoTheme.fontPoppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.black,
                            ),
                          ),
                          if (!widget.isEditing && !isLastStep) ...[
                            const SizedBox(width: 8),
                            const Icon(
                              IconsaxPlusLinear.arrow_right_3,
                              size: 15,
                              color: Colors.black,
                            ),
                          ],
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
