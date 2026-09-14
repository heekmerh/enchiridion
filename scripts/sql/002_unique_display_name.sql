-- =============================================================================
-- Unique, case-insensitive display names
-- =============================================================================
-- profiles.display_name had no uniqueness constraint at all — two users could
-- register with the identical name. The default '' (see profiles.display_name
-- in 000_init_database.sql) is deliberately excluded from the constraint so a
-- profile that hasn't set a name yet never collides with another blank one.
--
-- Run this BEFORE deploying the client changes that call
-- is_display_name_available — if any duplicate non-empty names already exist,
-- this index creation will fail and they must be resolved by hand first:
--   select lower(display_name), count(*)
--   from public.profiles
--   where display_name <> ''
--   group by lower(display_name)
--   having count(*) > 1;

create unique index if not exists idx_profiles_display_name_unique
  on public.profiles (lower(display_name))
  where display_name <> '';

-- Lets the sign-up form check availability before creating the account,
-- without widening the profiles SELECT policy (which deliberately only lets
-- a user read their own row — see the NOTE in 000_init_database.sql). This
-- function only ever returns a boolean, never row data, so it's safe to
-- expose to anon (a user checking a name has no session yet) and
-- authenticated alike.
create or replace function public.is_display_name_available(name text)
returns boolean
language sql
security definer
set search_path = public
as $$
  select not exists (
    select 1 from public.profiles
    where lower(display_name) = lower(name)
      and display_name <> ''
  );
$$;

grant execute on function public.is_display_name_available(text) to anon, authenticated;
