import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/bko_theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  final List<_OnboardingItem> _slides = const [
    _OnboardingItem(
      badge: 'SÉLECTION NATIONALE',
      title: 'Découvrez le meilleur du podcast au Mali.',
      description: 'Une immersion exclusive au cœur des voix, récits et conversations qui façonnent le Mali d\'aujourd\'hui.',
      icon: Icons.graphic_eq_rounded,
    ),
    _OnboardingItem(
      badge: 'EXPÉRIENCE IMMERSIVE',
      title: 'Écoutez & Regardez vos émissions.',
      description: 'Passez instantanément du flux audio haute fidélité aux sessions vidéo exclusives sans interruption.',
      icon: Icons.play_circle_fill_rounded,
    ),
    _OnboardingItem(
      badge: 'PATRIMOINE AUDIO',
      title: 'En Bamanankan & Français.',
      description: 'Explorez la richesse des contenus enregistrés en Bamanankan et restez connecté aux créateurs de la région.',
      icon: Icons.radio_rounded,
    ),
  ];

  void _nextPage() {
    if (_currentIndex < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.fastOutSlowIn,
      );
    } else {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BkoTheme.bgObsidian,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar: Skip Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'BKO PODCAST',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                      color: BkoTheme.textMuted,
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.go('/'),
                    style: TextButton.styleFrom(
                      foregroundColor: BkoTheme.textSecondary,
                      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    child: const Text('Passer'),
                  ),
                ],
              ),
            ),

            // PageView Slide Content
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
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Apple-style Minimal Visual Card
                        Container(
                          width: double.infinity,
                          height: 240,
                          decoration: BoxDecoration(
                            color: BkoTheme.bgSurface,
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(color: BkoTheme.borderSubtle),
                          ),
                          child: Center(
                            child: Container(
                              width: 88,
                              height: 88,
                              decoration: BoxDecoration(
                                color: BkoTheme.goldAccent.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Icon(
                                slide.icon,
                                size: 44,
                                color: BkoTheme.goldAccent,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 36),

                        // Editorial Badge
                        Text(
                          slide.badge,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2.0,
                            color: BkoTheme.goldAccent,
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Apple Display Title
                        Text(
                          slide.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                            height: 1.15,
                            color: BkoTheme.textPrimary,
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Subtitle Description
                        Text(
                          slide.description,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            height: 1.45,
                            color: BkoTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Bottom Navigation & Controls
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Smooth Page Indicator
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _slides.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.fastOutSlowIn,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentIndex == index ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentIndex == index ? BkoTheme.goldAccent : BkoTheme.borderStrong,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Main Action Button (Apple Touch Feedback)
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
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.2,
                        ),
                      ),
                      child: Text(
                        _currentIndex == _slides.length - 1 ? 'COMMENCER L\'EXPÉRIENCE' : 'CONTINUER',
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

class _OnboardingItem {
  final String badge;
  final String title;
  final String description;
  final IconData icon;

  const _OnboardingItem({
    required this.badge,
    required this.title,
    required this.description,
    required this.icon,
  });
}
