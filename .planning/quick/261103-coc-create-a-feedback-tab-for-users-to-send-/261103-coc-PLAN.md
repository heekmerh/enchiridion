---
phase: quick-261103-coc
plan: 01
quick_id: 261103-coc
type: execute
wave: 1
depends_on: []
files_modified:
  - /home/kaasor/Documents/Backup/Hikma/Enchiridion/enchiridion-web/supabase/enchiridion_master.sql
  - /home/kaasor/Documents/Backup/Hikma/Enchiridion/enchiridion-web/docs/database.md
  - enchiridion/lib/services/feedback_service.dart
  - enchiridion/lib/screens/feedback_screen.dart
  - enchiridion/lib/screens/library_screen.dart
  - enchiridion/test/services/feedback_service_test.dart
  - enchiridion/test/screens/feedback_screen_test.dart
  - enchiridion/test/screens/library_screen_test.dart
autonomous: false
requirements:
  - QUICK-261103-coc
user_setup:
  - service: supabase
    why: "public.app_feedback must exist in the live project before any submission can succeed; this project applies schema changes by hand"
    dashboard_config:
      - task: "Paste the whole of enchiridion-web/supabase/enchiridion_master.sql and click Run"
        location: "Supabase Dashboard -> SQL Editor -> New query"

estimate:
  tokens: 65000
  raw_tokens: 65000
  tasks: 3
  confidence: low

must_haves:
  truths:
    - "A signed-in user can open Feedback from the Settings sheet, pick Complaint, Feature request or Other, write a message and send it"
    - "A sent message is stored as one public.app_feedback row owned by that user, with status open"
    - "A blank, too-short or too-long message, or a missing category, is rejected with an inline error and nothing is sent"
    - "A signed-out user sees a sign-in notice instead of the form, and a session that ends mid-form gets a sign-in message, not a connection error"
    - "When the insert fails or times out the user sees a clear error, stays on the screen and keeps what they typed so they can retry"
    - "A user can never read another user's feedback, file feedback as someone else, or change a row after sending it"
    - "A maintainer can list open feedback and mark it handled using documented SQL"
  artifacts:
    - path: "/home/kaasor/Documents/Backup/Hikma/Enchiridion/enchiridion-web/supabase/enchiridion_master.sql"
      provides: "public.app_feedback table, open-status index, RLS and owner-only policies"
      contains: "create table if not exists public.app_feedback"
    - path: "enchiridion/lib/services/feedback_service.dart"
      provides: "FeedbackCategory, FeedbackSignInRequiredException, FeedbackService (validation limits, validateMessage, isSignedIn, submit)"
      exports: ["FeedbackCategory", "FeedbackSignInRequiredException", "FeedbackService"]
    - path: "enchiridion/lib/screens/feedback_screen.dart"
      provides: "FeedbackScreen form with category choice, message validation, send state and signed-out notice"
      exports: ["FeedbackScreen"]
    - path: "enchiridion/test/services/feedback_service_test.dart"
      provides: "Validation, row payload, sign-in, failure and timeout coverage"
    - path: "enchiridion/test/screens/feedback_screen_test.dart"
      provides: "Happy path plus validation, signed-out, failure and double-send coverage"
  key_links:
    - from: "enchiridion/lib/screens/library_screen.dart"
      to: "enchiridion/lib/screens/feedback_screen.dart"
      via: "Send feedback ListTile in the _showSettings sheet, directly above About Enchiridion"
      pattern: "FeedbackScreen\\(\\)"
    - from: "enchiridion/lib/screens/feedback_screen.dart"
      to: "enchiridion/lib/services/feedback_service.dart"
      via: "FeedbackService.submit and FeedbackService.validateMessage"
      pattern: "validateMessage|\\.submit\\("
    - from: "enchiridion/lib/services/feedback_service.dart"
      to: "/home/kaasor/Documents/Backup/Hikma/Enchiridion/enchiridion-web/supabase/enchiridion_master.sql"
      via: "Supabase insert into public.app_feedback with keys user_id, category, message, platform, which must match the SQL column names"
      pattern: "app_feedback"
---

<objective>
Give signed-in users an in-app way to send complaints and feature requests, stored in a new owner-only Supabase table that maintainers can read.

Purpose: users have no channel for complaints or requests today; a grep for "feedback" hits only unrelated exam-prep code.
Output: `public.app_feedback` in the master SQL, `FeedbackService`, `FeedbackScreen`, a Settings entry, tests, and a documented maintainer query. Applying the SQL to the live database is a manual user step (Task 3).

**Entry point decision (Claude's discretion, delegated by the orchestrator):** the request says "tab", but this plan adds a pushed screen opened from the Settings sheet rather than a third tab on the home `TabBar`. Observed structure: there is no bottom navigation bar; `LibraryScreen` has one `TabBar` of content categories (Library, Resources) over a swipeable `TabBarView`. A form there would put a text field and keyboard inside a horizontal swipe pager and mix an account action into content browsing. The Settings sheet already hosts app-level destinations (About Enchiridion, Diagnostics log), and the header row already carries three icon buttons beside the title. The executor must state this choice in the SUMMARY so the user can ask for a tab instead.
</objective>

<execution_context>
@~/.claude/gsd-core/workflows/execute-plan.md
@~/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@CLAUDE.md
@enchiridion/lib/services/question_flag_service.dart
@enchiridion/lib/services/biometric_sign_in_service.dart
@enchiridion/lib/screens/about_screen.dart
@enchiridion/lib/screens/library_screen.dart
@enchiridion/test/screens/library_screen_test.dart

Project rules that bind every Dart change here:
- All Flutter commands run from `enchiridion/`, never the repo root.
- CLAUDE.md default is zero comments. New Dart files and new test code contain no comments of any kind. Note that the closest analogs carry doc blocks and section comments: do not copy those.
- Commit only this task's files. `.gsd/dispatch-isolation-sentinel.json` in the app repo and the untracked images under `frontend/public/images/` in enchiridion-web are unrelated: never stage them, and never use `git add -A` or `git add .` in either repo. Do not push either repo.

Baseline observed at planning time: `flutter analyze` reports "No issues found!". Keep it that way.

No new packages. `package_info_plus` is not a dependency and adding one is out of scope, so there is deliberately no `app_version` column: a column nothing writes would be dead schema.

<interfaces>
Contract shared by the tasks. `enchiridion/lib/services/feedback_service.dart` must expose exactly this shape:

- `enum FeedbackCategory` with enhanced values `complaint('complaint', 'Complaint')`, `featureRequest('feature_request', 'Feature request')`, `other('other', 'Other')`; fields `final String storageValue` and `final String label`.
- `class FeedbackSignInRequiredException implements Exception` with a const constructor.
- `class FeedbackService` with:
  - Constructor taking optional named function seams, following the `BiometricSignInService` pattern: `Future<void> Function(Map<String, dynamic> row)? insertRow`, `String? Function()? currentUserId`, `String Function()? platform`, plus `Duration submitTimeout = const Duration(seconds: 15)`.
  - `static const int minMessageLength = 10` and `static const int maxMessageLength = 2000`.
  - `static String? validateMessage(String? raw)`, usable directly as a `TextFormField` validator.
  - `bool get isSignedIn`.
  - `Future<void> submit({required FeedbackCategory category, required String message})`.

Row sent to Supabase has exactly the keys `user_id`, `category`, `message`, `platform`. `status`, `id` and `created_at` are left to database defaults.

Exact user-facing copy (tests assert these strings):
| Where | Text |
|-------|------|
| Settings tile title / subtitle | `Send feedback` / `Report a problem or request something new` |
| AppBar title | `Feedback` |
| Category heading | `What is this about?` |
| Missing category error | `Choose what this feedback is about.` |
| Message field label | `Your message` |
| Blank message | `Please write your feedback.` |
| Too short | `Please add a little more detail (at least 10 characters).` |
| Too long | `Please keep it to 2000 characters or fewer.` |
| Send button | `Send` |
| Success snackbar | `Thanks — your feedback has been sent.` |
| Failure snackbar | `Couldn't send your feedback. Check your connection and try again — your message is still here.` |
| Signed-out notice and sign-in snackbar | `Sign in to send feedback.` |
</interfaces>
</context>

<tasks>

<task type="tracer">
  <name>Task 1: End-to-end signed-in submission from Settings to public.app_feedback</name>
  <files>/home/kaasor/Documents/Backup/Hikma/Enchiridion/enchiridion-web/supabase/enchiridion_master.sql, enchiridion/lib/services/feedback_service.dart, enchiridion/lib/screens/feedback_screen.dart, enchiridion/lib/screens/library_screen.dart, enchiridion/test/screens/feedback_screen_test.dart</files>
  <action>
**SQL (enchiridion-web/supabase/enchiridion_master.sql).** Insert a new block immediately after the two `create policy` statements that end the `public.flagged_questions` section and before `create table if not exists public.pinned_notes`, so it stays inside the main `begin;`/`commit;` transaction. Mirror the flagged_questions layout and keep the file idempotent. Table `public.app_feedback`, created with `create table if not exists`:
- `id uuid primary key default gen_random_uuid()`
- `user_id uuid not null references auth.users(id) on delete cascade`
- `category text not null` with a check allowing only `complaint`, `feature_request`, `other`
- `message text not null` with a check that `char_length(btrim(message))` is between 10 and 2000
- `platform text` (nullable) with a check that it is null or at most 32 characters
- `status text not null default 'open'` with a check allowing only `open`, `reviewed`, `resolved`, `dismissed`
- `created_at timestamptz not null default timezone('utc', now())`

Then: a partial index `idx_app_feedback_open` on `(status, created_at)` where `status = 'open'`, created with `if not exists`; `alter table ... enable row level security`; `drop policy if exists` then `create policy` for "Users can read their own feedback" (select, using `auth.uid() = user_id`) and "Users can insert their own feedback" (insert, with check `auth.uid() = user_id and status = 'open'`). Add no update or delete policy: rows are immutable to users, and only maintainers change status. One single-line SQL comment explaining why the insert policy pins `status` is permitted, matching the file's existing one-line comment style. Do not run this SQL anywhere.

**Service (enchiridion/lib/services/feedback_service.dart).** Implement the `<interfaces>` contract in full. The default `insertRow` awaits `Supabase.instance.client.from('app_feedback').insert(row)`, the default `currentUserId` reads `AuthService.currentUser?.id`, and the default `platform` returns `web` when `kIsWeb` and otherwise `defaultTargetPlatform.name` (web-safe: do not use `dart:io` `Platform`). `validateMessage` trims the input and returns the blank, too-short or too-long copy, or null when valid; build the too-short and too-long copy by interpolating the two limit constants so the numbers cannot drift from the rule. Count length with `runes.length`, because Postgres `char_length` counts code points while Dart `String.length` counts UTF-16 units; otherwise a message the client accepts could fail the database check. `submit` first throws `FeedbackSignInRequiredException` when there is no user id, then throws `ArgumentError.value` when `validateMessage` returns an error, then awaits the insert under `.timeout(submitTimeout)` with the trimmed message and `category.storageValue`, letting any failure propagate to the caller (same no-local-fallback stance as `QuestionFlagService`). Take `user_id` only from the session, never from a parameter.

**Screen (enchiridion/lib/screens/feedback_screen.dart).** `class FeedbackScreen extends StatefulWidget` with `const FeedbackScreen({super.key, this.service})` and `final FeedbackService? service`; the state uses `widget.service ?? FeedbackService()`. Scaffold with the `Feedback` AppBar title, then a `Form` containing a `ListView` padded like `AboutScreen` using `bottomViewportInset(context)` from `../utils/bottom_inset.dart`. Contents in order: one short intro line, the category heading, a `Wrap` of `ChoiceChip`s for `FeedbackCategory.values` with no preselection (a default would silently miscategorize messages), the missing-category error in `colorScheme.error` only after a failed send attempt, a multiline `TextFormField` (labelled `Your message`, `minLines` 5, `maxLines` 10, `maxLength: FeedbackService.maxMessageLength`, sentence capitalization, `OutlineInputBorder`, `validator: FeedbackService.validateMessage`), and a `FilledButton.icon` labelled `Send`. Dispose the controller.

Send behaviour: return early if already sending; run form validation and the category check together so both errors can show at once; on success show the success snackbar via a `ScaffoldMessenger` captured before the await, then `Navigator.maybePop`. While sending, `onPressed` is null and the icon is a small `CircularProgressIndicator`, so a double tap cannot insert twice. On any caught failure show the failure snackbar, stay on the screen and leave the message and category untouched. Never put the caught exception's text in user-facing copy: PostgREST errors can expose schema details. Guard every post-await `setState` with `mounted`. Do not add the signed-out view or the distinct sign-in snackbar here; Task 2 adds them.

**Entry (enchiridion/lib/screens/library_screen.dart).** Import `feedback_screen.dart` alongside the sibling imports. In `_showSettings`, add a `ListTile` between the `Divider` and the existing `About Enchiridion` tile: leading `Icons.feedback_outlined`, the Settings tile copy, `contentPadding: EdgeInsets.zero`, and an `onTap` identical in shape to About's (`Navigator.pop(context)`, then push `MaterialPageRoute` to `const FeedbackScreen()`). Leave the home `TabBar` unchanged.

**Tracer test (enchiridion/test/screens/feedback_screen_test.dart).** Pump a `MaterialApp` whose home is a `Scaffold` host (the snackbar needs a Scaffold to land on after the pop) with a button that pushes a `FeedbackScreen` given a `FeedbackService` built with an `insertRow` closure that captures rows and `currentUserId: () => 'user-1'`. Open it, tap the `Feature request` chip, enter a message with surrounding spaces, tap `Send`, and `pumpAndSettle`. Assert exactly one captured row equal to `user_id` `user-1`, `category` `feature_request`, the trimmed message, and `platform` `android` (flutter_test's default platform); assert `FeedbackScreen` is gone and the success snackbar text is visible.

**Commits.** App repo: stage the four app files by explicit path and commit. Web repo (`git -C /home/kaasor/Documents/Backup/Hikma/Enchiridion/enchiridion-web`): stage only `supabase/enchiridion_master.sql` and commit on the current branch. Push neither.
  </action>
  <verify>
    <automated>cd /home/kaasor/Documents/Backup/Hikma/Enchiridion/enchiridion-app/enchiridion && flutter test test/screens/feedback_screen_test.dart && flutter analyze && grep -q "FeedbackScreen()" lib/screens/library_screen.dart && ! grep -nE '^[[:space:]]*(//|/\*)' lib/services/feedback_service.dart lib/screens/feedback_screen.dart test/screens/feedback_screen_test.dart && SQL=/home/kaasor/Documents/Backup/Hikma/Enchiridion/enchiridion-web/supabase/enchiridion_master.sql && grep -q 'create table if not exists public.app_feedback' "$SQL" && grep -q 'on public.app_feedback for select' "$SQL" && grep -q 'on public.app_feedback for insert' "$SQL" && ! grep -qE 'on public.app_feedback for (update|delete|all)' "$SQL" && grep -q "auth.uid() = user_id and status = 'open'" "$SQL" && awk '/^begin;/{b++} /^commit;/{c++} END{exit !(b==c)}' "$SQL" && test "$(awk '/^commit;/{exit} /public.app_feedback/{n++} END{print n+0}' "$SQL")" -gt 0</automated>
  </verify>
  <done>From the Settings sheet a signed-in user reaches the form and a valid submission produces one correctly shaped row through the real service with only the network call faked, then the screen closes with a thank-you. The SQL block sits inside the main transaction with RLS and exactly two owner-only policies. `flutter analyze` reports no issues and the new Dart files contain no comments.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Signed-out users are told to sign in, every rejection path is covered, and maintainers can read feedback</name>
  <files>enchiridion/lib/screens/feedback_screen.dart, enchiridion/test/services/feedback_service_test.dart, enchiridion/test/screens/feedback_screen_test.dart, enchiridion/test/screens/library_screen_test.dart, /home/kaasor/Documents/Backup/Hikma/Enchiridion/enchiridion-web/docs/database.md</files>
  <behavior>
    Screen, written failing first:
    - Signed out at open (`currentUserId: () => null`): `Sign in to send feedback.` is shown, with no `TextFormField` and no `Send` button.
    - Session ends between opening and sending (a mutable user id set to null before tapping `Send`): the `Sign in to send feedback.` snackbar appears, the failure snackbar does not, the screen stays open, nothing is inserted.

    Screen, covering Task 1 behaviour:
    - `Send` on an untouched form shows both `Choose what this feedback is about.` and `Please write your feedback.`; nothing is inserted.
    - A category plus a 9-character message shows the too-short copy; nothing is inserted.
    - `insertRow` throws: the failure snackbar shows, `FeedbackScreen` stays, the field still holds the typed text, and `Send` is enabled again.
    - `insertRow` waits on a `Completer`: tapping `Send` twice inserts once and a `CircularProgressIndicator` is visible; completing it closes the screen. Use `tester.pump()` while the `Completer` is outstanding, because `pumpAndSettle` never settles with a spinner running.

    Service:
    - `validateMessage`: null, empty and whitespace-with-newlines give the blank copy; 9 characters gives too-short; exactly 10 and exactly 2000 give null; 2001 gives too-long; 5 emoji (10 UTF-16 units, 5 runes) gives too-short and 10 emoji gives null.
    - `submit` with no user throws `FeedbackSignInRequiredException` and never calls `insertRow`.
    - `submit` with an invalid message throws `ArgumentError` and never calls `insertRow`.
    - `submit` maps each `FeedbackCategory` to its `storageValue` and sends the trimmed message.
    - An `insertRow` failure propagates; a never-completing `insertRow` with `submitTimeout: Duration(milliseconds: 10)` throws `TimeoutException`.

    Settings entry:
    - From `LibraryScreen`, tapping the `Settings` tooltip, bringing `Send feedback` into view with `tester.ensureVisible`, and tapping it shows exactly one `FeedbackScreen`. The file's existing `setUpAll` stub Supabase session is signed out, so this lands on the signed-out notice without any network call.
  </behavior>
  <action>
**Screen tests first.** Extend `enchiridion/test/screens/feedback_screen_test.dart` with every Screen case above and run it to confirm the two signed-out cases fail before implementing. Reuse the host-route helper from Task 1.

**Screen (enchiridion/lib/screens/feedback_screen.dart).** Read `isSignedIn` once in `initState` and store it in a final field. Do not re-read it in `build`: the send handler's `setState` rebuilds the screen, so a session that expires mid-form would otherwise swap the form for the notice and discard what the user typed. When the stored value is false, the Scaffold body shows the sign-in notice (with one short line saying feedback is tied to the account, so the user must be signed in) and no form. In the send handler, add a dedicated catch for `FeedbackSignInRequiredException` ahead of the catch-all that shows the sign-in snackbar and keeps the form contents. The service guard stays authoritative: the stored value only decides whether the notice is shown at open.

**Service tests (enchiridion/test/services/feedback_service_test.dart).** New file covering every Service case above, using the constructor seams and no Supabase initialization; follow the plain `flutter_test` shape of `test/services/study_stats_service_test.dart`. These pin the contract from Task 1 and are expected to pass on first run. If one fails, that is a Task 1 defect: fix it in `enchiridion/lib/services/feedback_service.dart` rather than weakening the test, stage that file in this task's commit, and record the defect in the SUMMARY.

**Entry test (enchiridion/test/screens/library_screen_test.dart).** Add the Settings entry case using the file's existing `_buildSubject(_makeStorage())` harness, plus an import of `feedback_screen.dart`. Add no comments, even though the surrounding test code has them, and do not remove or rewrite those existing comments.

**Maintainer docs (enchiridion-web/docs/database.md).** There is no admin surface, so without this nobody can read the feedback. In the operating SQL block that holds the "Open question flags" query, add directly after the flagged_questions statements: a one-line SQL comment "Open app feedback (complaints and feature requests), newest first.", a select of `f.id, f.category, f.message, f.platform, f.created_at, u.email` from `public.app_feedback f` joined to `auth.users u` where status is open ordered by `created_at` desc, and an update example setting `status` to `resolved` for one row by id, written in the same form as the flagged_questions update line beside it. In the "What lives where" table, add "feedback" to the `public` row's parenthetical list of app data.

`enchiridion-web/supabase/wipe_application_data.sql` stays unchanged: `delete from auth.users` already removes feedback through the foreign key cascade.

**Commits.** App repo: stage the Dart files by explicit path and commit. Web repo: stage only `docs/database.md` and commit on the current branch. Push neither.
  </action>
  <verify>
    <automated>cd /home/kaasor/Documents/Backup/Hikma/Enchiridion/enchiridion-app/enchiridion && flutter test test/services/feedback_service_test.dart test/screens/feedback_screen_test.dart test/screens/library_screen_test.dart && flutter analyze && ! grep -nE '^[[:space:]]*(//|/\*)' lib/services/feedback_service.dart lib/screens/feedback_screen.dart test/services/feedback_service_test.dart test/screens/feedback_screen_test.dart && ! grep -nE '\$e\b|\$\{e' lib/screens/feedback_screen.dart && grep -q "from public.app_feedback f" /home/kaasor/Documents/Backup/Hikma/Enchiridion/enchiridion-web/docs/database.md</automated>
  </verify>
  <done>Signed-out and expired-session users get a sign-in message rather than a generic error. All validation, failure, timeout and double-send behaviour is pinned by tests. The Settings entry has a navigation test. `docs/database.md` documents how to list and resolve feedback. All three test files pass and `flutter analyze` reports no issues.</done>
</task>

<task type="checkpoint:human-action" gate="blocking">
  <name>Task 3: Apply the schema to the live Supabase project and smoke test one submission</name>
  <action>Apply the updated master SQL to the live Supabase project, then confirm one real submission arrives. The agent must not do this: project policy keeps live schema changes manual, and no agent connects to the deployed database.</action>
  <instructions>
    Claude has already written and committed the SQL, service, screen, tests and docs, and has pushed nothing.

    1. Supabase Dashboard -> SQL Editor -> New query. Paste the whole of `enchiridion-web/supabase/enchiridion_master.sql` and click Run. The file is idempotent, as `docs/database.md` describes.
    2. Run the app from `enchiridion/` with `flutter run`, signed in with a test account.
    3. Home -> Settings icon -> Send feedback. Tap Send on the empty form and confirm the inline errors appear. Choose Feature request, write a real sentence, tap Send, and confirm the thank-you message.
    4. In the SQL Editor, run the "Open app feedback" query from `docs/database.md`. Your row should be listed with the right category, message, platform and email.
    5. Optional: turn on airplane mode, send again, and confirm the connection error appears with your text still in the field.

    Until step 1 is done, every submission shows the failure snackbar, because the table does not exist yet. Apply the SQL before shipping an app build containing this screen.
  </instructions>
  <verification>The user confirms the row appeared in the query result. Claude has no database access, so this cannot be checked independently; record the user's reported result in the SUMMARY, or record the step as pending if they defer it.</verification>
  <resume-signal>Type "applied" with the result of the query, or "deferred" to finish the task with the schema step recorded as pending in the SUMMARY and STATE.md.</resume-signal>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| App client -> Supabase PostgREST | Everything in the insert (`user_id`, `category`, `message`, `platform`) is attacker-controllable with the public anon key, so the client's checks are UX only; RLS and check constraints are the enforcement |
| Stored feedback -> maintainer tooling | Free text written by users is later read by maintainers |

## STRIDE Threat Register

ASVS level 1, blocking threshold `high`: both high threats are mitigated below.

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|-----------|----------|-----------|----------|-------------|-----------------|
| T-261103-01 | Spoofing | `public.app_feedback` insert | high | mitigate | Insert policy requires `auth.uid() = user_id`, so a forged `user_id` is rejected server-side; anon has no `auth.uid()` so it cannot insert. The service takes `user_id` only from the session. Verified by grep on the policy text in Task 1 and by the sign-in tests in Task 2 |
| T-261103-02 | Information Disclosure | `public.app_feedback` select | high | mitigate | RLS enabled with a select policy of `auth.uid() = user_id`, so users see only their own rows. Foreign key `on delete cascade` removes feedback, which may contain personal details, with the account |
| T-261103-03 | Tampering | `status` and post-submit edits | medium | mitigate | Insert policy pins `status = 'open'`, and no update or delete policy exists, so users cannot self-resolve or rewrite a row after sending |
| T-261103-04 | Tampering | `category`, `message`, `platform` values | medium | mitigate | Database check constraints enforce the category list, the 10 to 2000 message length and the 32-character platform cap for any client, independent of the Dart validation |
| T-261103-05 | Information Disclosure | Error display in `FeedbackScreen` | medium | mitigate | Fixed user-facing copy only; the caught exception is never interpolated, unlike `ProfileScreen`'s existing pattern. Enforced by a negative grep in Task 2 |
| T-261103-06 | Denial of Service | Flooding `public.app_feedback` | low | accept | Requires an authenticated, device-gated account and is capped per row at 2000 characters; the send button is disabled in flight to stop accidental duplicates. Abuse is visible and removable through the maintainer query, and a server-side rate limit is not warranted at ASVS level 1 for this surface |
| T-261103-07 | Tampering | Stored message rendered by future tooling | low | accept | No in-app or web admin surface reads this table today; maintainers read it as plain text in the SQL Editor. Any future admin UI must treat `message` as untrusted and escape it |
| T-261103-SC | Tampering | Package installs | low | accept | Not applicable: this plan installs no npm, pip, cargo or pub packages, so the package legitimacy gate does not apply |
</threat_model>

<verification>
Run from `enchiridion/` after Task 2:

1. `flutter analyze` reports "No issues found!".
2. `flutter test` passes in full, confirming no regression in the existing `library_screen_test.dart` cases.
3. `git -C /home/kaasor/Documents/Backup/Hikma/Enchiridion/enchiridion-web status --short` still lists the unrelated untracked images and no staged or modified SQL or docs. Neither repo has been pushed.
4. Column-to-key match: every key the service sends (`user_id`, `category`, `message`, `platform`) is a column in the `public.app_feedback` block of the master SQL, and the category `storageValue`s match the check constraint list exactly.
5. Manual: Task 3 smoke test, reported by the user or recorded as pending.

Not verifiable by the agent: the SQL has not been executed. The local Postgres at `/var/run/postgresql` has no role for this OS user, so the `backend/tests/supabase_stub.sql` scratch-database route documented in `docs/database.md` is unavailable unless `TEST_DATABASE_URL` is supplied. Task 1's structural greps and the user's run in Task 3 are the checks. Say so plainly in the SUMMARY rather than implying the SQL was run.
</verification>

<success_criteria>
- A signed-in user can send a complaint or feature request from Settings -> Send feedback.
- Invalid input, signed-out state, and offline or insert failures each produce clear feedback, with typed text kept on failure.
- `public.app_feedback` is defined idempotently in the master SQL with owner-only RLS, immutable rows and check constraints, and is documented for maintainers.
- New service and screen tests pass, the full suite passes, `flutter analyze` is clean, and new Dart code has no comments.
- The manual schema step is either confirmed by the user or recorded as pending in the SUMMARY and STATE.md.
</success_criteria>

<source_audit>
SOURCE   | ID | Feature/Requirement | Plan | Status | Notes
-------- | -- | ------------------- | ---- | ------ | -----
GOAL     | —  | Users can send complaints or additions they want in the app | 01 (Tasks 1, 3) | COVERED | Delivered as a Settings-sheet destination; the rationale for not adding a home tab is in the objective
REQ      | —  | None assigned: quick task | — | N/A | `QUICK-261103-coc` is a synthetic ID so the frontmatter field is populated
RESEARCH | —  | None: no research phase for quick tasks | — | N/A |
CONTEXT  | —  | None: no CONTEXT.md for this task | — | N/A |
ORCH     | C1 | Non-empty and length-capped input | 01 (Tasks 1, 2) | COVERED | Client validation plus database checks
ORCH     | C2 | Signed-in user required | 01 (Tasks 1, 2) | COVERED | Service guard, signed-out notice, RLS
ORCH     | C3 | Success and error feedback | 01 (Tasks 1, 2) | COVERED |
ORCH     | C4 | Offline and insert failure handled gracefully | 01 (Tasks 1, 2) | COVERED | Timeout, failure snackbar, text kept for retry
ORCH     | C5 | Widget and unit tests | 01 (Tasks 1, 2) | COVERED |
ORCH     | C6 | Schema in the sibling repo, stage only that repo's own files, no push, no live apply | 01 (Tasks 1, 2, 3) | COVERED | Live apply is Task 3, a human step
ORCH     | C7 | `app_version` column was optional | — | NOT TAKEN | The app cannot read its version without a new dependency, and a column nothing writes would be dead schema; `platform` is included
</source_audit>

<output>
Create `.planning/quick/261103-coc-create-a-feedback-tab-for-users-to-send-/261103-coc-SUMMARY.md` when done. It must state the entry point choice and why it is not a home tab, the commit hashes in both repos, that the SQL was not executed by the agent, and whether the Task 3 schema step was applied or is pending.
</output>
