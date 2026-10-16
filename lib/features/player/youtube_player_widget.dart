import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import '../../core/theme/bko_theme.dart';
import '../../core/utils/youtube_url_parser.dart';
import '../../core/widgets/bko_bounceable.dart';

class BkoYoutubePlayerWidget extends StatefulWidget {
  final String coverUrl;
  final String? videoUrl;
  final bool isPlaying;
  final Duration startPosition;
  final int videoSeekRequestId;
  final Duration? videoSeekTarget;
  final void Function(Duration current, Duration? total)? onProgressChanged;
  final void Function(bool isPlaying)? onPlayingChanged;
  final VoidCallback? onEnded;
  final void Function(String message)? onPlaybackError;
  final VoidCallback? onRetry;

  const BkoYoutubePlayerWidget({
    super.key,
    required this.coverUrl,
    this.videoUrl,
    this.isPlaying = false,
    this.startPosition = Duration.zero,
    this.videoSeekRequestId = 0,
    this.videoSeekTarget,
    this.onProgressChanged,
    this.onPlayingChanged,
    this.onEnded,
    this.onPlaybackError,
    this.onRetry,
  });

  @override
  State<BkoYoutubePlayerWidget> createState() => _BkoYoutubePlayerWidgetState();
}

class _BkoYoutubePlayerWidgetState extends State<BkoYoutubePlayerWidget>
    with WidgetsBindingObserver {
  YoutubePlayerController? _ytController;
  StreamSubscription<YoutubePlayerValue>? _ytSubscription;
  StreamSubscription<YoutubeVideoState>? _ytPositionSub;

  VideoPlayerController? _nativeController;
  bool _isNativeInitialized = false;

  bool _isYouTube = false;
  bool _failed = false;
  String _errorMessage = '';
  bool _showNativeControls = true;
  Timer? _controlsTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializePlayer();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _pausePlayback();
    }
  }

  void _pausePlayback() {
    if (_isYouTube) {
      _ytController?.pauseVideo();
    } else {
      _nativeController?.pause();
    }
    widget.onPlayingChanged?.call(false);
  }

  void _initializePlayer() {
    _cleanupCurrentPlayer();
    _failed = false;
    _errorMessage = '';

    final rawUrl = widget.videoUrl?.trim();
    if (rawUrl == null || rawUrl.isEmpty) {
      return;
    }

    final ytId = YoutubeUrlParser.tryParseVideoId(rawUrl) ??
        YoutubePlayerController.convertUrlToId(rawUrl);

    if (ytId != null && ytId.isNotEmpty) {
      _isYouTube = true;
      _initYouTube(ytId);
    } else {
      _isYouTube = false;
      _initNativeVideo(rawUrl);
    }
  }

  void _initYouTube(String videoId) {
    _ytController = YoutubePlayerController.fromVideoId(
      videoId: videoId,
      autoPlay: widget.isPlaying,
      startSeconds: widget.startPosition.inMilliseconds / 1000.0,
      params: const YoutubePlayerParams(
        origin: 'https://www.youtube-nocookie.com',
        showControls: true,
        showFullscreenButton: true,
        mute: false,
        pointerEvents: PointerEvents.initial,
      ),
    );

    _ytSubscription = _ytController!.listen((value) {
      if (!mounted) return;

      if (value.hasError && !_failed) {
        String msg = 'Cette vidéo ne peut pas être lue dans l’application.';
        if (value.error == YoutubeError.notEmbeddable) {
          msg = 'L’auteur de la vidéo restreint son intégration hors de YouTube.';
        } else if (value.error == YoutubeError.videoNotFound ||
            value.error == YoutubeError.cannotFindVideo) {
          msg = 'Cette vidéo YouTube est introuvable ou a été supprimée.';
        }
        setState(() {
          _failed = true;
          _errorMessage = msg;
        });
        widget.onPlaybackError?.call(msg);
        return;
      }

      if (value.playerState == PlayerState.playing) {
        widget.onPlayingChanged?.call(true);
      } else if (value.playerState == PlayerState.paused) {
        widget.onPlayingChanged?.call(false);
      } else if (value.playerState == PlayerState.ended) {
        widget.onPlayingChanged?.call(false);
        widget.onEnded?.call();
      }
    });

    _ytPositionSub = _ytController!.videoStateStream.listen((videoState) async {
      if (!mounted || _failed) return;
      Duration? total;
      try {
        final sec = await _ytController?.duration;
        if (sec != null && sec > 0) {
          total = Duration(milliseconds: (sec * 1000).round());
        }
      } catch (_) {}
      widget.onProgressChanged?.call(videoState.position, total);
    });
  }

  void _initNativeVideo(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      setState(() {
        _failed = true;
        _errorMessage = 'Adresse de vidéo invalide.';
      });
      return;
    }

    _nativeController = VideoPlayerController.networkUrl(uri)
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() {
          _isNativeInitialized = true;
        });
        if (widget.startPosition > Duration.zero) {
          _nativeController?.seekTo(widget.startPosition);
        }
        if (widget.isPlaying) {
          _nativeController?.play();
          widget.onPlayingChanged?.call(true);
        }
      }).catchError((err) {
        if (!mounted) return;
        setState(() {
          _failed = true;
          _errorMessage = 'Impossible de charger le fichier vidéo.';
        });
        widget.onPlaybackError?.call('Erreur de chargement du fichier vidéo');
      });

    _nativeController?.addListener(_onNativePlayerUpdate);
  }

  void _onNativePlayerUpdate() {
    if (!mounted || _nativeController == null) return;
    final value = _nativeController!.value;
    if (value.hasError && !_failed) {
      setState(() {
        _failed = true;
        _errorMessage = value.errorDescription ?? 'Erreur lors de la lecture.';
      });
      widget.onPlaybackError?.call(_errorMessage);
      return;
    }

    widget.onProgressChanged?.call(value.position, value.duration);
    if (value.isPlaying != widget.isPlaying) {
      widget.onPlayingChanged?.call(value.isPlaying);
    }
    if (value.duration > Duration.zero &&
        value.position >= value.duration &&
        !value.isPlaying) {
      widget.onEnded?.call();
    }
  }

  @override
  void didUpdateWidget(covariant BkoYoutubePlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.videoUrl != widget.videoUrl) {
      _initializePlayer();
      return;
    }

    if (widget.videoSeekRequestId != oldWidget.videoSeekRequestId &&
        widget.videoSeekTarget != null) {
      final target = widget.videoSeekTarget!;
      if (_isYouTube) {
        _ytController?.seekTo(
          seconds: target.inMilliseconds / 1000.0,
          allowSeekAhead: true,
        );
      } else if (_isNativeInitialized) {
        _nativeController?.seekTo(target);
      }
    }

    if (oldWidget.isPlaying != widget.isPlaying) {
      if (_isYouTube) {
        if (widget.isPlaying) {
          _ytController?.playVideo();
        } else {
          _ytController?.pauseVideo();
        }
      } else if (_isNativeInitialized) {
        if (widget.isPlaying) {
          _nativeController?.play();
        } else {
          _nativeController?.pause();
        }
      }
    }
  }

  void _cleanupCurrentPlayer() {
    _ytSubscription?.cancel();
    _ytSubscription = null;
    _ytPositionSub?.cancel();
    _ytPositionSub = null;
    _ytController?.close();
    _ytController = null;

    _nativeController?.removeListener(_onNativePlayerUpdate);
    _nativeController?.dispose();
    _nativeController = null;
    _isNativeInitialized = false;

    _controlsTimer?.cancel();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cleanupCurrentPlayer();
    super.dispose();
  }

  void _toggleNativeControls() {
    setState(() => _showNativeControls = !_showNativeControls);
    if (_showNativeControls) {
      _startControlsTimer();
    }
  }

  void _startControlsTimer() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && widget.isPlaying) {
        setState(() => _showNativeControls = false);
      }
    });
  }

  Widget _buildErrorView() {
    final rawUrl = widget.videoUrl ?? '';
    final ytId = YoutubeUrlParser.tryParseVideoId(rawUrl) ??
        YoutubePlayerController.convertUrlToId(rawUrl);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        color: const Color(0xFF141414),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                color: Color(0xFF222222),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(
                  IconsaxPlusLinear.video_slash,
                  color: BkoTheme.goldAccent,
                  size: 26,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Lecture vidéo indisponible',
              textAlign: TextAlign.center,
              style: BkoTheme.fontLato(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _errorMessage.isNotEmpty
                  ? _errorMessage
                  : 'Impossible de lire la vidéo intégrée dans l’application.',
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: BkoTheme.fontLato(
                fontSize: 12.5,
                color: const Color(0xFF9E9E9E),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                BkoBounceable(
                  onTap: () {
                    widget.onRetry?.call();
                    _initializePlayer();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF262626),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF383838)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(IconsaxPlusLinear.refresh_2,
                            color: Colors.white, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'Réessayer',
                          style: BkoTheme.fontLato(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (ytId != null && ytId.isNotEmpty)
                  BkoBounceable(
                    onTap: () async {
                      final url = Uri.parse('https://www.youtube.com/watch?v=$ytId');
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url, mode: LaunchMode.externalApplication);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: BkoTheme.goldAccent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(IconsaxPlusBold.export,
                              color: Colors.black, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'Ouvrir sur YouTube',
                            style: BkoTheme.fontLato(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNativePlayer() {
    if (!_isNativeInitialized || _nativeController == null) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: BkoTheme.goldAccent,
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: _toggleNativeControls,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: _nativeController!.value.aspectRatio > 0
                  ? _nativeController!.value.aspectRatio
                  : 16 / 9,
              child: VideoPlayer(_nativeController!),
            ),
          ),
          if (_showNativeControls)
            AnimatedOpacity(
              opacity: _showNativeControls ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Container(
                color: Colors.black45,
                child: Center(
                  child: BkoBounceable(
                    onTap: () {
                      if (widget.isPlaying) {
                        _nativeController?.pause();
                        widget.onPlayingChanged?.call(false);
                      } else {
                        _nativeController?.play();
                        widget.onPlayingChanged?.call(true);
                      }
                    },
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(
                        color: BkoTheme.goldAccent,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        widget.isPlaying
                            ? IconsaxPlusBold.pause
                            : IconsaxPlusBold.play,
                        color: Colors.black,
                        size: 30,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: _buildErrorView(),
      );
    }

    if (_isYouTube && _ytController != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: YoutubePlayer(
            controller: _ytController!,
            aspectRatio: 16 / 9,
          ),
        ),
      );
    }

    if (!_isYouTube && _nativeController != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: _buildNativePlayer(),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: widget.coverUrl.isNotEmpty && widget.coverUrl.startsWith('http')
            ? CachedNetworkImage(
                imageUrl: widget.coverUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: const Color(0xFF141414),
                  child: const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: BkoTheme.goldAccent,
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: const Color(0xFF141414),
                  child: const Icon(
                    IconsaxPlusLinear.video,
                    color: BkoTheme.goldAccent,
                    size: 48,
                  ),
                ),
              )
            : Container(
                color: const Color(0xFF141414),
                child: const Icon(
                  IconsaxPlusLinear.video,
                  color: BkoTheme.goldAccent,
                  size: 48,
                ),
              ),
      ),
    );
  }
}
