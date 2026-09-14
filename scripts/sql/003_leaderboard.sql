-- =============================================================================
-- Real cross-user leaderboard
-- =============================================================================
-- 000_init_database.sql's leaderboard_points_totals view is `security_invoker`,
-- so it respects the caller's daily_study_stats RLS policy (own rows only) —
-- as its own comment there says, that means every user currently sees only
-- their own totals through it, not a real leaderboard. This is the
-- SECURITY DEFINER function that comment calls for: it aggregates across all
-- users but returns only display_name + points, never user_id or anything
-- else from profiles, so it's safe to expose broadly without widening
-- daily_study_stats' or profiles' own SELECT policies.
--
-- Always includes the caller's own row (with their true rank) even when it
-- falls outside the requested limit, so a leaderboard screen can show
-- "you're #47" without a second query.

create or replace function public.get_leaderboard(result_limit integer default 20)
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

grant execute on function public.get_leaderboard(integer) to authenticated;
