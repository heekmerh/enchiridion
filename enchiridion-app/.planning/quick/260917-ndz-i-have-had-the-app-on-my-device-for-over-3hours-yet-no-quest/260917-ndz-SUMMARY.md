---
phase: quick-260917-ndz
plan: 01
subsystem: android-notifications
tags: [flutter, dart, kotlin, workmanager, bubbles]
requires: []
provides:
  - Explicit Dart library URIs for both native bubble entrypoints
  - Startup repair of the unique WorkManager chain
  - Bounded access lookup and credential-free bubble outcome logs
affects: [android-bubbles, ambient-questions]
actuals:
  tokens: 2678
  tasks: 3
  commits: 0
plan_head_before: 7e4d5b6a0f65253702e0cb91d8ae19f0e869412b
commits: 0
tech-stack:
  added: []
  patterns: [secondary Dart entrypoint library URIs, WorkManager KEEP startup arm]
key-files:
  created:
    - enchiridion/lib/services/bubble_scheduler.dart
    - enchiridion/test/android/bubble_entrypoint_wiring_test.dart
    - enchiridion/test/services/bubble_scheduler_test.dart
    - enchiridion/test/services/bubble_alarm_callback_test.dart
  modified:
    - enchiridion/android/app/src/main/kotlin/com/example/enchiridion/BubbleAlarmWorker.kt
    - enchiridion/android/app/src/main/kotlin/com/example/enchiridion/BubbleActivity.kt
    - enchiridion/android/app/src/main/kotlin/com/example/enchiridion/BubblePlugin.kt
    - enchiridion/lib/main.dart
    - enchiridion/lib/services/bubble_alarm_callback.dart
key-decisions:
  - Keep the existing worker self-schedule delay and use KEEP with a three-minute first delay on app launch.
  - Import secondary Dart entrypoint libraries from main.dart so AOT compilation includes them.
requirements-completed: [QB-260917-NDZ]
coverage:
  - id: D1
    description: Scheduled and tapped bubble engines point to their declaring Dart libraries.
    verification:
      - kind: unit
        ref: test/android/bubble_entrypoint_wiring_test.dart
        status: pass
      - kind: other
        ref: cached Gradle 8.14 :app:compileDebugKotlin
        status: pass
    human_judgment: true
    rationale: Delivery and the tapped answer window still require an attached Android device.
  - id: D2
    description: Every Android launch requests a bubble schedule without replacing pending work.
    verification:
      - kind: unit
        ref: test/services/bubble_scheduler_test.dart
        status: pass
    human_judgment: true
    rationale: Actual WorkManager timing and recovery still require device observation.
  - id: D3
    description: Entitlement lookup is bounded and bubble runs log a credential-free outcome.
    verification:
      - kind: unit
        ref: test/services/bubble_alarm_callback_test.dart
        status: pass
    human_judgment: true
    rationale: Logcat output and notification permission behavior still require device observation.
duration: 10min
completed: 2026-09-17
status: complete
---

# Quick 260917-ndz: Ambient Quick Check delivery summary

**Native bubble engines now name their Dart libraries; Android startup repairs missing work, and headless runs log why a prompt was not posted.**

## Accomplishments

- The worker launches `bubbleAlarmCallback` from its declared library, and `BubbleActivity` launches `bubbleMain` from its own library. Root imports keep both libraries in the AOT program.
- Every Android launch asks WorkManager to arm unique work with `KEEP`; a new chain starts after about three minutes, while the worker retains its 18–35 minute `REPLACE` re-arm.
- Access checks time out after ten seconds and fall back to free-tier question selection. Headless outcomes share the `BubbleAlarm` log name, and Android warns when notifications are disabled. Question selection and the free-tier limit were not changed.

## Verification

- `flutter test --no-pub`: passed, 89 tests.
- Focused bubble tests: passed, 9 tests after the final source changes.
- `flutter analyze --no-pub lib/main.dart lib/services/bubble_scheduler.dart lib/services/bubble_alarm_callback.dart`: no issues.
- Kotlin compilation: passed with cached Gradle 8.14 and Java 17 using `:app:compileDebugKotlin --offline --quiet`. This checkout has no `android/gradlew`, so the plan's literal wrapper command could not run.
- `git diff --check`: passed.

## Deviations from Plan

**[Rule 2 - Missing critical functionality]** Added root imports for the secondary Dart libraries. Their native URIs alone do not make unimported libraries reachable to the root AOT build; the wiring test now checks these imports. This affected `lib/main.dart` and `test/android/bubble_entrypoint_wiring_test.dart`.

## Pending Android Device Validation

`adb devices -l` found no attached device. Delivery after a fresh or healed chain, `BubbleAlarm` logcat outcomes, notification permission handling, and the tapped one-question answer window remain unverified on device. With a signed-in device, launch the app, leave it with Home, watch for a Quick Check notification or `BubbleAlarm` outcome after roughly three minutes, then tap the notification and confirm the answer card renders.

## Commit Status

Changes remain in this isolated worktree. Git staging failed with the exact error:

```text
fatal: Unable to create '/home/kaasor/Documents/Backup/Hikma/Enchiridion/enchiridion/.git/worktrees/agent-260917-ndz/index.lock': Read-only file system
```

The coordinator must commit the code and this summary. `STATE.md`, `ROADMAP.md`, and `BATCH.json` were not edited.

## Self-Check: PASSED

All nine planned code files exist, the focused tests and full suite pass, Kotlin compiles, and the summary records the uncommitted state and pending device validation.
