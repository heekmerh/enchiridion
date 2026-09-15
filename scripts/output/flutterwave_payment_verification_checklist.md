# Flutterwave payment verification: deployment and test checklist

This is a source audit, not evidence that the backend is configured. Use a separate test project and Flutterwave test transactions; do not use live charges or put key values in this document.

## Current source-visible state

- [ ] Replace the client `FLWPUBK_TEST-REPLACE_ME-X` placeholder with the matching Flutterwave **test public** key before test checkout. `flutterwaveIsTestMode` is `true`, `flutterwaveCurrency` is `NGN`, and the redirect URL `https://enchiridion.app/payment-complete` is syntactically valid; the checkout package intercepts it, so the page need not be reachable.
- [ ] Confirm the authenticated `PaymentService` checkout returns a `transaction_id` and sends **only that ID** through `Supabase.instance.client.functions.invoke('verify-flutterwave-payment')`. The function gets the caller from the forwarded Authorization session, verifies Flutterwave's successful status, NGN currency, amount and metadata, then uses the Supabase service role to insert `processed_payments` and upsert `user_book_access`. A `granted=true` response triggers an `AccessService.loadAccess()` reload.
- [ ] Keep these three client prices synchronized with the function's `PLAN_PRICES` table. The source values currently match:

  | PricingPlan ID | Client amount (NGN) | Client accessDays | Function amount (NGN) | Function accessDays |
  | --- | ---: | ---: | ---: | ---: |
  | `book_monthly` | 1,000 | 30 | 1,000 | 30 |
  | `sub_monthly` | 1,000 | 30 | 1,000 | 30 |
  | `sub_yearly` | 10,000 | 365 | 10,000 | 365 |

## Deployment prerequisites (operator checks; unchecked)

- [ ] In the **test** Supabase project, confirm the `verify-flutterwave-payment` Edge Function is deployed and its server environment has `FLUTTERWAVE_SECRET_KEY` set to the matching Flutterwave **test secret** key. Confirm `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are available to the function; keep secret/service-role values server-side. Repository files cannot prove deployment or any secret is set.
- [ ] Confirm `000_init_database.sql` established `user_book_access` with unique `(user_id, book_id)` and RLS, then confirm `004_payments.sql` was actually applied. Inspect the live test schema/policies: `processed_payments.transaction_id` is its primary key, both tables have RLS enabled, `processed_payments` permits only the owner's SELECT, neither table grants client INSERT/UPDATE/DELETE, and `user_book_access` permits only the owner's **granted** rows whose `expires_at` is null or in the future. The function's service role performs the writes; `AccessService` sees expiry through that SELECT policy. The SQL files alone cannot prove these live conditions.
- [ ] Verify the app is pointed at the intended test Supabase project and the public/test key and server/test secret belong to the same Flutterwave test account before enabling checkout.

## Test-mode verified grant and replay (no real charges)

- [ ] With one authenticated test user, choose an intended book for `book_monthly`, or `'*'` for a subscription plan. Complete a successful **NGN** Flutterwave test checkout at the matching price; retain its returned `transaction_id` for this test only. Invoke verification through the authenticated client/function path and observe first response `granted=true` (without `alreadyProcessed=true`).
- [ ] In the test database, observe exactly one `processed_payments` row for that `transaction_id` and user, plan, amount, currency and intended scope. Observe one `user_book_access` row for that user/book or `'*'`, with `granted=true` and an expiry about 30 or 365 days after the later of now or any existing expiry. Reload `AccessService`; confirm the intended book/full scope is visible. For an expired row, confirm a fresh reload hides it.
- [ ] Repeat the **same** `transaction_id` with the **same authenticated user**. Expect `granted=true` and `alreadyProcessed=true`; verify the ledger still has exactly one row and `user_book_access.expires_at` is unchanged. Do not treat the response alone as proof of idempotence or a grant.
- [ ] In test mode, check a missing/unauthenticated session is rejected, a failed or non-successful transaction is not granted, and wrong currency, amount **below** the selected plan price, or present metadata `user_id` differing from the caller is not granted. Inspect both tables after each negative case for no new ledger row or access extension. Also test a missing metadata user ID and a plan/book scope mismatch before release; current code does not reject these consistently.

## Open code findings (not fixed by this checklist)

- Any `processed_payments` insert error is returned as `granted=true, alreadyProcessed=true`, even if it is **not** a duplicate-key violation; this can report a false success. A duplicate transaction from another user is likewise not checked against the stored ledger owner/scope before that response.
- The ledger insert and access upsert are separate operations. If the upsert fails after insert, a ledger row remains; retrying the same `transaction_id` can return `alreadyProcessed=true` although no access was granted.
- Verified Flutterwave metadata `user_id` is optional, and `plan_id` is not bound to an allowed `book_id` scope. A transaction with absent user metadata or an inappropriate plan/book pairing can be claimed for a different user or scope; `book_id` also defaults to `'*'` when absent.
- The verified transaction's `tx_ref` is never compared with the caller, plan, or requested book scope. The checkout constructs a reference containing those fields, but verification does not use it to bind the grant.
