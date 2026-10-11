# Premium subscriptions: setup and operations

Implements `enchiridion-app/tasks/enchiridion_subscription_architecture_v1_1.md`.
One Enchiridion account (Supabase Auth) works on the website and in the Android
app. Premium can be bought on the website (Flutterwave) or in the app (Google Play
Billing); both produce the same `premium` entitlement.

```text
Website /premium ──► POST /api/v1/payments/flutterwave/checkout ──► Flutterwave hosted checkout
                                                                        │ webhook + server re-verification
Android app ──► Google Play Billing ──► POST /api/v1/payments/google/verify ◄── Pub/Sub RTDN push
                                                      │
                               FastAPI backend (backend/app/billing)
                                                      │
          billing.subscriptions ──trigger──► billing.entitlements ◄── get_my_entitlements() (app)
                                                                  ◄── /api/v1/subscription/* (website)
```

Click-by-click provider setup: [payment-provider-setup.md](payment-provider-setup.md).

Every call from the app and the website goes through `https://enchiridion.site/api/v1/...`
(routed directly to FastAPI by Vercel Services). Provider webhooks use the same
combined domain. Follow [vercel-services.md](vercel-services.md) for the default
one-project deployment; the separate backend/frontend project instructions below
are an alternative.

## 1. Supabase

1. Run [`supabase/enchiridion_master.sql`](../supabase/enchiridion_master.sql) (see [database.md](database.md)).
2. **Authentication → Providers → Email:** Confirm email **on**; Email OTP length **8** (the app's code screen expects 8 digits).
3. **Authentication → URL Configuration:** Site URL `https://enchiridion.site`; add redirect URLs
   `https://enchiridion.site/verify-email`, `https://enchiridion.site/reset-password`, `https://enchiridion.site/auth/callback` (and the `localhost:3000` equivalents for development).
4. **Authentication → Emails → Templates:** paste
   [`confirm-signup.html`](../supabase/email-templates/confirm-signup.html) into *Confirm signup* (subject: `Verify your Enchiridion account`) and
   [`reset-password.html`](../supabase/email-templates/reset-password.html) into *Reset password*.
   Confirm signup uses the `{{ .Token }}` verification code on both the website and the app. Reset password uses the existing `{{ .ConfirmationURL }}` link flow. Keep the working Supabase templates if they already match these flows.
5. **Authentication → Emails → SMTP:** configure custom SMTP so verification mail is not rate-limited.

## 2. Backend (Vercel project rooted at `backend/`)

Environment variables — see [`backend/.env.example`](../backend/.env.example):

| Variable | Purpose |
| --- | --- |
| `SUPABASE_DB_URL` | Transaction-pooler URI (port 6543) |
| `SUPABASE_URL` | Verifies sessions from the website and the app via the project's JWKS |
| `SUPABASE_JWT_SECRET` | Only if the project still signs sessions with the legacy HS256 secret |
| `FRONTEND_URL`, `CORS_ORIGINS` | `https://enchiridion.site` |
| `FLUTTERWAVE_SECRET_KEY`, `FLUTTERWAVE_WEBHOOK_SECRET` | Server-side only |
| `GOOGLE_PLAY_PACKAGE_NAME` | The app's final `applicationId` |
| `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` | Service account key (raw JSON or base64) |
| `GOOGLE_RTDN_AUDIENCE`, `GOOGLE_RTDN_SERVICE_ACCOUNT` | Pub/Sub push authentication |
| `CRON_SECRET` | Protects the scheduled reconciliation job |
| `MAIL_*` | SMTP for billing notices and the consented offer email |

`backend/vercel.json` schedules `GET /api/v1/internal/jobs` daily (the Vercel Hobby
limit). It recovers checkouts whose webhook never arrived, retries failed provider
events, refreshes Google subscriptions near expiry, retries acknowledgements,
expires lapsed website subscriptions, and sends queued email. On Vercel Pro,
run it hourly; any external scheduler can also call it with
`Authorization: Bearer $CRON_SECRET`.

## 3. Website (Vercel project rooted at `frontend/`)

Set `BACKEND_URL`, `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY` (the
same project as the app), `NEXT_PUBLIC_FLUTTERWAVE_PUBLIC_KEY` (book checkout) and
`NEXT_PUBLIC_PLAY_STORE_URL`. Pages: `/premium`, `/premium/processing`,
`/account/subscription`, `/verify-email`, `/reset-password`, `/unsubscribe`,
`/terms`, `/privacy`.

## 4. Flutterwave

1. **Settings → Business preferences → transaction fees: charge the merchant**, so customers
   pay exactly ₦1,500 / ₦15,000. Every verified payment whose `charged_amount` exceeds the price
   is flagged `customer_charged_fees` in `billing.payments.provider_details` and logged, so a
   misconfiguration is visible.
2. **Settings → Webhooks:** URL `https://<backend>/api/v1/payments/flutterwave/webhook`, secret hash =
   `FLUTTERWAVE_WEBHOOK_SECRET`, retries on. This one URL handles book orders and subscriptions
   (Flutterwave allows one URL; `/referral/flutterwave/webhook` still works as an alias).
3. Payment plans are created automatically, one per price version, the first time someone checks
   out; `billing.set_plan_price` therefore never changes what existing subscribers are charged.
4. Auto-renewal is card-only (a Flutterwave rule). Unticking *Renew automatically* on `/premium`
   sells one non-renewing period by card, bank transfer or USSD.
5. Refunds are issued in the Flutterwave dashboard; then record them with
   `POST /api/v1/admin/subscriptions/{id}/refunded` (admin account), which ends access and audits it.

## 5. Google Play

1. **Change the app's `applicationId`.** It is still `com.example.enchiridion`, which Play rejects.
   Set it in `enchiridion-app/enchiridion/android/app/build.gradle.kts` before the first upload,
   and use the same value for `GOOGLE_PLAY_PACKAGE_NAME`.
2. **Monetize → Subscriptions:** create product `enchiridion_premium` with two auto-renewing base plans:
   `premium-monthly` (1 month) and `premium-annual` (1 year). Set Nigeria's prices so the
   tax-inclusive offer shows ₦1,500 and ₦15,000, then check the price the app actually displays
   (it always shows Google's localized price, never a hard-coded one). Different names? Update
   `kPlayPremiumProductId`/`basePlanId` in `lib/config/pricing_config.dart` **and**
   `billing.provider_plan_mappings`.
3. **Service account:** Google Cloud → create a service account + JSON key. Play Console →
   Users and permissions → invite it with *View financial data* and *Manage orders and subscriptions*.
4. **Real-time developer notifications:** create a Pub/Sub topic, grant
   `google-play-developer-notifications@system.gserviceaccount.com` the *Pub/Sub Publisher* role on it,
   enter it under Play Console → Monetization setup, and create a **push** subscription to
   `https://<backend>/api/v1/payments/google/notifications` with authentication enabled
   (choose a service account; audience = the endpoint URL). Put that audience and service-account
   email in `GOOGLE_RTDN_AUDIENCE` / `GOOGLE_RTDN_SERVICE_ACCOUNT`, then press *Send test notification*.
5. Add license testers and test with test cards before production.

The app passes the Supabase user id as the obfuscated account id. The backend rejects a purchase
token whose account id or recorded owner is a different account, never grants a pending purchase,
acknowledges only after recording the purchase, and follows `linkedPurchaseToken` on resubscribe
or plan change.

## 6. Policy defaults (restrictive)

`lib/config/purchasing_policy.dart` enables Google Play Billing on Android and disables Flutterwave
in-app, external checkout links, external-offer programmes and external account-management links
for every region. Device region, SIM or IP never switch them on. A guard test
(`test/guards/no_external_checkout_guard_test.dart`) fails if a website purchase route or Flutterwave
reference appears in the app. Website subscribers who sign in to the app get Premium without
repurchasing; the app tells them to manage the subscription on the website but does not link to it.
On platforms other than Android the app sells nothing.

Before release, re-check the live policies listed in §14 of the brief. In particular: the About screen
still links to the website homepage, whose navigation now includes **Premium**. Decide whether that is
acceptable for the Nigerian Play listing or remove the link.

The optional offer email is marketing: it goes only to website sign-ups who ticked the unticked consent
box, after verification, if they are not already Premium, with an unsubscribe link. App sign-ups
never receive it. Account, security and billing emails are sent regardless.

## 7. Sandbox test plan

| # | Scenario | Expect |
| --- | --- | --- |
| 1 | Website: subscribe monthly with a Flutterwave test card | `/premium/processing` → active; app shows Premium after refresh |
| 2 | Replay the same webhook | `{"status": "duplicate"}`; one payment row |
| 3 | Webhook with a wrong secret | 401; a `rejected` row in `billing.payment_events` |
| 4 | Close the tab before the redirect | Webhook or daily job activates it; email sent |
| 5 | Subscribe again while active (web or app) | Blocked with the *existing subscription* message |
| 6 | Cancel on `/account/subscription` | `CANCELLED`, Premium kept until period end, then `EXPIRED` via the job |
| 7 | Android: buy with a license tester | Localized price shown; Premium after verification; purchase acknowledged |
| 8 | Android: slow test card (pending) | *Payment processing* message, no Premium until it clears |
| 9 | Play Console: refund & revoke | RTDN → `REFUNDED`, Premium removed |
| 10 | Let a test subscription lapse (account hold) | `PAYMENT_FAILED`, Premium removed, email sent |
| 11 | Same Google account, second Enchiridion account | Restore shows *linked to another account*; nothing granted |

Automated coverage: `backend/tests/test_billing.py`, `test_google_auth.py`, `test_persistence.py`
(against the local database described in [database.md](database.md)) and the Flutter tests under
`test/services`, `test/config`, `test/guards`.

## 8. Not done yet

- **Android App Links:** "Open Enchiridion" after a website purchase links to the Play listing
  (`NEXT_PUBLIC_PLAY_STORE_URL`); a verified App Link needs `assetlinks.json` plus an intent filter.
- **iOS:** no purchase flow; App Store rules must be reviewed first.
- **Settlements** hold per-payment estimates (Flutterwave fee from each transaction; Play fees from
  `billing.settlement_assumptions`). Importing provider payout reports as `provider_report` rows is manual.
- **Flutterwave refunds** are recorded by an admin call, not detected automatically.
- **Price-change notices** (Terms §6.5, 30 days ahead) must be sent manually for now.
