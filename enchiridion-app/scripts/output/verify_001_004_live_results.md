# Migration 001–004 catalog verification result

User-provided Supabase SQL Editor output, pasted on 2026-09-16 after running the corrected `scripts/sql/verify_001_004.sql`. The agent did not connect to the deployed database. All 31 named checks and the OVERALL row returned `true`. These catalog results do not test a payment transaction or app behavior.

| migration_id | check_name                                 | passed | diagnostic                                                                                       |
| ------------ | ------------------------------------------ | ------ | ------------------------------------------------------------------------------------------------ |
| 001          | flagged_questions id primary key           | true   | id is the sole primary-key column                                                                |
| 001          | flagged_questions no write policies        | true   | no UPDATE, DELETE, or ALL policy                                                                 |
| 001          | flagged_questions open index               | true   | valid partial (status, created_at) index WHERE status=open                                       |
| 001          | flagged_questions own-user INSERT          | true   | permissive PUBLIC INSERT WITH CHECK uses only auth.uid()=user_id                                 |
| 001          | flagged_questions own-user SELECT          | true   | permissive PUBLIC SELECT uses only auth.uid()=user_id                                            |
| 001          | flagged_questions RLS                      | true   | row level security enabled                                                                       |
| 001          | flagged_questions SELECT policy inventory  | true   | exactly one SELECT/ALL policy, so no extra permissive OR policy                                  |
| 001          | flagged_questions status values            | true   | status CHECK limits values to open, reviewed, dismissed                                          |
| 001          | flagged_questions table                    | true   | public.flagged_questions exists as a table                                                       |
| 001          | flagged_questions user foreign key         | true   | user_id references auth.users(id) ON DELETE CASCADE                                              |
| 002          | availability NOT EXISTS body               | true   | committed body checks NOT EXISTS on profiles, folded names, and blank exclusion                  |
| 002          | availability RPC grants                    | true   | anon and authenticated may EXECUTE                                                               |
| 002          | availability RPC security                  | true   | SQL SECURITY DEFINER with search_path=public                                                     |
| 002          | availability RPC signature                 | true   | public.is_display_name_available(text) returns boolean                                           |
| 002          | display-name unique index                  | true   | valid UNIQUE lower(display_name) index excluding blank names                                     |
| 003          | leaderboard ranking body                   | true   | committed body sums performance_points, joins profiles, ranks, marks auth.uid(), includes caller |
| 003          | leaderboard RPC grant                      | true   | authenticated may EXECUTE                                                                        |
| 003          | leaderboard RPC security                   | true   | STABLE SQL SECURITY DEFINER with search_path=public                                              |
| 003          | leaderboard RPC signature                  | true   | public.get_leaderboard(integer DEFAULT 20) returns rank/name/points/is_you                       |
| 004          | processed_payments no write policies       | true   | no INSERT, UPDATE, DELETE, or ALL policy                                                         |
| 004          | processed_payments own-user SELECT         | true   | permissive PUBLIC SELECT uses only auth.uid()=user_id                                            |
| 004          | processed_payments RLS                     | true   | row level security enabled                                                                       |
| 004          | processed_payments SELECT policy inventory | true   | exactly one SELECT/ALL policy, so no extra permissive OR policy                                  |
| 004          | processed_payments table                   | true   | public.processed_payments exists as a table                                                      |
| 004          | processed_payments transaction key         | true   | transaction_id is the sole primary-key column                                                    |
| 004          | processed_payments user foreign key        | true   | user_id references auth.users(id) ON DELETE CASCADE                                              |
| 004          | processed_payments user index              | true   | valid user_id lookup index                                                                       |
| 004          | user_book_access expiry SELECT             | true   | PUBLIC SELECT requires own user, granted, and null-or-future expires_at                          |
| 004          | user_book_access no write policies         | true   | no INSERT, UPDATE, DELETE, or ALL policy                                                         |
| 004          | user_book_access RLS                       | true   | row level security enabled                                                                       |
| 004          | user_book_access SELECT policy inventory   | true   | exactly one SELECT/ALL policy, so no extra permissive OR policy                                  |
| OVERALL      | all migrations 001–004                     | true   | every named catalog assertion must pass                                                          |
