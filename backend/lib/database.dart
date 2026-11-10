import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:sqlite3/sqlite3.dart';
import 'cyrillic_validator.dart';

class AppDatabase {
  final Database db;
  bool _inTransaction = false;

  AppDatabase(this.db);

  T _runInTransaction<T>(T Function() action) {
    if (_inTransaction) {
      return action();
    }
    _inTransaction = true;
    db.execute('BEGIN TRANSACTION;');
    try {
      final result = action();
      db.execute('COMMIT;');
      return result;
    } catch (e) {
      db.execute('ROLLBACK;');
      rethrow;
    } finally {
      _inTransaction = false;
    }
  }

  factory AppDatabase.open(String path) {
    final db = sqlite3.open(path);
    // Performance optimizations for SQLite
    db.execute('PRAGMA journal_mode = WAL;');
    db.execute('PRAGMA busy_timeout = 5000;');
    db.execute('PRAGMA synchronous = NORMAL;');
    db.execute('PRAGMA foreign_keys = ON;');
    db.execute('PRAGMA secure_delete = ON;');
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
        explanation TEXT,
        submitted_by TEXT,
        status TEXT DEFAULT 'pending',
        moderator_note TEXT,
        reviewed_by TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        reviewed_at TIMESTAMP
      );
      CREATE INDEX IF NOT EXISTS idx_suggestions_status ON suggestions(status);

      CREATE TABLE IF NOT EXISTS rejected_words (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cyrillic TEXT NOT NULL,
        menksoft_code TEXT,
        reason TEXT NOT NULL,
        details TEXT,
        source TEXT,
        source_id INTEGER,
        submitted_by TEXT,
        reviewed_by TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
      CREATE INDEX IF NOT EXISTS idx_rejected_words_cyrillic ON rejected_words(cyrillic);
      CREATE INDEX IF NOT EXISTS idx_rejected_words_reason ON rejected_words(reason);
    ''');
    try {
      db.execute('ALTER TABLE suggestions ADD COLUMN reviewed_by TEXT;');
    } catch (_) {}
    try {
      db.execute('ALTER TABLE suggestions ADD COLUMN explanation TEXT;');
    } catch (_) {}
    try {
      db.execute('ALTER TABLE suggestions ADD COLUMN comment TEXT;');
    } catch (_) {}
    try {
      db.execute('ALTER TABLE suggestions ADD COLUMN target_menksoft TEXT;');
    } catch (_) {}

    // Normalize cyrillic casing for any existing pending suggestions
    try {
      final pendingRows = db.select(
        "SELECT id, cyrillic FROM suggestions WHERE status = 'pending'",
      );
      for (final row in pendingRows) {
        final rawCyr = row['cyrillic'] as String;
        final normCyr = CyrillicValidator.normalizeWord(rawCyr);
        if (normCyr != rawCyr) {
          db.execute('UPDATE suggestions SET cyrillic = ? WHERE id = ?', [
            normCyr,
            row['id'],
          ]);
        }
      }
    } catch (_) {}

    // Startup auto-cleanup for matching pending suggestions
    try {
      db.execute('''
        UPDATE suggestions
        SET status = 'approved',
            moderator_note = 'auto_resolved',
            context = NULL,
            reviewed_at = CURRENT_TIMESTAMP
        WHERE status = 'pending'
          AND (
            (
              TRIM(menksoft_code) != ''
              AND EXISTS (
                SELECT 1 FROM words w
                JOIN definitions d ON w.id = d.word_id
                WHERE w.cyrillic = suggestions.cyrillic
                  AND d.menksoft_code = suggestions.menksoft_code
              )
            )
            OR (
              submitted_by = 'db_discrepancy_review'
              AND EXISTS (
                SELECT 1 FROM words w
                WHERE w.cyrillic = suggestions.cyrillic
              )
            )
          );
      ''');
    } catch (_) {}
  }

  /// Looks up definitions for a Cyrillic word.
  /// If the word is an abbreviation (e.g. 'МУИС', 'УИХ', 'АН', 'УИХ-ын'), checks exact match first,
  /// then falls back to lowercase match. For regular words, checks lowercase match.
  /// Returns a list of maps: [{'menksoft': '...', 'explanation': '...', 'isDefault': true/false}]
  List<Map<String, dynamic>> lookupWord(String rawWord) {
    final trimmed = rawWord.trim();
    if (trimmed.isEmpty) return [];

    if (CyrillicValidator.isAbbreviation(trimmed)) {
      final exactDefs = _queryDefinitionsByCyrillic(trimmed);
      if (exactDefs.isNotEmpty) return exactDefs;
    }

    return _queryDefinitionsByCyrillic(trimmed.toLowerCase());
  }

  List<Map<String, dynamic>> _queryDefinitionsByCyrillic(String cyrillic) {
    final stmtWord = db.prepare('SELECT id FROM words WHERE cyrillic = ?');
    final wordResult = stmtWord.select([cyrillic]);
    stmtWord.close();

    if (wordResult.isEmpty) return [];

    final wordId = wordResult.first['id'] as int;
    final stmtDef = db.prepare(
      'SELECT menksoft_code, explanation, is_primary FROM definitions WHERE word_id = ? ORDER BY is_primary DESC, id ASC',
    );
    final defResult = stmtDef.select([wordId]);
    stmtDef.close();

    return defResult.map((row) {
      return {
        'menksoft': row['menksoft_code'] as String,
        'explanation': row['explanation'] as String?,
        'isDefault': (row['is_primary'] as int) == 1,
      };
    }).toList();
  }

  /// Logs or increments frequency of an unknown word.
  /// Preserves uppercase casing for abbreviations, normalizes regular words to lowercase.
  void logUnknownWord(String rawWord, {String? context}) {
    final normalized = CyrillicValidator.normalizeWord(rawWord);
    if (normalized.isEmpty) return;

    db.execute(
      '''
      INSERT INTO unknown_logs (cyrillic, frequency, last_context, last_seen)
      VALUES (?, 1, ?, CURRENT_TIMESTAMP)
      ON CONFLICT(cyrillic) DO UPDATE SET
        frequency = frequency + 1,
        last_context = COALESCE(?, last_context),
        last_seen = CURRENT_TIMESTAMP;
    ''',
      [normalized, context, context],
    );
  }

  /// Adds a user suggestion with separate usage context and word explanation.
  void addSuggestion({
    required String cyrillic,
    required String menksoft,
    String? context,
    String? explanation,
    String? comment,
    String? targetMenksoft,
    String? submittedBy,
  }) {
    final normalized = CyrillicValidator.normalizeWord(cyrillic);
    final cleanContext = (context != null && context.trim().isNotEmpty)
        ? context.trim()
        : null;
    final cleanExplanation =
        (explanation != null && explanation.trim().isNotEmpty)
        ? explanation.trim()
        : null;
    final cleanComment = (comment != null && comment.trim().isNotEmpty)
        ? comment.trim()
        : null;
    final cleanTarget =
        (targetMenksoft != null && targetMenksoft.trim().isNotEmpty)
        ? targetMenksoft.trim()
        : null;
    db.execute(
      '''
      INSERT INTO suggestions (cyrillic, menksoft_code, context, explanation, comment, target_menksoft, submitted_by)
      VALUES (?, ?, ?, ?, ?, ?, ?)
    ''',
      [
        normalized.isNotEmpty ? normalized : cyrillic.trim(),
        menksoft.trim(),
        cleanContext,
        cleanExplanation,
        cleanComment,
        cleanTarget,
        submittedBy,
      ],
    );
  }

  /// Gets the top unknown words ordered by frequency, optionally filtered by minimum frequency.
  List<Map<String, dynamic>> getTopUnknownWords({
    int limit = 100,
    int minFrequency = 1,
  }) {
    final safeLimit = limit.clamp(1, 200);
    final results = db.select(
      'SELECT id, cyrillic, frequency, last_context, last_seen FROM unknown_logs WHERE frequency >= ? ORDER BY frequency DESC, last_seen DESC LIMIT ?',
      [minFrequency, safeLimit],
    );
    return results.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  /// Gets pending suggestions for moderator review.
  List<Map<String, dynamic>> getPendingSuggestions({int limit = 100}) {
    final safeLimit = limit.clamp(1, 200);
    final results = db.select(
      '''
      SELECT id, cyrillic, menksoft_code, context, explanation, comment, target_menksoft, submitted_by, created_at
      FROM suggestions
      WHERE status = 'pending'
      ORDER BY
        CASE
          WHEN submitted_by = 'db_discrepancy_review' THEN 0
          WHEN COALESCE(submitted_by, '') != 'eck_import'
               AND (COALESCE(comment, '') != '' OR COALESCE(target_menksoft, '') != '') THEN 1
          WHEN COALESCE(submitted_by, '') != 'eck_import' THEN 2
          ELSE 3
        END ASC,
        created_at ASC,
        id ASC
      LIMIT ?
      ''',
      [safeLimit],
    );
    return results.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  /// Returns total count of pending suggestions.
  int getPendingSuggestionsCount() {
    final row = db.select(
      "SELECT count(*) as count FROM suggestions WHERE status = 'pending';",
    );
    return row.first['count'] as int;
  }

  void _autoResolveMatchingSuggestions(String cyrillic, String menksoft) {
    final normalized = CyrillicValidator.normalizeWord(cyrillic);
    final rawTrimmed = cyrillic.trim();
    final cleanMenksoft = menksoft.trim();

    db.execute(
      '''
      UPDATE suggestions
      SET status = 'approved',
          moderator_note = 'auto_resolved',
          context = NULL,
          reviewed_at = CURRENT_TIMESTAMP
      WHERE status = 'pending'
        AND (
          (
            cyrillic IN (?, ?)
            AND TRIM(menksoft_code) = ?
            AND TRIM(menksoft_code) != ''
          )
          OR (
            cyrillic IN (?, ?)
            AND submitted_by = 'db_discrepancy_review'
          )
        )
      ''',
      [normalized, rawTrimmed, cleanMenksoft, normalized, rawTrimmed],
    );
  }

  /// Adds or updates a word and definition. Returns word_id.
  int addWordDefinition({
    required String cyrillic,
    required String menksoft,
    String? explanation,
    bool isPrimary = true,
    String? verifiedBy,
  }) {
    return _runInTransaction(() {
      final normalized = CyrillicValidator.normalizeWord(cyrillic);
      final cleanMenksoft = menksoft.trim();

      final stmtWord = db.prepare(
        'INSERT OR IGNORE INTO words (cyrillic) VALUES (?)',
      );
      stmtWord.execute([normalized]);
      stmtWord.close();

      final stmtGetId = db.prepare('SELECT id FROM words WHERE cyrillic = ?');
      final wordRow = stmtGetId.select([normalized]);
      stmtGetId.close();
      final wordId = wordRow.first['id'] as int;

      final countRow = db.select(
        'SELECT count(*) as count FROM definitions WHERE word_id = ?;',
        [wordId],
      );
      final existingDefCount = countRow.first['count'] as int;
      final effectiveIsPrimary = (existingDefCount == 0) ? true : isPrimary;

      // Check if identical definition already exists
      final checkStmt = db.prepare(
        'SELECT id, is_primary, explanation FROM definitions WHERE word_id = ? AND menksoft_code = ?',
      );
      final existing = checkStmt.select([wordId, cleanMenksoft]);
      checkStmt.close();

      if (existing.isEmpty) {
        if (effectiveIsPrimary) {
          db.execute(
            'UPDATE definitions SET is_primary = 0 WHERE word_id = ?',
            [wordId],
          );
        }
        db.execute(
          '''
          INSERT INTO definitions (word_id, menksoft_code, explanation, is_primary, verified_by)
          VALUES (?, ?, ?, ?, ?)
        ''',
          [
            wordId,
            cleanMenksoft,
            explanation?.trim(),
            effectiveIsPrimary ? 1 : 0,
            verifiedBy,
          ],
        );
      } else {
        final defId = existing.first['id'] as int;
        if (isPrimary) {
          db.execute(
            'UPDATE definitions SET is_primary = 0 WHERE word_id = ?',
            [wordId],
          );
          db.execute('UPDATE definitions SET is_primary = 1 WHERE id = ?', [
            defId,
          ]);
        }
        if (explanation != null && explanation.trim().isNotEmpty) {
          db.execute('UPDATE definitions SET explanation = ? WHERE id = ?', [
            explanation.trim(),
            defId,
          ]);
        }
      }

      _autoResolveMatchingSuggestions(normalized, cleanMenksoft);
      return wordId;
    });
  }

  /// Replaces an existing definition for a word with a new spelling in place.
  void replaceDefinition({
    required String cyrillic,
    required String targetMenksoft,
    required String newMenksoft,
    String? explanation,
    bool? isPrimary,
    String? verifiedBy,
  }) {
    _runInTransaction(() {
      final normalized = CyrillicValidator.normalizeWord(cyrillic);
      final cleanNew = newMenksoft.trim();
      var cleanTarget = targetMenksoft.trim();

      final wordRows = db.select('SELECT id FROM words WHERE cyrillic = ?', [
        normalized,
      ]);
      if (wordRows.isEmpty) {
        addWordDefinition(
          cyrillic: normalized,
          menksoft: cleanNew,
          explanation: explanation,
          isPrimary: isPrimary ?? true,
          verifiedBy: verifiedBy,
        );
        return;
      }
      final wordId = wordRows.first['id'] as int;

      final allDefs = db.select(
        'SELECT id, menksoft_code, is_primary, explanation FROM definitions WHERE word_id = ? ORDER BY id ASC',
        [wordId],
      );
      if (allDefs.isEmpty) {
        addWordDefinition(
          cyrillic: normalized,
          menksoft: cleanNew,
          explanation: explanation,
          isPrimary: isPrimary ?? true,
          verifiedBy: verifiedBy,
        );
        return;
      }

      // If target_menksoft is empty and word has exactly 1 definition, target that single definition
      if (cleanTarget.isEmpty && allDefs.length == 1) {
        cleanTarget = allDefs.first['menksoft_code'] as String;
      }

      final targetMatches = allDefs
          .where((d) => (d['menksoft_code'] as String).trim() == cleanTarget)
          .toList();
      if (targetMatches.isEmpty) {
        addWordDefinition(
          cyrillic: normalized,
          menksoft: cleanNew,
          explanation: explanation,
          isPrimary: isPrimary ?? true,
          verifiedBy: verifiedBy,
        );
        return;
      }

      final targetDef = targetMatches.first;
      final targetDefId = targetDef['id'] as int;
      final targetWasPrimary = (targetDef['is_primary'] as int) == 1;

      // Check if newMenksoft already exists on another row for word_id
      final otherWithNew = allDefs
          .where(
            (d) =>
                (d['menksoft_code'] as String).trim() == cleanNew &&
                (d['id'] as int) != targetDefId,
          )
          .toList();

      if (otherWithNew.isNotEmpty) {
        final survivingDef = otherWithNew.first;
        final survivingDefId = survivingDef['id'] as int;
        final survivingWasPrimary = (survivingDef['is_primary'] as int) == 1;
        final shouldBePrimary =
            isPrimary ?? (targetWasPrimary || survivingWasPrimary);

        db.execute('DELETE FROM definitions WHERE id = ?', [targetDefId]);

        if (shouldBePrimary) {
          db.execute(
            'UPDATE definitions SET is_primary = 0 WHERE word_id = ?',
            [wordId],
          );
          db.execute('UPDATE definitions SET is_primary = 1 WHERE id = ?', [
            survivingDefId,
          ]);
        }
        if (explanation != null && explanation.trim().isNotEmpty) {
          db.execute(
            'UPDATE definitions SET explanation = ?, verified_by = COALESCE(?, verified_by) WHERE id = ?',
            [explanation.trim(), verifiedBy, survivingDefId],
          );
        } else if (verifiedBy != null) {
          db.execute('UPDATE definitions SET verified_by = ? WHERE id = ?', [
            verifiedBy,
            survivingDefId,
          ]);
        }
      } else {
        final shouldBePrimary = isPrimary ?? targetWasPrimary;
        if (shouldBePrimary) {
          db.execute(
            'UPDATE definitions SET is_primary = 0 WHERE word_id = ?',
            [wordId],
          );
        }
        db.execute(
          '''
          UPDATE definitions
          SET menksoft_code = ?,
              explanation = COALESCE(?, explanation),
              is_primary = ?,
              verified_by = COALESCE(?, verified_by)
          WHERE id = ?
          ''',
          [
            cleanNew,
            (explanation != null && explanation.trim().isNotEmpty)
                ? explanation.trim()
                : null,
            shouldBePrimary ? 1 : 0,
            verifiedBy,
            targetDefId,
          ],
        );
      }

      // Ensure exactly one primary definition if definitions remain
      final remainingDefs = db.select(
        'SELECT id, is_primary FROM definitions WHERE word_id = ? ORDER BY id ASC',
        [wordId],
      );
      if (remainingDefs.isNotEmpty &&
          !remainingDefs.any((d) => (d['is_primary'] as int) == 1)) {
        db.execute('UPDATE definitions SET is_primary = 1 WHERE id = ?', [
          remainingDefs.first['id'] as int,
        ]);
      }

      _autoResolveMatchingSuggestions(normalized, cleanNew);
    });
  }

  /// Deletes a specific definition for a word. Returns true if deleted.
  bool deleteDefinition({required String cyrillic, required String menksoft}) {
    return _runInTransaction(() {
      final normalized = CyrillicValidator.normalizeWord(cyrillic);
      final cleanMenksoft = menksoft.trim();

      final wordRows = db.select('SELECT id FROM words WHERE cyrillic = ?', [
        normalized,
      ]);
      if (wordRows.isEmpty) {
        return false;
      }
      final wordId = wordRows.first['id'] as int;

      final defRows = db.select(
        'SELECT id, is_primary FROM definitions WHERE word_id = ? AND menksoft_code = ?',
        [wordId, cleanMenksoft],
      );
      if (defRows.isEmpty) {
        return false;
      }

      final defToDelete = defRows.first;
      final defId = defToDelete['id'] as int;
      final wasPrimary = (defToDelete['is_primary'] as int) == 1;

      db.execute('DELETE FROM definitions WHERE id = ?', [defId]);

      final remaining = db.select(
        'SELECT id, is_primary FROM definitions WHERE word_id = ? ORDER BY id ASC',
        [wordId],
      );

      if (remaining.isEmpty) {
        db.execute('DELETE FROM words WHERE id = ?', [wordId]);
      } else if (wasPrimary) {
        final oldestId = remaining.first['id'] as int;
        db.execute('UPDATE definitions SET is_primary = 1 WHERE id = ?', [
          oldestId,
        ]);
      }

      return true;
    });
  }

  /// Sets a specific definition as primary and demotes all others for the word.
  bool setPrimaryDefinition({
    required String cyrillic,
    required String menksoft,
  }) {
    return _runInTransaction(() {
      final normalized = CyrillicValidator.normalizeWord(cyrillic);
      final cleanMenksoft = menksoft.trim();

      final wordRows = db.select('SELECT id FROM words WHERE cyrillic = ?', [
        normalized,
      ]);
      if (wordRows.isEmpty) {
        return false;
      }
      final wordId = wordRows.first['id'] as int;

      final targetDef = db.select(
        'SELECT id FROM definitions WHERE word_id = ? AND menksoft_code = ?',
        [wordId, cleanMenksoft],
      );
      if (targetDef.isEmpty) {
        return false;
      }

      db.execute('UPDATE definitions SET is_primary = 0 WHERE word_id = ?', [
        wordId,
      ]);
      db.execute('UPDATE definitions SET is_primary = 1 WHERE id = ?', [
        targetDef.first['id'] as int,
      ]);
      return true;
    });
  }

  /// Moderator review: Approve suggestion.
  void approveSuggestion(
    int suggestionId, {
    String? verifiedBy,
    String? cyrillic,
    String? menksoft,
    String? explanation,
    String action = 'add_primary',
    String? targetMenksoft,
  }) {
    _runInTransaction(() {
      final rows = db.select('SELECT * FROM suggestions WHERE id = ?', [
        suggestionId,
      ]);
      if (rows.isEmpty) {
        return;
      }
      final sug = rows.first;
      final finalCyrillic = (cyrillic != null && cyrillic.trim().isNotEmpty)
          ? cyrillic.trim()
          : (sug['cyrillic'] as String);
      final finalMenksoft = (menksoft != null && menksoft.trim().isNotEmpty)
          ? menksoft.trim()
          : (sug['menksoft_code'] as String);
      final rawExplanation = explanation ?? (sug['explanation'] as String?);
      final finalExplanation =
          (rawExplanation != null && rawExplanation.trim().isNotEmpty)
          ? rawExplanation.trim()
          : null;
      final finalTargetMenksoft =
          (targetMenksoft != null && targetMenksoft.trim().isNotEmpty)
          ? targetMenksoft.trim()
          : (sug['target_menksoft'] as String?)?.trim();

      switch (action) {
        case 'add_primary':
          addWordDefinition(
            cyrillic: finalCyrillic,
            menksoft: finalMenksoft,
            explanation: finalExplanation,
            isPrimary: true,
            verifiedBy: verifiedBy,
          );
          break;
        case 'add_secondary':
          addWordDefinition(
            cyrillic: finalCyrillic,
            menksoft: finalMenksoft,
            explanation: finalExplanation,
            isPrimary: false,
            verifiedBy: verifiedBy,
          );
          break;
        case 'replace':
          replaceDefinition(
            cyrillic: finalCyrillic,
            targetMenksoft: finalTargetMenksoft ?? '',
            newMenksoft: finalMenksoft,
            explanation: finalExplanation,
            verifiedBy: verifiedBy,
          );
          break;
        case 'resolve_only':
          // Close report without modifying dictionary entries
          break;
        default:
          addWordDefinition(
            cyrillic: finalCyrillic,
            menksoft: finalMenksoft,
            explanation: finalExplanation,
            isPrimary: true,
            verifiedBy: verifiedBy,
          );
          break;
      }

      db.execute(
        "UPDATE suggestions SET status = 'approved', cyrillic = ?, menksoft_code = ?, context = NULL, explanation = ?, target_menksoft = ?, moderator_note = ?, reviewed_by = ?, reviewed_at = CURRENT_TIMESTAMP WHERE id = ?",
        [
          finalCyrillic,
          finalMenksoft,
          finalExplanation,
          finalTargetMenksoft,
          action,
          verifiedBy,
          suggestionId,
        ],
      );

      // Only remove from unknown_logs when a definition was added or replaced
      if (action != 'resolve_only') {
        db.execute(
          'DELETE FROM unknown_logs WHERE cyrillic = ? OR cyrillic = ?',
          [finalCyrillic.trim(), finalCyrillic.trim().toLowerCase()],
        );
      }
    });
  }

  /// Records a rejected word into the rejected_words table for future study.
  void logRejectedWord({
    required String cyrillic,
    String? menksoft,
    required String reason,
    String? details,
    String? source,
    int? sourceId,
    String? submittedBy,
    String? reviewedBy,
  }) {
    db.execute(
      '''
      INSERT INTO rejected_words (cyrillic, menksoft_code, reason, details, source, source_id, submitted_by, reviewed_by)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ''',
      [
        cyrillic.trim(),
        menksoft?.trim(),
        reason.trim(),
        details?.trim(),
        source,
        sourceId,
        submittedBy,
        reviewedBy,
      ],
    );
  }

  /// Moderator review: Reject suggestion and log to rejected_words table.
  void rejectSuggestion(
    int suggestionId, {
    String? reason,
    String? reviewedBy,
  }) {
    final rows = db.select('SELECT * FROM suggestions WHERE id = ?', [
      suggestionId,
    ]);
    if (rows.isNotEmpty) {
      final sug = rows.first;
      logRejectedWord(
        cyrillic: sug['cyrillic'] as String,
        menksoft: sug['menksoft_code'] as String?,
        reason: reason ?? 'rejected',
        details: sug['explanation'] as String?,
        source: 'suggestion',
        sourceId: suggestionId,
        submittedBy: sug['submitted_by'] as String?,
        reviewedBy: reviewedBy,
      );
    }

    db.execute(
      "UPDATE suggestions SET status = 'rejected', context = NULL, moderator_note = ?, reviewed_by = ?, reviewed_at = CURRENT_TIMESTAMP WHERE id = ?",
      [reason, reviewedBy, suggestionId],
    );
  }

  /// Moderator review: Reject missing word from unknown_logs and log to rejected_words table.
  void rejectMissingWord(
    String cyrillic, {
    required String reason,
    String? reviewedBy,
  }) {
    final normalized = CyrillicValidator.normalizeWord(cyrillic);

    logRejectedWord(
      cyrillic: normalized,
      reason: reason,
      details: null,
      source: 'unknown_log',
      reviewedBy: reviewedBy,
    );

    db.execute('DELETE FROM unknown_logs WHERE cyrillic = ? OR cyrillic = ?', [
      normalized,
      normalized.toLowerCase(),
    ]);
  }

  /// Returns previous rejections for a word from rejected_words for informational display.
  List<Map<String, dynamic>> getRejectionHistory(String cyrillic) {
    final trimmed = cyrillic.trim();
    if (trimmed.isEmpty) return [];
    final results = db.select(
      'SELECT id, cyrillic, menksoft_code, reason, details, reviewed_by, created_at FROM rejected_words WHERE cyrillic = ? OR LOWER(cyrillic) = ? ORDER BY created_at DESC',
      [trimmed, trimmed.toLowerCase()],
    );
    return results.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  /// Returns total count of words in the database.
  int getWordCount() {
    final row = db.select('SELECT count(*) as count FROM words;');
    return row.first['count'] as int;
  }

  /// Creates an atomic SQLite backup snapshot using VACUUM INTO.
  void createBackupSnapshot(String destinationPath) {
    final file = File(destinationPath);
    if (file.existsSync()) {
      file.deleteSync();
    }
    db.execute('VACUUM INTO ?', [destinationPath]);
  }

  /// Returns all approved words and definitions as a JSON-serializable list.
  List<Map<String, dynamic>> getApprovedWordsJson() {
    final rows = db.select('''
      SELECT w.cyrillic, d.menksoft_code, d.explanation, d.is_primary
      FROM words w
      JOIN definitions d ON w.id = d.word_id
      ORDER BY w.cyrillic ASC, d.is_primary DESC;
    ''');
    return rows
        .map(
          (r) => {
            'cyrillic': r['cyrillic'],
            'menksoft': r['menksoft_code'],
            'explanation': r['explanation'],
            'isPrimary': (r['is_primary'] as int) == 1,
          },
        )
        .toList();
  }

  /// Returns all records across all tables as a JSON-serializable Map.
  Map<String, dynamic> getFullDatabaseJson() {
    final words = db.select(
      'SELECT id, cyrillic, is_abbreviation, created_at FROM words ORDER BY id ASC;',
    );
    final definitions = db.select(
      'SELECT id, word_id, menksoft_code, explanation, is_primary, verified_by, created_at FROM definitions ORDER BY id ASC;',
    );
    final unknownLogs = db.select(
      'SELECT id, cyrillic, frequency, last_context, first_seen, last_seen FROM unknown_logs ORDER BY frequency DESC;',
    );
    final suggestions = db.select(
      'SELECT id, cyrillic, menksoft_code, context, explanation, comment, target_menksoft, submitted_by, status, moderator_note, reviewed_by, created_at, reviewed_at FROM suggestions ORDER BY id ASC;',
    );
    final rejectedWords = db.select(
      'SELECT id, cyrillic, menksoft_code, reason, details, source, source_id, submitted_by, reviewed_by, created_at FROM rejected_words ORDER BY id ASC;',
    );

    return {
      'exported_at': DateTime.now().toIso8601String(),
      'words': words.map((r) => Map<String, dynamic>.from(r)).toList(),
      'definitions': definitions
          .map((r) => Map<String, dynamic>.from(r))
          .toList(),
      'unknown_logs': unknownLogs
          .map((r) => Map<String, dynamic>.from(r))
          .toList(),
      'suggestions': suggestions
          .map((r) => Map<String, dynamic>.from(r))
          .toList(),
      'rejected_words': rejectedWords
          .map((r) => Map<String, dynamic>.from(r))
          .toList(),
    };
  }

  /// Seeds or syncs data from the old PocketBase collection into SQLite.
  /// Returns a map with summary counts: {'imported': N, 'skipped': M, 'total': Total}
  Future<Map<String, int>> seedFromOldApp({
    String baseUrl =
        'https://cyrillic.suragch.dev/api/collections/words/records',
    void Function(String message)? onProgress,
  }) async {
    int page = 1;
    const perPage = 500;
    int totalImported = 0;
    int totalSkipped = 0;
    int totalItems = 0;

    while (true) {
      final url = Uri.parse('$baseUrl?page=$page&perPage=$perPage');
      onProgress?.call('Fetching page $page...');
      final response = await http.get(url).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        throw Exception('Failed to fetch page $page: ${response.statusCode}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final List<dynamic> items = data['items'] as List<dynamic>? ?? [];
      final int totalPages = data['totalPages'] as int? ?? 1;
      totalItems = data['totalItems'] as int? ?? 0;

      if (items.isEmpty) break;

      db.execute('BEGIN TRANSACTION;');
      try {
        for (final item in items) {
          final cyrillic = (item['cyrillic'] as String?)?.trim();
          final mongol = (item['mongol'] as String?)?.trim();

          if (cyrillic == null ||
              cyrillic.isEmpty ||
              mongol == null ||
              mongol.isEmpty) {
            totalSkipped++;
            continue;
          }

          final normalized = CyrillicValidator.normalizeWord(cyrillic);

          // 1. Insert word
          db.execute('INSERT OR IGNORE INTO words (cyrillic) VALUES (?);', [
            normalized,
          ]);

          // 2. Get word id
          final row = db.select(
            'SELECT id FROM words WHERE cyrillic = ? LIMIT 1;',
            [normalized],
          );
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
            final countRow = db.select(
              'SELECT count(*) as count FROM definitions WHERE word_id = ?;',
              [wordId],
            );
            final existingCount = countRow.first['count'] as int;
            final isPrimary = existingCount == 0 ? 1 : 0;

            db.execute(
              '''
              INSERT INTO definitions (word_id, menksoft_code, is_primary, verified_by)
              VALUES (?, ?, ?, 'migrated');
            ''',
              [wordId, mongol, isPrimary],
            );
            totalImported++;
          }
        }
        db.execute('COMMIT;');
      } catch (e) {
        db.execute('ROLLBACK;');
        rethrow;
      }

      onProgress?.call('Imported $totalImported / $totalItems items...');
      if (page >= totalPages) break;
      page++;
    }

    return {
      'imported': totalImported,
      'skipped': totalSkipped,
      'total': totalItems,
    };
  }

  void close() {
    db.close();
  }
}
