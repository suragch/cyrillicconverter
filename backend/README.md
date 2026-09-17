# Cyrillic Converter Backend Server

Dart Shelf server with SQLite 3 (WAL mode) powering the Cyrillic to Traditional Mongolian conversion engine, dictionary queries, and moderation workflow.

## Endpoints

### Public Endpoints
- `GET /health`: Server health check.
- `POST /convert`: Convert Cyrillic text to Mongolian vertical tokens with options and delimiters.
- `POST /contribute`: Submit a community suggestion for a Cyrillic word definition.
- `GET /words/check?cyrillic=<word>`: Public dictionary lookup for words and rejection history.
- `GET /export/csv`: Download all approved dictionary words as CSV (`mongol_dictionary.csv`).
- `GET /export/json`: Download all approved dictionary words as JSON.
- `POST /auth/login`: Authenticate with email/password against PocketBase.
- `GET /auth/me`: Validate user session and retrieve role.

### Protected Moderator Endpoints (Requires Bearer token or `?token=`)
- `GET /admin/words/check`: Check word status with moderator permissions.
- `GET /admin/missing`: Get queue of unknown words ordered by occurrence frequency.
- `POST /admin/missing/reject`: Reject a missing word (logs to `rejected_words`).
- `GET /admin/suggestions`: Get pending user submissions.
- `POST /admin/suggestions/approve`: Approve a submission into the dictionary.
- `POST /admin/suggestions/reject`: Reject a submission (logs to `rejected_words`).
- `POST /admin/words`: Directly add or update a dictionary word definition.
- `GET /admin/db/download`: Download atomic SQLite binary snapshot (`.db`).
- `GET /admin/db/export-json`: Download complete JSON database dump.
- `POST /admin/db/seed`: Trigger background seed from legacy PocketBase upstream.

## CLI Commands

```bash
# Run server locally
dart run bin/server.dart

# Seed data from old app version
dart run bin/seed.dart --from-old-app

# Create atomic SQLite backup snapshot
dart run bin/seed.dart --export-backup backup.db

# Run tests
dart test
```
