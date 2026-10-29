class CyrillicValidator {
  // Matches pure Cyrillic text, optionally with hyphens, apostrophes, or underscores between letters
  static final RegExp _cyrillicWordRegex = RegExp(
    r"^[а-яёөүА-ЯЁӨҮ]+(?:[-'_][а-яёөүА-ЯЁӨҮ]+)*$",
    caseSensitive: false,
  );

  static final RegExp _standaloneAbbreviationRegex = RegExp(r'^[А-ЯЁӨҮ]{2,}$');
  static final RegExp _suffixedAbbreviationRegex = RegExp(r'^[А-ЯЁӨҮ]{2,}-[а-яёөүА-ЯЁӨҮ]+$');

  /// Returns true if [text] is composed strictly of Cyrillic characters.
  /// Allows single letters (e.g. 'в', 'г', 'а') and consonant strings (e.g. 'УИХ', 'ХХК').
  /// Strictly rejects Latin characters, digits, URLs, and non-Cyrillic symbols.
  static bool isCyrillicWord(String? text) {
    if (text == null) return false;
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;
    return _cyrillicWordRegex.hasMatch(trimmed);
  }

  /// Returns true if [word] is an abbreviation (e.g. 'МУИС', 'УИХ', 'АН', 'УИХ-ын', 'МУИС-д').
  static bool isAbbreviation(String? word) {
    if (word == null) return false;
    final trimmed = word.trim();
    if (trimmed.isEmpty) return false;
    return _standaloneAbbreviationRegex.hasMatch(trimmed) ||
        _suffixedAbbreviationRegex.hasMatch(trimmed);
  }

  /// Normalizes a Cyrillic word: preserves uppercase for abbreviations,
  /// converts regular words to lowercase to avoid duplicate entries.
  static String normalizeWord(String word) {
    final trimmed = word.trim();
    if (isAbbreviation(trimmed)) {
      return trimmed;
    }
    return trimmed.toLowerCase();
  }
}
