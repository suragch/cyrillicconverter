## 1.2.0 - 2026.11.06

- Implement local-first word persistence using `LocalDictionaryService` backed by `SharedPreferences`.
- Display locally resolved words in converter with green dotted underline styling.
- Add "Миний үгс" (My Words) tab in dictionary browse view with search and delete capabilities.
- Support word deletion in `AddEditWordDialog`.
- Background silent purge of local words once recognized by central dictionary.

## 1.1.3 - 2026.11.03

- Update web favicon and PWA app icons with branded Mongolian calligraphy logo.

## 1.1.2 - 2026.11.02

- Fix font asset permissions (chmod 644) preventing HTTP 403 Forbidden on production web server.
- Ensure world-readable permissions (a+rX) on deployed web root in deployment workflow.
- Declare CSS @font-face in index.html for reliable browser font loading.

## 1.1.1 - 2026.11.02

- Update mongol package to 11.2.0. Supports emoji, CJK, and trailing space alignment.
- Migrate Material design imports across frontend to package:material_ui.

## 1.1.0 - 2026.11.02

- Mobile-responsive web interface with two-tab segmented toggle and `IndexedStack` state preservation.
- Touch-friendly homonym ambiguity bottom sheet with Menksoft script and Latin transliteration.
- Menksoft font preloading and zero-dependency inline HTML/CSS splash spinner.
- SQLite concurrency hardening (`PRAGMA busy_timeout = 5000`) and decoupled async unknown word logging.
- Cloudflare `CF-Connecting-IP` session composite keying and 512KB payload ceiling.
- Automated tests across backend and mobile frontend components.

## 1.0.0 - 2026.09.17

- Flutter frontend.
- Dart/Pocketbase backend.
- Desktop UI style.
- Moderator tools.
- Support dual meanings.

## Pre-1.0 

- https://github.com/suragch/mongol_converter