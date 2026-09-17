import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart';
import 'package:frontend/services/latin_ime.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('LatinIme Unit Tests', () {
    test('Transliterates Latin characters into Menksoft codes', () {
      final menksoft = LatinIme.latinToMenksoft('monggol');
      expect(menksoft.isNotEmpty, true);

      // Verify that Menksoft to Unicode works
      final unicode = LatinIme.menksoftToUnicode(menksoft);
      expect(unicode.isNotEmpty, true);
    });

    test('Handles MVS and FVS4 correctly', () {
      final withMvs = LatinIme.latinToMenksoft('nom-a');
      expect(withMvs.isNotEmpty, true);

      final withFvs4 = LatinIme.convertLatinToMongolianUnicode('h4');
      expect(withFvs4.codeUnitAt(1), 0x180F); // Mongol.fvs4
    });

    test('Converts Menksoft back to Latin transliteration', () {
      const latin = 'monggol';
      final menksoft = LatinIme.latinToMenksoft(latin);
      final derivedLatin = LatinIme.menksoftToLatin(menksoft);
      expect(derivedLatin, latin);
    });
  });

  group('Widget Tests', () {
    testWidgets('ConverterScreen loads with input field and convert button', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1280, 800);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // Check title
      expect(find.text('Кирилл ➜ ᠮᠣᠩᠭᠣᠯ'), findsOneWidget);

      // Check input field
      expect(find.byType(TextField), findsOneWidget);

      // Check convert button
      expect(find.text('Хөрвүүлэх'), findsOneWidget);
    });

    testWidgets('Guest user sees Login button without persistent token', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1280, 800);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      expect(find.text('Нэвтрэх'), findsOneWidget);
      expect(find.text('Модератор'), findsNothing);
    });

    testWidgets('Font zoom controls adjust font size', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1280, 800);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // Initial font size 26pt
      expect(find.text('26pt'), findsOneWidget);

      // Tap A+
      await tester.tap(find.text('A+'));
      await tester.pumpAndSettle();

      expect(find.text('28pt'), findsOneWidget);

      // Tap A- twice
      await tester.tap(find.text('A-'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('A-'));
      await tester.pumpAndSettle();

      expect(find.text('24pt'), findsOneWidget);
    });

    testWidgets('Navigating to Dictionary tab opens dictionary search view', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1280, 800);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // Tap dictionary tab
      await tester.tap(find.text('Толь бичиг'));
      await tester.pumpAndSettle();

      expect(find.text('Толь бичиг хайх & шалгах'), findsOneWidget);
      expect(find.text('Хайх'), findsOneWidget);
    });

    testWidgets('Shortcuts help button opens keyboard cheatsheet modal', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1280, 800);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // Tap help button
      await tester.tap(find.byIcon(Icons.help_outline));
      await tester.pumpAndSettle();

      expect(find.text('Товчлуурын хослолууд (Keyboard Shortcuts)'), findsOneWidget);
      expect(find.text('⌘ / Ctrl + Enter'), findsOneWidget);
      expect(find.text('Хаах'), findsOneWidget);

      // Close modal
      await tester.tap(find.text('Хаах'));
      await tester.pumpAndSettle();

      expect(find.text('Товчлуурын хослолууд (Keyboard Shortcuts)'), findsNothing);
    });

    testWidgets('Clicking Login button opens desktop login dialog', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1280, 800);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Нэвтрэх'));
      await tester.pumpAndSettle();

      expect(find.text('Системд нэвтрэх'), findsOneWidget);
      expect(find.text('Имэйл / Нэвтрэх нэр'), findsOneWidget);
      expect(find.text('Нууц үг'), findsOneWidget);

      // Cancel
      await tester.tap(find.text('Цуцлах'));
      await tester.pumpAndSettle();

      expect(find.text('Системд нэвтрэх'), findsNothing);
    });
  });
}
