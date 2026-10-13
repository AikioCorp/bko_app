import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import '../../core/network/bko_api.dart';
import '../../core/theme/bko_theme.dart';
import '../../core/widgets/bko_bounceable.dart';
import '../../core/widgets/skeleton_loaders.dart';
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
  bool _isSessionExpired = false;
  List<dynamic> _notifications = [];

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    final auth = ref.read(authProvider);
    final token = auth.token;
    if (!auth.isAuthenticated || token == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = null;
          _isSessionExpired = false;
        });
      }
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _isSessionExpired = false;
    });

    try {
      final res = await BkoApi.get('/me/notifications', token: token);
      if (mounted) {
        setState(() {
          _notifications = (res is List ? res : (res is Map && res['data'] is List ? res['data'] : [])) as List;
          _loading = false;
          _error = null;
          _isSessionExpired = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        final isAuthErr = e.statusCode == 401 ||
            e.message.toLowerCase().contains('jeton') ||
            e.message.toLowerCase().contains('expir');
        setState(() {
          _loading = false;
          _isSessionExpired = isAuthErr;
          _error = isAuthErr
              ? 'Votre session a expiré. Veuillez vous reconnecter.'
              : e.message;
        });
        if (isAuthErr) {
          ref.read(authProvider.notifier).handleSessionExpired();
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _isSessionExpired = false;
          _error = 'Impossible de charger vos notifications.';
        });
      }
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
          icon: Icon(IconsaxPlusLinear.arrow_left_2, color: textPri, size: 20),
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
          if (auth.isAuthenticated && !_isSessionExpired && _notifications.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: BkoBounceable(
                onTap: _markAllRead,
                child: TextButton.icon(
                  onPressed: _markAllRead,
                  icon: const Icon(IconsaxPlusLinear.tick_circle, color: BkoTheme.goldAccent, size: 16),
                  label: Text(
                    'Tout marquer lu',
                    style: BkoTheme.fontPoppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: BkoTheme.goldAccent,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: (!auth.isAuthenticated || _isSessionExpired)
          ? Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: border),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: BkoTheme.goldAccent.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isSessionExpired
                              ? IconsaxPlusLinear.shield_cross
                              : IconsaxPlusLinear.notification_bing,
                          size: 36,
                          color: BkoTheme.goldAccent,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        _isSessionExpired ? 'Session expirée' : 'Connexion requise',
                        style: BkoTheme.fontPoppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: textPri,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isSessionExpired
                            ? 'Votre session d\'authentification s\'est terminée. Connectez-vous à nouveau pour consulter vos notifications.'
                            : 'Connectez-vous à votre compte Bamako Podcast pour recevoir les alertes sur vos abonnements et émissions.',
                        textAlign: TextAlign.center,
                        style: BkoTheme.fontLato(
                          fontSize: 13,
                          color: textSec,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 22),
                      BkoBounceable(
                        onTap: () async {
                          await context.push('/login');
                          if (mounted) _fetch();
                        },
                        child: Container(
                          width: double.infinity,
                          height: 46,
                          decoration: BoxDecoration(
                            color: BkoTheme.goldAccent,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            _isSessionExpired ? 'Se reconnecter' : 'Se connecter',
                            style: BkoTheme.fontPoppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : _loading
              ? const BkoNotificationListSkeleton(count: 6)
              : _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                IconsaxPlusLinear.warning_2,
                                size: 32,
                                color: Colors.redAccent,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: BkoTheme.fontLato(fontSize: 13, color: Colors.red.shade300),
                            ),
                            const SizedBox(height: 16),
                            BkoBounceable(
                              onTap: _fetch,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                                decoration: BoxDecoration(
                                  color: BkoTheme.goldAccent,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  'Réessayer',
                                  style: BkoTheme.fontPoppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : _notifications.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(18),
                                  decoration: BoxDecoration(
                                    color: surface,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: border),
                                  ),
                                  child: Icon(
                                    IconsaxPlusLinear.notification_bing,
                                    size: 40,
                                    color: textSec,
                                  ),
                                ),
                                const SizedBox(height: 16),
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
                                  style: BkoTheme.fontLato(
                                    fontSize: 12.5,
                                    color: textSec,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                BkoBounceable(
                                  onTap: () => context.go('/explore'),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: surface,
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(color: BkoTheme.goldAccent.withValues(alpha: 0.4)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(IconsaxPlusLinear.discover, size: 16, color: BkoTheme.goldAccent),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Découvrir des émissions',
                                          style: BkoTheme.fontPoppins(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w600,
                                            color: textPri,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          color: BkoTheme.goldAccent,
                          backgroundColor: surface,
                          onRefresh: _fetch,
                          child: ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                            itemCount: _notifications.length,
                            itemBuilder: (context, index) {
                              final notif = _notifications[index] as Map<String, dynamic>;
                              final isRead = notif['isRead'] == true;
                              final title = notif['title'] ?? 'Notification';
                              final body = notif['body'] ?? notif['message'] ?? '';

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: BkoBounceable(
                                  onTap: () => _onNotificationTap(notif),
                                  child: Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: isRead ? surface : const Color(0xFF1B1B1F),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isRead
                                            ? border
                                            : BkoTheme.goldAccent.withValues(alpha: 0.35),
                                      ),
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: isRead
                                                ? const Color(0xFF222226)
                                                : BkoTheme.goldAccent.withValues(alpha: 0.15),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            isRead
                                                ? IconsaxPlusLinear.notification
                                                : IconsaxPlusLinear.notification_bing,
                                            color: isRead ? textSec : BkoTheme.goldAccent,
                                            size: 18,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      title,
                                                      style: BkoTheme.fontPoppins(
                                                        fontSize: 13.5,
                                                        fontWeight: isRead ? FontWeight.w500 : FontWeight.w700,
                                                        color: textPri,
                                                      ),
                                                    ),
                                                  ),
                                                  if (!isRead)
                                                    Container(
                                                      width: 8,
                                                      height: 8,
                                                      margin: const EdgeInsets.only(left: 6),
                                                      decoration: const BoxDecoration(
                                                        color: BkoTheme.goldAccent,
                                                        shape: BoxShape.circle,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                              if (body.isNotEmpty) ...[
                                                const SizedBox(height: 4),
                                                Text(
                                                  body,
                                                  style: BkoTheme.fontLato(
                                                    fontSize: 12,
                                                    color: textSec,
                                                    height: 1.35,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
    );
  }
}
