-- Complete database schema fix for signup issues
-- Run this in Supabase SQL Editor to apply all necessary fixes

-- Step 1: Drop existing tables if they exist (clean slate)
DROP TABLE IF EXISTS public.subscription_renewals CASCADE;
DROP TABLE IF EXISTS public.subscriptions CASCADE;
DROP TABLE IF EXISTS public.user_qr_codes CASCADE;
DROP TABLE IF EXISTS public.merchant_discounts CASCADE;
DROP TABLE IF EXISTS public.payments CASCADE;
DROP TABLE IF EXISTS public.businesses CASCADE;
DROP TABLE IF EXISTS public.merchants CASCADE;
DROP TABLE IF EXISTS public.memberships CASCADE;
DROP TABLE IF EXISTS public.profiles CASCADE;
DROP TABLE IF EXISTS public.users CASCADE;

-- Step 2: Drop existing functions
DROP FUNCTION IF EXISTS public.generate_user_qr_code(UUID) CASCADE;
DROP FUNCTION IF EXISTS public.process_monthly_renewal() CASCADE;
DROP FUNCTION IF EXISTS public.update_merchant_discounts_updated_at() CASCADE;
DROP FUNCTION IF EXISTS public.try_cast_double(TEXT) CASCADE;

-- Step 3: Create tables with proper structure
CREATE TABLE public.profiles (
  id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  name TEXT,
  surname TEXT,
  email TEXT,
  role TEXT DEFAULT 'member',
  category TEXT,
  street TEXT,
  suburb TEXT,
  city TEXT,
  province TEXT,
  contact TEXT,
  gender TEXT,
  ethnicity TEXT,
  date_of_birth DATE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::TEXT, NOW()) NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::TEXT, NOW()) NOT NULL
);

CREATE TABLE public.memberships (
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  role TEXT NOT NULL,
  gateway TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::TEXT, NOW()) NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::TEXT, NOW()) NOT NULL,
  PRIMARY KEY (user_id)
);

CREATE TABLE public.users (
  id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  email TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::TEXT, NOW()) NOT NULL
);

CREATE TABLE public.user_qr_codes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  qr_code TEXT NOT NULL UNIQUE,
  name TEXT,
  surname TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::TEXT, NOW()) NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::TEXT, NOW()) NOT NULL
);

-- Step 4: Enable RLS on all tables
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_qr_codes ENABLE ROW LEVEL SECURITY;

-- Step 5: Create essential RLS policies for signup
-- Profiles policies
CREATE POLICY "Users can view own profile" ON public.profiles
  FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Users can update own profile" ON public.profiles
  FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Users can insert own profile" ON public.profiles
  FOR INSERT WITH CHECK (auth.uid() = id);

-- Memberships policies
CREATE POLICY "Users can view own membership" ON public.memberships
  FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert memberships" ON public.memberships
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Users policies
CREATE POLICY "Users can view own user record" ON public.users
  FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Users can insert own user record" ON public.users
  FOR INSERT WITH CHECK (auth.uid() = id);

-- User QR codes policies
CREATE POLICY "Users can view own QR codes" ON public.user_qr_codes
  FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own QR codes" ON public.user_qr_codes
  FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own QR codes" ON public.user_qr_codes
  FOR UPDATE USING (auth.uid() = user_id);

-- Step 6: Create indexes for performance
CREATE INDEX idx_profiles_role ON public.profiles(role);
CREATE INDEX idx_memberships_role ON public.memberships(role);
CREATE INDEX idx_memberships_user_id ON public.memberships(user_id);
CREATE INDEX idx_user_qr_codes_user_id ON public.user_qr_codes(user_id);
CREATE INDEX idx_user_qr_codes_active ON public.user_qr_codes(is_active) WHERE is_active = true;