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
      'backend word definitions take strict precedence over local entries and queue purge',
      () async {
        await LocalDictionaryService.instance.initialize();
        // User previously added 'ном' locally
        await LocalDictionaryService.instance.addOrUpdateWord(
          cyrillic: 'ном',
          menksoft: 'ᠬᠠᠭᠤᠴᠢᠨ_ᠨᠣᠮ',
        );

        // Backend returns official word definition
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
        expect(resolved[0].options.first.menksoft, 'ᠨᠣᠮ');
        expect(resolved[0].options.first.explanation, 'Албан ёсны толь');

        // 'ном' was in local storage and recognized by backend -> queued for silent purge
        expect(purgeList, ['ном']);
      },
    );
  });
}
