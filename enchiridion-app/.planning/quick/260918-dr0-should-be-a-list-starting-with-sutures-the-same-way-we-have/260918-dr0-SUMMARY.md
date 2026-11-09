---
phase: quick-260918-dr0
plan: 01
quick_id: 260918-dr0
batch_id: 260918-dqw
subsystem: ui
tags: [flutter, dart, resource-topics, surgical-instrumentation, list, coming-soon]
status: complete
dependency-graph:
  requires:
    - 260918-dqx (availableFirst ordering helper)
    - 260918-dqy (ComingSoonStyle / ComingSoonBadge / ComingSoonDim / kComingSoonLabel)
  provides:
    - "ResourceTopicListScreen dense (OSCE-style ListTile) presentation mode"
    - "85-entry kSurgicalInstrumentationTopics catalog"
    - "Surgical Instrumentation source-fidelity guard test"
  affects:
    - enchiridion/lib/screens/library_screen.dart (Surgical Instrumentation call site only)
tech-stack:
  added: []
  patterns:
    - "Shared tap-handler closure extracted once, reused by both card and dense presentations"
    - "Guard test independently re-derives the slugification rule rather than importing production code"
key-files:
  created:
    - enchiridion/test/guards/surgical_instrumentation_source_fidelity_test.dart
  modified:
    - enchiridion/lib/models/resource_topic.dart
    - enchiridion/lib/screens/resource_topic_list_screen.dart
    - enchiridion/lib/screens/library_screen.dart
    - enchiridion/test/screens/resource_topic_list_screen_test.dart
decisions:
  - "Kept the pre-existing sutures entry byte-for-byte (id, title, asset paths, description) untouched per the dr1 sibling boundary; only its position was hoisted to index 0."
  - "Deduped the 'Foley catheter' bullet (listed twice in the source markdown) to its first occurrence, per plan instruction."
  - "Dense mode defaults to false so Medical Instrumentation and any other current/future caller keep the card presentation unless they opt in."
metrics:
  duration: "~35 minutes"
  completed: 2026-09-19
actuals:
  tokens: 9096
  tasks: 3
  commits: 4
  plan_head_before: 67181dbdc3030cf295d675dc8f09649058048488
---

# Phase quick-260918-dr0 Plan 01: OSCE-style Surgical Instrumentation list Summary

Turned Surgical Instrumentation from a single hero-card screen into an 85-row, OSCE-style dense list led by the suture topic, with a guard test that fails by name if the source markdown and the catalog ever drift apart.

## What Was Built

- Added an optional `dense` flag to `ResourceTopicListScreen`. When `false` (default) it renders exactly the existing hero-card presentation, unchanged. When `true`, it renders OSCE-style `ListTile` rows: a `CircleAvatar` icon, a title (dimmed when coming soon), a single-line description subtitle, and a trailing chevron (available) or `ComingSoonBadge` (coming soon). The tap handler — SnackBar guard for coming-soon rows, `ResourceTopicDetailScreen` push for available rows — was extracted into one shared closure used by both presentations.
- Wired `library_screen.dart`'s Surgical Instrumentation call site to `dense: true`. The Medical Instrumentation call site immediately below it (owned by siblings 260918-dr3/dr4) was left completely untouched.
- Expanded `kSurgicalInstrumentationTopics` from 1 entry to 85, one per unique bullet in `scripts/content/surgical instrumentation.md` (86 authored lines, `Foley catheter` deduped to its first occurrence). The pre-existing `sutures` entry (the only one with real content) was hoisted to position one and left byte-for-byte identical to its prior state, since sibling 260918-dr1 owns its `title`. Every other entry carries only `id`, `title`, `categoryTitle`, and `heroAssetPath` — no invented descriptions.
- Added `enchiridion/test/guards/surgical_instrumentation_source_fidelity_test.dart`: an independently-implemented slugifier re-parses the source markdown at test time and asserts set equality (both directions) against the catalog's ids, with one documented alias (`suture-material` → `sutures`). Skips cleanly if the source file is missing from the checkout.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Lint] Cleared `flutter analyze` findings surfaced by the plan-level verification pass**
- **Found during:** Plan-level `<verification>` step 2 (the five-file analyze command), after Task 3 committed
- **Issue:** `resource_topic_list_screen_test.dart` had a leading-underscore local helper (`_denseSubject`, a lint violation for local identifiers) and two `MaterialApp`/`ResourceTopicListScreen` constructor calls that could be `const`
- **Fix:** Renamed the helper to `denseSubject` and added `const` to both constructor invocations
- **Files modified:** `enchiridion/test/screens/resource_topic_list_screen_test.dart`
- **Commit:** `6682626`

### Worktree infrastructure catch-up (not a plan deviation, execution-environment note)

This worktree was branched before siblings 260918-dqx and 260918-dqy (the `availableFirst` helper and the `ComingSoonStyle`/`ComingSoonBadge`/`ComingSoonDim` module this plan explicitly builds on) had landed on `main`. Before starting Task 1, the worktree branch was fast-forwarded to `main`'s tip (`67181db`) — a pure fast-forward with no local divergent commits and no conflicts — to pick up that already-landed, already-reviewed infrastructure. No plan file was altered by this step; it only brought pre-existing main-branch history into the isolated worktree so the plan's "reuse-first" instructions could be followed as written.

## Verification

1. `cd enchiridion && flutter test` — full suite green, 166 tests including the repo-wide available-before-coming-soon ordering guard and the new fidelity guard.
2. `cd enchiridion && flutter analyze lib/models/resource_topic.dart lib/screens/resource_topic_list_screen.dart lib/screens/library_screen.dart test/guards/surgical_instrumentation_source_fidelity_test.dart test/screens/resource_topic_list_screen_test.dart` — clean, no issues.
3. Sibling-boundary check: `git diff 67181db HEAD -- enchiridion/lib/models/resource_topic.dart` shows `kMedicalInstrumentationTopics` untouched; `git diff 67181db HEAD -- enchiridion/lib/screens/library_screen.dart` shows only the one-line `dense: true` addition, Medical Instrumentation call site untouched.
4. Reuse check: `git diff 67181db HEAD --stat` touches exactly the 5 files declared in the plan's `files_modified` — no new ordering helper, badge, dim widget, or label constant declared anywhere in the diff.

## Self-Check: PASSED

- FOUND: enchiridion/lib/models/resource_topic.dart
- FOUND: enchiridion/lib/screens/resource_topic_list_screen.dart
- FOUND: enchiridion/lib/screens/library_screen.dart
- FOUND: enchiridion/test/screens/resource_topic_list_screen_test.dart
- FOUND: enchiridion/test/guards/surgical_instrumentation_source_fidelity_test.dart
- FOUND commit c35807c (Task 1)
- FOUND commit fd9173f (Task 2)
- FOUND commit ffa7272 (Task 3)
- FOUND commit 6682626 (lint fix)
