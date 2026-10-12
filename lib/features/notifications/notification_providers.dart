import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/bko_api.dart';
import '../auth/auth_controller.dart';

class UnreadNotificationsNotifier extends StateNotifier<int> {
  final Ref ref;
  UnreadNotificationsNotifier(this.ref) : super(0) {
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (!next.isAuthenticated) {
        reset();
      } else if (previous?.token != next.token) {
        fetchCount();
      }
    });
    fetchCount();
  }

  Future<void> fetchCount() async {
    final auth = ref.read(authProvider);
    if (!auth.isAuthenticated || auth.token == null) {
      state = 0;
      return;
    }

    try {
      final res = await BkoApi.get('/me/notifications/unread-count', token: auth.token);
      if (res is Map) {
        final count = res['data']?['unread'] ?? res['unread'];
        if (count is num) {
          state = count.toInt();
          return;
        }
      }
      state = 0;
    } catch (_) {
      // Keep previous state silently on transient error
    }
  }

  void markAsReadLocally([int count = 1]) {
    state = (state - count).clamp(0, 999);
  }

  void reset() {
    state = 0;
  }
}

final unreadNotificationsProvider = StateNotifierProvider<UnreadNotificationsNotifier, int>((ref) {
  return UnreadNotificationsNotifier(ref);
});
