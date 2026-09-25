# Auto-renewing subscriptions — Flutterwave

Written for whoever builds the website checkout at `enchiridion.site`.
Last updated: 25 September 2026.

## 1. Does Flutterwave support it?

**Yes — via Payment Plans.** You create a plan (amount, interval, duration),
then pass the plan id when you first charge a customer; Flutterwave
subscribes them and bills every interval from then on, with no further call
from us.

What you need to design around:

| Fact | Consequence |
| --- | --- |
| A payment plan fixes the payment method to **card**. Bank transfer and USSD cannot auto-renew. | The paywall must offer both an auto-renewing card plan and the existing one-off (transfer/USSD) purchase, or card-only users are the only subscribers. |
| The subscription is bound to the **customer's email** and cannot be moved if that email changes. | Always charge with the Supabase account email. If a user changes their email, cancel and re-subscribe. |
| A failed renewal is retried **3 times at 30-minute intervals**, then the subscription is cancelled automatically. | Handle `subscription.cancelled`; do not assume a lapsed card means a deliberate cancellation. |
| Cancellation happens from the dashboard, the API, or the cancel link in Flutterwave's own reminder emails. | Our "Manage or cancel" page must call the API so the app's state stays truthful, and must keep working even if the user cancelled from an email link — which is exactly what the webhook is for. |
| Billing intervals: hourly, daily, weekly, monthly, quarterly, bi-annually, yearly, or custom (`every 90 days`). | `sub_monthly` → `monthly`, `sub_yearly` → `yearly`. |
| v3 and v4 both offer plans; Flutterwave has announced no v3 deprecation. | The existing `verify-flutterwave-payment` function already uses v3 — stay on v3 for now, in one place. |

For bank accounts rather than cards, Flutterwave also offers **Direct Debit
(NIBSS e-mandate)**, Nigeria/NGN only: the customer authorises a mandate
(they transfer ₦100 to confirm), the token goes Pending → Approved → Active
(up to ~3 hours), and you then charge that token yourself on your own
schedule. It is a second, manual recurring path — Flutterwave does not run
the schedule for you — so treat it as a later addition, not part of v1.

## 2. Division of labour

```text
App (this repo)          Website (enchiridion.site)      Flutterwave
─────────────────        ──────────────────────────      ───────────
paywall → browser   →    /app/subscribe                →  checkout + plan
                         /app/subscription (manage)    →  cancel API
polls Supabase      ←    Supabase (user_book_access,
                         user_subscriptions)
                                  ↑
                         flutterwave-webhook Edge Fn   ←  webhooks
```

The app never talks to Flutterwave. It reads `user_book_access` for the
entitlement (`AccessService`) and `user_subscriptions` for the renewal date
and cancel entry point (`SubscriptionService`). Both tables are readable by
their owner only and writable only by the Edge Functions.

## 3. Already built in this repo

- `scripts/sql/999_MASTER_init.sql` — `user_subscriptions` (the table the
  app polls) and `user_id_for_email()` for resolving a renewal to an account.
  While the app is in development there are no numbered migration files: the
  master script is the whole schema, re-runnable top to bottom.
- `supabase/functions/flutterwave-webhook/index.ts` — verifies the
  `verif-hash` header, re-verifies every charge against Flutterwave with the
  secret key, extends `user_book_access`, and mirrors subscription state.
  Shares the `processed_payments` anti-replay ledger with
  `verify-flutterwave-payment`, so the first charge of a subscription is
  granted exactly once whether the webhook or the app's own verify call
  arrives first.
- App-side disclosure of renewal terms on the paywall, and
  **Profile → Subscription** showing the renewal date with a link to
  `/app/subscription`.

Deploy with:

```bash
supabase functions deploy flutterwave-webhook --no-verify-jwt
supabase secrets set FLUTTERWAVE_SECRET_KEY=<secret key>
supabase secrets set FLUTTERWAVE_WEBHOOK_HASH=<the secret hash from the dashboard>
```

Then point Flutterwave → Settings → Webhooks at
`https://<project-ref>.supabase.co/functions/v1/flutterwave-webhook`
and set the same secret hash there.

## 4. To build on the website

### 4.1 Create the plans (once)

```http
POST https://api.flutterwave.com/v3/payment-plans
Authorization: Bearer FLWSECK-...

{ "amount": 1000,  "name": "Enchiridion Monthly", "interval": "monthly" }
{ "amount": 10000, "name": "Enchiridion Yearly",  "interval": "yearly"  }
```

Store the returned plan ids in website config, keyed by our plan id
(`sub_monthly`, `sub_yearly`). Omit `duration` so the plan runs until
cancelled.

### 4.2 `/app/subscribe`

The app opens this with `user_id`, `email`, `plan`, and `scope` query
parameters. The page must:

1. Confirm the signed-in Supabase user matches `user_id` — never trust the
   query string for who gets access. Send the user to sign in on the website
   if they are not.
2. Show price, billing interval, renewal terms, and the cancellation route
   before the pay button, and link the Terms.
3. Initiate the charge with the account email and, for an auto-renewing
   plan, the Flutterwave plan id:

```json
{
  "tx_ref": "enchiridion-<user_id>-<plan>-<scope>-<timestamp>",
  "amount": 1000,
  "currency": "NGN",
  "payment_plan": "<flutterwave plan id>",
  "customer": { "email": "<account email>" },
  "meta": { "user_id": "<uuid>", "plan_id": "sub_monthly", "book_id": "<scope>" },
  "redirect_url": "https://enchiridion.site/app/subscribe/done"
}
```

`meta` is what lets the webhook attribute a renewal without a signed-in
session — **Flutterwave replays the original `meta` on recurring charges**.
Verify this in the sandbox before launch; if it is absent on renewals, the
webhook falls back to `flw_subscription_id`, then to the billed email, both
of which are already implemented.

4. On return, do not grant anything on the page. Access is granted by the
   Edge Function; the page polls `user_book_access` and the app re-checks
   when it regains focus.

### 4.3 `/app/subscription` (manage & cancel)

Required by the Terms (§6.3) and by Play's subscription rules.

- Show: plan, price, interval, next billing date, status.
- **Cancel** → `PUT /v3/subscriptions/:id/cancel`, then write
  `status='cancelled'`, `auto_renew=false`, `cancelled_at=now()` to
  `user_subscriptions` with the service-role key (or let the resulting
  `subscription.cancelled` webhook do it — but do not rely on it alone for
  the confirmation the user sees).
- State plainly that access continues to the end of the paid period.
- Reachable without being signed in on the app, via a signed-in website
  session, because the cancel route must never depend on the app.

To find the subscription id for a user, either store it when the first
charge's webhook arrives (the Edge Function already does) or call
`GET /v3/subscriptions?email=<account email>`.

### 4.4 Emails

Flutterwave sends its own renewal reminders. Send our own too: purchase
confirmation with the renewal date, price-change notice 30 days ahead
(Terms §6.5), failed-payment notice, and cancellation confirmation.

## 5. Test plan (sandbox)

1. Subscribe with a test card → webhook arrives → `user_book_access` gains
   30 days, `user_subscriptions` shows `active`, app shows the renewal date.
2. Replay the same webhook body → second call returns
   `alreadyProcessed: true`, expiry unchanged.
3. Send a webhook with a wrong `verif-hash` → 401, nothing written.
4. Use a plan with a short interval (`hourly`) to observe a real renewal →
   expiry extends from the existing expiry, not from now.
5. Cancel → `auto_renew=false`, access still valid until period end, then
   gone (the `user_book_access` SELECT policy enforces expiry live).
6. Failing card → 3 retries, then `subscription.cancelled`.
7. Account whose email is not in `auth.users` → webhook answers 200 with
   `No matching account`, nothing granted.

## 6. Before launch: the Google Play question

Play's Payments policy requires Google Play's billing system for in-app
purchases of digital content, with narrow exceptions (including countries
where Play billing is unavailable, and the external-link and alternative-
billing programmes, which carry their own reporting and fee obligations).
Selling app access on our own website and unlocking it in the app is exactly
the pattern that policy governs, and since 2026 Google charges a service fee
on auto-renewing subscriptions regardless of which billing route is used.

Two things to settle in Play Console before shipping:

1. Whether Enchiridion's distribution countries and the seller account's
   country leave us inside an exception, or require enrolment in an external
   payments/alternative billing programme.
2. `lib/services/payment_service.dart` — the in-app Flutterwave checkout —
   is currently **unreferenced dead code**. Leaving it in the binary is
   avoidable risk at review time; delete it or keep it out of release builds
   unless it is deliberately reinstated under a programme that allows it.

## Sources

- [Flutterwave — Payment Plans](https://developer.flutterwave.com/docs/payment-plans-1)
- [Flutterwave — Card tokenization](https://developer.flutterwave.com/docs/tokenization)
- [Flutterwave — Direct Debit (e-mandate)](https://developer.flutterwave.com/docs/direct-debit)
- [Flutterwave — Webhooks](https://developer.flutterwave.com/docs/webhooks)
- [Google Play — Understanding Play's Payments policy](https://support.google.com/googleplay/android-developer/answer/10281818)
- [Google Play — External payment links programme](https://developer.android.com/google/play/billing/externalpaymentlinks)
