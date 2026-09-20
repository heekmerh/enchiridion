-- =============================================================================
-- Enchiridion — WIPE all application data (run just before going live)
-- =============================================================================
-- Purpose: empty a development database so no test rows (accounts, study
-- data, notes, payments, flags, entitlements, avatars) survive into
-- production. Schema (tables, policies, functions) is left untouched —
-- run 999_MASTER_init.sql afterwards only if the project itself is fresh.
--
-- >>> THIS DESTROYS DATA. Run it once, on the correct project, right before
-- >>> launch. There is no undo short of a Supabase point-in-time restore.
--
-- What it does, in order:
--   1. Deletes every auth user. All public tables reference auth.users(id)
--      on delete cascade, so profiles, study stats, reviews, answers, notes,
--      bookmarks, settings, history, entitlements, payment references,
--      tombstones, and flags disappear with them.
--   2. Prints row counts so you can confirm everything reads zero.
--
-- Storage is handled separately: Supabase blocks direct SQL deletes on
-- storage.objects (error 42501 from storage.protect_delete) to prevent
-- accidental loss, so after running this, empty the avatars bucket via the
-- Dashboard (Storage → avatars → delete all) or the Storage API with the
-- SERVICE_ROLE key, e.g.:
--   curl -X DELETE "$SUPABASE_URL/storage/v1/bucket/avatars/empty" \
--     -H "apikey: $SERVICE_ROLE_KEY" \
--     -H "Authorization: Bearer $SERVICE_ROLE_KEY"
-- (Endpoint name varies by Supabase version — the Dashboard route always
-- works. Deleted users' photos persist until the bucket is emptied.)
--
-- What it does NOT do:
--   - Drop schema. Tables, RLS policies, and functions remain. (That is
--     what you want: wipe data, keep structure.)
--   - Remove the Supabase project, its keys, Edge Functions, or secrets.
--     Rotate the anon/service keys after wiping if any dev device ever held
--     them, and set FLUTTERWAVE_SECRET_KEY to the LIVE secret.
--   - Touch Flutterwave. Test payments live in your Flutterwave dashboard,
--     not here.

begin;

-- 1. Users first: cascades wipe every public.* row that belongs to them.
delete from auth.users;

commit;

-- 2. Confirm: every count below must be 0. (The avatars count is expected
--    to stay non-zero until the bucket is emptied via the Dashboard/API —
--    see above.)
select 'auth.users' as tbl, count(*) from auth.users
union all select 'profiles', count(*) from public.profiles
union all select 'user_book_access', count(*) from public.user_book_access
union all select 'questions', count(*) from public.questions
union all select 'daily_study_stats', count(*) from public.daily_study_stats
union all select 'question_reviews', count(*) from public.question_reviews
union all select 'flagged_questions', count(*) from public.flagged_questions
union all select 'processed_payments', count(*) from public.processed_payments
union all select 'pinned_notes', count(*) from public.pinned_notes
union all select 'note_collections', count(*) from public.note_collections
union all select 'bookmarks', count(*) from public.bookmarks
union all select 'reading_notes', count(*) from public.reading_notes
union all select 'clips', count(*) from public.clips
union all select 'user_answers', count(*) from public.user_answers
union all select 'user_settings', count(*) from public.user_settings
union all select 'user_book_history', count(*) from public.user_book_history
union all select 'synced_deletions', count(*) from public.synced_deletions
union all select 'storage.objects/avatars', count(*) from storage.objects
  where bucket_id = 'avatars';
