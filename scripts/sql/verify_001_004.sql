-- Run after deploying 001–004 in the Supabase SQL Editor, or with an existing
-- operator connection: psql -X -v ON_ERROR_STOP=1 -f scripts/sql/verify_001_004.sql
-- Run python scripts/sql/check_verify_001_004_read_only.py --self-test
--   scripts/sql/verify_001_004.sql before sending this file to the database.
-- Catalog metadata only: no application rows, credentials, or writes.

WITH objects AS (
  SELECT c.oid, c.relname, c.relrowsecurity
  FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public'
    AND c.relname IN ('flagged_questions', 'profiles',
                      'processed_payments', 'user_book_access')
    AND c.relkind IN ('r', 'p')
), policies AS (
  SELECT p.*, o.relname,
         lower(regexp_replace(coalesce(pg_get_expr(p.polqual, p.polrelid), ''),
                              '[[:space:]]+', '', 'g')) AS using_expr,
         lower(regexp_replace(coalesce(pg_get_expr(p.polwithcheck, p.polrelid), ''),
                              '[[:space:]]+', '', 'g')) AS check_expr
  FROM pg_policy p JOIN objects o ON o.oid = p.polrelid
), routines AS (
  SELECT p.*, n.nspname
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public'
    AND p.proname IN ('is_display_name_available', 'get_leaderboard')
), assertions AS (
  SELECT '001' AS migration_id, 'flagged_questions table' AS check_name,
         EXISTS (SELECT 1 FROM objects WHERE relname = 'flagged_questions') AS passed,
         'public.flagged_questions exists as a table' AS diagnostic
  UNION ALL SELECT '001', 'flagged_questions id primary key',
    EXISTS (SELECT 1 FROM pg_constraint k JOIN objects o ON o.oid = k.conrelid
            JOIN pg_attribute a ON a.attrelid = o.oid AND a.attnum = k.conkey[1]
            WHERE o.relname = 'flagged_questions' AND k.contype = 'p'
              AND array_length(k.conkey, 1) = 1 AND a.attname = 'id'),
    'id is the sole primary-key column'
  UNION ALL SELECT '001', 'flagged_questions user foreign key',
    EXISTS (SELECT 1 FROM pg_constraint k JOIN objects o ON o.oid = k.conrelid
            JOIN pg_attribute a ON a.attrelid = o.oid AND a.attnum = k.conkey[1]
            JOIN pg_class target ON target.oid = k.confrelid
            JOIN pg_namespace ns ON ns.oid = target.relnamespace
            JOIN pg_attribute ta ON ta.attrelid = target.oid AND ta.attnum = k.confkey[1]
            WHERE o.relname = 'flagged_questions' AND k.contype = 'f'
              AND array_length(k.conkey, 1) = 1 AND k.confdeltype = 'c'
              AND a.attname = 'user_id' AND ns.nspname = 'auth'
              AND target.relname = 'users' AND ta.attname = 'id'),
    'user_id references auth.users(id) ON DELETE CASCADE'
  UNION ALL SELECT '001', 'flagged_questions status values',
    EXISTS (SELECT 1 FROM pg_constraint k JOIN objects o ON o.oid = k.conrelid
            WHERE o.relname = 'flagged_questions' AND k.contype = 'c'
              AND lower(regexp_replace(pg_get_constraintdef(k.oid),
                                       '[[:space:]()]', '', 'g'))
                  = 'checkstatus=anyarray[''open''::text,''reviewed''::text,''dismissed''::text]'),
    'status CHECK limits values to open, reviewed, dismissed'
  UNION ALL SELECT '001', 'flagged_questions open index',
    EXISTS (SELECT 1 FROM pg_index i JOIN pg_class ix ON ix.oid = i.indexrelid
            JOIN objects o ON o.oid = i.indrelid
            WHERE o.relname = 'flagged_questions'
              AND ix.relname = 'idx_flagged_questions_open'
              AND i.indisvalid AND i.indisready AND i.indpred IS NOT NULL
              AND lower(pg_get_indexdef(i.indexrelid)) LIKE '%(status, created_at)%'
              AND lower(pg_get_expr(i.indpred, i.indrelid)) LIKE '%status%open%'),
    'valid partial (status, created_at) index WHERE status=open'
  UNION ALL SELECT '001', 'flagged_questions RLS',
    EXISTS (SELECT 1 FROM objects WHERE relname = 'flagged_questions' AND relrowsecurity),
    'row level security enabled'
  UNION ALL SELECT '001', 'flagged_questions SELECT policy inventory',
    (SELECT count(*) = 1 FROM policies
      WHERE relname = 'flagged_questions' AND polcmd IN ('r', '*')),
    'exactly one SELECT/ALL policy, so no extra permissive OR policy'
  UNION ALL SELECT '001', 'flagged_questions own-user SELECT',
    EXISTS (SELECT 1 FROM policies WHERE relname = 'flagged_questions'
            AND polname = 'Users can read their own flags'
            AND polcmd = 'r' AND polpermissive AND polroles = ARRAY[0]::oid[]
            AND using_expr ~ '^\(*auth\.uid\(\)=user_id\)*$'),
    'permissive PUBLIC SELECT uses only auth.uid()=user_id'
  UNION ALL SELECT '001', 'flagged_questions own-user INSERT',
    EXISTS (SELECT 1 FROM policies WHERE relname = 'flagged_questions'
            AND polname = 'Users can insert their own flags'
            AND polcmd = 'a' AND polpermissive AND polroles = ARRAY[0]::oid[]
            AND check_expr ~ '^\(*auth\.uid\(\)=user_id\)*$'),
    'permissive PUBLIC INSERT WITH CHECK uses only auth.uid()=user_id'
  UNION ALL SELECT '001', 'flagged_questions no write policies',
    NOT EXISTS (SELECT 1 FROM policies WHERE relname = 'flagged_questions'
                AND polcmd IN ('w', 'd', '*')),
    'no UPDATE, DELETE, or ALL policy'
  UNION ALL SELECT '002', 'display-name unique index',
    EXISTS (SELECT 1 FROM pg_index i JOIN pg_class ix ON ix.oid = i.indexrelid
            JOIN objects o ON o.oid = i.indrelid
            WHERE o.relname = 'profiles'
              AND ix.relname = 'idx_profiles_display_name_unique'
              AND i.indisvalid AND i.indisready AND i.indisunique
              AND i.indpred IS NOT NULL
              AND lower(regexp_replace(pg_get_indexdef(i.indexrelid),
                                       '[[:space:]]+', '', 'g'))
                  LIKE '%(lower(display_name))%'
              AND lower(regexp_replace(pg_get_expr(i.indpred, i.indrelid),
                                       '[[:space:]]+', '', 'g'))
                  LIKE '%display_name<>''''::text%'),
    'valid UNIQUE lower(display_name) index excluding blank names'
  UNION ALL SELECT '002', 'availability RPC signature',
    EXISTS (SELECT 1 FROM routines p WHERE p.proname = 'is_display_name_available'
            AND p.pronargs = 1 AND p.proargtypes = '25'::oidvector
            AND p.prorettype = 'boolean'::regtype),
    'public.is_display_name_available(text) returns boolean'
  UNION ALL SELECT '002', 'availability RPC security',
    EXISTS (SELECT 1 FROM routines p JOIN pg_language l ON l.oid = p.prolang
            WHERE p.proname = 'is_display_name_available'
              AND p.pronargs = 1 AND p.proargtypes = '25'::oidvector
              AND l.lanname = 'sql' AND p.prosecdef
              AND 'search_path=public' = ANY(p.proconfig)),
    'SQL SECURITY DEFINER with search_path=public'
  UNION ALL SELECT '002', 'availability RPC grants',
    EXISTS (SELECT 1 FROM routines p WHERE p.proname = 'is_display_name_available'
            AND p.pronargs = 1 AND p.proargtypes = '25'::oidvector
            AND has_function_privilege('anon', p.oid, 'EXECUTE')
            AND has_function_privilege('authenticated', p.oid, 'EXECUTE')),
    'anon and authenticated may EXECUTE'
  UNION ALL SELECT '002', 'availability NOT EXISTS body',
    EXISTS (SELECT 1 FROM routines p WHERE p.proname = 'is_display_name_available'
            AND p.pronargs = 1 AND p.proargtypes = '25'::oidvector
            AND md5(lower(regexp_replace(p.prosrc, '[[:space:]]+', '', 'g')))
                = '802aacb921fc4d991a9855564ca633e6'),
    'committed body checks NOT EXISTS on profiles, folded names, and blank exclusion'
  UNION ALL SELECT '003', 'leaderboard RPC signature',
    EXISTS (SELECT 1 FROM routines p WHERE p.proname = 'get_leaderboard'
            AND p.pronargs = 1 AND p.proargtypes = '23'::oidvector
            AND lower(regexp_replace(pg_get_function_result(p.oid),
                                     '[[:space:]]+', '', 'g'))
                = 'table(rankbigint,display_nametext,total_pointsbigint,is_youboolean)'
            AND lower(regexp_replace(coalesce(pg_get_expr(p.proargdefaults, 0), ''),
                                     '[[:space:]]+', '', 'g')) = '20'),
    'public.get_leaderboard(integer DEFAULT 20) returns rank/name/points/is_you'
  UNION ALL SELECT '003', 'leaderboard RPC security',
    EXISTS (SELECT 1 FROM routines p JOIN pg_language l ON l.oid = p.prolang
            WHERE p.proname = 'get_leaderboard'
              AND p.pronargs = 1 AND p.proargtypes = '23'::oidvector
              AND l.lanname = 'sql' AND p.prosecdef
              AND p.provolatile = 's'
              AND 'search_path=public' = ANY(p.proconfig)),
    'STABLE SQL SECURITY DEFINER with search_path=public'
  UNION ALL SELECT '003', 'leaderboard RPC grant',
    EXISTS (SELECT 1 FROM routines p WHERE p.proname = 'get_leaderboard'
            AND p.pronargs = 1 AND p.proargtypes = '23'::oidvector
            AND has_function_privilege('authenticated', p.oid, 'EXECUTE')),
    'authenticated may EXECUTE'
  UNION ALL SELECT '003', 'leaderboard ranking body',
    EXISTS (SELECT 1 FROM routines p WHERE p.proname = 'get_leaderboard'
            AND p.pronargs = 1 AND p.proargtypes = '23'::oidvector
            AND md5(lower(regexp_replace(p.prosrc, '[[:space:]]+', '', 'g')))
                = 'd1821041253e750bf7bec157fcb5c208'),
    'committed body sums performance_points, joins profiles, ranks, marks auth.uid(), includes caller'
  UNION ALL SELECT '004', 'processed_payments table',
    EXISTS (SELECT 1 FROM objects WHERE relname = 'processed_payments'),
    'public.processed_payments exists as a table'
  UNION ALL SELECT '004', 'processed_payments transaction key',
    EXISTS (SELECT 1 FROM pg_constraint k JOIN objects o ON o.oid = k.conrelid
            JOIN pg_attribute a ON a.attrelid = o.oid AND a.attnum = k.conkey[1]
            WHERE o.relname = 'processed_payments' AND k.contype = 'p'
              AND array_length(k.conkey, 1) = 1 AND a.attname = 'transaction_id'),
    'transaction_id is the sole primary-key column'
  UNION ALL SELECT '004', 'processed_payments user foreign key',
    EXISTS (SELECT 1 FROM pg_constraint k JOIN objects o ON o.oid = k.conrelid
            JOIN pg_attribute a ON a.attrelid = o.oid AND a.attnum = k.conkey[1]
            JOIN pg_class target ON target.oid = k.confrelid
            JOIN pg_namespace ns ON ns.oid = target.relnamespace
            JOIN pg_attribute ta ON ta.attrelid = target.oid AND ta.attnum = k.confkey[1]
            WHERE o.relname = 'processed_payments' AND k.contype = 'f'
              AND array_length(k.conkey, 1) = 1 AND k.confdeltype = 'c'
              AND a.attname = 'user_id' AND ns.nspname = 'auth'
              AND target.relname = 'users' AND ta.attname = 'id'),
    'user_id references auth.users(id) ON DELETE CASCADE'
  UNION ALL SELECT '004', 'processed_payments user index',
    EXISTS (SELECT 1 FROM pg_index i JOIN pg_class ix ON ix.oid = i.indexrelid
            JOIN objects o ON o.oid = i.indrelid
            WHERE o.relname = 'processed_payments'
              AND ix.relname = 'idx_processed_payments_user'
              AND i.indisvalid AND i.indisready
              AND lower(pg_get_indexdef(i.indexrelid)) LIKE '%(user_id)%'),
    'valid user_id lookup index'
  UNION ALL SELECT '004', 'processed_payments RLS',
    EXISTS (SELECT 1 FROM objects WHERE relname = 'processed_payments' AND relrowsecurity),
    'row level security enabled'
  UNION ALL SELECT '004', 'processed_payments SELECT policy inventory',
    (SELECT count(*) = 1 FROM policies
      WHERE relname = 'processed_payments' AND polcmd IN ('r', '*')),
    'exactly one SELECT/ALL policy, so no extra permissive OR policy'
  UNION ALL SELECT '004', 'processed_payments own-user SELECT',
    EXISTS (SELECT 1 FROM policies WHERE relname = 'processed_payments'
            AND polname = 'Users can read their own processed payments'
            AND polcmd = 'r' AND polpermissive AND polroles = ARRAY[0]::oid[]
            AND using_expr ~ '^\(*auth\.uid\(\)=user_id\)*$'),
    'permissive PUBLIC SELECT uses only auth.uid()=user_id'
  UNION ALL SELECT '004', 'processed_payments no write policies',
    NOT EXISTS (SELECT 1 FROM policies WHERE relname = 'processed_payments'
                AND polcmd IN ('a', 'w', 'd', '*')),
    'no INSERT, UPDATE, DELETE, or ALL policy'
  UNION ALL SELECT '004', 'user_book_access RLS',
    EXISTS (SELECT 1 FROM objects WHERE relname = 'user_book_access' AND relrowsecurity),
    'row level security enabled'
  UNION ALL SELECT '004', 'user_book_access SELECT policy inventory',
    (SELECT count(*) = 1 FROM policies
      WHERE relname = 'user_book_access' AND polcmd IN ('r', '*')),
    'exactly one SELECT/ALL policy, so no extra permissive OR policy'
  UNION ALL SELECT '004', 'user_book_access expiry SELECT',
    EXISTS (SELECT 1 FROM policies WHERE relname = 'user_book_access'
            AND polname = 'Users can read their granted access'
            AND polcmd = 'r' AND polpermissive AND polroles = ARRAY[0]::oid[]
            AND using_expr ~ '^\(*auth\.uid\(\)=user_id\)*andgrantedand'
            AND using_expr ~ 'expires_atisnull\)*or\(*expires_at>timezone\(''utc''::text,now\(\)\)\)*$'),
    'PUBLIC SELECT requires own user, granted, and null-or-future expires_at'
  UNION ALL SELECT '004', 'user_book_access no write policies',
    NOT EXISTS (SELECT 1 FROM policies WHERE relname = 'user_book_access'
                AND polcmd IN ('a', 'w', 'd', '*')),
    'no INSERT, UPDATE, DELETE, or ALL policy'
)
SELECT migration_id, check_name, passed, diagnostic FROM assertions
UNION ALL
SELECT 'OVERALL', 'all migrations 001–004', coalesce(bool_and(passed), false),
       'every named catalog assertion must pass'
FROM assertions
ORDER BY migration_id, check_name;
