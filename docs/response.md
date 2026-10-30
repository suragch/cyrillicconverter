# Architectural & UX Advisory Response: Handling Repeated Conversion Requests

**To**: Engineering & Product Team (Cyrillic-to-Traditional Mongolian Script Converter)  
**From**: System Architecture & UX Advisory  
**Subject**: Recommendations on Idempotency, State Preservation, and Telemetry Integrity  

---

## Executive Recommendation

Do not choose a single option from Section 5 in isolation. Instead, implement a **Hybrid Architecture (combining elements of Options 1, 2, and 3)**. 

Relying purely on frontend button disabling (Option 1) solves the accidental double-click problem, but **fails to solve the underlying fragility of the application's state model**. Think about what happens when a user converts a 300-word paragraph, carefully disambiguates 15 homonyms, and then notices a single typo in the Cyrillic input. Under Option 1, fixing that single character re-enables the button, and clicking "Convert" will *still* wipe out all 15 manual homonym selections.

Therefore, the permanent architecture must decouple **UI action guards**, **client-side state reconciliation**, and **backend telemetry deduplication**.

---

## 1. Responses to Specific Advisory Questions

### Q1: Button Behavior & Force-Refresh UX
**Recommendation: State-Aware Primary Button + Automatic Dictionary Invalidations (No hidden modifiers)**

1. **Reactive Dirty-State Tracking**: 
   Track `_lastConvertedText` alongside a boolean flag `_isDirty`. Listen to `_inputTextController`. When `currentText == _lastConvertedText && _errorMessage == null`, transition the primary button visually:
   * **Unconverted / Modified State**: Solid primary color, label: `"Хөрвүүлэх"` (Convert).
   * **Up-to-Date State**: Muted/outlined style or disabled appearance, label: `"Хөрвүүлсэн ✓"` (Converted).
2. **Handling Keyboard Shortcuts (<kbd>⌘</kbd>+<kbd>Enter</kbd> / <kbd>Ctrl</kbd>+<kbd>Enter</kbd>)**:
   If the state is not dirty, pressing the keyboard shortcut should be a **strict no-op** on the network layer (optionally triggering a subtle visual pulse on the output pane to reassure the user their text is already rendered).
3. **Eliminating the Need for "Force Refresh" in 95% of Cases**:
   Users should almost never have to manually "force refresh." 
   * **When a user uses the "Add Word" dialog** or updates `_localOverrides`: The frontend already knows this event happened! The dialog submission handler should automatically mark the conversion state as `_isDirty = true` and immediately trigger a silent background re-conversion (or patch the affected tokens directly in memory).
   * **For external updates (e.g., Moderator approved a word in another tab)**: Place a small, secondary icon button (`Icons.refresh`, tooltip: *"Дахин боловсруулах / Шинэчлэх"*) in the **Output/Preview pane header**, rather than cluttering the primary Convert button with split-dropdowns or secret <kbd>Shift</kbd>+Click modifiers (which are undiscoverable on web/desktop).

---

### Q2: Homonym Preservation Across Re-Conversions
**Recommendation: Yes — Mandatory. Migrate from Positional Indexing to Context-Aware Token Reconciliation.**

Preserving user selections is critical not only for repeated clicks on identical text, **but also when the user makes minor edits to the Cyrillic text.**

#### Why `_selectedOptionIndices.clear()` is currently necessary (and how to replace it):
Currently, `_selectedOptionIndices` likely maps `Map<int, int>` (Token Index $\rightarrow$ Selected Candidate Index). If you don't clear it when the text changes, inserting a word at the beginning of a sentence shifts all subsequent token indices by `+1`, applying the wrong homonym choices to the wrong words.

#### How to Preserve Choices Properly:
Instead of wiping selections before the HTTP call, keep the old tokens and old selections in memory until the new response arrives, then **reconcile** them:

1. **Preferred Value over Index**: Store the user's choice by the *actual selected Traditional script string* (or dictionary entry ID) rather than candidate array index, in case dictionary candidate ordering changes.
2. **Same-Text Re-conversion (e.g., Refresh after Dictionary Update)**:
   If `newText == _lastConvertedText`, token positions are guaranteed to be identical. Simply iterate through the new token list: if `oldTokens[i].cyrillic == newTokens[i].cyrillic`, carry over the user's selected option for index `i`.
3. **Edited-Text Re-conversion (Bonus UX Upgrade)**:
   Associate each user selection with a lightweight anchor key: `(normalizedCyrillicWord, occurrenceIndexInText)` or use a simple Longest Common Subsequence (LCS) / Myers diff between `oldTokens` and `newTokens`. If the user fixes one typo in paragraph 3, all homonym selections in paragraphs 1, 2, and 4 remain intact.

---

### Q3: Backend Logging Safeguards (`unknown_logs`)
**Recommendation: Yes — Decouple Operational Conversion from Analytics Ingestion.**

The backend must **never** trust the frontend to protect database analytics integrity. Even with UI guards, users can refresh the browser, open multiple tabs, or hit the endpoint via scripts. Furthermore, **in-document repetition** also skews your current SQL query: if a single document mentions a proper noun or unknown technical term 15 times, a single click of "Convert" increments `frequency` by 15!

Implement a **two-layer safeguard** in `backend/bin/server.dart` and `database.dart`:

#### Layer 1: Per-Request Deduplication (Immediate Fix)
Before logging unknown words in `_convertHandler()`, collect unknown words into a `Set<String>` for that single HTTP request.
* *Effect*: If an essay contains the unknown word `"тэтгэлэг"` 8 times, converting that essay increments the database counter by **1**, not 8. (Lexicographers want to know *how many documents/sessions* needed a word, not whether one user pasted a repetitive list).

#### Layer 2: In-Memory Sliding Window Cache (Session/IP Deduplication)
Since your backend is written in Dart (`server.dart`), you do not even need Redis or a database schema migration to prevent spam. Add a lightweight in-memory TTL cache in the Dart server process:

```dart
// Key: "$clientSessionOrIp:$normalizedWord" -> Value: Timestamp of last log
final Map<String, DateTime> _recentUnknownWordLogs = {};
const Duration _dedupWindow = Duration(minutes: 30);

bool shouldLogUnknownWord(String clientKey, String normalizedWord) {
  final now = DateTime.now();
  
  // Periodic lazy cleanup to prevent memory leaks
  if (_recentUnknownWordLogs.length > 10000) {
    _recentUnknownWordLogs.removeWhere((_, time) => now.difference(time) > _dedupWindow);
  }

  final key = '$clientKey:$normalizedWord';
  final lastLogged = _recentUnknownWordLogs[key];

  if (lastLogged != null && now.difference(lastLogged) < _dedupWindow) {
    return false; // Suppress duplicate increment within 30-minute window
  }

  _recentUnknownWordLogs[key] = now;
  return true;
}
```
* **Client Identifier**: Pass a lightweight random `X-Session-ID` UUID generated by the Flutter client on app startup (fallback to client IP address if missing).

---

## 2. Fixing Problem C (UI Jitter & Scroll Reset)

In `frontend/lib/main.dart`, the current implementation clears `_tokens = []` *before* awaiting the HTTP response. This is an anti-pattern known as **Optimistic Clearing**.

### Recommended Code Pattern (Optimistic Retention):
Keep the existing `_tokens` rendered on screen while `_isLoading = true`, overlaying a subtle linear progress bar at the top of the preview pane or reducing the preview pane opacity to `0.6`.

```dart
Future<void> _convert({bool force = false}) async {
  final text = _inputTextController.text.trim();
  if (text.isEmpty) return;

  // 1. Guard against redundant calls unless forced (e.g. after dictionary add)
  if (!force && text == _lastConvertedText && _errorMessage == null) {
    return; 
  }

  // 2. DO NOT clear _tokens or _selectedOptionIndices here!
  // Keeping old tokens prevents screen flash and preserves scroll position.
  setState(() {
    _isLoading = true;
    _errorMessage = null;
  });

  try {
    final response = await http.post(
      Uri.parse('$_serverUrl/convert'),
      headers: {
        'Content-Type': 'application/json',
        'X-Session-ID': _sessionId, // For backend deduplication
      },
      body: jsonEncode({'text': text}),
    );

    if (response.statusCode == 200) {
      final newTokens = _parseTokens(response.body);
      
      // 3. Reconcile homonym selections between _tokens (old) and newTokens
      final reconciledSelections = _reconcileSelections(_tokens, newTokens, _selectedOptionIndices);

      setState(() {
        _tokens = newTokens;
        _selectedOptionIndices = reconciledSelections;
        _lastConvertedText = text;
        _isLoading = false;
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

### Why This Solves Scroll Reset:
In Flutter, when you set `_tokens = []`, the `SingleChildScrollView` or `ListView` collapses its scrollable extent (`maxScrollExtent`) to `0.0`, which forces the `ScrollController` offset back to `0.0`. When the new tokens arrive 100ms later, the scroll view rebuilds from position `0.0`. By swapping `_tokens` directly from `oldList` to `newList` in a single `setState` frame after the network call completes, Flutter maintains the `ScrollController`'s current offset seamlessly.

---

## 3. Recommended Implementation Roadmap

| Priority             | Task                                                                                                                                             | Effort   | Impact                                                                                         |
| :------------------- | :----------------------------------------------------------------------------------------------------------------------------------------------- | :------- | :--------------------------------------------------------------------------------------------- |
| **P0 (Immediate)**   | **Stop clearing `_tokens` before `await http.post`** in `main.dart`. Swap tokens only when the response arrives.                                 | ~15 mins | Eliminates UI flash and scroll position reset immediately.                                     |
| **P0 (Immediate)**   | **Add Client-Side Dirty Check (`_lastConvertedText`)** with a `force: true` parameter triggered automatically when a user adds/overrides a word. | ~30 mins | Stops accidental <kbd>⌘</kbd>+<kbd>Enter</kbd> data loss and wasted network calls.             |
| **P1 (Short-Term)**  | **Backend Per-Request `Set` + In-Memory TTL Cache** for `logUnknownWord`.                                                                        | ~45 mins | Permanently protects `unknown_logs` priority queue from spam and intra-document repetition.    |
| **P2 (Medium-Term)** | **Token Selection Reconciliation (`_reconcileSelections`)** when swapping `oldTokens` $\rightarrow$ `newTokens`.                                 | ~2 hours | Preserves homonym disambiguations even when users fix typos or add sentences to existing text. |