import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bko_app/features/auth/forgot_password_screen.dart';
import 'package:bko_app/core/routing/app_router.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ForgotPasswordScreen & OTP Reset Flow Tests', () {
    testWidgets('1. Step 1: Displays email input, title and submit button', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ForgotPasswordScreen(),
        ),
      );

      expect(find.text('Mot de passe oublié'), findsOneWidget);
      expect(find.text('Adresse email'), findsOneWidget);
      expect(find.text('RECEVOIR LE CODE OTP'), findsOneWidget);
      expect(find.byType(TextFormField), findsOneWidget);
    });

    testWidgets('2. Step 1: Validates invalid email input', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ForgotPasswordScreen(),
        ),
      );

      // Cliquer sur le bouton sans email
      await tester.tap(find.text('RECEVOIR LE CODE OTP'));
      await tester.pumpAndSettle();

      expect(find.text('Veuillez saisir une adresse email valide.'), findsOneWidget);
    });

    testWidgets('3. Deep link / Direct URL: Initializes into Step 2 with email and code', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ForgotPasswordScreen(
            initialEmail: 'amadou@bamakopodcast.ml',
            initialCode: '123456',
          ),
        ),
      );

      // Doit afficher le titre et le label du champ de l'étape 2
      expect(find.text('Nouveau mot de passe'), findsNWidgets(2));
      expect(find.text('amadou@bamakopodcast.ml'), findsOneWidget);
      expect(find.text('Code OTP (6 chiffres)'), findsOneWidget);
      expect(find.text('RÉINITIALISER LE MOT DE PASSE'), findsOneWidget);

      // Doit comporter 3 champs : OTP, mot de passe, confirmation
      expect(find.byType(TextFormField), findsNWidgets(3));
    });

    test('4. appRouter configuration contains /forgot-password and /reset-password', () {
      final routes = appRouter.configuration.routes;

      final hasForgot = routes.any((r) => r.toString().contains('/forgot-password'));
      final hasReset = routes.any((r) => r.toString().contains('/reset-password'));

      expect(hasForgot, isTrue);
      expect(hasReset, isTrue);
    });
  });
}
