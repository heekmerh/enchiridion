# PRD: Question Bank

## Introduction

Enchiridion includes a per-book question bank for self-assessment. Questions are organized by book and chapter, formatted as multiple-choice questions (MCQ) with explanations. Access is gated under the freemium model: the first 10 questions per book are free, and the rest require an unlock. User progress (answered questions and scores) is tracked per user per book.

---

## Goals

- Provide MCQ-based self-assessment for each book
- Track which questions a user has answered and their score
- Enforce the freemium gate (10 free questions per book)
- Display OSCE-style tips tied to questions where relevant

---

## User Stories

### US-001: Browse Questions by Book
**Description:** As a user, I want to see questions organized by book so that I can quiz myself on what I've read.

**Acceptance Criteria:**
- [x] A "Questions" entry point is accessible from the book reader screen (or a dedicated tab)
- [x] Selecting a book opens a question list screen showing all questions for that book in chapter order
- [x] Each question item in the list shows: question number, a short preview of the question text (first 60 characters), and a status icon (unanswered / correct / incorrect)
- [x] Questions beyond the 10-question free limit are shown with a lock icon and a "Unlock" label instead of being selectable
- [x] Flutter analyzer passes with no errors

### US-002: Answer a Multiple-Choice Question
**Description:** As a user, I want to read a question and select an answer so that I can test my knowledge.

**Acceptance Criteria:**
- [x] Question screen shows: full question text, 4 answer options (Aâ€“D) as tappable cards
- [x] Only one option can be selected at a time
- [x] After selecting an option, a "Submit" button becomes active
- [x] Tapping "Submit" locks the selection (no further changes allowed) and reveals the result
- [x] If correct: selected option highlights green, feedback shows "Correct!"
- [x] If incorrect: selected option highlights red, correct option highlights green, feedback shows "Incorrect"
- [x] The explanation for the correct answer is shown below the result
- [x] If an OSCE tip exists for the question, it is shown in a distinct "OSCE Tip" card below the explanation
- [x] A "Next Question" button advances to the next question in the list
- [x] Flutter analyzer passes with no errors

### US-003: Track Answers and Score
**Description:** As a user, I want to see my progress and score for each book's question bank so that I can measure my learning.

**Acceptance Criteria:**
- [x] Each answered question is recorded locally on-device (answers migrated from Supabase to SharedPreferences)
- [x] The question list screen shows a progress summary: "X of Y answered â€” Z correct"
- [x] Answered questions show their result status (green check / red X) in the list
- [x] Score and answer history persist across app restarts
- [x] Flutter analyzer passes with no errors

### US-004: Freemium Gate Enforcement
**Description:** As the system, I need to prevent users from accessing questions beyond the free limit unless they have unlocked the book so that the freemium model is enforced.

**Acceptance Criteria:**
- [x] Questions 1â€“10 per book are freely accessible to all authenticated users
- [x] Questions 11+ are locked for users who have not unlocked that book
- [x] Tapping a locked question shows a paywall/unlock prompt (see Freemium PRD for unlock flow)
- [x] Unlocked state is read from Supabase (`user_book_access` table managed by Freemium feature)
- [x] Flutter analyzer passes with no errors

### US-005: Retake Questions
**Description:** As a user, I want to retake questions I've already answered so that I can practice until I get them right.

**Acceptance Criteria:**
- [x] A "Retake" button or option is available on the question list screen
- [x] Retaking a question allows re-selecting and re-submitting an answer
- [x] The new answer overwrites the previous answer (upsert via StorageService.saveAnswer)
- [x] The score summary reflects the updated answers
- [x] Flutter analyzer passes with no errors

---

## Functional Requirements

- FR-1: Questions are stored in Supabase (`questions` table: id, book_id, chapter_id, question_text, option_a, option_b, option_c, option_d, correct_option [a|b|c|d], explanation, osce_tip [nullable], question_number)
- FR-2: Questions are fetched from Supabase on question list load, ordered by question_number
- FR-3: The free limit is exactly 10 questions per book (questions with question_number â‰¤ 10 are free)
- FR-4: User answers are upserted in Supabase so retakes overwrite previous answers (unique on user_id + question_id)
- FR-5: RLS on `questions` table: all authenticated users can read all questions (lock enforcement is done client-side based on freemium access, not row-level)
- FR-6: RLS on `user_question_answers`: users can only read/write their own rows
- FR-7: OSCE tip, if present, must be visually distinct from the explanation (separate card or styled block)

---

## Non-Goals

- Timed quiz mode â€” not in this version
- Question shuffle / random order â€” not in this version
- Multiple question formats (true/false, fill-in-the-blank) â€” MCQ only in this version
- Leaderboards or social comparison â€” not in this version
- Importing or generating questions from AI â€” not in this version

---

## Design Considerations

- Answer options: full-width tappable cards with letter prefix (A. B. C. D.)
- Correct answer highlight: green background (#E8F5E9 or similar)
- Incorrect answer highlight: red background (#FFEBEE or similar)
- OSCE Tip card: teal/cyan accent, "OSCE Tip" label in header
- Lock icon on locked questions: Material `Icons.lock_outline` with muted color

---

## Technical Considerations

- Questions are content data â€” consider seeding from JSON files rather than manual Supabase entry to keep content manageable
- `user_question_answers` schema: `id` (UUID PK), `user_id` (UUID FK), `book_id` (text), `question_id` (UUID FK), `selected_option` (text: a|b|c|d), `is_correct` (bool), `answered_at` (timestamp); unique on (user_id, question_id)
- Score calculation is done client-side from the fetched answer list (count of is_correct = true)
- The freemium gate reads from `user_book_access` (managed by Freemium feature); if the table row exists for (user_id, book_id), all questions are unlocked

---

## Success Metrics

- A user can complete a question and see the explanation within 3 taps
- Progress persists and is accurate after app restart
- Freemium gate is never bypassable on the client (locked questions are non-tappable, not just visually obscured)

---

## Open Questions

- Should the question bank be accessible from the book reader (per chapter) or only as a standalone section?
- Should there be a "quiz mode" that presents questions one at a time without showing the full list?
- Who populates the question content in Supabase â€” is there an admin tool, or will it be seeded from a JSON file?
