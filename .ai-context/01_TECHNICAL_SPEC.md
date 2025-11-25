# Cyrillic-Traditional Mongolian Converter: Technical Specification

## 1. System Architecture

### 1.1. Overview
The system follows a separated Client-Server model.
1.  **Frontend (Flutter Web)**: Handles the UI, rendering Traditional Script, and managing local user overrides.
2.  **Conversion API (Dart Shelf)**: The heavy lifter. Connects directly to a specialized SQLite dictionary database for high-performance lookups. Logs unknown word frequencies.
3.  **Auth & User Management (PocketBase)**: Handles authentication, user sessions, and profile management.
4.  **Database Strategy**: Hybrid.
    *   **Dictionary.db (SQLite)**: Managed by Dart Shelf. Stores words, definitions, and frequency logs. Optimized for read speed.
    *   **pb_data (SQLite)**: Managed by PocketBase. Stores users, roles, and auth tokens.

### 1.2. High-Level Diagram

```mermaid
graph TD
    subgraph "Client (Flutter Web)"
        UI[User Interface]
        LocalStore[Hive (Local Overrides)]
        UI -- 1. Submit Text --> API
        UI -- 4. Render JSON --> UI
        UI -- 5. User Fix --> LocalStore
    end

    subgraph "Backend (Docker)"
        API[Dart Shelf API]
        PB[PocketBase (Auth)]
        
        DictDB[(Dictionary.db - SQLite)]
        
        API -- 2. Lookup/Log --> DictDB
        API -- 3. Verify Token --> PB
    end
```

### 1.3. Data Flow: Conversion

1.  **Input**: User sends a large string of Cyrillic text to `POST /api/convert`.
2.  **Tokenization**: Server splits text into tokens (words, punctuation, whitespace).
3.  **Lookup**:
    *   API queries `Dictionary.db`.
    *   If word found: Retrieve all Menksoft variations and context hints.
    *   If word NOT found: Increment counter in `UnknownWordLogs` table. Return original Cyrillic.
4.  **Response**: Server returns a JSON structure: `List<Token>`.
5.  **Client Processing**:
    *   Flutter app iterates through the list.
    *   Checks `LocalStore` (Hive) to see if the user has a personal override for this Cyrillic word. If yes, use that.
    *   Renders the text.
        *   **Red Underline**: Unknown word (Cyrillic).
        *   **Blue Underline**: Ambiguous word (Multiple options available).

## 2. Technology Stack

*   **Frontend**: Flutter Web (CanvasKit).
*   **Local Persistence**: Hive (NoSQL, fast, pure Dart) for storing user's personal dictionary overrides.
*   **Backend API**: Dart (Shelf framework).
*   **Authentication**: PocketBase (Go-based, acts as Auth provider).
*   **Database**: SQLite (accessed via `sqlite3` Dart package in Shelf).
*   **Deployment**: Docker Compose.

## 3. Data Models (Dictionary.db - SQLite)

This database is managed exclusively by the Dart Shelf API.

### 3.1. `words`
The Cyrillic entry points.
```sql
CREATE TABLE words (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    cyrillic TEXT NOT NULL UNIQUE,
    is_abbreviation BOOLEAN DEFAULT 0
);
CREATE INDEX idx_cyrillic ON words(cyrillic);
```

### 3.2. `definitions`
The Traditional Mongolian mappings. One-to-many relationship with `words`.
```sql
CREATE TABLE definitions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    word_id INTEGER NOT NULL,
    menksoft_code TEXT NOT NULL, -- The specific Traditional script string
    explanation TEXT, -- Context hint (e.g., "The bank (money)", "The bank (river)")
    is_primary BOOLEAN DEFAULT 0, -- Default choice if no user intervention
    FOREIGN KEY(word_id) REFERENCES words(id)
);
```

### 3.3. `unknown_logs`
Tracks frequency of missing words to guide moderation.
```sql
CREATE TABLE unknown_logs (
    cyrillic TEXT PRIMARY KEY,
    frequency INTEGER DEFAULT 1,
    last_seen TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### 3.4. `suggestions`
User submissions waiting for approval.
```sql
CREATE TABLE suggestions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    cyrillic TEXT NOT NULL,
    menksoft_code TEXT NOT NULL,
    context_snippet TEXT NULL, -- Optional, user opt-in
    user_id TEXT, -- From PocketBase
    status TEXT DEFAULT 'pending' -- pending, approved, rejected
);
```

## 4. API Endpoints (Dart Shelf)

### `POST /convert`
*   **Body**: `{ "text": "Би банк руу явлаа." }`
*   **Logic**: Tokenizes, looks up DB, logs unknown words.
*   **Response**:
    ```json
    {
      "tokens": [
        { "type": "word", "src": "Би", "options": [{"val": "...", "hint": "I", "default": true}] },
        { "type": "space", "val": " " },
        { "type": "word", "src": "банк", "options": [
            {"val": "...", "hint": "financial", "default": true}, 
            {"val": "...", "hint": "river edge", "default": false}
          ] 
        },
        ...
      ]
    }
    ```

### `POST /contribute`
*   **Body**: `{ "cyrillic": "...", "menksoft": "...", "context": "..." }`
*   **Logic**: Inserts into `suggestions` table.

### `GET /admin/stats` (Moderator Only)
*   **Logic**: Returns top 100 rows from `unknown_logs` ordered by frequency DESC.

## 5. Flutter Implementation Details

### 5.1. Rendering Engine
*   Flutter Web using `CanvasKit` is required for pixel-perfect rendering of the vertical Mongolian script, specifically to handle ligature joining correctly which HTML/DOM renderers often break.

### 5.2. State Management
*   **Provider** or **Riverpod**.
*   **Controller**: `ConversionController` holds the list of Tokens. It has methods like `selectOption(index, option)` which updates the UI instantly.

### 5.3. Local Overrides
*   When a user clicks a Red word and "Fixes" it, the app:
    1.  Saves `{cyrillic: menksoft}` to Hive (Local Browser Storage).
    2.  Sends the suggestion to the API (fire and forget).
    3.  Re-renders the view using the local override.