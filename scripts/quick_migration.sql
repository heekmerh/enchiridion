-- QUICK MIGRATION: Add Device Binding Columns + RLS
-- Copy and paste this into Supabase SQL Editor and click Run
-- Takes ~5 seconds, safe to run on production

-- 1. Add columns
ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS email_confirmed BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS device_id TEXT,
ADD COLUMN IF NOT EXISTS bound_at TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS authorized_devices JSONB DEFAULT '[]'::jsonb,
ADD COLUMN IF NOT EXISTS last_device_switch TIMESTAMP WITH TIME ZONE;

-- 2. Create indexes
CREATE INDEX IF NOT EXISTS idx_profiles_email_confirmed ON public.profiles(email_confirmed);
CREATE INDEX IF NOT EXISTS idx_profiles_device_id ON public.profiles(device_id);
CREATE INDEX IF NOT EXISTS idx_profiles_last_device_switch ON public.profiles(last_device_switch);

-- 3. Enable RLS
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- 4. Create policies
DROP POLICY IF EXISTS "Users can view own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can insert own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can delete own profile" ON public.profiles;
DROP POLICY IF EXISTS "Authenticated users can view public metadata" ON public.profiles;

CREATE POLICY "Users can view own profile" ON public.profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Users can insert own profile" ON public.profiles FOR INSERT WITH CHECK (auth.uid() = id);
CREATE POLICY "Users can update own profile" ON public.profiles FOR UPDATE USING (auth.uid() = id) WITH CHECK (auth.uid() = id);
CREATE POLICY "Users can delete own profile" ON public.profiles FOR DELETE USING (auth.uid() = id);
CREATE POLICY "Authenticated users can view public metadata" ON public.profiles FOR SELECT USING (auth.role() = 'authenticated');

-- Done! Migration complete.
-- Run this to verify:
-- SELECT email_confirmed, device_id, bound_at, authorized_devices, last_device_switch FROM profiles LIMIT 1;
