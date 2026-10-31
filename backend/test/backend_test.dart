import 'package:backend/cyrillic_validator.dart';
import 'package:backend/database.dart';
import 'package:backend/tokenizer.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

void main() {
  group('CyrillicValidator Tests', () {
    test('Identifies abbreviations and suffixed abbreviations', () {
      expect(CyrillicValidator.isAbbreviation('МУИС'), true);
      expect(CyrillicValidator.isAbbreviation('УИХ'), true);
      expect(CyrillicValidator.isAbbreviation('АН'), true);
      expect(CyrillicValidator.isAbbreviation('УИХ-ын'), true);
      expect(CyrillicValidator.isAbbreviation('МУИС-д'), true);
      expect(CyrillicValidator.isAbbreviation('АНУ-аас'), true);

      expect(CyrillicValidator.isAbbreviation('Монгол'), false);
      expect(CyrillicValidator.isAbbreviation('ном'), false);
      expect(CyrillicValidator.isAbbreviation('Баян-Өлгий'), false);
      expect(CyrillicValidator.isAbbreviation('Энэ'), false);
      expect(CyrillicValidator.isAbbreviation(''), false);
    });

    test(
      'Normalizes regular words to lowercase and preserves abbreviation casing',
      () {
        expect(CyrillicValidator.normalizeWord('МУИС'), 'МУИС');
        expect(CyrillicValidator.normalizeWord('УИХ-ын'), 'УИХ-ын');
        expect(CyrillicValidator.normalizeWord('Монгол'), 'монгол');
        expect(
          CyrillicValidator.normalizeWord('НОМ'),
          'НОМ',
        ); // 3-letter all-caps is treated as abbreviation unless fallback
        expect(CyrillicValidator.normalizeWord('Ном'), 'ном');
      },
    );
  });
  group('Tokenizer Tests', () {
    test('Tokenizes Cyrillic words, whitespace, and punctuation cleanly', () {
      final input = 'Сайн байна уу? "Монгол" улс, 2026 онд.';
      final tokens = Tokenizer.tokenize(input);

      expect(tokens.isNotEmpty, true);
      // Word tokens
      final words = tokens
          .where((t) => t.type == TokenType.word)
          .map((t) => t.text)
          .toList();
      expect(
        words,
        containsAll(['Сайн', 'байна', 'уу', 'Монгол', 'улс', 'онд']),
      );

      // Punctuation delimiters
      final delimiters = tokens
          .where((t) => t.type == TokenType.delimiter)
          .map((t) => t.text)
          .toList();
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
        explanation: 'тестийн тайлбар',
        submittedBy: 'tester',
      );

      final pending = appDb.getPendingSuggestions();
      expect(pending.length, 1);
      expect(pending.first['cyrillic'], 'туршилт');
      expect(pending.first['context'], 'туршилт хийв');
      expect(pending.first['explanation'], 'тестийн тайлбар');

      // Approve suggestion
      final sugId = pending.first['id'] as int;
      appDb.approveSuggestion(sugId, verifiedBy: 'moderator_user');

      // Suggestion should no longer be pending
      expect(appDb.getPendingSuggestions().isEmpty, true);

      // Word should now exist in dictionary with explanation only (never context)
      final options = appDb.lookupWord('туршилт');
      expect(options.isNotEmpty, true);
      expect(options.first['menksoft'], 'menk_test');
      expect(options.first['explanation'], 'тестийн тайлбар');

      // Ensure context is cleared from suggestions table after approval
      final updatedSug = rawDb.select(
        'SELECT context, explanation FROM suggestions WHERE id = ?',
        [sugId],
      );
      expect(updatedSug.first['context'], isNull);
      expect(updatedSug.first['explanation'], 'тестийн тайлбар');
    });

    test(
      'Rejections do not copy document context into rejected_words.details',
      () {
        // 1. Missing word rejection
        appDb.logUnknownWord('нууцүг', context: 'нууц утас 99112233');
        appDb.rejectMissingWord(
          'нууцүг',
          reason: 'нууц үг биш',
          reviewedBy: 'mod',
        );

        final rejections = rawDb.select(
          'SELECT * FROM rejected_words WHERE cyrillic = ?',
          ['нууцүг'],
        );
        expect(rejections.length, 1);
        expect(rejections.first['reason'], 'нууц үг биш');
        expect(rejections.first['details'], isNull);

        // 2. Suggestion rejection
        appDb.addSuggestion(
          cyrillic: 'нууцсанал',
          menksoft: 'menk_code',
          context: 'нууц бичвэр',
          explanation: 'ямар нэг тайлбар',
          submittedBy: 'user',
        );
        final sugList = appDb.getPendingSuggestions();
        final sugId =
            sugList.firstWhere((s) => s['cyrillic'] == 'нууцсанал')['id']
                as int;
        appDb.rejectSuggestion(sugId, reason: 'хүчингүй', reviewedBy: 'mod');

        final sugRejections = rawDb.select(
          'SELECT * FROM rejected_words WHERE cyrillic = ?',
          ['нууцсанал'],
        );
        expect(
          sugRejections.first['details'],
          'ямар нэг тайлбар',
        ); // stores explanation, not context
        final sugRow = rawDb.select(
          'SELECT context FROM suggestions WHERE id = ?',
          [sugId],
        );
        expect(sugRow.first['context'], isNull); // context cleared
      },
    );

    test('Abbreviations and regular words do not collide', () {
      // Add lowercase 'ан' (hunting / game)
      appDb.addWordDefinition(
        cyrillic: 'ан',
        menksoft: 'menk_hunting',
        explanation: 'hunting / game',
      );

      // Add uppercase abbreviation 'АН' (Democratic Party)
      appDb.addWordDefinition(
        cyrillic: 'АН',
        menksoft: 'menk_party',
        explanation: 'Democratic Party',
      );

      // Lookup 'ан' returns 'menk_hunting'
      final lowerOptions = appDb.lookupWord('ан');
      expect(lowerOptions.length, 1);
      expect(lowerOptions.first['menksoft'], 'menk_hunting');

      // Lookup 'АН' returns 'menk_party'
      final upperOptions = appDb.lookupWord('АН');
      expect(upperOptions.length, 1);
      expect(upperOptions.first['menksoft'], 'menk_party');

      // All-caps emphasis word without abbreviation definition falls back to lowercase
      appDb.addWordDefinition(
        cyrillic: 'анхаар',
        menksoft: 'menk_attention',
        explanation: 'attention',
      );
      final fallbackOptions = appDb.lookupWord('АНХААР');
      expect(fallbackOptions.length, 1);
      expect(fallbackOptions.first['menksoft'], 'menk_attention');
    });

    test(
      'Unknown abbreviation logs in uppercase and normal words in lowercase',
      () {
        appDb.logUnknownWord('МУИС', context: 'МУИС-ийн оюутнууд');
        appDb.logUnknownWord('УИХ-ын', context: 'УИХ-ын гишүүд');
        appDb.logUnknownWord(
          'Нохой',
          context: 'Нохой хуцав',
        ); // TitleCase start of sentence

        final top = appDb.getTopUnknownWords();
        final words = top.map((w) => w['cyrillic']).toList();

        expect(words, containsAll(['МУИС', 'УИХ-ын', 'нохой']));
        expect(words, isNot(contains('Нохой')));
      },
    );
  });
}
