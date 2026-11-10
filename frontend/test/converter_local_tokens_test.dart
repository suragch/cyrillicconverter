import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/main.dart';
import 'package:frontend/services/local_dictionary_service.dart';
import 'package:frontend/token.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalDictionaryService.instance.clearAll();
  });

  group('ConverterScreen.resolveLocalTokens', () {
    test(
      'resolves unknown token with local entry and flags isLocal: true',
      () async {
        await LocalDictionaryService.instance.initialize();
        await LocalDictionaryService.instance.addOrUpdateWord(
          cyrillic: 'ШинэҮг',
          menksoft: 'ᠰᠢᠨ᠎ᠡ',
          explanation: 'Туршилтын үг',
        );

        final tokens = [
          Token(type: 'unknown', original: 'ШинэҮг'),
          Token(type: 'space', original: ' '),
          Token(type: 'unknown', original: 'ҮлТанигдах'),
        ];

        final purgeList = <String>[];
        final resolved = ConverterScreen.resolveLocalTokens(
          tokens: tokens,
          localService: LocalDictionaryService.instance,
          outRecognizedToPurge: purgeList,
        );

        expect(resolved.length, 3);
        expect(resolved[0].type, 'word');
        expect(resolved[0].isLocal, isTrue);
        expect(resolved[0].options.length, 1);
        expect(resolved[0].options.first.menksoft, 'ᠰᠢᠨ᠎ᠡ');
        expect(resolved[0].options.first.explanation, 'Туршилтын үг');

        expect(resolved[1].type, 'space');
        expect(resolved[1].isLocal, isFalse);

        expect(resolved[2].type, 'unknown');
        expect(resolved[2].isLocal, isFalse);

        expect(purgeList, isEmpty);
      },
    );

    test(
      'local override for known word prepends local option as default and does not purge without pair-match',
      () async {
        await LocalDictionaryService.instance.initialize();
        // User added a local variant/correction 'ном'
        await LocalDictionaryService.instance.addOrUpdateWord(
          cyrillic: 'ном',
          menksoft: 'ᠬᠠᠭᠤᠴᠢᠨ_ᠨᠣᠮ',
        );

        // Backend returns official word definition with different spelling
        final tokens = [
          Token(
            type: 'word',
            original: 'ном',
            options: [
              TokenOption(
                menksoft: 'ᠨᠣᠮ',
                isDefault: true,
                explanation: 'Албан ёсны толь',
              ),
            ],
          ),
        ];

        final purgeList = <String>[];
        final resolved = ConverterScreen.resolveLocalTokens(
          tokens: tokens,
          localService: LocalDictionaryService.instance,
          outRecognizedToPurge: purgeList,
        );

        expect(resolved.length, 1);
        expect(resolved[0].type, 'word');
        expect(resolved[0].isLocal, isTrue);
        expect(resolved[0].options.length, 2);
        expect(resolved[0].options[0].menksoft, 'ᠬᠠᠭᠤᠴᠢᠨ_ᠨᠣᠮ');
        expect(resolved[0].options[0].isDefault, isTrue);
        expect(resolved[0].options[1].menksoft, 'ᠨᠣᠮ');
        expect(resolved[0].options[1].isDefault, isFalse);

        // Not purged yet because backend does not match local menksoft
        expect(purgeList, isEmpty);
      },
    );

    test(
      'local entry is purged when backend returns matching (cyrillic, menksoft) pair',
      () async {
        await LocalDictionaryService.instance.initialize();
        await LocalDictionaryService.instance.addOrUpdateWord(
          cyrillic: 'ном',
          menksoft: 'ᠨᠣᠮ',
        );

        final tokens = [
          Token(
            type: 'word',
            original: 'ном',
            options: [
              TokenOption(
                menksoft: 'ᠨᠣᠮ',
                isDefault: true,
                explanation: 'Албан ёсны толь',
              ),
            ],
          ),
        ];

        final purgeList = <String>[];
        final resolved = ConverterScreen.resolveLocalTokens(
          tokens: tokens,
          localService: LocalDictionaryService.instance,
          outRecognizedToPurge: purgeList,
        );

        expect(resolved.length, 1);
        expect(resolved[0].type, 'word');
        expect(resolved[0].isLocal, isFalse);
        expect(resolved[0].options.length, 1);
        expect(resolved[0].options.first.menksoft, 'ᠨᠣᠮ');

        // Pair-match -> queued for purge
        expect(purgeList, ['ном']);
      },
    );

    test('local entry older than 30 days is purged automatically', () async {
      await LocalDictionaryService.instance.initialize();
      // Add entry with createdAt 31 days ago
      final oldDate = DateTime.now().subtract(const Duration(days: 31));
      await LocalDictionaryService.instance.addOrUpdateWord(
        cyrillic: 'хуучин',
        menksoft: 'ᠬᠠᠭᠤᠴᠢᠨ',
        createdAt: oldDate,
      );

      final tokens = [
        Token(
          type: 'word',
          original: 'хуучин',
          options: [
            TokenOption(
              menksoft: 'ᠡᠪᠦᠷ',
              isDefault: true,
              explanation: 'Серверийн өөр бичлэг',
            ),
          ],
        ),
      ];

      final purgeList = <String>[];
      final resolved = ConverterScreen.resolveLocalTokens(
        tokens: tokens,
        localService: LocalDictionaryService.instance,
        outRecognizedToPurge: purgeList,
      );

      expect(resolved.length, 1);
      expect(resolved[0].isLocal, isFalse);
      expect(purgeList, ['хуучин']);
    });
  });
}
