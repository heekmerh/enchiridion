# AGENTS.md

This file provides guidance to agents when working with code in this repository.

## Project Structure
- **Flutter App**: `enchiridion/` (Primary codebase)
- **Data Scripts**: `scripts/` (Python utilities)

## Critical Info
- **Framework**: Flutter (Dart >= 3.0.0)
- **State Management**: `provider` package (MultiProvider in `main.dart`)
- **Data Source**: `assets/data/book.json` is the bundled content source.
- **Scripts**: `scripts/search_sections.py` contains hardcoded paths that MUST be updated before running.
- **Dependencies**: Python scripts require `python-docx`.

## Commands
- **Flutter**: Run `flutter run` inside `enchiridion/`.
- **Scripts**: Run python scripts from `scripts/`.
