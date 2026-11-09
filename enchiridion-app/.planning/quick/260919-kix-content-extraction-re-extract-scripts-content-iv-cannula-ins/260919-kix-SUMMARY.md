---
quick_id: 260919-kix
phase: quick-260919-kix
plan: 01
subsystem: content
tags: [iv-cannula, docx, resource-extraction, subtopics]
status: complete
dependency-graph:
  requires: []
  provides:
    - "TopicSpec.bold_heading_min_pt opt-in styled-heading rule in scripts/generate_resource_content.py"
    - "regenerated enchiridion/assets/data/resources/iv_cannula.json (34 subsections)"
    - "repeatable --topic SLUG CLI flag on scripts/generate_resource_content.py"
  affects:
    - "enchiridion/lib/widgets/common/subtopic_tabs.dart (consumes the new subsections with no code change)"
tech-stack:
  added: []
  patterns:
    - "Opt-in per-TopicSpec formatting signal (bold_heading_min_pt) instead of a global heading heuristic, to avoid restructuring already-shipped topics"
key-files:
  created:
    - scripts/tests/test_generate_resource_content.py
  modified:
    - scripts/generate_resource_content.py
    - enchiridion/assets/data/resources/iv_cannula.json
decisions:
  - "Sutures' TopicSpec.title was drifted (\"Sutures\" vs. shipped \"Suture Material\" from prior task 260918-dr1); corrected the spec's title to match the already-shipped asset rather than touching sutures.json, since the source document has no paragraph literally reading \"Sutures\" for the doc-title skip filter to key off"
  - "build_topic_json() now writes generated JSON with explicit newline=\"\\r\\n\" to match the bundled assets' existing CRLF convention, same rationale as the already-CRLF normalize_questions() output"
metrics:
  duration: ~35m
  completed: 2026-09-19
actuals:
  tokens: 6342
  tasks: 3
  commits: 2
plan_head_before: 7662dc01adfba2888d81a523430da220f1262f8e
---

# Phase quick-260919-kix Plan 01: Re-extract IV Cannula with paragraph-formatting-aware headings Summary

Taught the shared resource extractor to recognize bold, explicitly-large-run
paragraphs as headings (opt-in per topic), then regenerated the IV Cannula
module so Advantages, Disadvantages, Precautions, and Complications became
their own subtopic tabs instead of a single 45-item bullet dump.

## What Was Built

**Task 1 — Paragraph-formatting-aware headings, end to end, for IV Cannula only.**
Added `TopicSpec.bold_heading_min_pt: float | None = None` (opt-in, defaults
preserve the other two topics' behavior unchanged). Added module-level
`styled_heading_paragraph(paragraph, min_pt)`, which requires every non-empty
run in the paragraph to be bold AND at least one run to carry an explicit
`font.size.pt >= min_pt` — a bold run with no explicit size (the "Cannula
blockage" case) is deliberately excluded, keeping it a list item.

Widened `is_heading(text, style_name, paragraph=None, bold_heading_min_pt=None)`:
the three existing rules (Heading style, numbered prefix, all-caps) run first,
unchanged; `styled_heading_paragraph` is only consulted as a fallback. The
`build_topic_json` call site now passes the live `paragraph` object (materialized
via `list(iter_block_items(document))` before the loop, so there is no stale
generator side-channel) and `spec.bold_heading_min_pt`.

Set `bold_heading_min_pt=13.5` on the `iv_cannula` spec only. Added a repeatable
`--topic SLUG` CLI flag to `main()` that filters `TOPICS` and skips
`normalize_questions()` entirely (so a single-topic regeneration cannot rewrite
the exam question asset), and raises a clear error listing valid slugs for an
unknown one. Regenerated with `python3 scripts/generate_resource_content.py
--topic iv_cannula`: 34 subsections (up from 28); Advantages (5 entries),
Disadvantages (5), Precautions (8), Complications (8) are now subsection
titles; `Cannula blockage` remains the last Complications list item; `Overview`
still holds both images.

**Task 2 — Regression test lock-in.** Added
`scripts/tests/test_generate_resource_content.py` (stdlib `unittest`, no
`pytest`): 4 unit tests for `styled_heading_paragraph` covering the bold+large,
opted-out, bold-without-size, and large-without-bold cases; an integration
test reading the committed `iv_cannula.json` directly (not regenerating) that
asserts the four labels are subsection titles, none appears in any checklist,
and Complications ends with "Cannula blockage"; and a byte-identity stability
test that regenerates `sutures` and `abdominal_examination` into a
`tempfile.TemporaryDirectory` (module globals `RESOURCE_DATA_DIR` /
`RESOURCE_ASSET_DIR` redirected in `setUp`, restored via `addCleanup`) and
compares the produced bytes against the committed assets.

**Task 3 — Confirmed no Flutter change needed.** Re-read
`subtopicTabsFor` in `enchiridion/lib/widgets/common/subtopic_tabs.dart`:
the branch for "1 section, 2+ subsections" emits one tab per subsection by
default, and only takes the grouped `isSectionHeading` path when that optional
predicate is supplied. Confirmed
`enchiridion/lib/screens/resource_topic_detail_screen.dart`'s
`SubtopicTabsView(topic: widget.topic, chapter: _chapter)` call omits
`isSectionHeading` — that predicate is OSCE/Abdominal-Examination-specific
and lives in `enchiridion/lib/utils/osce_subtopics.dart`. So the six new IV
Cannula subsections become six new tabs automatically; no Dart change was
needed or made. `flutter analyze` and the scoped Dart test files
(`test/widgets/subtopic_tabs_test.dart`, `test/models/`,
`test/screens/resource_topic_list_screen_grouping_test.dart`,
`test/utils/osce_subtopics_test.dart`) ran clean/green — 89 tests passed, no
hard-coded IV Cannula subsection count needed updating. No file under
`enchiridion/lib/` was modified.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `build_topic_json` wrote LF instead of the bundled assets' CRLF**
- **Found during:** Task 2, while validating the regenerated `iv_cannula.json` diff
- **Issue:** On this Linux environment, `target.write_text(json.dumps(...), encoding="utf-8")` (no `newline` argument) wrote `\n` line endings, but the previously-committed resource JSONs (all three topics) use `\r\n`. Left as-is, every regeneration would flip every line's ending, making diffs unreviewable and defeating the "only `iv_cannula.json` changes" verification gate.
- **Fix:** Added `newline="\r\n"` to the `write_text` call in `build_topic_json`, matching the explicit CRLF choice `normalize_questions()` already makes for the question asset, with a comment explaining why.
- **Files modified:** `scripts/generate_resource_content.py`
- **Commit:** `346fb98`

**2. [Rule 1 - Bug] `TopicSpec.title` for `sutures` had drifted from the shipped asset**
- **Found during:** Task 2, writing the byte-identity stability test
- **Issue:** Quick task `260918-dr1` renamed the shipped topic from "Sutures" to "Suture Material" by editing `sutures.json`'s `chapter_title`/`section_title`/`tags` directly, without updating the generator's `TopicSpec.title`. Regenerating `sutures` from the unmodified spec produced `"Sutures"` instead of the committed `"Suture Material"`, breaking the plan-mandated byte-identity test and meaning `--topic sutures` (the new CLI capability this plan added) could never reproduce the committed file.
- **Fix:** Updated the `sutures` `TopicSpec.title` to `"Suture Material"`. Verified empirically (temp-dir regeneration diffed field-by-field) that this only changes the three title-derived metadata fields — the source `.docx` has no paragraph literally reading "Sutures" for the doc-title skip filter (`text == spec.title`) to key off, so section/subsection structure is unaffected. `sutures.json` itself was not regenerated by this plan (only `iv_cannula.json` was) — this fix only changes what `--topic sutures` would produce if run later.
- **Files modified:** `scripts/generate_resource_content.py`
- **Commit:** `346fb98`

Both fixes are pre-existing generator/asset drift unrelated to the heading-rule feature itself, but were blocking for this plan's verification and were caught while implementing it, so both were fixed inline per Rule 1 rather than deferred.

## Not Manually Verified

Task 3's `<human-check>` ("Open the IV Cannula module in the running app and
page through the tab strip") was not run — this executor has no way to launch
and interact with the Flutter app. Confidence instead comes from: (a) the
`subtopicTabsFor` contract read directly from source, (b) the unmodified,
passing Dart test suite for that widget and its callers, and (c) the
regenerated JSON's structure matching exactly what that contract expects
(one section, 34 subsections). Recommend a human spot-check the IV Cannula
module's tab strip in a running build before considering this fully closed.

## Self-Check: PASSED

- FOUND: `scripts/generate_resource_content.py` (modified, contains `styled_heading_paragraph`, `bold_heading_min_pt`, `--topic` flag)
- FOUND: `scripts/tests/test_generate_resource_content.py`
- FOUND: `enchiridion/assets/data/resources/iv_cannula.json` (34 subsections)
- FOUND commit `37c645d` (Task 1)
- FOUND commit `346fb98` (Task 2, includes the two Rule 1 fixes)
- Task 3 modified no files, so no commit is expected for it — confirmed `git status --short` is clean after Task 3's verification-only work.
