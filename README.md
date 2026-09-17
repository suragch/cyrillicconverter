# Cyrillic to Traditional Mongolian Converter (ᠮᠣᠩᠭᠣᠯ ᠬᠥᠪᠢᠷᠭᠦᠯᠦᠭᠴᠢ)

A high-performance web and desktop suite for converting Mongolian Cyrillic text into Traditional Mongolian vertical script (`ᠮᠣᠩᠭᠣᠯ ᠪᠢᠴᠢᠭ`), resolving homonyms, managing dictionary definitions, and crowd-sourcing missing words via an administrative moderation workflow.

---

## System Architecture

- **Frontend (`frontend/`)**: Modern Flutter desktop-style workspace with native Menksoft font glyph rendering, vertical mouse drag selection, hover inspect, split-pane layout, zoom controls, and persistent authentication.
- **Backend (`backend/`)**: High-throughput Dart server built with Shelf and SQLite in WAL mode. Features Cyrillic validation, rate limiting, token authentication via PocketBase, atomic database snapshots, and data export.
- **Data Model**:
  - `words` & `definitions`: 17,850+ verified Cyrillic-to-Traditional-Mongolian entries with primary and secondary homonym flags.
  - `unknown_logs`: Automatically aggregates unknown Cyrillic words with occurrence frequency and sentence context.
  - `suggestions`: Community submissions awaiting moderator review.
  - `rejected_words`: Complete historical audit log of rejected entries (misspellings or invalid tokens).

---

## Quick Start (Local Development)

### 1. Backend Server

```bash
cd backend
dart pub get

# Run server (defaults to port 8080 and dictionary.db)
dart run bin/server.dart
```

### 2. Frontend App

```bash
cd frontend
flutter pub get

# Run in Chrome (Web)
flutter run -d chrome

# Or run natively on macOS
flutter run -d macos
```

---

## Data Seeding & Migrations

When publishing to a new server or initializing a fresh database, you can populate the dictionary from the previous version of the app (`cyrillic.suragch.dev`):

### Option A: Automatic On-Boot Seeding
Set the `AUTO_SEED=true` environment variable when starting the server:
```bash
AUTO_SEED=true DB_PATH=/data/dictionary.db dart run bin/server.dart
```
If the database contains 0 words, it will automatically connect to upstream PocketBase and import all 17,858+ records.

### Option B: CLI Seeder Tool
```bash
cd backend
# Seed from the old app upstream
dart run bin/seed.dart --from-old-app

# Seed with a custom upstream URL
dart run bin/seed.dart --from-old-app --url https://cyrillic.suragch.dev/api/collections/words/records

# Seed from a JSON dump
dart run bin/seed.dart --from-json /path/to/dump.json
```

### Option C: Remote Web UI Seeding
Logged-in moderators and administrators can click **"Хуучин системээс татах (Seed)"** directly inside the Moderator Station UI to trigger background synchronization.

---

## Data Downloading & Backups

### 1. Public Download (Any User)
- **CSV Format**: `GET /export/csv` $\rightarrow$ downloads `mongol_dictionary.csv`.
- **JSON Format**: `GET /export/json` $\rightarrow$ downloads `mongol_dictionary.json`.
- **In UI**: Click the **"Толь татах (CSV)"** button in the header toolbar or inside the Dictionary Quick Lookup tab.

### 2. Full Database Download (Moderators & Admins Only)
- **SQLite Binary (`.db`)**: `GET /admin/db/download` (Requires Bearer token or `?token=` parameter). Uses SQLite `VACUUM INTO` for a non-blocking, zero-corruption snapshot containing all 5 database tables.
- **Full JSON Dump**: `GET /admin/db/export-json` $\rightarrow$ downloads complete JSON database dump.
- **In UI**: Log in as a moderator, open the Moderator Station tab, and click **"Бааз татах (.db)"**.

---

## Production Deployment (Docker)

The backend includes an optimized multi-stage `Dockerfile` utilizing `dart build cli` and a minimal Debian runtime with SQLite3 C libraries.

```bash
# Build Docker image
docker build -t mongol-converter-backend backend/

# Run container with persistent storage volume
docker run -d \
  -p 8080:8080 \
  -v $(pwd)/data:/data \
  -e DB_PATH=/data/dictionary.db \
  -e AUTO_SEED=true \
  --name converter-backend \
  mongol-converter-backend
```

### Environment Variables Reference

| Variable | Default | Description |
| :--- | :--- | :--- |
| `PORT` | `8080` | HTTP port for the server. |
| `DB_PATH` | `dictionary.db` | Absolute or relative path to the SQLite database. Mount to persistent storage. |
| `AUTO_SEED` | `false` | When `true`, automatically seeds an empty database from the old app on boot. |
| `OLD_APP_URL` | `https://cyrillic.suragch.dev/...` | PocketBase upstream API endpoint for legacy records. |
| `POCKETBASE_URL` | `http://127.0.0.1:8090` | PocketBase auth service URL for validating moderator sessions. |
| `CORS_ORIGIN` | `*` | Allowed CORS origin (set to your domain in production). |

---

## Frontend Web Build & Deployment

Build optimized production web assets:
```bash
cd frontend
flutter build web --release --dart-define=API_BASE_URL=https://api.yourdomain.com
```

Deploy the contents of `frontend/build/web/` to any static hosting provider (Cloudflare Pages, Firebase Hosting, Nginx, or Netlify). Ensure the host serves `.ttf` fonts with appropriate `Cache-Control` headers.

---

## Testing & Quality Assurance

Run automated unit and integration test suites:

```bash
# Backend test suite (23 tests)
cd backend && dart test

# Backend static analysis
cd backend && dart analyze

# Frontend test suite (11 widget and unit tests)
cd frontend && flutter test

# Frontend static analysis
cd frontend && flutter analyze
```
