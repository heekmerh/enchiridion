# Enchiridion

## What This Is

Enchiridion is a Flutter mobile app for medical students and junior doctors. It brings together structured clinical reference books, a self-assessment question bank, and clinical calculators into one mobile-first product. Content is delivered in a freemium model — enough free to evaluate, paid to unlock the full resource.

## Core Value

A medical student or junior doctor can open any of the 7 clinical books, test themselves with questions, and run bedside calculations — all in one place, on their phone.

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] User can register and log in with email and password
- [ ] User can reset their password via email
- [ ] User session persists across app restarts
- [ ] Landing page shows all 7 books as thumbnail cards
- [ ] User can open a book and read its content chapter by chapter
- [ ] First chapter of each book is free; remaining chapters require unlock
- [ ] User can access a question bank per book (first 10 questions free)
- [ ] User can run clinical calculators (one per category free; rest require unlock)
- [ ] Each calculator shows result, clinical interpretation, and a safety disclaimer
- [ ] User can add collapsible side notes to any topic
- [ ] Keyword tags in book content link to related sections
- [ ] Freemium gates enforced at the content level after authentication

### Out of Scope

- Real-time chat or social features — not a community app
- Content authoring tools — content is pre-written and loaded as JSON
- Web version — mobile-first, Flutter app only for v1
- OAuth / social login — email/password sufficient for v1
- Push notifications — defer to v2

## Context

- Flutter app already exists at `enchiridion/` with standard architecture (screens, widgets, models, services, providers)
- Book content for all 7 titles already written and available as JSON — loading/rendering is the work, not content creation
- 7 books: Internal Medicine, Surgery, Obstetrics & Gynaecology, Psychiatry, Radiology, Orthopedics, Dermatology
- Book thumbnails available at `Ideas/books/`
- Detailed feature specs in `Ideas/new_features.md`
- Target audience: medical students and junior doctors in Nigeria / African medical schools (implied by app context and content)
- Intended for wider public release on app stores

## Constraints

- **Tech stack**: Flutter — already chosen, all development stays in Flutter/Dart
- **Content**: JSON format, pre-written — no CMS or content creation tools needed
- **Distribution**: App stores (iOS + Android) — must follow store guidelines
- **Safety**: All calculators must display disclaimers; no wording implying clinical authority

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Flutter for mobile | Already started; cross-platform for iOS + Android | — Pending |
| JSON for book content | Content already in this format; no backend CMS needed for v1 | — Pending |
| Freemium model | First chapter + 10 questions + 1 calculator per category free | — Pending |
| Email/password auth only | Sufficient for v1; OAuth adds complexity without clear demand | — Pending |
| Question bank scoped per book | Aligns with how users study by specialty | — Pending |

---
*Last updated: 2026-04-11 after initialization*
