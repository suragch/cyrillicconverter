import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart';
import 'package:test/test.dart';
import '../lib/database.dart';

void main() {
  final port = '8089';
  final host = 'http://127.0.0.1:$port';
  final testDbPath = 'test_server_dictionary.db';
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
    final tokens = json['tokens'] as List<dynamic>;

    // Expect: "Сайн" (word), " " (space), "байна" (word), " " (space), "уу" (word), "?" (delimiter)
    expect(tokens.length, 6);
    expect(tokens[0]['type'], 'word');
    expect(tokens[0]['original'], 'Сайн');
    expect((tokens[0]['options'] as List).isNotEmpty, true);

    expect(tokens[1]['type'], 'space');
    expect(tokens[2]['type'], 'word');
    expect(tokens[2]['original'], 'байна');

    expect(tokens[5]['type'], 'delimiter');
    expect(tokens[5]['original'], '?');
  });

  test('Convert unknown word logs it and returns unknown type', () async {
    final unknownWord = 'үлшинэүгтуршилт';
    final response = await post(
      Uri.parse('$host/convert'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'text': unknownWord}),
    );

    expect(response.statusCode, 200);
    final json = jsonDecode(response.body);
    final tokens = json['tokens'] as List<dynamic>;

    expect(tokens.length, 1);
    expect(tokens[0]['type'], 'unknown');
    expect(tokens[0]['original'], unknownWord);
  });

  test('User suggestion endpoint /contribute', () async {
    final response = await post(
      Uri.parse('$host/contribute'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'cyrillic': 'тест_үг',
        'menksoft': 'test_menksoft',
        'context': 'жишээ өгүүлбэр',
      }),
    );

    expect(response.statusCode, 200);
    final json = jsonDecode(response.body);
    expect(json['success'], true);
  });

  test('CSV export endpoint', () async {
    final response = await get(Uri.parse('$host/export/csv'));
    expect(response.statusCode, 200);
    expect(response.headers['content-type'], contains('text/csv'));
    expect(response.body, contains('cyrillic,menksoft,explanation,is_primary'));
    expect(response.body, contains('сайн'));
  });

  test('Word existence check endpoint /admin/words/check', () async {
    final resKnown = await get(Uri.parse('$host/admin/words/check?cyrillic=сайн'));
    expect(resKnown.statusCode, 200);
    final jsonKnown = jsonDecode(resKnown.body);
    expect(jsonKnown['exists'], true);
    expect((jsonKnown['definitions'] as List).isNotEmpty, true);

    final resUnknown = await get(Uri.parse('$host/admin/words/check?cyrillic=үл_байгаа_үг'));
    expect(resUnknown.statusCode, 200);
    final jsonUnknown = jsonDecode(resUnknown.body);
    expect(jsonUnknown['exists'], false);
    expect((jsonUnknown['definitions'] as List).isEmpty, true);
  });
}
