enum TokenType {
  word,
  space,
  delimiter,
}

class RawToken {
  final TokenType type;
  final String text;

  const RawToken({required this.type, required this.text});

  @override
  String toString() => 'RawToken($type, "$text")';
}

class Tokenizer {
  static final RegExp _tokenRegex = RegExp(
    r"([а-яёөүА-ЯЁӨҮ]+(?:[-'][а-яёөүА-ЯЁӨҮ]+)*)|(\s+)|([^\sа-яёөүА-ЯЁӨҮ]+)",
    caseSensitive: false,
  );

  /// Tokenizes [input] into a sequential list of [RawToken]s, strictly
  /// preserving all whitespace, newlines, punctuation, and words.
  static List<RawToken> tokenize(String input) {
    if (input.isEmpty) return [];

    final tokens = <RawToken>[];
    final matches = _tokenRegex.allMatches(input);

    for (final m in matches) {
      if (m.group(1) != null) {
        tokens.add(RawToken(type: TokenType.word, text: m.group(1)!));
      } else if (m.group(2) != null) {
        tokens.add(RawToken(type: TokenType.space, text: m.group(2)!));
      } else if (m.group(3) != null) {
        tokens.add(RawToken(type: TokenType.delimiter, text: m.group(3)!));
      }
    }

    return tokens;
  }
}
