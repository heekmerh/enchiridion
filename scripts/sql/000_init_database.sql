-- =============================================================================
-- Enchiridion — Full Database Initialization
-- =============================================================================
-- Run this ONCE against a brand-new Supabase project to create every table,
-- index, RLS policy and storage bucket the Flutter app expects.
--
-- HOW TO RUN
--   1. Create a new project at https://supabase.com/dashboard
--   2. Open the project → SQL Editor → New query
--   3. Paste this entire file, THEN EDIT THE PASSWORD in section 6 → Run
--   4. Copy the new Project URL + anon key into
--      enchiridion/lib/config/supabase_config.dart
--   5. Auth → Providers → Email: turn "Confirm email" ON (the app's signup
--      flow assumes confirmation is required).
--
-- Section 6 seeds a pre-confirmed clinician account with a full subscription.
-- Its password is a placeholder in plain text in this file — change it before
-- running, and do not commit a real password here.
--
-- This script is idempotent — safe to re-run. It supersedes:
--   scripts/001_add_device_binding_columns.sql
--   scripts/quick_migration.sql
--
-- Derived from the app's actual Supabase calls:
--   profiles           auth_service.dart
--   user_book_access   access_service.dart
--   questions          question_list_screen.dart
--   daily_study_stats  study_stats_service.dart
--   avatars (bucket)   auth_service.dart :: uploadAvatar
-- =============================================================================

begin;

-- Needed for gen_random_uuid(). Present by default on Supabase, but a fresh
-- self-hosted Postgres may not have it.
create extension if not exists pgcrypto with schema extensions;


-- =============================================================================
-- 1. profiles
-- =============================================================================
-- One row per auth user. Written via upsert from AuthService.
-- Every non-key column MUST be nullable or defaulted: the app upserts partial
-- payloads (e.g. {id, avatar_url} alone), and a NOT NULL column with no default
-- would make the insert path fail.

create table if not exists public.profiles (
  id                  uuid primary key references auth.users(id) on delete cascade,
  display_name        text        default '',
  role                text        default 'student',   -- 'student' | 'clinician' | 'other'
  avatar_url          text,

  -- Phase 1 device-binding columns. Reserved: the migration created them but
  -- no current Dart code reads or writes them yet. Kept so the planned feature
  -- does not need another migration.
  email_confirmed     boolean     default false,
  device_id           text,
  bound_at            timestamptz,
  authorized_devices  jsonb       default '[]'::jsonb,
  last_device_switch  timestamptz,

  -- Exempts an account from the one-account-per-device gate entirely (see
  -- AuthProvider._checkDeviceGate). Not exposed anywhere in the app UI —
  -- only ever set by hand in SQL, for QA/test accounts that need to sign in
  -- from many devices/emulators. Defaults false for every real user.
  device_binding_exempt boolean   default false,

  created_at          timestamptz not null default timezone('utc', now())
);

-- Bring an existing/partial profiles table up to spec.
alter table public.profiles
  add column if not exists display_name       text        default '',
  add column if not exists role               text        default 'student',
  add column if not exists avatar_url         text,
  add column if not exists email_confirmed    boolean     default false,
  add column if not exists device_id          text,
  add column if not exists bound_at           timestamptz,
  add column if not exists authorized_devices jsonb       default '[]'::jsonb,
  add column if not exists last_device_switch timestamptz,
  add column if not exists device_binding_exempt boolean  default false,
  add column if not exists created_at         timestamptz not null default timezone('utc', now());

create index if not exists idx_profiles_email_confirmed    on public.profiles(email_confirmed);
create index if not exists idx_profiles_device_id          on public.profiles(device_id);
create index if not exists idx_profiles_last_device_switch on public.profiles(last_device_switch);

alter table public.profiles enable row level security;

drop policy if exists "Users can view own profile"                 on public.profiles;
drop policy if exists "Users can insert own profile"               on public.profiles;
drop policy if exists "Users can update own profile"               on public.profiles;
drop policy if exists "Users can delete own profile"               on public.profiles;
drop policy if exists "Authenticated users can view public metadata" on public.profiles;

create policy "Users can view own profile"
  on public.profiles for select
  using (auth.uid() = id);

create policy "Users can insert own profile"
  on public.profiles for insert
  with check (auth.uid() = id);

create policy "Users can update own profile"
  on public.profiles for update
  using (auth.uid() = id)
  with check (auth.uid() = id);

create policy "Users can delete own profile"
  on public.profiles for delete
  using (auth.uid() = id);

-- NOTE: the old scripts also created an "Authenticated users can view public
-- metadata" SELECT policy with USING (auth.role() = 'authenticated'). Because
-- RLS policies are OR-ed, that made EVERY profile readable by EVERY logged-in
-- user — names, avatars and device ids included. It is deliberately not
-- recreated here. Re-add it only if you build a leaderboard that needs to show
-- other users' names, and scope it to just those columns via a view.


-- =============================================================================
-- 1b. Auto-create a profile row on signup
-- =============================================================================
-- With "Confirm email" ON, AuthService.signUp() gets a null session and cannot
-- write the profile itself; it waits for ensureProfile() on first sign-in. This
-- trigger closes that gap so the row exists from the moment the user is created.
-- ON CONFLICT DO NOTHING keeps it compatible with the app's own upserts.

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_role text;
begin
  -- raw_user_meta_data is client-supplied (AuthService.signUp passes it
  -- straight through), so `role` cannot be trusted. Anything outside the three
  -- values register_screen.dart offers falls back to 'student'.
  --
  -- This is why profiles.role has no CHECK constraint: a CHECK would make the
  -- trigger raise, which aborts the auth.users insert and turns a junk role
  -- into a failed signup. Clamping here keeps the data clean without giving a
  -- client the ability to break registration.
  v_role := coalesce(new.raw_user_meta_data->>'role', 'student');
  if v_role not in ('student', 'clinician', 'other') then
    v_role := 'student';
  end if;

  insert into public.profiles (id, display_name, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'display_name', ''),
    v_role
  )
  on conflict (id) do nothing;

  -- Pre-provision the entitlement row, switched OFF. This exists so granting
  -- access is a one-checkbox edit in the Table Editor rather than a hand-
  -- written INSERT: find the user's row, tick `granted`, done.
  --
  -- It grants nothing while granted = false, because the SELECT policy on
  -- user_book_access hides ungranted rows from the client entirely.
  insert into public.user_book_access (user_id, book_id, access_type, granted)
  values (new.id, '*', 'subscription', false)
  on conflict (user_id, book_id) do nothing;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();


-- =============================================================================
-- 2. user_book_access — paid entitlements
-- =============================================================================
-- book_id is a catalog id ('paediatrics', 'internal-medicine', 'surgery',
-- 'obs-gynae', 'psychiatry', 'radiology', 'orthopedics', 'dermatology'),
-- or 'exam_prep_plab' for the PLAB exam-prep module,
-- or '*' for a full subscription (AccessService treats '*' as access to all).
--
-- The UNIQUE (user_id, book_id) constraint is REQUIRED: AccessService
-- .grantBookAccess() calls .upsert(), and PostgREST needs a unique constraint
-- to resolve ON CONFLICT. Without it the call fails at runtime.

create table if not exists public.user_book_access (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  book_id     text not null,
  access_type text not null default 'book',   -- 'book' | 'subscription'
  granted     boolean not null default false, -- the admin toggle; see below
  granted_at  timestamptz not null default timezone('utc', now()),
  expires_at  timestamptz,
  unique (user_id, book_id)
);

alter table public.user_book_access
  add column if not exists granted boolean not null default false;

create index if not exists idx_user_book_access_user_id on public.user_book_access(user_id);

-- Backfill a switched-off row for every pre-existing user, so the Table Editor
-- shows one row per registered account. New users get theirs from the
-- handle_new_user trigger in section 1b.
insert into public.user_book_access (user_id, book_id, access_type, granted)
select u.id, '*', 'subscription', false
from auth.users u
on conflict (user_id, book_id) do nothing;

alter table public.user_book_access enable row level security;

drop policy if exists "Users can read their own access"    on public.user_book_access;
drop policy if exists "Users can insert their own access"  on public.user_book_access;
drop policy if exists "Users can update their own access"  on public.user_book_access;
drop policy if exists "Users can read their granted access" on public.user_book_access;

-- THE TOGGLE. `and granted` is what makes a pre-provisioned row inert: the
-- client cannot see the row at all until an admin ticks the box, so
-- AccessService loads an empty entitlement set and falls back to the free
-- tier. Tick `granted` and the same row becomes visible, book_id '*' lands in
-- the cache, and the account has full access on its next sign-in.
create policy "Users can read their granted access"
  on public.user_book_access for select
  using (auth.uid() = user_id and granted);

-- No INSERT or UPDATE policy is defined on purpose. Rows are created by the
-- handle_new_user trigger (SECURITY DEFINER, so it bypasses RLS) and only ever
-- modified by an admin through the dashboard or the service_role key.
--
-- This closes a hole that existed while AccessService.grantBookAccess() was
-- reachable: with a client-side INSERT policy, anyone who extracted the anon
-- key from the APK could grant themselves book_id '*'. That method is dead
-- code today (nothing calls it), so removing the policies breaks nothing. If
-- it is ever revived it must move server-side — a payment webhook using
-- service_role, or a SECURITY DEFINER function that verifies a receipt.


-- =============================================================================
-- 3. questions — per-book question bank
-- =============================================================================
-- Read by question_list_screen.dart:
--   .from('questions').select().eq('book_id', ...).order('question_number')
--
-- Question.fromJson accepts EITHER an `options` jsonb map {"a": "...", ...}
-- OR flat option_a..option_e columns. Both are defined below so either seed
-- format works; populate one and leave the other null.
--
-- `id` is text (not uuid) because the model reads it as a plain String and the
-- bundled seed data uses human ids like 'exam-0001'. UUID strings also fit, and
-- the default below means a seed that omits `id` still works the way it would
-- against the original `uuid primary key default gen_random_uuid()` design.

create table if not exists public.questions (
  id              text primary key default gen_random_uuid()::text,
  book_id         text,
  chapter_id      text,
  question_text   text not null,
  options         jsonb,
  option_a        text,
  option_b        text,
  option_c        text,
  option_d        text,
  option_e        text,
  correct_option  text not null,
  explanation     text not null default '',
  osce_tip        text,
  question_number integer not null,
  topic           text,
  created_at      timestamptz not null default timezone('utc', now())
);

create index if not exists idx_questions_book_id on public.questions(book_id, question_number);

alter table public.questions enable row level security;

drop policy if exists "Signed-in users can read questions" on public.questions;

-- Content is world-readable to any signed-in user; the free-tier limit
-- (kFreeQuestionCount = 10) is enforced client-side, so RLS cannot meaningfully
-- restrict it without a server-side entitlement check. Change `authenticated`
-- to `anon, authenticated` if you ever let logged-out users browse questions.
create policy "Signed-in users can read questions"
  on public.questions for select
  to authenticated
  using (true);

-- DELIBERATELY LEFT EMPTY. This table is the *per-book* bank, keyed by
-- book_id. The 493 questions in scripts/content/question.json are general
-- exam-prep items with no book or chapter association, so they do not belong
-- here — they already ship as a bundled asset
-- (assets/data/exam_prep_questions.json) which the exam-prep module reads
-- locally, never from this table.
--
-- Until per-book question content exists, a book's Questions tab correctly
-- shows "No questions yet for this book." An empty count here is expected,
-- not a failed migration.


-- =============================================================================
-- 4. daily_study_stats — study tracking + leaderboard
-- =============================================================================
-- Written by StudyStatsService._sync() via upsert on (user_id, scope, study_date).
-- `scope` is 'exam_prep_plab' (kStandaloneExamPrepScope) or a book id.

create table if not exists public.daily_study_stats (
  id                 uuid primary key default gen_random_uuid(),
  user_id            uuid not null references auth.users(id) on delete cascade,
  scope              text not null,
  study_date         date not null,
  questions_answered integer not null default 0 check (questions_answered >= 0),
  correct_answers    integer not null default 0 check (correct_answers    >= 0),
  performance_points integer not null default 0 check (performance_points >= 0),
  updated_at         timestamptz not null default timezone('utc', now()),
  created_at         timestamptz not null default timezone('utc', now()),
  unique (user_id, scope, study_date)
);

create index if not exists idx_daily_study_stats_user on public.daily_study_stats(user_id, study_date desc);

alter table public.daily_study_stats enable row level security;

drop policy if exists "Users can read their own daily study stats"   on public.daily_study_stats;
drop policy if exists "Users can insert their own daily study stats" on public.daily_study_stats;
drop policy if exists "Users can update their own daily study stats" on public.daily_study_stats;

create policy "Users can read their own daily study stats"
  on public.daily_study_stats for select
  using (auth.uid() = user_id);

create policy "Users can insert their own daily study stats"
  on public.daily_study_stats for insert
  with check (auth.uid() = user_id);

create policy "Users can update their own daily study stats"
  on public.daily_study_stats for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- Leaderboard aggregate. security_invoker makes the view respect the caller's
-- RLS, so as written each user sees only their own totals. A real cross-user
-- leaderboard needs a SECURITY DEFINER function that returns display_name +
-- points only — do not widen the daily_study_stats select policy to do it.
create or replace view public.leaderboard_points_totals
with (security_invoker = true) as
select
  user_id,
  sum(performance_points) as total_points,
  sum(questions_answered) as total_answered,
  sum(correct_answers)    as total_correct
from public.daily_study_stats
group by user_id;


-- =============================================================================
-- 4b. question_reviews — spaced-repetition state for Exam Prep and book banks
-- =============================================================================
-- Written by StorageService.recordQuestionReview() via QuestionReviewSyncService
-- .push(), a best-effort upsert on every answer, mirroring the daily_study_stats
-- pattern above: the SharedPreferences copy on-device is authoritative, this
-- table exists so a second device can catch up, not as the source of truth.
--
-- `scope` matches daily_study_stats.scope: 'exam_prep_plab' (kStandaloneExamPrepScope)
-- or a book id. Column names match QuestionReview.toJson()/fromJson() exactly
-- so a fetched row can be deserialized directly without remapping keys.

create table if not exists public.question_reviews (
  user_id      uuid not null references auth.users(id) on delete cascade,
  question_id  text not null,
  scope        text not null default 'exam_prep_plab',
  stage        smallint not null default 0 check (stage >= 0),
  attempts     integer not null default 0 check (attempts >= 0),
  lapses       integer not null default 0 check (lapses >= 0),
  last_correct boolean,
  last_option  text,
  last_seen_at timestamptz not null default timezone('utc', now()),
  due_at       timestamptz not null default timezone('utc', now()),
  retired      boolean not null default false,
  primary key (user_id, question_id, scope)
);

-- Powers "what's due" queries without a full-table scan; partial on `not
-- retired` since a graduated question is never fetched by due date again.
create index if not exists idx_question_reviews_due
  on public.question_reviews(user_id, scope, due_at)
  where not retired;

alter table public.question_reviews enable row level security;

drop policy if exists "Users can read their own question reviews"   on public.question_reviews;
drop policy if exists "Users can insert their own question reviews" on public.question_reviews;
drop policy if exists "Users can update their own question reviews" on public.question_reviews;

create policy "Users can read their own question reviews"
  on public.question_reviews for select
  using (auth.uid() = user_id);

create policy "Users can insert their own question reviews"
  on public.question_reviews for insert
  with check (auth.uid() = user_id);

create policy "Users can update their own question reviews"
  on public.question_reviews for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- No delete policy: rows are only ever upserted or marked retired in place,
-- never removed, matching daily_study_stats.


-- =============================================================================
-- 5. Storage: avatars bucket
-- =============================================================================
-- AuthService.uploadAvatar() writes to '<user-id>/avatar.<ext>' with upsert,
-- then calls getPublicUrl() — so the bucket must be public for reads.

insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do update set public = true;

drop policy if exists "Avatar images are publicly readable" on storage.objects;
drop policy if exists "Users can upload their own avatar"   on storage.objects;
drop policy if exists "Users can update their own avatar"   on storage.objects;
drop policy if exists "Users can delete their own avatar"   on storage.objects;

create policy "Avatar images are publicly readable"
  on storage.objects for select
  using (bucket_id = 'avatars');

-- Writes are confined to a folder named after the caller's uid, matching the
-- '<user-id>/avatar.<ext>' path the app builds.
create policy "Users can upload their own avatar"
  on storage.objects for insert
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "Users can update their own avatar"
  on storage.objects for update
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "Users can delete their own avatar"
  on storage.objects for delete
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );


commit;


-- =============================================================================
-- 6. Seed: default clinician account with full access
-- =============================================================================
-- >>> CHANGE THE PASSWORD ON THE NEXT LINE BEFORE RUNNING THIS FILE. <<<
--
-- This block hand-writes a row into auth.users. That is normally Supabase's
-- job (Dashboard → Authentication → Users, or the Admin API with the
-- service_role key), and hand-written users are the usual cause of accounts
-- that can log in but cannot reset a password or refresh a token. This block
-- avoids that by also writing the matching auth.identities row and normalising
-- GoTrue's NOT NULL token columns — but it is still coupled to GoTrue's
-- internal schema, so re-verify it if you upgrade Supabase.
--
-- Runs in its own transaction, after the schema above is committed: if GoTrue's
-- layout has shifted, you lose the seed account, not the database.
--
-- Idempotent. Re-running will NOT reset the password of an existing account —
-- it only tops up the profile and entitlement rows. To change the password
-- later, use the Dashboard, or the app's own "forgot password" flow.

begin;

do $$
declare
  -- ---------------------------------------------------------------- EDIT ME
  v_email    text := 'clinician@enchiridion.app';
  v_password text := 'Test!2026';
  v_name     text := 'Enchiridion Clinician';
  -- -------------------------------------------------------------------------
  v_user_id         uuid;
  v_created         boolean := false;
  v_has_provider_id boolean;
  v_col             text;
begin
  -- pgcrypto's crypt()/gen_salt() live in the extensions schema on Supabase,
  -- but in public on some self-hosted installs. Cover both.
  set local search_path = public, extensions, auth;

  select id into v_user_id from auth.users where email = lower(v_email);

  if v_user_id is null then
    v_user_id := gen_random_uuid();
    v_created := true;

    -- NOTE: auth.users.role below is GoTrue's Postgres role ('authenticated').
    -- It is NOT the app's clinician/student role — that lives in
    -- raw_user_meta_data and is copied to public.profiles.role by the
    -- handle_new_user trigger defined in section 1b.
    insert into auth.users (
      instance_id,
      id,
      aud,
      role,
      email,
      encrypted_password,
      email_confirmed_at,
      raw_app_meta_data,
      raw_user_meta_data,
      created_at,
      updated_at
    ) values (
      '00000000-0000-0000-0000-000000000000',
      v_user_id,
      'authenticated',
      'authenticated',
      lower(v_email),
      crypt(v_password, gen_salt('bf')),
      timezone('utc', now()),          -- pre-confirmed: skips the email step
      '{"provider":"email","providers":["email"]}'::jsonb,
      jsonb_build_object('display_name', v_name, 'role', 'clinician'),
      timezone('utc', now()),
      timezone('utc', now())
    );

    -- Without a matching identity row the account logs in but breaks on
    -- password reset and identity linking. Newer GoTrue splits the old text
    -- `id` into `id uuid` + `provider_id text`; older releases do not.
    select exists (
      select 1 from information_schema.columns
      where table_schema = 'auth'
        and table_name   = 'identities'
        and column_name  = 'provider_id'
    ) into v_has_provider_id;

    if v_has_provider_id then
      insert into auth.identities (
        id, user_id, provider_id, identity_data, provider,
        last_sign_in_at, created_at, updated_at
      ) values (
        gen_random_uuid(), v_user_id, v_user_id::text,
        jsonb_build_object(
          'sub', v_user_id::text,
          'email', lower(v_email),
          'email_verified', true,
          'phone_verified', false
        ),
        'email',
        timezone('utc', now()), timezone('utc', now()), timezone('utc', now())
      );
    else
      insert into auth.identities (
        id, user_id, identity_data, provider,
        last_sign_in_at, created_at, updated_at
      ) values (
        v_user_id::text, v_user_id,
        jsonb_build_object(
          'sub', v_user_id::text,
          'email', lower(v_email),
          'email_verified', true,
          'phone_verified', false
        ),
        'email',
        timezone('utc', now()), timezone('utc', now()), timezone('utc', now())
      );
    end if;

    -- GoTrue treats several token columns as NOT NULL '' rather than NULL.
    -- A NULL here surfaces much later as a 500 on refresh or recovery. Only
    -- columns that actually exist in this release are touched.
    for v_col in
      select column_name
      from information_schema.columns
      where table_schema = 'auth'
        and table_name   = 'users'
        and is_nullable  = 'YES'
        and column_name in (
          'confirmation_token', 'recovery_token', 'email_change',
          'email_change_token_new', 'email_change_token_current',
          'phone_change', 'phone_change_token', 'reauthentication_token'
        )
    loop
      execute format(
        'update auth.users set %I = coalesce(%I, %L) where id = %L',
        v_col, v_col, '', v_user_id
      );
    end loop;
  end if;

  -- The handle_new_user trigger already created the profile; this makes the
  -- seed self-sufficient even if that trigger is ever removed.
  --
  -- device_binding_exempt = true: this is the shared QA/test account, so it
  -- is deliberately exempt from the one-account-per-device gate (see the
  -- column comment above) — otherwise testing on more than one device/
  -- emulator would trip the 30-day device-switch cooldown.
  insert into public.profiles (id, display_name, role, email_confirmed, device_binding_exempt)
  values (v_user_id, v_name, 'clinician', true, true)
  on conflict (id) do update
    set display_name          = coalesce(nullif(public.profiles.display_name, ''), excluded.display_name),
        role                  = 'clinician',
        email_confirmed       = true,
        device_binding_exempt = true;

  -- '*' is the wildcard AccessService checks for a full subscription: it
  -- unlocks all 8 books plus the standalone exam-prep module in one row.
  --
  -- This must be DO UPDATE, not DO NOTHING: the backfill in section 2 (and the
  -- signup trigger) will already have created this row with granted = false,
  -- and DO NOTHING would leave the seeded account switched off.
  insert into public.user_book_access (user_id, book_id, access_type, granted)
  values (v_user_id, '*', 'subscription', true)
  on conflict (user_id, book_id) do update
    set granted = true, access_type = 'subscription';

  if v_created then
    raise notice 'Created clinician account % (full access granted).', v_email;
    raise notice 'CHANGE THIS PASSWORD NOW if you did not edit it above.';
  else
    raise notice 'Account % already existed — password left unchanged, access topped up.', v_email;
  end if;
end;
$$;

commit;


-- =============================================================================
-- Verification — run separately after the script above succeeds
-- =============================================================================
-- Expect 4 rows: daily_study_stats, profiles, questions, user_book_access
--   select tablename, rowsecurity from pg_tables
--   where schemaname = 'public' order by tablename;
--
-- Expect ~15 policies across the 4 tables
--   select tablename, policyname, cmd from pg_policies
--   where schemaname = 'public' order by tablename, policyname;
--
-- Expect one row, public = true
--   select id, public from storage.buckets where id = 'avatars';
--
-- Expect one row: the seeded clinician, confirmed, with access_type
-- 'subscription' on book_id '*'. A null identity_provider means the
-- auth.identities insert did not land — fix that before relying on the account.
--   select u.email,
--          u.email_confirmed_at is not null as confirmed,
--          p.display_name, p.role,
--          a.book_id, a.access_type,
--          i.provider as identity_provider
--   from auth.users u
--   left join public.profiles p          on p.id = u.id
--   left join public.user_book_access a  on a.user_id = u.id
--   left join auth.identities i          on i.user_id = u.id
--   where u.email = 'clinician@enchiridion.app';
-- =============================================================================
