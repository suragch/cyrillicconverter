import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:backend/database.dart';

void main() async {
  final dbPath = 'dictionary.db';
  print('Connecting to $dbPath...');
  final appDb = AppDatabase.open(dbPath);
  appDb.initSchema();

  final db = appDb.db;
  print('Schema initialized. Starting migration from cyrillic.suragch.dev...');

  final baseUrl = 'https://cyrillic.suragch.dev/api/collections/words/records';
  int page = 1;
  const perPage = 500;
  int totalImported = 0;
  int totalSkipped = 0;

  final stopwatch = Stopwatch()..start();

  while (true) {
    final url = Uri.parse('$baseUrl?page=$page&perPage=$perPage');
    stdout.write('Fetching page $page... ');
    final response = await http.get(url);

    if (response.statusCode != 200) {
      print('Failed to fetch page $page: ${response.statusCode}');
      break;
    }

    final data = jsonDecode(response.body);
    final List<dynamic> items = data['items'];
    final int totalPages = data['totalPages'] ?? 1;
    final int totalItems = data['totalItems'] ?? 0;

    if (items.isEmpty) {
      print('Done.');
      break;
    }

    // Insert batch in transaction for maximum speed
    db.execute('BEGIN TRANSACTION;');
    try {
      for (final item in items) {
        final cyrillic = (item['cyrillic'] as String?)?.trim();
        final mongol = (item['mongol'] as String?)?.trim();

        if (cyrillic == null || cyrillic.isEmpty || mongol == null || mongol.isEmpty) {
          totalSkipped++;
          continue;
        }

        final normalized = cyrillic.toLowerCase();

        // 1. Insert word
        db.execute('INSERT OR IGNORE INTO words (cyrillic) VALUES (?);', [normalized]);

        // 2. Get word id
        final row = db.select('SELECT id FROM words WHERE cyrillic = ? LIMIT 1;', [normalized]);
        if (row.isEmpty) {
          totalSkipped++;
          continue;
        }
        final wordId = row.first['id'] as int;

        // 3. Insert definition if not exists
        final existingDef = db.select(
          'SELECT id FROM definitions WHERE word_id = ? AND menksoft_code = ? LIMIT 1;',
          [wordId, mongol],
        );

        if (existingDef.isEmpty) {
          // Check if there are already definitions for this word
          final countRow = db.select('SELECT count(*) as count FROM definitions WHERE word_id = ?;', [wordId]);
          final existingCount = countRow.first['count'] as int;
          final isPrimary = existingCount == 0 ? 1 : 0;

          db.execute('''
            INSERT INTO definitions (word_id, menksoft_code, is_primary, verified_by)
            VALUES (?, ?, ?, 'migrated');
          ''', [wordId, mongol, isPrimary]);
          totalImported++;
        }
      }
      db.execute('COMMIT;');
    } catch (e) {
      db.execute('ROLLBACK;');
      print('Error during page $page transaction: $e');
      rethrow;
    }

    print('Imported ${items.length} items (Total: $totalImported / $totalItems)');

    if (page >= totalPages) {
      break;
    }
    page++;
  }

  stopwatch.stop();
  print('--- Migration Summary ---');
  print('Time taken: ${stopwatch.elapsed.inSeconds}s');
  print('Total definitions imported: $totalImported');
  print('Total skipped/empty: $totalSkipped');

  final wordCount = db.select('SELECT count(*) as cnt FROM words;').first['cnt'];
  final defCount = db.select('SELECT count(*) as cnt FROM definitions;').first['cnt'];
  print('Total unique words in DB: $wordCount');
  print('Total definitions in DB: $defCount');

  appDb.close();
}
