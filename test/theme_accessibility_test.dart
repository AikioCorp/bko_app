import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:bko_app/core/theme/bko_theme.dart';
import 'package:bko_app/core/widgets/app_back_button.dart';
import 'package:bko_app/features/auth/auth_modal.dart';
import 'package:bko_app/features/onboarding/onboarding_screen.dart';

double contrast(Color a, Color b) {
  final x = a.computeLuminance(), y = b.computeLuminance();
  return ((x > y ? x : y) + 0.05) / ((x > y ? y : x) + 0.05);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final manifest =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final family in manifest) {
      final loader = FontLoader(family['family'] as String);
      for (final font in family['fonts']) {
        loader.addFont(rootBundle.load(font['asset'] as String));
      }
      await loader.load();
    }
    await GoogleFonts.pendingFonts();
  });
  GoogleFonts.config.allowRuntimeFetching = false;
  final themes = {
    'light': BkoTheme.lightTheme,
    'dark': BkoTheme.darkTheme,
    'amoled': BkoTheme.amoledTheme
  };
  for (final entry in themes.entries) {
    testWidgets('${entry.key}: readable roles, sheets and system controls',
        (tester) async {
      final key = GlobalKey();
      tester.view.resetPhysicalSize();
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      late BuildContext current;
      await tester.pumpWidget(MaterialApp(
          theme: entry.value,
          home: Builder(builder: (context) {
            current = context;
            return RepaintBoundary(
                key: key,
                child: Scaffold(
                    appBar: AppBar(
                        leading: AppBackButton(onPressed: () {}),
                        title: const Text('Bamako Podcast')),
                    body: SingleChildScrollView(
                        child: Column(children: [
                      Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text('Votre bibliothèque',
                              style: TextStyle(
                                  color: BkoTheme.getTextPrimary(context),
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold))),
                      Text('Épisodes et émissions enregistrés',
                          style: TextStyle(
                              color: BkoTheme.getTextSecondary(context))),
                      const AuthRequiredModal(
                          actionTitle: 'Enregistrer cet épisode'),
                    ]))));
          })));
      await tester.runAsync(() => GoogleFonts.pendingFonts());
      await tester.pumpAndSettle();
      final surface = BkoTheme.getBgSurface(current),
          background = BkoTheme.getBgObsidian(current);
      for (final fg in [
        BkoTheme.getTextPrimary(current),
        BkoTheme.getTextSecondary(current),
        BkoTheme.getTextMuted(current),
        BkoTheme.getAccent(current),
        BkoTheme.getError(current),
        BkoTheme.getSuccess(current)
      ]) {
        expect(contrast(fg, surface), greaterThanOrEqualTo(4.5));
        expect(contrast(fg, background), greaterThanOrEqualTo(4.5));
      }
      expect(contrast(BkoTheme.onBrand, BkoTheme.goldAccent),
          greaterThanOrEqualTo(4.5));
      expect(BkoTheme.getBgSurfaceElevated(current),
          entry.value.colorScheme.surfaceContainerHighest);
      expect(
          entry.value.appBarTheme.systemOverlayStyle,
          entry.key == 'light'
              ? SystemUiOverlayStyle.dark
              : SystemUiOverlayStyle.light);
      expect(tester.takeException(), isNull);
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        final dir = Directory('build/theme-audit');
        await dir.create(recursive: true);
        await File('${dir.path}/${entry.key}.png')
            .writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
    });
  }
  testWidgets('onboarding adapts to light theme and enlarged text',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        theme: BkoTheme.lightTheme,
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.6)),
            child: child!),
        home: const OnboardingScreen()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
