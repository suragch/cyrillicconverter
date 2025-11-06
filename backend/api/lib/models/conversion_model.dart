// backend/api/lib/models/conversion_model.dart
class Contribution {
  final String cyrillicWord;
  final String menksoft;
  final String? context;

  Contribution({
    required this.cyrillicWord,
    required this.menksoft,
    this.context,
  });

  factory Contribution.fromJson(Map<String, dynamic> json) {
    if (json['cyrillic_word'] == null || json['menksoft'] == null) {
      throw FormatException('Missing required fields: cyrillic_word, menksoft');
    }
    return Contribution(
      cyrillicWord: json['cyrillic_word'] as String,
      menksoft: json['menksoft'] as String,
      context: json['context'] as String?,
    );
  }
}
