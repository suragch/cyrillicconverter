# Frontend Services (`frontend/lib/services`)

## Overview
Platform services handling cross-platform file downloading (Web DOM Blob vs Desktop I/O) and Latin-to-Menksoft/Unicode Mongolian transliteration.

## Interface
- `[file_downloader.dart:downloadFileFromBytes]`: Cross-platform binary file saver routing to `$HOME/Downloads` on Desktop/CLI or DOM Blob download on Web.
- `[file_downloader.dart:downloadFileFromUrl]`: Cross-platform URL download initiator.
- `[latin_ime.dart:LatinIme]`: Transliteration and script utility offering `latinToMenksoft`, `menksoftToUnicode`, `menksoftToLatin`, `isAbbreviation`, `normalizeCyrillic`, `containsMongolianScript`, `convertToLatin`, `convertMongolianUnicodeToLatin`, `convertPunctuationToMenksoft`, and `convertLatinToMongolianUnicode`.
- `[local_dictionary_service.dart:LocalDictionaryService]`: Reactive `ChangeNotifier` singleton providing in-memory O(1) dictionary lookups backed by `SharedPreferences` with sequential Future-chained disk serialization. Offers `initialize`, `hasWord`, `getWord`, `addOrUpdateWord`, `deleteWord`, `purgeWords`, and `clearAll`.

## Invariants
- `[local_dictionary_service.dart:LocalDictionaryService]`: Defensively normalizes all Cyrillic keys via `LatinIme.normalizeCyrillic`. Disk writes are strictly serialized via `_persistLock` to prevent concurrent write races. Synchronous memory lookups never block rendering frames.
- `[latin_ime.dart:LatinIme]`: Abbreviations matching uppercase patterns preserve casing during normalization; regular words are lowercased. Narrow No-Break Space (U+202F) and MVS map to hyphen. Numeric characters are guarded from FVS conversions.
- `[file_downloader_stub.dart:downloadFileFromBytes]`: Falls back to `Directory.current` if `$HOME/Downloads` is unreachable.

## Side Effects
- `[file_downloader_stub.dart:downloadFileFromBytes]`: Synchronously writes binary bytes to disk.
- `[file_downloader_web.dart:downloadFileFromBytes]`: Manipulates browser DOM by appending anchor element, initiating click event, and revoking object URLs.

## Verification
- Run: `cd frontend && flutter test`
