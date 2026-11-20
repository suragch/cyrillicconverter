# Bug Audit & Remediation Plan

* **Author:** suragch
* **Status:** Implemented
* **Date:** 2026-11-20
* **Target Components:** [`backend/`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/backend/), [`frontend/`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/frontend/)

---

## Overview

This document catalogs 20 bugs across four areas identified during a comprehensive audit of the Cyrillic-to-Traditional-Mongolian Converter codebase (backend Shelf server, SQLite database layer, CLI utilities, Flutter frontend, and local dictionary persistence) and defines a 3-phase remediation plan incorporating the resolved design decisions for final approval before implementation.

In particular, Bugs #1–#4 explain why deleting or rejecting an item in the Moderator View can appear to **skip** the word rather than remove it from the server database.

---

## Bug Summary Index

| ID | Severity | Area | Summary | Primary Locations |
| :-: | :--- | :--- | :--- | :--- |
| #1 | **Critical** | Moderator UI | Double-submit / navigation race removes wrong queue item by mutable index (skips without deleting) | [`moderator_page.dart`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/frontend/lib/ui/moderator/moderator_page.dart#L441-L550) |
| #2 | **Critical** | Moderator / Backend | Deleting/updating/promoting definitions silently fails with HTTP `200 OK` (`deleted: false`) on case/whitespace mismatch | [`database.dart`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/backend/lib/database.dart#L422-L650), [`server.dart`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/backend/bin/server.dart#L840-L894) |
| #3 | **High** | Moderator UI | Stale `/admin/words/check` response overwrites current card with previous word's definitions | [`moderator_page.dart`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/frontend/lib/ui/moderator/moderator_page.dart#L216-L282) |
| #4 | **High** | Moderator / DB | `rejectMissingWord()` omits raw `cyrillic` in `DELETE`, lacks transaction, and isn't idempotent | [`database.dart`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/backend/lib/database.dart#L781-L829) |
| #5 | **High** | Moderator / DB | Impossible to clear `explanation` when approving a suggestion or editing a definition (leaks ECK metadata) | [`database.dart`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/backend/lib/database.dart#L534-L552), [`database.dart`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/backend/lib/database.dart#L676-L680) |
| #6 | **High** | Moderation Queue / DB | Startup sweep and `_autoResolveMatchingSuggestions` silently wipe out comment-bearing error reports / deletion requests | [`database.dart`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/backend/lib/database.dart#L134-L162), [`database.dart`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/backend/lib/database.dart#L311-L338) |
| #7 | **High** | Moderator UI / Dialog | Hotkey races, missing target validation, empty-`menksoft` approval, forced `replace` overwrite, swallowed errors, and pagination cap (100) | [`moderator_page.dart`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/frontend/lib/ui/moderator/moderator_page.dart#L320-L488), [`edit_suggestion_dialog.dart`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/frontend/lib/ui/moderator/edit_suggestion_dialog.dart#L108-L260) |
| #8 | **Medium** | Moderator / DB | `getRejectionHistory()` uses SQLite ASCII-only `LOWER()`, missing Cyrillic case variants | [`database.dart`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/backend/lib/database.dart#L832-L840) |
| #9 | **High** | Conversion | All newlines and paragraph breaks (`\n`) are destroyed and flattened into `' '` | [`server.dart`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/backend/bin/server.dart#L325-L331), [`main.dart`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/frontend/lib/main.dart#L633-L635) |
| #10 | **Medium** | Conversion | Compound punctuation (`...`, `?!`, `!?`) adjacent to other symbols and closing straight quotes `"` convert incorrectly | [`server.dart`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/backend/bin/server.dart#L190-L226), [`latin_ime.dart`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/frontend/lib/services/latin_ime.dart#L192-L229) |
| #11 | **High** | Local Dictionary | `_persistLock` breaks permanently after one storage error; ALL-CAPS lookups miss; Dictionary tab edits leave stale converter tokens | [`local_dictionary_service.dart`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/frontend/lib/services/local_dictionary_service.dart#L63-L71), [`local_dictionary_service.dart`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/frontend/lib/services/local_dictionary_service.dart#L147-L166) |
| #12 | **Medium** | Converter UI | `/contribute` errors swallowed after premature success toast; duplicate local options; wrong `targetMenksoft`; homonym reconciliation case collision | [`main.dart`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/frontend/lib/main.dart#L52-L63), [`main.dart`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/frontend/lib/main.dart#L837-L931) |
| #13 | **Medium** | Dialog Input | Pasting unmapped Mongolian Unicode characters freezes Latin preview and jumps cursor to end | [`add_edit_word_dialog.dart`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/frontend/lib/ui/dialogs/add_edit_word_dialog.dart#L94-L107), [`edit_suggestion_dialog.dart`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/frontend/lib/ui/moderator/edit_suggestion_dialog.dart#L83-L96) |
| #14 | **Medium** | Auth / UI Crash | Empty `currentUser['email']` throws `RangeError` in `DesktopHeader` | [`desktop_header.dart`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/frontend/lib/ui/desktop/components/desktop_header.dart#L142-L145) |
| #15 | **Medium** | Auth / Roles | Non-moderator logged-in accounts see Moderator tab & admin controls (failing with HTTP 403) | [`server.dart`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/backend/bin/server.dart#L117-L173), [`main.dart`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/frontend/lib/main.dart#L489-L494) |
| #16 | **Medium** | Lifecycle / Memory | Missing `mounted` checks after `await` and undisposed `TextEditingController`s | [`moderator_page.dart`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/frontend/lib/ui/moderator/moderator_page.dart#L170-L211), [`dictionary_browse_view.dart`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/frontend/lib/ui/dictionary/dictionary_browse_view.dart#L81-L99), [`main.dart`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/frontend/lib/main.dart#L1510-L1511) |
| #17 | **Low–Med** | Dialogs & Desktop UI | Dialog overflow on mobile keyboards, `Enter` hijacking in multi-line fields, global `Cmd+Enter`, stuck hover/error states, silent desktop write errors | [`desktop_dialog.dart`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/frontend/lib/ui/desktop/components/desktop_dialog.dart#L47-L52), [`add_edit_word_dialog.dart`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/frontend/lib/ui/dialogs/add_edit_word_dialog.dart#L245-L257), [`desktop_button.dart`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/frontend/lib/ui/desktop/components/desktop_button.dart#L110-L118) |
| #18 | **Medium** | Backend Security | Chunked requests bypass the 512KB `payloadLimitMiddleware` ceiling | [`server.dart`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/backend/bin/server.dart#L949-L964) |
| #19 | **Medium** | Backend API | Unvalidated `/admin/words` inputs, `/convert` dedup case bug, `_` validator/tokenizer mismatch, missing JSON content-type headers, non-batched flush | [`server.dart`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/backend/bin/server.dart#L287-L894), [`cyrillic_validator.dart`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/backend/lib/cyrillic_validator.dart#L3-L6) |
| #20 | **Medium** | CLI Scripts | `seed.dart` nested transaction crash; `migrate_seed.dart` abbreviation case bug; `setup_db.dart` outdated schema | [`seed.dart`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/backend/bin/seed.dart#L80-L100), [`migrate_seed.dart`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/backend/bin/migrate_seed.dart#L58), [`setup_db.dart`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/backend/bin/setup_db.dart#L8-L69) |

---

## Detailed Bug Catalog

### 1. Moderator View & Dictionary Management (Why "Delete" Skips or Silently Fails)

#### Bug #1 — Double-submit / navigation race removes the wrong queue item (skips without deleting)
* **Where:** [`moderator_page.dart`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/frontend/lib/ui/moderator/moderator_page.dart#L441-L550), [`moderator_page.dart`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/frontend/lib/ui/moderator/moderator_page.dart#L755-L799), [`moderator_page.dart`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/frontend/lib/ui/moderator/moderator_page.dart#L851-L944)
* **Cause:** `_executeApprove`, `_handleRejectCurrent`, `_handleRejectMissing`, `_deleteDefinitionForWord`, and `_setPrimaryForWord` have **no in-flight busy lock** and **no HTTP timeouts**. Furthermore, `_advanceQueue()` (`_suggestions.removeAt(_currentIndex)`) and `_handleRejectMissing()` (`_missingWords.removeAt(_missingIndex)`) remove items from the in-memory queue by the **mutable index** rather than by the acted-upon `id` or `cyrillic`.
* **Impact:** Pressing `2`/`3`/`1` twice over network latency—or pressing `Space`/`→`/`←` before the `POST` completes—removes the **next** item from the local list without ever rejecting or deleting it on the server. The untouched item appears skipped and reappears on reload.

#### Bug #2 — Deleting (or updating/promoting) an existing definition silently fails with HTTP `200 OK`
* **Where:** [`database.dart`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/backend/lib/database.dart#L422-L650), [`server.dart`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/backend/bin/server.dart#L840-L894), [`moderator_page.dart`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/frontend/lib/ui/moderator/moderator_page.dart#L600-L686), [`dictionary_browse_view.dart`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/frontend/lib/ui/dictionary/dictionary_browse_view.dart#L247-L369)
* **Cause:**
  * `lookupWord()` falls back to lowercase when an all-caps word (`CyrillicValidator.isAbbreviation` matches any 2+ uppercase Cyrillic letters, such as `НОМ` or `ТАСС`) is not stored in uppercase, so `/admin/words/check` renders the lowercase word's definitions. However, `deleteDefinition()`, `setPrimaryDefinition()`, and `replaceDefinition()` query only `WHERE cyrillic = normalized` with **no lowercase fallback** (and `replaceDefinition()` creates a duplicate uppercase row in `words`).
  * `deleteDefinition()` and `setPrimaryDefinition()` compare `menksoft_code = cleanMenksoft` without `TRIM(menksoft_code)` even though the request input is trimmed.
  * `_adminDeleteDefinitionHandler` and `_adminSetPrimaryDefinitionHandler` always return `200 OK` (`{"success": true, "deleted": false}` / `{"updated": false}`), and the frontend only checks `res.statusCode == 200`, ignoring `deleted == false` and showing no error.

#### Bug #3 — Stale `/admin/words/check` response race shows the previous word's definitions on the current card
* **Where:** [`moderator_page.dart`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/frontend/lib/ui/moderator/moderator_page.dart#L216-L282), [`moderator_page.dart`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/frontend/lib/ui/moderator/moderator_page.dart#L690-L737)
* **Cause:** `_checkWordForCurrent()` and `_checkWordForMissing()` do not track a request generation token or verify that the queried `cyrillic` still matches the currently displayed item when the HTTP response returns.
* **Impact:** Navigating quickly lets a slow response for Word A overwrite Word B's right-hand dictionary panel. Clicking Delete or Replace then sends `(wordB, wordA's menksoft)`, which silently fails (`deleted: false`, HTTP `200`) or mutates the wrong definition.

#### Bug #4 — `rejectMissingWord()` omits raw `cyrillic` in `DELETE`, lacks transaction, and isn't idempotent
* **Where:** [`database.dart`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/backend/lib/database.dart#L781-L829)
* **Cause:** `rejectMissingWord()` runs `DELETE FROM unknown_logs WHERE cyrillic = ? OR cyrillic = ?` using `[normalized, normalized.toLowerCase()]`, omitting raw `cyrillic.trim()`. Any non-normalized entry in `unknown_logs` is not deleted yet returns HTTP `200` (so the UI removes it from memory, making it look skipped until refresh). Neither `rejectMissingWord()` nor `rejectSuggestion()` runs inside `_runInTransaction`, and neither guards against duplicate rejections (`status = 'pending'`), allowing duplicate rows in `rejected_words`.

#### Bug #5 — Impossible to clear `explanation` when approving a suggestion or editing a definition
* **Where:** [`database.dart`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/backend/lib/database.dart#L534-L552), [`database.dart`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/backend/lib/database.dart#L676-L680), [`edit_suggestion_dialog.dart`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/frontend/lib/ui/moderator/edit_suggestion_dialog.dart#L235-L242)
* **Cause:**
  * When a moderator clears the explanation field in `EditSuggestionDialog` (e.g., to strip import metadata such as `"ECK зөрүү: Баазад: ... | ECK: ..."` or `"ECK толь (1:1)"`), the client sends `'explanation': null`. In `approveSuggestion()`, `explanation ?? (sug['explanation'] as String?)` falls back to the stored suggestion value, leaking ECK metadata into the public dictionary. Additionally, auto-generated `"ECK ..."` notes from bulk imports are copied straight into `definitions.explanation` on direct approval.
  * In `replaceDefinition()`, `explanation = COALESCE(?, explanation)` prevents moderators from clearing an existing definition's explanation in `DictionaryBrowseView._editDefinition`.

#### Bug #6 — Startup sweep and auto-resolution silently wipe out contributor error reports / deletion requests
* **Where:** [`database.dart`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/backend/lib/database.dart#L134-L162), [`database.dart`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/backend/lib/database.dart#L311-L338)
* **Cause:** Opening **"Алдаа мэдээлэх / Засах"** pre-fills the existing `menksoft` spelling. If a contributor leaves it untouched and writes a moderator `comment` (e.g., asking to delete the word or fix its explanation), the suggestion has the same `(cyrillic, menksoft_code)` as the existing definition. On server restart (`initSchema()`) or any edit to that word (`_autoResolveMatchingSuggestions()`), it gets **silently marked `auto_resolved`** and removed from the queue before any moderator reads the comment.

#### Bug #7 — Moderator approval / edit dialog edge cases & silent error swallowing
* **Where:** [`moderator_page.dart`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/frontend/lib/ui/moderator/moderator_page.dart#L320-L430), [`moderator_page.dart`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/frontend/lib/ui/moderator/moderator_page.dart#L441-L488), [`moderator_page.dart`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/frontend/lib/ui/moderator/moderator_page.dart#L801-L836), [`moderator_page.dart`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/frontend/lib/ui/moderator/moderator_page.dart#L864-L889), [`moderator_page.dart`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/frontend/lib/ui/moderator/moderator_page.dart#L1934-L1944), [`edit_suggestion_dialog.dart`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/frontend/lib/ui/moderator/edit_suggestion_dialog.dart#L108-L260)
* **Issues:**
  * **Hotkey `1`/`4` race:** Pressing `1` while `_isCheckingCurrentWord == true` sees `exists == false` and runs `add_primary` instead of `replace` (bypassing duplicate/homonym checks).
  * **Replace with no target selected:** When a word has 2+ definitions and `_selectedTargetMenksoft == null`, clicking "Одоогийн бичлэгийг солих" or pressing `1` silently falls back to `add_primary` (adding a duplicate primary instead of prompting the moderator to pick a target).
  * **`EditSuggestionDialog` defects:**
    * Does not reject empty `menksoft` on "Хадгалаад батлах" (allowing empty `menksoft_code = ''` into `definitions`; `approveSuggestion()` also lacks an empty-`menksoft` guard for non-`resolve_only` actions).
    * Hardcodes `action = hasTarget ? 'replace' : 'add_primary'`—because `ModeratorPage` auto-selects `_selectedTargetMenksoft` when `definitions.length == 1`, editing a new homonym variant and clicking "Хадгалаад батлах" **overwrites** the existing definition instead of letting the moderator choose Replace vs. Add Variant.
    * Keeps stale `widget.targetMenksoft` even if the moderator changes `cyrillic` to a different word.
    * `_checkCyrillicWord` never resets `_isCheckingCyrillic = false` on non-200 status (leaving the loading spinner active indefinitely) and lacks a timeout / stale-request guard.
    * `_executeApprove` swallows HTTP/network errors instead of rethrowing, so `EditSuggestionDialog` closes and discards the moderator's edits on failure.
  * **`_addWord` (Missing Words "Тодорхойлох / Нэмэх") swallows non-200 responses:** If `/admin/words` returns an error status, `_addWord` neither throws nor shows a SnackBar, closing `AddEditWordDialog` and losing the input.
  * **Double dialog on identical duplicate:** Confirming the "already exists" dialog immediately opens a second "Homonym (different spelling)" note prompt.
  * **Missing Words batch pagination & count:** `/admin/missing` returns at most 100 rows with no `total` count; the tab badge caps at `100`, and once 100 items are processed it shows "Finished all missing words!" instead of loading the next batch. `_addWord` also does not refresh the suggestions queue/count after auto-resolving matching suggestions.

#### Bug #8 — `getRejectionHistory()` fails on Cyrillic case differences
* **Where:** [`database.dart`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/backend/lib/database.dart#L752-L778), [`database.dart`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/backend/lib/database.dart#L832-L840)
* **Cause:** `getRejectionHistory()` relies on SQLite's `LOWER(cyrillic)`, which only folds ASCII `A–Z` and does not fold Cyrillic `А–Я, Ё, Ө, Ү`.

---

### 2. Text Conversion & Local Dictionary Bugs

#### Bug #9 — All newlines and paragraph breaks are destroyed during conversion
* **Where:** [`server.dart`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/backend/bin/server.dart#L325-L331), [`main.dart`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/frontend/lib/main.dart#L633-L635)
* **Cause:** `Tokenizer` preserves `\n` and `\n\n` inside `TokenType.space`, but both `_convertHandler` (`'menksoft': ' '`) and `_syncOutputText` (`if (token.type == 'space') { text = ' '; }`) unconditionally replace every whitespace token with a single space, flattening multi-paragraph text into one line in both the output display and clipboard copy.

#### Bug #10 — Punctuation conversion bugs (compound punctuation & closing quotes)
* **Where:** [`server.dart`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/backend/bin/server.dart#L190-L226), [`latin_ime.dart`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/frontend/lib/services/latin_ime.dart#L192-L229)
* **Cause:** Multi-character punctuation (`...`, `?!`, `!?`) only matches when it constitutes the *entire* delimiter token; if adjacent to another symbol (e.g. `...)`, `..."`), it falls back to character-by-character conversion (`...` becomes three full stops instead of ellipsis `\uE235`). Straight double quotes `"` always map to the left double angle bracket `\uE259` (`«`) even when closing (`"Монгол"` → `«Монгол«`).

#### Bug #11 — `LocalDictionaryService._persistLock` permanently breaks after one storage error, and misses ALL-CAPS lookups
* **Where:** [`local_dictionary_service.dart`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/frontend/lib/services/local_dictionary_service.dart#L63-L71), [`local_dictionary_service.dart`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/frontend/lib/services/local_dictionary_service.dart#L147-L166)
* **Cause:**
  * `_persist()` rethrows inside `_persistLock = _persistLock.then(...)`, leaving `_persistLock` in a permanently rejected state so **all subsequent saves/deletes never execute** for the remainder of the session.
  * `getWord()` / `hasWord()` perform no lowercase fallback for ALL-CAPS words (unlike backend `lookupWord`), so a locally saved word `'шинэүг'` is missed when converting `'ШИНЭҮГ'`.
  * Editing or deleting a local word in **Dictionary → Миний үгс** leaves stale green tokens rendered when switching back to the **Converter** tab.

#### Bug #12 — Converter suggestion submission swallows errors, duplicates local options, and sends wrong `targetMenksoft`
* **Where:** [`main.dart`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/frontend/lib/main.dart#L837-L931), [`main.dart`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/frontend/lib/main.dart#L1215-L1228), [`main.dart`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/frontend/lib/main.dart#L1375-L1388), [`main.dart`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/frontend/lib/main.dart#L52-L63)
* **Cause:**
  * `_handleWordAddedOrSuggested` displays a success toast *before* calling `POST /contribute`, has no HTTP timeout, and never checks `res.statusCode == 200`, so failed text-only reports or HTTP 400/500 errors are reported as successful.
  * The optimistic token update prepends `localOption` even if `cleanMenksoft` already exists in `_tokens[i].options`.
  * Clicking **"Алдаа мэдээлэх / Засах"** on a word with a local override while index `0` (local) is selected passes the user's unapproved local spelling as `targetMenksoft` instead of a server spelling.
  * Furthermore, if a user opens **"Алдаа мэдээлэх / Засах"**, leaves the pre-filled spelling unchanged, and writes only a `comment` (e.g., requesting deletion or describing an error), it still submits `menksoft` and triggers a local override instead of submitting a clean text-only report.
  * `reconcileHomonymSelections` uses `token.original.trim().toLowerCase()` instead of `LatinIme.normalizeCyrillic`, colliding abbreviations (`АН`) with regular words (`ан`).

#### Bug #13 — Pasting unmapped Mongolian Unicode characters breaks the Latin input field and preview
* **Where:** [`add_edit_word_dialog.dart`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/frontend/lib/ui/dialogs/add_edit_word_dialog.dart#L94-L107), [`edit_suggestion_dialog.dart`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/frontend/lib/ui/moderator/edit_suggestion_dialog.dart#L83-L96)
* **Cause:** `_onLatinChanged()` checks `LatinIme.containsMongolianScript(text)` (matching `\u1800-\u18AF\uE234-\uE34F`), calls `convertToLatin()`, reassigns `_latinController.value`, and returns early before updating `_previewMenksoft`. If pasted text includes any Mongolian character unmapped by `convertMongolianUnicodeToLatin` (e.g., punctuation `᠃` or digits `᠐`–`᠙`), `containsMongolianScript` stays `true` on every subsequent edit—jumping the cursor to the end and preventing `_previewMenksoft` from updating.

---

### 3. Auth, Role Handling, Crashes & UI Bugs

#### Bug #14 — Crash when `currentUser['email']` is empty (`RangeError`)
* **Where:** [`desktop_header.dart`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/frontend/lib/ui/desktop/components/desktop_header.dart#L142-L145)
* **Cause:** `(currentUser?['email'] as String? ?? 'U').substring(0, 1)` throws `RangeError` if `email` is `''` (empty string rather than `null`).

#### Bug #15 — Non-moderator logged-in accounts are treated as moderators in the UI
* **Where:** [`server.dart`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/backend/bin/server.dart#L117-L135), [`server.dart`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/backend/bin/server.dart#L157-L173), [`main.dart`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/frontend/lib/main.dart#L489-L494), [`desktop_header.dart`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/frontend/lib/ui/desktop/components/desktop_header.dart#L79-L86), [`dictionary_browse_view.dart`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/frontend/lib/ui/dictionary/dictionary_browse_view.dart#L49-L50)
* **Cause:** `_loginHandler` does not return `isModerator` (and `_authMeHandler` omits `isModerator` inside `user`), while the frontend checks `_isLoggedIn` (`_authToken != null`) instead of the user's moderator/admin role, exposing the Moderator tab and admin dictionary buttons to ordinary accounts (which then fail with HTTP 403).

#### Bug #16 — Missing `mounted` checks & undisposed `TextEditingController` leaks
* **Where:**
  * Missing `mounted` checks before `setState` after `await`: [`moderator_page.dart`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/frontend/lib/ui/moderator/moderator_page.dart#L170-L211) (`_loadData`), [`dictionary_browse_view.dart`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/frontend/lib/ui/dictionary/dictionary_browse_view.dart#L81-L99) (`_searchWord`), [`main.dart`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/frontend/lib/main.dart#L1371-L1398) (`_showAmbiguityMenu`), [`main.dart`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/frontend/lib/main.dart#L1463-L1479) (`_showWordActionMenu`).
  * Undisposed `TextEditingController`s: [`moderator_page.dart`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/frontend/lib/ui/moderator/moderator_page.dart#L366) (homonym note dialog) and [`main.dart`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/frontend/lib/main.dart#L1510-L1511) (login dialog, which also lacks an HTTP timeout).

#### Bug #17 — Dialog & keyboard UX bugs
* **Dialog overflow on small viewports / mobile keyboard:** [`desktop_dialog.dart`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/frontend/lib/ui/desktop/components/desktop_dialog.dart#L47-L52) uses `maxHeight ?? availableHeight` instead of `math.min(maxHeight, availableHeight)`, so dialogs specifying `maxHeight: 740`/`780` overflow mobile viewports when the software keyboard opens.
* **`Enter` key hijacked in multi-line fields:** [`add_edit_word_dialog.dart`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/frontend/lib/ui/dialogs/add_edit_word_dialog.dart#L245-L257) binds bare `Enter` to `_submit()`, submitting the dialog even when pressing Enter inside multi-line comment/context fields; `_submit()` also gives zero feedback when required fields are empty.
* **`Cmd+Enter` triggers conversion on other tabs:** [`main.dart`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/frontend/lib/main.dart#L1648-L1653) invokes `_convert()` even when the Moderator or Dictionary tab is active.
* **Clear button leaves `_errorMessage` stuck:** [`main.dart`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/frontend/lib/main.dart#L1891-L1900) clears input text and tokens but not `_errorMessage`.
* **Button hover/pressed state stuck when disabled mid-hover:** [`desktop_button.dart`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/frontend/lib/ui/desktop/components/desktop_button.dart#L110-L118) and [`desktop_button.dart`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/frontend/lib/ui/desktop/components/desktop_button.dart#L248-L252) set `onExit: null` when disabled, leaving `_isHovered` / `_isPressed` stuck `true`.
* **Desktop file download swallows write errors:** [`file_downloader_stub.dart`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/frontend/lib/services/file_downloader_stub.dart#L5-L19) catches and ignores write failures while callers still display a success toast.

---

### 4. Backend API, Database & CLI Script Bugs

#### Bug #18 — Chunked requests bypass the 512KB payload limit
* **Where:** [`server.dart`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/backend/bin/server.dart#L949-L964)
* **Cause:** `payloadLimitMiddleware` only checks `request.contentLength`, which is `null` for `Transfer-Encoding: chunked` requests.

#### Bug #19 — Input validation, consistency, and dedup bugs in backend handlers
* **`_adminAddWordHandler`** ([`server.dart`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/backend/bin/server.dart#L765-L798)): Does not validate empty/non-Cyrillic `cyrillic` or empty `menksoft`, and omits normalized forms when cleaning `unknown_logs`.
* **`_convertHandler` unknown word deduplication** ([`server.dart`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/backend/bin/server.dart#L379)): Uses `.toLowerCase()` instead of `CyrillicValidator.normalizeWord()`, so if an unknown regular word (`ан`) and an unknown abbreviation (`АН`) appear in the same text, `АН` is silently dropped from `unknown_logs`.
* **`CyrillicValidator` vs. `Tokenizer` underscore mismatch** ([`cyrillic_validator.dart`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/backend/lib/cyrillic_validator.dart#L3-L6) vs. [`tokenizer.dart`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/backend/lib/tokenizer.dart#L14-L17)): `CyrillicValidator` accepts `_`, while `Tokenizer` splits on `_`, allowing un-matchable tokens into `/contribute`.
* **Missing `'content-type': 'application/json'`** on most `Response.badRequest(...)` responses in [`server.dart`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/backend/bin/server.dart#L422-L894).
* **Unknown word background queue flush** ([`server.dart`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/backend/bin/server.dart#L287-L303)): Uses `removeAt(0)` ($O(n^2)$), commits a separate SQLite transaction per word instead of batching, and lacks `try / finally` to reset `_isFlushingUnknownWords`.

#### Bug #20 — CLI seed/setup scripts broken or outdated
* [`seed.dart`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/backend/bin/seed.dart#L80-L100): `--from-json <list>` executes `BEGIN TRANSACTION;` directly on `appDb.db` and then calls `appDb.addWordDefinition()` (which opens a transaction via `_runInTransaction`), crashing SQLite with `cannot start a transaction within a transaction`. Also lacks `ROLLBACK` on error.
* [`migrate_seed.dart`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/backend/bin/migrate_seed.dart#L58): Uses `cyrillic.toLowerCase()` instead of `CyrillicValidator.normalizeWord()`, corrupting abbreviation casing.
* [`setup_db.dart`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/backend/bin/setup_db.dart#L8-L69): Defines an outdated incompatible schema and seeds Unicode instead of Menksoft PUA codes.

---

## Phased Remediation Plan

### Phase 1: Backend Database, HTTP API & CLI Scripts

1. **`backend/lib/database.dart`**
   * Add a shared `_findWordId(String cyrillic)` helper mirroring `lookupWord()` (exact match if abbreviation, falling back to lowercase) and use it in `deleteDefinition`, `setPrimaryDefinition`, and `replaceDefinition`.
   * Match `TRIM(menksoft_code) = ?` in `deleteDefinition` and `setPrimaryDefinition`.
   * Support explicitly clearing `explanation` in `replaceDefinition` (e.g., `bool clearExplanation = false`) and `approveSuggestion` (distinguish omitted vs. explicitly cleared `""`/`null`).
   * Automatically omit auto-generated `"ECK ..."` notes on `eck_import` and `db_discrepancy_review` suggestions from `definitions.explanation` on approval unless the moderator explicitly edited them into a custom meaning note.
   * Protect comment-bearing suggestions (`COALESCE(TRIM(comment), '') = ''`) from startup auto-cleanup in `initSchema()` and from `_autoResolveMatchingSuggestions()`.
   * Wrap `rejectSuggestion` and `rejectMissingWord` in `_runInTransaction`; guard `approveSuggestion` and `rejectSuggestion` against already-reviewed rows (`status = 'pending'`); keep `rejectSuggestion` scoped exclusively to the targeted suggestion `id` (preserving sibling pending suggestions for the same Cyrillic word and not touching `unknown_logs`); reject empty `menksoft` in `approveSuggestion` unless `action == 'resolve_only'`.
   * In `rejectMissingWord`, delete matching `cyrillic IN (?, ?, ?)` (`cyrillic.trim()`, `normalized`, `normalized.toLowerCase()`) and return `bool` indicating whether a row was deleted. Add `getUnknownWordsCount({int minFrequency = 1})`.
   * Fix `getRejectionHistory` to match normalized/lowercase Cyrillic in Dart parameters (`WHERE cyrillic IN (?, ?, ?)`) rather than SQLite's ASCII-only `LOWER()`, and normalize `cyrillic` in `logRejectedWord`.
   * Expose a public `runInTransaction<T>(T Function() action)` helper (reused by `seed.dart` and batch unknown-word flushing).

2. **`backend/bin/server.dart` & `backend/lib/cyrillic_validator.dart`**
   * Return `404 Not Found` (`{'success': false, 'deleted': false, 'error': ...}` / `updated: false`) from `_adminDeleteDefinitionHandler` and `_adminSetPrimaryDefinitionHandler` when no matching definition exists; return `404`/`409` or clear error when approving/rejecting non-pending items.
   * Pass explicit `hasExplanation` / `clearExplanation` flags from `_adminApproveHandler` and `_adminUpdateDefinitionHandler` so moderators can clear explanations.
   * Include `'total'` (`_db.getUnknownWordsCount(minFrequency: minFrequency)`) in `GET /admin/missing`.
   * Preserve newlines (`\n`) in `_convertHandler` for `TokenType.space` (normalize `\r\n` → `\n` and collapse horizontal spaces/tabs without stripping `\n`).
   * Fix `_convertDelimiter` to match multi-char punctuation (`...`, `?!`, `!?`) inside compound delimiter tokens and track straight double-quote `"` open/close parity per paragraph (resetting on `\n`) so pairs become `«...»` (`\uE259` / `\uE25A`).
   * Use `CyrillicValidator.normalizeWord` for unknown-word deduplication in `_convertHandler`; batch `_unknownWordQueue` flush in a single transaction with `try / finally`.
   * Validate non-empty Cyrillic & Menksoft in `_adminAddWordHandler`, and clean `unknown_logs` using normalized forms.
   * Include `isModerator` in `_loginHandler` and inside `_authMeHandler`'s `user` object.
   * Enforce `maxBytes` even on chunked streams in `payloadLimitMiddleware`, and add `'content-type': 'application/json'` to all JSON error responses.
   * Remove `_` from `CyrillicValidator._cyrillicWordRegex` so `/contribute` and `/admin/words` match `Tokenizer` (Cyrillic letters with optional `-` or `'`).

3. **Backend CLI Scripts ([`seed.dart`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/backend/bin/seed.dart), [`migrate_seed.dart`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/backend/bin/migrate_seed.dart), [`setup_db.dart`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/backend/bin/setup_db.dart))**
   * Fix `seed.dart` to use `appDb.runInTransaction(...)` with proper rollback.
   * Update `migrate_seed.dart` to use `CyrillicValidator.normalizeWord`.
   * Update `setup_db.dart` to delegate schema creation to `AppDatabase.initSchema()`.

4. **Backend Tests ([`backend/test/`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/backend/test/))**
   * Add tests for: all-caps fallback on delete/setPrimary/replace, `404` on missing delete, clearing explanations on approve & update, auto-omitting `"ECK ..."` notes unless customized, preserving comment-bearing suggestions from auto-resolve, single-row rejection scope preserving sibling homonyms, newline preservation, compound punctuation and paired straight quotes, underscore rejection in `CyrillicValidator`, Cyrillic rejection history lookup, idempotent approve/reject, chunked payload limit, non-moderator `/auth/me` / `/auth/login`, and `/admin/missing` `total` count.

---

### Phase 2: Moderator View & Dictionary Management UI

1. **`frontend/lib/ui/moderator/moderator_page.dart`**
   * Add an `_isActionInProgress` guard disabling action buttons & hotkeys while any mutation is in flight, plus `.timeout(...)` on all HTTP requests.
   * Remove items from `_suggestions` by `id` and from `_missingWords` by `cyrillic` (never by mutable index).
   * Add request-generation tokens to `_checkWordForCurrent()` and `_checkWordForMissing()` so stale responses are discarded; guard hotkeys `1`/`4` while `_isCheckingCurrentWord` is true.
   * Check `deleted == true` / `updated == true` on `/admin/definitions/delete` and `/admin/definitions/primary` responses and show explicit success/error SnackBars.
   * Require selecting a target definition before enabling "Одоогийн бичлэгийг солих" (or hotkey `1` replace) when `definitions.length > 1`.
   * Rethrow errors from `_executeApprove` and `_addWord` so dialogs remain open on failure instead of silently discarding edits; auto-load the next missing-word batch when depleted and refresh the suggestions count after `_addWord`; track `_totalMissing` from backend.
   * Add `if (!mounted) return;` in `_loadData()`, dispose the homonym dialog's `TextEditingController`, and skip the homonym note prompt when approving an already-identical duplicate.

2. **`frontend/lib/ui/moderator/edit_suggestion_dialog.dart`**
   * Fix `_onLatinChanged()` (`if (converted != text)`) so unmapped Mongolian characters do not freeze preview/cursor.
   * Reset `_isCheckingCyrillic = false` in `finally`, add timeout and stale-request guard.
   * Pass both `explicitTargetMenksoft` (`current['target_menksoft']`) and `selectedTargetMenksoft` (`_selectedTargetMenksoft`) from `ModeratorPage`. For words that already exist in the dictionary, render an explicit action selector (`replace`, `add_secondary`, `add_primary`), defaulting to **Replace** only when `explicitTargetMenksoft` is non-empty (error report) and **Add secondary** otherwise.
   * Validate non-empty `_previewMenksoft` before `andApprove: true`; explicitly send empty string `''` when explanation is cleared; ignore stale `targetMenksoft` if `cyrillic` was edited.

3. **`frontend/lib/ui/dictionary/dictionary_browse_view.dart`**
   * Receive explicit `isModerator` boolean instead of inferring from `authToken != null`.
   * Add `mounted` and stale-request guards to `_searchWord()`, add timeouts to all HTTP requests, inspect `deleted`/`updated` booleans on response, send auth headers on `/contribute`, submit clean text-only reports (`menksoft: ''`) when `menksoft` matches `targetMenksoft` with unchanged explanation and non-empty `comment`, and notify parent when local words are modified.

---

### Phase 3: Converter, Local Dictionary & Shared UI

1. **`frontend/lib/services/local_dictionary_service.dart`**
   * Fix `_persist()` so a single storage failure does not permanently poison `_persistLock`.
   * Add lowercase fallback for ALL-CAPS lookups in `getWord()` and `hasWord()`.

2. **`frontend/lib/services/latin_ime.dart` & `frontend/lib/services/file_downloader_stub.dart`**
   * Mirror compound punctuation (`...`, `?!`, `!?`) and per-paragraph paired straight-quote (`"` → `«`/`»`) handling in `LatinIme.convertPunctuationToMenksoft`.
   * Return `bool` from `downloadFileFromBytes` (or throw on failure) so callers report write failures instead of a false success toast on desktop.

3. **`frontend/lib/main.dart`**
   * Preserve newlines in `_syncOutputText()` for `token.type == 'space'`.
   * Derive `_isModerator` from `user['isModerator']`, `user['isAdmin']`, or `user['role']` for Moderator tab visibility, `DictionaryBrowseView`, and `_fetchModeratorCount()`.
   * Reconcile `_tokens` cleanly when local words are updated/deleted in `DictionaryBrowseView`, and await `LocalDictionaryService.instance.initialize()` if not yet initialized before `_convert()`.
   * Fix `_handleWordAddedOrSuggested`: when opening "Алдаа мэдээлэх / Засах", if `menksoft` matches `targetMenksoft` (with unchanged explanation) and a non-empty `comment` is provided, submit a clean text-only report (`menksoft: ''`) without modifying `LocalDictionaryService`; avoid duplicating options in `_tokens`; add timeout & status check on `/contribute`; only report submission success after HTTP `200`; and avoid passing the user's unapproved local override spelling as `targetMenksoft`.
   * Use `LatinIme.normalizeCyrillic` in `reconcileHomonymSelections`.
   * Guard `Cmd+Enter` shortcut to `DesktopNavTab.converter`, clear `_errorMessage` on Clear, remove redundant `setState` in `TextField.onChanged`, add `mounted` + bounds checks in menu `.then()` callbacks, and dispose login dialog controllers + add login timeout.

4. **`frontend/lib/ui/dialogs/add_edit_word_dialog.dart` & Desktop Components**
   * Fix `_onLatinChanged()` unmapped Mongolian character handling, avoid hijacking `Enter` inside multi-line comment/context fields, and show validation feedback if Submit is clicked with empty required fields.
   * Fix empty-email crash in `desktop_header.dart` and pass `isModerator`.
   * Clamp `maxHeight` to viewport height minus `bottomInset` in `desktop_dialog.dart`.
   * Reset hover/pressed state in `desktop_button.dart` when disabled.

5. **Frontend Tests ([`frontend/test/`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/frontend/test/))**
   * Add unit & widget tests for `LocalDictionaryService` persistence recovery after error and all-caps fallback, `ModeratorPage` queue race/delete/reject error handling, `EditSuggestionDialog` action selector & clearing explanation & empty-menksoft validation, `DesktopHeader` empty email safety, `AddEditWordDialog` unmapped Mongolian character paste, unchanged-spelling error report submission, paired quotes, and newline preservation.

---

## Verification Workflow

After implementing the approved phases, execute the strict verification sequence from [`GEMINI.md`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/GEMINI.md):

```bash
dart format backend/ && dart format frontend/
cd backend && dart analyze --fatal-infos && dart test
cd ../frontend && flutter analyze --fatal-infos && flutter test
```

---

## Resolved Design Decisions

1. **Suggestion Rejection Scope (Bugs #1 / #4):** Rejecting a suggestion as `"Кирилл алдаатай"` or `"Үг биш"` applies strictly to the current suggestion row (`id`), preserving any sibling pending homonyms for the same Cyrillic word and leaving `unknown_logs` untouched.
2. **`EditSuggestionDialog` Action Selection (Bug #7):** When editing a suggestion for an already-existing word, `EditSuggestionDialog` renders an explicit action selector (`replace`, `add_secondary`, `add_primary`), defaulting to `replace` only when the suggestion carried an explicit `target_menksoft` from an error report and `add_secondary` otherwise.
3. **Auto-Generated `"ECK ..."` Import Notes (Bug #5):** In addition to fixing manual explanation clearing, auto-generated `"ECK ..."` notes on `eck_import` and `db_discrepancy_review` suggestions are automatically omitted (`null`) from public `definitions.explanation` on approval unless the moderator explicitly edits them into a custom meaning note.
4. **Unchanged Spelling Error Reports with Comment (Bugs #6 / #12):** In "Алдаа мэдээлэх / Засах", if the user keeps the pre-filled `menksoft` identical to `targetMenksoft` (with unchanged explanation) and writes a `comment`, the client submits a clean text-only report (`menksoft: ''`) without modifying `LocalDictionaryService`. The backend also exempts all comment-bearing suggestions from startup cleanup and `_autoResolveMatchingSuggestions`.
5. **Straight Quotes & Compound Punctuation (Bug #10):** Straight double quotes (`"`) track open/close parity per paragraph (resetting on `\n`) so pairs convert to `«...»` (`\uE259` / `\uE25A`), and multi-character punctuation (`...`, `?!`, `!?`) matches inside compound delimiter tokens in both backend `_convertDelimiter` and frontend `LatinIme.convertPunctuationToMenksoft`.
6. **Cyrillic Word Connector Alignment (Bug #19):** Underscore (`_`) is removed from `CyrillicValidator._cyrillicWordRegex` so `/contribute` and `/admin/words` match `Tokenizer` (Cyrillic letters with optional `-` or `'`).
7. **`DEPLOYMENT.md` & Implementation Timing:** Because [`DEPLOYMENT.md`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/DEPLOYMENT.md) is gitignored, its contents will remain untouched; code implementation will wait for explicit approval after reviewing this updated plan.
