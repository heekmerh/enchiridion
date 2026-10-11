# Flutterwave and Google Play: step-by-step setup

Follow this once in **test mode**, run the tests in Part C, then repeat the marked
steps with live credentials. Everything you create here plugs into values the
backend already reads, listed in Part D.

Before you start, have these ready:

- The backend's public URL, e.g. `https://enchiridion-api.vercel.app`. Below it is written `<BACKEND>`.
- Access to the backend Vercel project's **Settings → Environment Variables**.
- The master SQL already run in Supabase (see [database.md](database.md)).

Generate one random secret now; you will paste it in two places:

```bash
openssl rand -hex 32
```

---

## Part A — Flutterwave (website payments)

### A1. API keys

1. Log in to the Flutterwave dashboard and switch to **Test mode** (toggle at the top).
2. Open **Settings → API Keys**.
3. Copy the **Secret key** into the backend variable `FLUTTERWAVE_SECRET_KEY`. It must never go in the frontend.
4. Copy the **Public key** into the frontend variable `NEXT_PUBLIC_FLUTTERWAVE_PUBLIC_KEY`. Only the book checkout uses it.

### A2. Make Enchiridion pay the fees

Flutterwave's default is that the **customer pays the transaction fee**, which would charge more than ₦1,500 / ₦15,000.

1. Open **Settings → Business Preferences**.
2. Turn **off** the option to pass transaction charges to customers.
3. Under International Processing Fees, do **not** choose "Charge my customers".
4. Save.

VAT on Flutterwave's own fee is always charged to you and cannot be passed on. The backend flags any payment where the customer was charged more than the price (`customer_charged_fees` in `billing.payments.provider_details`). If you ever see that flag, this setting has been changed.

### A3. Webhook

1. Open **Settings → Webhooks**.
2. **URL:** `<BACKEND>/api/v1/payments/flutterwave/webhook`
3. **Secret hash:** paste the random secret you generated. Put the same value in the backend variable `FLUTTERWAVE_WEBHOOK_SECRET`.
4. Tick all the event checkboxes, including **webhook retries**. Flutterwave then retries 3 times, 30 minutes apart, whenever the backend doesn't answer 200.
5. Save.

This one URL serves both book orders and Premium. Flutterwave allows only one webhook URL per mode, and the old `/referral/flutterwave/webhook` path still works as an alias.

If Vercel **Deployment Protection** is on for the backend's production domain, Flutterwave's calls get blocked. Turn it off for production, or use a protection bypass.

### A4. Subscription reminder emails

Flutterwave emails subscribers before each renewal and, by default, those emails include a cancel link. You can leave it or disable it under **Settings → Account Settings**. If a customer cancels through it, Flutterwave sends `subscription.cancelled` and the backend marks the subscription cancelled; access continues to the end of the paid period.

### A5. Payment plans: nothing to create

The backend creates a Flutterwave payment plan automatically the first time someone checks out at each price. It then appears under **Payment Plans** as, for example, "Enchiridion Premium Monthly (₦1,500)".

- **Don't** edit plan amounts in the dashboard.
- To change a price, run `select billing.set_plan_price('premium_monthly', 'NGN', <amount>, '<reason>');` in Supabase. New checkouts get a new plan; existing subscribers keep the price they signed up at.

### A6. Test (test mode)

1. Deploy the backend and website with the test keys.
2. Sign up on the website, verify your email, open `/premium` and subscribe monthly with a Flutterwave **test card**; the list is in Flutterwave's docs under Testing.
3. You should land on `/premium/processing`, then see "Your Premium subscription is active".
4. In the Flutterwave dashboard, open the transaction and check its webhook delivery log shows **200**.
5. In Supabase:

   ```sql
   select internal_state, auto_renewing, access_expires_at from billing.subscriptions order by created_at desc limit 1;
   select event_type, authentication, processing_status from billing.payment_events order by received_at desc limit 3;
   ```

   Expect `ACTIVE`, `true`, a date a month away, and `verified` / `processed`.
6. Sign in to the Android app with the same account; it should show Premium.
7. Cancel from `/account/subscription`. The status should read "Cancelled — will not renew", with Premium kept until the period end.

### A7. Go live

1. Switch the dashboard to **Live mode**.
2. Repeat **A1** with the live keys.
3. Repeat **A3**, because live mode has its own webhook settings.
4. Re-check **A2**.
5. Update the Vercel variables and redeploy both projects.

---

## Part B — Google Play (in-app payments)

### B1. Prepare the app (one time, permanent)

1. **Pick the final application ID.** In `enchiridion-app/enchiridion/android/app/build.gradle.kts`, change `applicationId = "com.example.enchiridion"` to your own reverse domain, e.g. `site.enchiridion.app`.
   - Play rejects `com.example.*`, and the ID can never change after the first upload.
   - Leave `namespace` as it is; changing it would mean moving the Kotlin files.
2. **Release signing.** The release build is still signed with the debug key; the file has a `TODO` saying so. Create an upload keystore and a signing config, following Flutter's "Build and release an Android app" guide, and enrol in **Play App Signing** when you create the app.
3. Build the bundle: `cd enchiridion && flutter build appbundle`.
4. In Play Console, create the app if it doesn't exist.
5. Open **Test and release → Testing → Internal testing**, create a release, and upload the `.aab`.
   - Play only lets you create subscriptions after a build with the billing permission is uploaded. The `in_app_purchase` plugin adds that permission automatically.
6. If Play Console asks for a **payments profile** (merchant account) before you can sell, complete it.

### B2. Create the subscription

1. Open **Monetize with Play → Products → Subscriptions → Create subscription**.
2. **Product ID:** `enchiridion_premium` (permanent). **Name:** Enchiridion Premium. Save.
3. **Add base plan:**
   - **Base plan ID:** `premium-monthly`
   - **Type:** Auto-renewing
   - **Billing period:** Monthly
   - **Grace period:** e.g. 7 days. Users keep Premium while Google retries the payment; the backend treats this as `GRACE_PERIOD`.
   - **Account hold:** leave the default. Premium is removed while on hold.
   - **Prices:** open **Set prices**, set Nigeria to **₦1,500**, and let Play convert the other countries (or untick the countries you don't sell in).
   - Save, then **Activate**.
4. Add a second base plan: `premium-annual`, auto-renewing, **Yearly**, Nigeria **₦15,000**. Activate it.
5. **Don't add offers** (free trials, intro prices) for now. The app only shows the plain base plans, so an offer wouldn't appear until the app is changed to support it.

These IDs match `lib/config/pricing_config.dart` and the rows the master SQL seeded in `billing.provider_plan_mappings`. If you use different IDs, change both places; [database.md](database.md) has the SQL.

After you sell, check what a Nigerian test account actually sees at checkout. The app shows Google's localized price, so confirm it reads ₦1,500 / ₦15,000 with tax included.

### B3. Google Cloud project and the verification service account

1. At [console.cloud.google.com](https://console.cloud.google.com), create a project, e.g. `enchiridion-billing`.
2. Open **APIs & Services → Library** and enable **Google Play Android Developer API** and **Cloud Pub/Sub API**.
3. Open **IAM & Admin → Service accounts → Create service account**.
   - Name: `play-billing-verifier`. Grant it no project roles.
   - Open it, then **Keys → Add key → Create new key → JSON**. A file downloads.
4. Turn the key into one line and put it in the backend variable `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`. Then delete the downloaded file.

   ```bash
   base64 -w0 play-billing-verifier-key.json
   ```

5. In **Play Console → Users and permissions → Invite new users**:
   - **Email:** the service account address (`play-billing-verifier@<project-id>.iam.gserviceaccount.com`).
   - **App permissions → Add app →** Enchiridion. Grant:
     - **View financial data, orders, and cancellation survey responses**
     - **Manage orders and subscriptions**
   - Click **Invite user**. The permission can take some hours to start working.
6. Set the backend variable `GOOGLE_PLAY_PACKAGE_NAME` to the application ID from B1.

### B4. Real-time developer notifications (RTDN)

These tell the backend about renewals, cancellations, payment failures and refunds.

1. **Create the topic.** In **Pub/Sub → Topics → Create topic**, set Topic ID `play-rtdn`. Untick "Add a default subscription".
2. **Let Google Play publish to it.** Open the topic, then **Permissions → Add principal**:
   - Principal: `google-play-developer-notifications@system.gserviceaccount.com`
   - Role: **Pub/Sub Publisher**
   - Save.
3. **Create the push identity.** Create a second service account `rtdn-push` in **IAM & Admin → Service accounts**. It needs no roles and no key.
4. **Configure the backend first**, then redeploy it, so the test in step 6 is accepted:
   - `GOOGLE_RTDN_AUDIENCE=<BACKEND>/api/v1/payments/google/notifications`
   - `GOOGLE_RTDN_SERVICE_ACCOUNT=rtdn-push@<project-id>.iam.gserviceaccount.com`
5. **Create the push subscription.** In **Pub/Sub → Subscriptions → Create subscription**:
   - Topic: `play-rtdn`
   - Delivery type: **Push**
   - Endpoint URL: `<BACKEND>/api/v1/payments/google/notifications`
   - Tick **Enable authentication** and pick the `rtdn-push` service account.
   - Audience: the same endpoint URL. It must equal `GOOGLE_RTDN_AUDIENCE` exactly.
   - If the console says the Pub/Sub service agent needs the *Service Account Token Creator* role, grant it.
   - Retry policy: *Retry after exponential backoff delay*. Create.
6. **Connect Play to the topic.** In **Play Console → Monetize with Play → Monetization setup → Real-time developer notifications**:
   - Tick **Enable real-time notifications**.
   - Topic name: `projects/<project-id>/topics/play-rtdn`
   - Notification content: **Get notifications for subscriptions and all voided purchases**.
   - Click **Send test message**, then **Save changes**.
7. **Confirm it arrived** by running this in Supabase:

   ```sql
   select authentication, processing_status, received_at
   from billing.payment_events where provider = 'google_play' order by received_at desc limit 1;
   ```

   Expect `verified` / `ignored` (test messages are acknowledged and ignored). If nothing arrived, open the Pub/Sub subscription's metrics for errors. A `rejected` row in `billing.payment_events` means the audience or the service-account email doesn't match the backend variables.

### B5. Test purchases

1. **Settings → License testing:** add the Gmail accounts you'll test with, and set the licence response to *RESPOND_NORMALLY*.
2. **Internal testing → Testers:** add the same accounts and open the opt-in link on the test phone. Install the app **from the Play Store link**; a locally built debug APK can't buy.
3. Sign in to the app, open any locked content, and choose **Subscribe Monthly**. Pick Play's **test card, always approves**.
   - Premium should unlock and the snackbar should read "Your Premium subscription is active. Enjoy Enchiridion!".
   - `billing.subscriptions` should show `google_play`, `ACTIVE`, with `acknowledged_at` set.
4. Test subscriptions renew fast. A monthly plan renews every **5 minutes** and a yearly plan every **30 minutes**, up to six times. Watch the new rows in `billing.payment_events` and `billing.payments`.
5. The remaining scenarios:

| Try | Expect |
| --- | --- |
| Test card **"slowly approves"** | App says "We're confirming your payment…", no Premium until it clears |
| Test card **"always declines"** | Error shown, nothing granted |
| Cancel in Play Store → Subscriptions | Profile shows "Will not renew", Premium until period end, then removed |
| Play Console → Order management → **Refund** with *Revoke* | Subscription becomes `REFUNDED`, Premium removed |
| Buy on the website first, then open the app's paywall | "Premium is already active on this account…", no purchase buttons |
| Same Google account, different Enchiridion account → Restore | "This Google Play subscription is linked to another Enchiridion account…" |

### B6. Go live

1. Promote the tested release from Internal testing to **Production**. Subscriptions are shared across tracks.
2. Complete the store listing's **Data safety** form so it mentions purchase history and email.
3. Re-check the Payments policy (the brief's section 14 links) before submitting.

---

## Part C — Scheduled job and email

1. In the backend Vercel project, set `CRON_SECRET` to another `openssl rand -hex 32` value.
   - The cron in `backend/vercel.json` runs `/api/v1/internal/jobs` daily.
   - It recovers missed webhooks, refreshes Google subscriptions and retries acknowledgements, expires lapsed website plans, and sends queued emails.
2. Set the `MAIL_*` variables so the backend can send purchase, renewal, failure, cancellation and expiry emails.

To run the job by hand at any time:

```bash
curl -H "Authorization: Bearer $CRON_SECRET" <BACKEND>/api/v1/internal/jobs
```

## Part D — Where each value goes

| Value | Vercel project | Variable |
| --- | --- | --- |
| Flutterwave secret key | backend | `FLUTTERWAVE_SECRET_KEY` |
| Flutterwave webhook secret hash | backend | `FLUTTERWAVE_WEBHOOK_SECRET` |
| Flutterwave public key | frontend | `NEXT_PUBLIC_FLUTTERWAVE_PUBLIC_KEY` |
| App's application ID | backend | `GOOGLE_PLAY_PACKAGE_NAME` |
| `play-billing-verifier` JSON key (base64) | backend | `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` |
| Push endpoint URL | backend | `GOOGLE_RTDN_AUDIENCE` |
| `rtdn-push` service account email | backend | `GOOGLE_RTDN_SERVICE_ACCOUNT` |
| Play listing URL | frontend | `NEXT_PUBLIC_PLAY_STORE_URL` |
| Cron secret | backend | `CRON_SECRET` |

Redeploy after changing any variable; Vercel doesn't apply them to running deployments.
