# Final Desktop UI Full Redesign Plan

## 1. Overview & Vision
The existing frontend uses standard Flutter mobile Material Design 3 widgets (mobile `AppBar`, `FloatingActionButton`, floating bottom `SnackBar` toasts, 16–28px pill buttons, and vertically stacked phone-like layouts). On desktop monitors and widescreen laptops, this feels like an enlarged phone app rather than a productive desktop application.

This plan details a complete, ground-up redesign of the application into a **native-feeling desktop app** (resembling modern desktop applications like Linear, VS Code, and DeepL Desktop):
- **Full Removal of Material 3 Mobile Visuals**: Replace mobile widgets with clean, desktop-native components featuring subtle 1px slate borders, compact density, 4–6px subtle corner radii, and crisp typography.
- **Side-by-Side Split-Pane Workspace**: Left pane for Cyrillic editing and right pane for Traditional Mongolian vertical output, with seamless responsive fallback on narrow screens.
- **Top Desktop Navigation Bar**: Sleek tabs in the desktop header to navigate between **[Хөрвүүлэгч] (Converter)**, **[Шүүгч / Модератор] (Moderator)**, and **[Толь бичиг] (Dictionary)**.
- **Single-Key Moderator Hotkeys**: Power-user keyboard review (`[1]` Approve, `[2]` Misspelled, `[3]` Not a word, `[E]` Edit, `[Space]` Skip).
- **Desktop Status Bar & Zoom Controls**: Dynamic font zoom (`[A-]` 26pt `[A+]`), real-time text metrics (word, character, homonym, unknown counts), and server connectivity indicators.

---

## 2. Confirmed Design Decisions

| Aspect | Selected Specification |
| :--- | :--- |
| **Workspace Layout** | **Split-pane side-by-side** (Left: Cyrillic Editor, Right: Traditional Mongolian Output) with responsive vertical stacking on narrow windows (< 800px). |
| **Section Navigation** | **Top Desktop Navigation Bar** with tabs: `[Хөрвүүлэгч]`, `[Шүүгч / Модератор]`, `[Толь бичиг]`. |
| **Moderator Controls** | **Single-key keyboard shortcuts** (`[1]` Approve, `[2]` Misspelled, `[3]` Not a word, `[E]` Edit, `[Space]` Skip) for rapid review without mouse movement. |
| **Visual Styling** | **Slate / Neutral Desktop**: 1px crisp borders (`#E2E8F0`), flat surfaces (`#FFFFFF` / `#F8FAFC`), 4–6px radii, compact desktop sizing. |

---

## 3. Desktop Application Architecture

```
+-----------------------------------------------------------------------------------------------------------+
| [Logo] Кирилл ➜ ᠮᠣᠩᠭᠣᠯ   [ Хөрвүүлэгч ]  [ Шүүгч / Модератор (14) ]  [ Толь бичиг ]   | [A-] 26pt [A+]  [Unicode ▾]  user@email.com ▾ |
+-----------------------------------------------------------------------------------------------------------+
|  ЗҮҮН ХАГАС: Кирилл эх бичвэр                        |  БАРУУН ХАГАС: Монгол бичиг (Босоо)                |
|  +-------------------------------------------------+ |  +-----------------------------------------------+ |
|  | Гарчиг: Эх бичвэр           [Буулгах] [Цэвэрлэх] | |  | Гарчиг: Монгол бичиг          [Хуулах ⌘C] [Алдаа] | |
|  | ----------------------------------------------- | |  | --------------------------------------------- | |
|  |                                                 | |  |                                               | |
|  |  (Олон мөрт кирилл засварлагч)                   | |  |  (Босоо бичвэр - хэвтээ гүйлгэгчтэй)         | |
|  |                                                 | |  |                                               | |
|  |  "2026 онд Монгол улсын хүү, төр..."             | |  |  ᠬᠥᠪᠡᠭᠦᠨ ᠲᠥᠷᠥ ᠮᠣᠩᠭᠣᠯ ᠤᠯᠤᠰ                 | |
|  |                                                 | |  |  ...                                         | |
|  |                                                 | |  |                                               | |
|  +-------------------------------------------------+ |  +-----------------------------------------------+ |
|  [ Хөрвүүлэх (⌘+Enter) ]        Тэмдэгт: 280, Үг: 45 |  Тайлбар: [● Олон утгатай]  [● Тольд үгүй] [● Зөв] |
+-----------------------------------------------------------------------------------------------------------+
|  ● Бэлэн | Үг: 45 • Тэмдэгт: 280 | Олон утгатай: 2 • Тольд байхгүй: 1 | Босоо үсгийн хэмжээ: 26pt | Сервер: Хэвийн (8080) |
+-----------------------------------------------------------------------------------------------------------+
```

---

## 4. Detailed Component Design

### A. Desktop Application Header
- **Brand Title**: Clean desktop typographic logo with Mongolian vertical script emblem.
- **Navigation Tabs**:
  - `[Хөрвүүлэгч]` — Main split-screen converter workspace.
  - `[Шүүгч / Модератор]` — Moderator queue with badge counter (e.g. `14`).
  - `[Толь бичиг]` — Dictionary lookup, browsing, and search panel.
- **Desktop Utility Strip**:
  - **Font Size Controls**: `[A-]` `26pt` `[A+]` toolbar buttons to dynamically adjust vertical Traditional Mongolian text scale from 18pt to 44pt.
  - **Encoding Dropdown**: Sleek desktop dropdown `Unicode` vs `Menksoft`.
  - **Keyboard Help `[?]`**: Opens shortcut cheatsheet.
- **User Account Menu**:
  - Authenticated: Avatar badge + email + dropdown (`Шүүгч эрх`, `Гарах` [Sign Out]).
  - Unauthenticated: Clean `Нэвтрэх` [Sign In] desktop button.

---

### B. Split-Pane Converter Workspace
- **Layout**: Uses a desktop `Row` with flexible expansion and responsive window-width fallback:
  - If window width >= 800px: **Side-by-side 50/50 split**.
  - If window width < 800px: Stacks gracefully into top-and-bottom panes.
- **Left Pane (Cyrillic Source)**:
  - Header: "Эх бичвэр (Кирилл)", word count chip, `Буулгах` (Paste), `Цэвэрлэх` (Clear).
  - Editor: Full-height, custom styled desktop text field with monospace/system font, subtle focus border.
  - Footer Action Bar:
    - Primary button: `Хөрвүүлэх` with hotkey badge `[⌘+Enter]`.
    - Live char & word counters.
- **Right Pane (Traditional Mongolian Output)**:
  - Header: "Монгол бичиг (Босоо)", `Хуулж авах` (Copy selection/all), copy feedback indicator.
  - Canvas: Horizontal-scrolling canvas backed by [`MongolTextField`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/frontend/lib/main.dart) and [`MongolConverterController`](file:///Users/suragch/Dev/FlutterProjects/cyrillicconverter/frontend/lib/ui/converter_controller.dart).
  - Retains all existing rich interactions:
    - Natural mouse drag-and-drop text selection.
    - Interactive word hover highlighting (amber for homonyms, red wavy for unknown, indigo for verified).
    - Left-click on homonym: opens meaning selection popover.
    - Left-click on unknown word: opens definition/add dialog.
    - Right-click on any word: opens desktop context menu (Report error / Edit).
  - Footer Legend: Clean inline status indicators.

---

### C. Desktop Status Bar (Bottom 28px)
- **Status indicator**: Green dot with `Бэлэн` (Ready) / animated indicator during conversion.
- **Text statistics**: `Үг: 45 • Тэмдэгт: 280 • Олон утгатай: 2 • Тольд үгүй: 1`.
- **Zoom status**: `Хэмжээ: 26pt`.
- **Backend status**: `Сервер: 8080 (Хэвийн)`.

---

### D. Moderator Workspace Redesign (High-Speed Desktop Station)
- **Sub-Header**:
  - Queue Switcher: `Хянагдах саналууд (14)` | `Дутуу үгс (56)`.
  - Frequency Filter Dropdown: `Давтамж ≥ 2 (Зөвлөмжтэй)`, `Бүгд (≥ 1)`, `Их давтамжтай (≥ 5)`.
  - Hotkey Help Strip: `[1] Зөвшөөрөх  [2] Алдаатай  [3] Үг биш  [E] Засах  [Space] Алгасах`.
- **Inspection Card**:
  - **Left Section**: 48pt vertical Traditional Mongolian rendering + headword Cyrillic with inline copy button + Latin transliteration + context sentence.
  - **Right Section**: Dictionary match status + homonym list + previous review history badge (`Өмнөх түүх`).
- **Single-Key Keyboard Navigation**:
  - Pressing `1` -> Approves current word and advances.
  - Pressing `2` -> Rejects as Cyrillic misspelled.
  - Pressing `3` -> Rejects as Cyrillic not a word.
  - Pressing `E` -> Opens edit modal.
  - Pressing `Space` / `Right Arrow` -> Skips to next item.
  - Pressing `Left Arrow` -> Returns to previous item.
  - Enables reviewing hundreds of entries without lifting hands to the mouse.

---

### E. New Dictionary Quick Lookup Tab
- A dedicated desktop tab:
  - Search bar: Type any Cyrillic word or Menksoft code to instantly see dictionary entries.
  - Results view: Displays canonical Menksoft spelling, homonym variants, explanations, and primary flags.
  - Allows quick verification while writing or editing.

---

### F. Desktop Dialogs & Popovers
- Replace mobile `AlertDialog` with **Desktop Dialog Window**:
  - Title bar with window title and `✕` close button.
  - Clean form fields with keyboard autofocus.
  - Action buttons aligned to bottom-right: `Цуцлах` (Cancel), `Хадгалах` / `Нэмэх` (Primary action with `Enter` shortcut).

---

## 5. Implementation Roadmap

### Phase 1: Desktop Theme & Reusable Desktop Components
1. Create `frontend/lib/ui/desktop/desktop_theme.dart`:
   - Colors, typography, borders, paddings, shadows.
2. Create reusable desktop primitives in `frontend/lib/ui/desktop/components/`:
   - `DesktopButton`, `DesktopIconButton`, `DesktopHeader`, `DesktopStatusBar`, `DesktopDialogFrame`, `DesktopSegmentedTabs`.

### Phase 2: Converter Workspace (Side-by-Side Split View)
1. Refactor `ConverterScreen` in `frontend/lib/main.dart`:
   - Build desktop layout with top header bar, side-by-side editor/output split pane, and bottom status bar.
   - Implement responsive layout fallback (< 800px).
   - Implement font size zoom controls (`[A-]` / `[A+]`).
   - Implement desktop keyboard shortcuts (`Cmd+Enter` to convert, `Cmd+C` to copy).

### Phase 3: Desktop Moderator Workspace
1. Update `ModeratorPage` in `frontend/lib/ui/moderator/moderator_page.dart`:
   - Remove mobile AppBar/FloatingActionButton.
   - Embed desktop top header and navigation.
   - Wire single-key hotkey listener (`FocusNode` + `HardwareKeyboard` or `RawKeyboardListener`).
   - Add split inspection layout and desktop action buttons.

### Phase 4: Desktop Dialogs & Dictionary Tab
1. Redesign `AddEditWordDialog`, `EditSuggestionDialog`, and `LoginDialog` to use `DesktopDialogFrame`.
2. Add the `DictionaryBrowseTab` allowing quick dictionary word lookups.

### Phase 5: Verification & Polishing
1. Run `flutter test` and `flutter analyze` to ensure zero regressions.
2. Verify all keyboard shortcuts, mouse drag selections, font zooming, and responsive window resizing.
