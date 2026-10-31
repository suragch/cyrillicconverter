# Frontend Application Core (`frontend/lib`)

## Overview
Root package for the Flutter Cyrillic to Traditional Mongolian application, managing application bootstrapping, token models, homonym reconciliation, and the primary conversion workspace.

## Interface
- `[main.dart:ExportEncoding]`: Enum for copy encoding formats (`unicode`, `menksoft`).
- `[main.dart:MyApp]`: Application widget configuring `DesktopTheme.themeData` and `ConverterScreen`.
- `[main.dart:ConverterScreen]`: Main conversion screen managing side-by-side editing, Menksoft vertical rendering, homonym selection, unknown word reporting, authentication, and server polling.
- `[main.dart:ConverterScreen.reconcileHomonymSelections]`: Static helper reconciling selected homonym indices across text modifications and option reorderings.
- `[token.dart:Token]`: Model representing lexical tokens (type, original Cyrillic, converted menksoft, and options list).
- `[token.dart:TokenOption]`: Model for word translation options (menksoft code, explanation, `isDefault`).
- `[services](./services/README.md)`: Transliteration engine and file download services.
- `[ui](./ui/README.md)`: Vertical text controller, desktop design system, dialogs, dictionary, and moderator page.

## Invariants
- `[main.dart:ConverterScreen]`: First-time conversion forces user to set privacy context preference. Re-conversion is skipped when input text has not changed unless force is true. Homonym selection reconciliation matches by Cyrillic word occurrence and Menksoft code before falling back to index.
- `[token.dart:Token]`: Token type is strictly one of `'word'`, `'space'`, `'delimiter'`, or `'unknown'`.

## Side Effects
- `[main.dart:ConverterScreen]`: Sends HTTP POST requests to `/convert`, `/contribute`, `/auth/login`; sends HTTP GET requests to `/health`, `/auth/me`, `/admin/suggestions`, `/export`; reads/writes `SharedPreferences` for auth token and privacy context preference; accesses system clipboard.

## Verification
- Run: `cd frontend && flutter test`
