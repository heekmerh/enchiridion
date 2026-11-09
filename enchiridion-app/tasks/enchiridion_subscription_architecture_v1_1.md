# Enchiridion Subscription Architecture v1.1

**Implementation design and user communication copy**  
**Platforms:** Flutter Android, Web, future iOS  
**Payment providers:** Flutterwave (independent website), Google Play Billing (Android in-app)  
**Nigerian customer-facing prices:** ₦1,500/month; ₦15,000/year, inclusive of applicable taxes and vendor-borne processing fees.

> **Policy checkpoint:** This is an implementation design, not a substitute for checking the live Google Play and Apple policies before release. The Nigerian Play Store app must not route users to Flutterwave checkout unless an applicable, properly enrolled exception permits it. An independently sent, consent-based marketing email should not be designed as a disguised continuation of an in-app checkout flow.

## 1. Goals and constraints

- Support independent website subscriptions using the existing verified Flutterwave merchant account.
- Support Google Play Billing for digital subscriptions initiated in the Android app.
- Share one user identity, subscription domain and entitlement service across platforms.
- Prevent accidental overlapping recurring subscriptions.
- Support renewals, cancellation, expiry, payment failures, refunds and reconciliation.
- Apply platform/storefront-aware purchasing presentation with restrictive policy defaults.
- Verify new accounts by email and offer subscription-plan details via a separate, appropriately consented post-verification email.
- Display exactly ₦1,500 or ₦15,000 to Nigerian customers at checkout, with no vendor-added tax or processing-fee surprises. Independently levied customer bank or card charges are outside direct vendor control and should not be promised away.

## 2. Pricing and products

| Plan | Internal ID | Nigerian customer price | Interval | Benefits |
|---|---|---:|---|---|
| Premium Monthly | `premium_monthly` | ₦1,500 | Monthly | Full Premium |
| Premium Annual | `premium_annual` | ₦15,000 | Annual | Full Premium |

The annual plan saves ₦3,000 against twelve monthly payments (two months at the monthly price). Both plans grant identical Premium entitlements.

**Pricing rules:**

1. Treat Nigerian prices as *final customer-facing, tax-inclusive* amounts.
2. On Android, display localized prices returned by Google Play rather than hardcoding a naira figure into the purchasing UI. Configure the intended Nigerian prices in Play Console and verify the live tax-inclusive offer presentation.
3. On the website, fetch prices from your server. Create immutable, server-side checkout records with currency, price, plan and user identity.
4. Configure Flutterwave payment methods so vendor charges are absorbed. Reject or disable checkout routes that add charges to the amount the customer sees.
5. Store gross receipts, customer tax, provider fee, tax on provider fees, settlement currency, FX and net proceeds separately. Reconcile estimates against provider reports rather than assuming calculations equal actual payouts.

## 3. System architecture

```text
                 INDEPENDENT WEBSITE            PLAY STORE FLUTTER APP
                        |                              |
                 Website pricing                 Play Billing offers
                        |                              |
                 Flutterwave checkout            Google Play checkout
                        |                              |
                 Verified webhooks               Purchase token + RTDN
                        |                              |
                        +------------+-----------------+
                                     |
                               BACKEND API
                                     |
                      +--------------+--------------+
                      |              |              |
                  Identity      Subscriptions   Entitlements
                      |              |              |
                      +--------------+--------------+
                                     |
                                DATABASE
                                     |
                       Protected premium features
```

A modular subscription service inside the existing backend is preferable to introducing independent microservices for this functionality. Provider adapters normalize Flutterwave and Google events without discarding provider-specific lifecycle states. Backend authorization is the source of truth for premium access; cached Flutter flags are never authoritative.

## 4. Region-aware product behavior

Prefer **one Flutter codebase** with region/storefront-aware configuration, not separate applications for every geography. Separate the concepts of:

- **Release distribution:** which app releases are available in particular Play countries and Apple storefronts.
- **Price localization:** localized store prices versus independent website prices.
- **Purchasing permission:** permitted buttons, links and wording according to platform, storefront, approved program enrollment and current policy.

Example restrictive configuration:

```json
{
  "platform": "android",
  "distribution": "google_play",
  "region": "NG",
  "purchasing": {
    "google_play_billing": true,
    "flutterwave_in_app": false,
    "external_checkout_link": false,
    "external_offers_enrolled": false
  }
}
```

Never enable external purchasing merely because a device's IP address, GPS, SIM or language indicates an eligible country. Verify the actual store/program eligibility and use a restrictive default when uncertain. Regional release targeting is not itself authorization to present external checkout links.

| Market | Initial Android purchase interface | External checkout links in app |
|---|---|---|
| Nigeria | Google Play Billing | Disabled |
| Other markets | Google Play Billing | Disabled unless verified eligible and enrolled |
| Specifically approved regions | Program-specific implementation | Only within applicable rules and enrollment |

An independent website can market and sell its own subscriptions to customers who reach it through external channels. Do not build an app registration redirect or disguised account-management link that routes Nigerian Play Store users to website checkout.

## 5. Account creation and email communication

```text
Sign up → send transactional verification email → verify account
                                           |
                                activate free account
                                           |
                             check independent marketing
                              consent and eligibility
                                   /             \
                                 yes              no
                                  |                |
                     send separate offers email   finish onboarding
                                  |
                           website plans page
                                  |
                         Flutterwave checkout
```

- Keep verification transactional and solely about account activation.
- Record marketing consent, source, timestamp, applicable region and unsubscribe preference.
- The optional subscription email must be a separate, independently eligible marketing communication, **not** an automatic circumvention of in-app payment rules or an unavoidable consequence of account verification.
- Store essential transactional-message preferences separately so unsubscribing from offers does not block security messages.
- Do not presume that Apple permits in-app subscription-purchase prompts merely because an external email workflow exists. Review the iOS app classification and relevant storefront rules independently before launch.

### Copy: transactional verification email

**Subject:** Verify your Enchiridion account

Welcome to Enchiridion!

You're almost there. Confirm your email address to finish creating your account.

**[Verify My Email]**

This verification link expires after the validity period shown on the confirmation page. If you didn't create this account, you can ignore this message.

The Enchiridion Team

### Copy: optional post-verification subscription email

**Subject:** Your Enchiridion account is ready. Explore Premium.

Welcome aboard!

Your Enchiridion account is verified and ready to use. You can get started with your free account or explore Premium.

**Monthly: ₦1,500** — Flexible monthly billing.  
**Annual: ₦15,000** — Save ₦3,000 compared with twelve monthly payments.

Both plans include the same Premium access. Applicable taxes and Enchiridion's payment-processing charges are already included in the displayed price.

**[Explore Subscription Plans]**

You can manage your website subscription and cancel future renewals from your account. Already subscribed? Sign in to access your benefits.

The Enchiridion Team

*Include an appropriate unsubscribe mechanism and send this marketing message only where eligible and consented.*

## 6. Website / Flutterwave purchasing flow

1. User independently visits the website and selects `premium_monthly` or `premium_annual`.
2. Authenticate or create an account; check for an existing active subscription and warn against overlapping recurring charges.
3. Backend creates a pending transaction with immutable user ID, plan ID, NGN price, currency and unique transaction reference.
4. Backend creates Flutterwave checkout using the corresponding recurring payment plan where supported.
5. Customer completes payment and returns to a pending verification page. **A browser redirect is not proof of payment.**
6. Verify authentic webhook delivery, then independently query the Flutterwave transaction and compare its status, amount, currency and reference against the pending record.
7. Idempotently save the payment and subscription state, grant Premium access and issue confirmation.
8. Offer **Open Enchiridion** using a verified Android App Link or an installation option from the independent website after successful payment.
9. Reconcile delayed/missed events; handle billing failures, expiry, cancellation and refunds.

Automatic Flutterwave recurring payment methods depend on the available merchant features and eligible payment methods. Where auto-renewal is unavailable, display clear manual-renewal terms instead of promising automatic charges.

**Security:** Keep Flutterwave secret keys server-side. Never accept a browser-supplied price or webhook payload as final payment authority. Require idempotency and audit logging.

## 7. Google Play purchasing flow

1. Sign in to the Android app and query backend entitlements.
2. If no conflicting recurring subscription exists, query available Google Play subscription products and base-plan offers using Flutter's supported `in_app_purchase` integration.
3. Show actual Google-provided localized prices, renewal terms and offer details.
4. Start Google Play Billing for the selected offer.
5. Send the purchase token to the backend; verify the purchase through the Google Play Developer API and validate product, base plan, package and account association. Do not grant access for a pending purchase.
6. Grant Premium following verification and complete required purchase acknowledgment in the allowed period.
7. Subscribe to Google Play Real-time Developer Notifications, authenticate deliveries and query the Developer API for authoritative subscription states.
8. Synchronize renewal, grace period, hold, cancellation, expiry and refund changes with the entitlement service.

**Policy:** For Nigerian Play Store users, show Google Play Billing for digital subscriptions purchased in-app. Do not expose Flutterwave as a competing in-app checkout option or link to it indirectly through registration/help/account flows. Independent website subscribers may sign in and use paid features without repurchasing.

## 8. User-facing subscription screens

### Website pricing page

# Choose Your Premium Plan

Get more out of Enchiridion. Both plans include the same Premium features.

**Monthly — ₦1,500/month**  
Enjoy Premium access with flexible monthly billing.  
**[Subscribe Monthly]**

**Annual — ₦15,000/year**  
Save ₦3,000 compared with twelve monthly payments.  
**[Subscribe Annually]**

**All applicable taxes and Enchiridion processing charges are included. The displayed subscription price is what Enchiridion charges you.**

Payments are processed securely by Flutterwave. Subscriptions renew according to the terms shown before purchase. Cancel future renewals from your account.

Already subscribed? **[Sign in]**

### Nigerian Android Google Play subscription screen

# Unlock Enchiridion Premium

Get more from Enchiridion with Premium.

**Monthly — [Google Play localized monthly price]**  
Flexible monthly billing.  
**[Subscribe Monthly]**

**Annual — [Google Play localized annual price]**  
Save compared with monthly billing where the displayed prices support that claim.  
**[Subscribe Annually]**

Your payment is processed by Google Play. Your subscription renews automatically unless cancelled. Manage or cancel it through your Google Play account.

Already subscribed? **[Sign in]**

*Configure Nigerian offers for the intended final ₦1,500 and ₦15,000 prices, then verify the amounts returned by Play Billing and shown at checkout. Do not display a Flutterwave checkout link on this screen.*

### Reusable account and billing messages

| Event | Copy |
|---|---|
| Purchase verified | Your Premium subscription is active. Enjoy Enchiridion! |
| Payment processing | We're confirming your payment. Premium will activate once verification is complete. |
| Renewal verified | Your Premium subscription has been renewed successfully. |
| Payment failed | We couldn't complete your subscription payment. Please review your payment method with your subscription provider. |
| Cancellation | Your subscription won't renew. Your Premium access remains available until your current paid period ends, subject to your plan terms. |
| Expiry | Your Premium subscription has expired. You can continue using your Free account. |
| Existing subscription | Premium is already active on this account. Manage your existing subscription before starting another. |

Provider-specific management actions should direct Google Play users to Google's subscription-management interface and website subscribers to the independent website's management tools, subject to the applicable platform's rules.

## 9. Database design

| Table | Key fields |
|---|---|
| `users` | User ID, identity provider, verified email, communication preferences |
| `plans` | Plan ID, benefits, billing interval, website display price |
| `provider_plan_mapping` | Internal plan ID, provider, product ID, base-plan/payment-plan ID |
| `subscriptions` | User ID, plan, provider, provider reference, provider state, internal state, current period, access expiry |
| `payments` | Subscription ID, unique transaction reference, amount, currency, verification status, timestamps |
| `entitlements` | User ID, feature, status, effective access expiry |
| `payment_events` | Provider event ID, signature/authentication outcome, processing status, idempotency key |
| `settlements` | Gross receipts, customer tax, processor fee, provider-fee tax, FX, net settlement |

Suggested internal subscription states: `PENDING`, `ACTIVE`, `GRACE_PERIOD`, `PAYMENT_FAILED`, `CANCELLED`, `EXPIRED`, `REFUNDED`. Retain provider-specific states alongside these simplified labels. A cancelled auto-renewal can remain entitled until the paid period ends.

## 10. API contracts

| Method | Route | Purpose |
|---|---|---|
| GET | `/api/v1/subscription/plans` | Website plan catalogue |
| GET | `/api/v1/subscription/current` | Authenticated user's subscription |
| GET | `/api/v1/subscription/entitlements` | Premium feature permissions |
| POST | `/api/v1/payments/flutterwave/checkout` | Server-generated website checkout |
| POST | `/api/v1/payments/flutterwave/webhook` | Authenticated payment events |
| POST | `/api/v1/payments/google/verify` | Backend verification of mobile purchase token |
| POST | `/api/v1/payments/google/notifications` | Verified delivery of Google RTDN messages |
| POST | `/api/v1/subscription/cancel` | Provider-appropriate cancellation, where supported |

Every protected backend feature must verify active entitlements, rather than relying solely on mobile UI controls.

## 11. Fees, tax treatment and settlement

**Business rule:** The Nigerian customer sees and pays ₦1,500/month or ₦15,000/year. Applicable transaction charges borne by Enchiridion reduce merchant proceeds; they must not be added as a checkout surcharge.

For *illustration only*, if customer VAT is included at 7.5%, a 15% Google subscription commission applies to the VAT-exclusive sale, and an additional illustrative 7.5% VAT applies to that commission:

| Item | Monthly | Annual |
|---|---:|---:|
| Customer-facing price | ₦1,500.00 | ₦15,000.00 |
| Included 7.5% customer VAT | ₦104.65 | ₦1,046.51 |
| VAT-exclusive sale | ₦1,395.35 | ₦13,953.49 |
| Illustrative 15% commission | ₦209.30 | ₦2,093.02 |
| Illustrative 7.5% VAT on commission | ₦15.70 | ₦156.98 |
| **Illustrative net proceeds** | **₦1,170.35** | **₦11,703.49** |

These values are a planning model, not a guaranteed Google payout or tax determination. Validate the applicable rate, actual customer tax treatment and settlement figures with current official documentation and merchant reports. Flutterwave net proceeds must be calculated using the actual merchant pricing, selected payment method and applicable taxes, then reconciled against settlements. Income tax and operational expenses are separate from the transaction model.

## 12. Quality, fraud and reliability requirements

- Block accidental concurrent subscriptions across providers where practical, while preserving access to already-paid periods.
- Do not attach one Google purchase token or Flutterwave transaction reference to multiple user accounts.
- Process webhooks and RTDN events idempotently; record and reconcile failed processing attempts.
- Audit subscription transitions, manual overrides, refunds and entitlement changes.
- Refresh entitlements on sign-in, foregrounding and after verified purchase; authorize protected backend calls against server data.
- Show pending-payment status without prematurely granting Premium.
- Support explicit customer-facing cancellation instructions for each provider.
- Make pricing configuration versioned and auditable.
- Test both full-price purchases and any future trial/offer transitions.

## 13. Implementation milestones

| Milestone | Deliverables |
|---|---|
| 1 | Shared identity, subscription entities, provider mappings and entitlement service |
| 2 | Website plans, Flutterwave checkout and verification, renewal/cancellation handling |
| 3 | Email verification, communication consent and separate post-verification offer campaign |
| 4 | Google Play Billing, purchase verification, acknowledgment and RTDN lifecycle synchronization |
| 5 | Region/storefront policy configuration, settlement reconciliation, monitoring and end-to-end testing |

**Release acceptance criteria:**

1. Website and Android purchases both activate the same Premium entitlement for the same authenticated account.
2. Nigerian checkout amounts are exactly ₦1,500 or ₦15,000 through configured, verified payment routes, without added Enchiridion fees.
3. New accounts can verify and use the Free tier without subscribing; marketing offers go only to eligible recipients.
4. Nigerian Play Store screens expose no unauthorized Flutterwave checkout links, redirects or disguised purchase routes.
5. Duplicate, delayed, failed and refunded payment events produce correct final entitlement states.
6. Formatting, static analysis, automated tests and representative end-to-end billing tests pass, with results documented.

## 14. Official reference documents for pre-release checks

- Google Play Payments Policy: https://support.google.com/googleplay/android-developer/answer/9858738
- Google Play consumption-only guidance: https://support.google.com/googleplay/android-developer/answer/10281818
- Google Play service fees: https://support.google.com/googleplay/android-developer/answer/112622
- Google Play Billing integration: https://developer.android.com/google/play/billing/integrate
- Google Play subscription lifecycle: https://developer.android.com/google/play/billing/lifecycle/subscriptions
- Flutterwave developer documentation: https://developer.flutterwave.com/
- Apple App Review Guidelines, section 3.1: https://developer.apple.com/app-store/review/guidelines/
