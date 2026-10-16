import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/widgets/bko_haptics.dart';
import '../../../core/widgets/bko_toast.dart';
import '../../auth/auth_controller.dart';

/// Gestionnaire unifié et sécurisé des destinations de notifications (in-app & push FCM).
class NotificationDestinationHandler {
  /// Destination mise en attente lors d'un démarrage à froid (cold start) depuis un push.
  static String? _pendingDestination;

  static void setPendingDestination(String? raw) {
    final normalized = normalizeDestination(raw);
    if (normalized != null && normalized.isNotEmpty) {
      _pendingDestination = normalized;
    }
  }

  static String? get pendingDestination => _pendingDestination;

  static void clearPendingDestination() {
    _pendingDestination = null;
  }

  /// Consomme et navigue vers la destination en attente dès que le routeur et la session sont initialisés.
  static Future<bool> consumePending(BuildContext context, {WidgetRef? ref}) async {
    final dest = _pendingDestination;
    if (dest == null) return false;
    _pendingDestination = null;
    // Si la destination en attente est l'accueil, l'utilisateur s'y trouve déjà
    if (dest == '/' || dest.isEmpty) return true;
    return navigate(context, dest, ref: ref);
  }

  /// Normalise les liens serveur (web ou mobile) en chemin interne Flutter propre.
  static String? normalizeDestination(String? raw) {
    if (raw == null) return null;
    var trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    // Si URL absolue (ex. https://bamakopodcast.ml/podcasts/slug)
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      final uri = Uri.tryParse(trimmed);
      if (uri != null && uri.path.isNotEmpty) {
        trimmed = uri.path + (uri.hasQuery ? '?${uri.query}' : '');
      }
    }

    // Assurer le slash initial
    if (!trimmed.startsWith('/')) {
      trimmed = '/$trimmed';
    }

    // Nettoyer les doubles slashes initiaux
    while (trimmed.startsWith('//')) {
      trimmed = trimmed.substring(1);
    }

    return trimmed;
  }

  /// Vérifie si une destination interne est autorisée et correspond à un écran Flutter.
  static bool isValidRoute(String path) {
    final uri = Uri.tryParse(path);
    if (uri == null) return false;
    final basePath = uri.path;

    // Motifs de routes supportées dans app_router.dart
    if (basePath == '/' ||
        basePath == '/explore' ||
        basePath == '/library' ||
        basePath == '/favorites' ||
        basePath == '/profile' ||
        basePath == '/profile/edit' ||
        basePath == '/account' ||
        basePath == '/downloads' ||
        basePath == '/notifications' ||
        basePath == '/become-creator' ||
        basePath == '/taste-onboarding') {
      return true;
    }

    if (basePath.startsWith('/podcasts/') ||
        basePath.startsWith('/playlists/') ||
        basePath.startsWith('/settings/') ||
        basePath.startsWith('/studio') ||
        basePath.startsWith('/discovery')) {
      return true;
    }

    return false;
  }

  /// Navigue vers la destination avec validation, retour haptique et gestion des accès.
  static Future<bool> navigate(BuildContext context, String? rawDestination, {WidgetRef? ref}) async {
    final path = normalizeDestination(rawDestination);
    if (path == null) {
      // Pas de destination : reste sur la liste des notifications
      return false;
    }

    if (!isValidRoute(path)) {
      _showFeedback(context, "Le lien de cette notification n'est pas pris en charge.");
      return false;
    }

    final uri = Uri.tryParse(path);
    final basePath = uri?.path ?? path;

    // Contrôle d'accès au Studio (créateur, collaborateur ou administrateur)
    if (basePath.startsWith('/studio')) {
      var canAccessStudio = ref?.read(authProvider).canAccessStudio ?? false;
      if (!canAccessStudio && ref != null) {
        // En cas d'affectation récente (ex: notification "Ouvrir l'émission"), actualiser immédiatement les droits depuis /me
        await ref.read(authProvider.notifier).fetchMe();
        canAccessStudio = ref.read(authProvider).canAccessStudio;
      }
      if (!canAccessStudio) {
        _showFeedback(context, "Cet espace requiert un profil créateur, collaborateur ou administrateur.");
        return false;
      }
    }

    BkoHaptics.light();

    try {
      // Éviter la navigation si l'application est déjà exactement sur cette route
      final navContext = rootNavigatorKey.currentContext;
      if (navContext != null) {
        final currentLoc = GoRouter.of(navContext).routerDelegate.currentConfiguration.uri.toString();
        if (currentLoc == path) {
          return true;
        }
      }

      if (context.mounted) {
        context.go(path);
      } else {
        appRouter.go(path);
      }
      return true;
    } catch (_) {
      if (context.mounted) {
        _showFeedback(context, "Ce contenu n'est plus accessible ou a été supprimé.");
      }
      return false;
    }
  }

  static void _showFeedback(BuildContext context, String message) {
    BkoToast.showInfo(
      context,
      title: 'Contenu inaccessible',
      message: message,
    );
  }
}
