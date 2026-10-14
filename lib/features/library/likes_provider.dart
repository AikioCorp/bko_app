import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/bko_api.dart';
import '../../core/widgets/bko_haptics.dart';
import '../../core/widgets/bko_toast.dart';
import '../auth/auth_controller.dart';
import '../auth/auth_modal.dart';
import 'library_screen.dart';

class LikedEpisodesNotifier extends StateNotifier<Set<String>> {
  final Ref _ref;
  bool _isLoaded = false;

  LikedEpisodesNotifier(this._ref) : super(const <String>{});

  bool isLiked(String episodeId) => state.contains(episodeId);

  Future<void> fetchLikedIds({bool force = false}) async {
    if (_isLoaded && !force) return;
    final auth = _ref.read(authProvider);
    if (!auth.isAuthenticated || auth.token == null) {
      state = const <String>{};
      _isLoaded = false;
      return;
    }

    try {
      final res = await BkoApi.get('/me/liked-ids', token: auth.token);
      if (res is List) {
        state = res.map((id) => id.toString()).toSet();
        _isLoaded = true;
      }
    } catch (_) {
      // Ignoré en mode dégradé
    }
  }

  Future<bool> toggleLike(BuildContext context, String episodeId) async {
    final auth = _ref.read(authProvider);
    if (!auth.isAuthenticated || auth.token == null) {
      AuthRequiredModal.show(context, actionTitle: 'aimer cet épisode');
      return false;
    }

    final currentlyLiked = state.contains(episodeId);
    final updated = Set<String>.from(state);

    // Optimistic update
    if (currentlyLiked) {
      updated.remove(episodeId);
    } else {
      updated.add(episodeId);
    }
    state = updated;
    BkoHaptics.light();

    try {
      if (currentlyLiked) {
        await BkoApi.delete('/episodes/$episodeId/likes', token: auth.token);
      } else {
        await BkoApi.post('/episodes/$episodeId/likes', {}, token: auth.token);
      }
      _ref.read(libraryUpdateSignalProvider.notifier).state++;
      return !currentlyLiked;
    } catch (e) {
      // Revert optimistic update on failure
      state = Set<String>.from(state)
        ..remove(episodeId)
        ..addAll(currentlyLiked ? [episodeId] : []);
      if (context.mounted) {
        BkoToast.showError(
          context,
          title: 'Erreur',
          message: 'Impossible d’enregistrer votre réaction.',
        );
      }
      return currentlyLiked;
    }
  }
  void clear() {
    state = const <String>{};
    _isLoaded = false;
  }
}

final likedEpisodesProvider =
    StateNotifierProvider<LikedEpisodesNotifier, Set<String>>((ref) {
  final notifier = LikedEpisodesNotifier(ref);
  ref.listen<AuthState>(authProvider, (prev, next) {
    if (next.isAuthenticated && !(prev?.isAuthenticated ?? false)) {
      notifier.fetchLikedIds(force: true);
    } else if (!next.isAuthenticated) {
      notifier.clear();
    }
  });
  return notifier;
});
