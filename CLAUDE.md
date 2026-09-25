# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## CRITICAL: Project Structure

**The Flutter application lives in `enchiridion/`, NOT at the repository root.**

```text
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

**There are no Flutter source files at the repository root.**

If you see `lib/`, `assets/`, or `pubspec.yaml` directly at the root, they are stale and should be ignored. Always edit Flutter source files under `enchiridion/`.

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
- `lib/screens/`: UI screens
- `lib/widgets/`: Reusable widgets
- `lib/models/`: Data models
- `lib/services/`: Business logic and data services
- `lib/providers/`: State management using Provider

## Scripts & Data

Python scripts are located in `scripts/` at the repository root.

## CRITICAL: Code Quality and Commenting Standards

**Code must be self-explanatory. Comments are the exception, not the default.**

These rules apply to all code written, generated, modified, or refactored in this repository, including Dart, Python, JavaScript, configuration files, and test code.

### 1. Multiline Comments Are Prohibited

Never introduce multiline comments or documentation blocks.

Prohibited forms include:

- Block comments such as `/* ... */`.
- Documentation blocks such as `/** ... */`.
- Consecutive single-line comments used to simulate multiline comments.
- Python triple-quoted strings used as explanatory comments.
- Generated documentation blocks describing otherwise understandable code.

Existing multiline comments should be removed or replaced with clearer code when modifying the relevant section, provided doing so does not change functionality.

Do not remove required copyright notices, license headers, or documentation mandated by external tools or frameworks. Treat these as narrow exceptions.

### 2. Prioritize Self-Explanatory Code

**Express intent through syntax, naming, and structure rather than comments.**

Follow these principles:

- Use descriptive, intention-revealing names for variables, functions, methods, classes, and constants.
- Prefer explicit conditions and readable expressions over clever or unnecessarily condensed syntax.
- Extract complex logic into small, clearly named functions.
- Replace unexplained literal values with meaningfully named constants.
- Maintain a clear separation of responsibilities.
- Prefer straightforward control flow and early returns where appropriate.
- Eliminate redundant abstractions and unnecessary complexity.
- Structure code so that its purpose can be understood without accompanying explanations.

Do not sacrifice readability merely to reduce line count.

### 3. Single-Line Comments: Strictly Limited

Single-line comments are permitted only when they communicate essential information that cannot reasonably be expressed through code.

Acceptable circumstances include:

- Explaining non-obvious business rules.
- Documenting necessary workarounds for external bugs or platform limitations.
- Identifying critical security constraints.
- Explaining decisions where the reason cannot be inferred from the implementation.

Rules:

- Use no more than one concise comment for a particular decision or constraint.
- Explain **why**, never merely **what** the code does.
- Never narrate straightforward operations.
- Never use comments as section headings or visual separators.
- Never leave commented-out code in committed changes.
- If an explanation requires multiple comment lines, first reconsider the implementation and simplify it.

TODO comments are allowed only when they identify a specific outstanding action that cannot be completed within the current task.

### 4. Refactoring Existing Code

When editing existing code:

1. Follow the established architecture and conventions.
2. Prefer improving naming and structure over introducing explanatory comments.
3. Remove redundant comments within the modified code.
4. Replace existing multiline comments with self-explanatory implementations wherever practical.
5. Preserve functionality unless the task explicitly requires behavioral changes.
6. Avoid unrelated refactoring solely to remove comments.

Do not introduce comments to compensate for unnecessarily complicated code.

### 5. Agent Output Requirements

Before completing any coding task, verify that:

- No new multiline comments or documentation blocks have been introduced.
- No consecutive single-line comments serve as disguised multiline comments.
- Every newly introduced comment is genuinely necessary.
- Names and control flow adequately communicate implementation intent.
- No commented-out code or unnecessary explanatory narration remains.
- Code formatting and relevant static analysis checks pass.

**Default behavior: Write zero comments. Introduce a single-line comment only when removing it would conceal essential information that the code itself cannot communicate.**