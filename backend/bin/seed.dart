import 'dart:convert';
import 'dart:io';
import 'package:backend/database.dart';

void printUsage() {
  print('''
Usage: dart run bin/seed.dart [options]

Options:
  --from-old-app           Seed data from the previous app version API (PocketBase)
  --url <url>              Custom API URL for the old app (default: https://cyrillic.suragch.dev/api/collections/words/records)
  --from-json <file>       Seed data from a JSON dump file
  --export-json <file>     Export current database to a JSON file
  --export-backup <file>   Export current database to an atomic SQLite snapshot file (.db)
  --db <path>              Path to SQLite database file (default: dictionary.db or DB_PATH env)
  --help, -h               Show this help message
''');
}

void main(List<String> args) async {
  if (args.isEmpty || args.contains('--help') || args.contains('-h')) {
    printUsage();
    return;
  }

  String dbPath = Platform.environment['DB_PATH'] ?? 'dictionary.db';
  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--db' && i + 1 < args.length) {
      dbPath = args[i + 1];
    }
  }

  print('Opening SQLite database at: $dbPath');
  final appDb = AppDatabase.open(dbPath);
  appDb.initSchema();

  try {
    if (args.contains('--from-old-app')) {
      String url = Platform.environment['OLD_APP_URL'] ??
          'https://cyrillic.suragch.dev/api/collections/words/records';
      final urlIdx = args.indexOf('--url');
      if (urlIdx != -1 && urlIdx + 1 < args.length) {
        url = args[urlIdx + 1];
      }

      print('Seeding data from old app version: $url');
      final stopwatch = Stopwatch()..start();
      final stats = await appDb.seedFromOldApp(
        baseUrl: url,
        onProgress: (msg) => stdout.write('\r$msg'),
      );
      stopwatch.stop();
      print('\n--- Seeding Completed ---');
      print('Time elapsed: ${stopwatch.elapsed.inSeconds}s');
      print('Imported definitions: ${stats['imported']}');
      print('Skipped / existing: ${stats['skipped']}');
      print('Total upstream items: ${stats['total']}');
      print('Total words in database: ${appDb.getWordCount()}');
    } else if (args.contains('--from-json')) {
      final idx = args.indexOf('--from-json');
      if (idx + 1 >= args.length) {
        print('Error: --from-json requires a file path');
        exit(1);
      }
      final filePath = args[idx + 1];
      final file = File(filePath);
      if (!file.existsSync()) {
        print('Error: File not found: $filePath');
        exit(1);
      }

      print('Reading JSON seed data from $filePath...');
      final content = await file.readAsString();
      final data = jsonDecode(content);

      if (data is List) {
        // Simple list of word definitions: [{'cyrillic': ..., 'menksoft': ..., 'explanation': ...}]
        int count = 0;
        appDb.db.execute('BEGIN TRANSACTION;');
        for (final item in data) {
          final cyr = (item['cyrillic'] as String?)?.trim();
          final menk = (item['menksoft'] as String?)?.trim();
          final exp = item['explanation'] as String?;
          final isPrim = item['isPrimary'] as bool? ?? true;
          if (cyr != null && cyr.isNotEmpty && menk != null && menk.isNotEmpty) {
            appDb.addWordDefinition(
              cyrillic: cyr,
              menksoft: menk,
              explanation: exp,
              isPrimary: isPrim,
              verifiedBy: 'json_seed',
            );
            count++;
          }
        }
        appDb.db.execute('COMMIT;');
        print('Imported $count words from JSON list.');
      } else if (data is Map && data.containsKey('words')) {
        // Full database dump
        final words = data['words'] as List? ?? [];
        final defs = data['definitions'] as List? ?? [];
        print('Importing full database dump (${words.length} words, ${defs.length} definitions)...');
        appDb.db.execute('BEGIN TRANSACTION;');
        for (final w in words) {
          appDb.db.execute('INSERT OR IGNORE INTO words (id, cyrillic, is_abbreviation) VALUES (?, ?, ?);', [
            w['id'],
            w['cyrillic'],
            w['is_abbreviation'] ?? 0,
          ]);
        }
        for (final d in defs) {
          appDb.db.execute('INSERT OR IGNORE INTO definitions (id, word_id, menksoft_code, explanation, is_primary, verified_by) VALUES (?, ?, ?, ?, ?, ?);', [
            d['id'],
            d['word_id'],
            d['menksoft_code'],
            d['explanation'],
            d['is_primary'] ?? 0,
            d['verified_by'],
          ]);
        }
        appDb.db.execute('COMMIT;');
        print('Full database dump imported successfully.');
      }
    } else if (args.contains('--export-json')) {
      final idx = args.indexOf('--export-json');
      if (idx + 1 >= args.length) {
        print('Error: --export-json requires a file path');
        exit(1);
      }
      final outPath = args[idx + 1];
      print('Exporting full database to JSON: $outPath');
      final jsonMap = appDb.getFullDatabaseJson();
      await File(outPath).writeAsString(jsonEncode(jsonMap));
      print('Export complete (${jsonMap['words'].length} words).');
    } else if (args.contains('--export-backup')) {
      final idx = args.indexOf('--export-backup');
      if (idx + 1 >= args.length) {
        print('Error: --export-backup requires a file path');
        exit(1);
      }
      final outPath = args[idx + 1];
      print('Creating atomic SQLite backup at: $outPath');
      appDb.createBackupSnapshot(outPath);
      print('Backup complete. File size: ${File(outPath).lengthSync()} bytes.');
    } else {
      printUsage();
    }
  } catch (e, stack) {
    print('Error during operation: $e\n$stack');
    exit(1);
  } finally {
    appDb.close();
  }
}
