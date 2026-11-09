# Premium subscriptions — app side

Last updated: 27 September 2026. Supersedes the Flutterwave-in-app / Edge Function design.

The subscription service, database and provider setup live in the website repo:

- Setup, policy defaults and sandbox test plan: `enchiridion-web/docs/subscriptions.md`
- Schema (single master SQL file): `enchiridion-web/supabase/enchiridion_master.sql`
- Brief implemented: `tasks/enchiridion_subscription_architecture_v1_1.md`

## What the app does

| Concern | Where | Behaviour |
| --- | --- | --- |
| Buying | `lib/services/play_billing_service.dart`, `lib/screens/unlock_screen.dart` | Google Play Billing only (`in_app_purchase`). Shows Google's localized prices for base plans `premium-monthly` / `premium-annual` of product `enchiridion_premium`. Passes the Supabase user id as the obfuscated account id. |
| Verifying | `POST https://enchiridion.site/api/v1/payments/google/verify` | Sends the purchase token with the user's Supabase session. The purchase is completed (acknowledged) only after the server has verified and recorded it; pending purchases grant nothing. |
| Entitlement | `lib/services/access_service.dart` | Reads the `get_my_entitlements()` RPC; `premium` maps to the existing full-access scope `*`. Cached for offline use for 7 days, refreshed on sign-in, on returning to the foreground and after a purchase. |
| Status | `lib/services/subscription_service.dart`, Profile → Subscription | Reads `get_my_subscription()`. Google Play subscribers get a button to Google Play's subscription page; website subscribers are told to manage it on the website (no link). |
| Policy | `lib/config/purchasing_policy.dart` | Google Play Billing on Android; Flutterwave in-app, external checkout links and external account-management links off everywhere. Other platforms sell nothing. Guarded by `test/guards/no_external_checkout_guard_test.dart`. |

Website subscribers sign in with the same account and get Premium without repurchasing.

## Removed

- `lib/services/payment_service.dart`, `lib/config/flutterwave_config.dart` and the
  `flutterwave_standard` dependency (in-app Flutterwave checkout).
- The paywall's link to `enchiridion.site/app/subscribe`.
- `supabase/functions/verify-flutterwave-payment` and `supabase/functions/flutterwave-webhook`;
  the website backend now handles every Flutterwave webhook. Undeploy them:
  `supabase functions delete verify-flutterwave-payment` and `supabase functions delete flutterwave-webhook`.
- `scripts/sql/*` and the older migration scripts; see the master SQL file above.

## Before release

- Change `applicationId` from `com.example.enchiridion` (Play rejects it) and set the same value in the
  backend's `GOOGLE_PLAY_PACKAGE_NAME`.
- Create the Play subscription and base plans exactly as named above, or update
  `lib/config/pricing_config.dart` and `billing.provider_plan_mappings` together.
- Terms v1.2 (`docs/legal/terms-and-conditions.md`, bundled as `assets/legal/terms.md`) describe both
  purchase channels; have counsel review before publishing.
