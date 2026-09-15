---
quick_id: 260915-r9h
plan: 260915-r9h
subsystem: database
tags: [postgresql, supabase, rls, catalog-verification, read-only]
requires:
  - scripts/sql/001_flagged_questions.sql
  - scripts/sql/002_unique_display_name.sql
  - scripts/sql/003_leaderboard.sql
  - scripts/sql/004_payments.sql
provides:
  - SELECT-only catalog verification for migrations 001–004
  - Python lexical read-only gate with adversarial self-tests
affects: [payments, entitlements, deployment-verification]
tech-stack:
  added: []
  patterns: [catalog-only assertions, exact policy inventory, RPC source digest]
key-files:
  created:
    - scripts/sql/verify_001_004.sql
    - scripts/sql/check_verify_001_004_read_only.py
  modified: []
key-decisions:
  - Verify RPC source digests rather than invoking the functions.
  - Require an exact SELECT/ALL policy count alongside expression and role checks.
actuals:
  tokens: 5048
  tasks: 1
  commits: 1
duration: 6min
completed: 2026-09-15
status: complete
---

# Quick 260915-r9h: Read-only Migration Verification Summary

**One catalog-only SELECT reports 31 named assertions and an overall result for migrations 001–004; a Python gate rejects write-capable SQL before use.**

## Accomplishments

- Checked table keys, cascading foreign keys, indexes, RLS, policy commands/roles/expressions, RPC signatures/security/grants, and the two committed RPC body digests without reading application rows.
- Counted every SELECT/ALL policy on flagged questions, processed payments, and user book access, so an additional permissive policy fails even when the expected policy remains.
- Added a standard-library lexical gate that rejects write tokens inside CTEs, row locks, SELECT INTO, psql commands, dollar quotes, block comments, unknown function calls, and malformed quotes.

## Verification

- `python scripts/sql/check_verify_001_004_read_only.py --self-test scripts/sql/verify_001_004.sql` passed: one safe and 13 unsafe examples; the real file is one SELECT-only statement.
- Independent extraction from migrations 002 and 003 reproduced both RPC body digests exactly.
- `git diff --cached --check` passed before commit; the commit contains exactly the two requested code files and no deletions.
- Live Supabase execution remains the documented operator check after deployment. No operator connection was provided in this execution.

## Task Commit

- Task 1: `392a6bb` — `feat(260915-r9h): add read-only migration catalog verifier`

## Deviations from Plan

None. The planned live-backend check is explicitly a deployment-time human check.

## Known Stubs

None.

## Self-Check: PASSED

Both code files and this summary exist; commit `392a6bb` exists and contains only the two owned files. The automated gate still passes.
