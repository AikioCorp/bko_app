import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/network/bko_api.dart';
import '../../core/theme/bko_theme.dart';
import '../auth/auth_controller.dart';
import 'notification_providers.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  bool _loading = true;
  String? _error;
  List<dynamic> _notifications = [];

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    final token = ref.read(authProvider).token;
    if (token == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await BkoApi.get('/me/notifications', token: token);
      if (mounted) {
        setState(() {
          _notifications = (res is List ? res : (res is Map && res['data'] is List ? res['data'] : [])) as List;
          _loading = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.message; });
    } catch (_) {
      if (mounted) setState(() { _loading = false; _error = 'Impossible de charger vos notifications.'; });
    }
  }

  Future<void> _markAllRead() async {
    final token = ref.read(authProvider).token;
    if (token == null) return;
    try {
      await BkoApi.post('/me/notifications/read', {}, token: token);
      ref.read(unreadNotificationsProvider.notifier).reset();
      _fetch();
    } catch (_) {}
  }

  Future<void> _onNotificationTap(Map<String, dynamic> notif) async {
    final id = '${notif['id'] ?? ''}';
    final token = ref.read(authProvider).token;
    if (id.isNotEmpty && token != null && notif['isRead'] != true) {
      try {
        await BkoApi.post('/me/notifications/read', {'ids': [id]}, token: token);
        ref.read(unreadNotificationsProvider.notifier).markAsReadLocally(1);
        setState(() {
          notif['isRead'] = true;
        });
      } catch (_) {}
    }

    // Deep link or navigation if payload has target
    final data = notif['data'] is Map ? notif['data'] as Map : {};
    final podcastSlug = data['podcastSlug'] ?? notif['podcastSlug'];
    final episodeSlug = data['episodeSlug'] ?? notif['episodeSlug'];

    if (podcastSlug != null && episodeSlug != null) {
      if (mounted) context.push('/podcasts/$podcastSlug/episodes/$episodeSlug');
    } else if (podcastSlug != null) {
      if (mounted) context.push('/podcasts/$podcastSlug');
    }
  }

  @override
  Widget build(BuildContext context) {
    final textPri = BkoTheme.getTextPrimary(context);
    final textSec = BkoTheme.getTextSecondary(context);
    final surface = BkoTheme.getBgSurface(context);
    final border = BkoTheme.getBorderSubtle(context);
    final auth = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: BkoTheme.getBgObsidian(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textPri, size: 20),
          tooltip: 'Retour',
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Notifications',
          style: BkoTheme.fontPoppins(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: textPri,
          ),
        ),
        actions: [
          if (auth.isAuthenticated && _notifications.isNotEmpty)
            TextButton(
              onPressed: _markAllRead,
              child: Text(
                'Tout marquer lu',
                style: BkoTheme.fontPoppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: BkoTheme.goldAccent,
                ),
              ),
            ),
        ],
      ),
      body: !auth.isAuthenticated
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: const BoxDecoration(
                        color: Color(0xFF161616),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lock_outline_rounded,
                        size: 40,
                        color: BkoTheme.goldAccent,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Connexion requise',
                      style: BkoTheme.fontPoppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: textPri,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Connectez-vous à votre compte Bamako Podcast pour recevoir les alertes sur vos abonnements et émissions.',
                      textAlign: TextAlign.center,
                      style: BkoTheme.fontLato(
                        fontSize: 13,
                        color: textSec,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () async {
                        await context.push('/login');
                        if (mounted) _fetch();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: BkoTheme.goldAccent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                        elevation: 0,
                      ),
                      child: Text(
                        'Se connecter',
                        style: BkoTheme.fontPoppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : _loading
              ? const Center(child: CircularProgressIndicator(color: BkoTheme.goldAccent))
              : _error != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!, style: BkoTheme.fontLato(fontSize: 13, color: Colors.red.shade300)),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: _fetch,
                            style: ElevatedButton.styleFrom(backgroundColor: BkoTheme.goldAccent, foregroundColor: Colors.black),
                            child: Text('Réessayer', style: BkoTheme.fontPoppins(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black)),
                          ),
                        ],
                      ),
                    )
                  : _notifications.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.notifications_off_outlined, size: 54, color: Colors.grey),
                                const SizedBox(height: 14),
                                Text(
                                  'Aucune notification',
                                  style: BkoTheme.fontPoppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: textPri,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Vous serez alerté dès la publication d\'un nouvel épisode de vos émissions suivies.',
                                  textAlign: TextAlign.center,
                                  style: BkoTheme.fontLato(fontSize: 12.5, color: textSec, height: 1.4),
                                ),
                              ],
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          color: BkoTheme.goldAccent,
                          onRefresh: _fetch,
                          child: ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                            itemCount: _notifications.length,
                            itemBuilder: (context, index) {
                              final notif = _notifications[index] as Map<String, dynamic>;
                              final isRead = notif['isRead'] == true;
                              final title = notif['title'] ?? 'Notification';
                              final body = notif['body'] ?? notif['message'] ?? '';

                              return GestureDetector(
                                onTap: () => _onNotificationTap(notif),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: isRead ? surface : const Color(0xFF181818),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isRead ? border : BkoTheme.goldAccent.withValues(alpha: 0.4),
                                    ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: isRead
                                              ? const Color(0xFF222222)
                                              : BkoTheme.goldAccent.withValues(alpha: 0.15),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.notifications_active_rounded,
                                          color: isRead ? Colors.grey : BkoTheme.goldAccent,
                                          size: 18,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              title,
                                              style: BkoTheme.fontPoppins(
                                                fontSize: 13.5,
                                                fontWeight: isRead ? FontWeight.w500 : FontWeight.w700,
                                                color: textPri,
                                              ),
                                            ),
                                            if (body.isNotEmpty) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                body,
                                                style: BkoTheme.fontLato(
                                                  fontSize: 12,
                                                  color: textSec,
                                                  height: 1.3,
                                                ),
                                              ),
                                            ],
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
    );
  }
}
