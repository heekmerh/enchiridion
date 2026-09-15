---
quick_id: 260915-r9h
verified: 2026-09-15T19:50:34Z
status: gaps_found
score: 4/5 must-haves verified
gaps:
  - truth: An automated gate rejects every write-capable SQL statement and side-effecting function call.
    status: failed
    reason: Quoted, schema-qualified function identifiers are erased before the function allowlist scan; a side-effecting call is accepted.
    artifacts:
      - path: scripts/sql/check_verify_001_004_read_only.py
        issue: executable_sql blanks double-quoted identifiers, and CALL cannot see the hidden function name.
    missing:
      - Preserve and validate quoted identifiers in function-call positions, or reject quoted identifiers entirely; add the bypass to self-tests.
---

# Quick 260915-r9h Verification

**Goal:** Provide a read-only catalog verifier for migrations 001–004, with a repeatable SQL safety gate.
**Status:** gaps_found. One safety promise fails, so the operator should not rely on the gate until fixed.

## Observable truths

| Truth | Status | Codebase evidence |
| --- | --- | --- |
| One post-deployment SELECT reports named pass/fail results for 001–004 | VERIFIED structurally | `verify_001_004.sql` has one `WITH ... SELECT`, 31 named assertions, and an OVERALL row; the checker accepts it. Live output requires the operator connection. |
| Missing or changed keys, indexes, policies, and RPC contracts are detected through catalogs without reading application rows | VERIFIED structurally | Assertions read `pg_class`, `pg_constraint`, `pg_index`, `pg_policy`, and `pg_proc`; absent objects make positive `EXISTS` checks false. |
| Automated gate rejects every write-capable statement and side-effecting function call | FAILED | `check('SELECT "pg_catalog"."pg_sleep"(1);')` returns 1 instead of raising `UnsafeSQL`. |
| Additional SELECT/ALL policies and substituted RPC bodies fail checks | VERIFIED structurally | Exact policy inventories use `count(*) = 1`; `pg_proc.prosrc` MD5 constants independently match migration 002 (`802aacb921fc4d991a9855564ca633e6`) and 003 (`d1821041253e750bf7bec157fcb5c208`). |
| Verification SQL has no schema changes, credentials, application-row reads, or writes | VERIFIED | The checked file contains one catalog-only `WITH ... SELECT`; no connection string or credential is embedded. |

The two required artifacts exist, are substantive, and are wired through the documented command and the checker's default SQL-file path. Catalog assertions are wired to the expected objects in migrations 001–004. The `user_book_access` expiry assertion inspects `pg_policy.polqual`, matching the policy installed by 004, rather than reading entitlement rows.

## Behavioral checks

`python scripts/sql/check_verify_001_004_read_only.py --self-test scripts/sql/verify_001_004.sql` passed: 1 safe and 13 unsafe in-memory examples; the real SQL file passed as one SELECT statement. An independent in-memory bypass test accepted `SELECT "pg_catalog"."pg_sleep"(1);`, which is a side-effecting function outside the allowlist. This is a reproducible blocker despite the bundled self-test passing.

## Human verification

With an existing deployed database connection, run the SQL file through Supabase SQL Editor or `psql -X -v ON_ERROR_STOP=1 -f scripts/sql/verify_001_004.sql`. Every named row and OVERALL should return `passed=true` on the expected applied schema. No operator connection was available for this verification, so live catalog behavior remains unobserved.

## Gap

The scanner blanks double-quoted identifiers at `check_verify_001_004_read_only.py:86–94`, then checks function names at lines 123–126. A schema-qualified function with both identifiers quoted therefore becomes punctuation and escapes the allowlist. Reject quoted executable identifiers or parse and validate them, then add a regression example before using the gate as an operator safety assurance.

_Verifier: gsd-verifier; no code changes or commits made._
