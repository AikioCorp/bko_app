import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/bko_theme.dart';

/// Audio equalizer animation widget for podcasts/music playback and loading.
/// Displays 4 undulating vertical bars using solid colors without any gradient.
class EqualizerLoader extends StatefulWidget {
  final double size;
  final Color? color;
  final int barCount;
  final bool isPlaying;

  const EqualizerLoader({
    super.key,
    this.size = 24,
    this.color,
    int barCount = 4,
    int? bars,
    this.isPlaying = true,
  }) : barCount = bars ?? barCount;

  @override
  State<EqualizerLoader> createState() => _EqualizerLoaderState();
}

class _EqualizerLoaderState extends State<EqualizerLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    if (widget.isPlaying) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant EqualizerLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final barColor = widget.color ?? BkoTheme.goldAccent;

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            size: Size(widget.size, widget.size),
            painter: _EqualizerPainter(
              progress: widget.isPlaying ? _controller.value : 0.25,
              barCount: widget.barCount,
              color: barColor,
            ),
          );
        },
      ),
    );
  }
}

class _EqualizerPainter extends CustomPainter {
  final double progress;
  final int barCount;
  final Color color;

  _EqualizerPainter({
    required this.progress,
    required this.barCount,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final totalSpacing = size.width * 0.3;
    final spacing = totalSpacing / (barCount - 1);
    final barWidth = (size.width - totalSpacing) / barCount;
    final cornerRadius = Radius.circular(barWidth / 2);

    for (int i = 0; i < barCount; i++) {
      // Wave offset for each bar
      final offset = (i * 0.23);
      final phase = (progress * 2 * math.pi) + (offset * 2 * math.pi);
      // Normalized height between 0.25 and 1.0
      final heightRatio = 0.25 + 0.75 * ((math.sin(phase) + 1.0) / 2.0);
      final barHeight = size.height * heightRatio;

      final left = i * (barWidth + spacing);
      final top = size.height - barHeight;

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, top, barWidth, barHeight),
        cornerRadius,
      );

      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _EqualizerPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.barCount != barCount;
  }
}
