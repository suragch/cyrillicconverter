# Desktop GUI Components (`frontend/lib/ui/desktop/components`)

## Overview
Reusable desktop GUI component primitives providing buttons, icon buttons, dialog window frames, application navigation headers, and metric status bars styled for desktop density.

## Interface
- `[desktop_button.dart:DesktopButtonVariant]`: Enum defining button style variants (`primary`, `secondary`, `subtle`, `danger`, `success`).
- `[desktop_button.dart:DesktopButton]`: Interactive desktop button supporting loading indicators, keyboard shortcut badges, dense mode, and text selection prevention.
- `[desktop_button.dart:DesktopIconButton]`: Compact desktop action icon button with tooltips and hover feedback.
- `[desktop_dialog.dart:DesktopDialogFrame]`: Modal window container featuring title bar, leading icon, close button, scrollable body, and action footer.
- `[desktop_header.dart:DesktopNavTab]`: Enumeration of workspace navigation tabs (`converter`, `moderator`, `dictionary`).
- `[desktop_header.dart:DesktopHeader]`: Application navigation header featuring brand banner, tab switcher with badge count, privacy settings trigger, and user session profile strip.
- `[desktop_status_bar.dart:DesktopStatusBar]`: 28px bottom status bar showing conversion state, word and character counts, homonym and unknown word badges, and server status.

## Invariants
- `[desktop_button.dart:DesktopButton]`: Disabled when `onPressed` is null or `isLoading` is true, reducing opacity to 0.5 and setting cursor to `SystemMouseCursors.basic`.
- `[desktop_dialog.dart:DesktopDialogFrame]`: Default `maxWidth` is 520px with centered alignment; Escape or close icon pops navigator context if `onClose` is not overridden.
- `[desktop_header.dart:DesktopHeader]`: Moderator tab is rendered only if `isLoggedIn` is true. Profile chip displays the first letter of the user email capitalized.
- `[desktop_status_bar.dart:DesktopStatusBar]`: Status dot shows green for ready/success and amber for loading. Detailed metrics are hidden on viewports narrower than 900px.

## Side Effects
- `[desktop_button.dart:DesktopButton]`: Fires `widget.onPressed` callback on user click.
- `[desktop_header.dart:DesktopHeader]`: Triggers `onTabChanged`, `onLoginPressed`, `onLogoutPressed`, or `onSettingsPressed` navigation callbacks.
- `[desktop_dialog.dart:DesktopDialogFrame]`: Pops modal navigation route on close.

## Verification
- Run: `cd frontend && flutter test`
