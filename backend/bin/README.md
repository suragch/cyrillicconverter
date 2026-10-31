# Backend Executables and Server CLI (`backend/bin`)

## Overview
CLI binaries, database migration/seeding scripts, and HTTP REST server entry points for the Cyrillic to Traditional Mongolian conversion engine.

## Interface
- `[migrate_seed.dart:main]`: Standalone migration script migrating vocabulary records from legacy PocketBase API to SQLite `dictionary.db`.
- `[seed.dart:main]`: Multi-mode CLI tool for database seeding, dump ingestion, and snapshot backups.
- `[seed.dart:printUsage]`: CLI usage and parameter help printer.
- `[seed.dart:--from-old-app]`: CLI flag to seed vocabulary from legacy PocketBase API.
- `[seed.dart:--url]`: CLI flag specifying custom upstream PocketBase API endpoint.
- `[seed.dart:--from-json]`: CLI flag to import word definitions or complete database dump from JSON file.
- `[seed.dart:--export-json]`: CLI flag to export complete database tables to JSON file.
- `[seed.dart:--export-backup]`: CLI flag to export atomic SQLite snapshot file via `VACUUM INTO`.
- `[seed.dart:--db]`: CLI flag to specify target SQLite database file path.
- `[server.dart:main]`: Primary HTTP REST server daemon listening on `PORT` (default 8080) and serving conversion, lookup, and moderation APIs.
- `[server.dart:_router]`: Shelf Router defining public, moderator-protected, and admin-only endpoints.
- `[server.dart:payloadLimitMiddleware]`: Shelf middleware enforcing maximum HTTP request body size (default 10MB).
- `[server.dart:corsMiddleware]`: Shelf middleware handling CORS preflight `OPTIONS` and adding cross-origin headers.
- `[server.dart:privacySafeLogRequests]`: Shelf logging middleware stripping sensitive query parameters from access logs.
- `[server.dart:_convertDelimiter]`: Utility converting standard punctuation marks to Menksoft vertical Unicode glyphs.
- `[server.dart:_sanitizeContextSnippet]`: Sanitizer redacting URLs, emails, and long numbers (`[...]`) from unknown word sentence context snippets.
- `[server.dart:_shouldLogUnknownWord]`: Cache-backed rate limiter deduplicating unknown word logging within a 30-minute rolling window per client session/IP.
- `[setup_db.dart:main]`: Database initialization script creating base tables (`words`, `definitions`, `unknown_logs`, `suggestions`), index `idx_cyrillic`, and starter seed words.

## Invariants
- `[server.dart:main]`: Must open and initialize `AppDatabase` schema before mounting routes; if `AUTO_SEED=true` and database is empty, automatically seeds from `OLD_APP_URL`.
- `[server.dart:payloadLimitMiddleware]`: Rejects HTTP payloads exceeding `maxBytes` (default 10MB) with HTTP status 413.
- `[server.dart:_shouldLogUnknownWord]`: Deduplicates unknown word submissions per client within a 30-minute window (`_unknownWordDedupWindow`) and caps cache size at 10,000 entries to prevent memory exhaustion.
- `[server.dart:_convertHandler]`: Only logs unknown words if token passes `CyrillicValidator.isCyrillicWord` and sanitizes context snippets before persisting when `saveContext=true`.
- `[server.dart:_router]`: All moderator routes (`/admin/words/check`, `/admin/missing`, `/admin/suggestions/*`, `/admin/words`) require valid token and moderator role via `requireModerator`; admin routes (`/admin/db/*`, `/admin/moderators`) require `requireAdmin`.
- `[seed.dart:main]`: Always closes database connection via `finally { appDb.close(); }` regardless of whether operation succeeds or throws.
- `[seed.dart:--from-json]`: Wraps batch word imports and full database restore operations in atomic SQLite transactions (`BEGIN TRANSACTION; ... COMMIT;`).
- `[migrate_seed.dart:main]`: Lowercases Cyrillic terms before insertion, sets `is_primary = 1` only for the first definition of a word, and executes each 500-record page within a transaction rollback block.
- `[setup_db.dart:main]`: Executes idempotent DDL statements (`CREATE TABLE IF NOT EXISTS`, `CREATE INDEX IF NOT EXISTS`) and closes prepared statements and connection on completion.

## Side Effects
- `[server.dart:main]`: Binds and listens on TCP socket `InternetAddress.anyIPv4:PORT`.
- `[server.dart:_adminDbDownloadHandler]`: Creates temporary SQLite backup snapshot in system temp directory and deletes it after streaming response.
- `[server.dart:_adminAddModeratorHandler]`: Creates user records with moderator role in external PocketBase service over HTTP.
- `[server.dart:_convertHandler]`: Mutates SQLite `unknown_logs` table (inserts new unknown words or increments occurrence frequencies).
- `[server.dart:_contributeHandler]`: Writes new word suggestions to SQLite `suggestions` table.
- `[migrate_seed.dart:main]`: Performs HTTP GET requests to legacy PocketBase API and performs bulk inserts into `words` and `definitions` tables in `dictionary.db`.
- `[seed.dart:main]`: Reads and writes filesystem files (JSON dumps and `.db` SQLite snapshots) and accesses PocketBase API over network when `--from-old-app` is specified.
- `[setup_db.dart:main]`: Creates or writes to SQLite file `dictionary.db` on disk and seeds starter word rows.

## Verification
- Run: `cd backend && dart test`
