## A Functional UX/UI Style Guide

**To:** Project Stakeholders  
**From:** Lead Product Designer  
**RE:** Establishing a Scalable Design System for the Mongolian Script Converter  
**Date:** October 28, 2025

### A Note on Inspiration

This document outlines a functional design system based on the provided context and aesthetic guidelines. As the visual inspiration images were not available for analysis, this guide establishes a foundational system rooted in FANG-style best practices for high-touch SaaS applications. It is designed to be adaptable once specific aesthetic inspirations are incorporated.

***

### 1. Design Philosophy: The Principle of Instant Clarity

Our design system is governed by a single principle: **Instant Clarity**. Every component, interaction, and layout decision must serve to make the user's journey from Cyrillic input to Traditional Mongolian output feel effortless, trustworthy, and immediate.

We achieve this through a disciplined application of the following core concepts:

*   **Content-First Architecture:** The user's text is the hero. The UI is a minimal, elegant frame that elevates the content and removes all friction from the core conversion task.
*   **Cognitive Breathing Room:** We will aggressively use negative space to reduce cognitive load, guiding the user's focus naturally between input, action, and output. This ensures that even first-time users intuitively understand the interface without instruction.
*   **Purposeful Responsiveness:** The interface is not static; it is a conversation. Every user action will receive immediate, clear, and subtle feedback, from button state changes to micro-interactions, confirming system status and building trust.
*   **Graceful Ambiguity Resolution:** When a word or abbreviation has multiple valid options, the UI must present these choices in a frictionless, inline manner, allowing the user to resolve ambiguity without breaking their workflow.

This philosophy directly supports our core user stories, from the casual user (Chen) who wants a zero-friction experience to the preservationist (Batbayar) who requires a tool that feels professional and secure.

### 2. Color Palette

The color palette is designed for bold simplicity and accessibility. It uses a primary neutral family for the core interface, complemented by a vibrant, single-action color and semantic accents for clear communication.

| Role | Color | Hex Code | Usage |
| :--- | :--- | :--- | :--- |
| **Primary UI** | | | |
| Background | White | `#FFFFFF` | Provides maximum breathing room and content contrast. |
| Surface | Off-White | `#F9F9F9` | Used for contained elements like popovers and modals. |
| Text (Primary) | Near-Black | `#1A1A1A` | Main text for readability; avoids the harshness of pure black. |
| Text (Secondary) | Medium Gray | `#6B6B6B` | For placeholder text, helper text, and secondary information. |
| Borders/Dividers | Light Gray | `#E0E0E0` | Subtle structural lines. |
| **Action & Accent** | | | |
| Primary Action | Royal Blue | `#0052FF` | The core "Convert" button and primary interactive elements. |
| Primary Action (Hover)| Bright Blue | `#0048E0` | Provides clear feedback on interactive elements. |
| **Semantic** | | | |
| Success | Green | `#28A745` | Confirmation toasts (e.g., "Saved successfully!"). |
| Information | Muted Blue | `#007BFF` | Informational toasts (e.g., "Dictionary updated."). |
| Warning/Error | Red | `#DC3545` | Used *exclusively* for the underline on **unconverted** words. |
| **Choice/Ambiguity** | **Royal Blue** | **`#0052FF`** | **(NEW)** Used for the underline on words with **multiple options**. |

### 3. Typography

The typographic hierarchy is designed for scannability and clarity. We will utilize a single, versatile sans-serif font family for the UI and the specified `Menksoft` font for the output.

**UI Font Family:** Inter (or a similar neutral, highly legible sans-serif)

| Element | Font Weight | Size (Desktop / Mobile) | Line Height | Use Case |
| :--- | :--- | :--- | :--- | :--- |
| **Display Title** | Medium | `24px / 20px` | 1.2 | Main heading in modals (e.g., "Add to Dictionary"). |
| **Text Area** | Regular | `18px / 16px` | 1.6 | Cyrillic input text. Designed for comfortable reading and writing. |
| **Button** | Medium | `16px / 16px` | 1 | All button labels. |
| **Body / Label** | Regular | `14px / 14px` | 1.5 | Helper text, captions, context snippets in the modal. |
| **Toast Message** | Regular | `14px / 14px` | 1.4 | Notification text. |

**Traditional Mongolian Output Font:** Menksoft (or specified font)
*   **Rendering:** Text will be rendered vertically with appropriate character spacing to ensure beautiful and accurate representation. Font size will be proportional to the Cyrillic input to maintain visual harmony.

### 4. Grid & Spacing

A consistent spacing system based on an **8pt grid** will be used to ensure rhythmic, visually pleasing layouts.

*   **Base Unit:** `1rem = 16px`
*   **Core Spacing Values (Multiples of 8):** `4px`, `8px`, `16px`, `24px`, `32px`, `48px`.

### 5. Core Components

This section defines the building blocks of the interface, ensuring consistency and predictability.

#### **Buttons**

*   **Primary Action ("Convert")**
    *   **Style:** Solid fill with the `Primary Action` color.
    *   **States:** Default, Hover, Active/Pressed, Disabled.
*   **Secondary Actions ("Copy," "Clear")**
    *   **Style:** Ghost button style. Transparent background with a `Light Gray` border.
    *   **States:** Hover, Active/Pressed.

#### **Text Panels (Input & Output)**

*   **Layout:** Side-by-side on desktop/tablet, stacked vertically on mobile.
*   **Style:** A generous `medium (16px)` internal padding. A subtle `1px` `Light Gray` border. On focus, the border color changes to `Primary Action` blue.
*   **Input (Empty State):** Displays placeholder text in `Secondary Text` color: *"Та кирилл монгол бичвэрээ энд буулгана уу..."*
*   **Output (Converted State) & Input (Ambiguity State):**
    *   **Unconverted Words:** Remain in Cyrillic, styled with a `2px` dotted underline of `Warning/Error` red. Tooltip on hover: *"Click to add a translation."*
    *   **(NEW) Ambiguous Words/Abbreviations:** Styled with a `2px` dotted underline of `Choice/Ambiguity` blue. Tooltip on hover: *"Click to choose an option."* This applies in the Cyrillic input panel for abbreviations and the Traditional output panel for conversions.

#### **(NEW) Ambiguity Resolver Popover**

*   **Purpose:** To allow users to choose from multiple valid options for an abbreviation or a word conversion without leaving their workflow.
*   **Trigger:** Clicking on a word with a `Choice/Ambiguity` blue underline.
*   **Appearance:** A small, clean popover menu that appears attached to the clicked word. It uses the `Surface` color for its background and has a subtle drop shadow to lift it off the page.
*   **Layout:**
    1.  A simple list of clickable options (either Cyrillic expansions or Traditional Mongolian spellings).
    2.  The currently selected/default option is highlighted.
    3.  A final list item allows the user to "Add another option...", which would open the full Contribution Modal.
*   **Interaction:** Clicking an option instantly updates the text in the main panel and dismisses the popover. Clicking outside the popover also dismisses it.

#### **Contribution Modal**

*   **Appearance:** Appears with a gentle physics-based scale-in animation, centered on the screen. A semi-transparent overlay darkens the background.
*   **Layout (Content-First):**
    1.  **Context Snippet:** At the top, in a muted block with `Secondary Text` color.
    2.  **Primary Input:** Large, focused input field for Traditional Mongolian transliteration.
    3.  **Live Preview:** Rendered Menksoft text appears instantly below the input.
    4.  **Actions:** A segmented control for "Save Locally" (default) and "Save & Submit to Community."

#### **Notifications (Toasts)**

*   **Appearance:** A small, rounded rectangle that slides up from the bottom of the screen.
*   **Style:** Uses the appropriate semantic color (`Success` or `Information`) with high-contrast text.

### 6. Motion & Animation

Motion is used sparingly and purposefully to enhance the user's understanding of the interface. All animations will be **physics-based (springs)** for a more natural feel.

*   **State Transitions:** Changes in button states will have a subtle, quick transition.
*   **Modal/Popover Appearance:** The contribution modal and ambiguity popover will not simply "appear." They will animate in with a gentle spring.
*   **Feedback Micro-interactions:** The "Convert" button will perform a single, quick "pulse" animation upon click to acknowledge the input.

### 7. Accessibility

*   **Contrast Ratios:** All text and UI components will adhere to WCAG AA standards.
*   **Focus States:** All interactive elements will have a clear and highly visible focus state.
*   **Target Sizes:** Tap targets on mobile will be a minimum of `48x48px`.
*   **Alternative Text:** All meaningful icons will have appropriate text alternatives.