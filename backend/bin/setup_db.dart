import 'dart:io';
import 'package:sqlite3/sqlite3.dart';

void main() {
  final db = sqlite3.open('dictionary.db');

  // Create tables
  db.execute('''
    CREATE TABLE IF NOT EXISTS words (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      cyrillic TEXT NOT NULL UNIQUE,
      is_abbreviation BOOLEAN DEFAULT 0
    );
    CREATE INDEX IF NOT EXISTS idx_cyrillic ON words(cyrillic);
  ''');

  db.execute('''
    CREATE TABLE IF NOT EXISTS definitions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      word_id INTEGER NOT NULL,
      menksoft_code TEXT NOT NULL,
      explanation TEXT,
      is_primary BOOLEAN DEFAULT 0,
      FOREIGN KEY(word_id) REFERENCES words(id)
    );
  ''');

  db.execute('''
    CREATE TABLE IF NOT EXISTS unknown_logs (
      cyrillic TEXT PRIMARY KEY,
      frequency INTEGER DEFAULT 1,
      last_seen TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
  ''');

  db.execute('''
    CREATE TABLE IF NOT EXISTS suggestions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      cyrillic TEXT NOT NULL,
      menksoft_code TEXT NOT NULL,
      context TEXT,
      submitted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
  ''');

  print('Tables created.');

  // Seed data
  final words = [
    {'cyrillic': 'Монгол', 'menksoft': '\u182E\u1823\u1829\u182D\u1823\u182F', 'explanation': 'Mongol'},
    {'cyrillic': 'сайн', 'menksoft': '\u1830\u1822\u1828\u1822', 'explanation': 'good'},
    {'cyrillic': 'байна', 'menksoft': '\u182A\u1822\u1828\u1822\u1826', 'explanation': 'is/exists'},
    {'cyrillic': 'уу', 'menksoft': '\u1824\u1824', 'explanation': 'question particle'},
  ];

  final stmtWord = db.prepare('INSERT OR IGNORE INTO words (cyrillic) VALUES (?)');
  final stmtDef = db.prepare('INSERT INTO definitions (word_id, menksoft_code, explanation, is_primary) VALUES (?, ?, ?, 1)');
  final getWordId = db.prepare('SELECT id FROM words WHERE cyrillic = ?');

  for (final w in words) {
    stmtWord.execute([w['cyrillic']]);
    final result = getWordId.select([w['cyrillic']]);
    if (result.isNotEmpty) {
      final id = result.first['id'];
      // Check if definition exists to avoid duplicates on re-run
      final checkDef = db.select('SELECT id FROM definitions WHERE word_id = ? AND menksoft_code = ?', [id, w['menksoft']]);
      if (checkDef.isEmpty) {
         stmtDef.execute([id, w['menksoft'], w['explanation']]);
      }
    }
  }

  // Seed homonym "банк"
  // 1. Financial bank
  // 2. River bank (just for example, though usually different word in Mongol)
  stmtWord.execute(['банк']);
  final bankIdResult = getWordId.select(['банк']);
  if (bankIdResult.isNotEmpty) {
    final bankId = bankIdResult.first['id'];
    
    // Financial
    final checkDef1 = db.select('SELECT id FROM definitions WHERE word_id = ? AND explanation = ?', [bankId, 'financial institution']);
    if (checkDef1.isEmpty) {
        stmtDef.execute([bankId, '\u182A\u1820\u1829\u182A\u1821', 'financial institution']); // Dummy code
    }

    // River bank (using different dummy code for distinction)
    final checkDef2 = db.select('SELECT id FROM definitions WHERE word_id = ? AND explanation = ?', [bankId, 'river bank']);
    if (checkDef2.isEmpty) {
        // Manually insert with is_primary = 0
        db.execute('INSERT INTO definitions (word_id, menksoft_code, explanation, is_primary) VALUES (?, ?, ?, 0)', [bankId, '\u182A\u1820\u1829\u182A\u1821_river', 'river bank']);
    }
  }

  stmtWord.dispose();
  stmtDef.dispose();
  getWordId.dispose();
  db.dispose();

  print('Seed data inserted.');
}
