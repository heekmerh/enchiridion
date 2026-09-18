# Question serving and repetition

## Answer

`NextQuestionSelector.next` is the single entry point for choosing the next exam-prep question. It prioritizes due reviews and unseen questions, records each serve, and uses recent serves and review state to avoid immediate repeats. Its current fallback and cached preferences leave two gaps described below.

## How selection works today

There are three calls to `next`: the exam-prep home card when it loads, the same card after an answer, and the headless Android bubble worker in `bubble_alarm_callback.dart`. `in_app_study_prompt_host.dart` only opens the question named by a tapped notification; it does not select one.

The selector filters locked questions first. It puts eligible questions into lapsed-and-due, fresh-and-due, and unseen buckets. Due buckets sort by `dueAt`; the unseen bucket is shuffled once with the selector's unseeded `Random` by default. Lapsed due questions have first priority. The persisted serve counter's parity alternates whether fresh due or unseen questions come next. If no bucket yields a question, the fallback uses serve-log recency and review timestamps; before this fix, equal timestamps resolved deterministically from bank order.

Answer-option order is separate from question selection. `question_screen.dart` shuffles options with a seed supplied by its caller (or the question id by default), while `quick_check_card.dart` uses the question id and review attempt count. The exam-prep and notification callers derive the supplied seed from the question id and attempt count, keeping option order stable within an attempt.

## Repetition guarantees

1. A device-local, cross-surface `ServeLog` stores the 12 most recently served IDs, newest first. The selector skips these IDs while scanning priority buckets.
2. `_firstServable` applies a 90-minute cooldown against the review's `lastSeenAt`. That timestamp is updated when an answer is recorded, so it does not protect unanswered serves.
3. `QuestionReview.applyAnswer` assigns jittered spaced-repetition `dueAt` dates. Questions not yet due do not enter the due buckets.
4. Retired questions are excluded from the regular buckets and considered by the fallback only if no question still in rotation can be offered.

## Defects found

1. Serving a question records its ID in `ServeLog` but does not stamp `lastSeenAt`; only `applyAnswer` writes that timestamp. Never-answered questions therefore tie at the epoch in `_leastRecentlySeen`, whose strict `isBefore` comparison picks the first bank position. In a ten-question free-tier bank, ten serves fill the 12-slot recent log; all ten candidates are then filtered from the regular bucket and the fallback repeatedly picks that first question. The regression test serves 25 questions without answers and checks every rolling window of ten for distinct IDs.
2. The foreground app and headless bubble worker each hold a cached `SharedPreferences` instance. No selector path refreshes that cache, so a serve written by the other isolate is invisible until `reload()` is called. A held preferences instance reads an externally written serve log as empty before reload and sees the ID after reload; this defeats the intended cross-surface deduplication.
## Fixes applied

- `_leastRecentlySeen` now ranks questions missing from the recent serve log first, then logged questions from oldest serve to newest, then by review `lastSeenAt`, with an injected-random tie break. It still prefers questions in rotation over retired questions. The `rotates through the free-tier bank without repeating a question` test guards the ten-question, never-answered case across 25 serves.
- `NextQuestionSelector.next` now asks `StorageService` to reload its preferences cache before review migration or serve-log reads. The refresh is best-effort, so a platform failure still serves from cached state. The `sees a serve recorded by another isolate` test guards visibility of a serve written behind the foreground instance's cache.

## Recommended follow-ups

- The wrong-answer relearn interval is three hours in `question_review.dart`; a sibling batch item plans to move it to 24 hours. This item leaves it untouched.
- The headless bubble worker is the delivery path the sibling notification task will need.
- Hiding the bank size belongs to the question-list UI, not this selector.
- Review state syncs to Supabase, but `ServeLog` remains device-local. Two devices can still serve the same question.
