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
      ];

      final controller = MongolConverterController(tokenSpansProvider: () => spans);
      final textSpan = controller.buildTextSpan(
        context: buildContext,
        style: const TextStyle(fontSize: 26),
        withComposing: false,
      );

      expect(textSpan.children, isNotNull);
      expect(textSpan.children!.length, 3);

      final ambiguousSpan = textSpan.children![0] as TextSpan;
      expect(ambiguousSpan.style?.decoration, TextDecoration.underline);
      expect(ambiguousSpan.style?.decorationStyle, TextDecorationStyle.dashed);
      expect(ambiguousSpan.style?.decorationColor, Colors.blue.shade700);

      final unknownSpan = textSpan.children![2] as TextSpan;
      expect(unknownSpan.style?.decoration, TextDecoration.underline);
      expect(unknownSpan.style?.decorationStyle, TextDecorationStyle.wavy);
      expect(unknownSpan.style?.decorationColor, Colors.red);
      expect(unknownSpan.style?.color, Colors.red.shade700);
    });
  });
}
