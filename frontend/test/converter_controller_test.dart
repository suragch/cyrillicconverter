import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/token.dart';
import 'package:frontend/ui/converter_controller.dart';

void main() {
  group('MongolConverterController Tests', () {
    testWidgets('Builds custom styled TextSpans for unknown and ambiguous words', (tester) async {
      late BuildContext buildContext;
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (ctx) {
          buildContext = ctx;
          return const SizedBox();
        }),
      ));

      final spans = <TokenSpanInfo>[
        TokenSpanInfo(
          tokenIndex: 0,
          start: 0,
          end: 3,
          token: Token(type: 'word', original: 'хүү', options: [
            TokenOption(menksoft: '\uE2C1', isDefault: true, explanation: 'хүү (үр хүүхэд)'),
            TokenOption(menksoft: '\uE2C2', isDefault: false, explanation: 'хүү (хүүгийн хувь)'),
          ]),
          text: '\uE2C1',
        ),
        TokenSpanInfo(
          tokenIndex: 1,
          start: 3,
          end: 4,
          token: Token(type: 'space', original: ' '),
          text: ' ',
        ),
        TokenSpanInfo(
          tokenIndex: 2,
          start: 4,
          end: 7,
          token: Token(type: 'unknown', original: 'xyz'),
          text: 'xyz',
        ),
        TokenSpanInfo(
          tokenIndex: 3,
          start: 7,
          end: 13,
          token: Token(type: 'word', original: 'Монгол', options: [
            TokenOption(menksoft: 'ᠮᠣᠩᠭᠣᠯ', isDefault: true),
          ]),
          text: 'ᠮᠣᠩᠭᠣᠯ',
        ),
      ];

      final controller = MongolConverterController(tokenSpansProvider: () => spans);

      // 1. Initial unhovered state: no background highlights
      TextSpan textSpan = controller.buildTextSpan(
        context: buildContext,
        style: const TextStyle(fontSize: 26),
        withComposing: false,
      );

      expect(textSpan.children, isNotNull);
      expect(textSpan.children!.length, 4);

      final ambiguousSpan = textSpan.children![0] as TextSpan;
      expect(ambiguousSpan.style?.decoration, TextDecoration.underline);
      expect(ambiguousSpan.style?.decorationStyle, TextDecorationStyle.dashed);
      expect(ambiguousSpan.style?.decorationColor, Colors.blue.shade700);
      expect(ambiguousSpan.style?.backgroundColor, isNull);

      final unknownSpan = textSpan.children![2] as TextSpan;
      expect(unknownSpan.style?.decoration, TextDecoration.underline);
      expect(unknownSpan.style?.decorationStyle, TextDecorationStyle.wavy);
      expect(unknownSpan.style?.decorationColor, Colors.red);
      expect(unknownSpan.style?.color, Colors.red.shade700);
      expect(unknownSpan.style?.backgroundColor, isNull);

      final normalSpan = textSpan.children![3] as TextSpan;
      expect(normalSpan.style?.backgroundColor, isNull);

      // 2. Hover over ambiguous word (index 0)
      controller.setHoveredTokenIndex(0);
      textSpan = controller.buildTextSpan(
        context: buildContext,
        style: const TextStyle(fontSize: 26),
        withComposing: false,
      );

      final hoveredAmbiguous = textSpan.children![0] as TextSpan;
      expect(hoveredAmbiguous.style?.color, Colors.blue.shade900);
      expect(hoveredAmbiguous.style?.backgroundColor, Colors.blue.shade100);

      // 3. Hover over unknown word (index 2)
      controller.setHoveredTokenIndex(2);
      textSpan = controller.buildTextSpan(
        context: buildContext,
        style: const TextStyle(fontSize: 26),
        withComposing: false,
      );

      final hoveredUnknown = textSpan.children![2] as TextSpan;
      expect(hoveredUnknown.style?.color, Colors.red.shade900);
      expect(hoveredUnknown.style?.backgroundColor, Colors.red.shade100);

      // 4. Hover over normal known word (index 3)
      controller.setHoveredTokenIndex(3);
      textSpan = controller.buildTextSpan(
        context: buildContext,
        style: const TextStyle(fontSize: 26),
        withComposing: false,
      );

      final hoveredNormal = textSpan.children![3] as TextSpan;
      expect(hoveredNormal.style?.color, Colors.indigo.shade900);
      expect(hoveredNormal.style?.backgroundColor, Colors.indigo.shade50);

      // 5. Clear hover (null)
      controller.setHoveredTokenIndex(null);
      textSpan = controller.buildTextSpan(
        context: buildContext,
        style: const TextStyle(fontSize: 26),
        withComposing: false,
      );

      for (final span in textSpan.children!) {
        expect((span as TextSpan).style?.backgroundColor, isNull);
      }
    });
  });
}
