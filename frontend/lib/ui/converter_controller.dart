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

  MongolConverterController({
    required this.tokenSpansProvider,
  });

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
      if (token.type == 'unknown') {
        children.add(
          TextSpan(
            text: info.text,
            style: (style ?? const TextStyle()).copyWith(
              color: Colors.red.shade700,
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
              color: Colors.black87,
              decoration: TextDecoration.underline,
              decorationColor: Colors.blue.shade700,
              decorationStyle: TextDecorationStyle.dashed,
            ),
          ),
        );
      } else {
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
