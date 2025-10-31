
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
    );
    // Wait for the server to be ready.
    await process.stdout.first;
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
