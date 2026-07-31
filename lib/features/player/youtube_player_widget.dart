import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import '../../core/theme/bko_theme.dart';

class BkoYoutubePlayerWidget extends StatefulWidget {
  final String coverUrl;
  final String? videoUrl;
  final bool autoPlay;
  final Duration startPosition;
  final bool syncPosition;

  const BkoYoutubePlayerWidget({
    super.key,
    required this.coverUrl,
    this.videoUrl,
    this.autoPlay = false,
    this.startPosition = Duration.zero,
    this.syncPosition = false,
  });

  @override
  State<BkoYoutubePlayerWidget> createState() => _BkoYoutubePlayerWidgetState();
}

class _BkoYoutubePlayerWidgetState extends State<BkoYoutubePlayerWidget> {
  YoutubePlayerController? _controller;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  void _initController() {
    final id = widget.videoUrl == null || widget.videoUrl!.isEmpty
        ? null
        : YoutubePlayerController.convertUrlToId(widget.videoUrl!);

    if (id != null && id.isNotEmpty) {
      _controller = YoutubePlayerController.fromVideoId(
        videoId: id,
        autoPlay: widget.autoPlay,
        startSeconds: widget.startPosition.inMilliseconds / 1000,
        params: const YoutubePlayerParams(
          showControls: true,
          showFullscreenButton: true,
          mute: false,
          pointerEvents: PointerEvents.initial,
        ),
      );
    }
  }

  @override
  void didUpdateWidget(covariant BkoYoutubePlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      _controller?.close();
      _controller = null;
      _initController();
      if (mounted) setState(() {});
      return;
    }
    if (oldWidget.autoPlay != widget.autoPlay) {
      if (widget.autoPlay) {
        _controller?.playVideo();
      } else {
        _controller?.pauseVideo();
      }
    }
    if (widget.syncPosition &&
        oldWidget.startPosition != widget.startPosition) {
      _controller?.seekTo(
        seconds: widget.startPosition.inMilliseconds / 1000,
        allowSeekAhead: true,
      );
    }
  }

  @override
  void dispose() {
    _controller?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: YoutubePlayer(
            controller: _controller!,
            aspectRatio: 16 / 9,
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: widget.coverUrl.isNotEmpty
            ? Image.network(
                widget.coverUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: const Color(0xFF1E2638),
                  child: const Icon(Icons.graphic_eq_rounded,
                      color: BkoTheme.goldAccent, size: 48),
                ),
              )
            : Container(
                color: const Color(0xFF1E2638),
                child: const Icon(Icons.graphic_eq_rounded,
                    color: BkoTheme.goldAccent, size: 48),
              ),
      ),
    );
  }
}
