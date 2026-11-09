---
quick_id: 260917-ndz
phase: quick-260917-ndz
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - enchiridion/android/app/src/main/kotlin/com/example/enchiridion/BubbleAlarmWorker.kt
  - enchiridion/android/app/src/main/kotlin/com/example/enchiridion/BubbleActivity.kt
  - enchiridion/android/app/src/main/kotlin/com/example/enchiridion/BubblePlugin.kt
  - enchiridion/lib/main.dart
  - enchiridion/lib/services/bubble_scheduler.dart
  - enchiridion/lib/services/bubble_alarm_callback.dart
  - enchiridion/test/android/bubble_entrypoint_wiring_test.dart
  - enchiridion/test/services/bubble_scheduler_test.dart
  - enchiridion/test/services/bubble_alarm_callback_test.dart
autonomous: true
requirements: [QB-260917-NDZ]

estimate:
  tokens: 55000
  raw_tokens: 55000
  tasks: 3
  confidence: low
must_haves:
  truths:
    - A scheduled bubble run actually executes the `bubbleAlarmCallback` Dart function, so an installed, signed-in device receives a "Quick Check" notification without the app being opened.
    - Tapping a "Quick Check" notification opens the one-question answer window on the `bubbleMain` entrypoint rather than an engine with no Dart running.
    - Launching the app rebuilds the ambient work chain whenever no run is pending, so a chain lost to force-stop, battery-killer, or storage reset recovers on the next launch instead of staying dead for the life of the install.
    - A run that posts nothing records a distinguishable reason (no signed-in user, no servable question, error) that is readable from `adb logcat`.
    - Free-tier users are still limited to the first `kFreeQuestionCount` questions — the selection path through `NextQuestionSelector` is unchanged by this plan.
  artifacts:
    - enchiridion/android/app/src/main/kotlin/com/example/enchiridion/BubbleAlarmWorker.kt
    - enchiridion/android/app/src/main/kotlin/com/example/enchiridion/BubbleActivity.kt
    - enchiridion/lib/services/bubble_scheduler.dart
    - enchiridion/test/android/bubble_entrypoint_wiring_test.dart
  key_links:
    - BubbleAlarmWorker's `DartExecutor.DartEntrypoint` library argument must name the library that declares `bubbleAlarmCallback` (`package:enchiridion/services/bubble_alarm_callback.dart`); with a null library the engine only searches the root library `package:enchiridion/main.dart`.
    - BubbleActivity's `getDartEntrypointLibraryUri()` must name `package:enchiridion/bubble_main.dart`, the library that declares `bubbleMain`.
    - The arming chain `main()` → `BubbleScheduler.armOnStartup()` → BubblePlugin `armBubbleSchedule` → `BubbleAlarmWorker` unique work `bubble_quick_check` is the only thing that starts ambient prompts; every link must survive a cold launch.
---

<objective>
Find and fix why no ambient "Quick Check" bubble notification has ever been delivered on device, so scheduled question prompts actually reach a user who is not in the app.

Purpose: The ambient prompt is the only surface that serves questions outside "Practice Now". It has never been confirmed working on a device (see `.planning/STATE.md`, "verify Android bubble notifications on a device"), and the user observed 3+ hours with nothing delivered.
Output: A delivered-or-explained bubble path — a headless run that really executes Dart, a work chain that heals itself on app launch, and a logged reason whenever a run posts nothing.
</objective>

<context>
@.planning/STATE.md
@enchiridion/lib/services/bubble_alarm_callback.dart
@enchiridion/lib/services/notification_service.dart
@enchiridion/android/app/src/main/kotlin/com/example/enchiridion/BubbleAlarmWorker.kt
@enchiridion/android/app/src/main/kotlin/com/example/enchiridion/BubblePlugin.kt
@enchiridion/lib/main.dart
</context>

<investigation_findings>
Read before starting — this is the diagnosis the tasks below act on.

**Root cause (confirmed by reading the Flutter embedding in `/home/kaasor/development/flutter`).**
`BubbleAlarmWorker.doWork()` starts the headless engine with the two-argument
`DartExecutor.DartEntrypoint(appBundlePath, "bubbleAlarmCallback")`. In
`engine/src/flutter/shell/platform/android/io/flutter/embedding/engine/dart/DartExecutor.java`
(lines 355-360) that constructor sets `dartEntrypointLibrary = null`, and
`executeDartEntrypoint` (lines 146-165) forwards that null to
`flutterJNI.runBundleAndSnapshotFromLibrary(...)`. A null library means the engine resolves the
entrypoint **by name in the root library only** — `package:enchiridion/main.dart`.
`bubbleAlarmCallback` is declared in `lib/services/bubble_alarm_callback.dart`, so the lookup
fails, no isolate starts, and no Dart ever runs. Nothing throws on the Java side, so the
worker's `catch (_: Exception)` never fires; the latch simply times out after 60s and
`enqueueNext` re-arms. The chain therefore looks perfectly healthy in WorkManager while
delivering nothing, forever — exactly the reported "3 hours, no notification".

`BubbleActivity` has the same defect for its own entrypoint: it overrides
`getDartEntrypointFunctionName()` to `"bubbleMain"` but not `getDartEntrypointLibraryUri()`
(available on `FlutterActivity`, line 1154 of `FlutterActivity.java`), and `bubbleMain` lives in
`lib/bubble_main.dart`, not `lib/main.dart`. That defect is currently invisible only because no
notification has ever been posted to tap.

**Ruled out during investigation — do not spend time re-checking:**
- `androidx.work:work-runtime-ktx:2.9.1` and `androidx.core:core-ktx:1.13.1` are declared in
  `android/app/build.gradle.kts`; WorkManager auto-initialisation is present.
- `POST_NOTIFICATIONS` is declared in `AndroidManifest.xml` and requested at startup by
  `NotificationService.initialize()`.
- `FlutterLoader` initialisation is **not** missing: `FlutterEngine`'s constructor
  (`FlutterEngine.java` lines 383-389) calls `startInitialization` / `ensureInitializationComplete`
  itself, and the worker calls `findAppBundlePath()` only after constructing the engine.
- `GeneratedPluginRegistrant.registerWith(engine)` plus an explicit `BubblePlugin()` are both
  added to the headless engine, so `shared_preferences` / `supabase_flutter` / `rootBundle`
  would work once Dart actually runs.
- Free-tier gating is correct: `NextQuestionSelector.next(hasAccess: false)` keeps
  `questionNumber <= kFreeQuestionCount` (10). Do not change selection behaviour here.

**Secondary defects that would keep this fragile even after the entrypoint fix** (tasks 2 and 3):
- `lib/main.dart` arms the chain at most once per install, gated on the
  `bubble_alarm_armed` preference. Once that flag is stored, a chain lost to a force-stop,
  an OEM battery killer, or cleared WorkManager state is never rebuilt.
- `_run()` in `bubble_alarm_callback.dart` is `try { ... } finally { ... }` with no `catch` and
  no logging, and `AccessService.hasExamPrepAccess()` makes an unbounded network call inside
  it. Any throw or hang silently costs that run its notification with no trace anywhere.
</investigation_findings>

<tasks>

<task type="tracer">
  <name>Task 1: Name the entrypoint libraries so a scheduled run actually executes Dart</name>
  <files>enchiridion/android/app/src/main/kotlin/com/example/enchiridion/BubbleAlarmWorker.kt, enchiridion/android/app/src/main/kotlin/com/example/enchiridion/BubbleActivity.kt, enchiridion/test/android/bubble_entrypoint_wiring_test.dart</files>
  <read_first>Read `doWork()` in BubbleAlarmWorker.kt, the overrides in BubbleActivity.kt, the `@pragma('vm:entry-point')` declarations at the top of `enchiridion/lib/services/bubble_alarm_callback.dart` and `enchiridion/lib/bubble_main.dart`, and the `name:` field of `enchiridion/pubspec.yaml` (it is `enchiridion`, which fixes the `package:` prefix).</read_first>
  <action>In BubbleAlarmWorker.doWork(), switch the engine start to the three-argument DartExecutor.DartEntrypoint overload, passing the app bundle path, the library URI "package:enchiridion/services/bubble_alarm_callback.dart", and the function name "bubbleAlarmCallback" — in that parameter order (pathToBundle, dartEntrypointLibrary, dartEntrypointFunctionName). Keep the existing main-looper post, GeneratedPluginRegistrant registration, explicit BubblePlugin add, latch wait, engine destroy, and unconditional re-arm exactly as they are; this task changes only which Dart function the engine is told to find. In BubbleActivity.kt, add an override of getDartEntrypointLibraryUri() returning "package:enchiridion/bubble_main.dart" alongside the existing getDartEntrypointFunctionName() override. Do not move either entrypoint into main.dart and do not rename the functions — the library URI is the supported way to reach a secondary entrypoint, and both functions already carry the @pragma('vm:entry-point') annotation that keeps them alive through AOT tree-shaking. Then create enchiridion/test/android/bubble_entrypoint_wiring_test.dart as a plain Dart regression guard that reads all four source files from disk relative to Directory.current (the test runs with the Flutter package root as cwd). Before matching anything in a Kotlin or Dart source, strip its `//` line comments and `/* */` block comments, so a URI that survives only in an explanatory comment cannot satisfy the assertion. Assert, for each of the two Kotlin call sites, that the comment-stripped source contains a `package:enchiridion/...` library URI; then translate that URI back to a repo path by replacing the `package:enchiridion/` prefix with `lib/`, assert the file exists, and assert its comment-stripped contents declare the matching entrypoint function name with the vm:entry-point pragma. Drive both cases from one table so the test fails if either side drifts.</action>
  <verify>
    <automated>cd enchiridion && flutter test test/android/bubble_entrypoint_wiring_test.dart</automated>
    <automated>cd enchiridion/android && ./gradlew --quiet :app:compileDebugKotlin</automated>
  </verify>
  <done>The worker passes a library URI naming the file that declares `bubbleAlarmCallback`, BubbleActivity names the file that declares `bubbleMain`, the wiring test passes on comment-stripped sources, and the Kotlin sources compile. Gradle may take several minutes on a cold daemon; the wrapper distribution is already cached.</done>
</task>

<task type="auto">
  <name>Task 2: Re-arm the work chain on every launch instead of once per install</name>
  <files>enchiridion/lib/services/bubble_scheduler.dart, enchiridion/lib/main.dart, enchiridion/android/app/src/main/kotlin/com/example/enchiridion/BubbleAlarmWorker.kt, enchiridion/test/services/bubble_scheduler_test.dart</files>
  <read_first>Read the `_bubbleChannel` / `_bubbleAlarmArmedKey` block in `enchiridion/lib/main.dart` (lines 22-58), the `enqueueNext` companion function and the delay constants in BubbleAlarmWorker.kt, and the `armBubbleSchedule` branch of `onMethodCall` in BubblePlugin.kt.</read_first>
  <action>Create enchiridion/lib/services/bubble_scheduler.dart with a small BubbleScheduler class that owns the `enchiridion/bubbles` MethodChannel, accepts an injected channel through its constructor for testing, and exposes `Future<bool> armOnStartup()` which invokes `armBubbleSchedule`, returns true on success, and returns false — never rethrows — on PlatformException or MissingPluginException so a non-Android or plugin-less host cannot block startup. In main.dart, replace the inline channel call with `BubbleScheduler().armOnStartup()`, keep the existing `!kIsWeb && Platform.isAndroid` guard that commit f9e4cd1 added for Flutter web, and delete the one-shot preference gate together with its key constant and the now-unused shared_preferences read for it; arming must run on every Android launch. On the Kotlin side, split the companion API in two: keep the existing self re-arm used at the end of doWork() on ExistingWorkPolicy.REPLACE with the current 18-35 minute jittered delay, and add a separate app-start arm that uses ExistingWorkPolicy.KEEP so an already-pending run is left untouched while a chain that no longer exists is rebuilt. Give the app-start path its own short first-run delay constant of 3 minutes, so a fresh install or a healed chain produces an observable prompt promptly instead of leaving the user waiting at least 18 minutes to learn whether it works. Route BubblePlugin's `armBubbleSchedule` branch to the new app-start arm. Then create enchiridion/test/services/bubble_scheduler_test.dart using TestDefaultBinaryMessengerBinding's defaultBinaryMessenger.setMockMethodCallHandler on a MethodChannel named `enchiridion/bubbles`, covering: two successive armOnStartup() calls each reach the platform (recording two invocations of `armBubbleSchedule`, proving no once-per-install gate remains); a handler that throws PlatformException yields false without throwing; and with the mock handler cleared the MissingPluginException path also yields false. Extend test/android/bubble_entrypoint_wiring_test.dart with two comment-stripped source assertions: BubbleAlarmWorker.kt references both `ExistingWorkPolicy.KEEP` and `ExistingWorkPolicy.REPLACE`, and lib/main.dart no longer references the retired preference key.</action>
  <verify>
    <automated>cd enchiridion && flutter test test/services/bubble_scheduler_test.dart test/android/bubble_entrypoint_wiring_test.dart</automated>
    <automated>cd enchiridion && flutter analyze lib/main.dart lib/services/bubble_scheduler.dart</automated>
  </verify>
  <done>Arming runs on every Android launch through BubbleScheduler, the app-start enqueue keeps a healthy pending run while rebuilding a missing one, a fresh chain fires its first run within roughly 3 minutes, all three scheduler tests pass, and analyze reports no errors for the two Dart files.</done>
</task>

<task type="auto">
  <name>Task 3: Make a run that delivers nothing say why, and stop it hanging on the network</name>
  <files>enchiridion/lib/services/bubble_alarm_callback.dart, enchiridion/android/app/src/main/kotlin/com/example/enchiridion/BubblePlugin.kt, enchiridion/test/services/bubble_alarm_callback_test.dart</files>
  <read_first>Read `_run()` in `enchiridion/lib/services/bubble_alarm_callback.dart` in full, `hasExamPrepAccess()` and `loadAccess()` in `enchiridion/lib/services/access_service.dart`, and the `showBubble` private method in BubblePlugin.kt.</read_first>
  <action>In bubble_alarm_callback.dart, add a top-level, visibleForTesting helper that takes a `Future<bool> Function()` probe and a named timeout defaulting to 10 seconds, and resolves to false when the probe throws or exceeds the timeout. Call it around AccessService.instance.hasExamPrepAccess() so an offline or stalled entitlement lookup degrades to free-tier selection — which still serves the first ten questions — instead of consuming the worker's 60-second latch and dropping the prompt entirely. Give `_run()` a real catch clause between its body and the existing finally (it currently has none, so any throw escapes as an unhandled isolate error), and log every terminal outcome through dart:developer's log under a single fixed name so the whole run is greppable in logcat: Supabase initialisation reuse, no signed-in user, a question was selected and handed to showBubble, no servable question was returned, and the caught-error case. Log the outcome and the selected question id only; never log session tokens, refresh tokens, user ids, or email addresses. Keep the existing finally block signalling `workFinished` unconditionally — the worker's re-arm depends on it. In BubblePlugin.showBubble, before calling NotificationManagerCompat.notify, read areNotificationsEnabled() from the same NotificationManagerCompat instance and emit an android.util.Log warning when it is false, because on Android 13+ a denied POST_NOTIFICATIONS grant drops the post silently and is otherwise indistinguishable from the scheduler never running; still attempt the post afterwards either way. Then create enchiridion/test/services/bubble_alarm_callback_test.dart covering the helper alone — no Supabase or platform channel needed — with three cases: a probe resolving true returns true; a probe that throws returns false; and a probe that never completes returns false once a short injected timeout elapses, with the test asserting completion rather than hanging.</action>
  <verify>
    <automated>cd enchiridion && flutter test test/services/bubble_alarm_callback_test.dart</automated>
    <automated>cd enchiridion && flutter analyze lib/services/bubble_alarm_callback.dart</automated>
  </verify>
  <done>The access probe cannot hang or throw a run to death, every terminal outcome of a headless run is logged under one name with no credentials or identifiers in the message, a blocked notification permission is reported natively, and all three helper tests pass.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| headless worker → Supabase | The background isolate re-initialises Supabase and reads entitlements over the network with no user present. |
| app → Android notification shade | Question text leaves the app's process and is rendered by the system, including on a locked screen. |
| system → BubbleActivity | A tapped notification's PendingIntent starts an activity that shows and records an answer. |

## STRIDE Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|-----------|----------|-----------|----------|-------------|-----------------|
| T-ndz-01 | Information disclosure | `BubblePlugin.showBubble` notification body | low | accept | The teaser is study-bank question text the user opted into receiving; no account or clinical-record data is present, so lock-screen visibility is the intended behaviour of the feature. |
| T-ndz-02 | Tampering | Bubble `PendingIntent` (`FLAG_MUTABLE` is mandatory for BubbleMetadata) | medium | mitigate | Task 1 leaves the intent explicit — component set to `BubbleActivity`, which stays `android:exported="false"` in AndroidManifest.xml — so a third party cannot redirect the mutable intent. Do not relax either property. |
| T-ndz-03 | Information disclosure | New diagnostic logging in `bubble_alarm_callback.dart` and `BubblePlugin` | medium | mitigate | Task 3 restricts log payloads to outcome labels and the selected question id; session tokens, refresh tokens, user ids, and email addresses are excluded by instruction and must stay out. |
| T-ndz-04 | Denial of service | Unbounded `hasExamPrepAccess()` network call inside the 60-second worker latch | low | mitigate | Task 3 bounds the probe with a timeout and falls back to free-tier selection, so a stalled network costs one entitlement upgrade rather than the whole run plus wakelock time. |
| T-ndz-SC | Tampering | Dependency supply chain | n/a | accept | This plan adds no npm/pip/cargo/pub package. `androidx.work`, `androidx.core`, and `flutter_local_notifications` are already resolved in `android/app/build.gradle.kts` and `pubspec.lock`; no install task exists, so no package-legitimacy gate applies. |
</threat_model>

<verification>
Automated, from the repository root:

- `cd enchiridion && flutter test test/android/bubble_entrypoint_wiring_test.dart test/services/bubble_scheduler_test.dart test/services/bubble_alarm_callback_test.dart`
- `cd enchiridion && flutter test` — the pre-existing suite must stay green; this plan changes no selection, scoring, or UI behaviour.
- `cd enchiridion && flutter analyze lib/main.dart lib/services/bubble_scheduler.dart lib/services/bubble_alarm_callback.dart` — note the repository's analyzer baseline is non-empty for `lib` as a whole, so scope analysis to these files and require zero errors.
- `cd enchiridion/android && ./gradlew --quiet :app:compileDebugKotlin`

<human-check>
Delivery itself can only be proven on a device, and this feature has never been device-verified
(see `.planning/STATE.md`). After the fix is installed and the user is signed in:

1. `cd enchiridion && flutter run -d <device>`, then leave the app (home button, do not force-stop).
2. `adb logcat -c`, then `adb logcat | grep -iE "BubbleAlarm|Quick Check|enchiridion"`.
3. Within roughly 3 minutes of the first launch on a healed or fresh chain, expect either a
   "Quick Check" notification/bubble, or a logged outcome line stating why the run posted nothing.
4. If the log shows the notification-permission warning added in Task 3, grant notifications in
   Settings → Apps → enchiridion → Notifications and repeat from step 2.
5. Tap the delivered notification and confirm the one-question answer window renders content
   rather than a blank surface — that exercises the `bubbleMain` half of the Task 1 fix.
</human-check>
</verification>

<success_criteria>
A scheduled ambient run executes `bubbleAlarmCallback` in a real headless engine and posts a
"Quick Check" notification on device; tapping it opens a populated answer window; the work chain
is rebuilt on any launch where no run is pending; and any run that posts nothing leaves a
logged, credential-free reason behind.
</success_criteria>
