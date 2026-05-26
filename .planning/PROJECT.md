# Enchiridion — Project Context

**Last Updated:** 2026-05-21  
**Current Milestone:** MVP Polish

---

## What This Is

Enchiridion is a Flutter mobile app for medical students and junior doctors. It brings together structured clinical reference books, a self-assessment question bank, and clinical calculators into one mobile-first product. Content is delivered in a freemium model — enough free to evaluate, paid to unlock the full resource.

---

## Core Value

A medical student or junior doctor can open any of the 7 clinical books, test themselves with questions, and run bedside calculations — all in one place, on their phone. The app is:
- **Offline-capable:** Books load as JSON locally
- **Device-locked:** Tied to device with monthly switch allowance
- **Email-verified:** Sign-up requires confirmation
- **Freemium:** First chapter + calculator per category + 10 questions free

---

## Current Status

### Active Milestones

**MVP Polish** (current)
- Email confirmation flow
- Device binding & monthly switch
- Locked content (Chapter 1 only free)
- Reader UX (table wrapping, fixed navbar, tree TOC)
- Resources section redesign (formerly "Tools")
- Phase 1 calculators (18 new)
- Calculator enhancements (explanation, clinical interpretation)
- BMI unit auto-conversion

---

## Requirements (Active)

### Access Control & Authentication

- [ ] Email confirmation required on signup
- [ ] User can only access app after confirming email
- [ ] Device fingerprint stored on first login
- [ ] User tied to device; can switch once per calendar month
- [ ] Subsequent logins on old device are rejected
- [ ] Clear messaging about device binding to user

### Content Access

- [ ] Only Chapter 1 visible to free users
- [ ] Remaining chapters show lock icon + "Unlock" button
- [ ] Freemium gates enforced per book
- [ ] Paywall (UnlockScreen) accessible from locked chapters

### Reader Experience

- [ ] Tables wrap content (no horizontal scroll)
- [ ] Top app bar stays fixed (doesn't disappear on scroll)
- [ ] Sidebar shows chapter tree (expandable sections/subsections)
- [ ] Clicking subsection jumps directly to content
- [ ] Progress indicator persists with navbar

### Resources Section

- [ ] Rename "Tools" tab to "Resources"
- [ ] Display 4 tool categories as full-screen carousel:
  - Calculators
  - OSCE
  - Questions
  - Instrumentation
- [ ] Each shows full-screen image + title overlay
- [ ] Tap to enter that section
- [ ] Page indicator dots on right

### Calculators

**Phase 1 Additions (18 new):**
- [ ] Emergency & Critical Care: qSOFA, NEWS2, Shock Index, Osmolality, Corrected Sodium, A-a Gradient, PaO₂/FiO₂
- [ ] Drug Dosing: BSA, eGFR, Gentamicin/Vancomycin, Insulin, Paracetamol
- [ ] Pediatrics: APLS weight, Broselow, BP percentiles, Bilirubin, APGAR, Growth percentile

**All Calculators (Enhanced):**
- [ ] Result Explanation (plain language)
- [ ] Clinical Interpretation (how to act)
- [ ] Safety Notes (when NOT to use)
- [ ] Common Pitfalls (mistakes)
- [ ] OSCE Tips (exam-focused)

**BMI Calculator Specific:**
- [ ] Auto-convert all values when unit switches
- [ ] Maintain same physical quantity across unit changes

---

## Out of Scope (v1)

- Real-time chat or social features
- Content authoring tools
- Web version
- OAuth / social login
- Push notifications
- Phases 2-3 calculators (beyond Phase 1)

---

## Architecture & Tech Stack

- **Framework:** Flutter (Dart)
- **Auth:** Supabase (email/password)
- **Storage:** Supabase + local SharedPreferences
- **State:** Provider
- **Content:** JSON (pre-written, loaded locally)
- **Target Platforms:** Android (primary), iOS (secondary), Windows/macOS/Linux (desktop, secondary)

---

## Key Decisions

| Decision | Rationale | Status |
|----------|-----------|--------|
| Flutter | Cross-platform, mobile-first; already started | ✓ Active |
| Email/password auth | Sufficient for v1; device binding adds security | ⏳ In Progress |
| JSON content | Pre-written, no CMS needed | ✓ Active |
| Freemium model | First chapter + 10 Q + 1 calc/category free | ✓ Implemented (partial) |
| Device binding | Prevent unauthorized sharing; once/month switch | ⏳ Pending |
| Email confirmation | Reduce spam signups; tie to device for enforcement | ⏳ Pending |

---

## Success Metrics for MVP Polish

- [ ] Email-verified users can access app (confirmation required)
- [ ] Device binding prevents cross-device sharing (with monthly allowance)
- [ ] Free users see only Chapter 1 per book
- [ ] Tables render without horizontal scroll
- [ ] Resources section fully redesigned (4 categories, carousel UI)
- [ ] Phase 1 calculators implemented with enhancements
- [ ] BMI unit conversion working
- [ ] All (7 current + 18 new = 25 total) calculators have disclaimers

---

## Timeline & Dependencies

**Blocking:**
- Supabase schema updates (device_id, email_confirmed columns)
- Email confirmation setup in Supabase Auth

**Parallel:**
- Reader UX fixes (no dependencies)
- Resources section redesign (images already provided)
- Phase 1 calculator implementation

**Post-Email-Confirmation:**
- Device binding logic

---

## Known Issues & Technical Debt

- [ ] Table content overflow (horizontal scroll) — to fix
- [ ] SliverAppBar floating behavior — to fix
- [ ] Settings drawer footer covered — **FIXED** (added padding)
- [ ] Device binding logic not yet designed
- [ ] Tree structure for TOC not implemented
- [ ] No calculator result history/save feature

---

## Context & References

- **PRD:** `PRD.md` (comprehensive feature list)
- **Ideas:** `Ideas/ideas.md` (calculator specifications)
- **Calculator Definitions:** `lib/models/calculator_definition.dart`
- **Auth Service:** `lib/services/auth_service.dart`
- **Reader Screen:** `lib/screens/reader_screen.dart`
- **Resources Folder:** `assets/resources/` (4 images: calculators, exam_prep, instrumentation, osce)

---

## Next Steps

1. Create REQUIREMENTS.md (detailed scoped requirements)
2. Create ROADMAP.md (phase breakdown for this milestone)
3. Start Phase 1: Email confirmation & device binding
4. Then Phase 2: Reader UX fixes
5. Then Phase 3: Resources redesign
6. Then Phase 4: Phase 1 calculators

---

*Last updated: 2026-05-21 — Milestone "MVP Polish" initialized*
