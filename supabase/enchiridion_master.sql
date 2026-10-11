-- Enchiridion master schema for the shared Supabase project (Flutter app, website, billing); idempotent, see docs/database.md.

begin;

create extension if not exists pgcrypto with schema extensions;

create schema if not exists legacy;
revoke all on schema legacy from public, anon, authenticated;

-- The FastAPI Users website schema keyed accounts by its own ids; it is set aside rather than dropped so nothing is lost.
do $$
declare
  v_archive text := 'legacy_enchiridion_web_' || to_char(clock_timestamp(), 'YYYYMMDDHH24MISS');
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'enchiridion_web' and table_name = 'partners' and column_name = 'hashed_password'
  ) then
    execute format('alter schema enchiridion_web rename to %I', v_archive);
    execute format('revoke all on schema %I from public, anon, authenticated', v_archive);
    raise notice 'Archived the FastAPI Users website schema as %', v_archive;
  end if;
end $$;


create table if not exists public.profiles (
  id                    uuid primary key references auth.users(id) on delete cascade,
  display_name          text        default '',
  role                  text        default 'student',
  avatar_url            text,
  email_confirmed       boolean     default false,
  device_id             text,
  bound_at              timestamptz,
  authorized_devices    jsonb       default '[]'::jsonb,
  last_device_switch    timestamptz,
  device_binding_exempt boolean     default false,
  terms_version         text,
  terms_accepted_at     timestamptz,
  created_at            timestamptz not null default timezone('utc', now())
);

alter table public.profiles
  add column if not exists display_name          text        default '',
  add column if not exists role                  text        default 'student',
  add column if not exists avatar_url            text,
  add column if not exists email_confirmed       boolean     default false,
  add column if not exists device_id             text,
  add column if not exists bound_at              timestamptz,
  add column if not exists authorized_devices    jsonb       default '[]'::jsonb,
  add column if not exists last_device_switch    timestamptz,
  add column if not exists device_binding_exempt boolean     default false,
  add column if not exists terms_version         text,
  add column if not exists terms_accepted_at     timestamptz,
  add column if not exists created_at            timestamptz not null default timezone('utc', now());

create index if not exists idx_profiles_email_confirmed    on public.profiles(email_confirmed);
create index if not exists idx_profiles_device_id          on public.profiles(device_id);
create index if not exists idx_profiles_last_device_switch on public.profiles(last_device_switch);

alter table public.profiles enable row level security;

drop policy if exists "Users can view own profile"                   on public.profiles;
drop policy if exists "Users can insert own profile"                 on public.profiles;
drop policy if exists "Users can update own profile"                 on public.profiles;
drop policy if exists "Users can delete own profile"                 on public.profiles;
drop policy if exists "Authenticated users can view public metadata" on public.profiles;

create policy "Users can view own profile"
  on public.profiles for select using (auth.uid() = id);
create policy "Users can insert own profile"
  on public.profiles for insert with check (auth.uid() = id);
create policy "Users can update own profile"
  on public.profiles for update using (auth.uid() = id) with check (auth.uid() = id);
create policy "Users can delete own profile"
  on public.profiles for delete using (auth.uid() = id);

create unique index if not exists idx_profiles_display_name_unique
  on public.profiles (lower(display_name))
  where display_name <> '';

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

-- Google sign-ups carry no signup metadata, so acceptance is stamped here with server time, once, like the email flow.
create or replace function public.accept_terms(p_version text)
returns void
language sql
security definer
set search_path = ''
as $$
  update public.profiles
  set terms_version = left(trim(p_version), 32), terms_accepted_at = timezone('utc', now())
  where id = auth.uid() and terms_version is null and coalesce(trim(p_version), '') <> '';
$$;

revoke all on function public.accept_terms(text) from public, anon;
grant execute on function public.accept_terms(text) to authenticated;


create table if not exists public.communication_preferences (
  user_id                     uuid primary key references auth.users(id) on delete cascade,
  signup_source               text        not null default 'unknown',
  signup_region               text        not null default '',
  marketing_opt_in            boolean     not null default false,
  marketing_consent_source    text,
  marketing_consent_region    text,
  marketing_consent_at        timestamptz,
  marketing_unsubscribed_at   timestamptz,
  -- Security and billing notices stay independent of marketing consent, so unsubscribing never silences them.
  transactional_email_enabled boolean     not null default true,
  unsubscribe_token           uuid        not null default gen_random_uuid() unique,
  updated_at                  timestamptz not null default timezone('utc', now())
);

alter table public.communication_preferences enable row level security;

drop policy if exists "Users can read their own communication preferences" on public.communication_preferences;
create policy "Users can read their own communication preferences"
  on public.communication_preferences for select using (auth.uid() = user_id);

create table if not exists public.communication_consent_events (
  id          bigint generated always as identity primary key,
  user_id     uuid        not null references auth.users(id) on delete cascade,
  channel     text        not null default 'marketing_email',
  granted     boolean     not null,
  source      text        not null,
  region      text        not null default '',
  occurred_at timestamptz not null default timezone('utc', now())
);

create index if not exists idx_consent_events_user on public.communication_consent_events(user_id, occurred_at desc);

alter table public.communication_consent_events enable row level security;
revoke all on public.communication_consent_events from anon, authenticated;


create schema if not exists enchiridion_web;
revoke all on schema enchiridion_web from public, anon, authenticated;

create table if not exists enchiridion_web.partners (
  id                     uuid primary key references auth.users(id) on delete cascade,
  email                  text not null unique check (email = lower(trim(email))),
  name                   text not null default '',
  referral_code          text not null unique check (referral_code = lower(trim(referral_code))),
  referred_by            text references enchiridion_web.partners(referral_code) on update cascade on delete set null,
  date_joined            timestamptz not null default now(),
  is_active              boolean not null default true,
  is_superuser           boolean not null default false,
  is_verified            boolean not null default false,
  guest_payments_claimed boolean not null default false,
  state                  text not null default '',
  country                text not null default '',
  profession             text not null default '',
  phone                  text not null default '',
  institution            text not null default '',
  bank_name              text not null default '',
  account_name           text not null default '',
  account_number         text not null default '',
  points                 numeric(16,2) not null default 0 check (points >= 0),
  lifetime_earnings      numeric(16,2) not null default 0 check (lifetime_earnings >= 0),
  total_referrals        integer not null default 0 check (total_referrals >= 0),
  payout_status          text not null default 'PENDING',
  last_payout_amount     numeric(16,2) not null default 0,
  check (referred_by is null or referred_by <> referral_code)
);

alter table enchiridion_web.partners
  add column if not exists guest_payments_claimed boolean not null default false;

create index if not exists partners_referrer_idx on enchiridion_web.partners(referred_by);

create table if not exists enchiridion_web.onboarding (
  user_id            uuid primary key references enchiridion_web.partners(id) on delete cascade,
  is_partner         boolean not null default false,
  is_distributor     boolean not null default false,
  has_purchased_book boolean not null default false,
  last_updated       timestamptz not null default now()
);

create table if not exists enchiridion_web.milestones (
  id             uuid primary key default gen_random_uuid(),
  partner_id     uuid not null references enchiridion_web.partners(id) on delete cascade,
  referee        text not null,
  milestone_type text not null,
  points         numeric(16,2) not null check (points >= 0),
  created_at     timestamptz not null default now(),
  unique (partner_id, referee, milestone_type)
);
create unique index if not exists milestones_purchase_once on enchiridion_web.milestones(referee)
  where milestone_type = 'book_purchase';
create index if not exists milestones_created_idx on enchiridion_web.milestones(created_at desc);

create table if not exists enchiridion_web.payouts (
  id         uuid primary key default gen_random_uuid(),
  partner_id uuid not null references enchiridion_web.partners(id) on delete restrict,
  amount     numeric(16,2) not null check (amount > 0),
  reverted   boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists payouts_partner_idx on enchiridion_web.payouts(partner_id, created_at desc);

create table if not exists enchiridion_web.activities (
  id            uuid primary key default gen_random_uuid(),
  partner_id    uuid references enchiridion_web.partners(id) on delete set null,
  ref_code      text not null default '',
  activity_type text not null,
  points        numeric(16,2) not null default 0,
  details       jsonb not null default '{}',
  payout_status text not null default 'PENDING',
  payout_id     uuid references enchiridion_web.payouts(id),
  created_at    timestamptz not null default now()
);
create index if not exists activities_partner_idx on enchiridion_web.activities(partner_id, created_at desc);
create index if not exists activities_created_idx on enchiridion_web.activities(created_at);

create table if not exists enchiridion_web.leads (
  id         uuid primary key default gen_random_uuid(),
  kind       text not null check (kind in ('sample', 'newsletter', 'distributor')),
  email      text,
  name       text not null default '',
  phone      text not null default '',
  whatsapp   text not null default '',
  location   text not null default '',
  ref_code   text not null default '',
  details    jsonb not null default '{}',
  created_at timestamptz not null default now()
);
create index if not exists leads_kind_idx on enchiridion_web.leads(kind, created_at desc);

create table if not exists enchiridion_web.shipping_rates (
  name   text primary key,
  cost   numeric(16,2) not null check (cost >= 0),
  is_hub boolean not null default false
);

create table if not exists enchiridion_web.purchase_orders (
  tx_ref     text primary key,
  email      text not null,
  amount     numeric(16,2) not null check (amount > 0),
  currency   text not null default 'NGN',
  quantity   integer not null check (quantity between 1 and 100),
  state      text not null default '',
  metadata   jsonb not null default '{}',
  created_at timestamptz not null default now()
);

create table if not exists enchiridion_web.payments (
  reference      text primary key,
  transaction_id text not null unique,
  email          text not null,
  amount         numeric(16,2) not null check (amount > 0),
  currency       text not null,
  metadata       jsonb not null default '{}',
  created_at     timestamptz not null default now()
);
create index if not exists payments_email_idx on enchiridion_web.payments(email);

create table if not exists enchiridion_web.broadcasts (
  id         uuid primary key default gen_random_uuid(),
  kind       text not null,
  username   text not null,
  city       text not null default '',
  body       text not null,
  created_at timestamptz not null default now()
);

create table if not exists enchiridion_web.audit_logs (
  id         uuid primary key default gen_random_uuid(),
  actor_id   uuid references enchiridion_web.partners(id) on delete set null,
  action     text not null,
  details    jsonb not null default '{}',
  created_at timestamptz not null default now()
);

create table if not exists enchiridion_web.reviews (
  id           uuid primary key default gen_random_uuid(),
  name         text not null,
  job_title    text not null,
  organization text not null default '',
  rating       integer not null check (rating between 1 and 5),
  text         text not null,
  status       text not null default 'pending' check (status in ('pending', 'approved', 'rejected')),
  created_at   timestamptz not null default now(),
  approved_at  timestamptz
);
create index if not exists reviews_status_idx on enchiridion_web.reviews(status, created_at desc);

create table if not exists enchiridion_web.email_outbox (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid references auth.users(id) on delete cascade,
  kind        text not null,
  recipient   text not null,
  dedupe_key  text not null unique,
  payload     jsonb not null default '{}',
  status      text not null default 'pending' check (status in ('pending', 'sent', 'failed', 'skipped')),
  attempts    integer not null default 0,
  last_error  text,
  created_at  timestamptz not null default now(),
  sent_at     timestamptz
);
create index if not exists email_outbox_pending_idx on enchiridion_web.email_outbox(created_at) where status = 'pending';

insert into enchiridion_web.shipping_rates(name, cost, is_hub) values
('Abia',4500,false),('Adamawa',5000,false),('Akwa Ibom',4500,false),
('Anambra',4000,false),('Bauchi',4500,false),('Bayelsa',5000,false),
('Benue',4200,true),('Borno',5500,false),('Cross River',4500,false),
('Delta',4000,false),('Ebonyi',4500,false),('Edo',4000,false),
('Ekiti',3500,false),('Enugu',4000,false),('Gombe',4500,false),
('Imo',4200,false),('Jigawa',4500,false),('Kaduna',3500,true),
('Kano',3500,true),('Katsina',4000,false),('Kebbi',4500,false),
('Kogi',3500,false),('Kwara',3500,false),('Lagos',3000,true),
('Nasarawa',3500,false),('Niger',3500,false),('Ogun',3000,true),
('Ondo',3500,false),('Osun',3000,false),('Oyo',3000,false),
('Plateau',4000,false),('Rivers',4500,true),('Sokoto',4500,false),
('Taraba',5000,false),('Yobe',5000,false),('Zamfara',4500,false),
('Federal Capital Territory (Abuja)',3500,true)
on conflict (name) do nothing;

do $$
declare
  v_table text;
begin
  foreach v_table in array array['partners', 'onboarding', 'milestones', 'payouts', 'activities', 'leads',
    'shipping_rates', 'purchase_orders', 'payments', 'broadcasts', 'audit_logs', 'reviews', 'email_outbox']
  loop
    execute format('alter table enchiridion_web.%I enable row level security', v_table);
    execute format('revoke all on table enchiridion_web.%I from anon, authenticated', v_table);
  end loop;
end $$;


create schema if not exists billing;
revoke all on schema billing from public, anon, authenticated;

create table if not exists billing.plans (
  id                  text primary key check (id ~ '^[a-z0-9_]+$'),
  name                text not null,
  description         text not null default '',
  billing_interval    text not null check (billing_interval in ('month', 'year')),
  interval_count      integer not null default 1 check (interval_count > 0),
  entitlement_feature text not null default 'premium',
  benefits            jsonb not null default '[]'::jsonb,
  display_order       integer not null default 0,
  is_active           boolean not null default true,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);

create table if not exists billing.plan_prices (
  id             uuid primary key default gen_random_uuid(),
  plan_id        text not null references billing.plans(id),
  currency       text not null check (currency ~ '^[A-Z]{3}$'),
  amount         numeric(12,2) not null check (amount > 0),
  tax_inclusive  boolean not null default true,
  effective_from timestamptz not null default now(),
  effective_to   timestamptz,
  change_reason  text not null default '',
  created_by     text not null default current_user,
  created_at     timestamptz not null default now(),
  check (effective_to is null or effective_to > effective_from)
);
create unique index if not exists plan_prices_one_current
  on billing.plan_prices(plan_id, currency) where effective_to is null;

create or replace function billing.protect_plan_price()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'DELETE' then
    raise exception 'Plan prices are versioned; close a price with billing.set_plan_price instead of deleting it';
  end if;
  if new.plan_id <> old.plan_id or new.currency <> old.currency or new.amount <> old.amount
     or new.tax_inclusive <> old.tax_inclusive or new.effective_from <> old.effective_from
     or (old.effective_to is not null and new.effective_to is distinct from old.effective_to) then
    raise exception 'Plan price % is immutable; publish a new version with billing.set_plan_price', old.id;
  end if;
  return new;
end;
$$;

drop trigger if exists plan_prices_immutable on billing.plan_prices;
create trigger plan_prices_immutable
  before update or delete on billing.plan_prices
  for each row execute function billing.protect_plan_price();

create or replace function billing.current_plan_price(p_plan_id text, p_currency text default 'NGN')
returns billing.plan_prices
language sql
stable
as $$
  select * from billing.plan_prices
  where plan_id = p_plan_id and currency = p_currency
    and effective_from <= now() and (effective_to is null or effective_to > now())
  order by effective_from desc
  limit 1;
$$;

create or replace function billing.set_plan_price(p_plan_id text, p_currency text, p_amount numeric, p_reason text)
returns uuid
language plpgsql
as $$
declare
  v_now timestamptz := clock_timestamp();
  v_id  uuid;
begin
  if coalesce(trim(p_reason), '') = '' then
    raise exception 'A reason is required for every price change';
  end if;
  update billing.plan_prices set effective_to = v_now
  where plan_id = p_plan_id and currency = p_currency and effective_to is null;
  insert into billing.plan_prices (plan_id, currency, amount, effective_from, change_reason)
  values (p_plan_id, p_currency, p_amount, v_now, p_reason)
  returning id into v_id;
  return v_id;
end;
$$;

create table if not exists billing.provider_plan_mappings (
  id               uuid primary key default gen_random_uuid(),
  plan_id          text not null references billing.plans(id),
  provider         text not null check (provider in ('flutterwave', 'google_play')),
  product_id       text,
  base_plan_id     text,
  provider_plan_id text,
  plan_price_id    uuid references billing.plan_prices(id),
  is_active        boolean not null default true,
  created_at       timestamptz not null default now(),
  check (provider <> 'google_play' or (product_id is not null and base_plan_id is not null)),
  check (provider <> 'flutterwave' or (provider_plan_id is not null and plan_price_id is not null))
);
create unique index if not exists provider_plan_mappings_google
  on billing.provider_plan_mappings(product_id, base_plan_id) where provider = 'google_play';
create unique index if not exists provider_plan_mappings_flutterwave_plan
  on billing.provider_plan_mappings(provider_plan_id) where provider = 'flutterwave';
create unique index if not exists provider_plan_mappings_flutterwave_price
  on billing.provider_plan_mappings(plan_price_id) where provider = 'flutterwave' and is_active;

create table if not exists billing.checkout_sessions (
  reference        text primary key,
  user_id          uuid not null references auth.users(id) on delete cascade,
  plan_id          text not null references billing.plans(id),
  plan_price_id    uuid not null references billing.plan_prices(id),
  amount           numeric(12,2) not null check (amount > 0),
  currency         text not null,
  customer_email   text not null,
  auto_renew       boolean not null,
  provider         text not null default 'flutterwave' check (provider = 'flutterwave'),
  provider_plan_id text,
  status           text not null default 'pending' check (status in ('pending', 'paid', 'failed', 'abandoned')),
  checkout_url     text,
  failure_reason   text,
  created_at       timestamptz not null default now(),
  expires_at       timestamptz not null default now() + interval '1 day',
  completed_at     timestamptz
);
create index if not exists checkout_sessions_user on billing.checkout_sessions(user_id, created_at desc);
create index if not exists checkout_sessions_pending on billing.checkout_sessions(created_at) where status = 'pending';

create or replace function billing.protect_checkout_session()
returns trigger
language plpgsql
as $$
begin
  if new.reference <> old.reference or new.user_id <> old.user_id or new.plan_id <> old.plan_id
     or new.plan_price_id <> old.plan_price_id or new.amount <> old.amount or new.currency <> old.currency
     or new.customer_email <> old.customer_email or new.auto_renew <> old.auto_renew then
    raise exception 'Checkout session % is immutable', old.reference;
  end if;
  return new;
end;
$$;

drop trigger if exists checkout_sessions_immutable on billing.checkout_sessions;
create trigger checkout_sessions_immutable
  before update on billing.checkout_sessions
  for each row execute function billing.protect_checkout_session();

create table if not exists billing.subscriptions (
  id                        uuid primary key default gen_random_uuid(),
  user_id                   uuid references auth.users(id) on delete set null,
  plan_id                   text not null references billing.plans(id),
  provider                  text not null check (provider in ('flutterwave', 'google_play')),
  provider_reference        text not null,
  provider_subscription_id  text,
  provider_product_id       text,
  provider_plan_id          text,
  provider_state            text,
  internal_state            text not null check (internal_state in
    ('PENDING', 'ACTIVE', 'GRACE_PERIOD', 'PAYMENT_FAILED', 'PAUSED', 'CANCELLED', 'EXPIRED', 'REFUNDED')),
  auto_renewing             boolean not null default false,
  customer_email            text,
  current_period_start      timestamptz,
  current_period_end        timestamptz,
  access_expires_at         timestamptz,
  cancelled_at              timestamptz,
  ended_at                  timestamptz,
  linked_provider_reference text,
  superseded_by             uuid references billing.subscriptions(id),
  acknowledged_at           timestamptz,
  is_test                   boolean not null default false,
  metadata                  jsonb not null default '{}'::jsonb,
  created_at                timestamptz not null default now(),
  updated_at                timestamptz not null default now(),
  unique (provider, provider_reference)
);
create index if not exists subscriptions_user on billing.subscriptions(user_id);
create index if not exists subscriptions_provider_subscription on billing.subscriptions(provider, provider_subscription_id);
create index if not exists subscriptions_flutterwave_customer on billing.subscriptions(provider_plan_id, customer_email)
  where provider = 'flutterwave';

create table if not exists billing.subscription_transitions (
  id              bigint generated always as identity primary key,
  subscription_id uuid not null references billing.subscriptions(id) on delete cascade,
  from_state      text,
  to_state        text not null,
  provider_state  text,
  auto_renewing   boolean,
  access_expires_at timestamptz,
  reason          text not null default '',
  actor           text not null default 'system',
  created_at      timestamptz not null default now()
);
create index if not exists subscription_transitions_subscription
  on billing.subscription_transitions(subscription_id, created_at);

create table if not exists billing.payments (
  id                      uuid primary key default gen_random_uuid(),
  subscription_id         uuid references billing.subscriptions(id) on delete set null,
  user_id                 uuid references auth.users(id) on delete set null,
  provider                text not null check (provider in ('flutterwave', 'google_play')),
  reference               text not null,
  provider_transaction_id text,
  checkout_reference      text references billing.checkout_sessions(reference) on delete set null,
  kind                    text not null check (kind in ('initial', 'renewal')),
  amount                  numeric(12,2) not null check (amount >= 0),
  currency                text not null,
  verification_status     text not null check (verification_status in ('pending', 'verified', 'failed', 'refunded')),
  verified_at             timestamptz,
  refunded_at             timestamptz,
  period_start            timestamptz,
  period_end              timestamptz,
  provider_details        jsonb not null default '{}'::jsonb,
  created_at              timestamptz not null default now(),
  updated_at              timestamptz not null default now(),
  unique (provider, reference)
);
create unique index if not exists payments_provider_transaction
  on billing.payments(provider, provider_transaction_id) where provider_transaction_id is not null;
create index if not exists payments_subscription on billing.payments(subscription_id, created_at desc);

create table if not exists billing.payment_events (
  id                uuid primary key default gen_random_uuid(),
  provider          text not null check (provider in ('flutterwave', 'google_play')),
  event_id          text not null,
  event_type        text not null default '',
  authentication    text not null check (authentication in ('verified', 'rejected')),
  processing_status text not null default 'received' check (processing_status in ('received', 'processed', 'ignored', 'failed')),
  attempts          integer not null default 0,
  last_error        text,
  payload           jsonb not null default '{}'::jsonb,
  received_at       timestamptz not null default now(),
  processed_at      timestamptz,
  unique (provider, event_id)
);
create index if not exists payment_events_retry on billing.payment_events(received_at)
  where processing_status in ('received', 'failed');

create table if not exists billing.entitlements (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references auth.users(id) on delete cascade,
  feature         text not null,
  source          text not null check (source in ('subscription', 'manual')),
  subscription_id uuid references billing.subscriptions(id) on delete cascade,
  status          text not null check (status in ('active', 'inactive')),
  starts_at       timestamptz not null default now(),
  expires_at      timestamptz,
  reason          text not null default '',
  granted_by      text,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  check ((source = 'subscription') = (subscription_id is not null))
);
create unique index if not exists entitlements_subscription_feature
  on billing.entitlements(subscription_id, feature) where source = 'subscription';
create unique index if not exists entitlements_manual_feature
  on billing.entitlements(user_id, feature) where source = 'manual';
create index if not exists entitlements_user on billing.entitlements(user_id);

create table if not exists billing.settlement_assumptions (
  provider            text primary key check (provider in ('flutterwave', 'google_play')),
  customer_tax_rate   numeric(6,4) not null,
  commission_rate     numeric(6,4) not null,
  commission_tax_rate numeric(6,4) not null,
  notes               text not null default '',
  updated_at          timestamptz not null default now()
);

create table if not exists billing.settlements (
  id                  uuid primary key default gen_random_uuid(),
  payment_id          uuid not null references billing.payments(id) on delete cascade,
  provider            text not null,
  source              text not null check (source in ('estimate', 'provider_report')),
  gross_amount        numeric(14,2) not null,
  customer_tax        numeric(14,2) not null default 0,
  provider_fee        numeric(14,2) not null default 0,
  provider_fee_tax    numeric(14,2) not null default 0,
  settlement_currency text not null,
  fx_rate             numeric(18,8) not null default 1,
  net_amount          numeric(14,2) not null,
  report_reference    text,
  notes               text not null default '',
  recorded_at         timestamptz not null default now(),
  unique (payment_id, source)
);

do $$
declare
  v_table text;
begin
  foreach v_table in array array['plans', 'plan_prices', 'provider_plan_mappings', 'checkout_sessions',
    'subscriptions', 'subscription_transitions', 'payments', 'payment_events', 'entitlements',
    'settlement_assumptions', 'settlements']
  loop
    execute format('alter table billing.%I enable row level security', v_table);
    execute format('revoke all on table billing.%I from anon, authenticated', v_table);
  end loop;
end $$;

create or replace function billing.is_entitling_state(p_state text)
returns boolean
language sql
immutable
as $$
  select p_state in ('ACTIVE', 'GRACE_PERIOD', 'CANCELLED');
$$;

create or replace function billing.after_subscription_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_feature text;
begin
  if tg_op = 'INSERT'
     or new.internal_state is distinct from old.internal_state
     or new.auto_renewing is distinct from old.auto_renewing
     or new.access_expires_at is distinct from old.access_expires_at
     or new.provider_state is distinct from old.provider_state then
    insert into billing.subscription_transitions
      (subscription_id, from_state, to_state, provider_state, auto_renewing, access_expires_at, reason, actor)
    values (
      new.id,
      case when tg_op = 'INSERT' then null else old.internal_state end,
      new.internal_state, new.provider_state, new.auto_renewing, new.access_expires_at,
      coalesce(nullif(current_setting('billing.transition_reason', true), ''), ''),
      coalesce(nullif(current_setting('billing.transition_actor', true), ''), 'system')
    );
  end if;

  if new.user_id is null then
    update billing.entitlements set status = 'inactive', updated_at = now()
    where subscription_id = new.id;
    return new;
  end if;

  select entitlement_feature into v_feature from billing.plans where id = new.plan_id;

  insert into billing.entitlements (user_id, feature, source, subscription_id, status, starts_at, expires_at, reason)
  values (
    new.user_id, v_feature, 'subscription', new.id,
    case when billing.is_entitling_state(new.internal_state) then 'active' else 'inactive' end,
    coalesce(new.current_period_start, new.created_at), new.access_expires_at,
    new.provider || ' subscription ' || new.internal_state
  )
  on conflict (subscription_id, feature) where source = 'subscription' do update
    set user_id    = excluded.user_id,
        status     = excluded.status,
        expires_at = excluded.expires_at,
        reason     = excluded.reason,
        updated_at = now();
  return new;
end;
$$;

drop trigger if exists subscriptions_after_change on billing.subscriptions;
create trigger subscriptions_after_change
  after insert or update on billing.subscriptions
  for each row execute function billing.after_subscription_change();

create or replace function billing.active_entitlements(p_user_id uuid)
returns table (feature text, expires_at timestamptz, source text)
language sql
stable
security definer
set search_path = ''
as $$
  select e.feature,
         case when bool_or(e.expires_at is null) then null else max(e.expires_at) end as expires_at,
         case when bool_or(e.source = 'subscription') then 'subscription' else 'manual' end as source
  from billing.entitlements e
  where e.user_id = p_user_id
    and e.status = 'active'
    and e.starts_at <= now()
    and (e.expires_at is null or e.expires_at > now())
  group by e.feature;
$$;

create or replace function billing.has_entitlement(p_user_id uuid, p_feature text default 'premium')
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from billing.active_entitlements(p_user_id) a where a.feature = p_feature);
$$;

create or replace function billing.grant_manual_entitlement(
  p_email text, p_feature text default 'premium', p_expires_at timestamptz default null, p_reason text default ''
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
  v_id      uuid;
begin
  select id into v_user_id from auth.users where lower(email) = lower(trim(p_email));
  if v_user_id is null then
    raise exception 'No account uses the email %', p_email;
  end if;
  insert into billing.entitlements (user_id, feature, source, status, expires_at, reason, granted_by)
  values (v_user_id, p_feature, 'manual', 'active', p_expires_at, p_reason, current_user)
  on conflict (user_id, feature) where source = 'manual' do update
    set status = 'active', expires_at = excluded.expires_at, reason = excluded.reason,
        granted_by = excluded.granted_by, updated_at = now()
  returning id into v_id;
  return v_id;
end;
$$;

create or replace function billing.revoke_manual_entitlement(p_email text, p_feature text default 'premium', p_reason text default '')
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  update billing.entitlements e
  set status = 'inactive', reason = p_reason, granted_by = current_user, updated_at = now()
  from auth.users u
  where e.user_id = u.id and lower(u.email) = lower(trim(p_email))
    and e.feature = p_feature and e.source = 'manual';
end;
$$;

revoke all on function billing.grant_manual_entitlement(text, text, timestamptz, text) from public, anon, authenticated;
revoke all on function billing.revoke_manual_entitlement(text, text, text) from public, anon, authenticated;
revoke all on function billing.set_plan_price(text, text, numeric, text) from public, anon, authenticated;

create or replace function public.get_my_entitlements()
returns table (feature text, expires_at timestamptz, source text)
language sql
stable
security definer
set search_path = ''
as $$
  select a.feature, a.expires_at, a.source from billing.active_entitlements(auth.uid()) a
  where auth.uid() is not null;
$$;

revoke all on function public.get_my_entitlements() from public, anon;
grant execute on function public.get_my_entitlements() to authenticated;

create or replace function public.get_my_subscription()
returns table (
  plan_id text, provider text, internal_state text, auto_renewing boolean,
  current_period_end timestamptz, access_expires_at timestamptz, product_id text
)
language sql
stable
security definer
set search_path = ''
as $$
  select s.plan_id, s.provider, s.internal_state, s.auto_renewing,
         s.current_period_end, s.access_expires_at, s.provider_product_id
  from billing.subscriptions s
  where s.user_id = auth.uid() and auth.uid() is not null and s.superseded_by is null
    and s.internal_state <> 'PENDING'
  order by billing.is_entitling_state(s.internal_state) and coalesce(s.access_expires_at > now(), false) desc,
           s.auto_renewing desc, s.access_expires_at desc nulls last
  limit 1;
$$;

revoke all on function public.get_my_subscription() from public, anon;
grant execute on function public.get_my_subscription() to authenticated;

insert into billing.plans (id, name, description, billing_interval, benefits, display_order) values
  ('premium_monthly', 'Premium Monthly', 'Flexible monthly billing.', 'month',
   '["Full Premium"]'::jsonb, 1),
  ('premium_annual', 'Premium Annual', 'Save ₦3,000 compared with twelve monthly payments.', 'year',
   '["Full Premium"]'::jsonb, 2)
on conflict (id) do nothing;

insert into billing.plan_prices (plan_id, currency, amount, change_reason)
select v.plan_id, 'NGN', v.amount, 'Launch price (tax-inclusive, vendor-borne processing fees)'
from (values ('premium_monthly', 1500.00), ('premium_annual', 15000.00)) as v(plan_id, amount)
where not exists (
  select 1 from billing.plan_prices p where p.plan_id = v.plan_id and p.currency = 'NGN'
);

insert into billing.provider_plan_mappings (plan_id, provider, product_id, base_plan_id)
select v.plan_id, 'google_play', 'enchiridion_premium', v.base_plan_id
from (values ('premium_monthly', 'premium-monthly'), ('premium_annual', 'premium-annual')) as v(plan_id, base_plan_id)
where not exists (
  select 1 from billing.provider_plan_mappings m where m.provider = 'google_play' and m.plan_id = v.plan_id
);

insert into billing.settlement_assumptions (provider, customer_tax_rate, commission_rate, commission_tax_rate, notes) values
  ('google_play', 0.0750, 0.1500, 0.0750, 'Illustrative planning model only; reconcile against Play payout reports.'),
  ('flutterwave', 0.0750, 0.0000, 0.0750, 'Processor fee comes from each verified transaction; reconcile against settlements.')
on conflict (provider) do nothing;


-- Signup metadata is client-supplied, so every value is clamped and a failure here must never abort the auth.users insert.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_meta          jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
  v_role          text  := coalesce(v_meta->>'role', 'student');
  v_terms_version text  := nullif(left(coalesce(v_meta->>'terms_version', ''), 32), '');
  v_display_name  text  := left(coalesce(v_meta->>'display_name', v_meta->>'full_name', v_meta->>'name', ''), 80);
  v_full_name     text  := left(coalesce(nullif(v_meta->>'name', ''), nullif(v_meta->>'full_name', ''), v_meta->>'display_name', ''), 200);
  v_avatar_url    text  := case when coalesce(v_meta->>'avatar_url', v_meta->>'picture', '') ~ '^https://'
                                then left(coalesce(v_meta->>'avatar_url', v_meta->>'picture'), 500) end;
  v_source        text  := case when v_meta->>'signup_source' in ('web', 'android_app', 'ios_app')
                                then v_meta->>'signup_source' else 'unknown' end;
  v_region        text  := left(coalesce(v_meta->>'country', v_meta->>'signup_region', ''), 80);
  v_marketing     boolean := v_source = 'web' and coalesce(v_meta->>'marketing_opt_in', '') = 'true';
  v_code          text  := lower(coalesce(v_meta->>'referral_code', ''));
  v_referred_by   text  := nullif(lower(trim(coalesce(v_meta->>'referred_by', ''))), '');
begin
  if v_role not in ('student', 'clinician', 'other') then
    v_role := 'student';
  end if;

  begin
    insert into public.profiles (id, display_name, role, avatar_url, email_confirmed, terms_version, terms_accepted_at)
    values (new.id, v_display_name, v_role, v_avatar_url, new.email_confirmed_at is not null, v_terms_version,
            case when v_terms_version is null then null else timezone('utc', now()) end)
    on conflict (id) do nothing;
  exception when unique_violation then
    insert into public.profiles (id, display_name, role, avatar_url, email_confirmed, terms_version, terms_accepted_at)
    values (new.id, '', v_role, v_avatar_url, new.email_confirmed_at is not null, v_terms_version,
            case when v_terms_version is null then null else timezone('utc', now()) end)
    on conflict (id) do nothing;
  end;

  begin
    insert into public.communication_preferences
      (user_id, signup_source, signup_region, marketing_opt_in, marketing_consent_source,
       marketing_consent_region, marketing_consent_at)
    values (new.id, v_source, v_region, v_marketing,
            case when v_marketing then 'web_signup' end,
            case when v_marketing then v_region end,
            case when v_marketing then timezone('utc', now()) end)
    on conflict (user_id) do nothing;
    if v_marketing then
      insert into public.communication_consent_events (user_id, granted, source, region)
      values (new.id, true, 'web_signup', v_region);
    end if;
  exception when others then
    raise warning 'handle_new_user: communication preferences not created for %: %', new.id, sqlerrm;
  end;

  if new.email is null then
    return new;
  end if;

  begin
    if v_code !~ '^[a-z0-9_-]{3,64}$'
       or exists (select 1 from enchiridion_web.partners where referral_code = v_code) then
      v_code := substr(replace(gen_random_uuid()::text, '-', ''), 1, 12);
    end if;
    if v_referred_by is not null and (
         v_referred_by = v_code
         or not exists (select 1 from enchiridion_web.partners where referral_code = v_referred_by)) then
      v_referred_by := null;
    end if;
    insert into enchiridion_web.partners
      (id, email, name, referral_code, referred_by, is_verified, state, country, profession, phone, institution)
    values (
      new.id, lower(trim(new.email)), v_full_name, v_code, v_referred_by, new.email_confirmed_at is not null,
      left(coalesce(v_meta->>'state', ''), 100), left(coalesce(v_meta->>'country', ''), 100),
      left(coalesce(v_meta->>'profession', ''), 100), left(coalesce(v_meta->>'phone', ''), 40),
      left(coalesce(v_meta->>'institution', ''), 200)
    )
    on conflict (id) do nothing;
    insert into enchiridion_web.onboarding (user_id) values (new.id) on conflict (user_id) do nothing;
  exception when others then
    raise warning 'handle_new_user: website partner not created for %: %', new.id, sqlerrm;
  end;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

create or replace function public.handle_user_identity_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  begin
    update enchiridion_web.partners
    set email = coalesce(lower(trim(new.email)), email), is_verified = new.email_confirmed_at is not null
    where id = new.id;
    update public.profiles set email_confirmed = new.email_confirmed_at is not null where id = new.id;
  exception when others then
    raise warning 'handle_user_identity_change: sync failed for %: %', new.id, sqlerrm;
  end;

  -- The offer email is a separate, consent-gated marketing message, never an automatic part of verification.
  if old.email_confirmed_at is null and new.email_confirmed_at is not null and new.email is not null then
    insert into enchiridion_web.email_outbox (user_id, kind, recipient, dedupe_key)
    select new.id, 'premium_offer', lower(new.email), 'premium_offer:' || new.id
    from public.communication_preferences c
    where c.user_id = new.id and c.marketing_opt_in and c.marketing_unsubscribed_at is null
    on conflict (dedupe_key) do nothing;
  end if;
  return new;
end;
$$;

drop trigger if exists on_auth_user_identity_changed on auth.users;
create trigger on_auth_user_identity_changed
  after update of email, email_confirmed_at on auth.users
  for each row execute function public.handle_user_identity_change();

insert into public.profiles (id, email_confirmed)
select u.id, u.email_confirmed_at is not null from auth.users u
on conflict (id) do nothing;

insert into public.communication_preferences (user_id)
select u.id from auth.users u
on conflict (user_id) do nothing;

insert into enchiridion_web.partners (id, email, name, referral_code, is_verified)
select u.id, lower(trim(u.email)), coalesce(nullif(p.display_name, ''), ''),
       substr(replace(gen_random_uuid()::text, '-', ''), 1, 12), u.email_confirmed_at is not null
from auth.users u
left join public.profiles p on p.id = u.id
where u.email is not null
  and not exists (select 1 from enchiridion_web.partners w where w.id = u.id)
  and not exists (select 1 from enchiridion_web.partners w where w.email = lower(trim(u.email)));

insert into enchiridion_web.onboarding (user_id)
select id from enchiridion_web.partners
on conflict (user_id) do nothing;


do $$
begin
  if to_regclass('public.user_book_access') is not null then
    insert into billing.entitlements (user_id, feature, source, status, expires_at, reason, granted_by)
    select a.user_id, case when a.book_id = '*' then 'premium' else a.book_id end, 'manual', 'active',
           a.expires_at, 'Migrated from public.user_book_access', 'migration'
    from public.user_book_access a
    where a.granted and (a.expires_at is null or a.expires_at > now())
    on conflict (user_id, feature) where source = 'manual' do nothing;
    if to_regclass('legacy.user_book_access') is null then
      alter table public.user_book_access set schema legacy;
    else
      drop table public.user_book_access;
    end if;
  end if;
  if to_regclass('public.processed_payments') is not null and to_regclass('legacy.processed_payments') is null then
    alter table public.processed_payments set schema legacy;
  end if;
  if to_regclass('public.user_subscriptions') is not null and to_regclass('legacy.user_subscriptions') is null then
    alter table public.user_subscriptions set schema legacy;
  end if;
end $$;

drop function if exists public.user_id_for_email(text);


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
create policy "Signed-in users can read questions"
  on public.questions for select to authenticated using (true);


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
  on public.daily_study_stats for select using (auth.uid() = user_id);
create policy "Users can insert their own daily study stats"
  on public.daily_study_stats for insert with check (auth.uid() = user_id);
create policy "Users can update their own daily study stats"
  on public.daily_study_stats for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

create or replace view public.leaderboard_points_totals
with (security_invoker = true) as
select
  user_id,
  sum(performance_points) as total_points,
  sum(questions_answered) as total_answered,
  sum(correct_answers)    as total_correct
from public.daily_study_stats
group by user_id;

create or replace function public.get_leaderboard(result_limit integer default 20)
returns table (rank bigint, display_name text, total_points bigint, is_you boolean)
language sql
security definer
set search_path = public
stable
as $$
  with totals as (
    select d.user_id, coalesce(nullif(p.display_name, ''), 'Anonymous') as display_name,
           sum(d.performance_points) as total_points
    from public.daily_study_stats d
    join public.profiles p on p.id = d.user_id
    group by d.user_id, p.display_name
  ),
  ranked as (
    select row_number() over (order by total_points desc, display_name) as rank,
           display_name, total_points, (user_id = auth.uid()) as is_you
    from totals
  )
  select rank, display_name, total_points, is_you
  from ranked
  where rank <= greatest(result_limit, 1) or is_you
  order by rank;
$$;

grant execute on function public.get_leaderboard(integer) to authenticated;

create or replace function public.get_leaderboard_for_scope(
  result_limit integer default 20,
  scope_filter text default 'exam_prep_plab'
)
returns table (rank bigint, display_name text, total_points bigint, is_you boolean)
language sql
security definer
set search_path = public
stable
as $$
  with totals as (
    select d.user_id, coalesce(nullif(p.display_name, ''), 'Anonymous') as display_name,
           sum(d.performance_points) as total_points
    from public.daily_study_stats d
    join public.profiles p on p.id = d.user_id
    where d.scope = scope_filter
    group by d.user_id, p.display_name
  ),
  ranked as (
    select row_number() over (order by total_points desc, display_name) as rank,
           display_name, total_points, (user_id = auth.uid()) as is_you
    from totals
  )
  select rank, display_name, total_points, is_you
  from ranked
  where rank <= greatest(result_limit, 1) or is_you
  order by rank;
$$;

grant execute on function public.get_leaderboard_for_scope(integer, text) to authenticated;


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

create index if not exists idx_question_reviews_due
  on public.question_reviews(user_id, scope, due_at)
  where not retired;

alter table public.question_reviews enable row level security;

drop policy if exists "Users can read their own question reviews"   on public.question_reviews;
drop policy if exists "Users can insert their own question reviews" on public.question_reviews;
drop policy if exists "Users can update their own question reviews" on public.question_reviews;

create policy "Users can read their own question reviews"
  on public.question_reviews for select using (auth.uid() = user_id);
create policy "Users can insert their own question reviews"
  on public.question_reviews for insert with check (auth.uid() = user_id);
create policy "Users can update their own question reviews"
  on public.question_reviews for update using (auth.uid() = user_id) with check (auth.uid() = user_id);


create table if not exists public.flagged_questions (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  scope       text not null default 'exam_prep_plab',
  question_id text not null,
  reason      text not null,
  status      text not null default 'open' check (status in ('open', 'reviewed', 'dismissed')),
  created_at  timestamptz not null default timezone('utc', now())
);

create index if not exists idx_flagged_questions_open
  on public.flagged_questions(status, created_at)
  where status = 'open';

alter table public.flagged_questions enable row level security;

drop policy if exists "Users can read their own flags"   on public.flagged_questions;
drop policy if exists "Users can insert their own flags" on public.flagged_questions;

create policy "Users can read their own flags"
  on public.flagged_questions for select using (auth.uid() = user_id);
create policy "Users can insert their own flags"
  on public.flagged_questions for insert with check (auth.uid() = user_id);


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

create table if not exists public.note_collections (
  user_id    uuid not null references auth.users(id) on delete cascade,
  id         text not null,
  name       text not null default '',
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  primary key (user_id, id)
);

create table if not exists public.bookmarks (
  user_id         uuid not null references auth.users(id) on delete cascade,
  id              text not null,
  chapter_id      text not null default '',
  name            text not null default '',
  scroll_progress double precision not null default 0,
  created_at      timestamptz not null default timezone('utc', now()),
  primary key (user_id, id)
);

create table if not exists public.reading_notes (
  user_id    uuid not null references auth.users(id) on delete cascade,
  book_id    text not null,
  chapter_id text not null,
  content    text not null default '',
  updated_at timestamptz not null default timezone('utc', now()),
  primary key (user_id, book_id, chapter_id)
);

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

create table if not exists public.user_settings (
  user_id    uuid primary key references auth.users(id) on delete cascade,
  settings   jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.user_book_history (
  user_id   uuid not null references auth.users(id) on delete cascade,
  book_id   text not null,
  opened_at timestamptz not null default timezone('utc', now()),
  primary key (user_id, book_id)
);

create table if not exists public.synced_deletions (
  user_id    uuid not null references auth.users(id) on delete cascade,
  entity     text not null,
  entity_id  text not null,
  deleted_at timestamptz not null default timezone('utc', now()),
  primary key (user_id, entity, entity_id)
);

do $$
declare
  v_pair text[];
begin
  foreach v_pair slice 1 in array array[
    ['pinned_notes',      'Users manage own pinned notes'],
    ['note_collections',  'Users manage own note collections'],
    ['bookmarks',         'Users manage own bookmarks'],
    ['reading_notes',     'Users manage own reading notes'],
    ['clips',             'Users manage own clips'],
    ['user_answers',      'Users manage own answers'],
    ['user_settings',     'Users manage own settings'],
    ['user_book_history', 'Users manage own book history'],
    ['synced_deletions',  'Users manage own deletions']
  ]
  loop
    execute format('alter table public.%I enable row level security', v_pair[1]);
    execute format('drop policy if exists %I on public.%I', v_pair[2], v_pair[1]);
    execute format(
      'create policy %I on public.%I for all using (auth.uid() = user_id) with check (auth.uid() = user_id)',
      v_pair[2], v_pair[1]);
  end loop;
end $$;


create table if not exists public.announcements (
  id           uuid        primary key default gen_random_uuid(),
  title        text        not null,
  body         text        not null,
  is_important boolean     not null default false,
  is_published boolean     not null default true,
  published_at timestamptz not null default now(),
  expires_at   timestamptz
);

create index if not exists idx_announcements_published_at
  on public.announcements(published_at desc);

alter table public.announcements enable row level security;

drop policy if exists "Signed-in users can read live announcements" on public.announcements;
create policy "Signed-in users can read live announcements"
  on public.announcements for select to authenticated
  using (is_published and published_at <= now() and (expires_at is null or expires_at > now()));


insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do update set public = true;

drop policy if exists "Avatar images are publicly readable" on storage.objects;
drop policy if exists "Users can upload their own avatar"   on storage.objects;
drop policy if exists "Users can update their own avatar"   on storage.objects;
drop policy if exists "Users can delete their own avatar"   on storage.objects;

create policy "Avatar images are publicly readable"
  on storage.objects for select using (bucket_id = 'avatars');
create policy "Users can upload their own avatar"
  on storage.objects for insert
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "Users can update their own avatar"
  on storage.objects for update
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "Users can delete their own avatar"
  on storage.objects for delete
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

commit;


-- Optional QA account in its own transaction: set v_password to create it, or leave it empty to skip.
begin;

do $$
declare
  v_email    text := 'clinician@enchiridion.app';
  v_password text := '';
  v_name     text := 'Enchiridion Clinician';
  v_user_id  uuid;
  v_has_provider_id boolean;
  v_col      text;
begin
  set local search_path = public, extensions, auth;

  select id into v_user_id from auth.users where email = lower(v_email);

  if v_user_id is null and v_password = '' then
    raise notice 'QA clinician account skipped (no password set).';
    return;
  end if;

  if v_user_id is null then
    v_user_id := gen_random_uuid();

    insert into auth.users (
      instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
      raw_app_meta_data, raw_user_meta_data, created_at, updated_at
    ) values (
      '00000000-0000-0000-0000-000000000000', v_user_id, 'authenticated', 'authenticated',
      lower(v_email), crypt(v_password, gen_salt('bf')), timezone('utc', now()),
      '{"provider":"email","providers":["email"]}'::jsonb,
      jsonb_build_object('display_name', v_name, 'role', 'clinician', 'signup_source', 'unknown'),
      timezone('utc', now()), timezone('utc', now())
    );

    -- GoTrue releases differ on auth.identities' id/provider_id layout; both shapes are handled.
    select exists (
      select 1 from information_schema.columns
      where table_schema = 'auth' and table_name = 'identities' and column_name = 'provider_id'
    ) into v_has_provider_id;

    if v_has_provider_id then
      insert into auth.identities (id, user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
      values (gen_random_uuid(), v_user_id, v_user_id::text,
              jsonb_build_object('sub', v_user_id::text, 'email', lower(v_email), 'email_verified', true, 'phone_verified', false),
              'email', timezone('utc', now()), timezone('utc', now()), timezone('utc', now()));
    else
      execute 'insert into auth.identities (id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
               values ($1::text, $2, $3, ''email'', $4, $4, $4)'
      using v_user_id, v_user_id,
            jsonb_build_object('sub', v_user_id::text, 'email', lower(v_email), 'email_verified', true, 'phone_verified', false),
            timezone('utc', now());
    end if;

    -- GoTrue expects '' rather than NULL in these token columns; NULL surfaces later as a 500 on refresh or recovery.
    for v_col in
      select column_name from information_schema.columns
      where table_schema = 'auth' and table_name = 'users' and is_nullable = 'YES'
        and column_name in ('confirmation_token', 'recovery_token', 'email_change', 'email_change_token_new',
                            'email_change_token_current', 'phone_change', 'phone_change_token', 'reauthentication_token')
    loop
      execute format('update auth.users set %I = coalesce(%I, %L) where id = %L', v_col, v_col, '', v_user_id);
    end loop;
  end if;

  insert into public.profiles (id, display_name, role, email_confirmed, device_binding_exempt)
  values (v_user_id, v_name, 'clinician', true, true)
  on conflict (id) do update
    set display_name          = coalesce(nullif(public.profiles.display_name, ''), excluded.display_name),
        role                  = 'clinician',
        email_confirmed       = true,
        device_binding_exempt = true;

  perform billing.grant_manual_entitlement(v_email, 'premium', null, 'QA clinician account');
  raise notice 'QA clinician account % is ready with Premium.', v_email;
end;
$$;

commit;
