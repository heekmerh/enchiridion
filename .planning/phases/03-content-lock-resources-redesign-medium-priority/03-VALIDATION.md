---
phase: 3
slug: content-lock-resources-redesign-medium-priority
status: ready
nyquist_compliant: true
wave_0_complete: false
created: 2026-05-26
---

# Phase 3 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (built-in) + mockito ^5.4.4 |
| **Config file** | `enchiridion/pubspec.yaml` dev_dependencies |
| **Quick run command** | `cd enchiridion && flutter test test/ --name "reader\|resources\|library"` |
| **Full suite command** | `cd enchiridion && flutter test` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `cd enchiridion && flutter test test/ --name "reader|resources|library"`
- **After every plan wave:** Run `cd enchiridion && flutter test`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 03-01-01 | 01 | 1 | Free: Chapter 1 only | — | N/A | widget | `cd enchiridion && flutter test test/config/freemium_config_test.dart` | ❌ W0 | ⬜ pending |
| 03-01-02 | 01 | 1 | Free: locked overlay on Chapter 2+ | — | N/A | widget | `cd enchiridion && flutter test test/screens/reader_screen_test.dart` | ❌ W0 | ⬜ pending |
| 03-02-01 | 02 | 1 | Tab renamed to Resources + carousel | — | N/A | widget | `cd enchiridion && flutter test test/screens/library_screen_test.dart` | ❌ W0 | ⬜ pending |
| 03-02-02 | 02 | 1 | Carousel navigation + dots | — | N/A | widget | `cd enchiridion && flutter test test/screens/library_screen_test.dart` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `enchiridion/test/config/freemium_config_test.dart` — stubs for kFreeChapterCount assertions
- [ ] `enchiridion/test/screens/reader_screen_test.dart` — stubs for freemium gate widget tests
- [ ] `enchiridion/test/screens/library_screen_test.dart` — stubs for tab rename + carousel tests

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Carousel scroll feel + image rendering | Visual quality | Can't test visual fidelity in headless widget tests | Open app, go to Resources tab, swipe through all 4 cards |
| "Coming soon" snackbar on Instrumentation/OSCE tap | Routing placeholder | Platform snackbar timing unreliable in tests | Tap Instrumentation and OSCE cards, confirm snackbar appears |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 30s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved 2026-05-26
