# Combined Vercel deployment

The root `vercel.json` deploys the Next.js website and FastAPI backend together.
This is the default setup; the older separate-project instructions are an alternative.

## Import settings

- Repository: `heekmerh/enchiridion`, branch `main`.
- Project name: `enchiridion` (or another available name).
- Root directory: `./`, the directory containing the root `vercel.json`.
- Application preset: **Services**.
- Clear project-wide install, build, and output-directory overrides.
- The frontend service uses `frontend`; the backend service uses `backend`.

Use the checked-in configuration rather than the generated dashboard suggestion.
Vercel must receive the commit containing this file before importing it.

## Environment variables

Add these to the combined project before deployment. Use separate Preview values
with test payments and a non-production database when enabling Preview deployments.

| Variable | Value |
| --- | --- |
| `SUPABASE_DB_URL` | Existing Supabase transaction-pooler URI, port 6543 |
| `SUPABASE_URL` | `https://lvyoqnmqdquadkfixduq.supabase.co` |
| `NEXT_PUBLIC_SUPABASE_URL` | Same Supabase URL |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | Existing public anon key |
| `FRONTEND_URL` | `https://enchiridion.site` |
| `CORS_ORIGINS` | `https://enchiridion.site,https://www.enchiridion.site` |
| `BOOK_PRICE_NGN` | `10000` |
| `CRON_SECRET` | Previously generated cron secret |
| `MAIL_USERNAME` | `hikma@enchiridion.site` |
| `MAIL_PASSWORD` | Existing Hostinger mailbox password |
| `MAIL_FROM` | `hikma@enchiridion.site` |
| `MAIL_SERVER` | `smtp.hostinger.com` |
| `MAIL_PORT` | `587` (backend uses STARTTLS; Supabase retains its working port 465) |
| `MAIL_FROM_NAME` | `Enchiridion` |

Do not manually add `BACKEND_URL`: Vercel injects it through a service binding.
Remove any existing project variable with that name for combined deployment.
Backend database and provider secrets must never use the `NEXT_PUBLIC_` prefix.
Supabase SMTP sends authentication emails; backend SMTP sends billing and offer emails.
Keep the working Supabase Auth settings: signup code, password-reset link, and SMTP.

Payment setup adds `FLUTTERWAVE_SECRET_KEY`, `FLUTTERWAVE_WEBHOOK_SECRET`,
`NEXT_PUBLIC_FLUTTERWAVE_PUBLIC_KEY`, and the Google Play variables documented in
`subscriptions.md`. Set `NEXT_PUBLIC_PLAY_STORE_URL` once the application ID is final.
Checkout and Play verification require their provider credentials before testing.

## Routing

| Public path | Handler |
| --- | --- |
| `/api/v1/*` | FastAPI, including billing, communications, webhooks and cron |
| `/health/*` | FastAPI readiness |
| All other paths | Next.js, including `/api/users/me` and `/api/referral/*` |

The Next.js account/referral API handlers retain their existing path translations
and use the internal `BACKEND_URL` binding. Do not route all `/api/*` requests
straight to FastAPI: those account/referral URLs belong to Next.js.
Binding URLs are generated at runtime for the same deployment, including previews.
Local development can still run Next.js and Uvicorn separately with the frontend
`.env.local` setting `BACKEND_URL=http://127.0.0.1:8000`.

## Deployment checks

1. Confirm the build lists both services and the home page loads.
2. Open `/health/ready`; expect `{"status":"ready","storage":"supabase"}`.
3. Sign up and enter the emailed code on `/verify-email`.
4. Request a password reset and follow its email link to `/reset-password`.
5. Sign in and confirm the account/dashboard API calls succeed.
6. Ensure production Deployment Protection permits public webhooks.
7. Confirm the daily cron appears in project Settings; it calls
   `/api/v1/internal/jobs` at 06:00 UTC with `CRON_SECRET` authentication.

Add `enchiridion.site` and `www.enchiridion.site` to this combined project.
Use its public URL for Flutterwave `/api/v1/payments/flutterwave/webhook`
and Google `/api/v1/payments/google/notifications`. No separate backend domain is needed.
The standalone `backend/vercel.json` remains for the alternative backend-only import;
the combined project's schedule is defined in the root configuration.

## References

- https://vercel.com/docs/services
- https://vercel.com/docs/services/routing
- https://vercel.com/docs/services/bindings
