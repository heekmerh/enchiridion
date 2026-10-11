# Worktree validation — 2026-10-11

Committed the existing website/backend changes together: Supabase authentication and Postgres persistence, Google sign-in, subscription billing, provider callbacks and jobs, current API proxy routes, legal/account pages, deployment documentation and removal of legacy Google Sheets code and obsolete scratch files.

Validation on the final working sources:

- `npx tsc --noEmit`: passed.
- `npm run build`: passed; Next.js static pages and API routes generated successfully.
- Backend pytest suite: 45 passed against a new disposable UTF-8 PostgreSQL instance containing the test Supabase stub and master schema. No production database was accessed; the temporary server was stopped afterward. One existing Starlette/httpx deprecation warning remains.
- `git diff --check` with CRLF handling: passed.
- Pending text files checked for obvious private keys, privileged Supabase tokens and common secret formats; none detected. Environment files remain ignored; templates and dependency lockfiles are committed.

The duplicate website checkout remains archived outside the workspace as recorded in `repository-layout.md`. No files were discarded to achieve a clean worktree; existing removals are recorded in Git. Live provider/deployment checks remain separate. No push was performed.
