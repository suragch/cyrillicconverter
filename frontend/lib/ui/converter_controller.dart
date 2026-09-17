import 'package:flutter/material.dart';
import '../token.dart';

class TokenSpanInfo {
  final int tokenIndex;
  final int start;
  final int end;
  final Token token;
  final String text;

  const TokenSpanInfo({
    required this.tokenIndex,
    required this.start,
    required this.end,
    required this.token,
    required this.text,
  });
}

class MongolConverterController extends TextEditingController {
  final List<TokenSpanInfo> Function() tokenSpansProvider;
  int? hoveredTokenIndex;

  MongolConverterController({
    required this.tokenSpansProvider,
    this.hoveredTokenIndex,
  });

  void setHoveredTokenIndex(int? index) {
    if (hoveredTokenIndex == index) return;
    hoveredTokenIndex = index;
    notifyListeners();
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final spans = tokenSpansProvider();
    if (spans.isEmpty) {
      return TextSpan(text: text, style: style);
    }

    final children = <TextSpan>[];
    for (final info in spans) {
      final token = info.token;
      final isHovered = (info.tokenIndex == hoveredTokenIndex);

      if (token.type == 'unknown') {
        children.add(
          TextSpan(
            text: info.text,
            style: (style ?? const TextStyle()).copyWith(
              color: isHovered ? Colors.red.shade900 : Colors.red.shade700,
              backgroundColor: isHovered ? Colors.red.shade100 : null,
              fontFamily: null, // default Cyrillic fallback
              decoration: TextDecoration.underline,
              decorationColor: Colors.red,
              decorationStyle: TextDecorationStyle.wavy,
            ),
          ),
        );
      } else if (token.type == 'word' && token.options.length > 1) {
        children.add(
          TextSpan(
            text: info.text,
            style: (style ?? const TextStyle()).copyWith(
              fontFamily: 'Menksoft',
              color: isHovered ? Colors.blue.shade900 : Colors.black87,
              backgroundColor: isHovered ? Colors.blue.shade100 : null,
              decoration: TextDecoration.underline,
              decorationColor: Colors.blue.shade700,
              decorationStyle: TextDecorationStyle.dashed,
            ),
          ),
        );
      } else if (token.type == 'word') {
        children.add(
          TextSpan(
            text: info.text,
            style: (style ?? const TextStyle()).copyWith(
              fontFamily: 'Menksoft',
              color: isHovered ? Colors.indigo.shade900 : Colors.black87,
              backgroundColor: isHovered ? Colors.indigo.shade50 : null,
            ),
          ),
        );
      } else {
        // Delimiters and spaces
        children.add(
          TextSpan(
            text: info.text,
            style: (style ?? const TextStyle()).copyWith(
              fontFamily: (token.type == 'space') ? null : 'Menksoft',
              color: Colors.black87,
            ),
          ),
        );
      }
    }

    return TextSpan(children: children, style: style);
  }
}
