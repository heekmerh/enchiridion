---
quick_id: 261116-cqf
status: complete
commit: bc94467
---

# Topic notes in resources: summary

- Extracted the reader's Chapter Notes sheet into `lib/widgets/notes/chapter_notes_sheet.dart` (`showChapterNotesSheet`, noun-parameterised copy).
- Reader uses the shared sheet; no behaviour change (reader_notes_test passes).
- Resource topic and OSCE detail screens have a new "Topic notes" (edit_note) app bar action. Notes are keyed `topic.notesScope` / `topic.id`, so outline-only topics work too and sync through the existing reading-notes path.
- New test: test/screens/resource_topic_notes_test.dart. `flutter analyze` clean; all of test/screens passes.
- Margin (long-press) notes were already available in resources; unchanged.
