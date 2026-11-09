# Enchiridion Frontend

See [the repository setup and deployment guide](../README.md) for Supabase,
Flutterwave, Vercel and Hostinger configuration.

```bash
npm ci
cp .env.example .env.local
npm run dev
```

Set `BACKEND_URL` to the FastAPI service and
`NEXT_PUBLIC_FLUTTERWAVE_PUBLIC_KEY` to your Flutterwave test public key.
Database and payment secret keys belong only in the backend environment.

Run `npm run build` to check the production build.
