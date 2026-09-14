# Codebase Concerns: Enchiridion

This document outlines technical debt, potential risks, architectural weaknesses, and performance bottlenecks identified in the Enchiridion project.

## 1. Technical Debt

### Flutter/Dart Codebase
- **Direct JSON Serialization in Storage:** `StorageService` serializes and deserializes complex objects (bookmarks, settings) as JSON strings directly into `SharedPreferences`. As data grows, this becomes inefficient and error-prone.
- **Synchronous JSON Parsing:** Large JSON data (the entire book) is loaded and decoded on the main UI thread in `BookService.loadBook()`. This can cause significant UI "jank" or freezing during app initialization.
- **Beta Dependencies:** The project relies on `flutter_html: ^3.0.0-beta.2`. Using beta versions in production-targeted code introduces risks of breaking changes and unresolved bugs.
- **Static Service Pattern:** `BookService` is implemented using static methods, which complicates dependency injection and makes unit testing/mocking more difficult.
- **Inconsistent State Management:** UI state (drawers, timers, controls visibility) is mixed between local `setState` in `ReaderScreen` and global `Provider` state, increasing cognitive load for maintainers.

### Python Scripts
- **Hardcoded Paths:** Many scripts (e.g., `grobid_processor.py`) contain hardcoded file paths and URLs (like the local GROBID service), making the pipeline fragile across different environments.
- **Lack of Type Hinting:** While some type hints are present, coverage is inconsistent across the Python codebase, potentially leading to runtime errors during data processing.
- **Manual Pipeline Steps:** The data pipeline from PDF to Flutter-ready JSON requires several manual steps and a local GROBID installation, which is not integrated into a CI/CD or automated build process.

## 2. Potential Risks

- **Memory Exhaustion:** Loading the entire medical textbook into memory as a single `Book` object could lead to crashes on low-end mobile devices if the content grows significantly.
- **Data Integrity:** There is minimal validation for the `book.json` asset. A malformed JSON file will prevent the app from starting or cause runtime exceptions.
- **Medical Information Accuracy:** The reliance on automated PDF extraction (GROBID) for medical content is inherently risky. Any extraction error could lead to incorrect medical information being displayed to the user.
- **Dependency on Local GROBID:** The processing pipeline is entirely dependent on a local GROBID instance, which may be difficult for new contributors to set up and maintain.
- **Content Stale-ness:** Since all content is bundled as an asset, updates to the textbook require a full application update through app stores.

## 3. Missing Documentation

- **Architectural Specification:** There is no high-level document describing the system architecture, data flow, or the relationship between the Python extraction layer and the Flutter presentation layer.
- **Data Schema Definition:** The structure of `book.json` is not formally defined (e.g., via JSON Schema), making it difficult to validate the output of the extraction pipeline.
- **Developer Onboarding:** Comprehensive setup instructions for the Python environment and GROBID service are fragmented across multiple files (`GROBID_README.md`, `grobid_setup.md`).
- **Test Coverage Map:** While tests exist, there is no documentation on the testing strategy or coverage goals for either the Flutter or Python components.

## 4. Architectural Weaknesses

- **Violations of Single Responsibility Principle:** `ReaderScreen` is a "God Widget" that manages UI layout, navigation logic, auto-hide timers, and drawer states simultaneously.
- **Lack of Repository Pattern:** The app lacks a repository layer to abstract data sourcing. This makes it difficult to transition from local JSON to a database (like SQLite or Isar) or a remote API in the future.
- **Tight Coupling:** The UI components are tightly coupled to specific Provider implementations, making it harder to swap state management solutions or refactor the data layer.
- **Direct UI-Service Interaction:** The UI calls services directly in some cases, bypassing the provider/state management layer.

## 5. Performance Bottlenecks

- **Main-Thread Blocking:** Decoding a multi-megabyte JSON file on the main thread will block UI rendering. This should be moved to a background isolate.
- **Non-Virtualized Content Rendering:** `ReaderContent` renders the entire HTML content of a chapter at once using `flutter_html` inside a `SliverToBoxAdapter`. For very long chapters, this will lead to high memory usage and slow rendering.
- **Inefficient Storage Updates:** Every time a single bookmark is added or removed, the entire list is re-serialized and written to `SharedPreferences`.
- **Large Asset Loading:** Loading the entire book asset into memory on startup (even if only one chapter is visible) is inefficient. A more performant approach would be to lazy-load chapters or use a database.
