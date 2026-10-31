# Dictionary Browse View (`frontend/lib/ui/dictionary`)

## Overview
Dictionary lookup and exploration interface for querying words, viewing vertical script options, and submitting missing words.

## Interface
- `[dictionary_browse_view.dart:DictionaryBrowseView]`: Search view displaying Cyrillic terms with vertical Mongolian glyphs, Latin transliterations, multiple homonyms, primary tags, moderator rejection history, and word suggestion modals.

## Invariants
- `[dictionary_browse_view.dart:DictionaryBrowseView]`: When authenticated as moderator, queries `/admin/words/check`, reveals past rejection reasons, and enables direct addition (`/admin/words`); guest queries use `/words/check` and route to `/contribute`.

## Side Effects
- `[dictionary_browse_view.dart:DictionaryBrowseView]`: Sends HTTP GET requests to `/words/check` or `/admin/words/check`, HTTP POST requests to `/admin/words` or `/contribute`, copies Unicode to clipboard, and triggers `onDownloadDictionary`.

## Verification
- Run: `cd frontend && flutter test`
