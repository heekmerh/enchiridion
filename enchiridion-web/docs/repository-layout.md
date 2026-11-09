# Repository layout

The workspace contains two active Git repositories:

- `enchiridion-app/`: the Flutter application.
- `enchiridion-web/`: the Next.js website, FastAPI backend and shared web/database setup.

Use `enchiridion-web/` for all website development. App and web retain independent Git history, branches and worktree state.

## Duplicate website checkout archive

On 2026-10-11, the duplicate `website/enchiridion/` checkout was moved intact to:

`/home/kaasor/Documents/Backup/Hikma/Enchiridion-archives/2026-10-11-duplicate-website-checkout`

Both checkouts pointed to `https://github.com/heekmerh/enchiridion.git`. The archived checkout was on `asor/prod` at `2c284c9`; the active checkout is on `main`. The archive retains its complete `.git` directory, all local branches/commits, modified/deleted/untracked files, environment files, assets and historical GSD planning documents. Its worktree status and non-generated file hashes were verified unchanged after relocation.

The archived implementation uses legacy Google Sheets persistence, FastAPI Users authentication and an older combined Vercel setup. The active implementation uses Supabase Auth/Postgres, the current payment/subscription architecture and current authentication routes. Archived UI differences largely add lint suppressions and delayed state updates. These were retained in the archive rather than replacing current code.

The old `.planning/PROJECT.md` explicitly excluded migration from Google Sheets. Keep it as historical context in the archive; use the active README and setup runbook for current implementation guidance.

No active website source, environment settings or pre-existing staged changes were changed during consolidation. Existing uncommitted app and web work remains uncommitted. This consolidation does not establish a clean worktree.

## Recovery

Inspect the archive directly with `git -C <archive-path> status` or `git -C <archive-path> log`. To recover an individual file, compare its archived contents with the active file before copying it. The full archived checkout can be moved back to an alternate directory if needed; avoid recreating a second active website checkout under this workspace.

The private archive manifest is stored alongside the archive at `2026-10-11-website-archive-manifest.json`.
