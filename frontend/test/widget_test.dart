import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart';
import 'package:frontend/services/latin_ime.dart';
import 'package:frontend/token.dart';
import 'package:frontend/ui/desktop/components/desktop_button.dart';
import 'package:frontend/ui/dialogs/add_edit_word_dialog.dart';
import 'package:frontend/ui/dictionary/dictionary_browse_view.dart';
import 'package:frontend/ui/moderator/moderator_page.dart';
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
      expect(find.text('Шүүгч'), findsNothing);
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

    testWidgets(
      'Main header does not render download button; Dictionary tab renders download button',
      (tester) async {
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(1280, 800);
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        SharedPreferences.setMockInitialValues({});
        await tester.pumpWidget(const MyApp());
        await tester.pumpAndSettle();

        // Main header does not render download icon
        expect(find.byIcon(Icons.download_outlined), findsNothing);

        // Tap dictionary tab
        await tester.tap(find.text('Толь бичиг'));
        await tester.pumpAndSettle();

        // Download button is available in the dictionary view
        expect(find.text('Толь татах (CSV)'), findsOneWidget);
      },
    );

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
        expect(find.byTooltip('Товчлуур харах'), findsOneWidget);
        expect(find.text('Эгшиг (Vowels)'), findsNothing);

        // Verify the keyboard icon is below the text fields on the right side
        final previewFinder = find.byType(MongolText);
        final keyboardButtonFinder = find.byTooltip('Товчлуур харах');
        final explanationFieldFinder = find.widgetWithText(
          TextField,
          'Тайлбар (заавал биш)',
        );
        expect(
          tester.getTopLeft(keyboardButtonFinder).dy,
          greaterThan(tester.getBottomLeft(explanationFieldFinder).dy),
        );
        expect(
          tester.getTopLeft(keyboardButtonFinder).dx,
          greaterThan(tester.getTopLeft(previewFinder).dx),
        );

        // Tap show keyboard button
        await tester.tap(keyboardButtonFinder);
        await tester.pumpAndSettle();

        // Keyboard should now be visible on the right side of the Mongolian preview
        expect(find.byTooltip('Товчлуур нуух'), findsOneWidget);
        expect(find.text('Эгшиг (Vowels)'), findsOneWidget);

        final keyboardFinder = find.text('Эгшиг (Vowels)');
        expect(
          tester.getTopLeft(keyboardFinder).dx,
          greaterThan(tester.getTopLeft(previewFinder).dx),
        );

        // Tap hide keyboard button
        await tester.tap(find.byTooltip('Товчлуур нуух'));
        await tester.pumpAndSettle();

        // Keyboard should be hidden again
        expect(find.byTooltip('Товчлуур харах'), findsOneWidget);
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

    testWidgets(
      'AddEditWordDialog Latin field does not have hint text when selected/focused',
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
                        initialCyrillic: 'ном',
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

        final latinFieldFinder = find.widgetWithText(TextField, 'Латин галиг');
        expect(latinFieldFinder, findsOneWidget);

        // Autofocused, so it has focus and hint text should be null
        TextField latinField = tester.widget<TextField>(latinFieldFinder);
        expect(latinField.decoration?.hintText, isNull);

        // Unfocus
        latinField.focusNode?.unfocus();
        await tester.pumpAndSettle();

        latinField = tester.widget<TextField>(latinFieldFinder);
        expect(
          latinField.decoration?.hintText,
          'q=o, w=wa, v=u, o=oe, u=ue, E=ee',
        );
      },
    );

    testWidgets(
      'DesktopButton inside SelectionArea uses SystemMouseCursors.click and disables selection',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SelectionArea(
                child: DesktopButton(onPressed: () {}, label: 'Тест товч'),
              ),
            ),
          ),
        );

        // Find the MouseRegion within DesktopButton
        final mouseRegionFinder = find.descendant(
          of: find.byType(DesktopButton),
          matching: find.byType(MouseRegion),
        );
        expect(mouseRegionFinder, findsOneWidget);
        final mouseRegion = tester.widget<MouseRegion>(mouseRegionFinder);
        expect(mouseRegion.cursor, SystemMouseCursors.click);

        // SelectionContainer should be disabled around the button
        final selectionContainerFinder = find.descendant(
          of: find.byType(DesktopButton),
          matching: find.byType(SelectionContainer),
        );
        expect(selectionContainerFinder, findsOneWidget);
      },
    );

    testWidgets(
      'AddEditWordDialog supports vertically scrollable long text/abbreviations',
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
                        title: 'Урт товчлол нэмэх',
                        initialCyrillic: 'БНМАУ',
                        initialLatin: 'b.n.m.a.u.',
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

        // Should contain the keyboard button
        expect(find.byTooltip('Товчлуур харах'), findsOneWidget);

        final scrollbarFinder = find.byType(Scrollbar);
        expect(scrollbarFinder, findsOneWidget);

        // Mongol preview should have a vertical SingleChildScrollView inside the Scrollbar
        final verticalScrollFinder = find.descendant(
          of: scrollbarFinder,
          matching: find.byType(SingleChildScrollView),
        );
        expect(verticalScrollFinder, findsOneWidget);
        final scrollWidget = tester.widget<SingleChildScrollView>(
          verticalScrollFinder,
        );
        expect(scrollWidget.scrollDirection, Axis.vertical);

        // MongolText should be rendered inside
        expect(find.byType(MongolText), findsOneWidget);
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

    testWidgets(
      'DictionaryBrowseView renders guest-friendly suggest button and hides moderator controls when not logged in',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: DictionaryBrowseView(
                serverUrl: 'http://localhost:8080',
                authToken: null,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Search toolbar is present
        expect(find.text('Толь бичиг хайх & шалгах'), findsOneWidget);
        expect(find.text('Хайх'), findsOneWidget);

        // Moderator exclusive controls are not shown
        expect(find.text('Шинэ хувилбар нэмэх'), findsNothing);
        expect(find.text('Толь бичигт бүртгэх'), findsNothing);
        expect(find.textContaining('Өмнөх түүх:'), findsNothing);
      },
    );

    testWidgets(
      'ModeratorPage renders streamlined subheader with queue tabs and refresh',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: ModeratorPage(
                serverUrl: 'http://localhost:8080',
                authToken: 'mock-token',
                moderatorId: 'mod@example.com',
              ),
            ),
          ),
        );
        await tester.pump();

        // Queue switcher tabs and refresh button are rendered
        expect(find.text('Хянагдах саналууд'), findsOneWidget);
        expect(find.text('Дутуу үгс'), findsOneWidget);
        expect(find.byIcon(Icons.refresh), findsOneWidget);

        // Obsolete / redundant controls are not rendered
        expect(find.text('Бааз татах (.db)'), findsNothing);
        expect(find.text('Админ нэмэх'), findsNothing);
        expect(find.text('Үг нэмэх'), findsNothing);
        expect(find.textContaining('Товчлуур:'), findsNothing);
        expect(find.byIcon(Icons.cloud_download_outlined), findsNothing);
      },
    );

    testWidgets(
      'Output panel footer hides color legend on empty state and hides explanation text',
      (tester) async {
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(1280, 800);
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        SharedPreferences.setMockInitialValues({});
        await tester.pumpWidget(const MyApp());
        await tester.pumpAndSettle();

        // Footer color dots should NOT be visible when no words are converted
        expect(find.text('Олон утгатай'), findsNothing);
        expect(find.text('Тольд үгүй'), findsNothing);

        // Explanation text should be completely removed
        expect(find.textContaining('Үг дээр товшиж утга сонгох'), findsNothing);

        // Right-aligned font resizer is still present in the footer
        expect(find.text('26pt'), findsOneWidget);
      },
    );

    testWidgets(
      'Split copy button has dropdown menu for Unicode and Menksoft code choices',
      (tester) async {
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(1280, 800);
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        SharedPreferences.setMockInitialValues({});
        await tester.pumpWidget(const MyApp());
        await tester.pumpAndSettle();

        // Main copy label is present
        expect(find.text('Хуулах'), findsOneWidget);
        expect(find.text('⌘C'), findsOneWidget);

        // Down arrow icon is present
        final dropdownArrow = find.byIcon(Icons.arrow_drop_down);
        expect(dropdownArrow, findsOneWidget);

        // Tap dropdown arrow to open popup menu
        await tester.tap(dropdownArrow);
        await tester.pumpAndSettle();

        // Choices are rendered
        expect(find.text('Юникод (Unicode)'), findsOneWidget);
        expect(find.text('Menksoft код'), findsOneWidget);

        // Select Menksoft
        await tester.tap(find.text('Menksoft код'));
        await tester.pumpAndSettle();

        // Re-open menu to confirm selection
        await tester.tap(dropdownArrow);
        await tester.pumpAndSettle();
        expect(find.text('Menksoft код'), findsOneWidget);
      },
    );
  });
}
