import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bko_app/features/home/widgets/bko_drawer.dart';
import 'package:bko_app/features/auth/auth_controller.dart';
import 'package:bko_app/core/widgets/bko_download_toast.dart';

void main() {
  testWidgets('BkoDownloadToast is fully clickable and renders action', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                BkoDownloadToast.show(
                  context,
                  title: 'Épisode 12 - Les contes du Mandé',
                  podcastName: 'Bamako Culture',
                );
              },
              child: const Text('Tester Download Toast'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Tester Download Toast'));
    await tester.pumpAndSettle();

    expect(find.text('Téléchargement lancé'), findsOneWidget);
    expect(find.text('Épisode 12 - Les contes du Mandé'), findsOneWidget);
    expect(find.text('Voir'), findsOneWidget);

    // Tap on the toast
    await tester.tap(find.text('Voir'));
    await tester.pumpAndSettle();
  });

  testWidgets('BkoDrawer renders logout button and displays confirmation dialog on tap', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => _MockAuthNotifier()),
        ],
        child: const MaterialApp(
          home: Scaffold(
            drawer: BkoDrawer(),
            body: Center(child: Text('App Content')),
          ),
        ),
      ),
    );

    // Open drawer
    final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
    scaffoldState.openDrawer();
    await tester.pumpAndSettle();

    // Verify drawer items
    expect(find.text('Se déconnecter'), findsOneWidget);

    // Tap on "Se déconnecter"
    await tester.tap(find.text('Se déconnecter'));
    await tester.pumpAndSettle();

    // Verify confirmation dialog appears
    expect(find.text('Déconnexion'), findsOneWidget);
    expect(find.textContaining('vouloir vous déconnecter'), findsOneWidget);
    expect(find.text('Annuler'), findsOneWidget);

    // Cancel dialog
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(find.text('Déconnexion'), findsNothing);
  });
}

class _MockAuthNotifier extends AuthNotifier {
  _MockAuthNotifier() : super() {
    state = const AuthState(
      isAuthenticated: true,
      token: 'fake_test_token',
      user: {
        'id': 'user_1',
        'fullName': 'Mamadou Diarra',
        'email': 'mamadou@test.com',
        'roles': ['AUDITOR'],
      },
    );
  }
}
