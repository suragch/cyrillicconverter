# Moderator Workstation (`frontend/lib/ui/moderator`)

## Overview
Moderator queue management view for reviewing community suggestions, defining missing words, and downloading database snapshots.

## Interface
- `[moderator_page.dart:ModeratorPage]`: Queue review workstation supporting single-key hotkey triage (1, 2, 3, E, Space, arrows), suggestion approval/rejection, missing word frequency threshold filtering, and SQLite backup download.
- `[edit_suggestion_dialog.dart:EditSuggestionDialog]`: Modal dialog for updating Cyrillic spelling, Latin transliteration, and homonym clarification notes prior to approval.

## Invariants
- `[moderator_page.dart:ModeratorPage]`: Full database backup (`.db`) download button is strictly visible only when `isAdmin` is true. Approving an existing homonym requires clarification notes or explicit override confirmation.
- `[edit_suggestion_dialog.dart:EditSuggestionDialog]`: Debounces Cyrillic spelling changes by 350ms to query dictionary for collision detection.

## Side Effects
- `[moderator_page.dart:ModeratorPage]`: Sends HTTP requests to `/admin/missing`, `/admin/suggestions`, `/admin/suggestions/approve`, `/admin/suggestions/reject`, `/admin/missing/reject`, `/admin/words`, and `/admin/db/download`; triggers file download via `downloadFileFromBytes`; invokes `onCountChanged` callback.
- `[edit_suggestion_dialog.dart:EditSuggestionDialog]`: Queries `/admin/words/check` via HTTP GET, accesses clipboard, and invokes `onSave` callback.

## Verification
- Run: `cd frontend && flutter test`
