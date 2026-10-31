# Frontend Application (`frontend`)

## Overview
Flutter application for the Cyrillic to Traditional Mongolian conversion suite, targeting Web and Desktop platforms. Features vertical script rendering, side-by-side editing, homonym disambiguation, and moderator workstations.

## Subdirectories & Boundaries
- [lib](./lib/README.md): Application bootstrapping, token models, vertical Mongolian text controllers, desktop design system, dialog workflows, dictionary search, and moderator station.

## Verification & Build

```bash
# Run unit and widget tests
flutter test

# Run static analysis
flutter analyze

# Build optimized production web assets
flutter build web --release --dart-define=API_BASE_URL=https://api.yourdomain.com
```
