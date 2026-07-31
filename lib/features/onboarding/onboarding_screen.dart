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

  final List<_MinimalSlide> _slides = const [
    _MinimalSlide(
      step: '01 / 03',
      title: 'Le son & l\'image du Mali.',
      description: 'Découvrez les meilleures productions audio et vidéo créées par la communauté malienne et africaine.',
    ),
    _MinimalSlide(
      step: '02 / 03',
      title: 'Une expérience sans coupure.',
      description: 'Basculez librement du flux audio haute fidélité aux sessions vidéo exclusives sans interrompre votre écoute.',
    ),
    _MinimalSlide(
      step: '03 / 03',
      title: 'En Bamanankan & Français.',
      description: 'Conservez le lien avec votre culture, vos langues et vos voix préférées où que vous soyez.',
    ),
  ];

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
              // Minimal Top Header: Counter & Skip
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
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),

              const Spacer(),

              // Ultra-Minimalist PageView Content (Pure Typography & Space)
              SizedBox(
                height: 280,
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
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          slide.title,
                          style: const TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.0,
                            height: 1.10,
                            color: BkoTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          slide.description,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                            height: 1.5,
                            color: BkoTheme.textSecondary,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

              const Spacer(),

              // Bottom Bar: Dots & Minimal Action Button
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sleek Dot Indicator
                  Row(
                    children: List.generate(
                      _slides.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.fastOutSlowIn,
                        margin: const EdgeInsets.only(right: 6),
                        width: _currentIndex == index ? 20 : 6,
                        height: 4,
                        decoration: BoxDecoration(
                          color: _currentIndex == index ? BkoTheme.goldAccent : BkoTheme.borderStrong,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

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

class _MinimalSlide {
  final String step;
  final String title;
  final String description;

  const _MinimalSlide({
    required this.step,
    required this.title,
    required this.description,
  });
}
