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

This philosophy directly supports our core user stories, from the casual user (Chen) who wants a zero-friction experience to the preservationist (Batbayar) who requires a tool that feels professional and secure.

### 2. Color Palette

The color palette is designed for bold simplicity and accessibility. It uses a primary neutral family for the core interface, ensuring content is always the focus, complemented by a vibrant, single-action color and semantic accents for clear communication.

| Role                   | Color       | Hex Code  | Usage                                                                                       |
| :--------------------- | :---------- | :-------- | :------------------------------------------------------------------------------------------ |
| **Primary UI**         |             |           |                                                                                             |
| Background             | White       | `#FFFFFF` | Provides maximum breathing room and content contrast.                                       |
| Surface                | Off-White   | `#F9F9F9` | Used for contained elements like modals to gently separate them from the main background.   |
| Text (Primary)         | Near-Black  | `#1A1A1A` | Main text for readability; avoids the harshness of pure black.                              |
| Text (Secondary)       | Medium Gray | `#6B6B6B` | For placeholder text, helper text, and secondary information like character counts.         |
| Borders/Dividers       | Light Gray  | `#E0E0E0` | Subtle structural lines.                                                                    |
| **Action & Accent**    |             |           |                                                                                             |
| Primary Action         | Royal Blue  | `#0052FF` | The core "Convert" button and primary interactive elements. A vibrant, trustworthy hue.     |
| Primary Action (Hover) | Bright Blue | `#0048E0` | Provides clear feedback on interactive elements.                                            |
| **Semantic**           |             |           |                                                                                             |
| Success                | Green       | `#28A745` | Confirmation toasts (e.g., "Saved successfully!").                                          |
| Information            | Muted Blue  | `#007BFF` | Informational toasts (e.g., "Dictionary updated.").                                         |
| Warning/Error          | Red         | `#DC3545` | Used *exclusively* for the subtle underline on unconverted words and critical error states. |

### 3. Typography

The typographic hierarchy is designed for scannability and clarity, creating a clear information structure that guides the user's eye without effort. We will utilize a single, versatile sans-serif font family for the UI and the specified `Menksoft` font for the output.

**UI Font Family:** Inter (or a similar neutral, highly legible sans-serif)

| Element           | Font Weight | Size (Desktop / Mobile) | Line Height | Use Case                                                           |
| :---------------- | :---------- | :---------------------- | :---------- | :----------------------------------------------------------------- |
| **Display Title** | Medium      | `24px / 20px`           | 1.2         | Main heading in modals (e.g., "Add to Dictionary").                |
| **Text Area**     | Regular     | `18px / 16px`           | 1.6         | Cyrillic input text. Designed for comfortable reading and writing. |
| **Button**        | Medium      | `16px / 16px`           | 1           | All button labels.                                                 |
| **Body / Label**  | Regular     | `14px / 14px`           | 1.5         | Helper text, captions, context snippets in the modal.              |
| **Toast Message** | Regular     | `14px / 14px`           | 1.4         | Notification text.                                                 |

**Traditional Mongolian Output Font:** Menksoft (or specified font)
*   **Rendering:** Text will be rendered vertically with appropriate character spacing to ensure beautiful and accurate representation. Font size will be proportional to the Cyrillic input to maintain visual harmony.

### 4. Grid & Spacing

A consistent spacing system based on an **8pt grid** will be used to ensure rhythmic, visually pleasing layouts. This systematic approach to spacing is critical for creating "breathable whitespace" and reducing visual clutter.

*   **Base Unit:** `1rem = 16px`
*   **Core Spacing Values (Multiples of 8):**
    *   `x-small (4px)`: Gaps between icons and text.
    *   `small (8px)`: Padding within small components like icon buttons.
    *   `medium (16px)`: Padding within larger components (buttons, text inputs), gaps between related items.
    *   `large (24px)`: Gaps between distinct UI sections (e.g., input panel and button).
    *   `x-large (32px)`: Padding around the main conversion container.
    *   `xx-large (48px)`: Major layout divisions.

### 5. Core Components

This section defines the building blocks of the interface, ensuring consistency and predictability.

#### **Buttons**

*   **Primary Action ("Convert")**
    *   **Style:** Solid fill with the `Primary Action` color. High contrast white text.
    *   **Size:** Large, with generous `medium (16px)` vertical and `x-large (32px)` horizontal padding to create an unmissable target.
    *   **States:**
        *   **Default:** Solid `#0052FF`.
        *   **Hover:** Darkens slightly to `#0048E0` with a subtle "lift" shadow.
        *   **Active/Pressed:** Darker `#003ECC`.
        *   **Disabled:** Light gray fill `#E0E0E0` with `Medium Gray` text. Non-interactive.

*   **Secondary Actions ("Copy," "Clear")**
    *   **Style:** Ghost button style. Transparent background with a `1px` solid `Light Gray` border and `Primary Action` colored text.
    *   **States:**
        *   **Hover:** Background subtly fills with a very light tint of the `Primary Action` color.
        *   **Active/Pressed:** Background fill becomes more pronounced.

#### **Text Panels (Input & Output)**

*   **Layout:** Side-by-side on desktop/tablet, stacked vertically on mobile. A `large (24px)` gap separates them.
*   **Style:** A generous `medium (16px)` internal padding. A subtle `1px` `Light Gray` border. On focus, the border color changes to `Primary Action` blue.
*   **Input (Empty State):** Displays placeholder text in `Secondary Text` color: *"Та кирилл монгол бичвэрээ энд буулгана уу..."*
*   **Output (Converted State):**
    *   **Unconverted Words:** Remain in Cyrillic script but are styled with a `2px` dotted underline of `Warning/Error` red. This avoids the alarming feel of a solid underline while clearly indicating an actionable item.
    *   **Tooltip on Hover:** On hovering an unconverted word, a small tooltip appears: *"Click to add a translation."*

#### **Contribution Modal**

*   **Appearance:** Appears with a gentle physics-based scale-in animation, centered on the screen. A semi-transparent overlay darkens the background to focus the user.
*   **Layout (Content-First):**
    1.  **Context Snippet:** At the top, in a muted block with `Secondary Text` color.
    2.  **Primary Input:** Large, focused input field for Traditional Mongolian transliteration.
    3.  **Live Preview:** Rendered Menksoft text appears instantly below the input.
    4.  **Actions:** A segmented control for "Save Locally" (default) and "Save & Submit to Community."

#### **Notifications (Toasts)**

*   **Appearance:** A small, rounded rectangle that slides up from the bottom of the screen. It remains for 3-4 seconds before gently sliding out.
*   **Style:** Uses the appropriate semantic color (`Success` or `Information`) with high-contrast text.

### 6. Motion & Animation

Motion is used sparingly and purposefully to enhance the user's understanding of the interface and provide feedback. All animations will be **physics-based (springs)** rather than duration-based, creating a more natural and fluid feel.

*   **State Transitions:** Changes in button states (hover, press) will have a subtle, quick transition on color and shadow properties. This makes the UI feel responsive and alive.
*   **Modal Appearance:** The contribution modal will not simply "appear." It will animate in with a gentle spring, giving it a sense of physical presence.
*   **Feedback Micro-interactions:** For large text conversions, the "Convert" button will perform a single, quick "pulse" animation upon click to acknowledge the input, even if the conversion is instantaneous. This reassures the user their action was received.

### 7. Accessibility

Accessibility is a core requirement, not an afterthought. The design system must ensure universal usability.

*   **Contrast Ratios:** All text and UI components will adhere to WCAG AA standards for color contrast, ensuring readability for users with visual impairments.
*   **Focus States:** All interactive elements (buttons, inputs, links) will have a clear and highly visible focus state (e.g., the `Primary Action` blue ring) for keyboard-only navigation.
*   **Target Sizes:** Tap targets on mobile will be a minimum of `48x48px` to accommodate imprecise touch interactions and prevent "fat-finger" errors.
*   **Alternative Text:** All icons that convey meaning will have appropriate text alternatives for screen reader users.