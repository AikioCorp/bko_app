import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/bko_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Apple-inspired spring-like entrance animation (700ms)
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _scaleAnimation = Tween<double>(begin: 0.82, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.fastOutSlowIn),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.forward();

    // Auto navigate after 2.2s to Onboarding
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (mounted) {
        context.go('/onboarding');
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BkoTheme.bgObsidian,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Minimal Logo Container with Apple-style subtle depth
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: BkoTheme.bgSurface,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: BkoTheme.borderSubtle, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: BkoTheme.goldAccent.withValues(alpha: 0.12),
                        blurRadius: 30,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(26),
                    child: Image.asset(
                      'assets/brand/app_icon.png',
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Center(
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: BkoTheme.goldAccent,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.mic, color: Colors.black, size: 32),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Apple Typography
                const Text(
                  'BKO PODCAST',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.5,
                    color: BkoTheme.textPrimary,
                  ),
                ),

                const SizedBox(height: 8),

                const Text(
                  'Les voix du Mali et d\'Afrique',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.2,
                    color: BkoTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
