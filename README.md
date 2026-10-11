# Enchiridion Web

Next.js frontend, FastAPI backend, Supabase Postgres persistence, Flutterwave checkout, and the
shared Premium subscription service used by the Enchiridion Android app.
Accounts are **Supabase Auth** users shared with the app: one email and password work on both.
Website records live in the `enchiridion_web` schema and subscriptions in `billing`.
Browser storage holds only the Supabase session, referral attribution, and interface state.

- **Start here — ordered setup runbook (Supabase → Vercel → Flutterwave → Google Play → launch): [docs/setup-runbook.md](docs/setup-runbook.md)**
- Database: [docs/database.md](docs/database.md)
- Premium subscriptions (Flutterwave + Google Play) setup and test plan: [docs/subscriptions.md](docs/subscriptions.md)
- Step-by-step Flutterwave and Google Play console setup: [docs/payment-provider-setup.md](docs/payment-provider-setup.md)
- Step-by-step Google sign-in setup (app and website): [docs/google-sign-in-setup.md](docs/google-sign-in-setup.md)

## Supabase Setup

Use the same Supabase project as the Android app. In the SQL editor, paste and run the whole of
[`supabase/enchiridion_master.sql`](supabase/enchiridion_master.sql). It is the only schema file,
is safe to re-run, and archives the earlier FastAPI Users website schema instead of dropping it.
Then configure Auth as described in [docs/subscriptions.md](docs/subscriptions.md#1-supabase).

Copy the transaction pooler URI from **Connect > Transaction pooler**, using port
6543, into the backend's `SUPABASE_DB_URL`. URL-encode special characters in the
database password. The backend requires TLS and disables prepared statements for
transaction-pooler compatibility. Never place this URI in a `NEXT_PUBLIC_*` variable.
The `enchiridion_web` and `billing` schemas have RLS enabled and grant no browser-role access.

Earlier website accounts (FastAPI Users password hashes) cannot become Supabase Auth logins.
If any real partners registered before this change, ask them to sign up again with the same
email, then copy balances from the archived `legacy_enchiridion_web_*` schema.

## Local Development

Backend:

```bash
cd backend
python3 -m venv venv
source venv/bin/activate
pip install -r requirements-dev.txt
cp .env.example .env
# Fill SUPABASE_DB_URL, SUPABASE_URL, SMTP and Flutterwave/Google test settings in .env.
uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
```

Frontend in a second terminal:

```bash
cd frontend
npm ci
cp .env.example .env.local
# Set the Supabase URL/anon key and the Flutterwave test public key in .env.local.
npm run dev
```

App: http://localhost:3000. API documentation: http://127.0.0.1:8000/docs.
`GET /health/ready` verifies database connectivity and schema availability.
Missing database credentials return errors; there is no mock persistence fallback.
Supabase Auth sends verification and password-reset email; backend SMTP sends billing
notices and the consent-gated offer email. Referral rewards and Premium checkout require a
verified email.

Promote a registered administrator using the Supabase SQL editor:

```sql
UPDATE enchiridion_web.partners SET is_superuser = true
WHERE email = 'your-registered-email@example.com';
```

## Vercel Deployment

Create **two Vercel projects from this repository**:

| Project | Root directory | Framework |
| --- | --- | --- |
| Backend | `backend` | FastAPI |
| Website | `frontend` | Next.js |

The backend exports `app` from `app/main.py`, a supported Vercel entrypoint.
It writes no local files and awaits persistence within the request. Database
transactions commit before successful API responses; connections close afterwards.
Do not set a long-running Uvicorn start command in Vercel.

Backend environment variables:

- `SUPABASE_DB_URL`: your existing project's transaction-pooler URI.
- `SUPABASE_URL` (and `SUPABASE_JWT_SECRET` only for legacy HS256 projects).
- `GOOGLE_PLAY_PACKAGE_NAME`, `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`, `GOOGLE_RTDN_AUDIENCE`,
  `GOOGLE_RTDN_SERVICE_ACCOUNT`, `CRON_SECRET` (see docs/subscriptions.md).
- `FRONTEND_URL=https://enchiridion.site`.
- `CORS_ORIGINS=https://enchiridion.site,https://www.enchiridion.site`.
- `FLUTTERWAVE_SECRET_KEY`, `FLUTTERWAVE_WEBHOOK_SECRET`.
- `BOOK_PRICE_NGN=10000` (existing book price; adjust deliberately).
- SMTP settings from `backend/.env.example`.

Frontend environment variables:

- `BACKEND_URL=https://YOUR-BACKEND-PROJECT.vercel.app` (no trailing API path).
- `NEXT_PUBLIC_FLUTTERWAVE_PUBLIC_KEY`: matching test/live Flutterwave public key.
- `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY`: the shared Supabase project.
- `NEXT_PUBLIC_PLAY_STORE_URL`: the app's Play listing, used after website purchases.

Configure Preview separately with test payment keys and test data. Redeploy the
frontend after changing its public key. Ensure Vercel deployment protection permits
the frontend proxy and Flutterwave webhook to reach the production backend.

## Flutterwave

Configure this webhook URL in Flutterwave:
`https://YOUR-BACKEND-PROJECT.vercel.app/api/v1/payments/flutterwave/webhook`
(the older `/referral/flutterwave/webhook` path is an alias for the same handler).
Set its secret hash to the backend's `FLUTTERWAVE_WEBHOOK_SECRET` and enable retries.
The backend validates HMAC-SHA256 signatures (or the legacy v3 `verif-hash` header),
then independently re-verifies the transaction with Flutterwave's API.

Checkout creates an order in Supabase first. Amounts are in **naira**, not kobo.
Only matching successful NGN payments with the expected reference, email and amount
are accepted. Both the browser callback and webhook use the same idempotent payment
handler. A failed confirmation can be retried without starting another payment.
Guest payments are retained and associated with an account when that email signs up.
Old unsigned payment and mock-credit routes are retired.

## Hostinger Domain

1. Add `enchiridion.site` and `www.enchiridion.site` to the **frontend** Vercel project.
2. In Hostinger's DNS Zone Editor, set the apex A record and the `www` CNAME to the
   exact values Vercel displays for this project. Avoid copying stale generic IPs.
3. Remove only conflicting web A/AAAA/CNAME records. Preserve mail MX, SPF, DKIM,
   verification TXT records, and other unrelated records.
4. Choose `enchiridion.site` as canonical and redirect `www` in Vercel.
5. Wait for Vercel domain verification and HTTPS issuance, then test checkout and
   verification/reset email links on the domain.

You can keep Hostinger as registrar and DNS provider. No nameserver transfer is
required. No Vercel deployment or DNS changes have been made by this code change.

## Verification

```bash
cd backend
python -m pytest tests -q
cd ../frontend
npm run build
```

Persistence and billing tests require a disposable local PostgreSQL database named
`enchiridion_test` built from `backend/tests/supabase_stub.sql` and the master schema
(see docs/database.md).
Set `TEST_DATABASE_URL=postgresql://USER@127.0.0.1:PORT/enchiridion_test` to include
them. These tests clear website tables and reject remote database URLs. Without the
variable they are skipped, while API smoke tests still run.

## References

- [Vercel FastAPI deployment](https://vercel.com/docs/frameworks/backend/fastapi)
- [Supabase database connections](https://supabase.com/docs/guides/database/connecting-to-postgres)
- [Flutterwave transaction verification](https://developer.flutterwave.com/docs/transaction-verification)
- [Flutterwave webhooks](https://developer.flutterwave.com/docs/webhooks)
- [Vercel custom domains](https://vercel.com/docs/domains/working-with-domains/add-a-domain)
