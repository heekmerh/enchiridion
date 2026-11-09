# PRD: Freemium Access Model

## Introduction

Enchiridion operates on a freemium model. Authenticated users get limited free access to book content, question banks, and calculators. Full access requires an unlock â€” either per-book or via a subscription. This PRD covers access gating, the unlock prompt/paywall UI, and the data model for tracking user access state. Payment processing integration is out of scope for this version (the unlock flow ends at a placeholder confirmation screen).

---

## Goals

- Define and enforce access tiers (free vs. unlocked) for book content, question banks, and calculators
- Show clear, non-disruptive paywall prompts when a user hits a gate
- Store and read unlock state from Supabase
- Make it easy to expand payment processing in a future version

---

## Access Tiers

| Feature | Free | Unlocked |
|---|---|---|
| Book content | First chapter only | Full book |
| Question bank | First 10 questions per book | All questions |
| Calculators | One per category | All calculators |
| Notes / annotations | All logged-in users | All logged-in users |

---

## User Stories

### US-001: Book Content Gate
**Description:** As the system, I need to restrict book content beyond the first chapter to unlocked users so that the freemium model is enforced.

**Acceptance Criteria:**
- [x] In the book reader, content beyond the first chapter is blurred or hidden for free users
- [x] A paywall prompt appears at the end of the first chapter: "Unlock full access to continue reading [Book Title]"
- [x] Tapping the paywall prompt opens the Unlock Screen (US-004)
- [x] Unlocked users see the full book with no gate
- [x] Unlock state is read from Supabase `user_book_access` table on reader screen load
- [x] Flutter analyzer passes with no errors

### US-002: Question Bank Gate
**Description:** As the system, I need to prevent access to questions 11+ for free users so that the question bank freemium limit is enforced.

**Acceptance Criteria:**
- [x] Questions with `question_number > 10` are displayed with a lock icon and "Unlock" label in the question list
- [x] Tapping a locked question opens the Unlock Screen (US-004) for that book
- [x] Unlocked users see and can access all questions
- [x] Flutter analyzer passes with no errors

### US-003: Calculator Gate
**Description:** As the system, I need to restrict all but one calculator per category for free users.

**Acceptance Criteria:**
- [x] In the calculator list, the first calculator per category is freely accessible; remaining calculators in the same category show a lock icon
- [x] Tapping a locked calculator shows a brief bottom sheet: "Unlock all calculators to access [Calculator Name]" with an "Unlock" button
- [x] Tapping "Unlock" navigates to the Unlock Screen (US-004)
- [x] Unlocked users (full subscription) see all calculators with no gate
- [x] Flutter analyzer passes with no errors

### US-004: Unlock Screen (Paywall UI)
**Description:** As a free user, I want to see a clear unlock prompt so that I understand what I get by unlocking and can choose to proceed.

**Acceptance Criteria:**
- [x] Unlock Screen shows: book thumbnail (if book-specific), a title "Unlock [Book Title]" or "Unlock All Access", a bullet list of what is included in the unlock, and two CTA buttons: "Unlock this Book â€” [price placeholder]" and "Full Subscription â€” [price placeholder]"
- [x] Tapping either CTA button currently shows a placeholder screen: "Payment coming soon â€” thank you for your interest!" with a "Go Back" button (no actual payment processing in this version)
- [x] A "Maybe later" / dismiss button closes the unlock screen and returns to the previous screen
- [x] Flutter analyzer passes with no errors

### US-005: Grant and Read Unlock State
**Description:** As a developer, I need a reliable way to grant and check book unlock state so that gating logic is consistent across all features.

**Acceptance Criteria:**
- [x] `user_book_access` table in Supabase: `id` (UUID PK), `user_id` (UUID FK), `book_id` (text, or `*` for full subscription), `access_type` (text: `book` | `subscription`), `granted_at` (timestamp)
- [x] A single Dart service class `AccessService` exposes: `hasBookAccess(userId, bookId) â†’ Future<bool>` and `hasFullAccess(userId) â†’ Future<bool>`
- [x] Both methods check for a subscription row (`book_id = '*'`) or a book-specific row in `user_book_access`
- [x] Access is cached in memory for the session duration (no repeated Supabase calls per screen)
- [x] RLS: users can only read their own rows; only a service role key (server-side) can insert rows
- [x] Flutter analyzer passes with no errors

### US-006: Admin Grant Access (Manual / Seed)
**Description:** As an admin, I need to be able to manually grant a user full or per-book access in Supabase so that I can handle beta testers and manual unlocks before payment is integrated.

**Acceptance Criteria:**
- [ ] A Supabase SQL seed script or Supabase dashboard instruction is documented that inserts a row into `user_book_access` for a given user
- [x] The `AccessService` correctly reflects manually granted access on next app start
- [x] This is a developer/admin operation â€” no in-app admin panel required in this version

---

## Functional Requirements

- FR-1: All gate checks must go through `AccessService`; no feature should query `user_book_access` directly
- FR-2: Free tier limits are constants defined in a single Dart file (`freemium_config.dart`): free chapter count (1), free question count (10), free calculators per category (1)
- FR-3: Unlock state is fetched once per session on login and cached; a manual refresh is available via app restart
- FR-4: The book content gate must blur or hide content (not just show a banner above it) so that free users cannot scroll past and read locked content
- FR-5: The calculator gate applies per category; if the category has only one calculator, it is freely accessible
- FR-6: RLS on `user_book_access` must prevent users from inserting their own access grants; only the service role can write to this table

---

## Non-Goals

- Actual payment processing (Stripe, Google Pay, etc.) â€” placeholder UI only in this version
- Free trial with expiry â€” not in this version
- Discount codes or promotional access â€” not in this version
- In-app receipt validation â€” not in this version
- Server-side access enforcement (content served via API with auth check) â€” client-side gating only in this version

---

## Technical Considerations

- `AccessService` is a singleton initialized after login; inject via Provider
- Cache: a simple `Map<String, bool>` keyed by book_id, loaded once from Supabase on session start
- Book content gating in the reader: check chapter index against `freemiumConfig.freeChapterCount`; if locked, render a blur overlay widget (`BackdropFilter`) over the content with the paywall prompt on top
- Calculator gating: each `CalculatorDefinition` has a `category` field; the first calculator per category (sorted by a fixed `order` field) is free
- Future payment integration: `AccessService.grantAccess()` will call a Supabase Edge Function that validates payment and inserts the access row server-side

---

## Success Metrics

- No authenticated free user can access locked content through any navigation path
- Unlock prompt is shown within 1 tap of hitting a gate
- `AccessService.hasBookAccess()` resolves in under 100ms (from cache) after first load

---

## Open Questions

- What is the price point for per-book unlock vs. full subscription? (Needed for the placeholder UI)
- Should the freemium limits be configurable from Supabase (remote config) or hardcoded in the app?
- Should beta testers get automatic full access, or will they be granted manually via Supabase?
