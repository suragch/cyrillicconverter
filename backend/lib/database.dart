import 'package:sqlite3/sqlite3.dart';

class AppDatabase {
  final Database db;

  AppDatabase(this.db);

  factory AppDatabase.open(String path) {
    final db = sqlite3.open(path);
    // Performance optimizations for SQLite
    db.execute('PRAGMA journal_mode = WAL;');
    db.execute('PRAGMA synchronous = NORMAL;');
    db.execute('PRAGMA foreign_keys = ON;');
    return AppDatabase(db);
  }

  void initSchema() {
    db.execute('''
      CREATE TABLE IF NOT EXISTS words (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cyrillic TEXT NOT NULL UNIQUE,
        is_abbreviation BOOLEAN DEFAULT 0,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
      CREATE INDEX IF NOT EXISTS idx_words_cyrillic ON words(cyrillic);

      CREATE TABLE IF NOT EXISTS definitions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        word_id INTEGER NOT NULL,
        menksoft_code TEXT NOT NULL,
        explanation TEXT,
        is_primary BOOLEAN DEFAULT 0,
        verified_by TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY(word_id) REFERENCES words(id) ON DELETE CASCADE
      );
      CREATE INDEX IF NOT EXISTS idx_definitions_word_id ON definitions(word_id);

      CREATE TABLE IF NOT EXISTS unknown_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cyrillic TEXT NOT NULL UNIQUE,
        frequency INTEGER DEFAULT 1,
        last_context TEXT,
        first_seen TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        last_seen TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
      CREATE INDEX IF NOT EXISTS idx_unknown_freq ON unknown_logs(frequency DESC);

      CREATE TABLE IF NOT EXISTS suggestions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cyrillic TEXT NOT NULL,
        menksoft_code TEXT NOT NULL,
        context TEXT,
        submitted_by TEXT,
        status TEXT DEFAULT 'pending',
        moderator_note TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        reviewed_at TIMESTAMP
      );
      CREATE INDEX IF NOT EXISTS idx_suggestions_status ON suggestions(status);
    ''');
  }

  /// Looks up definitions for a Cyrillic word.
  /// Returns a list of maps: [{'menksoft': '...', 'explanation': '...', 'isDefault': true/false}]
  List<Map<String, dynamic>> lookupWord(String rawWord) {
    final normalized = rawWord.trim().toLowerCase();
    if (normalized.isEmpty) return [];

    final stmtWord = db.prepare('SELECT id FROM words WHERE cyrillic = ?');
    final wordResult = stmtWord.select([normalized]);
    stmtWord.dispose();

    if (wordResult.isEmpty) return [];

    final wordId = wordResult.first['id'] as int;
    final stmtDef = db.prepare(
      'SELECT menksoft_code, explanation, is_primary FROM definitions WHERE word_id = ? ORDER BY is_primary DESC, id ASC',
    );
    final defResult = stmtDef.select([wordId]);
    stmtDef.dispose();

    return defResult.map((row) {
      return {
        'menksoft': row['menksoft_code'] as String,
        'explanation': row['explanation'] as String?,
        'isDefault': (row['is_primary'] as int) == 1,
      };
    }).toList();
  }

  /// Logs or increments frequency of an unknown word.
  void logUnknownWord(String rawWord, {String? context}) {
    final normalized = rawWord.trim().toLowerCase();
    if (normalized.isEmpty) return;

    db.execute('''
      INSERT INTO unknown_logs (cyrillic, frequency, last_context, last_seen)
      VALUES (?, 1, ?, CURRENT_TIMESTAMP)
      ON CONFLICT(cyrillic) DO UPDATE SET
        frequency = frequency + 1,
        last_context = COALESCE(?, last_context),
        last_seen = CURRENT_TIMESTAMP;
    ''', [normalized, context, context]);
  }

  /// Adds a user suggestion.
  void addSuggestion({
    required String cyrillic,
    required String menksoft,
    String? context,
    String? submittedBy,
  }) {
    db.execute('''
      INSERT INTO suggestions (cyrillic, menksoft_code, context, submitted_by)
      VALUES (?, ?, ?, ?)
    ''', [cyrillic.trim(), menksoft.trim(), context?.trim(), submittedBy]);
  }

  /// Gets the top unknown words ordered by frequency.
  List<Map<String, dynamic>> getTopUnknownWords({int limit = 100}) {
    final results = db.select(
      'SELECT id, cyrillic, frequency, last_context, last_seen FROM unknown_logs ORDER BY frequency DESC LIMIT ?',
      [limit],
    );
    return results.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  /// Gets pending suggestions for moderator review.
  List<Map<String, dynamic>> getPendingSuggestions({int limit = 100}) {
    final results = db.select(
      "SELECT id, cyrillic, menksoft_code, context, submitted_by, created_at FROM suggestions WHERE status = 'pending' ORDER BY created_at ASC LIMIT ?",
      [limit],
    );
    return results.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  /// Adds or updates a word and definition. Returns word_id.
  int addWordDefinition({
    required String cyrillic,
    required String menksoft,
    String? explanation,
    bool isPrimary = true,
    String? verifiedBy,
  }) {
    final normalized = cyrillic.trim().toLowerCase();
    final stmtWord = db.prepare('INSERT OR IGNORE INTO words (cyrillic) VALUES (?)');
    stmtWord.execute([normalized]);
    stmtWord.dispose();

    final stmtGetId = db.prepare('SELECT id FROM words WHERE cyrillic = ?');
    final wordRow = stmtGetId.select([normalized]);
    stmtGetId.dispose();
    final wordId = wordRow.first['id'] as int;

    // Check if identical definition already exists
    final checkStmt = db.prepare(
      'SELECT id FROM definitions WHERE word_id = ? AND menksoft_code = ?',
    );
    final existing = checkStmt.select([wordId, menksoft.trim()]);
    checkStmt.dispose();

    if (existing.isEmpty) {
      // If setting as primary, demote existing primary definitions if needed
      if (isPrimary) {
        db.execute('UPDATE definitions SET is_primary = 0 WHERE word_id = ?', [wordId]);
      }
      db.execute('''
        INSERT INTO definitions (word_id, menksoft_code, explanation, is_primary, verified_by)
        VALUES (?, ?, ?, ?, ?)
      ''', [wordId, menksoft.trim(), explanation?.trim(), isPrimary ? 1 : 0, verifiedBy]);
    }

    return wordId;
  }

  /// Moderator review: Approve suggestion.
  void approveSuggestion(int suggestionId, {String? verifiedBy}) {
    final rows = db.select('SELECT * FROM suggestions WHERE id = ?', [suggestionId]);
    if (rows.isEmpty) return;
    final sug = rows.first;
    final cyrillic = sug['cyrillic'] as String;
    final menksoft = sug['menksoft_code'] as String;
    final context = sug['context'] as String?;

    addWordDefinition(
      cyrillic: cyrillic,
      menksoft: menksoft,
      explanation: context,
      isPrimary: true,
      verifiedBy: verifiedBy,
    );

    db.execute(
      "UPDATE suggestions SET status = 'approved', reviewed_at = CURRENT_TIMESTAMP WHERE id = ?",
      [suggestionId],
    );

    // Also remove from unknown_logs if it was logged
    db.execute('DELETE FROM unknown_logs WHERE cyrillic = ?', [cyrillic.trim().toLowerCase()]);
  }

  /// Moderator review: Reject suggestion.
  void rejectSuggestion(int suggestionId, {String? reason}) {
    db.execute(
      "UPDATE suggestions SET status = 'rejected', moderator_note = ?, reviewed_at = CURRENT_TIMESTAMP WHERE id = ?",
      [reason, suggestionId],
    );
  }

  void close() {
    db.dispose();
  }
}
