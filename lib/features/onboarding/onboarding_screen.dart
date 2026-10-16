import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/bko_theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  final List<_OnboardingSlideData> _slides = const [
    _OnboardingSlideData(
      badge: 'DÉCOUVRIR',
      title: 'Des voix à découvrir. Des histoires à partager.',
      description:
          'Explorez des podcasts, des idées et des conversations selon vos envies.',
      type: _VisualType.discover,
    ),
    _OnboardingSlideData(
      badge: 'ÉCOUTER OU REGARDER',
      title: 'Votre écoute, à votre façon.',
      description:
          'Découvrez des épisodes audio et vidéo, et retrouvez vos contenus préférés.',
      type: _VisualType.listenOrWatch,
    ),
    _OnboardingSlideData(
      badge: 'COMMENCER',
      title: 'Trouvez votre prochaine découverte.',
      description:
          'Parcourez les émissions, suivez celles qui vous plaisent et composez votre bibliothèque.',
      type: _VisualType.start,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _markOnboardingSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_seen_onboarding', true);
    } catch (_) {}
  }

  Future<void> _skipOnboarding() async {
    await _markOnboardingSeen();
    if (mounted) {
      context.go('/');
    }
  }

  Future<void> _finishAndExplore() async {
    await _markOnboardingSeen();
    if (mounted) {
      context.go('/');
    }
  }

  Future<void> _finishAndLogin() async {
    await _markOnboardingSeen();
    if (mounted) {
      context.push('/login');
    }
  }

  void _nextPage() {
    if (_currentIndex < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.fastOutSlowIn,
      );
    } else {
      _finishAndExplore();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BkoTheme.getBgObsidian(context),
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar: Passer Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Semantics(
                    button: true,
                    label: "Passer l'introduction",
                    child: SizedBox(
                      height: 48,
                      child: TextButton(
                        onPressed: _skipOnboarding,
                        style: TextButton.styleFrom(
                          foregroundColor: BkoTheme.getTextSecondary(context),
                          minimumSize: const Size(48, 48),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        child: Text(
                          'Passer',
                          style: BkoTheme.fontPoppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: BkoTheme.getTextSecondary(context),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Page View
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
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          physics: const ClampingScrollPhysics(),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                                minHeight: constraints.maxHeight),
                            child: IntrinsicHeight(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 8),

                                  // Offline Geometric Visual Container
                                  Center(
                                    child: _VisualContainer(type: slide.type),
                                  ),

                                  const SizedBox(height: 24),

                                  // Badge
                                  Text(
                                    slide.badge,
                                    style: BkoTheme.fontPoppins(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 2.0,
                                      color: BkoTheme.getAccent(context),
                                    ),
                                  ),

                                  const SizedBox(height: 8),

                                  // Main Title
                                  Text(
                                    slide.title,
                                    style: BkoTheme.fontPoppins(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.4,
                                      height: 1.25,
                                      color: BkoTheme.getTextPrimary(context),
                                    ),
                                  ),

                                  const SizedBox(height: 12),

                                  // Description
                                  Text(
                                    slide.description,
                                    style: BkoTheme.fontPoppins(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w400,
                                      height: 1.5,
                                      color: BkoTheme.getTextSecondary(context),
                                    ),
                                  ),

                                  const Spacer(),
                                  const SizedBox(height: 12),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),

            // Bottom Section: Indicators & Action Buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Dot Indicator
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _slides.length,
                      (index) => Semantics(
                        label: 'Écran ${index + 1} sur ${_slides.length}',
                        selected: _currentIndex == index,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.fastOutSlowIn,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: _currentIndex == index ? 24 : 8,
                          height: 4,
                          decoration: BoxDecoration(
                            color: _currentIndex == index
                                ? BkoTheme.goldAccent
                                : BkoTheme.getBorderSubtle(context),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Action Buttons with Smooth CrossFade
                  AnimatedCrossFade(
                    duration: const Duration(milliseconds: 200),
                    crossFadeState: _currentIndex == _slides.length - 1
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    firstChild: SizedBox(
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
                          'Continuer',
                          style: BkoTheme.fontPoppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                    secondChild: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _finishAndExplore,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: BkoTheme.goldAccent,
                              foregroundColor: Colors.black,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(
                              'Explorer les épisodes',
                              style: BkoTheme.fontPoppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: OutlinedButton(
                            onPressed: _finishAndLogin,
                            style: OutlinedButton.styleFrom(
                              backgroundColor: BkoTheme.getBgSurface(context),
                              foregroundColor: BkoTheme.getTextPrimary(context),
                              side: BorderSide(
                                  color: BkoTheme.getBorderSubtle(context)),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text(
                              'Se connecter',
                              style: BkoTheme.fontPoppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: BkoTheme.getTextPrimary(context),
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
          ],
        ),
      ),
    );
  }
}

enum _VisualType { discover, listenOrWatch, start }

class _OnboardingSlideData {
  final String badge;
  final String title;
  final String description;
  final _VisualType type;

  const _OnboardingSlideData({
    required this.badge,
    required this.title,
    required this.description,
    required this.type,
  });
}

class _VisualContainer extends StatelessWidget {
  final _VisualType type;

  const _VisualContainer({required this.type});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BkoTheme.getBgSurface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: BkoTheme.getBorderSubtle(context)),
      ),
      child: switch (type) {
        _VisualType.discover => _buildDiscoverVisual(context),
        _VisualType.listenOrWatch => _buildListenOrWatchVisual(context),
        _VisualType.start => _buildStartVisual(context),
      },
    );
  }

  Widget _buildDiscoverVisual(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          children: [
            _buildMiniCover(
              context: context,
              icon: Icons.podcasts_rounded,
              category: 'Société',
              tag: 'Idées',
              iconColor: BkoTheme.goldAccent,
            ),
            const SizedBox(width: 10),
            _buildMiniCover(
              context: context,
              icon: Icons.record_voice_over_rounded,
              category: 'Débats',
              tag: 'Direct',
              iconColor: BkoTheme.getTextPrimary(context),
            ),
            const SizedBox(width: 10),
            _buildMiniCover(
              context: context,
              icon: Icons.menu_book_rounded,
              category: 'Récits',
              tag: 'Culture',
              iconColor: BkoTheme.goldAccent,
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: BkoTheme.getBgSurface(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: BkoTheme.getBorderSubtle(context)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: BkoTheme.getBgSurface(context),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: BkoTheme.getBorderSubtle(context)),
                ),
                child: Icon(
                  Icons.explore_rounded,
                  color: BkoTheme.getAccent(context),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Découverte libre & ouverte',
                      style: BkoTheme.fontPoppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: BkoTheme.getTextPrimary(context),
                      ),
                    ),
                    Text(
                      'Des formats variés pour tous les goûts',
                      style: BkoTheme.fontPoppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w400,
                        color: BkoTheme.getTextSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_rounded,
                color: BkoTheme.getTextSecondary(context),
                size: 16,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMiniCover({
    required BuildContext context,
    required IconData icon,
    required String category,
    required String tag,
    required Color iconColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: BkoTheme.getBgSurface(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: BkoTheme.getBorderSubtle(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                Icon(icon, color: iconColor, size: 22),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: BkoTheme.getBgSurface(context),
                    borderRadius: BorderRadius.circular(6),
                    border:
                        Border.all(color: BkoTheme.getBorderSubtle(context)),
                  ),
                  child: Text(
                    tag,
                    style: BkoTheme.fontPoppins(
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                      color: BkoTheme.getTextSecondary(context),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              category,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: BkoTheme.fontPoppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: BkoTheme.getTextPrimary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListenOrWatchVisual(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Mini Player Preview
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: BkoTheme.getBgSurface(context),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: BkoTheme.getBorderSubtle(context)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: BkoTheme.goldAccent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.black,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Lecture en cours',
                      style: BkoTheme.fontPoppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: BkoTheme.getTextPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          flex: 4,
                          child: Container(
                            height: 4,
                            decoration: BoxDecoration(
                              color: BkoTheme.goldAccent,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 6,
                          child: Container(
                            height: 4,
                            decoration: BoxDecoration(
                              color: BkoTheme.getBorderSubtle(context),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Two Formats: Audio and Video
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: BkoTheme.getBgSurface(context),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: BkoTheme.getBorderSubtle(context)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: BkoTheme.getBgSurface(context),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: BkoTheme.getBorderSubtle(context)),
                      ),
                      child: Icon(
                        Icons.headphones_rounded,
                        color: BkoTheme.getAccent(context),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Format Audio',
                            style: BkoTheme.fontPoppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: BkoTheme.getTextPrimary(context),
                            ),
                          ),
                          Text(
                            'Écoute nomade',
                            style: BkoTheme.fontPoppins(
                              fontSize: 9,
                              fontWeight: FontWeight.w400,
                              color: BkoTheme.getTextSecondary(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: BkoTheme.getBgSurface(context),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: BkoTheme.getBorderSubtle(context)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: BkoTheme.getBgSurface(context),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: BkoTheme.getBorderSubtle(context)),
                      ),
                      child: Icon(
                        Icons.play_circle_outline_rounded,
                        color: BkoTheme.getAccent(context),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Format Vidéo',
                            style: BkoTheme.fontPoppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: BkoTheme.getTextPrimary(context),
                            ),
                          ),
                          Text(
                            'Émissions filmées',
                            style: BkoTheme.fontPoppins(
                              fontSize: 9,
                              fontWeight: FontWeight.w400,
                              color: BkoTheme.getTextSecondary(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStartVisual(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Show / Follow card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: BkoTheme.getBgSurface(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: BkoTheme.getBorderSubtle(context)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: BkoTheme.getBgSurface(context),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: BkoTheme.getBorderSubtle(context)),
                ),
                child: Icon(
                  Icons.podcasts_rounded,
                  color: BkoTheme.getAccent(context),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Émissions suivies',
                      style: BkoTheme.fontPoppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: BkoTheme.getTextPrimary(context),
                      ),
                    ),
                    Text(
                      'Abonnements aux flux favoris',
                      style: BkoTheme.fontPoppins(
                        fontSize: 10,
                        color: BkoTheme.getTextSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: BkoTheme.getBgSurface(context),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: BkoTheme.goldAccent),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_rounded,
                      color: BkoTheme.getAccent(context),
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Suivi',
                      style: BkoTheme.fontPoppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: BkoTheme.getAccent(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // Saved Episodes & Library Card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: BkoTheme.getBgSurface(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: BkoTheme.getBorderSubtle(context)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: BkoTheme.getBgSurface(context),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: BkoTheme.getBorderSubtle(context)),
                ),
                child: Icon(
                  Icons.bookmark_border_rounded,
                  color: BkoTheme.getAccent(context),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Épisodes enregistrés',
                      style: BkoTheme.fontPoppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: BkoTheme.getTextPrimary(context),
                      ),
                    ),
                    Text(
                      'À écouter et retrouver dans la bibliothèque',
                      style: BkoTheme.fontPoppins(
                        fontSize: 10,
                        color: BkoTheme.getTextSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.library_music_rounded,
                color: BkoTheme.getTextSecondary(context),
                size: 18,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
