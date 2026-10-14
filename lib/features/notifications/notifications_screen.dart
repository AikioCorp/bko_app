import '../../core/widgets/app_header_actions.dart';
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
/// - Filtres par puces (Toutes / Non lues) avec transitions fluides
/// - Groupement contextuel par date (Aujourd'hui, Cette semaine, Plus tôt)
/// - Micro-animations d'entrée en cascade et retours haptiques sobres
/// - Rollback optimiste en cas d'erreur serveur
/// - Espacement inférieur compatible avec le mini-lecteur persistant
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  late final AnimationController _animationController;

  List<BkoNotification> _notifications = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  String? _error;
  bool _isSessionExpired = false;

  /// Filtre actif : 0 = Toutes, 1 = Non lues
  int _activeFilter = 0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _scrollController.addListener(_onScroll);
    _fetch(isRefresh: false);
  }

  @override
  void dispose() {
    _animationController.dispose();
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
      final res = await BkoApi.get('/me/notifications?limit=30', token: token);
      final parsed = NotificationListResponse.fromResponse(res);

      if (!mounted) return;
      setState(() {
        _notifications = parsed.items;
        _hasMore = parsed.items.length >= 30;
        _loading = false;
        _error = null;
        _isSessionExpired = false;
      });

      _animationController.forward(from: 0.0);

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
        '/me/notifications?limit=30&before=${Uri.encodeComponent(lastDate)}',
        token: token,
      );
      final parsed = NotificationListResponse.fromResponse(res);

      if (!mounted) return;

      // Déduplication stricte par ID pour prévenir toute duplication visuelle
      final existingIds = _notifications.map((n) => n.id).toSet();
      final newItems = parsed.items.where((n) => !existingIds.contains(n.id)).toList();

      setState(() {
        _notifications.addAll(newItems);
        _hasMore = parsed.items.length >= 30;
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

    BkoHaptics.success();

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
      ref.read(unreadNotificationsProvider.notifier).fetchCount();
      _showToast('Toutes vos notifications sont marquées comme lues.');
    } catch (_) {
      if (mounted) {
        setState(() => _notifications = previousList);
        ref.read(unreadNotificationsProvider.notifier).setCount(previousUnread);
        _showToast('Échec du marquage des notifications.');
      }
    }
  }

  Future<void> _deleteNotification(BkoNotification notif) async {
    final token = ref.read(authProvider).token;
    if (token == null) return;

    BkoHaptics.medium();

    final previousList = List<BkoNotification>.from(_notifications);
    final wasUnread = !notif.isRead;
    final previousUnread = ref.read(unreadNotificationsProvider);

    setState(() {
      _notifications.removeWhere((n) => n.id == notif.id);
    });
    if (wasUnread) {
      ref.read(unreadNotificationsProvider.notifier).markAsReadLocally(1);
    }

    try {
      await BkoApi.delete('/me/notifications/${notif.id}', token: token);
      ref.read(unreadNotificationsProvider.notifier).fetchCount();
      _showToast('Notification supprimée.');
    } catch (_) {
      if (mounted) {
        setState(() => _notifications = previousList);
        ref.read(unreadNotificationsProvider.notifier).setCount(previousUnread);
        _showToast('Échec de la suppression de la notification.');
      }
    }
  }

  Future<void> _clearAllNotifications() async {
    final token = ref.read(authProvider).token;
    if (token == null || _notifications.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BkoTheme.getBgSurfaceElevated(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: BkoTheme.getBorderSubtle(context)),
        ),
        title: Text(
          'Tout effacer ?',
          style: BkoTheme.fontPoppins(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: BkoTheme.getTextPrimary(context),
          ),
        ),
        content: Text(
          'Voulez-vous supprimer l\'ensemble de vos notifications ? Cette action est irréversible.',
          style: BkoTheme.fontLato(
            fontSize: 13,
            color: BkoTheme.getTextSecondary(context),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Annuler',
              style: TextStyle(color: BkoTheme.getTextSecondary(context)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent.shade700,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Tout supprimer'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    BkoHaptics.medium();

    final previousList = List<BkoNotification>.from(_notifications);
    final previousUnread = ref.read(unreadNotificationsProvider);

    setState(() {
      _notifications = [];
    });
    ref.read(unreadNotificationsProvider.notifier).setCount(0);

    try {
      await BkoApi.delete('/me/notifications', token: token);
      _showToast('Toutes vos notifications ont été effacées.');
    } catch (_) {
      if (mounted) {
        setState(() => _notifications = previousList);
        ref.read(unreadNotificationsProvider.notifier).setCount(previousUnread);
        _showToast('Impossible d\'effacer les notifications.');
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
        ref.read(unreadNotificationsProvider.notifier).fetchCount();
      }).catchError((_) {
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

  List<BkoNotification> get _filteredNotifications {
    if (_activeFilter == 1) {
      return _notifications.where((n) => !n.isRead).toList();
    }
    return _notifications;
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
          const AppHeaderActions(),
          if (auth.isAuthenticated && _notifications.isNotEmpty) ...[
            if (unreadCount > 0)
              BkoBounceable(
                onTap: _markAllRead,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  margin: const EdgeInsets.only(right: 8),
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
                        size: 14,
                        color: BkoTheme.goldAccent,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Tout lire ($unreadCount)',
                        style: BkoTheme.fontPoppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: BkoTheme.goldAccent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            BkoBounceable(
              onTap: _clearAllNotifications,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                margin: const EdgeInsets.only(right: 14),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.redAccent.withValues(alpha: 0.35),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      IconsaxPlusLinear.trash,
                      size: 14,
                      color: Colors.redAccent,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Tout effacer',
                      style: BkoTheme.fontPoppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.redAccent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
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
            return _buildEmptyState(context, isFiltered: false);
          }

          final displayList = _filteredNotifications;

          return Column(
            children: [
              // 1. Barre de filtres par puces (Toutes / Non lues)
              _buildFilterChips(unreadCount),

              // 2. Liste de notifications groupées
              Expanded(
                child: displayList.isEmpty
                    ? _buildEmptyState(context, isFiltered: true)
                    : RefreshIndicator(
                        color: BkoTheme.goldAccent,
                        backgroundColor: BkoTheme.getBgSurfaceElevated(context),
                        onRefresh: () => _fetch(isRefresh: true),
                        child: _buildGroupedListView(displayList, bottomPadding),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Puces de filtrage (Toutes / Non lues)
  Widget _buildFilterChips(int unreadCount) {
    final border = BkoTheme.getBorderSubtle(context);
    final surface = BkoTheme.getBgSurfaceElevated(context);
    final textPri = BkoTheme.getTextPrimary(context);
    final textSec = BkoTheme.getTextSecondary(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Puce Toutes
          _buildFilterChip(
            label: 'Toutes (${_notifications.length})',
            isSelected: _activeFilter == 0,
            onTap: () {
              BkoHaptics.light();
              setState(() => _activeFilter = 0);
            },
            surface: surface,
            border: border,
            textPri: textPri,
            textSec: textSec,
          ),
          const SizedBox(width: 8),

          // Puce Non lues
          _buildFilterChip(
            label: unreadCount > 0 ? 'Non lues ($unreadCount)' : 'Non lues',
            isSelected: _activeFilter == 1,
            badgeCount: unreadCount,
            onTap: () {
              BkoHaptics.light();
              setState(() => _activeFilter = 1);
            },
            surface: surface,
            border: border,
            textPri: textPri,
            textSec: textSec,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required Color surface,
    required Color border,
    required Color textPri,
    required Color textSec,
    int badgeCount = 0,
  }) {
    return BkoBounceable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? BkoTheme.goldAccent.withValues(alpha: 0.15) : surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? BkoTheme.goldAccent : border,
            width: isSelected ? 1.2 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: BkoTheme.fontPoppins(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? BkoTheme.goldAccent : textSec,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Liste avec en-têtes de dates contextuels (Aujourd'hui, Cette semaine, Plus tôt)
  Widget _buildGroupedListView(List<BkoNotification> items, double bottomPadding) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekAgo = today.subtract(const Duration(days: 7));

    final todayItems = <BkoNotification>[];
    final thisWeekItems = <BkoNotification>[];
    final earlierItems = <BkoNotification>[];

    for (final notif in items) {
      final date = notif.createdAt;
      final notifDate = DateTime(date.year, date.month, date.day);
      if (notifDate.isAtSameMomentAs(today) || notifDate.isAfter(today)) {
        todayItems.add(notif);
      } else if (notifDate.isAfter(weekAgo)) {
        thisWeekItems.add(notif);
      } else {
        earlierItems.add(notif);
      }
    }

    final sections = <_NotificationSection>[];
    if (todayItems.isNotEmpty) {
      sections.add(_NotificationSection(title: "AUJOURD'HUI", items: todayItems));
    }
    if (thisWeekItems.isNotEmpty) {
      sections.add(_NotificationSection(title: "CETTE SEMAINE", items: thisWeekItems));
    }
    if (earlierItems.isNotEmpty) {
      sections.add(_NotificationSection(title: "PLUS TÔT", items: earlierItems));
    }

    return ListView.builder(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: EdgeInsets.fromLTRB(16, 6, 16, bottomPadding),
      itemCount: sections.fold<int>(0, (sum, s) => sum + 1 + s.items.length) + (_loadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        var cursor = 0;
        for (final section in sections) {
          if (index == cursor) {
            return _buildSectionHeader(section.title);
          }
          cursor++;

          if (index < cursor + section.items.length) {
            final itemIndex = index - cursor;
            final notif = section.items[itemIndex];
            final globalIndex = items.indexOf(notif);

            return _buildAnimatedCard(notif, globalIndex);
          }
          cursor += section.items.length;
        }

        // Loader de bas de page pour la pagination
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: BkoTheme.goldAccent,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    final textSec = BkoTheme.getTextSecondary(context);
    final border = BkoTheme.getBorderSubtle(context);

    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 8),
      child: Row(
        children: [
          Text(
            title,
            style: BkoTheme.fontPoppins(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: textSec.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 1,
              color: border.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedCard(BkoNotification notif, int index) {
    // Entrée en cascade Apple fluide
    final delay = (index * 0.05).clamp(0.0, 0.4);
    final animation = CurvedAnimation(
      parent: _animationController,
      curve: Interval(delay, (delay + 0.5).clamp(0.0, 1.0), curve: Curves.easeOutCubic),
    );

    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.08),
          end: Offset.zero,
        ).animate(animation),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Dismissible(
            key: ValueKey('notif_${notif.id}'),
            direction: DismissDirection.endToStart,
            onUpdate: (details) {
              if (details.reached && !details.previousReached) {
                BkoHaptics.light();
              }
            },
            onDismissed: (_) {
              _deleteNotification(notif);
            },
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              decoration: BoxDecoration(
                color: Colors.redAccent.shade700,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    IconsaxPlusLinear.trash,
                    color: Colors.white,
                    size: 19,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Supprimer',
                    style: BkoTheme.fontPoppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            child: _buildNotificationCard(context, notif),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationCard(BuildContext context, BkoNotification notif) {
    final textPri = BkoTheme.getTextPrimary(context);
    final textSec = BkoTheme.getTextSecondary(context);
    final surface = BkoTheme.getBgSurfaceElevated(context);
    final border = BkoTheme.getBorderSubtle(context);

    final isUnread = !notif.isRead;
    final iconData = _iconForType(notif.type);

    return BkoBounceable(
      onTap: () => _onNotificationTap(notif),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isUnread ? surface : surface.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isUnread ? BkoTheme.goldAccent.withValues(alpha: 0.45) : border,
            width: isUnread ? 1.2 : 1.0,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Badge d'icône thématique selon le type de notification
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isUnread
                    ? BkoTheme.goldAccent.withValues(alpha: 0.15)
                    : BkoTheme.getBgSurface(context),
                border: Border.all(
                  color: isUnread
                      ? BkoTheme.goldAccent.withValues(alpha: 0.4)
                      : border,
                  width: 1,
                ),
              ),
              child: Center(
                child: Icon(
                  iconData,
                  size: 19,
                  color: isUnread ? BkoTheme.goldAccent : textSec,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // 2. Contenu texte principal
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          notif.title,
                          style: BkoTheme.fontPoppins(
                            fontSize: 13.5,
                            fontWeight: isUnread ? FontWeight.w700 : FontWeight.w600,
                            color: textPri,
                            height: 1.3,
                          ),
                        ),
                      ),
                      if (isUnread) ...[
                        const SizedBox(width: 6),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: BkoTheme.goldAccent,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (notif.body != null && notif.body!.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      notif.body!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: BkoTheme.fontLato(
                        fontSize: 12.5,
                        color: textSec,
                        height: 1.35,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),

                  // Ligne d'horodatage et statut
                  Row(
                    children: [
                      Icon(
                        IconsaxPlusLinear.clock,
                        size: 12,
                        color: textSec.withValues(alpha: 0.6),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _formatDate(notif.createdAt),
                        style: BkoTheme.fontLato(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: textSec.withValues(alpha: 0.75),
                        ),
                      ),
                      if (isUnread) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: BkoTheme.goldAccent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'NOUVEAU',
                            style: BkoTheme.fontPoppins(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                              color: BkoTheme.goldAccent,
                            ),
                          ),
                        ),
                      ],
                      const Spacer(),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        icon: Icon(
                          IconsaxPlusLinear.trash,
                          size: 14,
                          color: textSec.withValues(alpha: 0.45),
                        ),
                        onPressed: () => _deleteNotification(notif),
                      ),
                      if (notif.link != null && notif.link!.isNotEmpty) ...[
                        const SizedBox(width: 4),
                        Icon(
                          IconsaxPlusLinear.arrow_right_3,
                          size: 14,
                          color: isUnread ? BkoTheme.goldAccent : textSec.withValues(alpha: 0.6),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconForType(String type) {
    switch (type.toUpperCase()) {
      case 'NEW_EPISODE':
        return IconsaxPlusLinear.microphone_2;
      case 'CAMPAIGN':
      case 'PROMOTION':
        return IconsaxPlusLinear.notification_bing;
      case 'FAVORITE':
      case 'LIKE':
        return IconsaxPlusLinear.heart;
      case 'PLAYLIST':
        return IconsaxPlusLinear.music_playlist;
      case 'STUDIO':
        return IconsaxPlusLinear.video_play;
      case 'SYSTEM':
      default:
        return IconsaxPlusLinear.notification;
    }
  }

  Widget _buildEmptyState(BuildContext context, {required bool isFiltered}) {
    final textPri = BkoTheme.getTextPrimary(context);
    final textSec = BkoTheme.getTextSecondary(context);
    final surface = BkoTheme.getBgSurfaceElevated(context);
    final border = BkoTheme.getBorderSubtle(context);

    final title = isFiltered
        ? 'Toutes vos notifications sont lues'
        : 'Vous êtes à jour';
    final subtitle = isFiltered
        ? 'Basculez sur « Toutes » pour consulter l\'historique de vos notifications.'
        : 'Aucune notification pour le moment. Vos alertes de nouveaux épisodes s\'afficheront ici.';

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
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: BkoTheme.goldAccent.withValues(alpha: 0.12),
                  border: Border.all(color: BkoTheme.goldAccent.withValues(alpha: 0.3)),
                ),
                child: const Center(
                  child: Icon(
                    IconsaxPlusLinear.notification_status,
                    size: 26,
                    color: BkoTheme.goldAccent,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: BkoTheme.fontPoppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: textPri,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: BkoTheme.fontLato(
                  fontSize: 13,
                  color: textSec,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              BkoBounceable(
                onTap: () {
                  if (isFiltered) {
                    setState(() => _activeFilter = 0);
                  } else {
                    context.go('/explore');
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                  decoration: BoxDecoration(
                    color: BkoTheme.goldAccent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isFiltered ? IconsaxPlusLinear.refresh : IconsaxPlusLinear.discover,
                        size: 16,
                        color: Colors.black,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isFiltered ? 'Voir toutes les notifications' : 'Explorer les podcasts',
                        style: BkoTheme.fontPoppins(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
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
      itemCount: 5,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: border.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
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
                      width: 200,
                      height: 12,
                      decoration: BoxDecoration(
                        color: border.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 80,
                      height: 10,
                      decoration: BoxDecoration(
                        color: border.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
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

class _NotificationSection {
  final String title;
  final List<BkoNotification> items;

  _NotificationSection({required this.title, required this.items});
}
