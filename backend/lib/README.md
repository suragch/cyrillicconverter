# Backend Core Domain and Data Library (`backend/lib`)

## Overview
Core domain and infrastructure library for the Cyrillic-to-Traditional Mongolian conversion backend. Contains lossless text tokenization, Cyrillic script validation and case-preserving normalization, an optimized SQLite dictionary engine with homonym resolution, moderation auditing, and backup snapshotting, PocketBase authentication middleware with role-based access control, and serializable token models.

## Interface
- `[auth_middleware.dart:AuthContext]`: Immutable context holding authenticated `RecordModel? user`, `bool isModerator`, `bool isAdmin`, and `String? token`.
- `[auth_middleware.dart:pocketBaseAuth]`: Shelf Middleware authenticating Bearer tokens via PocketBase users and `_superusers` collections or test bypass environment tokens.
- `[auth_middleware.dart:requireModerator]`: Shelf Handler wrapper enforcing moderator or admin authorization, returning HTTP 403 on failure.
- `[auth_middleware.dart:requireAdmin]`: Shelf Handler wrapper enforcing admin authorization, returning HTTP 403 on failure.
- `[cyrillic_validator.dart:CyrillicValidator.isCyrillicWord]`: Validates whether input text consists strictly of Cyrillic characters and hyphen/apostrophe/underscore connectors.
- `[cyrillic_validator.dart:CyrillicValidator.isAbbreviation]`: Detects standalone uppercase Cyrillic abbreviations and suffixed abbreviations (e.g., 'МУИС', 'УИХ-ын').
- `[cyrillic_validator.dart:CyrillicValidator.normalizeWord]`: Normalizes word casing while strictly preserving uppercase for abbreviations.
- `[database.dart:AppDatabase]`: SQLite dictionary service managing words, definitions, homonyms, unknown logs, suggestions, and audit rejections.
- `[database.dart:AppDatabase.open]`: Factory establishing SQLite connection configured with WAL mode, normal synchronous writes, and foreign key cascades.
- `[database.dart:AppDatabase.initSchema]`: Initializes table schemas (`words`, `definitions`, `unknown_logs`, `suggestions`, `rejected_words`) and associated indexes.
- `[database.dart:AppDatabase.lookupWord]`: Queries dictionary definitions for a Cyrillic term, honoring case-sensitive abbreviation matching before lowercase fallback.
- `[database.dart:AppDatabase.logUnknownWord]`: Logs or increments frequency counter and context snippet for missing Cyrillic terms.
- `[database.dart:AppDatabase.addSuggestion]`: Submits a community word definition proposal into the pending moderation queue.
- `[database.dart:AppDatabase.getTopUnknownWords]`: Fetches frequency-ranked missing word queue for review.
- `[database.dart:AppDatabase.getPendingSuggestions]`: Fetches pending community word suggestions.
- `[database.dart:AppDatabase.addWordDefinition]`: Adds or updates word definitions, maintaining single-primary definition status.
- `[database.dart:AppDatabase.approveSuggestion]`: Approves suggestion, creates dictionary entry, purges unknown log, and redacts usage context.
- `[database.dart:AppDatabase.rejectSuggestion]`: Rejects suggestion, records audit entry in `rejected_words`, and purges usage context.
- `[database.dart:AppDatabase.rejectMissingWord]`: Rejects unknown word log, records audit entry, and deletes log entry.
- `[database.dart:AppDatabase.getRejectionHistory]`: Retrieves historical rejections for a word.
- `[database.dart:AppDatabase.getWordCount]`: Retrieves total count of words in dictionary.
- `[database.dart:AppDatabase.createBackupSnapshot]`: Creates atomic SQLite binary snapshot using `VACUUM INTO`.
- `[database.dart:AppDatabase.getApprovedWordsJson]`: Exports approved words and definitions as JSON-serializable list.
- `[database.dart:AppDatabase.getFullDatabaseJson]`: Exports full database contents across all tables.
- `[database.dart:AppDatabase.seedFromOldApp]`: Synchronizes legacy words collection from PocketBase REST API.
- `[database.dart:AppDatabase.close]`: Releases underlying SQLite database connection.
- `[token.dart:Token]`: Represents converted token containing original Cyrillic text, resolved Menksoft vertical text, type, and candidate options.
- `[token.dart:TokenOption]`: Represents candidate Traditional Mongolian Menksoft translation with definition explanation and primary/default flag.
- `[tokenizer.dart:TokenType]`: Enum representing token lexical classes (word, space, delimiter).
- `[tokenizer.dart:RawToken]`: Immutable representation of a lexical chunk with its `TokenType` and literal string text.
- `[tokenizer.dart:Tokenizer.tokenize]`: Losslessly decomposes input text into a sequence of `RawTokens` preserving all whitespace, newlines, and punctuation.

## Invariants
- `[tokenizer.dart:Tokenizer.tokenize]`: Lossless text invariant: `tokens.map((t) => t.text).join() == input` for any arbitrary input string.
- `[cyrillic_validator.dart:CyrillicValidator.isCyrillicWord]`: Pure Cyrillic invariant: strictly rejects any token containing Latin characters, Arabic numerals, or non-connector symbols.
- `[cyrillic_validator.dart:CyrillicValidator.normalizeWord]`: Case integrity invariant: abbreviations retain uppercase to prevent collision between distinct words and acronyms (e.g. 'АН' vs 'ан').
- `[database.dart:AppDatabase.lookupWord]`: Definition ordering invariant: definitions are returned sorted by `is_primary DESC, id ASC`, ensuring the primary homonym is selected first.
- `[database.dart:AppDatabase.addWordDefinition]`: Single-primary invariant: adding a primary definition demotes existing primary definitions for the same word ID to `is_primary = 0`.
- `[database.dart:AppDatabase.approveSuggestion]` and `[database.dart:AppDatabase.rejectSuggestion]`: Privacy preservation invariant: clears user document context to `NULL` upon moderation to prevent persisting sensitive sentences.
- `[database.dart:AppDatabase.initSchema]`: Referential integrity invariant: `FOREIGN KEY(word_id) REFERENCES words(id) ON DELETE CASCADE` automatically purges definitions if a word record is removed.
- `[auth_middleware.dart:AuthContext]`: Unauthenticated fail-safe invariant: requests with missing, malformed, or failed Bearer tokens receive `const AuthContext()` with non-privileged flags rather than throwing unhandled exceptions.
- `[auth_middleware.dart:requireModerator]` and `[auth_middleware.dart:requireAdmin]`: Guard invariant: non-authorized requests are rejected with HTTP 403 Forbidden before reaching inner Shelf handlers.
- `[token.dart:Token.fromJson]` and `[token.dart:TokenOption.fromJson]`: Non-null safe fallback invariant: missing option arrays fall back to `[]`, and missing `isDefault` falls back to `false`.

## Side Effects
- `[database.dart:AppDatabase]`: Reads, inserts, updates, and deletes records on local SQLite database (`dictionary.db`); manages WAL journal files.
- `[database.dart:AppDatabase.createBackupSnapshot]`: Deletes destination file if pre-existing and executes disk I/O snapshot via `VACUUM INTO`.
- `[database.dart:AppDatabase.seedFromOldApp]`: Makes outbound network HTTP GET requests to PocketBase API; commits SQLite batch transactions.
- `[database.dart:AppDatabase.close]`: Closes SQLite connection and releases file system locks.
- `[auth_middleware.dart:pocketBaseAuth]`: Reads `Platform.environment` (`TEST_ADMIN_TOKEN`, `TEST_MODERATOR_TOKEN`); executes outbound HTTP auth refresh requests to PocketBase; mutates Shelf `request.context`.
- `[auth_middleware.dart:requireModerator]` and `[auth_middleware.dart:requireAdmin]`: Terminates HTTP pipeline early with 403 response on missing privileges.

## Verification
- Run: `cd backend && dart test`
