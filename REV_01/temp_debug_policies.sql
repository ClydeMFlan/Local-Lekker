-- Temporary debug version - more permissive policies for testing
-- Execute this SQL in your Supabase SQL Editor (Dashboard > SQL Editor)
-- This version allows uploads to any business-bills bucket for authenticated users
-- Replace with the proper policies after confirming the upload works

-- 1. Create storage bucket for business bills (if it doesn't exist)
INSERT INTO storage.buckets (id, name, public)
VALUES ('business-bills', 'business-bills', true)
ON CONFLICT (id) DO NOTHING;

-- 2. Drop existing policies if they exist
DROP POLICY IF EXISTS "Business owners can view their bills" ON storage.objects;
DROP POLICY IF EXISTS "Business owners can upload their bills" ON storage.objects;
DROP POLICY IF EXISTS "Business owners can update their bills" ON storage.objects;
DROP POLICY IF EXISTS "Business owners can delete their bills" ON storage.objects;

-- 3. Create temporary permissive policies for testing
CREATE POLICY "Authenticated users can upload bills" ON storage.objects
    FOR INSERT WITH CHECK (
        bucket_id = 'business-bills' AND
        auth.role() = 'authenticated'
    );

CREATE POLICY "Authenticated users can view bills" ON storage.objects
    FOR SELECT USING (
        bucket_id = 'business-bills' AND
        auth.role() = 'authenticated'
    );

CREATE POLICY "Authenticated users can update bills" ON storage.objects
    FOR UPDATE USING (
        bucket_id = 'business-bills' AND
        auth.role() = 'authenticated'
    );

CREATE POLICY "Authenticated users can delete bills" ON storage.objects
    FOR DELETE USING (
        bucket_id = 'business-bills' AND
        auth.role() = 'authenticated'
    );

-- 4. Create business_bills table (if it doesn't exist)
CREATE TABLE IF NOT EXISTS public.business_bills (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    business_id UUID NOT NULL,
    bill_url TEXT NOT NULL,
    business_name TEXT,
    is_active BOOLEAN DEFAULT true,
    extracted_features JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::TEXT, NOW()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::TEXT, NOW()) NOT NULL
);

-- 5. Enable RLS on business_bills table
ALTER TABLE public.business_bills ENABLE ROW LEVEL SECURITY;

-- 6. Create temporary permissive RLS policies for business_bills table
DROP POLICY IF EXISTS "Authenticated users can view bills" ON public.business_bills;
DROP POLICY IF EXISTS "Authenticated users can insert bills" ON public.business_bills;
DROP POLICY IF EXISTS "Authenticated users can update bills" ON public.business_bills;
DROP POLICY IF EXISTS "Authenticated users can delete bills" ON public.business_bills;

CREATE POLICY "Authenticated users can view bills" ON public.business_bills
    FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can insert bills" ON public.business_bills
    FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can update bills" ON public.business_bills
    FOR UPDATE USING (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can delete bills" ON public.business_bills
    FOR DELETE USING (auth.role() = 'authenticated');

-- 7. Create updated_at trigger for business_bills
CREATE OR REPLACE FUNCTION update_business_bills_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_business_bills_updated_at ON public.business_bills;
CREATE TRIGGER update_business_bills_updated_at
    BEFORE UPDATE ON public.business_bills
    FOR EACH ROW
    EXECUTE FUNCTION update_business_bills_updated_at();