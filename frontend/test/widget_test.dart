import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart';
import 'package:frontend/services/latin_ime.dart';
import 'package:frontend/token.dart';
import 'package:frontend/ui/desktop/components/desktop_button.dart';
import 'package:frontend/ui/dialogs/add_edit_word_dialog.dart';
import 'package:mongol/mongol.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('LatinIme Unit Tests', () {
    test('Transliterates Latin characters into Menksoft codes', () {
      final menksoft = LatinIme.latinToMenksoft('monggol');
      expect(menksoft.isNotEmpty, true);

      // Verify that Menksoft to Unicode works
      final unicode = LatinIme.menksoftToUnicode(menksoft);
      expect(unicode.isNotEmpty, true);
    });

    test('Handles MVS and FVS4 correctly', () {
      final withMvs = LatinIme.latinToMenksoft('nom-a');
      expect(withMvs.isNotEmpty, true);

      final withFvs4 = LatinIme.convertLatinToMongolianUnicode('h4');
      expect(withFvs4.codeUnitAt(1), 0x180F); // Mongol.fvs4
    });

    test('Converts Menksoft back to Latin transliteration', () {
      const latin = 'monggol';
      final menksoft = LatinIme.latinToMenksoft(latin);
      final derivedLatin = LatinIme.menksoftToLatin(menksoft);
      expect(derivedLatin, latin);
    });

    test(
      'Detects Mongolian script and converts to Latin with whitespace trimming',
      () {
        // Cyrillic and English should not be detected as Mongolian script
        expect(LatinIme.containsMongolianScript('hello world'), false);
        expect(LatinIme.containsMongolianScript('Сайн байна уу'), false);
        expect(LatinIme.containsMongolianScript('12345'), false);

        // Mongolian Unicode
        const unicodeMongol = 'ᠮᠣᠩᠭᠣᠯ';
        expect(LatinIme.containsMongolianScript(unicodeMongol), true);
        final latinFromUnicode = LatinIme.convertToLatin(
          '   $unicodeMongol   ',
        );
        expect(latinFromUnicode, 'mqNgql');

        // Menksoft PUA
        final menksoft = LatinIme.latinToMenksoft('nom');
        expect(LatinIme.containsMongolianScript(menksoft), true);
        final latinFromMenksoft = LatinIme.convertToLatin('  $menksoft  ');
        expect(latinFromMenksoft, 'nom');

        // NNBS (U+202F) mapped to hyphen (-)
        const withNnbs = 'ᠮᠣᠩᠭᠣᠯ\u202Fᠤᠨ';
        expect(LatinIme.convertToLatin(withNnbs), 'mqNgql-vn');
      },
    );

    test('Identifies abbreviations and normalizes Cyrillic words', () {
      expect(LatinIme.isAbbreviation('МУИС'), true);
      expect(LatinIme.isAbbreviation('УИХ-ын'), true);
      expect(LatinIme.isAbbreviation('Монгол'), false);
      expect(LatinIme.isAbbreviation('ном'), false);

      expect(LatinIme.normalizeCyrillic('МУИС'), 'МУИС');
      expect(LatinIme.normalizeCyrillic('УИХ-ын'), 'УИХ-ын');
      expect(LatinIme.normalizeCyrillic('Монгол'), 'монгол');
      expect(LatinIme.normalizeCyrillic('Ном'), 'ном');
    });
  });

  group('Homonym Selection Reconciliation Tests', () {
    test('Reconciles homonym selections when text is unchanged', () {
      final oldTokens = [
        Token(
          type: 'word',
          original: 'гол',
          options: [
            TokenOption(menksoft: 'gvl_river'),
            TokenOption(menksoft: 'gol_reject'),
          ],
        ),
      ];
      final newTokens = [
        Token(
          type: 'word',
          original: 'гол',
          options: [
            TokenOption(menksoft: 'gvl_river'),
            TokenOption(menksoft: 'gol_reject'),
          ],
        ),
      ];
      final oldSelections = {0: 1}; // Selected option 1 (gol_reject)

      final reconciled = ConverterScreen.reconcileHomonymSelections(
        oldTokens: oldTokens,
        newTokens: newTokens,
        oldSelections: oldSelections,
      );

      expect(reconciled, {0: 1});
    });

    test(
      'Preserves homonym selections when a word is inserted earlier in the text',
      () {
        final oldTokens = [
          Token(
            type: 'word',
            original: 'гол',
            options: [
              TokenOption(menksoft: 'gvl_river'),
              TokenOption(menksoft: 'gol_reject'),
            ],
          ),
        ];
        // User inserted "Энэ " at the start
        final newTokens = [
          Token(
            type: 'word',
            original: 'энэ',
            options: [TokenOption(menksoft: 'ene')],
          ),
          Token(type: 'space', original: ' '),
          Token(
            type: 'word',
            original: 'гол',
            options: [
              TokenOption(menksoft: 'gvl_river'),
              TokenOption(menksoft: 'gol_reject'),
            ],
          ),
        ];
        final oldSelections = {0: 1};

        final reconciled = ConverterScreen.reconcileHomonymSelections(
          oldTokens: oldTokens,
          newTokens: newTokens,
          oldSelections: oldSelections,
        );

        // Token index shifted from 0 to 2, but selection is still option 1
        expect(reconciled, {2: 1});
      },
    );

    test(
      'Preserves homonym selections by menksoft value when option order changes',
      () {
        final oldTokens = [
          Token(
            type: 'word',
            original: 'гол',
            options: [
              TokenOption(menksoft: 'gvl_river'),
              TokenOption(menksoft: 'gol_reject'),
            ],
          ),
        ];
        // Dictionary returned options in different order
        final newTokens = [
          Token(
            type: 'word',
            original: 'гол',
            options: [
              TokenOption(menksoft: 'gol_reject'),
              TokenOption(menksoft: 'gvl_river'),
            ],
          ),
        ];
        final oldSelections = {0: 1}; // User picked 'gol_reject'

        final reconciled = ConverterScreen.reconcileHomonymSelections(
          oldTokens: oldTokens,
          newTokens: newTokens,
          oldSelections: oldSelections,
        );

        // In newTokens, 'gol_reject' is now at index 0
        expect(reconciled, {0: 0});
      },
    );

    test('Disambiguates multiple occurrences of the same word independently', () {
      final oldTokens = [
        Token(
          type: 'word',
          original: 'гол',
          options: [
            TokenOption(menksoft: 'gvl_river'),
            TokenOption(menksoft: 'gol_reject'),
          ],
        ),
        Token(type: 'space', original: ' '),
        Token(
          type: 'word',
          original: 'ба',
          options: [TokenOption(menksoft: 'ba')],
        ),
        Token(type: 'space', original: ' '),
        Token(
          type: 'word',
          original: 'гол',
          options: [
            TokenOption(menksoft: 'gvl_river'),
            TokenOption(menksoft: 'gol_reject'),
          ],
        ),
      ];
      // User selected option 0 for 1st 'гол' and option 1 for 2nd 'гол'
      final oldSelections = {0: 0, 4: 1};

      // Add a word at the beginning
      final newTokens = [
        Token(
          type: 'word',
          original: 'том',
          options: [TokenOption(menksoft: 'tom')],
        ),
        Token(type: 'space', original: ' '),
        ...oldTokens,
      ];

      final reconciled = ConverterScreen.reconcileHomonymSelections(
        oldTokens: oldTokens,
        newTokens: newTokens,
        oldSelections: oldSelections,
      );

      // 1st 'гол' is now at index 2 (option 0), 2nd 'гол' is at index 6 (option 1)
      expect(reconciled, {2: 0, 6: 1});
    });
  });

  group('Widget Tests', () {
    testWidgets('ConverterScreen loads with input field and convert button', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1280, 800);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // Check title
      expect(find.text('Кирилл ➜ ᠮᠣᠩᠭᠣᠯ'), findsOneWidget);

      // Check input field
      expect(find.byType(TextField), findsOneWidget);

      // Check convert button
      expect(find.text('Хөрвүүлэх'), findsOneWidget);

      // Check vertical Mongol text placeholder in empty output area
      expect(find.byType(MongolText), findsOneWidget);
    });

    testWidgets('Guest user sees Login button without persistent token', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1280, 800);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      expect(find.text('Нэвтрэх'), findsOneWidget);
      expect(find.text('Модератор'), findsNothing);
    });

    testWidgets('Font zoom controls adjust font size', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1280, 800);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // Initial font size 26pt
      expect(find.text('26pt'), findsOneWidget);

      // Tap A+
      await tester.tap(find.text('A+'));
      await tester.pumpAndSettle();

      expect(find.text('28pt'), findsOneWidget);

      // Tap A- twice
      await tester.tap(find.text('A-'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('A-'));
      await tester.pumpAndSettle();

      expect(find.text('24pt'), findsOneWidget);
    });

    testWidgets('Navigating to Dictionary tab opens dictionary search view', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1280, 800);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // Tap dictionary tab
      await tester.tap(find.text('Толь бичиг'));
      await tester.pumpAndSettle();

      expect(find.text('Толь бичиг хайх & шалгах'), findsOneWidget);
      expect(find.text('Хайх'), findsOneWidget);
    });

    testWidgets('Shortcuts help button opens keyboard cheatsheet modal', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1280, 800);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // Tap help button
      await tester.tap(find.byIcon(Icons.help_outline));
      await tester.pumpAndSettle();

      expect(
        find.text('Товчлуурын хослолууд (Keyboard Shortcuts)'),
        findsOneWidget,
      );
      expect(find.text('⌘ / Ctrl + Enter'), findsOneWidget);
      expect(find.text('Хаах'), findsOneWidget);

      // Close modal
      await tester.tap(find.text('Хаах'));
      await tester.pumpAndSettle();

      expect(
        find.text('Товчлуурын хослолууд (Keyboard Shortcuts)'),
        findsNothing,
      );
    });

    testWidgets('Clicking Login button opens desktop login dialog', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1280, 800);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Нэвтрэх'));
      await tester.pumpAndSettle();

      expect(find.text('Системд нэвтрэх'), findsOneWidget);
      expect(find.text('Имэйл / Нэвтрэх нэр'), findsOneWidget);
      expect(find.text('Нууц үг'), findsOneWidget);

      // Cancel
      await tester.tap(find.text('Цуцлах'));
      await tester.pumpAndSettle();

      expect(find.text('Системд нэвтрэх'), findsNothing);
    });

    testWidgets('Header renders public dictionary download button', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1280, 800);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // Download button with download icon must be rendered
      expect(find.byIcon(Icons.download_outlined), findsWidgets);
    });

    testWidgets(
      'AddEditWordDialog hides keyboard by default and toggles on button press',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AddEditWordDialog(
                        title: 'Үл мэдэгдэх үг: "тест"',
                        initialCyrillic: 'тест',
                        onSubmit:
                            ({
                              required cyrillic,
                              required menksoft,
                              explanation,
                            }) async {},
                      ),
                    );
                  },
                  child: const Text('Open Dialog'),
                ),
              ),
            ),
          ),
        );

        // Open the dialog
        await tester.tap(find.text('Open Dialog'));
        await tester.pumpAndSettle();

        // Keyboard should be hidden by default
        expect(find.text('Товчлуур харах'), findsOneWidget);
        expect(find.text('Эгшиг (Vowels)'), findsNothing);

        // Tap show keyboard button
        await tester.tap(find.text('Товчлуур харах'));
        await tester.pumpAndSettle();

        // Keyboard should now be visible
        expect(find.text('Товчлуур нуух'), findsOneWidget);
        expect(find.text('Эгшиг (Vowels)'), findsOneWidget);

        // Tap hide keyboard button
        await tester.tap(find.text('Товчлуур нуух'));
        await tester.pumpAndSettle();

        // Keyboard should be hidden again
        expect(find.text('Товчлуур харах'), findsOneWidget);
        expect(find.text('Эгшиг (Vowels)'), findsNothing);
      },
    );

    testWidgets('Pressing Enter in AddEditWordDialog triggers onSubmit', (
      tester,
    ) async {
      bool submitted = false;
      String? submittedCyrillic;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AddEditWordDialog(
                      title: 'Үг нэмэх',
                      submitButtonText: 'Хадгалах',
                      initialCyrillic: 'ном',
                      initialLatin: 'nom',
                      onSubmit:
                          ({
                            required cyrillic,
                            required menksoft,
                            explanation,
                          }) async {
                            submitted = true;
                            submittedCyrillic = cyrillic;
                          },
                    ),
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      // Open dialog
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Хадгалах'), findsOneWidget);

      // Press Enter key
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(submitted, true);
      expect(submittedCyrillic, 'ном');
    });

    testWidgets(
      'Entering or pasting Mongolian Unicode into Latin field converts to Latin',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AddEditWordDialog(
                        title: 'Үг нэмэх',
                        initialCyrillic: 'монгол',
                        onSubmit:
                            ({
                              required cyrillic,
                              required menksoft,
                              explanation,
                            }) async {},
                      ),
                    );
                  },
                  child: const Text('Open Dialog'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Dialog'));
        await tester.pumpAndSettle();

        final latinField = find.widgetWithText(TextField, 'Латин галиг');
        expect(latinField, findsOneWidget);

        // Verify helper text is displayed
        expect(
          find.text('Энд монгол бичвэр (Юникод) буулгаж болно'),
          findsOneWidget,
        );

        // Verify Paste button is present
        final pasteButton = find.byTooltip('Буулгах');
        expect(pasteButton, findsOneWidget);

        // Mock clipboard getData
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (MethodCall methodCall) async {
            if (methodCall.method == 'Clipboard.getData') {
              return const <String, dynamic>{'text': '   ᠮᠣᠩᠭᠣᠯ   '};
            }
            return null;
          },
        );

        await tester.tap(pasteButton);
        await tester.pumpAndSettle();

        // Should automatically convert to Latin and trim outer whitespace
        final textFieldWidget = tester.widget<TextField>(latinField);
        expect(textFieldWidget.controller?.text, 'mqNgql');
      },
    );

    testWidgets('Convert button state transitions: dirty vs up-to-date', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1280, 800);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      final inputFinder = find.byType(TextField);
      // Initially input is empty -> Convert button is disabled
      final convertBtn = find.widgetWithText(DesktopButton, 'Хөрвүүлэх');
      expect(convertBtn, findsOneWidget);
      final initialButton = tester.widget<DesktopButton>(convertBtn);
      expect(initialButton.onPressed, isNull);

      // Enter text
      await tester.enterText(inputFinder, 'сайн байна уу');
      await tester.pumpAndSettle();

      // Now dirty -> Convert button is enabled with label 'Хөрвүүлэх'
      final enabledButton = tester.widget<DesktopButton>(convertBtn);
      expect(enabledButton.onPressed, isNotNull);
      expect(enabledButton.label, 'Хөрвүүлэх');
    });
  });
}
