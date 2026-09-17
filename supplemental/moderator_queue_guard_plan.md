# Implementation Plan: Cyrillic-Only Queue Ingestion & Pragmatic Filtering

## Goal Description
Refine how unknown words and suggestions enter and are displayed in the moderator queue, aligning with the project's exact requirements:
1. **No input word limits**: If a user pastes a large text, all unknown words from that text will be logged.
2. **Strict Cyrillic-only validation**: Only Cyrillic text is accepted and logged. Tokens containing Latin characters, digits, URLs, or non-Cyrillic symbols are strictly filtered out.
3. **No aggressive linguistic over-filtering**: Single letters (e.g. `в`, `г`, `а`) and consonant strings (e.g. abbreviations `УИХ`, `ХХК`, `МХЕГ`) are fully allowed.
4. **Assume good actors initially**: No complex IP or user banning system is needed at this stage.
5. **Tolerate moderator mistakes & specialized terminology**: Words previously marked as misspelled or not a word are **not** permanently hard-blocked. Previous rejections are shown as informative badges on the card without preventing future review.
6. **High signal-to-noise ratio for moderators**: Missing words queue defaults to `frequency >= 2` so one-off typos don't clutter daily review, while providing a toggle to view `Бүгд (>= 1)` at any time.

---

## Architecture & Flow

```mermaid
flowchart TD
    Req[Incoming Text to /convert or /contribute] --> CyrillicCheck{Is it strictly Cyrillic text?\nNo Latin, digits, or symbols}
    CyrillicCheck -- No --> IgnoreToken[Do not log into unknown_logs\nReject suggestion with 400]
    CyrillicCheck -- Yes --> LogAll[Log all unknown words to unknown_logs\nNo per-request quantity limits]
    
    LogDb[unknown_logs Database Table] --> ModFilter{Moderator View Filter}
    ModFilter -- Default: Frequency >= 2 --> HighSignal[High-Priority Review Queue\nReal missing words with repeated searches]
    ModFilter -- Toggle: All >= 1 --> FullQueue[Full Review Queue\nIncludes single-occurrence words]
    
    HighSignal --> CheckHistory{In rejected_words history?}
    FullQueue --> CheckHistory
    CheckHistory -- Yes --> ShowBadge[Display Info Badge on Card:\n'Өмнө нь 1 удаа шалгагдсан: [Шалтгаан]']
    CheckHistory -- No --> NormalCard[Standard Card Review]
```

---

## Proposed Changes

### 1. Cyrillic Validation (`backend/lib/cyrillic_validator.dart`)

#### [NEW] `backend/lib/cyrillic_validator.dart`
Create a focused validator ensuring only genuine Cyrillic text is accepted:
- **Strict Cyrillic Pattern**:
  ```dart
  static final RegExp _cyrillicWordRegex = RegExp(
    r"^[а-яёөүА-ЯЁӨҮ]+(?:[-'_][а-яёөүА-ЯЁӨҮ]+)*$",
    caseSensitive: false,
  );
  ```
- **Rules**:
  - Contains strictly Cyrillic letters (supports standard Cyrillic `а-я` and Mongolian vowels `ө, ү`).
  - Supports valid hyphens/connectors in compound words.
  - Allows single letters (`а`, `б`, `в`, `г`, `д`, etc.).
  - Allows consonant strings (`УИХ`, `ХХК`, `МХЕГ`, etc.).
  - Strictly rejects: Latin characters (`a-z`, `A-Z`), digits (`0-9`), URLs, punctuation, emojis, or mixed-script tokens (`test`, `нохой123`, `home.com`).

---

### 2. Backend Handlers & Database (`backend/`)

#### [MODIFY] `backend/lib/database.dart`
- **Update `getTopUnknownWords`**:
  Add `minFrequency` parameter to filter by frequency:
  ```sql
  SELECT id, cyrillic, frequency, last_context, last_seen 
  FROM unknown_logs 
  WHERE frequency >= ? 
  ORDER BY frequency DESC, last_seen DESC 
  LIMIT ?
  ```
- **Add `getRejectionHistory(String cyrillic)`**:
  Queries `rejected_words` table to check if a word has previous rejection entries, returning past reasons, dates, and review notes to display on the card.

#### [MODIFY] `backend/bin/server.dart`
- **In `_convertHandler`**:
  - Do NOT cap word count (process and log all unknown words from the input).
  - For each unknown token:
    - Validate with `CyrillicValidator.isCyrillicWord(token.text)`.
    - If valid Cyrillic: log/increment in `_db.logUnknownWord(token.text, context: contextSnippet)`.
    - If not Cyrillic: skip logging into `unknown_logs`.
- **In `_contributeHandler`**:
  - Validate that `cyrillic` is valid Cyrillic text. If not, return HTTP `400 Bad Request` (`{"error": "Зөвхөн кирилл үг оруулна уу"}`).
- **In `_adminMissingHandler`**:
  - Accept `min_frequency` query parameter (defaulting to `2` for moderator review, or whatever the client requests).
- **In `_adminCheckWordHandler`**:
  - Return `rejectionHistory: _db.getRejectionHistory(cyrillic)` alongside existing dictionary definitions.

---

### 3. Frontend Moderator UI (`frontend/lib/ui/moderator/moderator_page.dart`)

#### [MODIFY] `frontend/lib/ui/moderator/moderator_page.dart`
- **Missing Words Tab Filter**:
  - In the Missing Words tab header, add a frequency filter:
    - **`Давтамж >= 2 (Зөвлөмжтэй)`** (Default)
    - **`Бүгд (>= 1)`**
    - **`Их давтамжтай (>= 5)`**
  - When switched, reloads `/admin/missing?min_frequency=$selectedFreq`.
- **Card Informational Badges**:
  - If a word was previously reviewed in `rejected_words`, display an informational banner/chip:
    > ℹ️ *Өмнө нь 1 удаа "Кирилл бичгийн алдаатай" гэж тэмдэглэгдсэн байна.*
  - The moderator can still approve, edit, or reject the word as they see fit.

---

## Verification Plan

### Automated Tests
1. **Validator Tests** (`backend/test/cyrillic_validator_test.dart`):
   - Valid words: `монгол`, `хөрвүүлэгч`, `хөх-ногоон`, `мазаалай`.
   - Valid single letters: `в`, `г`, `а`, `н`.
   - Valid consonant acronyms: `УИХ`, `ХХК`, `МХЕГ`, `ТӨХ`.
   - Invalid mixed script: `mongol`, `сайн123`, `хoх` (with Latin 'o').
   - Invalid URLs and symbols: `https://example.com`, `user@mail.com`, `12345`.
2. **Backend Tests** (`backend/test/server_test.dart`):
   - Test that `/convert` logs all unknown Cyrillic words without a word limit.
   - Test that non-Cyrillic tokens are NOT logged to `unknown_logs`.
   - Test that `/contribute` rejects non-Cyrillic suggestions with 400.
   - Test that `/admin/missing?min_frequency=2` returns only words with frequency >= 2.
   - Test that `getRejectionHistory` returns previous rejections without preventing new additions.
3. **Frontend Tests** (`frontend/test/`):
   - Run `flutter test` and `flutter analyze`.

### Manual Verification
1. Paste a long Mongolian Cyrillic article into the converter with multiple unknown words: verify all of them are parsed and converted.
2. In the Moderator view -> Missing Words queue, verify default shows words with frequency >= 2.
3. Switch the filter to `Бүгд (>= 1)` and verify all one-off words from the pasted article appear in the queue.
4. Verify non-Cyrillic tokens (numbers, English words) do not appear in the Missing Words queue.
