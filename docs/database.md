# Database

The Flutter app, the website and the billing service share **one Supabase
project**. Everything that creates or changes the schema lives in a single file:

**[`supabase/enchiridion_master.sql`](../supabase/enchiridion_master.sql)**

## Running it

1. Supabase Dashboard → **SQL Editor** → **New query**.
2. Paste the whole file and click **Run**.
3. Optional: to create the QA clinician account (Premium, exempt from the device
   gate), search for `v_password text := ''`, set a password, and run again.
   Leave it empty in production.

The file is idempotent: run it again after every change to it. It uses
`create ... if not exists`, `add column if not exists`, `create or replace`, and
seed rows that are only inserted when missing. Re-running never resets prices,
grants or accounts.

On a project that already ran the old scripts, the first run also migrates:

| Old object | What happens |
| --- | --- |
| `enchiridion_web` with FastAPI Users accounts (`partners.hashed_password`) | The whole schema is renamed to `legacy_enchiridion_web_<timestamp>` and a fresh `enchiridion_web` keyed by Supabase Auth users is created. Nothing is dropped. |
| `public.user_book_access` | Granted, unexpired rows become manual entitlements (`'*'` → `premium`); the table moves to the `legacy` schema. |
| `public.processed_payments`, `public.user_subscriptions` | Moved to `legacy`. |
| `public.user_id_for_email()` | Dropped (only the retired Edge Function used it). |

## What lives where

| Schema | Owner | Browser/app access |
| --- | --- | --- |
| `public` | Flutter app data (profiles, study stats, notes, sync tables, announcements), `communication_preferences`, and two RPCs: `get_my_entitlements()`, `get_my_subscription()` | Row-level security; owner-only rows |
| `enchiridion_web` | Website: referral partners, rewards, payouts, book orders, reviews, leads, `email_outbox` | None; backend only |
| `billing` | Plans, versioned prices, provider plan mappings, checkout sessions, subscriptions, transitions (audit), payments, payment events, entitlements, settlements | None; backend only. The app reads through the two `public` RPCs. |
| `legacy` | Archived pre-migration tables | None |

`auth.users` is the single identity. Triggers on it create the app profile,
communication preferences and the website partner row on sign-up, keep the
partner email/verification flag in sync, and queue the consent-gated Premium offer
email when an address is verified.

## Operating the billing data (SQL editor)

```sql
-- Comp or revoke Premium by hand (audited in billing.entitlements).
select billing.grant_manual_entitlement('someone@example.com', 'premium', null, 'Reviewer access');
select billing.grant_manual_entitlement('someone@example.com', 'premium', now() + interval '30 days', 'Trial');
select billing.revoke_manual_entitlement('someone@example.com', 'premium', 'Trial ended');

-- Change a website price: closes the current version and opens a new one; old rows are immutable.
select billing.set_plan_price('premium_monthly', 'NGN', 1500, 'Reason for the change');

-- Point Premium at the Play Console product/base plans if you named them differently.
update billing.provider_plan_mappings set product_id = 'your_product', base_plan_id = 'your-monthly-base-plan'
where provider = 'google_play' and plan_id = 'premium_monthly';

-- Make a website administrator.
update enchiridion_web.partners set is_superuser = true where email = 'you@example.com';

-- Why does this account have (or not have) Premium?
select s.provider, s.internal_state, s.provider_state, s.auto_renewing, s.access_expires_at, t.*
from billing.subscriptions s
join auth.users u on u.id = s.user_id
left join billing.subscription_transitions t on t.subscription_id = s.id
where u.email = 'someone@example.com'
order by t.created_at;

-- Provider events that failed and will be retried by the scheduled job.
select provider, event_type, attempts, last_error, received_at
from billing.payment_events where processing_status = 'failed' order by received_at desc;

-- Open question flags from the app, newest first.
select f.id, f.scope, f.question_id, f.reason, f.created_at, u.email
from public.flagged_questions f join auth.users u on u.id = f.user_id
where f.status = 'open' order by f.created_at desc;
update public.flagged_questions set status = 'reviewed' where id = '<id>';
```

## Before launch

[`supabase/wipe_application_data.sql`](../supabase/wipe_application_data.sql)
deletes every account and all app, website and billing data while keeping the
schema. Run it once, on the right project, just before going live, then empty the
`avatars` storage bucket from the dashboard.

## Local testing

`backend/tests/supabase_stub.sql` imitates the Supabase-managed pieces (`auth`,
`storage`, roles, default grants) so the master file can run on a plain
PostgreSQL 16:

```bash
createdb enchiridion_test
psql -d enchiridion_test -f backend/tests/supabase_stub.sql
psql -d enchiridion_test -f supabase/enchiridion_master.sql
TEST_DATABASE_URL=postgresql://USER@127.0.0.1:5432/enchiridion_test python -m pytest backend/tests -q
```
