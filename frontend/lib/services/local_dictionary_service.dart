import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/local_word_entry.dart';
import 'latin_ime.dart';

/// Client-side persistent storage repository for user-contributed dictionary entries.
///
/// Uses an in-memory map for synchronous O(1) lookups during text conversion
/// backed by SharedPreferences persistence with sequential Future serialization.
class LocalDictionaryService extends ChangeNotifier {
  static const String storageKey = 'cyrillic_converter_local_words';

  static final LocalDictionaryService instance = LocalDictionaryService._();

  LocalDictionaryService._();

  final Map<String, LocalWordEntry> _entries = <String, LocalWordEntry>{};
  List<LocalWordEntry> _sortedWords = <LocalWordEntry>[];
  Future<void> _persistLock = Future<void>.value();
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  /// Returns an unmodifiable snapshot of local word entries sorted by creation date descending.
  List<LocalWordEntry> get allWords =>
      List<LocalWordEntry>.unmodifiable(_sortedWords);

  int get count => _entries.length;

  /// Initializes the service by reading saved words from [SharedPreferences].
  Future<void> initialize({SharedPreferences? preferences}) async {
    try {
      final prefs = preferences ?? await SharedPreferences.getInstance();
      final raw = prefs.getString(storageKey);
      _entries.clear();

      if (raw != null && raw.isNotEmpty) {
        final dynamic decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map<String, dynamic>) {
              final entry = LocalWordEntry.fromJson(item);
              final norm = LatinIme.normalizeCyrillic(entry.cyrillic);
              if (norm.isNotEmpty) {
                _entries[norm] = entry;
              }
            }
          }
        }
      }
      _rebuildSortedWords();
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('LocalDictionaryService initialization error: $e');
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Synchronously checks if a word exists in the local dictionary.
  bool hasWord(String cyrillic) {
    return _entries.containsKey(LatinIme.normalizeCyrillic(cyrillic));
  }

  /// Synchronously retrieves a word entry by its Cyrillic root.
  LocalWordEntry? getWord(String cyrillic) {
    return _entries[LatinIme.normalizeCyrillic(cyrillic)];
  }

  /// Upserts a local word definition, updates memory, and enqueues sequential persistence.
  Future<bool> addOrUpdateWord({
    required String cyrillic,
    required String menksoft,
    String? explanation,
  }) async {
    final norm = LatinIme.normalizeCyrillic(cyrillic);
    if (norm.isEmpty) {
      return false;
    }

    final entry = LocalWordEntry(
      cyrillic: cyrillic.trim(),
      menksoft: menksoft.trim(),
      explanation: explanation?.trim().isEmpty == true
          ? null
          : explanation?.trim(),
      createdAt: DateTime.now(),
    );

    _entries[norm] = entry;
    _rebuildSortedWords();
    notifyListeners();

    return _persist();
  }

  /// Deletes a local word definition by its Cyrillic root.
  Future<bool> deleteWord(String cyrillic) async {
    final norm = LatinIme.normalizeCyrillic(cyrillic);
    if (_entries.remove(norm) != null) {
      _rebuildSortedWords();
      notifyListeners();
      return _persist();
    }
    return true;
  }

  /// Batch removes multiple words from the local store (e.g. during conversion reconciliation).
  Future<bool> purgeWords(Iterable<String> cyrillicWords) async {
    var changed = false;
    for (final word in cyrillicWords) {
      final norm = LatinIme.normalizeCyrillic(word);
      if (_entries.remove(norm) != null) {
        changed = true;
      }
    }

    if (changed) {
      _rebuildSortedWords();
      notifyListeners();
      return _persist();
    }
    return true;
  }

  /// Clears all local words from memory and storage.
  Future<bool> clearAll() async {
    if (_entries.isNotEmpty) {
      _entries.clear();
      _rebuildSortedWords();
      notifyListeners();
      return _persist();
    }
    return true;
  }

  void _rebuildSortedWords() {
    _sortedWords = _entries.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// Serializes disk writes using a sequential Future chain to eliminate race conditions.
  Future<bool> _persist() {
    _persistLock = _persistLock.then((_) async {
      try {
        final raw = jsonEncode(_entries.values.map((e) => e.toJson()).toList());
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(storageKey, raw);
      } catch (e) {
        debugPrint('LocalDictionaryService persist error: $e');
        rethrow;
      }
    });

    return _persistLock.then(
      (_) => true,
      onError: (Object error) {
        debugPrint('LocalDictionaryService persist failed: $error');
        return false;
      },
    );
  }
}
