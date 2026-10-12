import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/network/bko_telemetry.dart';

/// Widget de suivi d'impression pour Flutter (équivalent mobile d'IntersectionObserver).
/// Déclenche une impression de télémétrie dès que l'élément est visible à au moins 50%
/// dans le viewport de l'écran pendant une durée continue de 1 seconde (1000ms).
class TrackedVisibilityCard extends StatefulWidget {
  final Widget child;
  final String batchId;
  final String sectionId;
  final String sectionSlug;
  final String targetType; // 'EPISODE' | 'PODCAST'
  final String targetId;
  final int position;
  final String? reason;
  final String? token;

  const TrackedVisibilityCard({
    super.key,
    required this.child,
    required this.batchId,
    required this.sectionId,
    required this.sectionSlug,
    required this.targetType,
    required this.targetId,
    required this.position,
    this.reason,
    this.token,
  });

  @override
  State<TrackedVisibilityCard> createState() => _TrackedVisibilityCardState();
}

class _TrackedVisibilityCardState extends State<TrackedVisibilityCard> with WidgetsBindingObserver {
  Timer? _checkTimer;
  DateTime? _visibleSince;
  bool _impressionLogged = false;
  bool _isAppInForeground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Démarrage du contrôleur périodique de visibilité dans le viewport
    _checkTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      _checkVisibility();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _isAppInForeground = true;
    } else {
      // Si l'application passe en arrière-plan, mettre en pause le compteur
      _isAppInForeground = false;
      _visibleSince = null;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _checkTimer?.cancel();
    super.dispose();
  }

  void _checkVisibility() {
    if (_impressionLogged || !mounted || !_isAppInForeground) {
      if (!_isAppInForeground) _visibleSince = null;
      return;
    }

    // Vérifier si la route courante est active (pas couverte par un modal ou une autre page)
    final modalRoute = ModalRoute.of(context);
    if (modalRoute != null && !modalRoute.isCurrent) {
      _visibleSince = null;
      return;
    }

    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return;

    final mediaQuery = MediaQuery.maybeOf(context);
    if (mediaQuery == null) return;

    final screenHeight = mediaQuery.size.height;
    final screenWidth = mediaQuery.size.width;

    try {
      final position = renderObject.localToGlobal(Offset.zero);
      final size = renderObject.size;

      final totalArea = size.width * size.height;
      if (totalArea <= 0) return;

      // Calcul de la boîte d'intersection entre la carte et le viewport écran
      final left = position.dx.clamp(0.0, screenWidth);
      final right = (position.dx + size.width).clamp(0.0, screenWidth);
      final top = position.dy.clamp(0.0, screenHeight);
      final bottom = (position.dy + size.height).clamp(0.0, screenHeight);

      final visibleWidth = (right - left).clamp(0.0, size.width);
      final visibleHeight = (bottom - top).clamp(0.0, size.height);

      final visibleArea = visibleWidth * visibleHeight;
      // Ratio surfacique strict : surface réellement visible / surface totale >= 0.50 (50%)
      final surfaceRatio = visibleArea / totalArea;

      final isSubstantiallyVisible = surfaceRatio >= 0.50;

      if (isSubstantiallyVisible) {
        _visibleSince ??= DateTime.now();
        final elapsed = DateTime.now().difference(_visibleSince!).inMilliseconds;
        if (elapsed >= 1000) {
          _impressionLogged = true;
          _checkTimer?.cancel();

          BkoTelemetryService().trackImpression(
            batchId: widget.batchId,
            sectionId: widget.sectionId,
            sectionSlug: widget.sectionSlug,
            targetType: widget.targetType,
            targetId: widget.targetId,
            position: widget.position,
            reason: widget.reason,
            token: widget.token,
          );
        }
      } else {
        // En cas de sortie du viewport ou masquage partiel (< 50% surface), réinitialiser
        _visibleSince = null;
      }
    } catch (_) {
      // Ignorer si la disposition n'est pas encore finalisée
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
