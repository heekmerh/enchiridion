-- =============================================================================
-- Real payments (Flutterwave) — anti-replay ledger + expiry enforcement
-- =============================================================================
-- Backs supabase/functions/verify-flutterwave-payment, the only thing
-- allowed to write user_book_access (see that table's own note in
-- 000_init_database.sql — no client-side INSERT/UPDATE policy exists there
-- on purpose). This migration adds:
--
--   1. processed_payments — an anti-replay ledger. Each Flutterwave
--      transaction_id may only ever grant access once; the Edge Function
--      inserts here (transaction_id is the primary key) before granting,
--      so replaying the same transaction_id back to the function a second
--      time cannot extend access further.
--
--   2. An RLS fix on user_book_access: the existing policy only checked
--      `granted`, never `expires_at`, so a row stayed visible (and access
--      stayed active) forever once granted — expiry was tracked but never
--      actually enforced. The Edge Function sets a real expires_at on every
--      purchase; this makes the client-visible row disappear once it
--      passes, which is what actually makes a purchased access window
--      time-limited. No scheduled job needed — this is evaluated live on
--      every read, the same way `granted` already was.

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

drop policy if exists "Users can read their granted access" on public.user_book_access;

create policy "Users can read their granted access"
  on public.user_book_access for select
  using (
    auth.uid() = user_id
    and granted
    and (expires_at is null or expires_at > timezone('utc', now()))
  );
