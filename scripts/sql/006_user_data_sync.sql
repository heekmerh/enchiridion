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

-- ── Pinned margin notes ──────────────────────────────────────────────────────

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

-- ── Note collections ─────────────────────────────────────────────────────────

create table if not exists public.note_collections (
  user_id    uuid not null references auth.users(id) on delete cascade,
  id         text not null,
  name       text not null default '',
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  primary key (user_id, id)
);

-- ── Bookmarks ────────────────────────────────────────────────────────────────

create table if not exists public.bookmarks (
  user_id         uuid not null references auth.users(id) on delete cascade,
  id              text not null,
  chapter_id      text not null default '',
  name            text not null default '',
  scroll_progress double precision not null default 0,
  created_at      timestamptz not null default timezone('utc', now()),
  primary key (user_id, id)
);

-- ── Free-text reading notes (one per book+chapter) ───────────────────────────

create table if not exists public.reading_notes (
  user_id    uuid not null references auth.users(id) on delete cascade,
  book_id    text not null,
  chapter_id text not null,
  content    text not null default '',
  updated_at timestamptz not null default timezone('utc', now()),
  primary key (user_id, book_id, chapter_id)
);

-- ── Text clips ───────────────────────────────────────────────────────────────

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

-- ── Per-question answers (powers "review what you've answered" lists) ───────

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

-- ── Reading settings (single row per user) ───────────────────────────────────

create table if not exists public.user_settings (
  user_id    uuid primary key references auth.users(id) on delete cascade,
  settings   jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default timezone('utc', now())
);

-- ── Recently opened books ────────────────────────────────────────────────────

create table if not exists public.user_book_history (
  user_id   uuid not null references auth.users(id) on delete cascade,
  book_id   text not null,
  opened_at timestamptz not null default timezone('utc', now()),
  primary key (user_id, book_id)
);

-- ── Deletion tombstones ──────────────────────────────────────────────────────

create table if not exists public.synced_deletions (
  user_id    uuid not null references auth.users(id) on delete cascade,
  entity     text not null,
  entity_id  text not null,
  deleted_at timestamptz not null default timezone('utc', now()),
  primary key (user_id, entity, entity_id)
);

-- ── RLS: owner-only everything ───────────────────────────────────────────────

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
