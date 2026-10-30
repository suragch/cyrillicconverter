# Implementation Specification: Idempotent Conversion, State Preservation, and Telemetry Deduplication

**Target Files**:
1. `backend/bin/server.dart`
2. `frontend/lib/main.dart`

**Objective**: Eliminate destructive state resets on repeated conversions, preserve manual homonym selections across both identical and edited text re-runs, prevent UI scroll resets/flashing during conversion, and deduplicate `unknown_logs` frequency increments on the backend.

---

## Step 1: Backend Unknown-Word Telemetry Deduplication (`backend/bin/server.dart`)

Currently, `_convertHandler` calls `_db.logUnknownWord(...)` inside the token loop. This increments `frequency` multiple times if an unknown word appears multiple times in a single document, or if a client repeatedly submits the same text.

### Instructions for Agent:

1. **Add an in-memory sliding-window cache** at the top/class level of `backend/bin/server.dart`:
   ```dart
   /// Tracks recently logged unknown words per client to prevent frequency spam.
   /// Key format: "$clientKey:$normalizedCyrillic" -> Value: UTC timestamp of last DB log.
   final Map<String, DateTime> _recentUnknownWordLogs = {};
   const Duration _unknownWordDedupWindow = Duration(minutes: 30);

   bool _shouldLogUnknownWord(String clientKey, String normalizedCyrillic) {
     final now = DateTime.now().toUtc();

     // Prevent unbounded memory growth
     if (_recentUnknownWordLogs.length > 10000) {
       _recentUnknownWordLogs.removeWhere(
         (_, timestamp) => now.difference(timestamp) > _unknownWordDedupWindow,
       );
     }

     final cacheKey = '$clientKey:$normalizedCyrillic';
     final lastLogged = _recentUnknownWordLogs[cacheKey];

     if (lastLogged != null && now.difference(lastLogged) < _unknownWordDedupWindow) {
       return false;
     }

     _recentUnknownWordLogs[cacheKey] = now;
     return true;
   }
   ```

2. **Extract the client identifier in `_convertHandler(Request request)`**:
   Read the `x-session-id` header sent by the client. If absent, fall back to the `x-forwarded-for` header or `'anonymous'`:
   ```dart
   final clientKey = request.headers['x-session-id']?.trim().isNotEmpty == true
       ? request.headers['x-session-id']!.trim()
       : (request.headers['x-forwarded-for'] ?? 'anonymous');
   ```

3. **Deduplicate unknown words per request and check the sliding window**:
   Before iterating over the tokens in `_convertHandler`, create a per-request set:
   ```dart
   final Set<String> loggedInThisRequest = {};
   ```
   Inside the token loop where `CyrillicValidator.isCyrillicWord(token.text)` is checked for unknown words, replace the direct `_db.logUnknownWord(...)` call with:
   ```dart
   if (CyrillicValidator.isCyrillicWord(token.text)) {
     final normalized = token.text.trim().toLowerCase();
     // 1. Ensure a word repeated 5 times in one essay only counts once per request.
     // 2. Ensure repeated clicks within 30 minutes from the same session don't increment frequency.
     if (loggedInThisRequest.add(normalized) &&
         _shouldLogUnknownWord(clientKey, normalized)) {
       _db.logUnknownWord(token.text, context: contextSnippet);
     }
   }
   ```

---

## Step 2: Frontend Session Tracking & Dirty-State Management (`frontend/lib/main.dart`)

### Instructions for Agent:

1. **Add state fields to the main State class in `frontend/lib/main.dart`**:
   ```dart
   import 'dart:math';

   // Unique session ID generated once per app launch for backend deduplication
   late final String _sessionId = _generateSessionId();

   // Stores the exact trimmed text of the last successful conversion
   String? _lastConvertedText;

   static String _generateSessionId() {
     final random = Random();
     final values = List<int>.generate(16, (_) => random.nextInt(256));
     return values.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
   }

   /// Returns true if the current input text differs from the last successfully converted text,
   /// or if the last conversion resulted in an error.
   bool get _isConversionDirty {
     final currentText = _inputTextController.text.trim();
     if (currentText.isEmpty) return false;
     if (_errorMessage != null) return true;
     return currentText != _lastConvertedText;
   }
   ```

2. **Listen to `_inputTextController` changes to update button UI**:
   In `initState()`, attach a listener to `_inputTextController` so the Convert button rebuilds when the user edits the text:
   ```dart
   @override
   void initState() {
     super.initState();
     _inputTextController.addListener(_onInputTextChanged);
     // keep existing initState logic...
   }

   void _onInputTextChanged() {
     // Only trigger a rebuild if the dirty state might have flipped
     setState(() {});
   }

   @override
   void dispose() {
     _inputTextController.removeListener(_onInputTextChanged);
     // keep existing dispose logic...
   }
   ```

---

## Step 3: Non-Destructive `_convert()` & Optimistic Token Retention (`frontend/lib/main.dart`)

Do **not** clear `_tokens`, `_tokenSpanInfos`, or `_selectedOptionIndices` before `await http.post(...)`. Clearing them collapses the scrollable area to `0.0` (resetting scroll offset) and causes a blank screen flash.

### Instructions for Agent:

1. **Update the signature of `_convert()` to accept `{bool force = false}`**:
   ```dart
   Future<void> _convert({bool force = false}) async {
     final text = _inputTextController.text.trim();
     if (text.isEmpty) return;

     // Guard: If already loading, ignore.
     if (_isLoading) return;

     // Guard: If text has not changedsince last successful conversion and force is false, no-op.
     if (!force && !_isConversionDirty) {
       return;
     }

     setState(() {
       _isLoading = true;
       _errorMessage = null;
       // DO NOT clear _tokens, _tokenSpanInfos, or _selectedOptionIndices here!
     });

     try {
       final response = await http.post(
         Uri.parse('$_serverUrl/convert'),
         headers: {
           'Content-Type': 'application/json',
           'X-Session-ID': _sessionId,
         },
         body: jsonEncode({'text': text}),
       );

       if (response.statusCode == 200) {
         // Parse the new tokens from response (use existing token parsing logic)
         final List<dynamic> rawTokens = jsonDecode(utf8.decode(response.bodyBytes))['tokens'];
         final newTokens = ...; // existing mapping to your Token model/map

         // Reconcile homonym selections between old _tokens and newTokens (defined in Step 4)
         final reconciledSelections = _reconcileHomonymSelections(
           oldTokens: _tokens,
           newTokens: newTokens,
           oldSelections: _selectedOptionIndices,
         );

         setState(() {
           _tokens = newTokens;
           _selectedOptionIndices
             ..clear()
             ..addAll(reconciledSelections);
           _lastConvertedText = text;
           _isLoading = false;
           // Rebuild _tokenSpanInfos here if it is derived synchronously, or let build() handle it
         });
       } else {
         setState(() {
           _isLoading = false;
           _errorMessage = 'Алдаа гарлаа: ${response.statusCode}';
         });
       }
     } catch (e) {
       setState(() {
         _isLoading = false;
         _errorMessage = 'Сервертэй холбогдож чадсангүй';
       });
     }
   }
   ```

2. **Keep existing tokens visible while `_isLoading == true`**:
   In the `build()` method where the output preview pane is rendered:
   * Previously, it likely checked `if (_isLoading) return CircularProgressIndicator();`.
   * **Change this** so that if `_tokens.isEmpty && _isLoading`, it shows the centered `CircularProgressIndicator()`.
   * If `_tokens.isNotEmpty`, keep rendering the vertical script preview pane (so its `ScrollController` remains attached and keeps its scroll position), wrapped in a `Stack` or `AnimatedOpacity` (opacity `0.6` when `_isLoading` is true) with a `LinearProgressIndicator(minHeight: 2)` aligned at the top of the preview pane.

---

## Step 4: Context-Aware Homonym Selection Reconciliation (`frontend/lib/main.dart`)

When `newTokens` arrive from the server, we must preserve the user's previous homonym choices—even if the user inserted/deleted words earlier in the text or refreshed after adding a word to the dictionary.

### Instructions for Agent:

Add the `_reconcileHomonymSelections` method to the State class in `frontend/lib/main.dart`. Adjust property accessors (`token['cyrillic']` or `token.text`, `token['options']` or `token.options`) to match the exact token data structure in `main.dart`:

```dart
/// Reconciles user homonym selections across re-conversions.
/// Works for both identical text refreshes and edited texts (insertions/deletions).
Map<int, int> _reconcileHomonymSelections({
  required List<dynamic> oldTokens,
  required List<dynamic> newTokens,
  required Map<int, int> oldSelections,
}) {
  if (oldSelections.isEmpty || oldTokens.isEmpty || newTokens.isEmpty) {
    return {};
  }

  // Helper to extract normalized Cyrillic text from a token
  String getCyrillic(dynamic token) {
    // Adapt to your token structure (e.g., token.text or token['text'] or token['cyrillic'])
    final raw = (token is Map ? (token['text'] ?? token['cyrillic']) : token.text) as String? ?? '';
    return raw.trim().toLowerCase();
  }

  // Helper to extract the list of traditional script candidate strings/objects from a token
  List<dynamic> getOptions(dynamic token) {
    // Adapt to your token structure (e.g., token.options or token['options'] or token['candidates'])
    return (token is Map ? (token['options'] ?? token['candidates']) : token.options) as List<dynamic>? ?? const [];
  }

  // Helper to extract the unique traditional script string from an option item
  String getOptionValue(dynamic option) {
    if (option is String) return option;
    if (option is Map) return (option['script'] ?? option['traditional'] ?? option['value'] ?? '').toString();
    return option.toString();
  }

  // 1. Record the N-th occurrence of each Cyrillic word in oldTokens and what option value the user picked.
  // Key: "$normalizedCyrillic#$occurrenceIndex" -> Value: selectedOptionString (and fallback index)
  final Map<String, ({String selectedValue, int selectedIndex})> selectionByOccurrence = {};
  final Map<String, int> oldWordCounts = {};

  for (int i = 0; i < oldTokens.length; i++) {
    final cyrillic = getCyrillic(oldTokens[i]);
    if (cyrillic.isEmpty) continue;

    final occ = (oldWordCounts[cyrillic] ?? 0) + 1;
    oldWordCounts[cyrillic] = occ;

    if (oldSelections.containsKey(i)) {
      final chosenIndex = oldSelections[i]!;
      final options = getOptions(oldTokens[i]);
      if (chosenIndex >= 0 && chosenIndex < options.length) {
        selectionByOccurrence['$cyrillic#$occ'] = (
          selectedValue: getOptionValue(options[chosenIndex]),
          selectedIndex: chosenIndex,
        );
      }
    }
  }

  // 2. Walk through newTokens, count occurrences of each Cyrillic word, and restore selections.
  final Map<int, int> reconciled = {};
  final Map<String, int> newWordCounts = {};

  for (int j = 0; j < newTokens.length; j++) {
    final cyrillic = getCyrillic(newTokens[j]);
    if (cyrillic.isEmpty) continue;

    final occ = (newWordCounts[cyrillic] ?? 0) + 1;
    newWordCounts[cyrillic] = occ;

    final saved = selectionByOccurrence['$cyrillic#$occ'];
    if (saved != null) {
      final newOptions = getOptions(newTokens[j]);
      if (newOptions.length > 1) {
        // Prefer matching by the exact traditional script string in case option order changed
        int matchedIndex = -1;
        for (int k = 0; k < newOptions.length; k++) {
          if (getOptionValue(newOptions[k]) == saved.selectedValue) {
            matchedIndex = k;
            break;
          }
        }
        // Fallback to index if string didn't match but index is still in bounds
        if (matchedIndex == -1 && saved.selectedIndex < newOptions.length) {
          matchedIndex = saved.selectedIndex;
        }
        if (matchedIndex > 0) {
          reconciled[j] = matchedIndex;
        }
      }
    }
  }

  return reconciled;
}
```

---

## Step 5: UI Button States, Force Refresh, and Auto-Invalidation (`frontend/lib/main.dart`)

### Instructions for Agent:

1. **Update the Primary "Convert" Button**:
   * Keep `onPressed` bound as follows:
     ```dart
     onPressed: (_inputTextController.text.trim().isEmpty || _isLoading || !_isConversionDirty)
         ? null
         : () => _convert(),
     ```
   * Update the button label and icon dynamically:
     * When `_isConversionDirty` is `true` (or `_lastConvertedText == null`):
       * Icon: `Icons.translate` (or existing icon)
       * Label: `'Хөрвүүлэх'`
     * When `!_isConversionDirty` and `_lastConvertedText != null`:
       * Icon: `Icons.check`
       * Label: `'Хөрвүүлсэн'`

2. **Add a Secondary "Force Refresh" IconButton in the Output Preview Header**:
   * In the header/toolbar of the output preview pane (only visible when `_tokens.isNotEmpty`), add an `IconButton`:
     ```dart
     IconButton(
       icon: const Icon(Icons.refresh, size: 20),
       tooltip: 'Дахин хөрвүүлэх (Толь бичгийн шинэчлэлийг татах)',
       onPressed: _isLoading ? null : () => _convert(force: true),
     )
     ```
   * This allows a user to explicitly re-fetch from the server (e.g., after a moderator updates the dictionary in another tab) while still preserving all their homonym selections via Step 4.

3. **Auto-Trigger `_convert(force: true)` on Dictionary Addition / Local Override**:
   * Locate the callback in `frontend/lib/main.dart` where a user submits a new word definition (e.g., the "Add Word" dialog or where `_localOverrides` is modified).
   * Immediately after the word is saved to the backend or added to `_localOverrides`, call:
     ```dart
     _convert(force: true);
     ```
   * Because `force: true` bypasses the `_isConversionDirty` guard and Step 4 reconciles `_selectedOptionIndices`, the newly added word will immediately render in Traditional Mongolian script without losing any existing homonym choices or scroll position.

---

## Step 6: Verification Checklist for the Agent

After applying Steps 1–5, verify the following scenarios:

1. **Idempotent Click & Shortcut**:
   * Enter Cyrillic text with an ambiguous word (e.g. `гол`) and an unknown word (e.g. `абвгд`).
   * Click `"Хөрвүүлэх"`. Verify button changes to disabled `"Хөрвүүлсэн ✓"`.
   * Select the second homonym option for `гол`.
   * Press <kbd>⌘</kbd>+<kbd>Enter</kbd> / <kbd>Ctrl</kbd>+<kbd>Enter</kbd> 5 times.
   * **Expected**: Zero network requests sent, no screen flash, homonym selection on `гол` remains intact.
2. **Force Refresh & Edited Text Preservation**:
   * Click the `Icons.refresh` button in the output header.
   * **Expected**: Network request is sent, scroll position does not jump to 0, homonym selection on `гол` remains on the second option.
   * Now type a new word at the very beginning of the Cyrillic input text and click `"Хөрвүүлэх"`.
   * **Expected**: Even though the token index of `гол` shifted by `+1` (or `+2` including whitespace), `_reconcileHomonymSelections` keeps the second homonym option selected on `гол`.
3. **Backend Unknown Word Deduplication**:
   * Input `"абвгд абвгд абвгд"` (same unknown word 3 times) and click `"Хөрвүүлэх"`.
   * **Expected**: `unknown_logs` frequency for `абвгд` increments by **1** (not 3).
   * Click the Force Refresh (`Icons.refresh`) button 3 times.
   * **Expected**: `unknown_logs` frequency for `абвгд` does **not** increment again because `_shouldLogUnknownWord` suppresses duplicate increments for the same `X-Session-ID` within the 30-minute window.