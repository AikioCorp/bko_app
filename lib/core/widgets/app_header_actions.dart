import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import '../../features/notifications/notification_providers.dart';
import '../../features/shell/shell_providers.dart';
import '../theme/bko_theme.dart';

/// Shared shortcuts for page headers. Full-screen players do not include this widget.
class AppHeaderActions extends ConsumerWidget {
  const AppHeaderActions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(isFullPlayerOpenProvider)) {
      return const SizedBox.shrink();
    }
    final path =
        GoRouter.maybeOf(context)?.routeInformationProvider.value.uri.path;
    final unread = ref.watch(unreadNotificationsProvider);
    final foreground = BkoTheme.getTextPrimary(context);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      if (path != '/downloads')
        IconButton(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          tooltip: 'Téléchargements',
          icon: Icon(IconsaxPlusLinear.document_download,
              size: 22, color: foreground),
          onPressed: () => context.push('/downloads'),
        ),
      if (path != '/notifications')
        IconButton(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          tooltip:
              unread > 0 ? 'Notifications, $unread non lues' : 'Notifications',
          icon: Badge(
            isLabelVisible: unread > 0,
            backgroundColor: BkoTheme.goldAccent,
            textColor: BkoTheme.onBrand,
            label: Text(unread > 99 ? '99+' : '$unread'),
            child: Icon(IconsaxPlusLinear.notification,
                size: 22, color: foreground),
          ),
          onPressed: () => context.push('/notifications'),
        ),
    ]);
  }
}
