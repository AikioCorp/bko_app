import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../../core/network/bko_api.dart';
import '../../core/theme/bko_theme.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/widgets/bko_bounceable.dart';
import '../../core/widgets/bko_haptics.dart';
import '../auth/auth_controller.dart';
import 'models/bko_notification.dart';
import 'notification_providers.dart';
import 'services/notification_destination_handler.dart';

/// Écran des Notifications de Bamako Podcast.
/// Conforme aux directives `mobile-designer` et `apple-design` :
/// - Iconsax uniquement (retour AppBackButton avec arrow_left_1)
/// - Zéro ombre, zéro dégradé, surfaces solides et contrastées
/// - Pagination sans doublon ni requêtes concurrentes
/// - Rollback optimiste en cas d'erreur serveur
/// - Espacement inférieur compatible avec le mini-lecteur persistant
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  final ScrollController _scrollController = ScrollController();

  List<BkoNotification> _notifications = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  String? _error;
  bool _isSessionExpired = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _fetch(isRefresh: false);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _loadingMore || !_hasMore) return;
    final threshold = _scrollController.position.maxScrollExtent - 200;
    if (_scrollController.position.pixels >= threshold) {
      _loadMore();
    }
  }

  Future<void> _fetch({bool isRefresh = false}) async {
    final auth = ref.read(authProvider);
    final token = auth.token;

    if (!auth.isAuthenticated || token == null || token.isEmpty) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = null;
          _isSessionExpired = false;
          _notifications = [];
        });
      }
      return;
    }

    if (!isRefresh) {
      setState(() {
        _loading = true;
        _error = null;
        _isSessionExpired = false;
      });
    }

    try {
      final res = await BkoApi.get('/me/notifications?limit=25', token: token);
      final parsed = NotificationListResponse.fromResponse(res);

      if (!mounted) return;
      setState(() {
        _notifications = parsed.items;
        _hasMore = parsed.items.length >= 25;
        _loading = false;
        _error = null;
        _isSessionExpired = false;
      });

      // Réconciliation immédiate du compteur de notifications non lues
      ref.read(unreadNotificationsProvider.notifier).setCount(parsed.unread);
    } on ApiException catch (e) {
      if (!mounted) return;
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
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _isSessionExpired = false;
        _error = 'Impossible de charger vos notifications pour le moment.';
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _notifications.isEmpty) return;

    final auth = ref.read(authProvider);
    final token = auth.token;
    if (token == null) return;

    setState(() => _loadingMore = true);

    final lastDate = _notifications.last.createdAt.toIso8601String();

    try {
      final res = await BkoApi.get(
        '/me/notifications?limit=25&before=${Uri.encodeComponent(lastDate)}',
        token: token,
      );
      final parsed = NotificationListResponse.fromResponse(res);

      if (!mounted) return;

      // Déduplication stricte par ID pour prévenir toute duplication visuelle
      final existingIds = _notifications.map((n) => n.id).toSet();
      final newItems = parsed.items.where((n) => !existingIds.contains(n.id)).toList();

      setState(() {
        _notifications.addAll(newItems);
        _hasMore = parsed.items.length >= 25;
        _loadingMore = false;
      });

      ref.read(unreadNotificationsProvider.notifier).setCount(parsed.unread);
    } catch (_) {
      if (mounted) {
        setState(() => _loadingMore = false);
      }
    }
  }

  Future<void> _markAllRead() async {
    final token = ref.read(authProvider).token;
    if (token == null || _notifications.isEmpty) return;

    BkoHaptics.light();

    final previousList = List<BkoNotification>.from(_notifications);
    final previousUnread = ref.read(unreadNotificationsProvider);
    final now = DateTime.now();

    // Mise à jour optimiste immédiate
    setState(() {
      _notifications = _notifications.map((n) => n.isRead ? n : n.copyWith(readAt: now)).toList();
    });
    ref.read(unreadNotificationsProvider.notifier).setCount(0);

    try {
      await BkoApi.post('/me/notifications/read', {}, token: token);
      // Réconciliation avec le serveur
      ref.read(unreadNotificationsProvider.notifier).fetchCount();
    } catch (_) {
      // Annulation en cas d'échec serveur
      if (mounted) {
        setState(() => _notifications = previousList);
        ref.read(unreadNotificationsProvider.notifier).setCount(previousUnread);
        _showToast("Échec du marquage des notifications.");
      }
    }
  }

  Future<void> _onNotificationTap(BkoNotification notif) async {
    final token = ref.read(authProvider).token;

    // Marquage individuel optimiste si non lue
    if (!notif.isRead && token != null) {
      final previousList = List<BkoNotification>.from(_notifications);
      final now = DateTime.now();

      setState(() {
        _notifications = _notifications.map((n) {
          return n.id == notif.id ? n.copyWith(readAt: now) : n;
        }).toList();
      });
      ref.read(unreadNotificationsProvider.notifier).markAsReadLocally(1);

      BkoApi.post(
        '/me/notifications/read',
        {'ids': [notif.id]},
        token: token,
      ).then((_) {
        // Réconciliation avec le serveur
        ref.read(unreadNotificationsProvider.notifier).fetchCount();
      }).catchError((_) {
        // Rollback en cas d'échec
        if (mounted) {
          setState(() => _notifications = previousList);
          ref.read(unreadNotificationsProvider.notifier).fetchCount();
        }
      });
    }

    // Gestion unifiée de la destination
    if (notif.link != null && notif.link!.isNotEmpty) {
      await NotificationDestinationHandler.navigate(context, notif.link, ref: ref);
    }
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        elevation: 0,
        backgroundColor: BkoTheme.getBgSurfaceElevated(context),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 88),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: BkoTheme.getBorderSubtle(context)),
        ),
        content: Text(
          message,
          style: BkoTheme.fontLato(fontSize: 13, color: BkoTheme.getTextPrimary(context)),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final unreadCount = ref.watch(unreadNotificationsProvider);

    final bgObsidian = BkoTheme.getBgObsidian(context);
    final textPri = BkoTheme.getTextPrimary(context);

    final bottomPadding = 120.0 + MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: bgObsidian,
      appBar: AppBar(
        backgroundColor: bgObsidian,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: const AppBackButton(),
        centerTitle: false,
        title: Text(
          'Notifications',
          style: BkoTheme.fontPoppins(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: textPri,
          ),
        ),
        actions: [
          if (auth.isAuthenticated && unreadCount > 0)
            BkoBounceable(
              onTap: _markAllRead,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                margin: const EdgeInsets.only(right: 14),
                decoration: BoxDecoration(
                  color: BkoTheme.goldAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: BkoTheme.goldAccent.withValues(alpha: 0.35),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      IconsaxPlusLinear.tick_circle,
                      size: 15,
                      color: BkoTheme.goldAccent,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Tout lire ($unreadCount)',
                      style: BkoTheme.fontPoppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: BkoTheme.goldAccent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      body: Builder(
        builder: (context) {
          if (!auth.isAuthenticated) {
            return _buildUnauthenticatedState(context);
          }

          if (_loading) {
            return _buildSkeletonLoader(context);
          }

          if (_error != null) {
            return _buildErrorState(context);
          }

          if (_notifications.isEmpty) {
            return _buildEmptyState(context);
          }

          return RefreshIndicator(
            color: BkoTheme.goldAccent,
            backgroundColor: BkoTheme.getBgSurfaceElevated(context),
            onRefresh: () => _fetch(isRefresh: true),
            child: ListView.separated(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              padding: EdgeInsets.fromLTRB(16, 12, 16, bottomPadding),
              itemCount: _notifications.length + (_loadingMore ? 1 : 0),
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                if (index >= _notifications.length) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: BkoTheme.goldAccent,
                        ),
                      ),
                    ),
                  );
                }

                final notif = _notifications[index];
                return _buildNotificationCard(context, notif);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildNotificationCard(BuildContext context, BkoNotification notif) {
    final textPri = BkoTheme.getTextPrimary(context);
    final textSec = BkoTheme.getTextSecondary(context);
    final surface = BkoTheme.getBgSurfaceElevated(context);
    final border = BkoTheme.getBorderSubtle(context);

    final isUnread = !notif.isRead;

    return BkoBounceable(
      onTap: () => _onNotificationTap(notif),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isUnread ? surface : surface.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isUnread ? BkoTheme.goldAccent.withValues(alpha: 0.4) : border,
            width: isUnread ? 1.2 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Indicateur visuel d'état lu / non-lu
            Container(
              margin: const EdgeInsets.only(top: 3),
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isUnread ? BkoTheme.goldAccent : Colors.transparent,
                border: Border.all(
                  color: isUnread ? BkoTheme.goldAccent : textSec.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Contenu texte
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notif.title,
                    style: BkoTheme.fontPoppins(
                      fontSize: 14,
                      fontWeight: isUnread ? FontWeight.w700 : FontWeight.w600,
                      color: textPri,
                    ),
                  ),
                  if (notif.body != null && notif.body!.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      notif.body!,
                      style: BkoTheme.fontLato(
                        fontSize: 12.5,
                        color: textSec,
                        height: 1.35,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    _formatDate(notif.createdAt),
                    style: BkoTheme.fontLato(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: textSec.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),

            if (notif.link != null && notif.link!.isNotEmpty) ...[
              const SizedBox(width: 8),
              Icon(
                IconsaxPlusLinear.arrow_right_3,
                size: 16,
                color: isUnread ? BkoTheme.goldAccent : textSec,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final textPri = BkoTheme.getTextPrimary(context);
    final textSec = BkoTheme.getTextSecondary(context);
    final surface = BkoTheme.getBgSurfaceElevated(context);
    final border = BkoTheme.getBorderSubtle(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: BkoTheme.goldAccent.withValues(alpha: 0.12),
                  border: Border.all(color: BkoTheme.goldAccent.withValues(alpha: 0.3)),
                ),
                child: const Center(
                  child: Icon(
                    IconsaxPlusLinear.notification_1,
                    size: 26,
                    color: BkoTheme.goldAccent,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Vous êtes à jour',
                textAlign: TextAlign.center,
                style: BkoTheme.fontPoppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: textPri,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Aucune notification pour le moment. Vos alertes de nouveaux épisodes s\'afficheront ici.',
                textAlign: TextAlign.center,
                style: BkoTheme.fontLato(
                  fontSize: 13,
                  color: textSec,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    final textPri = BkoTheme.getTextPrimary(context);
    final textSec = BkoTheme.getTextSecondary(context);
    final surface = BkoTheme.getBgSurfaceElevated(context);
    final border = BkoTheme.getBorderSubtle(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
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
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.red.withValues(alpha: 0.12),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: const Center(
                  child: Icon(
                    IconsaxPlusLinear.warning_2,
                    size: 24,
                    color: Colors.redAccent,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                _isSessionExpired ? 'Session expirée' : 'Impossible de charger les notifications',
                textAlign: TextAlign.center,
                style: BkoTheme.fontPoppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: textPri,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _error ?? 'Une erreur est survenue.',
                textAlign: TextAlign.center,
                style: BkoTheme.fontLato(
                  fontSize: 12.5,
                  color: textSec,
                ),
              ),
              const SizedBox(height: 18),
              BkoBounceable(
                onTap: () {
                  if (_isSessionExpired) {
                    context.push('/login?redirect=/notifications');
                  } else {
                    _fetch(isRefresh: false);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: BkoTheme.goldAccent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _isSessionExpired ? 'Se reconnecter' : 'Réessayer',
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
      ),
    );
  }

  Widget _buildUnauthenticatedState(BuildContext context) {
    final textPri = BkoTheme.getTextPrimary(context);
    final textSec = BkoTheme.getTextSecondary(context);
    final surface = BkoTheme.getBgSurfaceElevated(context);
    final border = BkoTheme.getBorderSubtle(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: BkoTheme.goldAccent.withValues(alpha: 0.12),
                  border: Border.all(color: BkoTheme.goldAccent.withValues(alpha: 0.3)),
                ),
                child: const Center(
                  child: Icon(
                    IconsaxPlusLinear.user,
                    size: 26,
                    color: BkoTheme.goldAccent,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Connectez-vous',
                style: BkoTheme.fontPoppins(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: textPri,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Connectez-vous pour retrouver vos alertes de nouveaux épisodes et vos notifications d\'écoute.',
                textAlign: TextAlign.center,
                style: BkoTheme.fontLato(
                  fontSize: 13,
                  color: textSec,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              BkoBounceable(
                onTap: () => context.push('/login?redirect=/notifications'),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: BkoTheme.goldAccent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      'Se connecter',
                      style: BkoTheme.fontPoppins(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSkeletonLoader(BuildContext context) {
    final surface = BkoTheme.getBgSurfaceElevated(context);
    final border = BkoTheme.getBorderSubtle(context);

    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                height: 14,
                decoration: BoxDecoration(
                  color: border.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: 180,
                height: 12,
                decoration: BoxDecoration(
                  color: border.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'À l\'instant';
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Il y a ${diff.inHours} h';
    if (diff.inDays < 7) return 'Il y a ${diff.inDays} j';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
