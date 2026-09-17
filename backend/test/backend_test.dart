import 'package:backend/database.dart';
import 'package:backend/tokenizer.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

void main() {
  group('Tokenizer Tests', () {
    test('Tokenizes Cyrillic words, whitespace, and punctuation cleanly', () {
      final input = 'Сайн байна уу? "Монгол" улс, 2026 онд.';
      final tokens = Tokenizer.tokenize(input);

      expect(tokens.isNotEmpty, true);
      // Word tokens
      final words = tokens.where((t) => t.type == TokenType.word).map((t) => t.text).toList();
      expect(words, containsAll(['Сайн', 'байна', 'уу', 'Монгол', 'улс', 'онд']));

      // Punctuation delimiters
      final delimiters = tokens.where((t) => t.type == TokenType.delimiter).map((t) => t.text).toList();
      expect(delimiters, containsAll(['?', '"', ',', '2026', '.']));

      // Reconstructed text must match input exactly
      final reconstructed = tokens.map((t) => t.text).join();
      expect(reconstructed, equals(input));
    });

    test('Preserves multiple newlines and spaces', () {
      final input = 'Мөр нэг.\n\nМөр хоёр!\tТөгсгөл.';
      final tokens = Tokenizer.tokenize(input);
      final reconstructed = tokens.map((t) => t.text).join();
      expect(reconstructed, equals(input));
    });
  });

  group('Database Tests', () {
    late Database rawDb;
    late AppDatabase appDb;

    setUp(() {
      rawDb = sqlite3.openInMemory();
      appDb = AppDatabase(rawDb);
      appDb.initSchema();
    });

    tearDown(() {
      appDb.close();
    });

    test('Add word and lookup definition', () {
      appDb.addWordDefinition(
        cyrillic: 'ном',
        menksoft: '\uE263\uE280',
        explanation: 'book',
        isPrimary: true,
      );

      final options = appDb.lookupWord('НОМ'); // case-insensitive
      expect(options.length, 1);
      expect(options.first['menksoft'], '\uE263\uE280');
      expect(options.first['isDefault'], true);
    });

    test('Homonyms / Ambiguity (1:N definitions)', () {
      appDb.addWordDefinition(
        cyrillic: 'банк',
        menksoft: 'menksoft_financial',
        explanation: 'financial',
        isPrimary: true,
      );
      appDb.addWordDefinition(
        cyrillic: 'банк',
        menksoft: 'menksoft_river',
        explanation: 'river edge',
        isPrimary: false,
      );

      final options = appDb.lookupWord('банк');
      expect(options.length, 2);
      expect(options[0]['menksoft'], 'menksoft_financial');
      expect(options[0]['isDefault'], true);
      expect(options[1]['menksoft'], 'menksoft_river');
      expect(options[1]['isDefault'], false);
    });

    test('Unknown word logging and frequency increment', () {
      appDb.logUnknownWord('шинэүг', context: 'Энэ бол шинэүг мөн.');
      var topUnknown = appDb.getTopUnknownWords();
      expect(topUnknown.length, 1);
      expect(topUnknown.first['cyrillic'], 'шинэүг');
      expect(topUnknown.first['frequency'], 1);

      // Increment
      appDb.logUnknownWord('ШинэҮг', context: 'Өөр нэг шинэүг жишээ.');
      topUnknown = appDb.getTopUnknownWords();
      expect(topUnknown.length, 1);
      expect(topUnknown.first['frequency'], 2);
    });

    test('User suggestions and moderator approval', () {
      appDb.addSuggestion(
        cyrillic: 'туршилт',
        menksoft: 'menk_test',
        context: 'туршилт хийв',
        submittedBy: 'tester',
      );

      final pending = appDb.getPendingSuggestions();
      expect(pending.length, 1);
      expect(pending.first['cyrillic'], 'туршилт');

      // Approve suggestion
      final sugId = pending.first['id'] as int;
      appDb.approveSuggestion(sugId, verifiedBy: 'moderator_user');

      // Suggestion should no longer be pending
      expect(appDb.getPendingSuggestions().isEmpty, true);

      // Word should now exist in dictionary
      final options = appDb.lookupWord('туршилт');
      expect(options.isNotEmpty, true);
      expect(options.first['menksoft'], 'menk_test');
    });
  });
}
