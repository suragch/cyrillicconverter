# Dialog Workflows (`frontend/lib/ui/dialogs`)

## Overview
Modal dialog workflows for adding/editing dictionary words, reporting translation issues, and configuring privacy context retention.

## Interface
- `[add_edit_word_dialog.dart:AddEditWordDialog]`: Modal dialog with live vertical Menksoft preview, Cyrillic input, Latin transliteration with paste support, optional explanation, deletable sentence context snippet, toggleable on-screen Mongolian keyboard, and optional `onDelete` action.
- `[privacy_settings_dialog.dart:PrivacySettingsDialog]`: Modal settings dialog allowing users to toggle whether surrounding sentence context of unknown words is stored on the server for moderators.

## Invariants
- `[add_edit_word_dialog.dart:AddEditWordDialog]`: Pasting or typing Mongolian Unicode into the Latin field automatically converts to Latin transliteration via `LatinIme.convertToLatin`. Submissions with empty Cyrillic text are blocked. Deleted sentence context sends `null`. When `onDelete` is provided, displays an "Устгах" danger button with confirmation alert.
- `[privacy_settings_dialog.dart:PrivacySettingsDialog]`: First-time prompt is non-dismissible (`barrierDismissible: false`) and omits Cancel button to mandate an explicit choice.

## Side Effects
- `[add_edit_word_dialog.dart:AddEditWordDialog]`: Invokes async `onSubmit` callback, interacts with system clipboard via `Clipboard.getData` and `Clipboard.setData`, and pops dialog route.
- `[privacy_settings_dialog.dart:PrivacySettingsDialog]`: Pops modal route returning selected boolean preference.

## Verification
- Run: `cd frontend && flutter test`
