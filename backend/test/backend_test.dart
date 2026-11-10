import 'dart:io';
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

    test('AppDatabase.open configures PRAGMA busy_timeout to 5000ms', () {
      const dbPath = 'test_open_timeout.db';
      final openedDb = AppDatabase.open(dbPath);
      final res = openedDb.db.select('PRAGMA busy_timeout;');
      expect(res.first['timeout'], 5000);
      openedDb.close();
      for (final suffix in ['', '-wal', '-shm']) {
        final f = File('$dbPath$suffix');
        if (f.existsSync()) {
          f.deleteSync();
        }
      }
    });

    test('replaceDefinition updates in place and handles merge', () {
      appDb.addWordDefinition(
        cyrillic: 'ор',
        menksoft: 'menk_bed',
        explanation: 'ор дэр',
        isPrimary: true,
      );
      appDb.addWordDefinition(
        cyrillic: 'ор',
        menksoft: 'menk_enter',
        explanation: 'дотор орох',
        isPrimary: false,
      );

      // 1. Replace menk_bed with menk_bed_fixed in place
      appDb.replaceDefinition(
        cyrillic: 'ор',
        targetMenksoft: 'menk_bed',
        newMenksoft: 'menk_bed_fixed',
        explanation: 'ор дэр зассан',
      );

      var defs = appDb.lookupWord('ор');
      expect(defs.length, 2);
      expect(defs[0]['menksoft'], 'menk_bed_fixed');
      expect(defs[0]['isDefault'], true);
      expect(defs[0]['explanation'], 'ор дэр зассан');
      expect(defs[1]['menksoft'], 'menk_enter');
      expect(defs[1]['isDefault'], false);

      // 2. Replace menk_enter with menk_bed_fixed -> should merge into existing menk_bed_fixed
      appDb.replaceDefinition(
        cyrillic: 'ор',
        targetMenksoft: 'menk_enter',
        newMenksoft: 'menk_bed_fixed',
      );

      defs = appDb.lookupWord('ор');
      expect(defs.length, 1);
      expect(defs.first['menksoft'], 'menk_bed_fixed');
      expect(defs.first['isDefault'], true);
    });

    test('deleteDefinition promotes next definition or deletes word', () {
      appDb.addWordDefinition(
        cyrillic: 'зур',
        menksoft: 'menk_draw',
        isPrimary: true,
      );
      appDb.addWordDefinition(
        cyrillic: 'зур',
        menksoft: 'menk_scratch',
        isPrimary: false,
      );

      // Deleting non-existent definition returns false
      expect(
        appDb.deleteDefinition(cyrillic: 'зур', menksoft: 'nonexistent'),
        false,
      );

      // Deleting primary definition promotes the remaining definition to primary
      final deleted = appDb.deleteDefinition(
        cyrillic: 'зур',
        menksoft: 'menk_draw',
      );
      expect(deleted, true);

      var defs = appDb.lookupWord('зур');
      expect(defs.length, 1);
      expect(defs.first['menksoft'], 'menk_scratch');
      expect(defs.first['isDefault'], true);

      // Deleting the last definition deletes the word from words table
      final deletedLast = appDb.deleteDefinition(
        cyrillic: 'зур',
        menksoft: 'menk_scratch',
      );
      expect(deletedLast, true);
      expect(appDb.lookupWord('зур').isEmpty, true);

      final wordRows = rawDb.select('SELECT * FROM words WHERE cyrillic = ?', [
        'зур',
      ]);
      expect(wordRows.isEmpty, true);
    });

    test('setPrimaryDefinition switches primary definition', () {
      appDb.addWordDefinition(
        cyrillic: 'хэл',
        menksoft: 'menk_tongue',
        isPrimary: true,
      );
      appDb.addWordDefinition(
        cyrillic: 'хэл',
        menksoft: 'menk_speak',
        isPrimary: false,
      );

      expect(
        appDb.setPrimaryDefinition(cyrillic: 'хэл', menksoft: 'nonexistent'),
        false,
      );

      final ok = appDb.setPrimaryDefinition(
        cyrillic: 'хэл',
        menksoft: 'menk_speak',
      );
      expect(ok, true);

      final defs = appDb.lookupWord('хэл');
      expect(defs[0]['menksoft'], 'menk_speak');
      expect(defs[0]['isDefault'], true);
      expect(defs[1]['menksoft'], 'menk_tongue');
      expect(defs[1]['isDefault'], false);
    });

    test(
      'approveSuggestion actions: add_primary, add_secondary, replace, resolve_only',
      () {
        appDb.logUnknownWord('шалгалт', context: 'нууц context 1');
        appDb.logUnknownWord('тексттайлбар', context: 'нууц context 2');

        // 1. add_primary
        appDb.addSuggestion(
          cyrillic: 'шалгалт',
          menksoft: 'menk_exam_1',
          context: 'контекст',
          explanation: 'анхны',
        );
        final sug1 = appDb.getPendingSuggestions().first;
        appDb.approveSuggestion(
          sug1['id'] as int,
          action: 'add_primary',
          verifiedBy: 'mod',
        );

        var defs = appDb.lookupWord('шалгалт');
        expect(defs.length, 1);
        expect(defs.first['menksoft'], 'menk_exam_1');
        expect(defs.first['isDefault'], true);
        // unknown_logs removed
        expect(
          rawDb.select('SELECT * FROM unknown_logs WHERE cyrillic = ?', [
            'шалгалт',
          ]).isEmpty,
          true,
        );

        // 2. add_secondary
        appDb.addSuggestion(
          cyrillic: 'шалгалт',
          menksoft: 'menk_exam_2',
          explanation: 'хоёрдогч',
        );
        final sug2 = appDb.getPendingSuggestions().first;
        appDb.approveSuggestion(
          sug2['id'] as int,
          action: 'add_secondary',
          verifiedBy: 'mod',
        );

        defs = appDb.lookupWord('шалгалт');
        expect(defs.length, 2);
        expect(defs[0]['menksoft'], 'menk_exam_1');
        expect(defs[0]['isDefault'], true);
        expect(defs[1]['menksoft'], 'menk_exam_2');
        expect(defs[1]['isDefault'], false);

        // 3. replace
        appDb.addSuggestion(
          cyrillic: 'шалгалт',
          menksoft: 'menk_exam_fixed',
          targetMenksoft: 'menk_exam_1',
        );
        final sug3 = appDb.getPendingSuggestions().first;
        appDb.approveSuggestion(
          sug3['id'] as int,
          action: 'replace',
          verifiedBy: 'mod',
        );

        defs = appDb.lookupWord('шалгалт');
        expect(defs.length, 2);
        expect(defs[0]['menksoft'], 'menk_exam_fixed');
        expect(defs[0]['isDefault'], true);

        // 4. resolve_only (text-only report)
        appDb.addSuggestion(
          cyrillic: 'тексттайлбар',
          menksoft: '',
          comment: 'алдаатай байна засна уу',
        );
        final sug4 = appDb.getPendingSuggestions().first;
        appDb.approveSuggestion(
          sug4['id'] as int,
          action: 'resolve_only',
          verifiedBy: 'mod',
        );

        // No definition created
        expect(appDb.lookupWord('тексттайлбар').isEmpty, true);
        // unknown_logs retained
        expect(
          rawDb.select('SELECT * FROM unknown_logs WHERE cyrillic = ?', [
            'тексттайлбар',
          ]).isNotEmpty,
          true,
        );

        // Suggestion record updated with context = NULL
        final sug4Row = rawDb.select('SELECT * FROM suggestions WHERE id = ?', [
          sug4['id'],
        ]);
        expect(sug4Row.first['status'], 'approved');
        expect(sug4Row.first['moderator_note'], 'resolve_only');
        expect(sug4Row.first['context'], isNull);
      },
    );

    test('Auto-resolution of matching pending suggestions and discrepancy items', () {
      // 1. Pending suggestion with capitalized Cyrillic
      appDb.addSuggestion(
        cyrillic: 'Монгол',
        menksoft: 'menk_mongol',
        context: 'Монгол улс',
      );

      // 2. Pending suggestion with discrepancy tag
      rawDb.execute('''
        INSERT INTO suggestions (cyrillic, menksoft_code, context, submitted_by, status)
        VALUES ('улс', 'menk_old_spelling', 'контекст', 'db_discrepancy_review', 'pending');
      ''');

      expect(appDb.getPendingSuggestions().length, 2);

      // Adding definition for 'монгол' with 'menk_mongol' auto-resolves 'Монгол'
      appDb.addWordDefinition(cyrillic: 'монгол', menksoft: 'menk_mongol');

      // Adding definition for 'улс' auto-resolves the db_discrepancy_review item
      appDb.addWordDefinition(cyrillic: 'улс', menksoft: 'menk_new_spelling');

      // Both suggestions should now be auto-resolved
      expect(appDb.getPendingSuggestions().isEmpty, true);

      final resolvedRows = rawDb.select(
        "SELECT cyrillic, moderator_note, context FROM suggestions WHERE status = 'approved'",
      );
      expect(resolvedRows.length, 2);
      for (final r in resolvedRows) {
        expect(r['moderator_note'], 'auto_resolved');
        expect(r['context'], isNull);
      }
    });

    test('getPendingSuggestions 4-tier priority queue ordering and count', () {
      // Tier 3: bulk eck_import
      appDb.addSuggestion(
        cyrillic: 'үг4',
        menksoft: 'menk4',
        submittedBy: 'eck_import',
      );
      // Tier 2: other user suggestion
      appDb.addSuggestion(
        cyrillic: 'үг3',
        menksoft: 'menk3',
        submittedBy: 'user1',
      );
      // Tier 1: user suggestion with comment or target_menksoft
      appDb.addSuggestion(
        cyrillic: 'үг2',
        menksoft: 'menk2',
        comment: 'note to mod',
        submittedBy: 'user2',
      );
      // Tier 0: db_discrepancy_review
      rawDb.execute('''
        INSERT INTO suggestions (cyrillic, menksoft_code, submitted_by, status)
        VALUES ('үг1', 'menk1', 'db_discrepancy_review', 'pending');
      ''');

      expect(appDb.getPendingSuggestionsCount(), 4);

      final pending = appDb.getPendingSuggestions();
      expect(pending.length, 4);
      expect(pending[0]['cyrillic'], 'үг1'); // Tier 0
      expect(pending[1]['cyrillic'], 'үг2'); // Tier 1
      expect(pending[2]['cyrillic'], 'үг3'); // Tier 2
      expect(pending[3]['cyrillic'], 'үг4'); // Tier 3
    });
  });
}
