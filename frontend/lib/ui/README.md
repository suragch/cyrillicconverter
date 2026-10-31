# Frontend User Interface Architecture (`frontend/lib/ui`)

## Overview
Core user interface architecture providing custom vertical text rendering controllers and sub-packages for desktop layouts, dialogs, dictionary search, and moderation.

## Interface
- `[converter_controller.dart:TokenSpanInfo]`: Character range offset model mapping tokens to rendered vertical text spans.
- `[converter_controller.dart:MongolConverterController]`: Custom vertical `TextEditingController` synthesizing colored `TextSpan`s: wavy red for unknown tokens, dashed blue for homonyms, Menksoft font binding, and hover highlights.
- `[desktop](./desktop/README.md)`: Desktop theme and reusable widget primitives.
- `[dialogs](./dialogs/README.md)`: Modal dialogs for word contributions and privacy preferences.
- `[dictionary](./dictionary/README.md)`: Dictionary search and browsing interface.
- `[moderator](./moderator/README.md)`: Moderator review workstation and suggestion editing.

## Invariants
- `[converter_controller.dart:MongolConverterController]`: Unknown tokens always retain Cyrillic system font with wavy red underline. Word tokens always use Menksoft font. Hover updates notify listeners only when the hovered index changes.

## Side Effects
- `[converter_controller.dart:MongolConverterController]`: Calls `notifyListeners()` on hover index state change.

## Verification
- Run: `cd frontend && flutter test`
