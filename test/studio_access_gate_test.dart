import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bko_app/features/auth/auth_controller.dart';
import 'package:bko_app/features/notifications/notification_providers.dart';
import 'package:bko_app/features/studio/studio_access_gate.dart';

class _AuthenticatedUser extends AuthNotifier {
  _AuthenticatedUser() {
    state = const AuthState(isAuthenticated: true, token: 'test', user: {'id': 'auditor'});
  }
}

class _MockUnreadNotifier extends UnreadNotificationsNotifier {
  _MockUnreadNotifier(super.ref) {
    state = 0;
  }

  @override
  Future<void> fetchCount() async {}
}

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  Future<void> showGate(WidgetTester tester, Map<String, dynamic> access,
      {bool requireProfile = false}) async {
    await tester.pumpWidget(ProviderScope(overrides: [
      authProvider.overrideWith((ref) => _AuthenticatedUser()),
      studioAccessProvider.overrideWith((ref) async => access),
      unreadNotificationsProvider.overrideWith((ref) => _MockUnreadNotifier(ref)),
    ], child: MaterialApp(home: StudioAccessGate(requireProfile: requireProfile,
      child: const Scaffold(body: Text('Studio accessible'))))));
    await tester.pumpAndSettle();
  }
  testWidgets('auditor sees activation and cannot see protected content', (tester) async {
    await showGate(tester, {'canAccess': false, 'canCreatePodcast': false});
    expect(find.text('Activer mon Studio'), findsOneWidget);
    expect(find.text('Studio accessible'), findsNothing);
  });
  testWidgets('invited collaborator can manage existing shows', (tester) async {
    await showGate(tester, {'canAccess': true, 'canCreatePodcast': false});
    expect(find.text('Studio accessible'), findsOneWidget);
  });
  testWidgets('collaborator must activate own profile to create a show', (tester) async {
    await showGate(tester, {'canAccess': true, 'canCreatePodcast': false}, requireProfile: true);
    expect(find.text('Activer mon Studio'), findsOneWidget);
    expect(find.text('Studio accessible'), findsNothing);
  });
  testWidgets('activated creator can create a show', (tester) async {
    await showGate(tester, {'canAccess': true, 'canCreatePodcast': true}, requireProfile: true);
    expect(find.text('Studio accessible'), findsOneWidget);
  });
}
