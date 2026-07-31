import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/bko_theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  late AnimationController _iconAnimationController;

  final List<_OnboardingData> _slides = const [
    _OnboardingData(
      step: '01 / 03',
      badge: 'CULTURE & ACTUALITÉ',
      title: 'Les voix qui font bouger Bamako.',
      description: 'Accédez aux récits, débats, musiques et interviews des créateurs les plus influents du Mali et de la sous-région.',
      iconType: _IconType.audioWave,
    ),
    _OnboardingData(
      step: '02 / 03',
      badge: 'EXPÉRIENCE MULTIMÉDIA',
      title: 'En fond sonore ou en vidéo HD.',
      description: 'Écoutez vos podcasts en arrière-plan pendant vos déplacements, ou basculez en vidéo HD en un clic.',
      iconType: _IconType.videoStream,
    ),
    _OnboardingData(
      step: '03 / 03',
      badge: 'PATRIMOINE LOCAL',
      title: 'Vos émissions en Bamanankan & Français.',
      description: 'Découvrez des contenus authentiques en Bambara et en Français, pensés pour tous les auditeurs.',
      iconType: _IconType.languageCulture,
    ),
  ];

  @override
  void initState() {
    super.initState();
    // Continuous subtle Apple-style breath animation for icons
    _iconAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _iconAnimationController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentIndex < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Minimal Top Navigation: Step Badge & Skip
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _slides[_currentIndex].step,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'monospace',
                      color: BkoTheme.goldAccent,
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.go('/'),
                    style: TextButton.styleFrom(
                      foregroundColor: BkoTheme.textSecondary,
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Passer',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),

              const Spacer(),

              // Animated Minimal Icon & Content PageView
              SizedBox(
                height: 380,
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
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Animated Sleek Minimal Icon Header
                        _AnimatedMinimalIcon(
                          iconType: slide.iconType,
                          controller: _iconAnimationController,
                        ),

                        const SizedBox(height: 32),

                        // Contextual Category Badge
                        Text(
                          slide.badge,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2.0,
                            color: BkoTheme.goldAccent,
                          ),
                        ),

                        const SizedBox(height: 10),

                        // Apple Display Title
                        Text(
                          slide.title,
                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.8,
                            height: 1.12,
                            color: BkoTheme.textPrimary,
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Context-tailored Description
                        Text(
                          slide.description,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            height: 1.45,
                            color: BkoTheme.textSecondary,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

              const Spacer(),

              // Bottom Section: Dots & Action Button
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Dot Indicator
                  Row(
                    children: List.generate(
                      _slides.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.fastOutSlowIn,
                        margin: const EdgeInsets.only(right: 6),
                        width: _currentIndex == index ? 22 : 6,
                        height: 4,
                        decoration: BoxDecoration(
                          color: _currentIndex == index ? BkoTheme.goldAccent : BkoTheme.borderStrong,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Minimal Action Button
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
                  const SizedBox(height: 12),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _IconType { audioWave, videoStream, languageCulture }

class _OnboardingData {
  final String step;
  final String badge;
  final String title;
  final String description;
  final _IconType iconType;

  const _OnboardingData({
    required this.step,
    required this.badge,
    required this.title,
    required this.description,
    required this.iconType,
  });
}

class _AnimatedMinimalIcon extends StatelessWidget {
  final _IconType iconType;
  final AnimationController controller;

  const _AnimatedMinimalIcon({
    required this.iconType,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final scaleValue = 0.95 + (controller.value * 0.10); // 0.95 -> 1.05 breath
        final translationY = -4.0 * controller.value; // -4px float

        return Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: BkoTheme.bgSurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: BkoTheme.borderSubtle),
          ),
          child: Center(
            child: Transform.translate(
              offset: Offset(0, translationY),
              child: Transform.scale(
                scale: scaleValue,
                child: _buildIconContent(),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildIconContent() {
    switch (iconType) {
      case _IconType.audioWave:
        return const Icon(
          Icons.graphic_eq_rounded,
          color: BkoTheme.goldAccent,
          size: 34,
        );
      case _IconType.videoStream:
        return const Icon(
          Icons.play_circle_outline_rounded,
          color: BkoTheme.goldAccent,
          size: 34,
        );
      case _IconType.languageCulture:
        return const Icon(
          Icons.record_voice_over_outlined,
          color: BkoTheme.goldAccent,
          size: 34,
        );
    }
  }
}
