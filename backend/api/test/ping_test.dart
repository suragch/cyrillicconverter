
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

void main() {
  late Process process;
  final port = 8080;
  final url = Uri.parse('http://localhost:$port/ping');

  setUp(() async {
    process = await Process.start(
      'dart',
      ['run', 'bin/server.dart'],
      workingDirectory: '/Users/suragch/Dev/Web/cyrillicconverter/backend/api',
      environment: {
        'DB_HOST': 'localhost',
        'DB_PORT': '5432',
        'DB_NAME': 'cyrillic_converter_db',
        'DB_USER': 'converter_user',
        'DB_PASSWORD': 'YourNewStrongPasswordGoesHere', // From .env
      },
    );
    
    // Wait for the server to be ready.
    // We'll read stdout until we see "Server listening"
    final stream = process.stdout.transform(SystemEncoding().decoder);
    await for (final line in stream) {
      if (line.contains('Server listening')) {
        break;
      }
    }
  });

  tearDown(() {
    process.kill();
  });

  test('/ping should return "pong"', () async {
    final response = await http.get(url);
    expect(response.statusCode, 200);
    expect(response.body, 'pong');
  });
}
