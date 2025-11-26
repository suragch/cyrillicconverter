# Project Plan: Iterative Local Development

**Philosophy**: We build "Vertically." We don't build the whole API then the whole UI. We build the "Hello World" API, then the "Hello World" UI. Then the "Database" API, then the "Database" UI.
**Prerequisites**: Flutter SDK installed, Dart SDK installed.

---

## Phase 1: The Walking Skeleton (Connectivity)
*Goal: Get a Flutter Web app talking to a local Dart server using JSON.*

- [ ] **Step 1.1: Initialize the Server**
  - **Task**: Create a raw Dart console app that will become our API. Add `shelf` and `shelf_router` dependencies.
  - **Action**:
    1.  `mkdir backend && cd backend`
    2.  `dart create -t server-shelf . --force`
    3.  Clean up `bin/server.dart` to be a minimal "Hello World".
  - **Verification**: Run `dart bin/server.dart`. Open browser to `http://localhost:8080`. You should see "Hello, World!".

- [ ] **Step 1.2: Initialize the Frontend**
  - **Task**: Create the Flutter Web project.
  - **Action**:
    1.  `flutter create --platforms=web frontend`
    2.  Clean up `lib/main.dart` to remove the counter app. Make a simple Scaffold with a Text widget saying "Frontend Ready".
  - **Verification**: Run `cd frontend && flutter run -d chrome`. You should see the text in the browser.

- [ ] **Step 1.3: Define the Data Contract (Shared Model)**
  - **Task**: We need a standard format for the tokens.
  - **Action**: Create a simple Dart class (you can copy-paste this file into both projects for now to keep it simple).
    ```dart
    // Token Types: word, space, punctuation
    class Token {
      final String type;
      final String original; // The Cyrillic text
      final List<String> options; // Traditional translations
      // ... constructor & toJson/fromJson ...
    }
    ```
  - **Verification**: Ensure both projects compile with this class added.

- [ ] **Step 1.4: Connect FE to BE (The Echo Test)**
  - **Task**: Send text from Flutter, receive it back from Server.
  - **Server Action**: Add a POST route `/echo` that reads the body and returns `{"received": "..."}`.
  - **Frontend Action**: Add a `TextField` and a `Button`. On click, use `http` package to POST to `localhost:8080/echo`. Display result.
  - **CORS Note**: You will likely hit a CORS error. You must add `shelf_cors` headers to your server responses.
  - **Verification**: Type "Sain bainu" in Flutter, click button. See "Sain bainu" displayed back on the screen (round-trip successful).

---

## Phase 2: Core Engine & Rendering
*Goal: Render vertical Traditional Mongolian script from a mock server response.*

- [ ] **Step 2.1: Add the Font**
  - **Task**: Get the `Menksoft` font into the project.
  - **Action**:
    1.  Download a standard Mongolian font (e.g., Menksoft Qagan).
    2.  Place in `frontend/assets/fonts/`.
    3.  Update `frontend/pubspec.yaml` to include the font family.
  - **Verification**: Change a Text widget in Flutter to use `fontFamily: 'Menksoft'`. It should look different (even if rendering English characters).

- [ ] **Step 2.2: Implement Vertical Rendering**
  - **Task**: Mongolian is written top-to-bottom, left-to-right.
  - **Action**: Use a `Wrap` widget with `direction: Axis.vertical` or a `RichText` inside a RotatedBox if needed (though standard vertical layout is preferred).
  - **Verification**: Hardcode a long string of dummy Mongolian text. Ensure it wraps correctly to the next vertical line (moving right) when it hits the bottom of the screen.

- [ ] **Step 2.3: Mock Conversion API**
  - **Task**: Make the server pretend to convert.
  - **Action**: Create POST `/convert`.
    *   Input: `text`
    *   Logic: Split string by space.
    *   Response: JSON List of Tokens. Hardcode the response: If input is "Монгол", return `options: ["MenksoftCodeForMongol"]`.
  - **Verification**: Use `curl -X POST -d '{"text":"Монгол"}' http://localhost:8080/convert`. Check the JSON response.

- [ ] **Step 2.4: Integrate Rendering**
  - **Task**: Flutter takes the JSON list and builds the UI widgets.
  - **Action**: Iterate through the List of Tokens. Create a `Text` widget for each.
  - **Verification**: Type "Монгол" in the input. Click Convert. The Output area should show the vertical Menksoft glyphs.

---

## Phase 3: The Real Database (SQLite)
*Goal: Replace hardcoded mocks with real data lookups.*

- [ ] **Step 3.1: Database Setup**
  - **Task**: Setup SQLite in the backend.
  - **Action**:
    1.  Add `sqlite3` to backend `pubspec.yaml`.
    2.  Create a `bin/setup_db.dart` script.
    3.  Write SQL to create tables: `words`, `definitions`.
    4.  Insert 5-10 test words (include a homonym like "bank").
  - **Verification**: Run the script. A `dictionary.db` file should appear. Use a SQLite viewer (or VS Code extension) to verify the rows exist.

- [ ] **Step 3.2: Tokenizer & Lookup Logic**
  - **Task**: The server needs to intelligently parse the string.
  - **Action**:
    1.  Regex split: `(\s+|[.,!?]+|[а-яА-ЯөӨүҮ]+)`.
    2.  Loop through tokens. If it's a word, query `SELECT * FROM words JOIN definitions ...`.
    3.  Construct the `Token` object with the results.
  - **Verification**: Send "bank" to the API via Curl. It should return a Token with *two* options (financial bank and river bank) because you seeded it in Step 3.1.

- [ ] **Step 3.3: Unknown Word Handling (The "Red" State)**
  - **Task**: Handle words not in the DB.
  - **Action**:
    1.  **Backend**: If Query returns 0 rows, create a Token with `type: 'unknown'` and `options: []`. Log to `unknown_logs` table (create this table if not exists).
    2.  **Frontend**: In the render loop, if `type == 'unknown'`, style the Text widget with a red wavy underline.
  - **Verification**: Type "NonExistentWord" in Flutter. Click Convert. Result should be the original Cyrillic word with a red underline. Check `dictionary.db` -> `unknown_logs` table; count should be 1.

---

## Phase 4: Interactivity (The "Blue" State & Fixes)
*Goal: Allow the user to interact with the results.*

- [ ] **Step 4.1: Ambiguity UI (The "Blue" State)**
  - **Task**: Handle words with multiple definitions.
  - **Action**:
    1.  **Backend**: Ensure `Token` JSON includes `explanation` for each option.
    2.  **Frontend**: If `options.length > 1`, style with Blue Dotted Line.
    3.  **Frontend Interaction**: Wrap the Text widget in a `GestureDetector` or `MenuAnchor`. On click, show a dropdown of options. Selecting one updates the displayed text.
  - **Verification**: Convert "bank" (from your seed data). It should have a blue line. Click it. Select the other meaning. The text should change.

- [ ] **Step 4.2: Local Persistence (Hive)**
  - **Task**: Save user preferences/fixes.
  - **Action**:
    1.  Add `hive` and `hive_flutter` to Frontend.
    2.  Initialize Hive in `main.dart`. Open a box named `user_overrides`.
    3.  Create a helper: `String? getOverride(String cyrillicWord)`.
  - **Verification**: Manually put a value in Hive (via code). Run the app. Ensure the conversion engine checks Hive *before* using the API result.

- [ ] **Step 4.3: The "Fix" Dialog**
  - **Task**: Let users fix unknown words.
  - **Action**:
    1.  On clicking a **Red** word, show a Dialog.
    2.  Input field: "Traditional Spelling".
    3.  Save Button: Writes to Hive `user_overrides`.
  - **Verification**: Convert "UnknownWord". Click Red line. Type "NewSpelling". Save. The Red line should vanish, replaced by "NewSpelling". Refresh the page. Convert "UnknownWord" again. It should immediately show "NewSpelling" (loaded from local Hive).

---

## Phase 5: Feedback Loop
*Goal: Send user fixes back to the server.*

- [ ] **Step 5.1: Contribution API**
  - **Task**: Endpoint to receive suggestions.
  - **Action**:
    1.  **Backend**: Create `POST /contribute`.
    2.  Body: `{ cyrillic, menksoft, context }`.
    3.  Insert into `suggestions` table.
  - **Verification**: Curl POST a suggestion. Check SQLite table.

- [ ] **Step 5.2: Connect Frontend Fix to API**
  - **Task**: When user saves locally, also tell the server.
  - **Action**: Update the "Save" button logic in Step 4.3. After writing to Hive, fire an async HTTP POST to `/contribute`.
  - **Verification**: Perform a fix in the UI. Check the backend `suggestions` table.

---

## Phase 6: Deployment Prep
*Goal: Containerize only after everything works.*

- [ ] **Step 6.1: Dockerfile for Backend**
  - **Task**: Image for Dart Shelf.
  - **Action**: Create `backend/Dockerfile`. Standard Dart server build.
  - **Verification**: `docker build -t mongo-api ./backend`. Run it. `curl localhost:8080/echo`.

- [ ] **Step 6.2: Dockerfile for Frontend (Nginx)**
  - **Task**: Build Flutter Web and serve via Nginx.
  - **Action**:
    1.  `flutter build web --web-renderer canvaskit`.
    2.  Create `frontend/Dockerfile` that copies `build/web` to `/usr/share/nginx/html`.
  - **Verification**: Build and run. Open localhost:80.

- [ ] **Step 6.3: Compose**
  - **Task**: Orchestrate.
  - **Action**: Create `docker-compose.yml` linking the two. Map the SQLite volume so data persists.
  - **Verification**: `docker-compose up`. Full system test.

---