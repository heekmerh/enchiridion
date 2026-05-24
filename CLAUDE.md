# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## CRITICAL: Project Structure

**The Flutter application lives in `enchiridion/` — NOT at the repository root.**

```
repo root/
├── enchiridion/        ← THE Flutter app (all Flutter source is here)
│   ├── lib/
│   ├── assets/
│   ├── pubspec.yaml
│   └── ...
├── .planning/          ← GSD planning artifacts
├── integration_test/   ← Auth e2e tests
├── scripts/            ← Python data utilities
└── CLAUDE.md
```

**There are no Flutter source files at the repository root.** If you see `lib/`, `assets/`, or `pubspec.yaml` directly at the root, they are stale and should be ignored. Always edit files under `enchiridion/`.

## Development Commands

All Flutter commands must be run from the `enchiridion/` directory:

```bash
cd enchiridion
flutter pub get
flutter run
flutter test
flutter analyze
```

## Architecture

The Flutter app (`enchiridion/`) follows standard Flutter structure:
- `lib/main.dart`: Entry point
- `lib/screens/`: UI Screens
- `lib/widgets/`: Reusable widgets
- `lib/models/`: Data models
- `lib/services/`: Business logic and data services
- `lib/providers/`: State management (using Provider)

## Scripts & Data

Python scripts are located in `scripts/` (repo root level).
