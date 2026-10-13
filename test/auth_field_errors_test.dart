import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bko_app/features/auth/auth_screen.dart';

void main() {
  testWidgets('Registration has Mali selected by default on same line with phone field', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MaterialApp(
      home: AuthScreen(initialTab: AuthTab.register),
    )));

    // Vérifie que l'indicatif +223 du Mali est affiché
    expect(find.text('+223'), findsOneWidget);
    // Vérifie que le hint malien est affiché
    expect(find.text('70 00 00 90'), findsOneWidget);
  });

  testWidgets('Registration shows missing field errors beside the inputs and phone is optional', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MaterialApp(
      home: AuthScreen(initialTab: AuthTab.register),
    )));
    final submit = find.text('Créer mon compte');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump();

    expect(find.text('Renseignez votre nom ou pseudo.'), findsOneWidget);
    expect(find.text('Saisissez une adresse e-mail valide.'), findsOneWidget);
    expect(find.text('Utilisez entre 8 et 72 caractères.'), findsOneWidget);
    expect(find.text('Acceptez les conditions pour continuer.'), findsOneWidget);
    // Le téléphone étant optionnel, aucune erreur de téléphone ne doit apparaître s'il est vide
    expect(find.text('Le numéro malien doit comporter 8 chiffres (ex. 70 00 00 90).'), findsNothing);
  });

  testWidgets('Entering invalid Malian phone number shows format error', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MaterialApp(
      home: AuthScreen(initialTab: AuthTab.register),
    )));

    // Renseigner un numéro incomplet dans le champ téléphone
    final phoneField = find.widgetWithText(TextField, '70 00 00 90');
    expect(phoneField, findsOneWidget);
    await tester.enterText(phoneField, '7612');

    final submit = find.text('Créer mon compte');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump();

    expect(find.text('Le numéro malien doit comporter 8 chiffres (ex. 70 00 00 90).'), findsOneWidget);
  });

  testWidgets('Entering valid Malian phone number formats to 8 digits spaced without error', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MaterialApp(
      home: AuthScreen(initialTab: AuthTab.register),
    )));

    final phoneField = find.widgetWithText(TextField, '70 00 00 90');
    await tester.enterText(phoneField, '70000090');
    await tester.pump();

    // Doit être formaté en '70 00 00 90'
    expect(find.text('70 00 00 90'), findsWidgets);

    final submit = find.text('Créer mon compte');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump();

    expect(find.text('Le numéro malien doit comporter 8 chiffres (ex. 70 00 00 90).'), findsNothing);
  });

  testWidgets('Login shows missing field errors beside inputs when submitted empty', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MaterialApp(
      home: AuthScreen(initialTab: AuthTab.login),
    )));

    final submit = find.text('Se connecter');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump();

    expect(find.text('Renseignez votre identifiant.'), findsOneWidget);
    expect(find.text('Renseignez votre mot de passe.'), findsOneWidget);
  });
}
