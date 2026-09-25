-- ===============================================================================
-- Enchiridion — MASTER database initialization (single file)
-- ===============================================================================
-- THE schema. There are no numbered migration files: while the app is in
-- development, every schema change is folded into this file, in dependency
-- order, so one paste provisions a project completely.
--
-- HOW TO RUN
--   1. Create a project at https://supabase.com/dashboard
--   2. Open the project → SQL Editor → New query
--   3. Paste this entire file, THEN EDIT THE PASSWORD in section 6 → Run
--   4. Copy the Project URL + anon key into
--      enchiridion/lib/config/supabase_config.dart
--   5. Auth → Providers → Email: turn "Confirm email" ON (the app's signup
--      flow assumes confirmation is required).
--
-- CONTENTS
--   1.  profiles (incl. device binding and terms acceptance)
--   1b. handle_new_user — profile + inert entitlement row on signup
--   2.  user_book_access — paid entitlements, expiry enforced in RLS
--   3.  questions
--   4.  daily_study_stats
--   5.  question_reviews (spaced repetition)
--   6.  avatars bucket + seed clinician account
--   7.  flagged_questions
--   8.  unique display names
--   9.  leaderboard (global and per-module)
--   10. payments — processed_payments anti-replay ledger
--   11. cross-device user data sync
--   12. user_subscriptions — auto-renewal mirror the app polls
--
-- Every section is idempotent — safe to re-run top to bottom. Adding a column
-- to an existing table needs BOTH the column in its create table and a
-- matching `alter table ... add column if not exists`, or a project that was
-- provisioned earlier never receives it.
--
-- Derived from the app's actual Supabase calls:
--   profiles            auth_service.dart
--   user_book_access    access_service.dart
--   user_subscriptions  subscription_service.dart
--   questions           question_list_screen.dart
--   daily_study_stats   study_stats_service.dart
--   avatars (bucket)    auth_service.dart :: uploadAvatar
--
-- >>> BEFORE GOING LIVE: edit the seed password in section 6 (search for
--     EDIT ME), then run 998_wipe_database.sql first on a used project so no
--     development rows survive.
-- ===============================================================================


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

  -- Which version of docs/legal/terms-and-conditions.md the user accepted at
  -- sign-up, and when. Stamped by handle_new_user from server time, not from
  -- the device clock, so the record stands as evidence of acceptance.
  terms_version       text,
  terms_accepted_at   timestamptz,

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
  add column if not exists terms_version      text,
  add column if not exists terms_accepted_at  timestamptz,
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
  v_terms_version text;
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

  v_terms_version :=
    nullif(left(coalesce(new.raw_user_meta_data->>'terms_version', ''), 32), '');

  insert into public.profiles (
    id, display_name, role, terms_version, terms_accepted_at
  )
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'display_name', ''),
    v_role,
    v_terms_version,
    case when v_terms_version is null then null else timezone('utc', now()) end
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
--
-- The expires_at clause is what makes a purchased window actually end: the
-- row disappears from the client the moment it passes. Evaluated live on
-- every read, so no scheduled job is needed.
create policy "Users can read their granted access"
  on public.user_book_access for select
  using (
    auth.uid() = user_id
    and granted
    and (expires_at is null or expires_at > timezone('utc', now()))
  );

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

-- ──────────────────────────────────────────────────────────────────────────────
-- Flagged questions
-- ──────────────────────────────────────────────────────────────────────────────

-- =============================================================================
-- flagged_questions — user-reported issues with exam-prep / book questions
-- =============================================================================
-- Written by lib/services/question_flag_service.dart when a user taps
-- "Flag this question" on QuestionScreen. `scope` matches daily_study_stats
-- and question_reviews: 'exam_prep_plab' (kStandaloneExamPrepScope) or a book id.
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
  scope       text not null default 'exam_prep_plab',
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

-- ──────────────────────────────────────────────────────────────────────────────
-- Unique display names
-- ──────────────────────────────────────────────────────────────────────────────

-- =============================================================================
-- Unique, case-insensitive display names
-- =============================================================================
-- profiles.display_name had no uniqueness constraint at all — two users could
-- register with the identical name. The default '' (see profiles.display_name
-- in section 1) is deliberately excluded from the constraint so a
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
-- a user read their own row — see the NOTE in section 1). This
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

-- ──────────────────────────────────────────────────────────────────────────────
-- Leaderboard
-- ──────────────────────────────────────────────────────────────────────────────

-- =============================================================================
-- Real cross-user leaderboard
-- =============================================================================
-- The leaderboard_points_totals view in section 4 is `security_invoker`,
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

-- ──────────────────────────────────────────────────────────────────────────────
-- Payments
-- ──────────────────────────────────────────────────────────────────────────────

-- =============================================================================
-- Real payments (Flutterwave) — anti-replay ledger + expiry enforcement
-- =============================================================================
-- Backs supabase/functions/verify-flutterwave-payment and
-- supabase/functions/flutterwave-webhook, the only things allowed to write
-- user_book_access (see section 2 — no client-side INSERT/UPDATE policy
-- exists there on purpose).
--
-- processed_payments is an anti-replay ledger. Each Flutterwave
-- transaction_id may only ever grant access once; the Edge Functions insert
-- here (transaction_id is the primary key) before granting, so replaying
-- the same transaction_id a second time cannot extend access further. It is
-- shared by both functions, which is also what stops the first charge of a
-- subscription being granted twice when the webhook and the app's own
-- verify call both arrive.

create table if not exists public.processed_payments (
  transaction_id text primary key,
  user_id        uuid not null references auth.users(id) on delete cascade,
  plan_id        text,
  book_id        text not null,
  amount         numeric not null,
  currency       text not null,
  processed_at   timestamptz not null default timezone('utc', now())
);

create index if not exists idx_processed_payments_user on public.processed_payments(user_id);

alter table public.processed_payments enable row level security;

drop policy if exists "Users can read their own processed payments" on public.processed_payments;

create policy "Users can read their own processed payments"
  on public.processed_payments for select
  using (auth.uid() = user_id);

-- No insert/update/delete policy: only the Edge Function (service_role)
-- writes here, exactly like user_book_access.

-- ──────────────────────────────────────────────────────────────────────────────
-- Per-module leaderboards
-- ──────────────────────────────────────────────────────────────────────────────

-- =============================================================================
-- Module-scoped leaderboard
-- =============================================================================
-- Companion to `get_leaderboard` above: the same
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

-- ──────────────────────────────────────────────────────────────────────────────
-- Cross-device user data sync
-- ──────────────────────────────────────────────────────────────────────────────

-- =============================================================================
-- Cross-device user data sync (notes, bookmarks, answers, settings, …)
-- =============================================================================
-- Backs lib/services/user_data_sync_service.dart. Local SharedPreferences
-- state stays authoritative in the app; these tables exist so a user who
-- signs in on a new device recovers everything.
--
-- Merge rule is last-write-wins per row (every row carries updated_at).
-- Deletions propagate as tombstones in synced_deletions: the client writes
-- one when deleting locally, uploads it, deletes the remote row, and
-- applies remotely-pulled tombstones to local storage. Tombstones older
-- than 90 days are purged client-side.
--
-- All tables are owner-only via RLS (auth.uid() = user_id), including
-- SELECT — unlike the leaderboard RPCs, nothing here is ever aggregated
-- across users.

begin;

-- ────────────────────────────────────────────────────────────────────────────── Pinned margin notes ──────────────────────────────────────────────────────

create table if not exists public.pinned_notes (
  user_id       uuid not null references auth.users(id) on delete cascade,
  id            text not null,
  book_id       text not null default '',
  chapter_id    text not null default '',
  anchor_id     text not null default '',
  side          text not null default 'left',
  content       text not null default '',
  collection_id text,
  created_at    timestamptz not null default timezone('utc', now()),
  updated_at    timestamptz not null default timezone('utc', now()),
  primary key (user_id, id)
);

create index if not exists idx_pinned_notes_user_updated
  on public.pinned_notes(user_id, updated_at desc);

-- ────────────────────────────────────────────────────────────────────────────── Note collections ─────────────────────────────────────────────────────────

create table if not exists public.note_collections (
  user_id    uuid not null references auth.users(id) on delete cascade,
  id         text not null,
  name       text not null default '',
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  primary key (user_id, id)
);

-- ────────────────────────────────────────────────────────────────────────────── Bookmarks ────────────────────────────────────────────────────────────────

create table if not exists public.bookmarks (
  user_id         uuid not null references auth.users(id) on delete cascade,
  id              text not null,
  chapter_id      text not null default '',
  name            text not null default '',
  scroll_progress double precision not null default 0,
  created_at      timestamptz not null default timezone('utc', now()),
  primary key (user_id, id)
);

-- ────────────────────────────────────────────────────────────────────────────── Free-text reading notes (one per book+chapter) ───────────────────────────

create table if not exists public.reading_notes (
  user_id    uuid not null references auth.users(id) on delete cascade,
  book_id    text not null,
  chapter_id text not null,
  content    text not null default '',
  updated_at timestamptz not null default timezone('utc', now()),
  primary key (user_id, book_id, chapter_id)
);

-- ────────────────────────────────────────────────────────────────────────────── Text clips ───────────────────────────────────────────────────────────────

create table if not exists public.clips (
  user_id    uuid not null references auth.users(id) on delete cascade,
  id         text not null,
  book_id    text not null default '',
  chapter_id text not null default '',
  section_id text not null default '',
  content    text not null default '',
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  primary key (user_id, id)
);

create index if not exists idx_clips_user_updated
  on public.clips(user_id, updated_at desc);

-- ────────────────────────────────────────────────────────────────────────────── Per-question answers (powers "review what you've answered" lists) ───────

create table if not exists public.user_answers (
  user_id         uuid not null references auth.users(id) on delete cascade,
  scope           text not null,
  question_id     text not null,
  selected_option text not null default '',
  is_correct      boolean not null default false,
  answered_at     timestamptz not null default timezone('utc', now()),
  primary key (user_id, scope, question_id)
);

create index if not exists idx_user_answers_user_scope
  on public.user_answers(user_id, scope);

-- ────────────────────────────────────────────────────────────────────────────── Reading settings (single row per user) ───────────────────────────────────

create table if not exists public.user_settings (
  user_id    uuid primary key references auth.users(id) on delete cascade,
  settings   jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default timezone('utc', now())
);

-- ────────────────────────────────────────────────────────────────────────────── Recently opened books ────────────────────────────────────────────────────

create table if not exists public.user_book_history (
  user_id   uuid not null references auth.users(id) on delete cascade,
  book_id   text not null,
  opened_at timestamptz not null default timezone('utc', now()),
  primary key (user_id, book_id)
);

-- ────────────────────────────────────────────────────────────────────────────── Deletion tombstones ──────────────────────────────────────────────────────

create table if not exists public.synced_deletions (
  user_id    uuid not null references auth.users(id) on delete cascade,
  entity     text not null,
  entity_id  text not null,
  deleted_at timestamptz not null default timezone('utc', now()),
  primary key (user_id, entity, entity_id)
);

-- ────────────────────────────────────────────────────────────────────────────── RLS: owner-only everything ───────────────────────────────────────────────

alter table public.pinned_notes     enable row level security;
alter table public.note_collections enable row level security;
alter table public.bookmarks        enable row level security;
alter table public.reading_notes    enable row level security;
alter table public.clips            enable row level security;
alter table public.user_answers     enable row level security;
alter table public.user_settings    enable row level security;
alter table public.user_book_history enable row level security;
alter table public.synced_deletions enable row level security;

drop policy if exists "Users manage own pinned notes"      on public.pinned_notes;
drop policy if exists "Users manage own note collections"  on public.note_collections;
drop policy if exists "Users manage own bookmarks"         on public.bookmarks;
drop policy if exists "Users manage own reading notes"     on public.reading_notes;
drop policy if exists "Users manage own clips"             on public.clips;
drop policy if exists "Users manage own answers"           on public.user_answers;
drop policy if exists "Users manage own settings"          on public.user_settings;
drop policy if exists "Users manage own book history"      on public.user_book_history;
drop policy if exists "Users manage own deletions"         on public.synced_deletions;

-- One policy per table covering all commands (select/insert/update/delete
-- restricted to the caller's own rows). Deletion must be allowed: tombstone
-- propagation deletes the remote row after uploading the tombstone.
create policy "Users manage own pinned notes"
  on public.pinned_notes for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "Users manage own note collections"
  on public.note_collections for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "Users manage own bookmarks"
  on public.bookmarks for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "Users manage own reading notes"
  on public.reading_notes for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "Users manage own clips"
  on public.clips for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "Users manage own answers"
  on public.user_answers for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "Users manage own settings"
  on public.user_settings for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "Users manage own book history"
  on public.user_book_history for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "Users manage own deletions"
  on public.synced_deletions for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

commit;


-- ──────────────────────────────────────────────────────────────────────────────
-- Auto-renewing subscriptions
-- ──────────────────────────────────────────────────────────────────────────────

-- =============================================================================
-- Auto-renewing subscriptions (Flutterwave payment plans)
-- =============================================================================
-- Checkout and renewal both happen on the website; Flutterwave bills the
-- card on its own schedule and tells us by webhook. This table is the
-- mirror of that state the app can actually read: the app never talks to
-- Flutterwave, it polls here (lib/services/subscription_service.dart) to
-- show the renewal date and the cancel entry point, exactly as it polls
-- user_book_access for the entitlement itself.
--
-- Entitlement still lives in user_book_access — this table only explains
-- *why* it is there and *when* it next extends. Keeping them separate means
-- a subscription that stops renewing simply stops extending expires_at, and
-- the existing expiry enforcement in section 2's RLS does the rest with no
-- scheduled job.
--
-- Written only by the flutterwave-webhook Edge Function (service_role); no
-- client INSERT/UPDATE policy exists on purpose, same as user_book_access.

create table if not exists public.user_subscriptions (
  user_id              uuid        not null references auth.users(id) on delete cascade,
  scope                text        not null default '*',
  plan_id              text        not null,
  flw_plan_id          text,
  flw_subscription_id  text,
  customer_email       text,
  status               text        not null default 'active',
  auto_renew           boolean     not null default true,
  amount               numeric,
  currency             text        not null default 'NGN',
  current_period_end   timestamptz,
  next_billing_at      timestamptz,
  last_payment_at      timestamptz,
  cancelled_at         timestamptz,
  created_at           timestamptz not null default timezone('utc', now()),
  updated_at           timestamptz not null default timezone('utc', now()),
  primary key (user_id, scope)
);

create index if not exists idx_user_subscriptions_flw_sub
  on public.user_subscriptions(flw_subscription_id);

create index if not exists idx_user_subscriptions_email
  on public.user_subscriptions(customer_email);

alter table public.user_subscriptions enable row level security;

drop policy if exists "Users can read their own subscription" on public.user_subscriptions;

create policy "Users can read their own subscription"
  on public.user_subscriptions for select
  using (auth.uid() = user_id);

-- Recurring charges arrive as webhooks, not as a call from the signed-in
-- client, so the grant path cannot authenticate the user the way
-- verify-flutterwave-payment does. The webhook resolves the payer by the
-- email Flutterwave billed; this lets it do that without exposing auth.users
-- to anyone else (SECURITY DEFINER, service_role only via the revoke below).
create or replace function public.user_id_for_email(p_email text)
returns uuid
language sql
security definer
set search_path = public
as $$
  select id from auth.users where lower(email) = lower(p_email) limit 1;
$$;

revoke all on function public.user_id_for_email(text) from public, anon, authenticated;
