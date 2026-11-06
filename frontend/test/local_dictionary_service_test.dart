import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/models/local_word_entry.dart';
import 'package:frontend/services/local_dictionary_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalDictionaryService.instance.clearAll();
  });

  group('LocalWordEntry Model', () {
    test('toJson and fromJson serialize and deserialize correctly', () {
      final now = DateTime(2026, 11, 6, 12, 0, 0);
      final entry = LocalWordEntry(
        cyrillic: 'номын',
        menksoft: 'ᠨᠣᠮ ᠤᠨ',
        explanation: 'Номын тайлбар',
        createdAt: now,
      );

      final json = entry.toJson();
      expect(json['cyrillic'], 'номын');
      expect(json['menksoft'], 'ᠨᠣᠮ ᠤᠨ');
      expect(json['explanation'], 'Номын тайлбар');
      expect(json['createdAt'], now.toIso8601String());

      final restored = LocalWordEntry.fromJson(json);
      expect(restored, entry);
      expect(restored.hashCode, entry.hashCode);
    });

    test('fromJson handles null and missing fields gracefully', () {
      final entry = LocalWordEntry.fromJson({});
      expect(entry.cyrillic, '');
      expect(entry.menksoft, '');
      expect(entry.explanation, isNull);
      expect(entry.createdAt, isNotNull);
    });
  });

  group('LocalDictionaryService', () {
    test('initializes empty when no preferences exist', () async {
      await LocalDictionaryService.instance.initialize();
      expect(LocalDictionaryService.instance.allWords, isEmpty);
      expect(LocalDictionaryService.instance.count, 0);
    });

    test('initializes pre-stored entries from SharedPreferences', () async {
      final entry = LocalWordEntry(
        cyrillic: 'Сүхбаатар',
        menksoft: 'ᠰᠦᠬᠡᠪᠠᠭᠠᠲᠤᠷ',
        explanation: 'Хот',
        createdAt: DateTime.now(),
      );
      SharedPreferences.setMockInitialValues({
        LocalDictionaryService.storageKey: jsonEncode([entry.toJson()]),
      });

      await LocalDictionaryService.instance.initialize();
      expect(LocalDictionaryService.instance.count, 1);
      expect(LocalDictionaryService.instance.hasWord('сүхбаатар'), isTrue);
      expect(LocalDictionaryService.instance.hasWord('Сүхбаатар'), isTrue);
      expect(
        LocalDictionaryService.instance.getWord('сүхбаатар')?.menksoft,
        'ᠰᠦᠬᠡᠪᠠᠭᠠᠲᠤᠷ',
      );
    });

    test(
      'handles corrupted JSON in SharedPreferences without throwing',
      () async {
        SharedPreferences.setMockInitialValues({
          LocalDictionaryService.storageKey: 'INVALID_JSON_CORRUPTED{{{',
        });

        await LocalDictionaryService.instance.initialize();
        expect(LocalDictionaryService.instance.isInitialized, isTrue);
        expect(LocalDictionaryService.instance.count, 0);
      },
    );

    test(
      'addOrUpdateWord upserts entries and normalizes keys defensively',
      () async {
        await LocalDictionaryService.instance.initialize();
        final success = await LocalDictionaryService.instance.addOrUpdateWord(
          cyrillic: '  Монгол  ',
          menksoft: 'ᠮᠣᠩᠭᠣᠯ',
          explanation: 'Улс',
        );

        expect(success, isTrue);
        expect(LocalDictionaryService.instance.count, 1);
        expect(LocalDictionaryService.instance.hasWord('монгол'), isTrue);
        expect(LocalDictionaryService.instance.hasWord('Монгол'), isTrue);
        expect(
          LocalDictionaryService.instance.getWord('монгол')?.menksoft,
          'ᠮᠣᠩᠭᠣᠯ',
        );

        // Test abbreviation preservation
        await LocalDictionaryService.instance.addOrUpdateWord(
          cyrillic: 'МУИС',
          menksoft: 'ᠮᠤᠢᠰ',
        );
        expect(LocalDictionaryService.instance.hasWord('МУИС'), isTrue);
        expect(
          LocalDictionaryService.instance.getWord('МУИС')?.menksoft,
          'ᠮᠤᠢᠰ',
        );
      },
    );

    test('deleteWord removes target entry and persists', () async {
      await LocalDictionaryService.instance.initialize();
      await LocalDictionaryService.instance.addOrUpdateWord(
        cyrillic: 'ном',
        menksoft: 'ᠨᠣᠮ',
      );
      expect(LocalDictionaryService.instance.hasWord('ном'), isTrue);

      final success = await LocalDictionaryService.instance.deleteWord('Ном');
      expect(success, isTrue);
      expect(LocalDictionaryService.instance.hasWord('ном'), isFalse);
      expect(LocalDictionaryService.instance.count, 0);
    });

    test('purgeWords removes multiple matching entries in batch', () async {
      await LocalDictionaryService.instance.initialize();
      await LocalDictionaryService.instance.addOrUpdateWord(
        cyrillic: 'ном',
        menksoft: 'ᠨᠣᠮ',
      );
      await LocalDictionaryService.instance.addOrUpdateWord(
        cyrillic: 'дэвтэр',
        menksoft: 'ᠳᠡᠪᠲᠡᠷ',
      );
      await LocalDictionaryService.instance.addOrUpdateWord(
        cyrillic: 'үзэг',
        menksoft: 'ᠦᠵᠡᠭ',
      );
      expect(LocalDictionaryService.instance.count, 3);

      final success = await LocalDictionaryService.instance.purgeWords([
        'Ном',
        'Үзэг',
        'байхгүйҮг',
      ]);
      expect(success, isTrue);
      expect(LocalDictionaryService.instance.count, 1);
      expect(LocalDictionaryService.instance.hasWord('дэвтэр'), isTrue);
      expect(LocalDictionaryService.instance.hasWord('ном'), isFalse);
      expect(LocalDictionaryService.instance.hasWord('үзэг'), isFalse);
    });

    test(
      'allWords getter returns entries sorted by createdAt descending',
      () async {
        await LocalDictionaryService.instance.initialize();
        await LocalDictionaryService.instance.addOrUpdateWord(
          cyrillic: 'эхний',
          menksoft: '1',
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await LocalDictionaryService.instance.addOrUpdateWord(
          cyrillic: 'хоёрдахь',
          menksoft: '2',
        );

        final words = LocalDictionaryService.instance.allWords;
        expect(words.length, 2);
        expect(words.first.cyrillic, 'хоёрдахь');
        expect(words.last.cyrillic, 'эхний');
      },
    );
  });
}
