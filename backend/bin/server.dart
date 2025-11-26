import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:sqlite3/sqlite3.dart';
import '../lib/token.dart'; // Though we are constructing JSON manually, good to have reference if we switch to using the class directly

// Configure routes.
final _router = Router()
  ..post('/echo', _echoHandler)
  ..post('/convert', _convertHandler);

late final Database _db;

Future<Response> _echoHandler(Request request) async {
  final content = await request.readAsString();
  try {
    final json = jsonDecode(content);
    return Response.ok(
      jsonEncode({'received': json['text']}),
      headers: {'content-type': 'application/json'},
    );
  } catch (e) {
    return Response.badRequest(body: 'Invalid JSON');
  }
}

Future<Response> _convertHandler(Request request) async {
  final content = await request.readAsString();
  try {
    final json = jsonDecode(content);
    final text = json['text'] as String;
    
    // Improved tokenizer: use splitMapJoin to preserve both words and spaces
    final List<String> rawTokens = [];
    text.splitMapJoin(
      RegExp(r'\S+'),  // Match non-whitespace (words)
      onMatch: (m) {
        rawTokens.add(m.group(0)!);
        return '';
      },
      onNonMatch: (nm) {
        if (nm.isNotEmpty) rawTokens.add(nm);
        return '';
      },
    );
    
    final List<Map<String, dynamic>> tokens = [];
    
    final stmtWord = _db.prepare('SELECT id FROM words WHERE cyrillic = ?');
    final stmtDef = _db.prepare('SELECT menksoft_code, explanation, is_primary FROM definitions WHERE word_id = ?');

    for (final raw in rawTokens) {
      // Check if this token is whitespace
      if (raw.trim().isEmpty) {
        tokens.add({
          'type': 'space',
          'original': raw,  // Preserve the actual whitespace
          'options': []
        });
        continue;
      }

      final wordResult = stmtWord.select([raw]);
      if (wordResult.isNotEmpty) {
        final wordId = wordResult.first['id'];
        final defResult = stmtDef.select([wordId]);
        
        final options = defResult.map((row) => {
          'menksoft': row['menksoft_code'] as String,
          'explanation': row['explanation'] as String?,
          'isDefault': (row['is_primary'] as int) == 1,
        }).toList();
        
        tokens.add({
          'type': 'word',
          'original': raw,
          'options': options
        });
      } else {
        // Log unknown word
        _db.execute('INSERT OR IGNORE INTO unknown_logs (cyrillic) VALUES (?)', [raw]);
        _db.execute('UPDATE unknown_logs SET frequency = frequency + 1 WHERE cyrillic = ?', [raw]);

        tokens.add({
          'type': 'unknown',
          'original': raw,
          'options': []
        });
      }
    }
    
    stmtWord.dispose();
    stmtDef.dispose();

    return Response.ok(
      jsonEncode({'tokens': tokens}),
      headers: {'content-type': 'application/json'},
    );
  } catch (e) {
    print(e);
    return Response.badRequest(body: 'Invalid JSON or Server Error');
  }
}

// Manual CORS Middleware
Middleware corsMiddleware() {
  return (Handler handler) {
    return (Request request) async {
      if (request.method == 'OPTIONS') {
        return Response.ok('', headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
          'Access-Control-Allow-Headers': 'Origin, Content-Type',
        });
      }
      final response = await handler(request);
      return response.change(headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
        'Access-Control-Allow-Headers': 'Origin, Content-Type',
      });
    };
  };
}

void main(List<String> args) async {
  // Initialize DB
  _db = sqlite3.open('dictionary.db');
  print('Database opened.');

  // Use any available host or container IP (usually `0.0.0.0`).
  final ip = InternetAddress.anyIPv4;

  // Configure a pipeline that logs requests.
  final handler = Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(corsMiddleware()) // Add CORS headers
      .addHandler(_router.call);

  // For running in containers, we respect the PORT environment variable.
  final port = int.parse(Platform.environment['PORT'] ?? '8080');
  final server = await serve(handler, ip, port);
  print('Server listening on port ${server.port}');
}
