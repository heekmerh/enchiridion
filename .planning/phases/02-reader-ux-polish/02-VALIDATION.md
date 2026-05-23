---
phase: 02-reader-ux-polish
padded_phase: "02"
date: 2026-05-23
status: ready
---

# Phase 2: Reader UX Polish — Validation Architecture

## Test Framework

| Property | Value |
|----------|-------|
| Framework | flutter_test (built-in, no separate install) |
| Config file | None (uses default flutter test runner) |
| Quick run command | `cd enchiridion && flutter test test/widgets/ -x` |
| Full suite command | `cd enchiridion && flutter test` |

## Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| REQ-2.1 | TableBlockWidget renders without horizontal scroll | Widget test | `flutter test test/widgets/table_block_test.dart -x` | No — Wave 0 |
| REQ-2.1 | Equal column widths computed from MediaQuery | Widget test | `flutter test test/widgets/table_block_test.dart -x` | No — Wave 0 |
| REQ-2.2 | SliverAppBar floating is false | Widget test | `flutter test test/widgets/reader_app_bar_test.dart -x` | No — Wave 0 |
| REQ-2.3a | TOC renders Chapter→Section→Subsection tree | Widget test | `flutter test test/widgets/toc_drawer_test.dart -x` | No — Wave 0 |
| REQ-2.3b | TOC all collapsed on open | Widget test | `flutter test test/widgets/toc_drawer_test.dart -x` | No — Wave 0 |
| REQ-2.3c | Tap subsection → onSectionSelected called | Widget test | `flutter test test/widgets/toc_drawer_test.dart -x` | No — Wave 0 |
| REQ-2.3d | Active section highlighted in TOC | Widget test | `flutter test test/widgets/toc_drawer_test.dart -x` | No — Wave 0 |
| D-05 | No auto-hide timer on back+TOC pill | Unit test (logic) | `flutter test test/screens/reader_screen_test.dart -x` | No — Wave 0 |

## Sampling Rate

- **Per task commit:** `cd enchiridion && flutter test test/widgets/ -x`
- **Per wave merge:** `cd enchiridion && flutter test`
- **Phase gate:** Full suite green before `/gsd:verify-work`

## Wave 0 Gaps

- [ ] `test/widgets/table_block_test.dart` — covers REQ-2.1
- [ ] `test/widgets/reader_app_bar_test.dart` — covers REQ-2.2
- [ ] `test/widgets/toc_drawer_test.dart` — covers REQ-2.3a/b/c/d
- [ ] `test/screens/reader_screen_test.dart` — covers D-05 (no timer)
