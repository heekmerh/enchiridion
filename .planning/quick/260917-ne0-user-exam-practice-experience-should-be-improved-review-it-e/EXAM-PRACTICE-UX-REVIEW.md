# Exam Practice UX Review

## Scope and method

This review was produced by reading the live repository tree after fast-forwarding the execution worktree onto the shared `main` branch, which carries every fix from the ten dependency quick-batch items. Every behavioral claim below cites the repository-relative path it was read from; nothing here restates this plan's own prose about what the app used to do, since that prose was written before the siblings landed. Reviewed surfaces: enchiridion/lib/screens/exam_prep_home_screen.dart, enchiridion/lib/screens/question_screen.dart, enchiridion/lib/screens/question_list_screen.dart, enchiridion/lib/services/next_question_selector.dart, enchiridion/lib/services/study_stats_service.dart, enchiridion/lib/services/notification_service.dart, enchiridion/lib/services/bubble_alarm_callback.dart, enchiridion/lib/services/question_review_sync_service.dart, enchiridion/lib/models/question_review.dart, enchiridion/lib/models/study_day_stats.dart, enchiridion/lib/models/serve_log.dart, enchiridion/lib/config/freemium_config.dart, enchiridion/lib/widgets/exam_prep/quick_check_card.dart, enchiridion/lib/widgets/exam_prep/in_app_study_prompt_host.dart, enchiridion/lib/services/access_service.dart, enchiridion/lib/screens/unlock_screen.dart, enchiridion/lib/screens/answered_questions_screen.dart, enchiridion/lib/services/leaderboard_service.dart, enchiridion/android/app/src/main/kotlin/com/example/enchiridion/BubbleAlarmWorker.kt, and enchiridion/android/app/src/main/kotlin/com/example/enchiridion/BubblePlugin.kt, cross-checked against `git log --oneline` and `git show --stat` for what each sibling actually changed.

HEAD commit: ee0f1ed

Sibling items present in history: all ten of 260917-ndq, 260917-ndr, 260917-nds, 260917-ndt, 260917-ndu, 260917-ndv, 260917-ndw, 260917-ndx, 260917-ndy, 260917-ndz are present in `git log --oneline`, so this review reflects the fully corrected post-fix tree, not a pre-fix snapshot.

## Sibling coverage map

| Quick id | Area | Scope it owns |
| --- | --- | --- |
| 260917-ndq | 2 | Removed the whole-bank-size disclosure from the exam-prep library review entry and the Access card subtitle, so free users see only their own answered questions and entitlement state, never a bank total. |
| 260917-ndr | 1 | Fixed the question/answer explanation renderer to preserve literal newlines instead of collapsing them, via a shared ExplanationText widget used across the practice and Quick Check surfaces. |
| 260917-nds | 4 | Wired the Answered/Correct/Wrong/Points metric tiles on the Exam Prep home screen to open a filtered, previously-answered-only review list. |
| 260917-ndt | 1 | Removed literal question-number ordinals from exam-prep and question-list screen UI text, leaving only question content and status. |
| 260917-ndu | 4 | Fixed the daily study stats and points system so repeat or Quick Check answers no longer double-count questionsAnswered or performancePoints. |
| 260917-ndv | 1 | Gave the practice-one-now question screen an in-place "Next question" control with an auto-advance countdown after an answer. |
| 260917-ndw | 5 | Rotated served-question selection through a shared serve log with a cooldown and due/lapse buckets, replacing independent per-surface random rolls. |
| 260917-ndx | 2 | Deleted the whole-bank question list screen and its "Browse Full Bank" entry point from the Exam Prep home screen. |
| 260917-ndy | 5 | Made a wrong answer requeue after 24 hours via QuestionReview's relearn interval, instead of never resurfacing it. |
| 260917-ndz | 3 | Restored the Android ambient bubble/Quick Check delivery path after a startup regression stopped notifications firing for hours at a time. |

## Area 1 - Practice session flow

### Observed behavior

`ExamPrepHomeScreen._load()` loads the question bank, the user's exam-prep access flag, previously recorded answers, and a single next question from `NextQuestionSelector`, seeding the on-screen option order from `Object.hash(question.id, review?.attempts ?? 0)` (enchiridion/lib/screens/exam_prep_home_screen.dart). The home screen's "Quick Check" card offers exactly one entry point, a "Practice one now" button, which pushes `QuestionScreen` with `onAnswered` wired to `_handleStudyCardAnswer` (records the answer locally and re-picks the next question) and `onRequestNext` wired to `_serveNextQuestion` (hands over the already-picked next question without invoking the selector a second time) (enchiridion/lib/screens/exam_prep_home_screen.dart). Inside `QuestionScreen`, selecting an option and tapping Submit calls `_submit()`, which records the `UserAnswer` through `StorageService.recordAnswer`, then (when `trackDailyStudyStats` is set) through `StudyStatsProvider.recordAnswer`, then invokes `widget.onAnswered`, then fires two best-effort background calls, `NotificationService.scheduleFollowUp` and `QuestionReviewSyncService(storage).push` (enchiridion/lib/screens/question_screen.dart). Feedback renders immediately below the options: a green/red "Correct!"/"Incorrect" banner, an "Explanation" section rendered through `ExplanationText` (which preserves literal newlines per sibling 260917-ndr), and an optional teal "OSCE Tip" box when `question.osceTip` is set (enchiridion/lib/screens/question_screen.dart, enchiridion/lib/widgets/exam_prep/explanation_text.dart). When `onRequestNext` is supplied and the screen is not read-only, submitting starts a fixed six-second auto-advance countdown (`_feedbackPause`) showing "Next question in Ns", a "Next question" button, and a "Stay on this question" cancel control; on expiry `_advance()` awaits the loader and swaps `_question`/`_optionSeed` in place, or sets `_exhausted = true` and shows "You're all caught up — nothing more is queued right now." when the loader returns null (enchiridion/lib/screens/question_screen.dart). Leaving the flow otherwise is only "Back to question list" (`Navigator.pop`). The book-scoped `QuestionListScreen` (used for per-book question banks, not the standalone exam-prep scope) shows only previously-answered questions via `reviewableQuestions`, with a padlock icon on anything past `kFreeQuestionCount` (enchiridion/lib/screens/question_list_screen.dart, enchiridion/lib/services/question_visibility.dart). The former whole-bank browsing screen no longer exists in this tree at all — `git log --diff-filter=D --oneline -- '*exam_prep_question_list_screen.dart*'` shows it deleted in commit 66b6a80, sibling 260917-ndx's work. The Android bubble window renders the same one-question flow through a separately implemented `QuickCheckCard`, with its own Submit/Skip/Close controls and no auto-advance or next-question chaining at all (enchiridion/lib/widgets/exam_prep/quick_check_card.dart, enchiridion/lib/bubble_main.dart).

### Findings

A practice session has no defined start or end: opening Exam Prep serves exactly one question at a time from the home screen's Quick Check card, with no "how many questions in this session" framing, no progress indicator, and no session summary — the six-second auto-advance is the only through-line, and cancelling it just returns to the same single-question card with nothing to work toward. The "Next question in Ns" auto-advance timer runs on a fixed six seconds regardless of explanation length (enchiridion/lib/screens/question_screen.dart, `_feedbackPause`), forcing a user who wants to actually read the OSCE tip to consciously tap "Stay on this question" every single time, which is friction hidden inside a feature meant to remove friction. There is no self-rated confidence input anywhere in the answer flow — `_submit()` builds `UserAnswer` from only `isCorrect`, and `QuestionReview.applyAnswer`'s `confident` parameter (which exists specifically to distinguish a guess from real knowledge and route to `guessedInterval`) is never passed a non-default value from any of the three answer-recording call sites, so a lucky guess is scheduled on the ladder identically to a knowledge-based correct answer. The bubble `QuickCheckCard` duplicates almost all of `QuestionScreen`'s submit/explanation rendering with its own separate `State` class and stops at Close — even though the same `NextQuestionSelector` that powers the home screen's advance could hand the bubble window another question immediately, a user who has the bubble open and wants to keep going has no way to.

### Recommendations

#### R-01: Give the practice session an explicit shape
Turn "Practice one now" into a bounded practice set — e.g. offer a 10-question run with a visible "N of 10" progress indicator on `QuestionScreen`'s app bar and a session-end summary card (answered, correct, points earned this run) once the set completes, instead of an undifferentiated stream of single questions. This sits directly on top of 260917-ndv's existing in-place advance mechanism (`onRequestNext`/`_advance()` in enchiridion/lib/screens/question_screen.dart already swap the question without leaving the route) — it only needs a counter and a terminal state layered over that plumbing, not a new advance mechanism.

#### R-02: Gate the auto-advance pause on self-rated confidence
After submit, offer an inline "Sure / Guessed" choice instead of (or before) starting the fixed six-second countdown, and thread the answer into the `confident` parameter `QuestionReview.applyAnswer` already accepts but which the practice flow never supplies (enchiridion/lib/models/question_review.dart). This makes the existing `guessedInterval` branch actually reachable from real user behavior, and lets the pause length reflect how sure the user was rather than a flat six seconds for everyone.

#### R-03: Let a bubble Quick Check answer chain into another question
Extend `QuickCheckCard`/`bubble_main.dart` so a submitted bubble answer can load a second question via `NextQuestionSelector.next()` and swap it in place, instead of ending every bubble interaction at Close or Skip (enchiridion/lib/widgets/exam_prep/quick_check_card.dart, enchiridion/lib/bubble_main.dart). This keeps the bubble's "one light question, minimal chrome" character intact while giving a user who wants to keep going in that small window a way to, without forcing them back into the full app.

## Area 2 - Freemium question limit

### Observed behavior

_Pending Task 2._

### Findings

_Pending Task 2._

### Recommendations

_Pending Task 2._

## Area 3 - Study-mode notification delivery

### Observed behavior

_Pending Task 2._

### Findings

_Pending Task 2._

### Recommendations

_Pending Task 2._

## Area 4 - Stats and points feedback loop

### Observed behavior

_Pending Task 2._

### Findings

_Pending Task 2._

### Recommendations

_Pending Task 2._

## Area 5 - Retry and review flow

### Observed behavior

_Pending Task 2._

### Findings

_Pending Task 2._

### Recommendations

_Pending Task 2._

## Prioritized recommendations

| ID | Recommendation | Area | Class | Impact | Effort | Sibling overlap | Evidence |
| --- | --- | --- | --- | --- | --- | --- | --- |
| R-01 | Give the practice session an explicit shape | 1 | standard-practice | high | medium | adjacent: 260917-ndv | enchiridion/lib/screens/question_screen.dart |
| R-02 | Gate the auto-advance pause on self-rated confidence | 1 | standard-practice | medium | small | none | enchiridion/lib/models/question_review.dart |
| R-03 | Let a bubble Quick Check answer chain into another question | 1 | innovation | medium | medium | none | enchiridion/lib/widgets/exam_prep/quick_check_card.dart |

## Explicitly out of scope

_Pending Task 2._
