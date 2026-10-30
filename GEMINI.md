# Cyrillic Converter Project Rules

This document outlines the coding standards, formatting guidelines, and verification workflows for agents and developers working on the Cyrillic Converter project.

---

## 1. Code Style & Syntax

### 1.1 Always Use Curly Braces on Control Flow Statements
- **Mandatory**: Always enclose the body of every control flow statement (`if`, `else`, `for`, `while`, `do`) in curly braces `{ ... }`, even for single-line statements.
- **Example**:
  ```dart
  // Correct
  if (mounted) {
    setState(() => _serverStatusText = 'Сервер: Хэвийн');
  }

  // Incorrect - DO NOT USE
  if (mounted) setState(() => _serverStatusText = 'Сервер: Хэвийн');
  ```
- **Rationale**: `dart format` may wrap long single-line statements across multiple lines, which will violate the `curly_braces_in_flow_control_structures` linter rule and produce analyzer warnings.

---

## 2. Verification Workflow (Strict Sequence)

Whenever you create or modify code in this repository, you **must** execute the verification steps in the following exact order:

1. **Step 1: Format First**
   - Backend: `dart format backend/`
   - Frontend: `dart format frontend/`
   - Always run formatting *before* running static analysis so that line wrapping and formatting changes are evaluated by the analyzer.

2. **Step 2: Static Analysis (`--fatal-infos`)**
   - Backend: `cd backend && dart analyze --fatal-infos`
   - Frontend: `cd frontend && flutter analyze --fatal-infos`
   - **Zero Tolerance**: No warnings, lints, or infos should remain. Any issue flagged by `--fatal-infos` must be resolved before proceeding.

3. **Step 3: Automated Tests**
   - Backend: `cd backend && dart test`
   - Frontend: `cd frontend && flutter test`
   - All tests must pass before declaring a task complete. If code changes alter behavior, update or add tests accordingly.

---

## 3. Architecture & Project Conventions

- **Frontend (`frontend/`)**:
  - Flutter application (targets Web, Desktop, Mobile).
  - State preservation: Ensure asynchronous callbacks verify `if (mounted) { ... }` before updating state.
  - UI responsiveness: Avoid blocking the UI thread; retain scroll position and token selections during loading states where appropriate.

- **Backend (`backend/`)**:
  - Dart Shelf HTTP server integrating with PocketBase.
  - Idempotency & deduplication: Ensure request handling gracefully deduplicates duplicate submissions.
  - Clean error handling and proper HTTP status codes.

- **Documentation & Comments**:
  - Maintain documentation integrity. Do not strip comments or docstrings from existing code unless explicitly instructed.
