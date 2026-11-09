# Feature Landscape

**Domain:** Medical reference and clinical education mobile app
**Project:** Enchiridion
**Researched:** 2026-04-11
**Confidence:** MEDIUM-HIGH (derived from competitor analysis via domain knowledge, project planning documents, and existing codebase)

---

## Research Basis

This analysis is grounded in:
- The project's own planning documents (`Ideas/new_features.md`, `Ideas/ideas.md`, `FLUTTER_IMPLEMENTATION_PLAN.md`)
- The existing Flutter codebase (models, screens, providers already built)
- Competitor landscape: Geeky Medics, Oxford Handbook apps, Medscape, Amboss, Anki medical decks
- Domain knowledge of medical education mobile apps

Note: Web search was not available during this research pass. Competitor feature analysis draws on training knowledge (cutoff August 2025). Flag items marked LOW confidence for external validation if needed.

---

## Table Stakes

Features users expect. Missing = product feels incomplete or users switch to Medscape/Amboss.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Offline access to content | Medical students use apps in clinical settings with no Wi-Fi; ALL major medical apps work offline | High | JSON already embedded as assets — needs bundling, not a server call |
| Full-text search across content | Every reference app has search; users cannot browse 7 books manually | Medium | Search index across all books/chapters/sections |
| Bookmarks / saved positions | Users return to specific topics repeatedly; expected from any reader app | Low | Model already built (`bookmark.dart`); needs UI surface |
| Reading progress indicator | Shows where user is in a chapter; standard reader UX | Low | Already implemented (`reader_progress_bar.dart`) |
| Dark mode / theme switching | Medical students use apps at night, on-call; eye strain is a real concern | Low | Already implemented (Light/Dark/Sepia in `app_theme.dart`) |
| Font size adjustment | Variable viewing conditions, accessibility | Low | Already in `user_settings.dart` |
| Chapter/section navigation | TOC drawer, prev/next chapter; users navigate non-linearly | Low | Already implemented (`toc_drawer.dart`, `reader_navigation.dart`) |
| User authentication | Freemium model requires identity; also enables cross-device sync of notes | Medium | Specified in `new_features.md`; not yet built |
| Freemium content gates | First chapter free, rest paid — standard monetization for Oxford Handbook-style apps | Medium | Logic specified; not yet built |
| Clinical calculators (core set) | Medscape and all clinical apps include calculators; expected by junior doctors | High | 8 calculators fully specified in `ideas.md`; engine not built |
| MCQ question bank | Every medical education app (Amboss, Geeky Medics) includes self-assessment questions | Medium | Specified in `new_features.md`; not yet built |
| Structured content blocks | Medical content needs visual hierarchy: red flags, clinical pearls, algorithms, mnemonics | Medium | Already built (`content_block.dart`, block renderer widgets) |
| Library / book discovery screen | Users need to browse 7 books; card grid is standard | Low | Specified; not yet built (only single-book reader exists) |
| Last-read position persistence | App must reopen where user left off | Low | Partially in `storage_service.dart`; needs multi-book scope |

---

## Differentiators

Features that set Enchiridion apart. Not universally expected, but create real value for the target user.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Calculator result interpretation with clinical context | Amboss/Medscape calculators give raw numbers; Enchiridion adds "explain result", "next step", "OSCE tips" | Medium | Fully specified in `ideas.md`; unique educational layer |
| OSCE tips tied to calculator results | No competitor links calculator outputs to OSCE exam preparation | Low | High value for the student audience; low additional build cost once calculator engine exists |
| Keyword cross-referencing between books | A keyword in Surgery links to its section in Internal Medicine; cross-specialty connections | High | Specified in `ideas.md`; requires cross-book index and tagging system |
| Collapsible per-topic personal notes | Most apps have a generic notes section; Enchiridion embeds notes inline at topic level | Medium | Specified in `ideas.md`; requires note model + persistence per chapter section |
| Content organized by specialty book (not flat search) | Oxford Handbook-style specialty books are trusted by medical students; familiar mental model | Low | Already the architecture; differentiates from Medscape's flat disease-index approach |
| Structured content blocks as first-class UI | Mnemonics, red flags, algorithms, clinical pearls as typed visual blocks — not plain text | Medium | Already built; competitor apps render flat HTML |
| Educational framing on calculators (common pitfalls, safety notes) | Makes Enchiridion a teaching tool, not just a lookup tool | Low | Specified; just copy in the calculator data model |
| OSCE-style question bank (not just MCQ) | Geeky Medics OSCE content is highly sought-after; clinical scenario format | Medium | Partially specified; adds exam preparation dimension |
| Sepia reading mode | Oxford Handbook apps and Kindle popularised this; medical students read for hours | Low | Already built |

---

## Anti-Features

Features to explicitly NOT build — they create scope creep, medical-legal risk, or dilute the product.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Drug interaction checker | Regulatory minefield; requires real-time BNF/WHO drug database; requires clinical-grade accuracy | Reference users to BNF app or hospital formulary |
| Diagnostic AI / symptom checker | Enormous liability; misleads junior doctors; impossible to validate safely | Provide reference content only; use disclaimer framework already specified |
| Real-time news feed / medical news | Maintenance burden; out of scope for reference tool; content goes stale quickly | Keep focus on curated, stable clinical reference content |
| Social features (discussion forums, peer sharing) | Moderation burden; not expected by this audience; competitor UpToDate has proved users don't want this | Let users share externally via copy-result or screenshot |
| Telemedicine / patient-facing features | Completely wrong audience; licensing complexity | Keep app clinician/student-facing only |
| Crowdsourced / user-editable content | Medical inaccuracy risk; QA overhead; trust damage if wrong content appears | Content is author-curated; quality over volume |
| Complex spaced repetition (Anki-style) | Anki already does this better; building SR algorithm is a non-trivial feature | Provide MCQ and OSCE tips; don't rebuild Anki |
| Multi-language support at launch | Translation requires clinical review in each language; huge overhead | English only at launch; add languages later as paid expansion |
| Push notifications for learning reminders | Battery drain complaints; users find it intrusive; medical students have their own study schedules | Optional local notification at most; not server-push |
| Live video or lecture content | Bandwidth, CDN, licensing, and content production costs | Text + calculators only |

---

## Feature Dependencies

```
User Authentication
  → Freemium Access Gates (gates require user identity)
  → Personal Notes / Annotations (notes must be persisted per user)
  → Reading Progress (progress sync requires user identity for multi-device)
  → MCQ Question Bank (track answered questions per user)

Library Landing Screen
  → Multi-book support in BookService (currently loads single book)
  → Multi-book BookProvider (currently single-book scoped)

Multi-book Support (BookService + BookProvider refactor)
  → Freemium gates per-book
  → Keyword cross-referencing (needs cross-book index)
  → Reading progress per book

Calculator Engine (shared screen pattern, data model, validation framework)
  → Individual calculators (each calculator is a data record + formula function)
  → Calculator favorites / save
  → OSCE tips on calculators

MCQ Question Bank
  → User Authentication (to track score and history)
  → Freemium gates (10 questions free per book)

Keyword Cross-referencing
  → Multi-book support (index must span books)
  → Content tagging in JSON data (requires data layer work)

Personal Notes
  → User Authentication
  → Topic/subsection-level anchoring in content model
```

---

## MVP Recommendation

The current codebase has a single-book reader working. The MVP completion goal is: a fully functional freemium app deployable to both stores.

**Prioritize (MVP):**

1. **Multi-book library** — Library screen + BookService for 7 books + per-book state. Without this, the app is a prototype, not a product.
2. **User authentication** — Firebase Auth with email/password. Gates everything else. Must come before freemium.
3. **Freemium access gates** — Chapter 1 + 10 questions + 1 calculator per category free. Core business model.
4. **Calculator engine + 8 v1 calculators** — The 8 calculators in `ideas.md` are fully specified and buildable. Calculators are a strong differentiator and have no competitor dependency.
5. **MCQ question bank** — Basic per-book question screen with score tracking. Content already exists as JSON.
6. **Full-text search** — Cross-book search. Users need this to navigate 7 books.
7. **Personal notes** — Collapsible per-topic note panel. Medium complexity, high perceived value.

**Defer post-MVP:**

- **Keyword cross-referencing** — High complexity, requires data-layer tagging work across all 7 book JSON files. Defer to Phase 2.
- **OSCE-style questions** — MCQ first; OSCE format adds complexity. Defer to Phase 2.
- **Backlog calculators** (30+) — 8 v1 calculators deliver the value; the long tail can follow incrementally.
- **Multi-device sync** — Local-first storage is fine for MVP; add Firestore sync later.
- **Calculator favorites** — Nice-to-have; not needed for v1.

---

## Feature Inventory: Build Status

| Feature | Status | Phase |
|---------|--------|-------|
| Single-book reader (HTML blocks, nav, TOC) | Built | Done |
| Theme system (Light/Dark/Sepia) | Built | Done |
| Bookmarks | Built (model + provider) | Needs UI polish |
| Reading progress bar | Built | Done |
| Font size / typography settings | Built | Done |
| Multi-book library screen | Not built | MVP Phase 1 |
| Multi-book BookService | Not built | MVP Phase 1 |
| User authentication | Not built | MVP Phase 2 |
| Freemium access gates | Not built | MVP Phase 2 |
| Calculator engine | Not built | MVP Phase 3 |
| 8 v1 calculators | Not built | MVP Phase 3 |
| MCQ question bank | Not built | MVP Phase 4 |
| Full-text search | Not built | MVP Phase 4 |
| Personal notes / annotations | Not built | MVP Phase 5 |
| Keyword cross-referencing | Not built | Post-MVP |
| OSCE-style questions | Not built | Post-MVP |
| Backlog calculators (30+) | Not built | Post-MVP |

---

## Sources

- Project planning documents: `Ideas/new_features.md`, `Ideas/ideas.md`, `FLUTTER_IMPLEMENTATION_PLAN.md`
- Existing codebase: `enchiridion/lib/` (models, screens, providers, widgets)
- Competitor analysis: Geeky Medics, Oxford Handbook apps, Medscape, Amboss — training knowledge, confidence MEDIUM
- Medical education app conventions: domain knowledge, confidence MEDIUM
