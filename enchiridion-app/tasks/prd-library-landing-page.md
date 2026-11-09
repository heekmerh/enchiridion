# PRD: Library Landing Page

## Introduction

The Library Landing Page is the first screen a user sees after logging in. It displays all available Enchiridion books as a scrollable grid of cards, each showing a thumbnail image and book title. Tapping a card opens that book. The screen also highlights recently opened books.

---

## Goals

- Show all 8 available books in a browsable grid
- Allow users to open any book by tapping its card
- Visually highlight recently opened books
- Provide a consistent, mobile-optimized entry point into content

---

## User Stories

### US-001: Display Book Grid
**Description:** As a logged-in user, I want to see all available books on the home screen so that I can choose what to read.

**Acceptance Criteria:**
- [x] Screen displays all 8 books: Paediatrics, Internal Medicine, Surgery, Obstetrics & Gynaecology, Psychiatry, Radiology, Orthopedics, Dermatology
- [x] Each book is shown as a card with: thumbnail image (from `Ideas/books/`) and book title below the image
- [x] Cards are arranged in a 2-column grid
- [x] Grid is vertically scrollable
- [x] Images load from local assets (bundled in the app)
- [x] Flutter analyzer passes with no errors

### US-002: Navigate into a Book
**Description:** As a user, I want to tap a book card to open that book so that I can start reading.

**Acceptance Criteria:**
- [x] Tapping any book card navigates to the Book Reader screen for that book, passing the book ID
- [x] Navigation uses GoRouter (or the app's established routing system)
- [x] Flutter analyzer passes with no errors

### US-003: Recently Opened Indicator
**Description:** As a returning user, I want to see which books I've recently opened so that I can quickly resume reading.

**Acceptance Criteria:**
- [x] Books opened by the user in the last 7 days are marked with a visible "Recent" badge or highlighted border
- [x] The most recently opened book appears first in the grid (pinned to position 1)
- [x] Recently opened state is stored locally on-device (user_book_history migrated from Supabase to SharedPreferences)
- [x] On first use (no history), all books appear in default order with no badges
- [x] Flutter analyzer passes with no errors

### US-004: App Bar with User Access
**Description:** As a logged-in user, I want to see my identity and access account settings from the library screen.

**Acceptance Criteria:**
- [x] App bar shows the Enchiridion logo/title on the left
- [x] App bar shows a profile avatar or icon on the right that navigates to the Profile screen
- [x] Flutter analyzer passes with no errors

---

## Functional Requirements

- FR-1: The library screen must be the default route for authenticated users
- FR-2: All 8 book thumbnails must be bundled as local assets in the Flutter app (not fetched remotely)
- FR-3: Book ordering: most recently opened book first; remaining books in a fixed default order
- FR-4: Recently opened state must be persisted to Supabase so it survives app restarts
- FR-5: Tapping a book must pass a `bookId` (string slug, e.g. `paediatrics`) to the reader screen
- FR-6: The grid must use a `GridView` with `crossAxisCount: 2` and consistent card aspect ratio

---

## Non-Goals

- Search or filtering of books â€” not in this version
- Book download / offline caching â€” not in this version
- Book descriptions or previews on the library screen â€” not in this version
- Progress indicators (% complete) per book â€” not in this version

---

## Design Considerations

- Card dimensions: square thumbnail filling card width, title below in 2 lines max
- Thumbnail images: `Ideas/books/Paediatrics.jpeg`, `Ideas/books/Internal Medicine.jpeg`, etc.
- "Recent" badge: small colored chip in the top-right corner of the card (e.g. teal with "Recent" text)
- Card spacing: 12px horizontal and vertical gap between cards
- Grid padding: 16px on all sides

---

## Technical Considerations

- Book list is a static Dart constant (list of `Book` objects with id, title, assetPath)
- Recently opened books fetched from Supabase on screen init; show grid immediately with cached/default order, update when fetch completes
- `user_book_history` table: `user_id` (UUID FK), `book_id` (text), `last_opened_at` (timestamp); RLS: users can only read/write their own rows
- On every book open, upsert a row in `user_book_history` with the current timestamp

---

## Success Metrics

- Library screen renders all 8 books within 500ms of navigation
- Recently opened book is visually distinct and at position 1 within 1 second of screen load
- Zero navigation failures when tapping any book card

---

## Open Questions

- Should the library screen have a "Continue Reading" shortcut that jumps to the last-read chapter, not just the book?
- Should book availability (e.g. locked under freemium) be indicated on the card itself?
