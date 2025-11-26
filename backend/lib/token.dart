class Token {
  final String type; // 'word', 'space', 'punctuation', 'unknown'
  final String original; // The Cyrillic text
  final List<TokenOption> options; // Traditional translations

  Token({
    required this.type,
    required this.original,
    required this.options,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'original': original,
      'options': options.map((e) => e.toJson()).toList(),
    };
  }

  factory Token.fromJson(Map<String, dynamic> json) {
    return Token(
      type: json['type'] as String,
      original: json['original'] as String,
      options: (json['options'] as List<dynamic>)
          .map((e) => TokenOption.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class TokenOption {
  final String menksoft;
  final String? explanation;
  final bool isDefault;

  TokenOption({
    required this.menksoft,
    this.explanation,
    this.isDefault = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'menksoft': menksoft,
      'explanation': explanation,
      'isDefault': isDefault,
    };
  }

  factory TokenOption.fromJson(Map<String, dynamic> json) {
    return TokenOption(
      menksoft: json['menksoft'] as String,
      explanation: json['explanation'] as String?,
      isDefault: json['isDefault'] as bool? ?? false,
    );
  }
}
