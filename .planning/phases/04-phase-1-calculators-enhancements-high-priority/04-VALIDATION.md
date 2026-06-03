---
phase: 4
slug: phase-1-calculators-enhancements-high-priority
status: ready
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-27
---

# Phase 4 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (Flutter SDK) + mockito ^5.4.4 |
| **Config file** | none — `flutter test` auto-discovers `test/` |
| **Quick run command** | `flutter test test/models/calculator_definition_test.dart test/config/freemium_config_test.dart` |
| **Full suite command** | `flutter test` (from `enchiridion/` directory) |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run `flutter test test/models/calculator_definition_test.dart test/config/freemium_config_test.dart`
- **After every plan wave:** Run `flutter test`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** ~15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 4a-model | 04-01 | 1 | REQ-4a | — | N/A | unit | `flutter test test/models/calculator_definition_test.dart` | ❌ W0 | ⬜ pending |
| 4e-fields | 04-01 | 1 | REQ-4e | — | N/A | unit | `flutter test test/models/calculator_definition_test.dart` | ❌ W0 | ⬜ pending |
| 4e-ui | 04-01 | 1 | REQ-4e | — | N/A | widget | `flutter test test/screens/calculator_screen_test.dart` | ❌ W0 | ⬜ pending |
| 4f-bmi | 04-01 | 1 | REQ-4f | — | N/A | widget | `flutter test test/screens/calculator_screen_test.dart` | ❌ W0 | ⬜ pending |
| 4b-ec | 04-02 | 2 | REQ-4b | T-V5 | Input validated before calculation (no crash on empty/negative) | widget | `flutter test test/screens/calculator_screen_test.dart` | ❌ W0 | ⬜ pending |
| 4c-drug | 04-03 | 2 | REQ-4c | T-V5 | Input validated before calculation | widget | `flutter test test/screens/calculator_screen_test.dart` | ❌ W0 | ⬜ pending |
| 4d-peds | 04-04 | 2 | REQ-4d | T-V5 | Input validated before calculation | widget | `flutter test test/screens/calculator_screen_test.dart` | ❌ W0 | ⬜ pending |
| freemium | 04-01 | 1 | REQ-4a | T-V4 | kFreeCalculatorsPerCategory = 1 unchanged | unit | `flutter test test/config/freemium_config_test.dart` | ✅ exists | ⬜ pending |

---

## Wave 0 Requirements

- [x] `enchiridion/test/models/calculator_definition_test.dart` — unit tests: kCalculators count = 26 (8 existing + 18 new; NOTE: ROADMAP said 25 but codebase has 8 existing calculators, not 7), 5 new fields present with correct types, all categories present in groupByCategory output, freemium order invariant (existing first-in-category entries unchanged)
- [x] `enchiridion/test/screens/calculator_screen_test.dart` — widget tests: _ClinicalNotesSection renders non-empty fields, _ClinicalNotesSection is empty when all fields are empty, BMI weight converts kg→lb, BMI height converts cm→m, shock-index screen renders and accepts inputs

*Wave 0 must be committed before any calculator implementation tasks begin.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Calculator results match published clinical reference values | REQ-4b/4c/4d | Formula accuracy requires clinical verification; automated tests only check rendering | Manually test each calculator with known reference inputs; compare outputs against published guidelines |
| Disclaimer text visible on every calculator screen | REQ-4e | Visual inspection required | Open each calculator; verify disclaimer text appears below result card |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references (04-01 Task 1 creates both test files before Tasks 2-4 run)
- [x] No watch-mode flags
- [x] Feedback latency < 15s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved 2026-05-27
