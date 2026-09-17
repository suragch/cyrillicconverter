import 'dart:convert';
import 'dart:io';

import 'package:pocketbase/pocketbase.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_router/shelf_router.dart';

import 'package:backend/auth_middleware.dart';
import 'package:backend/cyrillic_validator.dart';
import 'package:backend/database.dart';
import 'package:backend/tokenizer.dart';

late final AppDatabase _db;
late final String _pbUrl;

// Configure routes
final _router = Router()
  ..get('/health', _healthHandler)
  ..post('/auth/login', _loginHandler)
  ..get('/auth/me', _authMeHandler)
  ..post('/echo', _echoHandler)
  ..post('/convert', _convertHandler)
  ..post('/contribute', _contributeHandler)
  ..post('/suggest', _contributeHandler)
  ..get('/export/csv', _exportCsvHandler)
  ..get('/export/json', _exportJsonHandler)
  // Public Dictionary lookup
  ..get('/words/check', _adminCheckWordHandler)
  // Admin / Moderator endpoints (Protected)
  ..get('/admin/words/check', requireModerator(_adminCheckWordHandler))
  ..get('/admin/missing', requireModerator(_adminMissingHandler))
  ..post('/admin/missing/reject', requireModerator(_adminRejectMissingHandler))
  ..get('/admin/suggestions', requireModerator(_adminSuggestionsHandler))
  ..post('/admin/suggestions/approve', requireModerator(_adminApproveHandler))
  ..post('/admin/suggestions/reject', requireModerator(_adminRejectHandler))
  ..post('/admin/words', requireModerator(_adminAddWordHandler))
  ..get('/admin/db/download', requireModerator(_adminDbDownloadHandler))
  ..get('/admin/db/export-json', requireModerator(_adminDbExportJsonHandler))
  ..post('/admin/db/seed', requireModerator(_adminDbSeedHandler));

Response _healthHandler(Request request) {
  return Response.ok(
    jsonEncode({'status': 'ok', 'timestamp': DateTime.now().toIso8601String()}),
    headers: {'content-type': 'application/json'},
  );
}

Future<Response> _loginHandler(Request request) async {
  try {
    final content = await request.readAsString();
    final json = jsonDecode(content) as Map<String, dynamic>;
    final email = (json['email'] as String?)?.trim() ?? '';
    final password = json['password'] as String? ?? '';

    if (email.isEmpty || password.isEmpty) {
      return Response.badRequest(
        body: jsonEncode({'error': 'Email and password are required'}),
        headers: {'content-type': 'application/json'},
      );
    }

    final pb = PocketBase(_pbUrl);
    final authData = await pb.collection('users').authWithPassword(email, password);
    final user = authData.record;
    final role = user.data['role'] as String? ?? '';

    return Response.ok(
      jsonEncode({
        'token': authData.token,
        'user': {
          'id': user.id,
          'email': user.getStringValue('email').isNotEmpty ? user.getStringValue('email') : email,
          'role': role,
        },
      }),
      headers: {'content-type': 'application/json'},
    );
  } catch (e) {
    return Response(
      401,
      body: jsonEncode({'error': 'Имэйл эсвэл нууц үг буруу байна (Invalid email or password)'}),
      headers: {'content-type': 'application/json'},
    );
  }
}

Response _authMeHandler(Request request) {
  final auth = request.context['auth'] as AuthContext?;
  if (auth == null || auth.user == null) {
    return Response(
      401,
      body: jsonEncode({'error': 'Not authenticated'}),
      headers: {'content-type': 'application/json'},
    );
  }

  final user = auth.user!;
  final role = user.data['role'] as String? ?? '';
  final email = user.getStringValue('email');
  final id = user.id;

  return Response.ok(
    jsonEncode({
      'id': id,
      'email': email,
      'role': role,
      'isModerator': auth.isModerator,
      if (auth.token != null) 'token': auth.token,
      'user': {
        'id': id,
        'email': email,
        'role': role,
      },
    }),
    headers: {'content-type': 'application/json'},
  );
}

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

const Map<String, String> _punctuationToMenksoft = {
  '.': '\uE237', // Traditional Mongolian full stop
  '。': '\uE237',
  ',': '\uE236', // Traditional Mongolian comma
  '،': '\uE236',
  '?': '\uE251', // Vertical question mark
  '!': '\uE250', // Vertical exclamation mark
  ':': '\uE238', // Vertical colon
  ';': '\uE252', // Vertical semicolon
  '(': '\uE253', // Vertical left parenthesis
  ')': '\uE254', // Vertical right parenthesis
  '[': '\uE257', // Vertical left bracket
  ']': '\uE258', // Vertical right bracket
  '«': '\uE259', // Left double angle bracket
  '»': '\uE25A', // Right double angle bracket
  '“': '\uE259',
  '”': '\uE25A',
  '"': '\uE259',
  '—': '\uE261', // Em dash
  '–': '\uE260', // En dash
  '...': '\uE235', // Ellipsis
  '…': '\uE235',
  '?!': '\uE24E',
  '!?': '\uE24F',
};

String _convertDelimiter(String text) {
  if (_punctuationToMenksoft.containsKey(text)) {
    return _punctuationToMenksoft[text]!;
  }
  final buffer = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    final ch = text[i];
    buffer.write(_punctuationToMenksoft[ch] ?? ch);
  }
  return buffer.toString();
}

Future<Response> _convertHandler(Request request) async {
  final content = await request.readAsString();
  try {
    final json = jsonDecode(content) as Map<String, dynamic>;
    final text = json['text'] as String? ?? '';

    final rawTokens = Tokenizer.tokenize(text);
    final List<Map<String, dynamic>> resultTokens = [];

    for (var i = 0; i < rawTokens.length; i++) {
      final token = rawTokens[i];

      if (token.type == TokenType.space) {
        resultTokens.add({
          'type': 'space',
          'original': token.text,
          'menksoft': ' ',
          'options': [],
        });
      } else if (token.type == TokenType.delimiter) {
        resultTokens.add({
          'type': 'delimiter',
          'original': token.text,
          'menksoft': _convertDelimiter(token.text),
          'options': [],
        });
      } else {
        // TokenType.word
        final options = _db.lookupWord(token.text);

        if (options.isNotEmpty) {
          resultTokens.add({
            'type': 'word',
            'original': token.text,
            'options': options,
          });
        } else {
          // Unknown word - extract a window of text for context
          final start = (i - 4).clamp(0, rawTokens.length);
          final end = (i + 5).clamp(0, rawTokens.length);
          final contextSnippet = rawTokens.sublist(start, end).map((t) => t.text).join();

          // Only accept and log strictly Cyrillic text
          if (CyrillicValidator.isCyrillicWord(token.text)) {
            _db.logUnknownWord(token.text, context: contextSnippet);
          }

          resultTokens.add({
            'type': 'unknown',
            'original': token.text,
            'options': [],
          });
        }
      }
    }

    return Response.ok(
      jsonEncode({'tokens': resultTokens}),
      headers: {'content-type': 'application/json'},
    );
  } catch (e, stack) {
    print('Error in /convert: $e\n$stack');
    return Response.internalServerError(
      body: jsonEncode({'error': 'Conversion failed: $e'}),
      headers: {'content-type': 'application/json'},
    );
  }
}

Future<Response> _contributeHandler(Request request) async {
  final content = await request.readAsString();
  try {
    final json = jsonDecode(content) as Map<String, dynamic>;
    final cyrillic = json['cyrillic'] as String?;
    final menksoft = json['menksoft'] as String?;
    final context = json['context'] as String? ?? '';
    final auth = request.context['auth'] as AuthContext?;

    if (cyrillic == null || cyrillic.trim().isEmpty) {
      return Response.badRequest(body: jsonEncode({'error': 'cyrillic is required'}));
    }
    if (!CyrillicValidator.isCyrillicWord(cyrillic)) {
      return Response.badRequest(
        body: jsonEncode({'error': 'Зөвхөн кирилл үг оруулна уу (Only Cyrillic text accepted)'}),
        headers: {'content-type': 'application/json'},
      );
    }
    if (menksoft == null || menksoft.trim().isEmpty) {
      return Response.badRequest(body: jsonEncode({'error': 'menksoft is required'}));
    }

    _db.addSuggestion(
      cyrillic: cyrillic,
      menksoft: menksoft,
      context: context,
      submittedBy: auth?.user?.id ?? 'anonymous',
    );

    return Response.ok(
      jsonEncode({'success': true, 'message': 'Suggestion submitted for review'}),
      headers: {'content-type': 'application/json'},
    );
  } catch (e) {
    print('Error in /contribute: $e');
    return Response.badRequest(body: jsonEncode({'error': 'Invalid request: $e'}));
  }
}

Future<Response> _exportCsvHandler(Request request) async {
  final rows = _db.db.select('''
    SELECT w.cyrillic, d.menksoft_code, d.explanation, d.is_primary
    FROM words w
    JOIN definitions d ON w.id = d.word_id
    ORDER BY w.cyrillic ASC, d.is_primary DESC;
  ''');

  final csv = StringBuffer('cyrillic,menksoft,explanation,is_primary\n');
  for (final row in rows) {
    final cyrillic = (row['cyrillic'] as String).replaceAll('"', '""');
    final menksoft = (row['menksoft_code'] as String).replaceAll('"', '""');
    final explanation = ((row['explanation'] as String?) ?? '').replaceAll('"', '""');
    final isPrimary = row['is_primary'] as int;
    csv.writeln('"$cyrillic","$menksoft","$explanation",$isPrimary');
  }

  return Response.ok(
    csv.toString(),
    headers: {
      'content-type': 'text/csv; charset=utf-8',
      'content-disposition': 'attachment; filename="mongol_dictionary.csv"',
    },
  );
}

Future<Response> _exportJsonHandler(Request request) async {
  final list = _db.getApprovedWordsJson();
  return Response.ok(
    jsonEncode(list),
    headers: {
      'content-type': 'application/json; charset=utf-8',
      'content-disposition': 'attachment; filename="mongol_dictionary.json"',
    },
  );
}

Future<Response> _adminDbDownloadHandler(Request request) async {
  final tempFile = File('${Directory.systemTemp.path}/db_backup_${DateTime.now().millisecondsSinceEpoch}.db');
  try {
    _db.createBackupSnapshot(tempFile.path);
    final bytes = await tempFile.readAsBytes();
    final dateStr = DateTime.now().toIso8601String().split('T').first;
    final filename = 'cyrillic_dictionary_full_$dateStr.db';
    return Response.ok(
      bytes,
      headers: {
        'content-type': 'application/vnd.sqlite3',
        'content-disposition': 'attachment; filename="$filename"',
      },
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': 'Failed to create database snapshot: $e'}),
      headers: {'content-type': 'application/json'},
    );
  } finally {
    if (tempFile.existsSync()) {
      try {
        tempFile.deleteSync();
      } catch (_) {}
    }
  }
}

Future<Response> _adminDbExportJsonHandler(Request request) async {
  final fullData = _db.getFullDatabaseJson();
  final dateStr = DateTime.now().toIso8601String().split('T').first;
  final filename = 'cyrillic_dictionary_dump_$dateStr.json';
  return Response.ok(
    jsonEncode(fullData),
    headers: {
      'content-type': 'application/json; charset=utf-8',
      'content-disposition': 'attachment; filename="$filename"',
    },
  );
}

Future<Response> _adminDbSeedHandler(Request request) async {
  try {
    String? customUrl;
    if (request.contentLength != null && request.contentLength! > 0) {
      try {
        final body = await request.readAsString();
        if (body.isNotEmpty) {
          final json = jsonDecode(body) as Map<String, dynamic>;
          customUrl = json['url'] as String?;
        }
      } catch (_) {}
    }

    final url = customUrl ?? Platform.environment['OLD_APP_URL'] ?? 'https://cyrillic.suragch.dev/api/collections/words/records';
    final result = await _db.seedFromOldApp(
      baseUrl: url,
      onProgress: (msg) => print('[AdminSeed] $msg'),
    );
    return Response.ok(
      jsonEncode({'success': true, 'stats': result}),
      headers: {'content-type': 'application/json'},
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': 'Seeding failed: $e'}),
      headers: {'content-type': 'application/json'},
    );
  }
}

// Admin / Moderator Handlers

Future<Response> _adminMissingHandler(Request request) async {
  final limit = int.tryParse(request.url.queryParameters['limit'] ?? '100') ?? 100;
  final minFrequency = int.tryParse(request.url.queryParameters['min_frequency'] ?? '1') ?? 1;
  final results = _db.getTopUnknownWords(limit: limit, minFrequency: minFrequency);
  return Response.ok(
    jsonEncode({'missing': results}),
    headers: {'content-type': 'application/json'},
  );
}

Future<Response> _adminSuggestionsHandler(Request request) async {
  final limit = int.tryParse(request.url.queryParameters['limit'] ?? '100') ?? 100;
  final results = _db.getPendingSuggestions(limit: limit);
  return Response.ok(
    jsonEncode({'suggestions': results}),
    headers: {'content-type': 'application/json'},
  );
}

Future<Response> _adminCheckWordHandler(Request request) async {
  final cyrillic = request.url.queryParameters['cyrillic']?.trim().toLowerCase() ?? '';
  if (cyrillic.isEmpty) {
    return Response.ok(
      jsonEncode({'exists': false, 'definitions': [], 'rejectionHistory': []}),
      headers: {'content-type': 'application/json'},
    );
  }

  final defs = _db.lookupWord(cyrillic);
  final rejectionHistory = _db.getRejectionHistory(cyrillic);
  return Response.ok(
    jsonEncode({
      'cyrillic': cyrillic,
      'exists': defs.isNotEmpty,
      'definitions': defs,
      'rejectionHistory': rejectionHistory,
    }),
    headers: {'content-type': 'application/json'},
  );
}

Future<Response> _adminApproveHandler(Request request) async {
  final content = await request.readAsString();
  try {
    final json = jsonDecode(content) as Map<String, dynamic>;
    final id = json['id'] as int;
    final cyrillic = json['cyrillic'] as String?;
    final menksoft = json['menksoft'] as String?;
    final explanation = json['explanation'] as String?;

    final auth = request.context['auth'] as AuthContext?;
    final verifiedBy = auth?.user?.id ??
        auth?.user?.getStringValue('email') ??
        json['moderatorId'] as String? ??
        'moderator';

    _db.approveSuggestion(
      id,
      verifiedBy: verifiedBy,
      cyrillic: cyrillic,
      menksoft: menksoft,
      explanation: explanation,
    );
    return Response.ok(
      jsonEncode({'success': true, 'verifiedBy': verifiedBy}),
      headers: {'content-type': 'application/json'},
    );
  } catch (e) {
    return Response.badRequest(body: jsonEncode({'error': 'Invalid request: $e'}));
  }
}

Future<Response> _adminRejectHandler(Request request) async {
  final content = await request.readAsString();
  try {
    final json = jsonDecode(content) as Map<String, dynamic>;
    final id = json['id'] as int;
    final reason = json['reason'] as String?;

    final auth = request.context['auth'] as AuthContext?;
    final reviewedBy = auth?.user?.id ??
        auth?.user?.getStringValue('email') ??
        json['moderatorId'] as String? ??
        'moderator';

    _db.rejectSuggestion(id, reason: reason, reviewedBy: reviewedBy);
    return Response.ok(
      jsonEncode({'success': true, 'reviewedBy': reviewedBy}),
      headers: {'content-type': 'application/json'},
    );
  } catch (e) {
    return Response.badRequest(body: jsonEncode({'error': 'Invalid request: $e'}));
  }
}

Future<Response> _adminRejectMissingHandler(Request request) async {
  final content = await request.readAsString();
  try {
    final json = jsonDecode(content) as Map<String, dynamic>;
    final cyrillic = (json['cyrillic'] as String?)?.trim() ?? '';
    final reason = (json['reason'] as String?)?.trim() ?? 'rejected';

    if (cyrillic.isEmpty) {
      return Response.badRequest(body: jsonEncode({'error': 'Cyrillic word is required'}));
    }

    final auth = request.context['auth'] as AuthContext?;
    final reviewedBy = auth?.user?.id ??
        auth?.user?.getStringValue('email') ??
        json['moderatorId'] as String? ??
        'moderator';

    _db.rejectMissingWord(cyrillic, reason: reason, reviewedBy: reviewedBy);

    return Response.ok(
      jsonEncode({'success': true, 'reviewedBy': reviewedBy}),
      headers: {'content-type': 'application/json'},
    );
  } catch (e) {
    return Response.badRequest(body: jsonEncode({'error': 'Invalid request: $e'}));
  }
}

Future<Response> _adminAddWordHandler(Request request) async {
  final content = await request.readAsString();
  try {
    final json = jsonDecode(content) as Map<String, dynamic>;
    final cyrillic = json['cyrillic'] as String;
    final menksoft = json['menksoft'] as String;
    final explanation = json['explanation'] as String?;
    final isPrimary = json['isPrimary'] as bool? ?? true;
    final auth = request.context['auth'] as AuthContext?;

    final wordId = _db.addWordDefinition(
      cyrillic: cyrillic,
      menksoft: menksoft,
      explanation: explanation,
      isPrimary: isPrimary,
      verifiedBy: auth?.user?.id ?? 'moderator',
    );

    // Also remove from unknown_logs if it was there
    _db.db.execute('DELETE FROM unknown_logs WHERE cyrillic = ?', [cyrillic.trim().toLowerCase()]);

    return Response.ok(
      jsonEncode({'success': true, 'wordId': wordId}),
      headers: {'content-type': 'application/json'},
    );
  } catch (e) {
    return Response.badRequest(body: jsonEncode({'error': 'Invalid request: $e'}));
  }
}

Middleware payloadLimitMiddleware({int maxBytes = 10 * 1024 * 1024}) {
  return (Handler handler) {
    return (Request request) async {
      if (request.contentLength != null && request.contentLength! > maxBytes) {
        return Response(
          413,
          body: jsonEncode({'error': 'Payload exceeds maximum limit of ${maxBytes ~/ (1024 * 1024)}MB'}),
          headers: {'content-type': 'application/json'},
        );
      }
      return handler(request);
    };
  };
}

Middleware corsMiddleware() {
  final origin = Platform.environment['CORS_ORIGIN'] ?? '*';
  return (Handler handler) {
    return (Request request) async {
      if (request.method == 'OPTIONS') {
        return Response.ok('', headers: {
          'Access-Control-Allow-Origin': origin,
          'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
          'Access-Control-Allow-Headers': 'Origin, Content-Type, Authorization',
        });
      }
      final response = await handler(request);
      return response.change(headers: {
        'Access-Control-Allow-Origin': origin,
        'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
        'Access-Control-Allow-Headers': 'Origin, Content-Type, Authorization',
      });
    };
  };
}

void main(List<String> args) async {
  final dbPath = Platform.environment['DB_PATH'] ?? 'dictionary.db';
  _db = AppDatabase.open(dbPath);
  _db.initSchema();
  print('SQLite database opened at $dbPath.');

  // Auto-seed if database has 0 words and AUTO_SEED is set to true
  final autoSeed = Platform.environment['AUTO_SEED'] == 'true';
  if (autoSeed && _db.getWordCount() == 0) {
    final url = Platform.environment['OLD_APP_URL'] ?? 'https://cyrillic.suragch.dev/api/collections/words/records';
    print('AUTO_SEED=true and database is empty. Seeding from $url...');
    try {
      final stats = await _db.seedFromOldApp(baseUrl: url, onProgress: (m) => print('[AutoSeed] $m'));
      print('Auto-seeding completed: $stats');
    } catch (e) {
      print('Auto-seeding error: $e');
    }
  }

  final ip = InternetAddress.anyIPv4;
  final port = int.parse(Platform.environment['PORT'] ?? '8080');
  _pbUrl = Platform.environment['POCKETBASE_URL'] ?? 'http://127.0.0.1:8090';

  final pipeline = Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(payloadLimitMiddleware())
      .addMiddleware(corsMiddleware())
      .addMiddleware(pocketBaseAuth(pbUrl: _pbUrl))
      .addHandler(_router.call);

  final server = await serve(pipeline, ip, port);
  print('Server listening on port ${server.port}');
}
