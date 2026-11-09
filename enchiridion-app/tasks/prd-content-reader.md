# PRD: Content & Reading Experience

## Introduction

The Book Reader is the core reading surface of Enchiridion. It renders book content from JSON data files, optimized for mobile. It includes keyword cross-referencing (tags that link to related sections), a collapsible side notes panel per topic, and floating annotations (clip-ins) that users can attach to specific topics.

---

## Goals

- Render book content in a clean, mobile-optimized layout from existing JSON data
- Surface keyword tags under each topic that link to related sections
- Allow users to write and save personal notes per topic (collapsible panel)
- Allow users to attach floating annotation cards to specific topics

---

## User Stories

### US-001: Render Book Content from JSON
**Description:** As a user, I want to read book content clearly formatted on my phone so that I can study effectively.

**Acceptance Criteria:**
- [x] The reader screen loads content for the selected book from the corresponding JSON data file
- [x] Chapter/topic titles are displayed as section headers
- [x] Body text, lists, and tables render correctly on a mobile screen (no horizontal overflow)
- [x] The user can scroll through the full book content vertically
- [x] A chapter/topic navigation panel (sidebar or bottom sheet) allows jumping to any section
- [x] Flutter analyzer passes with no errors

### US-002: Keyword Tags per Topic
**Description:** As a user, I want to see keyword tags under each topic so that I can discover related sections quickly.

**Acceptance Criteria:**
- [x] Each topic displays a horizontal row of keyword chips below its content
- [x] Each chip contains a single keyword (e.g. "Septic shock", "Fluid resuscitation")
- [x] Tapping a keyword chip navigates to the linked section within the same book (or another book if cross-book links are supported)
- [x] If a topic has no keywords, the chip row is not shown
- [x] Keywords are defined in the JSON data (each topic object has an optional `keywords` array)
- [x] Flutter analyzer passes with no errors

### US-003: Collapsible Side Notes Panel
**Description:** As a user, I want to expand a notes panel for any topic so that I can write and save personal notes while reading.

**Acceptance Criteria:**
- [x] Each chapter has a "Notes" button in the app bar (pencil icon) — implemented at chapter level, not per-topic
- [ ] Tapping the toggle expands an inline notes panel below the topic content — implemented as modal bottom sheet instead
- [x] The panel contains a text input field and a "Save" button
- [x] On save, note text is stored locally on-device (migrated from Supabase to SharedPreferences)
- [x] If a saved note exists for a topic, the panel shows the saved text pre-filled when expanded
- [x] Bottom sheet is dismissed to close the notes panel
- [x] Flutter analyzer passes with no errors

### US-004: Floating Annotations (Clip-ins)
**Description:** As a user, I want to attach a floating note card to a topic so that I can highlight key personal takeaways.

**Acceptance Criteria:**
- [x] A "Clip" action is available per topic (e.g. a pin/clip icon)
- [x] Tapping "Clip" opens a bottom sheet with a short text input (max 200 characters) and a "Save clip" button
- [ ] Saved clips appear inline — currently accessible via pin icon bottom sheet (not persistently visible above next section)
- [x] Clips are stored locally on-device (migrated from Supabase to SharedPreferences)
- [x] Tapping a clip card allows editing or deleting it
- [x] Flutter analyzer passes with no errors

### US-005: Chapter Navigation
**Description:** As a user, I want to jump to any chapter quickly so that I don't have to scroll the entire book.

**Acceptance Criteria:**
- [x] A navigation button (e.g. hamburger or list icon) opens a chapter list panel (drawer or bottom sheet)
- [x] The panel lists all chapters/topics in order
- [x] Tapping a chapter closes the panel and scrolls to that section
- [x] The currently visible chapter is highlighted in the list
- [x] Flutter analyzer passes with no errors

---

## Functional Requirements

- FR-1: Book content is loaded from local JSON asset files; each book has one JSON file keyed by book ID
- FR-2: The JSON schema for each topic must support: `id`, `title`, `content` (rich text or markdown), `keywords` (array of strings with optional target `topicId`)
- FR-3: Keyword chips must use the book's topic index to resolve link targets; broken links are silently omitted (no chip shown)
- FR-4: User notes are upserted (not duplicated) in Supabase â€” one row per (user_id, book_id, topic_id)
- FR-5: User clips are inserted as new rows; multiple clips per topic are allowed
- FR-6: RLS on `user_notes` and `user_clips`: users can only read/write their own rows
- FR-7: Content must not overflow horizontally on screens as narrow as 360px width

---

## Non-Goals

- Text highlighting / selection annotations â€” not in this version
- Sharing notes or clips with other users â€” not in this version
- Rich text formatting in notes (bold, lists) â€” plain text only
- Audio or video content â€” not in this version
- Offline content access â€” not in this version

---

## Design Considerations

- Content text: 16sp body, 20sp section headers, sufficient line height (1.5Ã—) for readability
- Keyword chips: outlined style, small font, wraps to multiple rows if many keywords
- Notes panel: light yellow background to distinguish from main content
- Clip card: elevated card with a pin icon, teal accent, positioned at bottom of topic

---

## Technical Considerations

- Use a `ScrollController` with a chapter index to support programmatic scroll-to-section
- Notes and clips fetched once on screen load (per book); stored locally in provider state during session
- `user_notes` schema: `id` (UUID PK), `user_id` (UUID FK), `book_id` (text), `topic_id` (text), `note_text` (text), `updated_at` (timestamp)
- `user_clips` schema: `id` (UUID PK), `user_id` (UUID FK), `book_id` (text), `topic_id` (text), `clip_text` (text, max 200 chars), `created_at` (timestamp)
- Consider `flutter_markdown` or a custom renderer depending on content format in the existing JSON

---

## Success Metrics

- Book content renders without overflow or layout errors on 360pxâ€“430px wide screens
- Notes save and reload correctly across app restarts
- Keyword chip navigation lands on the correct section within 300ms

---

## Open Questions

- What is the exact schema of the existing book JSON files? (Determines how content is parsed)
- Should keyword links be able to cross book boundaries (e.g. Paediatrics â†’ Internal Medicine)?
- Should clips be limited to one per topic, or unlimited?
