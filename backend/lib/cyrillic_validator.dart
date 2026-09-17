class CyrillicValidator {
  // Matches pure Cyrillic text, optionally with hyphens, apostrophes, or underscores between letters
  static final RegExp _cyrillicWordRegex = RegExp(
    r"^[а-яёөүА-ЯЁӨҮ]+(?:[-'_][а-яёөүА-ЯЁӨҮ]+)*$",
    caseSensitive: false,
  );

  /// Returns true if [text] is composed strictly of Cyrillic characters.
  /// Allows single letters (e.g. 'в', 'г', 'а') and consonant strings (e.g. 'УИХ', 'ХХК').
  /// Strictly rejects Latin characters, digits, URLs, and non-Cyrillic symbols.
  static bool isCyrillicWord(String? text) {
    if (text == null) return false;
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;
    return _cyrillicWordRegex.hasMatch(trimmed);
  }
}
