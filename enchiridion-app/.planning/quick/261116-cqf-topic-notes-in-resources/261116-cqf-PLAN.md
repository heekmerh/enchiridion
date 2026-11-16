---
quick_id: 261116-cqf
mode: quick
description: Bring the book reader's Chapter Notes sheet to resource topics
---

# Topic notes in resources

Book chapters have a free-text Chapter Notes sheet (the edit_note button in the
reader app bar). Resource topics already support margin (long-press) notes via
`ResourceTopic.notesScope`, but they lack this sheet.

## Task 1: Extract the sheet into a shared widget
- files: lib/widgets/notes/chapter_notes_sheet.dart (new), lib/screens/reader_screen.dart
- action: Move `_NotesBottomSheet` out of reader_screen.dart into a public
  `ChapterNotesSheet` + `showChapterNotesSheet()` helper, parameterised by a
  noun ("chapter"/"topic") for its title, hint and snackbar copy. Reader uses it
  unchanged in behaviour.
- done: reader still opens the same sheet; no behaviour change.

## Task 2: Add topic notes to resource screens
- files: lib/screens/resource_topic_detail_screen.dart, lib/screens/osce_screen.dart
- action: Add an edit_note app bar action that opens the sheet with
  bookId = topic.notesScope, chapterId = topic.id (works even for
  outline-only topics with no content JSON). Storage/sync reuse the existing
  reading-notes path.
- verify: flutter analyze clean; existing tests pass.
