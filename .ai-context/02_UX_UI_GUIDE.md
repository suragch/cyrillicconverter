# UX/UI Guide: Material Mongolian

## 1. Design Philosophy
We are building a **Productivity Tool**, not a brochure website. The interface should feel like a robust text editor. We will utilize **Material 3** design principles provided natively by Flutter.

## 2. Layout Structure

### Desktop / Tablet (Landscape)
*   **Split View**:
    *   **Left Panel (Input)**: Large multi-line text field for Cyrillic.
    *   **Right Panel (Output)**: Rich Text rendering area for Traditional Script.
    *   **Center Action Bar**: Contains the floating "Convert" button (FAB) or a vertical column of action icons (Convert, Copy, Clear).

### Mobile (Portrait)
*   **Tabbed View or Stacked**:
    *   Input area on top (40% height).
    *   Output area on bottom (60% height).
    *   FAB anchored bottom-right.

## 3. Visual Feedback States

### 3.1. The "Unknown" Word (Red)
*   **Visual**: Text color is black, but underlined with a **Red Wavy Line**.
*   **Interaction**: Tap/Click opens a Dialog: "Unknown Word".
    *   **Dialog Content**:
        *   "We don't know this word yet."
        *   Input field: "Enter Traditional Mongolian spelling".
        *   Checkbox: "Include sentence for context? (Helps moderators)".
        *   Button: "Save to my dictionary & Suggest".

### 3.2. The "Ambiguous" Word (Blue)
*   **Visual**: Text color black, underlined with a **Blue Dotted Line**.
*   **Interaction**: Tap/Click opens a Popover/Dropdown (MenuAnchor in Flutter).
    *   **Content**: List of possible meanings/spellings.
    *   **Action**: Selecting an item replaces the rendered text inline and removes the underline.

## 4. Typography
*   **Cyrillic**: Roboto or Open Sans (Standard sans-serif).
*   **Traditional**: Menksoft (Vertical rendering).
    *   *Note*: Flutter handles fonts well, but we must ensure the `Menksoft` font file is bundled in `pubspec.yaml`.