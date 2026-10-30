import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart';
import 'package:backend/database.dart';
import 'package:test/test.dart';

void main() {
  final port = '8089';
  final host = 'http://127.0.0.1:$port';
  final testDbPath = 'test_server_dictionary.db';
  const testModToken = 'test-moderator-secret-123';
  final modHeaders = {'Authorization': 'Bearer $testModToken'};
  late Process p;

  setUpAll(() async {
    // 1. Create a clean, isolated temporary test database
    final appDb = AppDatabase.open(testDbPath);
    appDb.initSchema();
    appDb.addWordDefinition(
      cyrillic: 'сайн',
      menksoft: '\uE2AC\uE281\uE2B5',
      isPrimary: true,
      verifiedBy: 'test_seed',
    );
    appDb.addWordDefinition(
      cyrillic: 'байна',
      menksoft: '\uE2A5\uE281\uE2B5\uE281',
      isPrimary: true,
      verifiedBy: 'test_seed',
    );
    appDb.addWordDefinition(
      cyrillic: 'уу',
      menksoft: '\uE28D\uE28D',
      isPrimary: true,
      verifiedBy: 'test_seed',
    );
    appDb.close();

    // 2. Start server pointing strictly to the isolated test database
    p = await Process.start(
      'dart',
      ['run', 'bin/server.dart'],
      environment: {
        'PORT': port,
        'DB_PATH': testDbPath,
        'TEST_MODERATOR_TOKEN': testModToken,
      },
    );
    // Listen for startup output
    final line = await p.stdout.transform(utf8.decoder).transform(const LineSplitter()).first;
    print('Server started: $line');
  });

  tearDownAll(() async {
    p.kill();
    // Wait briefly for process to exit cleanly
    try {
      await p.exitCode.timeout(const Duration(seconds: 2));
    } catch (_) {}

    // Clean up temporary test database files so no test artifacts remain
    for (final suffix in ['', '-shm', '-wal']) {
      final f = File('$testDbPath$suffix');
      if (f.existsSync()) {
        try {
          f.deleteSync();
        } catch (_) {}
      }
    }
  });

  test('Health check', () async {
    final response = await get(Uri.parse('$host/health'));
    expect(response.statusCode, 200);
    final json = jsonDecode(response.body);
    expect(json['status'], 'ok');
  });

  test('Convert known words with punctuation and spaces', () async {
    final response = await post(
      Uri.parse('$host/convert'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'text': 'Сайн байна уу?'}),
    );
    expect(response.statusCode, 200);
    final json = jsonDecode(response.body);
    final tokens = json['tokens'] as List;

    expect(tokens.length, 6);
    expect(tokens[0]['type'], 'word');
    expect(tokens[0]['original'], 'Сайн');
    expect(tokens[0]['options'][0]['menksoft'], '\uE2AC\uE281\uE2B5');

    expect(tokens[1]['type'], 'space');
    expect(tokens[2]['type'], 'word');
    expect(tokens[2]['original'], 'байна');

    expect(tokens[5]['type'], 'delimiter');
    expect(tokens[5]['original'], '?');
    expect(tokens[5]['menksoft'], '\uE251');
  });

  test('Name abbreviation periods are converted to middle dot', () async {
    // 1. Single abbreviation without whitespace: Д.Сүхбаатар -> middle dot \uE243
    var response = await post(
      Uri.parse('$host/convert'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'text': 'Д.Сүхбаатар'}),
    );
    expect(response.statusCode, 200);
    var tokens = jsonDecode(response.body)['tokens'] as List;
    expect(tokens.length, 3);
    expect(tokens[0]['original'], 'Д');
    expect(tokens[1]['type'], 'delimiter');
    expect(tokens[1]['original'], '.');
    expect(tokens[1]['menksoft'], '\uE243'); // Middle dot
    expect(tokens[2]['original'], 'Сүхбаатар');

    // 2. Chained abbreviations without whitespace: Б.Д.Сүхбаатар -> both middle dots
    response = await post(
      Uri.parse('$host/convert'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'text': 'Б.Д.Сүхбаатар'}),
    );
    expect(response.statusCode, 200);
    tokens = jsonDecode(response.body)['tokens'] as List;
    expect(tokens.length, 5);
    expect(tokens[1]['original'], '.');
    expect(tokens[1]['menksoft'], '\uE243');
    expect(tokens[3]['original'], '.');
    expect(tokens[3]['menksoft'], '\uE243');

    // 3. Abbreviation with whitespace: Д. Сүхбаатар -> standard Mongolian full stop \uE237
    response = await post(
      Uri.parse('$host/convert'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'text': 'Д. Сүхбаатар'}),
    );
    expect(response.statusCode, 200);
    tokens = jsonDecode(response.body)['tokens'] as List;
    expect(tokens[1]['original'], '.');
    expect(tokens[1]['menksoft'], '\uE237'); // Full stop

    // 4. Regular sentence ending: Монгол улс. -> standard Mongolian full stop \uE237
    response = await post(
      Uri.parse('$host/convert'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'text': 'Монгол улс.'}),
    );
    expect(response.statusCode, 200);
    tokens = jsonDecode(response.body)['tokens'] as List;
    final dotToken = tokens.firstWhere((t) => t['original'] == '.');
    expect(dotToken['menksoft'], '\uE237');
  });

  test('Convert unknown word logs it and returns unknown type', () async {
    final response = await post(
      Uri.parse('$host/convert'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'text': 'үлтоох'}),
    );
    expect(response.statusCode, 200);
    final json = jsonDecode(response.body);
    final tokens = json['tokens'] as List;
    expect(tokens.first['type'], 'unknown');
    expect(tokens.first['original'], 'үлтоох');
  });

  test('Abbreviations preserve uppercase when converted and checked', () async {
    // 1. Convert text containing unknown abbreviation and sentence-capitalized word
    final response = await post(
      Uri.parse('$host/convert'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'text': 'МУИС бол их сургууль. Бөртэ ирэв.'}),
    );
    expect(response.statusCode, 200);

    // 2. Check /words/check endpoint for abbreviation
    final checkAbbr = await get(Uri.parse('$host/words/check?cyrillic=МУИС'));
    expect(checkAbbr.statusCode, 200);
    final abbrData = jsonDecode(checkAbbr.body);
    expect(abbrData['cyrillic'], 'МУИС'); // Preserves uppercase for abbreviation

    // 3. Check /words/check endpoint for capitalized regular word
    final checkWord = await get(Uri.parse('$host/words/check?cyrillic=Бөртэ'));
    expect(checkWord.statusCode, 200);
    final wordData = jsonDecode(checkWord.body);
    expect(wordData['cyrillic'], 'бөртэ'); // Normalized to lowercase
  });

  test('User suggestion endpoint /contribute', () async {
    final response = await post(
      Uri.parse('$host/contribute'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'cyrillic': 'шинэүг',
        'menksoft': '\uE281\uE282\uE283',
        'context': 'Жишээ өгүүлбэр',
      }),
    );
    expect(response.statusCode, 200);
    final json = jsonDecode(response.body);
    expect(json['success'], true);
  });

  test('CSV export endpoint (Public)', () async {
    final response = await get(Uri.parse('$host/export/csv'));
    expect(response.statusCode, 200);
    expect(response.headers['content-type'], contains('text/csv'));
    expect(response.body, contains('cyrillic,menksoft,explanation,is_primary'));
    expect(response.body, contains('сайн'));
  });

  test('JSON export endpoint (Public)', () async {
    final response = await get(Uri.parse('$host/export/json'));
    expect(response.statusCode, 200);
    expect(response.headers['content-type'], contains('application/json'));
    final list = jsonDecode(response.body) as List;
    expect(list.isNotEmpty, true);
    expect(list.any((item) => item['cyrillic'] == 'сайн'), true);
  });

  test('Public word existence check endpoint /words/check', () async {
    final resKnown = await get(Uri.parse('$host/words/check?cyrillic=сайн'));
    expect(resKnown.statusCode, 200);
    final jsonKnown = jsonDecode(resKnown.body);
    expect(jsonKnown['exists'], true);
    expect((jsonKnown['definitions'] as List).isNotEmpty, true);

    final resUnknown = await get(Uri.parse('$host/words/check?cyrillic=үл_байгаа_үг'));
    expect(resUnknown.statusCode, 200);
    final jsonUnknown = jsonDecode(resUnknown.body);
    expect(jsonUnknown['exists'], false);
    expect((jsonUnknown['definitions'] as List).isEmpty, true);
    expect(jsonUnknown['rejectionHistory'], isA<List>());
  });

  test('Admin endpoints require moderator authorization', () async {
    // Calling /admin/* without token must return 403 Forbidden
    final resWords = await get(Uri.parse('$host/admin/words/check?cyrillic=сайн'));
    expect(resWords.statusCode, 403);

    final resMissing = await get(Uri.parse('$host/admin/missing'));
    expect(resMissing.statusCode, 403);

    final resSug = await get(Uri.parse('$host/admin/suggestions'));
    expect(resSug.statusCode, 403);

    final resDownload = await get(Uri.parse('$host/admin/db/download'));
    expect(resDownload.statusCode, 403);

    final resExportJson = await get(Uri.parse('$host/admin/db/export-json'));
    expect(resExportJson.statusCode, 403);
  });

  test('Moderator can download full database (.db snapshot and JSON dump)', () async {
    // 1. Download SQLite binary snapshot
    final resDb = await get(Uri.parse('$host/admin/db/download'), headers: modHeaders);
    expect(resDb.statusCode, 200);
    expect(resDb.headers['content-type'], contains('application/vnd.sqlite3'));
    expect(resDb.headers['content-disposition'], contains('attachment; filename='));
    expect(resDb.bodyBytes.length > 100, true);
    // SQLite header magic string check
    final headerStr = utf8.decode(resDb.bodyBytes.sublist(0, 16));
    expect(headerStr.startsWith('SQLite format 3'), true);

    // 2. Download full JSON dump
    final resJson = await get(Uri.parse('$host/admin/db/export-json'), headers: modHeaders);
    expect(resJson.statusCode, 200);
    final dump = jsonDecode(resJson.body) as Map<String, dynamic>;
    expect(dump.containsKey('words'), true);
    expect(dump.containsKey('definitions'), true);
    expect(dump.containsKey('unknown_logs'), true);
    expect(dump.containsKey('suggestions'), true);
    expect(dump.containsKey('rejected_words'), true);
  });

  test('Non-Cyrillic words in /convert are not logged to unknown_logs', () async {
    final response = await post(
      Uri.parse('$host/convert'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'text': 'Hello world 12345'}),
    );
    expect(response.statusCode, 200);

    // Verify neither "Hello" nor "world" nor "12345" are in /admin/missing
    final missingRes = await get(Uri.parse('$host/admin/missing?min_frequency=1'), headers: modHeaders);
    expect(missingRes.statusCode, 200);
    final missingJson = jsonDecode(missingRes.body);
    final list = (missingJson['missing'] as List).map((m) => m['cyrillic']).toList();
    expect(list.contains('hello'), false);
    expect(list.contains('world'), false);
    expect(list.contains('12345'), false);
  });

  test('All unknown Cyrillic words in a large text are logged without limits', () async {
    // Submit 5 distinct unknown words in one conversion text
    final text = 'үгнэг үгхоёр үггурав үгдөрөв үгтав';
    final response = await post(
      Uri.parse('$host/convert'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'text': text}),
    );
    expect(response.statusCode, 200);

    final missingRes = await get(Uri.parse('$host/admin/missing?min_frequency=1'), headers: modHeaders);
    final missingJson = jsonDecode(missingRes.body);
    final list = (missingJson['missing'] as List).map((m) => m['cyrillic']).toList();

    expect(list.contains('үгнэг'), true);
    expect(list.contains('үгхоёр'), true);
    expect(list.contains('үггурав'), true);
    expect(list.contains('үгдөрөв'), true);
    expect(list.contains('үгтав'), true);
  });

  test('/admin/missing filters by min_frequency', () async {
    // "давтамжтайүг" converted by two different client sessions
    await post(
      Uri.parse('$host/convert'),
      headers: {'Content-Type': 'application/json', 'X-Session-ID': 'client-session-1'},
      body: jsonEncode({'text': 'давтамжтайүг'}),
    );
    await post(
      Uri.parse('$host/convert'),
      headers: {'Content-Type': 'application/json', 'X-Session-ID': 'client-session-2'},
      body: jsonEncode({'text': 'давтамжтайүг'}),
    );

    // "ганцдавтамжтайүг" converted once
    await post(
      Uri.parse('$host/convert'),
      headers: {'Content-Type': 'application/json', 'X-Session-ID': 'client-session-3'},
      body: jsonEncode({'text': 'ганцдавтамжтайүг'}),
    );

    // Query with min_frequency=2
    final res2 = await get(Uri.parse('$host/admin/missing?min_frequency=2'), headers: modHeaders);
    expect(res2.statusCode, 200);
    final list2 = (jsonDecode(res2.body)['missing'] as List).map((m) => m['cyrillic']).toList();
    expect(list2.contains('давтамжтайүг'), true);
    expect(list2.contains('ганцдавтамжтайүг'), false);

    // Query with min_frequency=1 includes both
    final res1 = await get(Uri.parse('$host/admin/missing?min_frequency=1'), headers: modHeaders);
    expect(res1.statusCode, 200);
    final list1 = (jsonDecode(res1.body)['missing'] as List).map((m) => m['cyrillic']).toList();
    expect(list1.contains('давтамжтайүг'), true);
    expect(list1.contains('ганцдавтамжтайүг'), true);
  });

  test('Unknown word deduplication per request and session window', () async {
    // Repeated unknown word within the SAME document (3 times) only increments frequency by 1
    final res = await post(
      Uri.parse('$host/convert'),
      headers: {'Content-Type': 'application/json', 'X-Session-ID': 'dedup-test-session'},
      body: jsonEncode({'text': 'давтагдсанүг давтагдсанүг давтагдсанүг'}),
    );
    expect(res.statusCode, 200);

    // Repeated convert request from SAME session within 30-min window does NOT increment frequency
    await post(
      Uri.parse('$host/convert'),
      headers: {'Content-Type': 'application/json', 'X-Session-ID': 'dedup-test-session'},
      body: jsonEncode({'text': 'давтагдсанүг'}),
    );

    final check = await get(Uri.parse('$host/admin/missing?min_frequency=1'), headers: modHeaders);
    final missingList = (jsonDecode(check.body)['missing'] as List);
    final item = missingList.firstWhere((m) => m['cyrillic'] == 'давтагдсанүг');
    expect(item['frequency'], 1); // Only 1, not 4!
  });

  test('/contribute rejects non-Cyrillic words', () async {
    final response = await post(
      Uri.parse('$host/contribute'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'cyrillic': 'latin_word',
        'menksoft': 'test_menksoft',
        'context': 'example',
      }),
    );
    expect(response.statusCode, 400);
    final json = jsonDecode(response.body);
    expect(json['error'], contains('кирилл'));
  });
}
