import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/theme/bko_theme.dart';
import '../../shell/shell_providers.dart';

class HeroBannerSlider extends ConsumerStatefulWidget {
  final List<dynamic> slides;
  final Function(Map<String, dynamic> ep) onPlay;

  const HeroBannerSlider({
    super.key,
    required this.slides,
    required this.onPlay,
  });

  @override
  ConsumerState<HeroBannerSlider> createState() => _HeroBannerSliderState();
}

class _HeroBannerSliderState extends ConsumerState<HeroBannerSlider>
    with WidgetsBindingObserver {
  late final PageController _pageController;
  int _currentIndex = 0;
  Timer? _autoSlideTimer;
  bool _isUserInteracting = false;
  bool _foreground = true;

  String _slideId(dynamic slide) {
    if (slide is! Map) return '';
    final episode = slide['episode'] is Map ? slide['episode'] as Map : slide;
    return episode['id']?.toString() ?? '';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pageController = PageController();
    _startAutoSlide();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoSlideTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
  }

  @override
  void didUpdateWidget(covariant HeroBannerSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldIds = oldWidget.slides.map(_slideId).join(',');
    final newIds = widget.slides.map(_slideId).join(',');
    if (oldIds == newIds) return;
    final currentId = oldWidget.slides.isNotEmpty
        ? _slideId(oldWidget.slides[_currentIndex.clamp(0, oldWidget.slides.length - 1)])
        : '';
    final retainedIndex = widget.slides.indexWhere((s) => _slideId(s) == currentId);
    _currentIndex = retainedIndex >= 0 ? retainedIndex : 0;
    _isUserInteracting = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_pageController.hasClients && widget.slides.isNotEmpty) {
        _pageController.jumpToPage(_currentIndex);
      }
      _startAutoSlide();
    });
  }

  void _startAutoSlide() {
    _autoSlideTimer?.cancel();
    if (widget.slides.length <= 1) return;
    _autoSlideTimer = Timer.periodic(const Duration(seconds: 7), (timer) {
      if (_isUserInteracting || !mounted || !_foreground) return;
      if (!TickerMode.valuesOf(context).enabled ||
          MediaQuery.of(context).disableAnimations ||
          GoRouterState.of(context).uri.path != '/' ||
          ModalRoute.of(context)?.isCurrent == false ||
          widget.slides.length <= 1) {
        return;
      }
      if (_pageController.hasClients) {
        final nextIndex = (_currentIndex + 1) % widget.slides.length;
        _pageController.animateToPage(
          nextIndex,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  String _cleanText(String? input, {int max = 140}) {
    if (input == null || input.isEmpty) return '';
    String t = input
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll(RegExp(r'&#39;|&#x27;|&apos;'), "'")
        .replaceAll('&quot;', '"')
        .replaceAll('&amp;', '&')
        .replaceAll('&nbsp;', ' ')
        .replaceAll(RegExp(r'https?:\/\/\S+'), '')
        .replaceAll(RegExp(r'[-_=]{4,}'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (t.length > max) {
      t = '${t.substring(0, max).trimRight()}…';
    }
    return t;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.slides.isEmpty) return const SizedBox.shrink();

    final borderSub = BkoTheme.getBorderSubtle(context);
    final textPri = BkoTheme.getTextPrimary(context);
    final textSec = BkoTheme.getTextSecondary(context);

    return Column(
      children: [
        SizedBox(
          height: 380,
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is ScrollStartNotification && notification.dragDetails != null) {
                _isUserInteracting = true;
              } else if (notification is ScrollEndNotification) {
                _isUserInteracting = false;
              }
              return false;
            },
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.slides.length,
              onPageChanged: (index) {
                setState(() => _currentIndex = index);
              },
              itemBuilder: (context, index) {
                final slide = widget.slides[index] as Map;
                final ep = (slide['episode'] is Map)
                    ? Map<String, dynamic>.from(slide['episode'] as Map)
                    : Map<String, dynamic>.from(slide);
                final podcast = (ep['podcast'] is Map) ? ep['podcast'] as Map : null;

                final cover = '${ep['cover'] ?? podcast?['cover'] ?? ''}';
                final label = '${slide['label'] ?? 'À LA UNE'}'.toUpperCase();
                final podcastName = '${podcast?['name'] ?? ''}';
                final podcastSlug = '${podcast?['slug'] ?? ''}';
                final title = _cleanText(ep['title'], max: 90);
                final desc = _cleanText(ep['description'], max: 130);
                final durationSec = ep['durationSeconds'] as int?;
                final durationText = durationSec != null && durationSec > 0
                    ? '${(durationSec / 60).round()} min'
                    : null;

                final episodeId = '${ep['id'] ?? ''}';

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF121212), // Solid background
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: borderSub, width: 1),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      children: [
                        // Background image with solid dark overlay (NO GRADIENT)
                        if (cover.startsWith('http'))
                          Positioned.fill(
                            child: CachedNetworkImage(
                              imageUrl: cover,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => const SizedBox.shrink(),
                            ),
                          ),
                        // Crisp solid dark overlay
                        Positioned.fill(
                          child: Container(
                            color: const Color(0xEB0B0B0B), // Solid 92% dark overlay
                          ),
                        ),

                        // Slide content
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Top badges row
                              SizedBox(
                                height: 26,
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: BkoTheme.goldAccent,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        label,
                                        style: BkoTheme.fontLato(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.5,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ),
                                    if (durationText != null) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF262626),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          durationText,
                                          style: BkoTheme.fontLato(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w700,
                                            color: textSec,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),

                              const Spacer(),

                              // Podcast name link (fixed slot height: 18px)
                              SizedBox(
                                height: 18,
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: GestureDetector(
                                    onTap: () {
                                      if (podcastSlug.isNotEmpty) {
                                        context.push('/podcasts/$podcastSlug');
                                      }
                                    },
                                    child: Text(
                                      (podcastName.isNotEmpty ? podcastName : 'BAMAKO PODCAST').toUpperCase(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: BkoTheme.fontLato(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.1,
                                        color: BkoTheme.goldAccent,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),

                              // Episode Title (fixed slot height: 50px - exactly 2 lines reserved)
                              SizedBox(
                                height: 50,
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: BkoTheme.fontLato(
                                      fontSize: 19,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      height: 1.2,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),

                              // Episode Description (fixed slot height: 34px - exactly 2 lines reserved)
                              SizedBox(
                                height: 34,
                                child: Align(
                                  alignment: Alignment.topLeft,
                                  child: Text(
                                    desc.isNotEmpty ? desc : 'Découvrez cet épisode exclusif sur la plateforme BKO Podcast.',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: BkoTheme.fontLato(
                                      fontSize: 12,
                                      color: textSec,
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Bottom Actions (fixed slot height: 44px)
                              SizedBox(
                                height: 44,
                                child: Row(
                                children: [
                                  // Play / Pause button
                                  Consumer(
                                    builder: (context, ref, _) {
                                      final isCurrent = ref.watch(activeEpisodeProvider.select((s) => s.episodeId == episodeId));
                                      final isPlayingThis = isCurrent && ref.watch(activeEpisodeProvider.select((s) => s.isPlaying));
                                      final isLoadingThis = isCurrent && ref.watch(activeEpisodeProvider.select((s) => s.isLoading));
                                      return ElevatedButton.icon(
                                        onPressed: () => widget.onPlay(ep),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: BkoTheme.goldAccent,
                                          foregroundColor: Colors.black,
                                          elevation: 0,
                                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(999),
                                          ),
                                        ),
                                        icon: isLoadingThis
                                            ? const SizedBox(
                                                width: 16,
                                                height: 16,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                                                ),
                                              )
                                            : Icon(
                                                isPlayingThis ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                                size: 18,
                                                color: Colors.black,
                                              ),
                                        label: Text(
                                          isLoadingThis
                                              ? 'CHARGEMENT'
                                              : (isPlayingThis
                                                  ? 'PAUSE'
                                                  : (isCurrent ? 'REPRENDRE' : 'ÉCOUTER')),
                                          style: BkoTheme.fontLato(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.5,
                                            color: Colors.black,
                                          ),
                                        ),
                                      );
                                    },
                                  ),

                                  const SizedBox(width: 10),

                                  // Podcast page button
                                  if (podcastSlug.isNotEmpty)
                                    OutlinedButton(
                                      onPressed: () => context.push('/podcasts/$podcastSlug'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.white,
                                        side: BorderSide(color: borderSub),
                                        backgroundColor: const Color(0xFF1E1E1E),
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(999),
                                        ),
                                      ),
                                      child: Text(
                                        'Émission',
                                        style: BkoTheme.fontLato(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: textPri,
                                        ),
                                      ),
                                    ),

                                  const Spacer(),

                                  // Share button
                                  IconButton(
                                    onPressed: () {
                                      // ignore: deprecated_member_use
                                      Share.share(
                                        'Découvrez "${ep['title']}" sur Bamako Podcast : https://bamakopodcast.studio/podcasts/$podcastSlug',
                                      );
                                    },
                                    icon: const Icon(Icons.share_outlined, size: 20),
                                    color: textSec,
                                    style: IconButton.styleFrom(
                                      backgroundColor: const Color(0xFF1E1E1E),
                                      shape: const CircleBorder(),
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
              },
            ),
          ),
        ),

        // Indicator dots
        if (widget.slides.length > 1) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.slides.length, (index) {
              final isCurrent = index == _currentIndex;
              return GestureDetector(
                onTap: () {
                  _pageController.animateToPage(
                    index,
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeInOutCubic,
                  );
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: isCurrent ? 24 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isCurrent ? BkoTheme.goldAccent : const Color(0xFF333333),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}
