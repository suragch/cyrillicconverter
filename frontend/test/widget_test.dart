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
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      expect(find.text('Нэвтрэх'), findsOneWidget);
      expect(find.text('Модератор'), findsNothing);
    });
  });
}
