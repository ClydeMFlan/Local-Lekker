-- Comprehensive fix for business bills storage and column issues
-- Execute this SQL in your Supabase SQL Editor (Dashboard > SQL Editor)

-- 1. Fix businesses table column name (if needed)
DO $$
BEGIN
    -- Check if owner_user_id column exists and owner_member_id doesn't
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
        AND table_name = 'businesses'
        AND column_name = 'owner_user_id'
    ) AND NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
        AND table_name = 'businesses'
        AND column_name = 'owner_member_id'
    ) THEN
        -- Add the new column
        ALTER TABLE businesses ADD COLUMN owner_member_id UUID REFERENCES auth.users(id) ON DELETE CASCADE;

        -- Copy data from the old column to the new column
        UPDATE businesses SET owner_member_id = owner_user_id;

        -- Make the new column NOT NULL (assuming the old column was NOT NULL)
        ALTER TABLE businesses ALTER COLUMN owner_member_id SET NOT NULL;

        -- Drop the old column
        ALTER TABLE businesses DROP COLUMN owner_user_id;

        -- Add unique constraint
        ALTER TABLE businesses ADD CONSTRAINT businesses_owner_member_id_key UNIQUE (owner_member_id);

        -- Create index
        CREATE INDEX IF NOT EXISTS idx_businesses_owner_member_id ON public.businesses(owner_member_id);
    END IF;
END $$;

-- 2. Create storage bucket for business bills (if it doesn't exist)
INSERT INTO storage.buckets (id, name, public)
VALUES ('business-bills', 'business-bills', true)
ON CONFLICT (id) DO NOTHING;

-- 3. Drop existing policies if they exist (to avoid conflicts)
DROP POLICY IF EXISTS "Business owners can view their bills" ON storage.objects;
DROP POLICY IF EXISTS "Business owners can upload their bills" ON storage.objects;
DROP POLICY IF EXISTS "Business owners can update their bills" ON storage.objects;
DROP POLICY IF EXISTS "Business owners can delete their bills" ON storage.objects;

-- 4. Create storage policies for business bills
CREATE POLICY "Business owners can view their bills" ON storage.objects
    FOR SELECT USING (
        bucket_id = 'business-bills' AND
        (storage.foldername(name))[1] IN (
            SELECT id::text FROM businesses WHERE owner_member_id = auth.uid()
        )
    );

CREATE POLICY "Business owners can upload their bills" ON storage.objects
    FOR INSERT WITH CHECK (
        bucket_id = 'business-bills' AND
        (storage.foldername(name))[1] IN (
            SELECT id::text FROM businesses WHERE owner_member_id = auth.uid()
        )
    );

CREATE POLICY "Business owners can update their bills" ON storage.objects
    FOR UPDATE USING (
        bucket_id = 'business-bills' AND
        (storage.foldername(name))[1] IN (
            SELECT id::text FROM businesses WHERE owner_member_id = auth.uid()
        )
    );

CREATE POLICY "Business owners can delete their bills" ON storage.objects
    FOR DELETE USING (
        bucket_id = 'business-bills' AND
        (storage.foldername(name))[1] IN (
            SELECT id::text FROM businesses WHERE owner_member_id = auth.uid()
        )
    );

-- 5. Create business_bills table (if it doesn't exist)
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

-- 6. Enable RLS on business_bills table
ALTER TABLE public.business_bills ENABLE ROW LEVEL SECURITY;

-- 7. Create RLS policies for business_bills table
DROP POLICY IF EXISTS "Business owners can view their bills" ON public.business_bills;
DROP POLICY IF EXISTS "Business owners can insert their bills" ON public.business_bills;
DROP POLICY IF EXISTS "Business owners can update their bills" ON public.business_bills;
DROP POLICY IF EXISTS "Business owners can delete their bills" ON public.business_bills;

CREATE POLICY "Business owners can view their bills" ON public.business_bills
    FOR SELECT USING (
        business_id IN (
            SELECT id FROM businesses WHERE owner_member_id = auth.uid()
        )
    );

CREATE POLICY "Business owners can insert their bills" ON public.business_bills
    FOR INSERT WITH CHECK (
        business_id IN (
            SELECT id FROM businesses WHERE owner_member_id = auth.uid()
        )
    );

CREATE POLICY "Business owners can update their bills" ON public.business_bills
    FOR UPDATE USING (
        business_id IN (
            SELECT id FROM businesses WHERE owner_member_id = auth.uid()
        )
    );

CREATE POLICY "Business owners can delete their bills" ON public.business_bills
    FOR DELETE USING (
        business_id IN (
            SELECT id FROM businesses WHERE owner_member_id = auth.uid()
        )
    );

-- 8. Create updated_at trigger for business_bills
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