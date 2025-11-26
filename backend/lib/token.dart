class Token {
  final String type; // 'word', 'space', 'punctuation', 'unknown'
  final String original; // The Cyrillic text
  final List<String> options; // Traditional translations (Menksoft encoded)

  Token({
    required this.type,
    required this.original,
    required this.options,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'original': original,
      'options': options,
    };
  }

  factory Token.fromJson(Map<String, dynamic> json) {
    return Token(
      type: json['type'] as String,
      original: json['original'] as String,
      options: (json['options'] as List<dynamic>).cast<String>(),
    );
  }
}
