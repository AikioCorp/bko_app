import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/bko_theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  late AnimationController _floatController;

  final List<_OnboardingItemData> _slides = const [
    _OnboardingItemData(
      badge: 'DÉCOUVREZ',
      title: 'Les voix du Mali, réunies ici.',
      description: 'Histoires, idées, culture et conversations à découvrir sur une seule plateforme.',
      type: _SlideVisualType.discoveryPortrait,
    ),
    _OnboardingItemData(
      badge: 'ÉCOUTEZ OU REGARDEZ',
      title: 'Votre podcast, à votre façon.',
      description: 'Passez de l’audio à la vidéo et suivez chaque épisode comme vous le souhaitez.',
      type: _SlideVisualType.audioVideoDual,
    ),
    _OnboardingItemData(
      badge: 'DU MALI À L’AFRIQUE',
      title: 'Des voix proches. Des idées sans frontières.',
      description: 'Commencez au Mali, puis explorez les conversations qui font vibrer l’Afrique.',
      type: _SlideVisualType.africanConnection,
    ),
  ];

  @override
  void initState() {
    super.initState();
    // Apple-style continuous gentle floating animation
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _floatController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finishOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_seen_onboarding', true);
    } catch (_) {}
    if (mounted) {
      context.go('/');
    }
  }

  void _nextPage() {
    if (_currentIndex < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.fastOutSlowIn,
      );
    } else {
      _finishOnboarding();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BkoTheme.bgObsidian,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar: Brand & Passer Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: BkoTheme.bgSurface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: BkoTheme.borderSubtle),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(7),
                          child: Image.asset(
                            'assets/brand/app_icon.png',
                            width: 26,
                            height: 26,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => const Icon(
                              Icons.mic,
                              color: BkoTheme.goldAccent,
                              size: 14,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'BKO PODCAST',
                        style: BkoTheme.fontLato(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                          color: BkoTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: _finishOnboarding,
                    style: TextButton.styleFrom(
                      foregroundColor: BkoTheme.textSecondary,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    ),
                    child: Text(
                      'Passer',
                      style: BkoTheme.fontLato(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: BkoTheme.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Main Visual Stage & Typography PageView
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentIndex = index;
                  });
                },
                itemCount: _slides.length,
                itemBuilder: (context, index) {
                  final slide = _slides[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),

                        // Apple-style Visual Stage (Upper stage)
                        Expanded(
                          flex: 5,
                          child: Center(
                            child: _AppleVisualStage(
                              type: slide.type,
                              controller: _floatController,
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Content (Lower stage)
                        Expanded(
                          flex: 4,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Petit titre (Badge)
                              Text(
                                slide.badge,
                                style: BkoTheme.fontLato(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2.0,
                                  color: BkoTheme.goldAccent,
                                ),
                              ),

                              const SizedBox(height: 8),

                              // Titre principal
                              Text(
                                slide.title,
                                style: BkoTheme.fontLato(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5,
                                  height: 1.15,
                                  color: BkoTheme.textPrimary,
                                ),
                              ),

                              const SizedBox(height: 10),

                              // Description
                              Text(
                                slide.description,
                                style: BkoTheme.fontLato(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                  height: 1.45,
                                  color: BkoTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Bottom Section: Dots & Primary Button
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Dot Indicator
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _slides.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.fastOutSlowIn,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentIndex == index ? 24 : 8,
                        height: 4,
                        decoration: BoxDecoration(
                          color: _currentIndex == index ? BkoTheme.goldAccent : BkoTheme.borderStrong,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Bouton Principal
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _nextPage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: BkoTheme.goldAccent,
                        foregroundColor: Colors.black,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        _currentIndex == _slides.length - 1 ? 'Commencer à écouter' : 'Continuer',
                        style: BkoTheme.fontLato(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.2,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _SlideVisualType { discoveryPortrait, audioVideoDual, africanConnection }

class _OnboardingItemData {
  final String badge;
  final String title;
  final String description;
  final _SlideVisualType type;

  const _OnboardingItemData({
    required this.badge,
    required this.title,
    required this.description,
    required this.type,
  });
}

class _AppleVisualStage extends StatelessWidget {
  final _SlideVisualType type;
  final AnimationController controller;

  const _AppleVisualStage({
    required this.type,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final floatY = -6.0 * controller.value;

        return Transform.translate(
          offset: Offset(0, floatY),
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxHeight: 250),
            decoration: BoxDecoration(
              color: BkoTheme.bgSurface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: BkoTheme.borderSubtle),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Stack(
                children: [
                  // Glow Background
                  Positioned(
                    top: -30,
                    right: -30,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: BkoTheme.goldAccent.withValues(alpha: 0.08),
                      ),
                    ),
                  ),

                  // Stage Content
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: _buildVisualForType(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildVisualForType() {
    switch (type) {
      case _SlideVisualType.discoveryPortrait:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Portrait Studio Scene Representation with Bko Logo
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: BkoTheme.bgObsidian,
                shape: BoxShape.circle,
                border: Border.all(color: BkoTheme.goldAccent.withValues(alpha: 0.4), width: 1.5),
              ),
              child: Center(
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    color: BkoTheme.bgSurfaceElevated,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.mic_external_on_rounded, color: BkoTheme.goldAccent, size: 28),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: BkoTheme.bgObsidian,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: BkoTheme.borderSubtle),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: BkoTheme.goldAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Bko Podcast Studio • Mali',
                    style: BkoTheme.fontLato(fontSize: 11, fontWeight: FontWeight.w700, color: BkoTheme.textPrimary),
                  ),
                ],
              ),
            ),
          ],
        );

      case _SlideVisualType.audioVideoDual:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Episode Cover Deck with Audio Wave & Video Player Indicator
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: BkoTheme.bgObsidian,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: BkoTheme.borderSubtle),
              ),
              child: Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: BkoTheme.bgSurfaceElevated,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: BkoTheme.borderSubtle),
                    ),
                    child: const Icon(Icons.graphic_eq_rounded, color: BkoTheme.goldAccent, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Voix de Bamako',
                          style: BkoTheme.fontLato(fontSize: 13, fontWeight: FontWeight.w900, color: BkoTheme.textPrimary),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.volume_up_rounded, color: BkoTheme.textSecondary, size: 14),
                            const SizedBox(width: 4),
                            Text('Audio High Fidelity', style: BkoTheme.fontLato(fontSize: 10, color: BkoTheme.textSecondary)),
                            const SizedBox(width: 10),
                            const Icon(Icons.videocam_rounded, color: BkoTheme.goldAccent, size: 14),
                            const SizedBox(width: 4),
                            Text('Vidéo HD', style: BkoTheme.fontLato(fontSize: 10, color: BkoTheme.goldAccent, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );

      case _SlideVisualType.africanConnection:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.public_rounded, color: BkoTheme.goldAccent, size: 48),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildRegionBadge('🇲🇱 Mali'),
                const SizedBox(width: 8),
                _buildRegionBadge('🇸🇳 Sénégal'),
                const SizedBox(width: 8),
                _buildRegionBadge('🇨🇮 Côte d\'Ivoire'),
              ],
            ),
          ],
        );
    }
  }

  Widget _buildRegionBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: BkoTheme.bgObsidian,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: BkoTheme.borderSubtle),
      ),
      child: Text(
        text,
        style: BkoTheme.fontLato(fontSize: 11, fontWeight: FontWeight.w700, color: BkoTheme.textPrimary),
      ),
    );
  }
}
