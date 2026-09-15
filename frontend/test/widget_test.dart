import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart';
import 'package:frontend/services/latin_ime.dart';

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
  });

  group('Widget Tests', () {
    testWidgets('ConverterScreen loads with input field and convert button', (tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // Check title
      expect(find.text('Кирилл ➜ ᠮᠣᠩᠭᠣᠯ'), findsOneWidget);

      // Check input field
      expect(find.byType(TextField), findsOneWidget);

      // Check convert button
      expect(find.text('Хөрвүүлэх'), findsOneWidget);
    });
  });
}
