-- =============================================================================
-- flagged_questions — user-reported issues with exam-prep / book questions
-- =============================================================================
-- Written by lib/services/question_flag_service.dart when a user taps
-- "Flag this question" on QuestionScreen. `scope` matches daily_study_stats
-- and question_reviews: 'exam_prep' (kStandaloneExamPrepScope) or a book id.
--
-- There is no in-app admin surface (and no outbound email/Slack integration
-- configured anywhere in this project) to notify maintainers automatically —
-- the "notification mechanism" here is the query at the bottom of this file,
-- run from the Supabase SQL editor (service role, bypasses RLS below by
-- design) whenever a maintainer wants to see what's been flagged. Wiring a
-- real push notification (e.g. a Supabase Edge Function on insert, posting
-- to Slack/email) is a reasonable follow-up once there's a real webhook/API
-- key to send it to.

create table if not exists public.flagged_questions (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  scope       text not null default 'exam_prep',
  question_id text not null,
  reason      text not null,
  status      text not null default 'open' check (status in ('open', 'reviewed', 'dismissed')),
  created_at  timestamptz not null default timezone('utc', now())
);

-- Powers the maintainer query below without a full-table scan.
create index if not exists idx_flagged_questions_open
  on public.flagged_questions(status, created_at)
  where status = 'open';

alter table public.flagged_questions enable row level security;

drop policy if exists "Users can read their own flags"   on public.flagged_questions;
drop policy if exists "Users can insert their own flags" on public.flagged_questions;

create policy "Users can read their own flags"
  on public.flagged_questions for select
  using (auth.uid() = user_id);

create policy "Users can insert their own flags"
  on public.flagged_questions for insert
  with check (auth.uid() = user_id);

-- No update/delete policy for regular users: only a maintainer, using the
-- service role, should move a flag from 'open' to 'reviewed'/'dismissed'.


-- =============================================================================
-- Maintainer query — run from the Supabase SQL editor (service role)
-- =============================================================================
-- Open flags, most recent first, with the reporting user's email for context:
--   select f.id, f.scope, f.question_id, f.reason, f.created_at, u.email
--   from public.flagged_questions f
--   join auth.users u on u.id = f.user_id
--   where f.status = 'open'
--   order by f.created_at desc;
--
-- Which questions get flagged most (helps spot a genuinely bad question
-- vs. one-off reports):
--   select scope, question_id, count(*) as flag_count
--   from public.flagged_questions
--   where status = 'open'
--   group by scope, question_id
--   order by flag_count desc;
--
-- Resolve a flag once addressed:
--   update public.flagged_questions set status = 'reviewed' where id = '<id>';
-- =============================================================================
