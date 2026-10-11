# Setup runbook: from code to launch

This puts the other setup documents in the order to do them. Each step names the
document and section with the click-by-click detail, and ends with a **Check**
so you know it worked before moving on.

| Document | Covers |
| --- | --- |
| [database.md](database.md) | Running the master SQL, admin SQL, the pre-launch wipe |
| [subscriptions.md](subscriptions.md) | Supabase Auth settings, Vercel variables, the sandbox test plan |
| [payment-provider-setup.md](payment-provider-setup.md) | Flutterwave (Part A), Google Play (Part B), cron and email (Part C), variable map (Part D) |
| [google-sign-in-setup.md](google-sign-in-setup.md) | Google Cloud OAuth clients, Supabase Google provider, app build flag |

Everything runs in **test mode** first (phases 1–8). Phase 9 switches to live.

---

## Phase 0 — Prepare (about 30 minutes)

### 0.1 Accounts you need

- [ ] Supabase: the project the app already uses, `lvyoqnmqdquadkfixduq` (set in `enchiridion-app/enchiridion/lib/config/supabase_config.dart`). The website **must** use the same one.
- [ ] Vercel, with this repository connected
- [ ] Flutterwave business account, approved for live payments (test mode works before approval)
- [ ] Google Play Console developer account
- [ ] Google Cloud (same Google account as Play Console is easiest)
- [ ] An SMTP mailbox, e.g. `admin@enchiridion.site` or a Gmail app password
- [ ] Hostinger access for `enchiridion.site` DNS

### 0.2 Back up the database

The master SQL changes a live project. In **Supabase → Database → Backups**, confirm there is a recent backup, or download one first.

If real partners registered on the old website, the master SQL archives their accounts instead of migrating them; they will need to sign up again (see the README, *Supabase Setup*).

### 0.3 Generate secrets

Run this twice and keep both outputs:

```bash
openssl rand -hex 32   # → FLUTTERWAVE_WEBHOOK_SECRET
openssl rand -hex 32   # → CRON_SECRET
```

### 0.4 Start a values sheet

Keep these in a password manager; you fill them in as you go.

| Value | Filled in at |
| --- | --- |
| Supabase transaction-pooler URI (port 6543) | 1.1 |
| Supabase project URL and anon key | 1.1 |
| Backend URL (`<BACKEND>`) | 2.1 |
| Flutterwave test secret and public keys | 5.1 |
| Android application ID (`<APPLICATION_ID>`) | 6.1 |
| Google Web client ID and secret | 6.4 |
| Play service-account JSON (base64) | 7.3 |
| `rtdn-push` service-account email | 7.4 |
| Play Store listing URL | 6.3 |

---

## Phase 1 — Supabase

### 1.1 Collect connection values

- [ ] **Connect → Transaction pooler**: copy the URI on port **6543**. URL-encode special characters in the password.
- [ ] **Project Settings → API**: copy the project URL and the **anon** key.

### 1.2 Run the master SQL

[database.md → Running it](database.md#running-it)

- [ ] SQL Editor → New query → paste all of `supabase/enchiridion_master.sql` → **Run**.
- [ ] Leave `v_password` empty, unless you want the QA clinician account for testing. If you set it, clear it and re-run before launch.

**Check:**

```sql
select plan_id, currency, amount from billing.plan_prices where effective_to is null;
```

Expect `premium_monthly NGN 1500.00` and `premium_annual NGN 15000.00`.

### 1.3 Auth settings

[subscriptions.md → 1. Supabase](subscriptions.md#1-supabase), steps 2–5

- [ ] **Providers → Email:** Confirm email on; OTP length **8**.
- [ ] **URL Configuration:**
  - Site URL: `https://enchiridion.site`
  - Redirect URLs: `https://enchiridion.site/verify-email`, `/reset-password`, `/auth/callback`, plus the same three on `http://localhost:3000`.
- [ ] **Emails → Templates:** paste `confirm-signup.html` and `reset-password.html`.
- [ ] **Emails → SMTP:** custom SMTP on (the built-in sender is rate-limited to a few emails an hour).

Google sign-in comes later, in phase 6.

---

## Phase 2 — Combined website and backend on Vercel

Follow [vercel-services.md](vercel-services.md) for the current one-project deployment.

- [ ] Import `heekmerh/enchiridion` with repository root `./` and application preset **Services**.
- [ ] Use the checked-in root `vercel.json`; the service roots are `frontend` and `backend`.
- [ ] Add the backend and frontend environment variables from the combined guide to this project.
- [ ] Do not manually set `BACKEND_URL`; the service binding injects it at runtime.
- [ ] Deploy and record the combined URL as `<BACKEND>` for the provider setup steps below.
- [ ] Ensure production Deployment Protection allows public API and webhook requests.

**Check:** `<BACKEND>/` serves the website and `<BACKEND>/health/ready` returns `ready`.

## Phase 3 — Domain and administrator account

The frontend and backend share the combined project. Add the domain to that project.

### 3.2 Domain

[README → Hostinger Domain](../README.md#hostinger-domain)

- [ ] Add `enchiridion.site` and `www.enchiridion.site` to the **combined Services** project.
- [ ] In Hostinger DNS, set the A and CNAME records Vercel shows. Keep the MX, SPF and DKIM records.
- [ ] Wait for HTTPS to be issued.

### 3.3 Make yourself admin

- [ ] Sign up on `https://enchiridion.site/refer` and enter the emailed verification code on `/verify-email`.
- [ ] In Supabase:

  ```sql
  update enchiridion_web.partners set is_superuser = true where email = 'you@example.com';
  ```

**Check:** the verification email arrived and used the new template; after verifying you can log in through **Partner Login**; the same email and password log in to the Android app.

---

## Phase 4 — Tests on your machine (optional, about 15 minutes)

This confirms the code before you spend time in provider consoles.

- [ ] Backend: follow [database.md → Local testing](database.md#local-testing), then `python -m pytest backend/tests -q`. Expect 45 passed.
- [ ] Website: `cd frontend && npm ci && npm run build`.
- [ ] App: `cd enchiridion-app/enchiridion && flutter test`. Expect 318 passed.

---

## Phase 5 — Flutterwave in test mode

[payment-provider-setup.md → Part A](payment-provider-setup.md#part-a--flutterwave-website-payments)

- [ ] **A1:** test secret key → backend `FLUTTERWAVE_SECRET_KEY`; test public key → frontend `NEXT_PUBLIC_FLUTTERWAVE_PUBLIC_KEY`.
- [ ] **A2:** Business Preferences → you pay the fees, not the customer.
- [ ] **A3:** webhook `<BACKEND>/api/v1/payments/flutterwave/webhook`, secret hash = first secret from 0.3, which also goes into backend `FLUTTERWAVE_WEBHOOK_SECRET`. Retries on.
- [ ] **A4:** decide about the cancel link in Flutterwave's reminder emails.
- [ ] Redeploy the combined Vercel project.
- [ ] **A6:** subscribe monthly on `/premium` with a test card.

**Check:** the A6 SQL shows `ACTIVE` / `verified` / `processed`; the webhook log in Flutterwave shows 200; cancelling on `/account/subscription` keeps Premium until the period end.

---

## Phase 6 — Android app: identity, signing and first upload

The order matters: Play only creates the app-signing certificate after the first upload, and Google sign-in needs that certificate.

### 6.1 Application ID (permanent)

[payment-provider-setup.md → B1](payment-provider-setup.md#b1-prepare-the-app-one-time-permanent), step 1

- [ ] In `enchiridion-app/enchiridion/android/app/build.gradle.kts`, change `applicationId` from `com.example.enchiridion` to your final ID, e.g. `site.enchiridion.app`. **It can never change after the first upload.**

### 6.2 Release signing

B1, step 2

- [ ] Create an upload keystore and a release `signingConfig` (Flutter's "Build and release an Android app" guide). Back up the keystore and its passwords; losing them means asking Google for a key reset.

### 6.3 Create the app in Play Console

- [ ] Create the app with Play App Signing enabled.
- [ ] Complete the payments profile if asked.
- [ ] Copy the listing URL `https://play.google.com/store/apps/details?id=<APPLICATION_ID>` into frontend `NEXT_PUBLIC_PLAY_STORE_URL`.

### 6.4 Google sign-in: first two certificates

[google-sign-in-setup.md](google-sign-in-setup.md), steps 1–4

- [ ] **Step 1:** create the Google Cloud project you will also use for billing (e.g. `enchiridion-billing`), then set up the consent screen and publish it.
- [ ] **Step 2:** create the Web client and record its ID and secret.
- [ ] **Step 3:** create Android clients for the **debug** and **upload** SHA-1s. The Play signing one comes in 6.6.
- [ ] **Step 4:** enable Supabase's Google provider (Web client ID and secret, nonce check on). Redirect URLs were already added in 1.3.

**Check:** on the website, **Partner Login → Continue with Google** lands on `/dashboard`.

### 6.5 Build and upload to internal testing

```bash
cd enchiridion-app/enchiridion
flutter build appbundle --dart-define=GOOGLE_WEB_CLIENT_ID=<web client id>
```

- [ ] Upload `build/app/outputs/bundle/release/app-release.aab` to **Test and release → Testing → Internal testing**.

Every future build needs that `--dart-define`; without it the Google button is hidden.

### 6.6 Google sign-in: Play signing certificate

- [ ] **Play Console → Test and release → App integrity → App signing:** copy the *App signing key* SHA-1.
- [ ] Google Cloud: add a third Android client with it.

**Check:** install from the internal-testing link; **Continue with Google** on the Log in screen reaches the library. Run the SQL in [google-sign-in-setup.md, step 6](google-sign-in-setup.md#6-test).

---

## Phase 7 — Google Play billing

[payment-provider-setup.md → Part B](payment-provider-setup.md#part-b--google-play-in-app-payments)

### 7.1 Enable the APIs

B3, steps 1–2

- [ ] In the Google Cloud project from 6.4, enable **Google Play Android Developer API** and **Cloud Pub/Sub API**.

### 7.2 Subscription product

B2

- [ ] `enchiridion_premium` with base plans `premium-monthly` (₦1,500) and `premium-annual` (₦15,000), both auto-renewing, grace period on, no offers. Activate both.

### 7.3 Verification service account

B3, steps 3–6

- [ ] Create `play-billing-verifier` with a JSON key, then `base64 -w0` it → backend `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`. Delete the downloaded file.
- [ ] Invite it in Play Console with *View financial data* and *Manage orders and subscriptions*.
- [ ] Backend `GOOGLE_PLAY_PACKAGE_NAME` = `<APPLICATION_ID>`.

Permissions can take several hours (sometimes up to a day) to take effect. Do 7.4 meanwhile.

### 7.4 Real-time notifications

B4

- [ ] Create the `play-rtdn` topic and grant Play's service account *Pub/Sub Publisher* on it.
- [ ] Create the `rtdn-push` service account.
- [ ] Set backend `GOOGLE_RTDN_AUDIENCE` and `GOOGLE_RTDN_SERVICE_ACCOUNT`, then **redeploy**.
- [ ] Create the authenticated push subscription to `<BACKEND>/api/v1/payments/google/notifications`.
- [ ] Connect Play Console to the topic and click **Send test message**.

**Check:** the B4 step 7 SQL shows `verified` / `ignored`.

### 7.5 Test purchases

B5

- [ ] Add license testers and internal testers, and install from the Play link (a sideloaded APK can't buy).
- [ ] Buy monthly with the "always approves" test card.

**Check:** Premium unlocks; `billing.subscriptions` shows `google_play`, `ACTIVE`, with `acknowledged_at` set. Then work through the B5 scenario table.

---

## Phase 8 — Cron and full sandbox run

- [ ] Run the job by hand once:

  ```bash
  curl -H "Authorization: Bearer <CRON_SECRET>" <BACKEND>/api/v1/internal/jobs
  ```

  It should return a JSON summary, not 401.
- [ ] In the combined project, open **Settings → Cron Jobs** and confirm the daily job is listed.
- [ ] Work through all 11 rows of [subscriptions.md → 7. Sandbox test plan](subscriptions.md#7-sandbox-test-plan). Rows 1–6 are the website and rows 7–11 are Android.
- [ ] Confirm the billing emails (activated, cancelled) arrive from your SMTP address.

---

## Phase 9 — Go live

Do these in order, in one sitting.

### 9.1 Decide on the open policy item

- [ ] The app's About screen links to the website, whose menu includes **Premium**. Under Play's anti-steering rules, keep it only if you are comfortable with that; otherwise remove the link ([subscriptions.md → 6](subscriptions.md#6-policy-defaults-restrictive)).

### 9.2 Clear test data

[database.md → Before launch](database.md#before-launch)

> **Warning:** `wipe_application_data.sql` deletes **every account and all data** in the project, including real app users. Run it only if the project has no real users yet. Otherwise, delete your test accounts individually under **Authentication → Users** (their data cascades).

- [ ] Wipe, or delete the test accounts.
- [ ] If you set the QA `v_password`, clear it and re-run the master SQL.
- [ ] Re-run the price check from 1.2.

### 9.3 Flutterwave live

[A7](payment-provider-setup.md#a7-go-live)

- [ ] Switch the dashboard to Live mode.
- [ ] Enter the live keys in the combined Vercel project.
- [ ] Set up the live webhook with the same URL and secret.
- [ ] Re-check the fee setting.
- [ ] Redeploy the combined Vercel project.

### 9.4 Play production

[B6](payment-provider-setup.md#b6-go-live)

- [ ] Complete the Data safety form, mentioning email and purchase history.
- [ ] Re-read the Payments policy pages listed in §14 of the brief.
- [ ] Promote the tested release to **Production**, built with the `--dart-define`.

### 9.5 First real purchase

- [ ] Buy monthly on the website with a real card, then refund it from the Flutterwave dashboard and record the refund:

  ```text
  POST <BACKEND>/api/v1/admin/subscriptions/<subscription id>/refunded
  ```

  Use your admin session.
- [ ] Once the app is live, buy in the app with a real account, then refund and revoke it from Play Console → Order management.

**Check:** each purchase shows Premium on **both** platforms, and each refund removes it.

---

## If something fails

| Symptom | Look at |
| --- | --- |
| `/health/ready` fails | `SUPABASE_DB_URL`: port 6543 and URL-encoded password |
| Website login works but API calls return 401 | `SUPABASE_URL` on the backend, and the website and app using the same project |
| Flutterwave payment succeeds but Premium never appears | The webhook delivery log; Deployment Protection; whether `FLUTTERWAVE_WEBHOOK_SECRET` equals the dashboard secret hash. Run the job by hand (phase 8) to recover it. |
| Customer charged more than ₦1,500 | Flutterwave fee setting (A2); look for `customer_charged_fees` in `billing.payments` |
| App purchase stuck on "confirming" | Service-account permissions are still propagating (7.3), or `GOOGLE_PLAY_PACKAGE_NAME` doesn't match the application ID |
| `rejected` Google rows in `billing.payment_events` | `GOOGLE_RTDN_AUDIENCE` or `GOOGLE_RTDN_SERVICE_ACCOUNT` doesn't exactly match the push subscription |
| Google button missing in the app | The build lacks `--dart-define=GOOGLE_WEB_CLIENT_ID=…` |
| Google sign-in in the app says "developer error" / code 10 | The SHA-1 of the build you installed has no Android client (6.4 / 6.6) |
| Verification emails slow or missing | Supabase custom SMTP (1.3) |
| Anything about one user's Premium | The "Why does this account have Premium?" query in [database.md](database.md#operating-the-billing-data-sql-editor) |
