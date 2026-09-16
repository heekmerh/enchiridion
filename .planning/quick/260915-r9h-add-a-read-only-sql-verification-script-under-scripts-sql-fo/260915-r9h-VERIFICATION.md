---
quick_id: 260915-r9h
verified: 2026-09-16T14:52:38Z
status: human_needed
score: 4/5 must-haves verified
covered_files:
  - .planning/quick/260915-r9h-add-a-read-only-sql-verification-script-under-scripts-sql-fo/260915-r9h-PLAN.md
  - .planning/quick/260915-r9h-add-a-read-only-sql-verification-script-under-scripts-sql-fo/260915-r9h-SUMMARY.md
  - scripts/sql/000_init_database.sql
  - scripts/sql/001_flagged_questions.sql
  - scripts/sql/002_unique_display_name.sql
  - scripts/sql/003_leaderboard.sql
  - scripts/sql/004_payments.sql
  - scripts/sql/check_verify_001_004_read_only.py
  - scripts/sql/verify_001_004.sql
covered_digest: "v1:sha256:ce259ecba41ac03b086859c90df28d676ace594f93673bd8bd7fc3fb62e0ace9"
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 4/5
  gaps_closed:
    - Quoted, schema-qualified pg_catalog.pg_sleep bypassed the function allowlist.
  gaps_remaining: []
  regressions: []
human_verification:
  - test: Run scripts/sql/verify_001_004.sql against deployed Supabase PostgreSQL through an existing operator connection.
    expected: Every named assertion for migrations 001–004 and the OVERALL row returns passed=true on the expected applied schema; drift produces a false row.
    why_human: No live operator database connection was available, so query execution and deployed catalog values could not be observed.
---

# Quick 260915-r9h Verification

**Goal:** Provide a read-only catalog verifier for migrations 001–004, with a repeatable SQL safety gate.
**Status:** human_needed. The original safety gap is closed by commit `1187b87`; the deployed catalog query still requires an operator connection.
**Re-verification:** Yes, after gap closure.

## Observable truths

| Truth | Status | Codebase evidence |
| --- | --- | --- |
| One post-deployment SELECT reports named pass/fail results for 001–004 | ? UNCERTAIN | `verify_001_004.sql:1–4` documents SQL Editor and `psql` execution. Lines 26–221 define 31 named boolean assertions (001: 10, 002: 5, 003: 4, 004: 12) plus OVERALL; the gate accepts one SELECT statement. All rows passed in a temporary PostgreSQL 16 fixture using the actual migrations, but the deployed query was not run. |
| Missing or changed keys, indexes, policies, and RPC contracts are detected through catalogs without reading application rows | VERIFIED structurally | Assertions read `pg_class`, `pg_constraint`, `pg_index`, `pg_policy`, and `pg_proc`; absent objects make positive `EXISTS` checks false. |
| Automated gate rejects every write-capable statement and side-effecting function call | VERIFIED | `check_verify_001_004_read_only.py:56–59` rejects double-quoted executable identifiers before token/function scanning. Independent checks reject the original quoted `pg_sleep` bypass, other quoted variants, DML CTEs, SELECT INTO, row locks, DDL, and unapproved calls. |
| Additional SELECT/ALL policies and substituted RPC bodies fail checks | VERIFIED structurally | Exact policy inventories use `count(*) = 1`; `pg_proc.prosrc` MD5 constants independently match migration 002 (`802aacb921fc4d991a9855564ca633e6`) and 003 (`d1821041253e750bf7bec157fcb5c208`). |
| Verification SQL has no schema changes, credentials, application-row reads, or writes | VERIFIED | The checked file contains one catalog-only `WITH ... SELECT`; no connection string or credential is embedded. |

The two required artifacts exist, are substantive, and are wired through the documented command and the checker's default SQL-file path. Catalog assertions are wired to the expected objects in migrations 001–004. The `user_book_access` expiry assertion inspects `pg_policy.polqual`, matching the policy installed by 004, rather than reading entitlement rows.

**Score:** 4/5 truths verified. The first truth remains uncertain because live PostgreSQL execution has not been observed; all five are structurally present and the query ran successfully against a local fixture. No behavior-dependent state-transition truth is untested.

## Artifact, link, and data-flow evidence

| Artifact or link | Status | Evidence |
| --- | --- | --- |
| `scripts/sql/verify_001_004.sql` | EXISTS, SUBSTANTIVE, WIRED | 221 lines; 31 catalog assertions plus OVERALL. Its header documents the operator path and the gate command. |
| `scripts/sql/check_verify_001_004_read_only.py` | EXISTS, SUBSTANTIVE, WIRED | 168 lines; lexical scan, statement and function checks, fail-closed errors, active self-test, and CLI entry point. It checks the SQL file by default or by path. |
| Migrations 001–004 → catalog assertions | WIRED | Keys, indexes, RLS, policy definitions, RPC contracts and permissions map to `pg_class`, `pg_constraint`, `pg_index`, `pg_policy`, and `pg_proc`. Positive `EXISTS` predicates fail on missing objects. |
| Migration 004 expiry policy → `user_book_access` assertion | WIRED | SQL lines 204–210 inspect `pg_policy.polqual` via `pg_get_expr`, requiring caller user, granted state, and null-or-future expiry. |
| Migration RPC bodies → source-digest assertions | WIRED | Independent normalization of migrations 002 and 003 produced `802aacb921fc4d991a9855564ca633e6` and `d1821041253e750bf7bec157fcb5c208`, exactly the constants at SQL lines 121–122 and 149–150. |

Catalog rows flow through the `assertions.passed` booleans to named output and `bool_and(passed)` OVERALL. There is no static success return or application-row query.

## Behavioral checks

`python scripts/sql/check_verify_001_004_read_only.py --self-test scripts/sql/verify_001_004.sql` passed: 1 safe and 15 unsafe in-memory examples; the real SQL file passed as one SELECT statement. An independent 18-case check matched every expected accept/reject result. It rejected the original quoted `pg_catalog.pg_sleep` bypass; quoted schema/function variants; comments; case and whitespace variations; a data-modifying CTE; SELECT INTO; row locking; and DDL. It accepted ordinary quoted string literals and a harmless catalog SELECT. Independent assertion enumeration found 31 checks; independent migration-body extraction reproduced both SQL digest constants.

No probe is declared for this quick item. The self-test has active fixed assertions and does not generate expected values from the gate. No disabled requirement-linked tests, circular fixtures, debt markers, or stub implementations were found in the two changed files. No phase-specific requirement IDs or CONTEXT decisions were supplied. The re-verification anti-pattern advisory set is empty.

## Human verification

With an existing deployed database connection, run the SQL file through Supabase SQL Editor or `psql -X -v ON_ERROR_STOP=1 -f scripts/sql/verify_001_004.sql`. Every named row and OVERALL should return `passed=true` on the expected applied schema. No operator connection was available for this verification, so live catalog behavior remains unobserved.

## 2026-09-16 PostgreSQL regex correction

The first live attempt reported PostgreSQL `2201B: invalid regular expression: quantifier operand invalid`. Five policy patterns had doubled backslashes inside ordinary SQL string literals. With standard-conforming strings, those backslashes reach the regex engine unchanged; the patterns now use single backslashes for escaped parentheses and dots.

The corrected script passed the local read-only gate. It ran on a temporary PostgreSQL 16 instance and returned all 32 rows without an SQL error. After applying the actual migration files `001`–`004` to minimal local prerequisite tables and roles, all 31 named assertions and OVERALL returned true. This validates SQL execution and expected migration shapes locally, not the state of the deployed database.

## Original gap and closure

The first verification reproduced `check('SELECT "pg_catalog"."pg_sleep"(1);') == 1`: the lexer had erased double-quoted identifiers, leaving the function call invisible to the allowlist. Commit `1187b87` now raises `UnsafeSQL("quoted identifiers are prohibited")` at the first double quote and adds both the side-effecting quoted call and a harmless quoted `count` call to self-tests. The original blocker is closed. No remaining codebase gap was found.

_Rechecked: 2026-09-16T14:52:38Z. The earlier independent GSD verification remains `human_needed` until the deployed catalog is checked._
