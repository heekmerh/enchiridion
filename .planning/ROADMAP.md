# MVP Polish — Roadmap

**Milestone:** MVP Polish  
**Goal:** Ship shippable MVP with auth, content lock, reader polish, and Phase 1 calculators

---

## Phase Breakdown

### Phase 1: Email Confirmation & Device Binding (Critical)

**Goal:** Secure app access via email + device fingerprint

**Tasks:**
1. [ ] Supabase Auth setup — enable email confirmation
2. [ ] Supabase schema — add device_id, email_confirmed, authorized_devices columns
3. [ ] Device fingerprint service — get platform-specific device ID
4. [ ] SignUpScreen — create with email, password, name, role
5. [ ] ConfirmEmailScreen — "Check your email" + resend button
6. [ ] Device binding logic — tie first device on login
7. [ ] Device auth dialog — prompt for monthly device switch
8. [ ] Block app access if unconfirmed/unauthorized
9. [ ] Test end-to-end on 2 devices
10. [ ] Update login flow UI

**Deliverable:** Users can only access app after email confirmation and device binding

**Estimate:** 3–4 days

---

### Phase 2: Reader UX Polish (High Priority)

**Goal:** Fix reader experience — tables, navbar, TOC (tree structure with jump-to navigation)

**Plans:** 5/5 plans complete

Plans:
- [x] 02-01-PLAN.md — App bar fix (floating: false) + chapter_color data pipeline (book.json + Chapter model)
- [x] 02-02-PLAN.md — Table fix: TableBlockWidget + _AgeReferenceWidget (FixedColumnWidth, no horizontal scroll)
- [x] 02-03-PLAN.md — BlockRenderer → StatefulWidget + GlobalKey anchor map + ReaderContent callback wiring
- [x] 02-04-PLAN.md — reader_screen.dart: remove auto-hide timer (D-05) + scroll tracking _currentSectionId (D-11)
- [x] 02-05-PLAN.md — TOC tree (ExpansionTile, 3 levels) + _navigateToSection + active-section highlight

**Requirements:** REQ-2.1, REQ-2.2, REQ-2.3

**Deliverable:** Smooth, accessible reader with visible tables and persistent nav

---

### Phase 3: Content Lock & Resources Redesign (Medium Priority)

**Goal:** Free users see Chapter 1 only; rename Tools → Resources with carousel

**Plans:** 2 plans

Plans:
- [x] 03-01-PLAN.md — Verify freemium gate + add tests (reader_screen gate already shipped; kFreeChapterCount=1)
- [x] 03-02-PLAN.md — Rename Tools→Resources tab + horizontal PageView carousel (4 image cards, right-side dots, card routing) + widget tests

**Note:** Content-lock production code (`_LockedChapterOverlay`, `kFreeChapterCount=1`, gate in reader_screen.dart) is already implemented — Plan 01 is verification/tests only. pubspec already declares `assets/resources/` — no asset registration change needed.

**Requirements:** REQ-3.1, REQ-3.2

**Deliverable:** Resources section redesigned; content lock enforced

**Estimate:** 2 days

---

### Phase 4: Phase 1 Calculators + Enhancements (High Priority)

**Goal:** Add 18 new calculators with explanation, interpretation, safety notes

**Tasks:**

**4a. Calculator Definitions (1 day)**
1. [ ] Add 18 calculator definitions to kCalculators
2. [ ] Categorize into Emergency & Critical Care, Drug Dosing, Pediatrics
3. [ ] Write brief descriptions

**4b. Emergency & Critical Care (3 days)**
1. [ ] qSOFA / SOFA score
2. [ ] NEWS2 (Early Warning Score)
3. [ ] Shock Index
4. [ ] Osmolality & Osmolar Gap
5. [ ] Corrected Sodium
6. [ ] A-a Gradient
7. [ ] PaO₂/FiO₂ Ratio

**4c. Drug Dosing (2 days)**
1. [ ] BSA
2. [ ] eGFR (CKD-EPI)
3. [ ] Gentamicin / Vancomycin
4. [ ] Insulin dose
5. [ ] Paracetamol dosing

**4d. Pediatrics (2 days)**
1. [ ] APLS weight estimation
2. [ ] Broselow Tape equivalent
3. [ ] Pediatric BP percentiles
4. [ ] Neonatal bilirubin
5. [ ] APGAR score
6. [ ] Growth percentile

**4e. Enhancements (2 days)**
1. [ ] Add explanation field to all 25 calculators
2. [ ] Add clinical interpretation field
3. [ ] Add safety notes field
4. [ ] Add common pitfalls field
5. [ ] Add OSCE tips field
6. [ ] Update calculator screens to display all sections

**4f. BMI Unit Conversion (0.5 day)**
1. [ ] Detect unit picker change
2. [ ] Auto-convert entered values
3. [ ] Test conversion accuracy
4. [ ] Verify no data loss

**Deliverable:** 25 total calculators with full enhancements; BMI unit conversion working

**Estimate:** 10–11 days

---

## Critical Path & Sequencing

```
Phase 1 (Email + Device)
    ↓
Phase 2 (Reader UX) — can run parallel with Phase 3
Phase 3 (Content Lock + Resources)
    ↓
Phase 4 (Calculators) — can run parallel with Phases 2–3 after Phase 1
```

**Recommendation:**
1. **Week 1:** Complete Phase 1 (unblocks app release)
2. **Week 2:** Parallel — Phase 2 (reader), Phase 3 (resources), Phase 4a-4b (calculators)
3. **Week 3:** Complete Phase 4c-4f (remaining calculators + enhancements)

---

## Success Criteria

- [ ] Email-verified access working (Phase 1)
- [ ] Device binding enforced (Phase 1)
- [ ] Tables render without horizontal scroll (Phase 2)
- [ ] Top navbar always visible (Phase 2)
- [ ] TOC tree navigation working (Phase 2)
- [x] Free users see Chapter 1 only (Phase 3)
- [x] Resources section fully redesigned (Phase 3)
- [ ] All 25 calculators implemented (Phase 4)
- [ ] All calculators have explanation + interpretation (Phase 4)
- [ ] BMI unit conversion working (Phase 4)
- [ ] No new bugs introduced in existing features

---

## Testing Strategy

**Phase 1:**
- [ ] Test signup → email → confirmation flow
- [ ] Test login on Device A (binding)
- [ ] Test login on Device B (device auth prompt)
- [ ] Test monthly switch limit

**Phase 2:**
- [ ] Render tables on phone (320px, 375px, 414px widths)
- [ ] Scroll behavior on multiple screen sizes
- [ ] TOC expand/collapse + jump-to accuracy
- [ ] Regression: existing reader features still work

**Phase 3:**
- [ ] Carousel scrolls smoothly
- [ ] Images load correctly
- [ ] Tap category opens correct section
- [ ] Chapter 1 only visible for free users
- [ ] Locked chapter shows properly

**Phase 4:**
- [ ] Each calculator: inputs accept valid range
- [ ] Calculation results accurate
- [ ] Unit conversions correct
- [ ] Disclaimers display
- [ ] Regression: freemium gating still works (1 free per category)

---

## Rollout Plan

**Internal Testing:**
- Phases 1–4 complete and tested locally

**Beta Release (Limited):**
- Share APK with 5–10 beta testers
- Gather feedback on UX, device binding, calculators

**Production Release:**
- Fix critical bugs from beta
- Deploy to Play Store
- Monitor crash reports, user feedback

---

## Known Blockers & Dependencies

- **Supabase Schema Update:** Must add device_id, email_confirmed, authorized_devices before Phase 1
- **Tool Images:** Already provided in assets/resources/ ✓
- **Phase 4 Calculator Specs:** Reference Ideas/ideas.md ✓
- **Deep Linking (Email Confirmation):** Supabase handles via link; may need deep link config for Android

---

## Next Actions

1. [ ] Kick off Phase 1 → `/gsd:plan-phase 1`
2. [ ] After Phase 1 approved → `/gsd:execute-phase 1`
3. [ ] Kick off Phases 2, 3, 4 in parallel after Phase 1 complete

---

*Roadmap finalized: 2026-05-21*
*Phase 2 planned: 2026-05-23 — 5 plans, 5 waves*
*Phase 3 planned: 2026-05-26 — 2 plans, 1 wave*
*Phase 3 executed: 2026-05-27 — 03-01 (freemium gate tests) + 03-02 (Resources carousel) complete; 16/16 tests pass*
