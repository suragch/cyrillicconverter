# Desktop Design System & Theme (`frontend/lib/ui/desktop`)

## Overview
Desktop UI design system tokens, themes, surface metrics, and component contracts for high-density desktop layout.

## Interface
- `[desktop_theme.dart:DesktopTheme]`: Design tokens for slate surfaces, borders, primary blue and semantic colors, corner radii (4px, 6px, 8px), shadows, desktop typography, and global `ThemeData`.
- `[components](./components/README.md)`: Reusable desktop UI widget primitives.

## Invariants
- `[desktop_theme.dart:DesktopTheme]`: Corner radii small, medium, large are fixed at 4.0, 6.0, 8.0 respectively. Global theme strictly enforces `useMaterial3: true` with canvas background.

## Side Effects
- `[desktop_theme.dart:DesktopTheme]`: Pure UI theme data and styling constants; no state mutations or external I/O.

## Verification
- Run: `cd frontend && flutter test`
