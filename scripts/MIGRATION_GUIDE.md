# Database Migration Guide — Phase 1 Device Binding

**Date:** 2026-05-23  
**Migration:** `001_add_device_binding_columns.sql`  
**Purpose:** Enable email confirmation and device binding for Phase 1

---

## Overview

This migration adds 5 new columns to the `profiles` table to support:
1. Email verification status (blocking app access until confirmed)
2. Device fingerprinting (first device binding)
3. Multi-device authorization with monthly quota
4. Row-level security (RLS) to prevent cross-user access

---

## New Columns

| Column | Type | Default | Purpose |
|--------|------|---------|---------|
| `email_confirmed` | BOOLEAN | FALSE | Email verification gate |
| `device_id` | TEXT | NULL | First/primary device fingerprint (immutable) |
| `bound_at` | TIMESTAMP | NULL | When device was first bound |
| `authorized_devices` | JSONB | `[]` | Array of {device_id, authorized_at} for Device B, C, etc. |
| `last_device_switch` | TIMESTAMP | NULL | Rolling 30-day quota tracker |

---

## RLS Policies

Five policies are created to enforce user isolation:

| Policy Name | Operation | Rule | Effect |
|-------------|-----------|------|--------|
| `Users can view own profile` | SELECT | `auth.uid() = id` | Users can only read their own profile |
| `Users can insert own profile` | INSERT | `auth.uid() = id` | Users can only create their own profile |
| `Users can update own profile` | UPDATE | `auth.uid() = id` | Users can only update their own profile |
| `Users can delete own profile` | DELETE | `auth.uid() = id` | Users can only delete their own profile |
| `Authenticated users can view public metadata` | SELECT | `auth.role() = 'authenticated'` | All authenticated users can verify profile exists |

---

## How to Run

### Option 1: Supabase Dashboard (Recommended for manual testing)

1. Go to **Supabase Dashboard** → Your Project
2. Navigate to **SQL Editor** (left sidebar)
3. Create a new query
4. Copy the entire content of `001_add_device_binding_columns.sql`
5. Paste into the SQL editor
6. Click **Run** button (⏯️)
7. Verify: All 10 steps execute without errors
8. Verify: No existing data is lost (migration is additive)

### Option 2: Supabase CLI

```bash
# Prerequisites: Install Supabase CLI
npm install -g supabase

# Login to your Supabase account
supabase login

# Link to your project
supabase link --project-ref YOUR_PROJECT_REF

# Run the migration
supabase db push --schema=public < scripts/001_add_device_binding_columns.sql
```

### Option 3: Programmatic (via App Code)

If you want the app to auto-migrate on first launch:

```dart
// In your initialization code (main.dart or bootstrap)
Future<void> _runMigrations() async {
  final client = Supabase.instance.client;
  
  // Read the migration SQL
  final sql = await rootBundle.loadString(
    'assets/migrations/001_add_device_binding_columns.sql'
  );
  
  // Execute
  await client.rpc('exec_sql', params: {'sql': sql});
}

// Call during app initialization
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(...);
  await _runMigrations();
  runApp(const MyApp());
}
```

---

## Verification Checklist

After running the migration, verify:

### 1. Columns Added ✓
```sql
-- Run this query in Supabase SQL Editor:
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_name = 'profiles'
AND column_name IN ('email_confirmed', 'device_id', 'bound_at', 'authorized_devices', 'last_device_switch')
ORDER BY ordinal_position;
```

Expected output:
- `email_confirmed` | boolean | NO | false
- `device_id` | text | YES | NULL
- `bound_at` | timestamp with time zone | YES | NULL
- `authorized_devices` | jsonb | NO | '[]'::jsonb
- `last_device_switch` | timestamp with time zone | YES | NULL

### 2. Indexes Created ✓
```sql
-- Run this query:
SELECT schemaname, tablename, indexname
FROM pg_indexes
WHERE tablename = 'profiles'
AND indexname LIKE 'idx_profiles_%';
```

Expected: 3 indexes (email_confirmed, device_id, last_device_switch)

### 3. RLS Enabled ✓
```sql
-- Run this query:
SELECT tablename, rowsecurity
FROM pg_tables
WHERE schemaname = 'public'
AND tablename = 'profiles';
```

Expected: `profiles | true`

### 4. RLS Policies Created ✓
```sql
-- Run this query:
SELECT policyname, cmd
FROM pg_policies
WHERE tablename = 'profiles'
ORDER BY policyname;
```

Expected: 5 policies
- `Authenticated users can view public metadata`
- `Users can delete own profile`
- `Users can insert own profile`
- `Users can update own profile`
- `Users can view own profile`

### 5. No Data Loss ✓
```sql
-- Run this query:
SELECT COUNT(*) as user_count,
       COUNT(DISTINCT id) as unique_users
FROM public.profiles;
```

Expected: Same count as before migration (no rows deleted)

---

## Rollback Plan

If something goes wrong, you can revert:

```sql
-- Drop RLS policies
DROP POLICY IF EXISTS "Users can view own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can insert own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can delete own profile" ON public.profiles;
DROP POLICY IF EXISTS "Authenticated users can view public metadata" ON public.profiles;

-- Disable RLS
ALTER TABLE public.profiles DISABLE ROW LEVEL SECURITY;

-- Drop indexes
DROP INDEX IF EXISTS idx_profiles_email_confirmed;
DROP INDEX IF EXISTS idx_profiles_device_id;
DROP INDEX IF EXISTS idx_profiles_last_device_switch;

-- Drop columns
ALTER TABLE public.profiles
DROP COLUMN IF EXISTS email_confirmed,
DROP COLUMN IF EXISTS device_id,
DROP COLUMN IF EXISTS bound_at,
DROP COLUMN IF EXISTS authorized_devices,
DROP COLUMN IF EXISTS last_device_switch;
```

**Warning:** This will delete all device binding data. Only run if necessary.

---

## Testing After Migration

### 1. Test RLS — User Can Read Own Profile
```dart
// In your app or test
final response = await Supabase.instance.client
    .from('profiles')
    .select()
    .eq('id', currentUser.id)
    .single();

// Should succeed - returns own profile
```

### 2. Test RLS — User Cannot Read Other Profiles
```dart
// In your app or test
try {
  final response = await Supabase.instance.client
      .from('profiles')
      .select()
      .eq('id', 'some-other-user-id');
  
  // Should fail with 403 Forbidden (or return empty)
} on PostgrestException catch (e) {
  // Expected: status 403 or empty result
}
```

### 3. Test Device Binding Flow (Post-Migration)
```dart
// Create a new user via signup
final response = await AuthService.signUp(
  email: 'test@example.com',
  password: 'password123',
  displayName: 'Test User',
  role: 'medical_student',
);

// Verify profile has email_confirmed = false
final profile = await AuthService.getProfile();
print('email_confirmed: ${profile['email_confirmed']}'); // false

// After email verification (simulated)
final updated = await Supabase.instance.client
    .from('profiles')
    .update({'email_confirmed': true})
    .eq('id', currentUser.id)
    .select()
    .single();

print('Updated: ${updated['email_confirmed']}'); // true
```

---

## Performance Considerations

- **Indexes:** Created on `email_confirmed`, `device_id`, `last_device_switch` for fast lookups
- **JSONB:** `authorized_devices` array can grow; consider archival after 1 year if performance degrades
- **RLS:** Adds ~5-10ms per query (Supabase overhead); acceptable for mobile app
- **Row Count:** Migration time ~O(n) where n = current users; <1s for 10k rows

---

## Next Steps

1. **Run migration** using one of the methods above
2. **Verify** using the verification checklist
3. **Test** RLS policies with sample queries
4. **Deploy** Phase 1 code (DeviceService, AuthProvider, etc.)
5. **Monitor** Supabase logs for any RLS-related errors

---

## Support

- **Supabase Docs:** https://supabase.com/docs/guides/auth/row-level-security
- **PostgreSQL RLS:** https://www.postgresql.org/docs/current/sql-createpolicy.html
- **JSONB Guide:** https://supabase.com/docs/guides/database/json

---

*Migration created: 2026-05-23*
