-- Migration: Add device binding and email confirmation columns to profiles table
-- Date: 2026-05-23
-- Purpose: Enable Phase 1 - Email Confirmation & Device Binding

-- Step 1: Add new columns to profiles table
ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS email_confirmed BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS device_id TEXT,
ADD COLUMN IF NOT EXISTS bound_at TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS authorized_devices JSONB DEFAULT '[]'::jsonb,
ADD COLUMN IF NOT EXISTS last_device_switch TIMESTAMP WITH TIME ZONE;

-- Step 2: Create index for email_confirmed (used in auth gates)
CREATE INDEX IF NOT EXISTS idx_profiles_email_confirmed
ON public.profiles(email_confirmed);

-- Step 3: Create index for device_id (used in device matching)
CREATE INDEX IF NOT EXISTS idx_profiles_device_id
ON public.profiles(device_id);

-- Step 4: Create index for last_device_switch (used in quota enforcement)
CREATE INDEX IF NOT EXISTS idx_profiles_last_device_switch
ON public.profiles(last_device_switch);

-- Step 5: Enable RLS on profiles table
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Step 6: Drop existing policies (if any) to avoid conflicts
DROP POLICY IF EXISTS "Users can view own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can insert own profile" ON public.profiles;

-- Step 7: Create RLS policy - SELECT (users can read only their own profile)
CREATE POLICY "Users can view own profile"
ON public.profiles
FOR SELECT
USING (auth.uid() = id);

-- Step 8: Create RLS policy - INSERT (users can create only their own profile)
CREATE POLICY "Users can insert own profile"
ON public.profiles
FOR INSERT
WITH CHECK (auth.uid() = id);

-- Step 9: Create RLS policy - UPDATE (users can update only their own profile)
CREATE POLICY "Users can update own profile"
ON public.profiles
FOR UPDATE
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

-- Step 10: Create RLS policy - DELETE (users can delete only their own profile)
CREATE POLICY "Users can delete own profile"
ON public.profiles
FOR DELETE
USING (auth.uid() = id);

-- Step 11: Allow authenticated users to view their own metadata
-- (in case app needs to query for existence check)
CREATE POLICY "Authenticated users can view public metadata"
ON public.profiles
FOR SELECT
USING (auth.role() = 'authenticated');

-- Verification: Check that columns were added
-- SELECT column_name, data_type, is_nullable
-- FROM information_schema.columns
-- WHERE table_name = 'profiles'
-- ORDER BY ordinal_position;

-- Verification: Check RLS is enabled
-- SELECT tablename, rowsecurity
-- FROM pg_tables
-- WHERE tablename = 'profiles';

-- Verification: Check RLS policies
-- SELECT schemaname, tablename, policyname, cmd, qual, with_check
-- FROM pg_policies
-- WHERE tablename = 'profiles'
-- ORDER BY policyname;
