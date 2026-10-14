import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bko_app/features/notifications/models/bko_notification.dart';
import 'package:bko_app/features/notifications/notification_providers.dart';
import 'package:bko_app/features/notifications/services/notification_destination_handler.dart';
import 'package:bko_app/features/notifications/notifications_screen.dart';
import 'package:bko_app/features/auth/auth_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (MethodCall methodCall) async => null,
    );
  });

  group('1. Contrat serveur et parsing explicite', () {
    test('NotificationListResponse parse la structure réelle { items, unread }', () {
      final json = {
        'items': [
          {
            'id': 'notif_1',
            'type': 'NEW_EPISODE',
            'title': 'Nouvel épisode : Bamako Culture',
            'body': 'Les contes du Mandé',
            'link': '/podcasts/bamako-culture/episodes/les-contes-du-mande',
            'readAt': null,
            'createdAt': '2026-10-14T10:00:00.000Z',
          },
          {
            'id': 'notif_2',
            'type': 'CAMPAIGN',
            'title': 'Bienvenue sur Bamako Podcast',
            'body': 'Découvrez nos nouveautés',
            'link': '/explore',
            'readAt': '2026-10-14T11:00:00.000Z',
            'createdAt': '2026-10-14T09:00:00.000Z',
          },
        ],
        'unread': 1,
      };

      final response = NotificationListResponse.fromResponse(json);

      expect(response.items.length, 2);
      expect(response.unread, 1);

      final notif1 = response.items[0];
      expect(notif1.id, 'notif_1');
      expect(notif1.isRead, false); // readAt == null
      expect(notif1.link, '/podcasts/bamako-culture/episodes/les-contes-du-mande');

      final notif2 = response.items[1];
      expect(notif2.id, 'notif_2');
      expect(notif2.isRead, true); // readAt != null
    });

    test('Réponse invalide lève FormatException au lieu de masquer une erreur', () {
      expect(
        () => NotificationListResponse.fromResponse({'invalidKey': 'some_data'}),
        throwsA(isA<FormatException>()),
      );

      expect(
        () => NotificationListResponse.fromResponse([]),
        throwsA(isA<FormatException>()),
      );

      expect(
        () => BkoNotification.fromJson({'title': 'Sans ID'}),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('2. Normalisation et validation des destinations', () {
    test('normalizeDestination convertit les URL complètes et gère les slashes', () {
      expect(
        NotificationDestinationHandler.normalizeDestination('https://bamakopodcast.ml/podcasts/culture'),
        '/podcasts/culture',
      );
      expect(
        NotificationDestinationHandler.normalizeDestination('podcasts/culture'),
        '/podcasts/culture',
      );
      expect(
        NotificationDestinationHandler.normalizeDestination('//podcasts/culture'),
        '/podcasts/culture',
      );
      expect(
        NotificationDestinationHandler.normalizeDestination(null),
        isNull,
      );
      expect(
        NotificationDestinationHandler.normalizeDestination('   '),
        isNull,
      );
    });

    test('isValidRoute valide les routes internes de Bamako Podcast', () {
      expect(NotificationDestinationHandler.isValidRoute('/podcasts/culture/episodes/ep-1'), isTrue);
      expect(NotificationDestinationHandler.isValidRoute('/podcasts/culture'), isTrue);
      expect(NotificationDestinationHandler.isValidRoute('/downloads'), isTrue);
      expect(NotificationDestinationHandler.isValidRoute('/notifications'), isTrue);
      expect(NotificationDestinationHandler.isValidRoute('/unknown/route/not/supported'), isFalse);
    });
  });

  group('3. UnreadNotificationsNotifier et isolation de compte', () {
    testWidgets('markAsReadLocally décrémente correctement et ne descend pas sous 0', (tester) async {
      final providerContainer = ProviderContainer(
        overrides: [
          authProvider.overrideWith((ref) => _MockLoggedOutAuthNotifier()),
        ],
      );
      try {
        final notifier = providerContainer.read(unreadNotificationsProvider.notifier);

        notifier.setCount(5);
        expect(providerContainer.read(unreadNotificationsProvider), 5);

        notifier.markAsReadLocally(2);
        expect(providerContainer.read(unreadNotificationsProvider), 3);

        notifier.markAsReadLocally(10);
        expect(providerContainer.read(unreadNotificationsProvider), 0);
      } finally {
        providerContainer.dispose();
      }
    });

    testWidgets('reset remet immédiatement le compteur à 0 lors de la déconnexion', (tester) async {
      final providerContainer = ProviderContainer(
        overrides: [
          authProvider.overrideWith((ref) => _MockLoggedOutAuthNotifier()),
        ],
      );
      try {
        final notifier = providerContainer.read(unreadNotificationsProvider.notifier);

        notifier.setCount(8);
        expect(providerContainer.read(unreadNotificationsProvider), 8);

        notifier.reset();
        expect(providerContainer.read(unreadNotificationsProvider), 0);
      } finally {
        providerContainer.dispose();
      }
    });
  });

  group('4. NotificationsScreen UI Tests', () {
    testWidgets('Affiche l invitation de connexion si utilisateur non authentifié', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => _MockLoggedOutAuthNotifier()),
          ],
          child: const MaterialApp(
            home: NotificationsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Connectez-vous'), findsOneWidget);
      expect(find.text('Se connecter'), findsOneWidget);
    });

    test('markAsReadLocally et décrémentation lors de la suppression d une notification non lue', () {
      final container = ProviderContainer();
      try {
        final notifier = container.read(unreadNotificationsProvider.notifier);
        notifier.setCount(3);
        expect(container.read(unreadNotificationsProvider), 3);

        notifier.markAsReadLocally(1);
        expect(container.read(unreadNotificationsProvider), 2);

        notifier.markAsReadLocally(5);
        expect(container.read(unreadNotificationsProvider), 0);
      } finally {
        container.dispose();
      }
    });
  });
}

class _MockLoggedOutAuthNotifier extends AuthNotifier {
  _MockLoggedOutAuthNotifier() : super() {
    state = const AuthState(isAuthenticated: false);
  }
}
