-- Add missing tables to complete the schema
-- This adds the tables that are missing from the current database

-- Create merchants table (stores trusted partner information for businesses)
CREATE TABLE IF NOT EXISTS public.merchants (
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  business_name TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::TEXT, NOW()) NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::TEXT, NOW()) NOT NULL
);

-- Create businesses table
CREATE TABLE IF NOT EXISTS public.businesses (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  owner_user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT,
  category TEXT,
  address TEXT,
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  contact_email TEXT,
  contact_number TEXT,
  verified BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::TEXT, NOW()) NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::TEXT, NOW()) NOT NULL,
  UNIQUE(owner_user_id)
);

-- Create merchant_discounts table
CREATE TABLE IF NOT EXISTS public.merchant_discounts (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    merchant_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT NOT NULL,
    percentage DECIMAL(5,2) DEFAULT 0,
    fixed_amount DECIMAL(10,2),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT discount_type_check CHECK (
        (percentage > 0 AND fixed_amount IS NULL) OR
        (percentage = 0 AND fixed_amount IS NOT NULL AND fixed_amount > 0)
    )
);

-- Create subscriptions table
CREATE TABLE IF NOT EXISTS public.subscriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  plan_type TEXT NOT NULL CHECK (plan_type IN ('basic', 'premium', 'annual')),
  auto_renew BOOLEAN NOT NULL DEFAULT FALSE,
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'cancelled', 'expired')),
  current_period_start TIMESTAMP WITH TIME ZONE NOT NULL,
  current_period_end TIMESTAMP WITH TIME ZONE NOT NULL,
  cancel_at_period_end BOOLEAN NOT NULL DEFAULT FALSE,
  payment_method_id TEXT,
  last_payment_date TIMESTAMP WITH TIME ZONE,
  next_payment_date TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create subscription_renewals table
CREATE TABLE IF NOT EXISTS public.subscription_renewals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  subscription_id UUID NOT NULL REFERENCES public.subscriptions(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  renewal_date TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  amount DECIMAL(10,2) NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('success', 'failed', 'pending')),
  payment_method TEXT,
  qr_code_updated BOOLEAN NOT NULL DEFAULT FALSE,
  error_message TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS on the new tables
ALTER TABLE public.merchants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.businesses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.merchant_discounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subscription_renewals ENABLE ROW LEVEL SECURITY;

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_merchants_user_id ON public.merchants(user_id);
CREATE INDEX IF NOT EXISTS idx_businesses_owner_user_id ON public.businesses(owner_user_id);
CREATE INDEX IF NOT EXISTS idx_merchant_discounts_merchant_id ON public.merchant_discounts(merchant_id);
CREATE INDEX IF NOT EXISTS idx_merchant_discounts_active ON public.merchant_discounts(is_active);
CREATE INDEX IF NOT EXISTS idx_subscriptions_user_id ON public.subscriptions(user_id);
CREATE INDEX IF NOT EXISTS idx_subscriptions_status ON public.subscriptions(status);
CREATE INDEX IF NOT EXISTS idx_subscription_renewals_subscription_id ON public.subscription_renewals(subscription_id);
CREATE INDEX IF NOT EXISTS idx_subscription_renewals_user_id ON public.subscription_renewals(user_id);

-- RLS Policies for merchants
DROP POLICY IF EXISTS "Users can view their own merchant profile" ON public.merchants;
DROP POLICY IF EXISTS "Users can insert their own merchant profile" ON public.merchants;
DROP POLICY IF EXISTS "Users can update their own merchant profile" ON public.merchants;
DROP POLICY IF EXISTS "Service role can manage merchants" ON public.merchants;

CREATE POLICY "Users can view their own merchant profile" ON public.merchants
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own merchant profile" ON public.merchants
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own merchant profile" ON public.merchants
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Service role can manage merchants" ON public.merchants
    FOR ALL USING (auth.role() = 'service_role');

-- RLS Policies for businesses
DROP POLICY IF EXISTS "Users can view businesses" ON public.businesses;
DROP POLICY IF EXISTS "Trusted partners can manage their businesses" ON public.businesses;
DROP POLICY IF EXISTS "Service role can manage businesses" ON public.businesses;

CREATE POLICY "Users can view businesses" ON public.businesses
    FOR SELECT USING (true);

CREATE POLICY "Trusted partners can manage their businesses" ON public.businesses
    FOR ALL USING (auth.uid() = owner_user_id);

CREATE POLICY "Service role can manage businesses" ON public.businesses
    FOR ALL USING (auth.role() = 'service_role');

-- RLS Policies for merchant_discounts
DROP POLICY IF EXISTS "Users can view active discounts" ON public.merchant_discounts;
DROP POLICY IF EXISTS "Merchants can manage their discounts" ON public.merchant_discounts;
DROP POLICY IF EXISTS "Service role can manage merchant discounts" ON public.merchant_discounts;

CREATE POLICY "Users can view active discounts" ON public.merchant_discounts
    FOR SELECT USING (is_active = true);

CREATE POLICY "Merchants can manage their discounts" ON public.merchant_discounts
    FOR ALL USING (auth.uid() = merchant_id);

CREATE POLICY "Service role can manage merchant discounts" ON public.merchant_discounts
    FOR ALL USING (auth.role() = 'service_role');

-- RLS Policies for subscriptions
DROP POLICY IF EXISTS "Users can view their own subscriptions" ON public.subscriptions;
DROP POLICY IF EXISTS "Users can insert their own subscriptions" ON public.subscriptions;
DROP POLICY IF EXISTS "Users can update their own subscriptions" ON public.subscriptions;
DROP POLICY IF EXISTS "Service role can manage subscriptions" ON public.subscriptions;

CREATE POLICY "Users can view their own subscriptions" ON public.subscriptions
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own subscriptions" ON public.subscriptions
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own subscriptions" ON public.subscriptions
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Service role can manage subscriptions" ON public.subscriptions
    FOR ALL USING (auth.role() = 'service_role');

-- RLS Policies for subscription_renewals
DROP POLICY IF EXISTS "Users can view their own renewal history" ON public.subscription_renewals;
DROP POLICY IF EXISTS "Service role can manage subscription renewals" ON public.subscription_renewals;

CREATE POLICY "Users can view their own renewal history" ON public.subscription_renewals
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Service role can manage subscription renewals" ON public.subscription_renewals
    FOR ALL USING (auth.role() = 'service_role');