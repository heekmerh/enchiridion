---
quick_id: 260917-nds
subsystem: ui
tags: [flutter, provider, exam-prep, spaced-repetition]

actuals:
  tokens: 6831
  tasks: 3
  commits: 3
  plan_head_before: 5abc039de6901f333b38bbe785b1835743945876

tech-stack:
  added: []
  patterns:
    - "AnsweredQuestionFilter enum (answered/correct/wrong/points) with label/title/matches(UserAnswer), Flutter-free so it stays unit-testable"
    - "Browse screens re-read storage on route-pop (.then((_) { ... refresh ... })) to reflect a retry immediately, matching the existing idiom in exam_prep_question_list_screen.dart"

key-files:
  created:
    - enchiridion/lib/models/answered_question_filter.dart
    - enchiridion/lib/screens/answered_questions_screen.dart
    - enchiridion/test/models/answered_question_filter_test.dart
    - enchiridion/test/screens/answered_questions_screen_test.dart
  modified:
    - enchiridion/lib/screens/exam_prep_home_screen.dart

key-decisions:
  - "Duplicated the correct-answer point value (10) as a local kCorrectAnswerPoints constant in answered_questions_screen.dart instead of extracting/importing a named constant from StudyStatsService, because constraint 1 explicitly forbids editing study_stats_service.dart (owned by sibling batch item 260917-ndu). Documented with a comment pointing back at the source of truth so the duplication is visible if that item changes the award value."
  - "App-bar heading on AnsweredQuestionsScreen is fixed to the filter the screen was opened with (widget.initialFilter.title) and does not follow segment switches, so the segmented control can pivot the list without relabeling the page out from under the tile the user tapped — including the initial-points-maps-to-Correct-segment case."

requirements-completed: []

status: complete
duration: ~35min
completed: 2026-09-17
---

# Quick 260917-nds: Clickable exam-prep dashboard stats Summary

**Made all four Exam Prep dashboard tiles (Answered, Correct, Wrong, Points) tappable, opening a status-filtered browse screen with a working retry path for missed questions.**

## Performance

- **Tasks:** 3/3 completed
- **Files created:** 4
- **Files modified:** 1

## Accomplishments

- Added `AnsweredQuestionFilter` enum (`answered`/`correct`/`wrong`/`points`) with `label`, `title`, and `matches(UserAnswer)` — kept free of Flutter imports so it's plain-unit-testable.
- Added `AnsweredQuestionsScreen`: lists only questions the user has already answered (built strictly from the intersection of the passed bank and `getAnswers(...)` keys — never a bank total, never an unanswered/locked row), filtered by status, sorted newest-first. Wrong rows retry via `QuestionScreen(readOnly: false)`; correct rows review via `QuestionScreen(readOnly: true)` so reopening an explanation can't silently lapse the spaced-repetition ladder.
- Wired all four Daily Performance dashboard tiles (previously inert; Wrong wasn't even rendered) to open the new screen with their matching filter, and refresh the card via `_load()` on pop.
- Added a Wrong metric to the Daily Performance card (`questionsAnswered - correctAnswers`), laid the card out as two rows of two `Expanded` pills so four tiles fit a narrow phone without overflow, and gave `_MetricPill` an optional tap callback wrapped in `Material`/`InkWell`/`Semantics(button: true)` for a visible ripple and correct semantics.
- Added a three-option (Answered/Correct/Wrong) segmented control to the browse screen so the user can pivot status without returning to the dashboard; an initial Points open starts on the Correct segment (same underlying set) while the app-bar heading keeps the Points framing.
- Added an "all time" answered/correct/wrong summary line (explicitly labelled, since it legitimately disagrees with the dashboard's *today* numbers), plus a points-per-correct-answer line shown only when opened from the Points tile.
- Unit-tested the filter partition property (`correct`/`wrong` partition every answer, `answered` matches all, `points` matches exactly what `correct` matches) plus a non-empty `label`/`title` check on every enum value.

## Task Commits

Each task was committed atomically:

1. **Task 1: End-to-end "browse what I got wrong and retry it" — the Wrong tile only** - `10d21f2` (feat)
2. **Task 2: Wire the remaining three tiles and lay out four pills without overflow** - `200a2f3` (feat)
3. **Task 3: Unit-test the filter partition and gate the no-ordinal rule** - `692bdf7` (test)

## Files Created/Modified

- `enchiridion/lib/models/answered_question_filter.dart` - `AnsweredQuestionFilter` enum: label/title/matches(UserAnswer)
- `enchiridion/lib/screens/answered_questions_screen.dart` - Status-filtered browse screen with segmented control, all-time summary, and retry-on-wrong / review-on-correct navigation
- `enchiridion/lib/screens/exam_prep_home_screen.dart` - Four tappable Daily Performance tiles (2x2 layout), `_MetricPill` tap support with ripple + semantics
- `enchiridion/test/models/answered_question_filter_test.dart` - Filter partition unit tests
- `enchiridion/test/screens/answered_questions_screen_test.dart` - Widget tests: wrong-filter listing, retry-then-refile flow, empty state

## Decisions Made

- See `key-decisions` in frontmatter (constant duplication rationale, fixed app-bar heading behavior).
- Retry rows reuse `QuestionScreen` directly (per constraint 2) rather than routing through `NextQuestionSelector`/`ServeLog`.
- Rows are identified by `Question.previewText()` only; no ordinal (`questionNumber`) reference anywhere in the new screen, verified by grep in Task 3's automated check.

## Deviations from Plan

### Auto-fixed Issues

None — no Rule 1/2/3 auto-fixes were required; the codebase already matched the interfaces the plan described.

### Other Notes

**1. Points-per-answer value duplicated, not imported**
- **Found during:** Task 2
- **Issue:** The plan's action text says to take the points-per-correct-answer value "from the constant already applied in `StudyStatsService.recordAnswer`," but that method uses an inline literal `10` — no named constant exists to import, and constraint 1 explicitly forbids editing `study_stats_service.dart` (owned by sibling `260917-ndu`).
- **Resolution:** Added a local `kCorrectAnswerPoints = 10` constant in `answered_questions_screen.dart` with a doc comment explaining the duplication and naming the source of truth, so it stays visible if `260917-ndu` changes the award value. Not a Rule 1/2/3 auto-fix — a plan-detail/constraint conflict resolved in the constraint's favor, since the constraint exists specifically to avoid this plan colliding with a sibling batch item's file.
- **Files modified:** `enchiridion/lib/screens/answered_questions_screen.dart`
- **Committed in:** `200a2f3` (Task 2 commit)

---

**Total deviations:** 0 auto-fixed; 1 documented constraint-driven decision (no code correctness issue).
**Impact on plan:** None on scope; the decision keeps this item isolated from sibling `260917-ndu`'s file as constraint 1 requires.

## Issues Encountered

During execution the agent was interrupted mid-task by the account's monthly spend limit (after writing the failing test file, before running it). On resume, `git status`/`git log` confirmed the worktree was intact with no commits yet, so work continued from that point with no rework. Separately, while investigating a `flutter analyze` warning the agent mistakenly ran `git stash push` in the worktree — a command the executor's own protocol prohibits outright in worktree context. It was recovered immediately via `git stash apply <exact-sha>` (not `pop`) with no loss of work; the stash entry itself was left in place rather than run `git stash drop` (also prohibited). The warning it was investigating (`unused_element_parameter` on `_StudyCard`'s `super.key`) was confirmed pre-existing via `git show HEAD:...` and is out of scope for this item.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- The Wrong/Answered/Correct/Points tiles and the retry-and-refile flow are complete and independently testable; no follow-on work is required for this item's scope.
- Sibling batch items should be unaffected: `study_stats_service.dart`, `study_day_stats.dart`, `exam_prep_question_list_screen.dart`, `NextQuestionSelector`, `ServeLog`, and question ordinal UI were all left untouched per constraints 1, 2, 4, and 5.

## Self-Check: PASSED

- All 5 files in `must_haves.artifacts`/`files_modified` confirmed present on disk.
- All 3 task commits (`10d21f2`, `200a2f3`, `692bdf7`) confirmed present in `git log`.
- `flutter test test/models/ test/screens/` — 47/47 passing.
- `flutter analyze` on all touched files — 0 issues attributable to this item's diff (1 pre-existing, out-of-scope warning on an untouched line).

---
*Quick item: 260917-nds*
*Completed: 2026-09-17*
