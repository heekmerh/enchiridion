create table if not exists public.daily_study_stats (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  scope text not null,
  study_date date not null,
  questions_answered integer not null default 0 check (questions_answered >= 0),
  correct_answers integer not null default 0 check (correct_answers >= 0),
  performance_points integer not null default 0 check (performance_points >= 0),
  updated_at timestamptz not null default timezone('utc', now()),
  created_at timestamptz not null default timezone('utc', now()),
  unique (user_id, scope, study_date)
);

alter table public.daily_study_stats enable row level security;

create policy if not exists "Users can read their own daily study stats"
on public.daily_study_stats
for select
using (auth.uid() = user_id);

create policy if not exists "Users can insert their own daily study stats"
on public.daily_study_stats
for insert
with check (auth.uid() = user_id);

create policy if not exists "Users can update their own daily study stats"
on public.daily_study_stats
for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

create or replace view public.leaderboard_points_totals as
select
  user_id,
  sum(performance_points) as total_points,
  sum(questions_answered) as total_answered,
  sum(correct_answers) as total_correct
from public.daily_study_stats
group by user_id;
