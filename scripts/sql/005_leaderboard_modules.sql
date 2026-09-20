-- =============================================================================
-- Module-scoped leaderboard
-- =============================================================================
-- Companion to 003_leaderboard.sql's `get_leaderboard`: the same
-- cross-user aggregation filtered to one exam module's storage scope
-- (`exam_prep_plab`, `exam_prep_usmle`, … — see
-- `lib/models/exam_module.dart`). Powers the per-module tabs in
-- `LeaderboardScreen`; the unfiltered function remains the Overall board.
--
-- Same privacy shape as the original: SECURITY DEFINER, returns only
-- display_name + points, never user_id. Always includes the caller's own
-- row with their true rank even outside the limit.
--
-- Safe to run repeatedly (`create or replace`). Clients call this
-- opportunistically and fall back to `get_leaderboard` when it is missing,
-- so this migration can land before or after the app update.

create or replace function public.get_leaderboard_for_scope(
  result_limit integer default 20,
  scope_filter text default 'exam_prep_plab'
)
returns table (
  rank         bigint,
  display_name text,
  total_points bigint,
  is_you       boolean
)
language sql
security definer
set search_path = public
stable
as $$
  with totals as (
    select
      d.user_id,
      coalesce(nullif(p.display_name, ''), 'Anonymous') as display_name,
      sum(d.performance_points) as total_points
    from public.daily_study_stats d
    join public.profiles p on p.id = d.user_id
    where d.scope = scope_filter
    group by d.user_id, p.display_name
  ),
  ranked as (
    select
      row_number() over (order by total_points desc, display_name) as rank,
      display_name,
      total_points,
      (user_id = auth.uid()) as is_you
    from totals
  )
  select rank, display_name, total_points, is_you
  from ranked
  where rank <= greatest(result_limit, 1) or is_you
  order by rank;
$$;

grant execute on function public.get_leaderboard_for_scope(integer, text) to authenticated;
