import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart';
import 'package:test/test.dart';

void main() {
  final port = '8089';
  final host = 'http://127.0.0.1:$port';
  late Process p;

  setUpAll(() async {
    p = await Process.start(
      'dart',
      ['run', 'bin/server.dart'],
      environment: {
        'PORT': port,
        'DB_PATH': 'dictionary.db',
      },
    );
    // Listen for startup output
    final line = await p.stdout.transform(utf8.decoder).transform(const LineSplitter()).first;
    print('Server started: $line');
  });

  tearDownAll(() => p.kill());

  test('Health check', () async {
    final response = await get(Uri.parse('$host/health'));
    expect(response.statusCode, 200);
    final json = jsonDecode(response.body);
    expect(json['status'], 'ok');
  });

  test('Convert known words with punctuation and spaces', () async {
    // We migrated 'сайн', 'байна', 'уу' from PocketBase
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
}
