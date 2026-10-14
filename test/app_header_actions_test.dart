import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:bko_app/core/widgets/app_header_actions.dart';
import 'package:bko_app/features/notifications/notification_providers.dart';

class _Unread extends UnreadNotificationsNotifier {
  _Unread(super.ref) { state = 3; }
}

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  Future<GoRouter> showHeader(WidgetTester tester, String path) async {
    final router = GoRouter(initialLocation: path, routes: [
      for (final path in ['/content', '/downloads', '/notifications'])
        GoRoute(path: path, builder: (context, state) => Scaffold(
          appBar: AppBar(actions: const [AppHeaderActions()]),
          body: Text('Page ${state.uri.path}'),
        )),
    ]);
    await tester.pumpWidget(ProviderScope(overrides: [
      unreadNotificationsProvider.overrideWith((ref) => _Unread(ref)),
    ], child: MaterialApp.router(routerConfig: router)));
    await tester.pumpAndSettle();
    return router;
  }
  testWidgets('header shows unread badge and downloads opens the correct page', (tester) async {
    final router = await showHeader(tester, '/content');
    addTearDown(router.dispose);
    expect(find.byTooltip('Notifications, 3 non lues'), findsOneWidget);
    await tester.tap(find.byTooltip('Téléchargements'));
    await tester.pumpAndSettle();
    expect(find.text('Page /downloads'), findsOneWidget);
    expect(find.byTooltip('Téléchargements'), findsNothing);
    expect(find.byTooltip('Notifications, 3 non lues'), findsOneWidget);
  });
  testWidgets('notifications page retains downloads and hides its own shortcut', (tester) async {
    final router = await showHeader(tester, '/notifications');
    addTearDown(router.dispose);
    expect(find.byTooltip('Téléchargements'), findsOneWidget);
    expect(find.byTooltip('Notifications, 3 non lues'), findsNothing);
  });
}
