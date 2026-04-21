-- Migration to fix trusted partner signup issues
-- Execute this in Supabase SQL Editor

-- Step 1: Check current businesses table structure
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'businesses'
ORDER BY ordinal_position;

-- Step 2: Add owner_member_id column if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
    AND table_name = 'businesses'
    AND column_name = 'owner_member_id'
  ) THEN
    -- Check if owner_user_id exists and rename it
    IF EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'public'
      AND table_name = 'businesses'
      AND column_name = 'owner_user_id'
    ) THEN
      ALTER TABLE public.businesses RENAME COLUMN owner_user_id TO owner_member_id;
    ELSE
      -- Add the column if neither exists
      ALTER TABLE public.businesses ADD COLUMN owner_member_id UUID REFERENCES auth.users(id) ON DELETE CASCADE;
    END IF;
  END IF;
END $$;

-- Step 3: Check current discount table name
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
AND table_name IN ('merchant_discounts', 'trusted_partner_discounts');

-- Step 4: Rename merchant_discounts to trusted_partner_discounts if needed
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'merchant_discounts') THEN
    ALTER TABLE public.merchant_discounts RENAME TO trusted_partner_discounts;
  END IF;
END $$;

-- Step 5: Rename merchant_id column to trusted_partner_id if needed
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'trusted_partner_discounts' AND column_name = 'merchant_id'
  ) THEN
    ALTER TABLE public.trusted_partner_discounts RENAME COLUMN merchant_id TO trusted_partner_id;
  END IF;
END $$;

-- Step 6: Update foreign key constraint
ALTER TABLE public.trusted_partner_discounts DROP CONSTRAINT IF EXISTS merchant_discounts_merchant_id_fkey;
ALTER TABLE public.trusted_partner_discounts DROP CONSTRAINT IF EXISTS trusted_partner_discounts_merchant_id_fkey;
ALTER TABLE public.trusted_partner_discounts DROP CONSTRAINT IF EXISTS trusted_partner_discounts_trusted_partner_id_fkey;

ALTER TABLE public.trusted_partner_discounts
ADD CONSTRAINT trusted_partner_discounts_trusted_partner_id_fkey
FOREIGN KEY (trusted_partner_id) REFERENCES auth.users(id) ON DELETE CASCADE;

-- Step 7: Update RLS policies for trusted_partner_discounts
DROP POLICY IF EXISTS "Users can view their own discounts" ON public.trusted_partner_discounts;
DROP POLICY IF EXISTS "Users can insert their own discounts" ON public.trusted_partner_discounts;
DROP POLICY IF EXISTS "Users can update their own discounts" ON public.trusted_partner_discounts;
DROP POLICY IF EXISTS "Users can delete their own discounts" ON public.trusted_partner_discounts;
DROP POLICY IF EXISTS "Users can view active discounts from all merchants" ON public.trusted_partner_discounts;
DROP POLICY IF EXISTS "Members can view their own discounts" ON public.trusted_partner_discounts;
DROP POLICY IF EXISTS "Members can insert their own discounts" ON public.trusted_partner_discounts;
DROP POLICY IF EXISTS "Members can update their own discounts" ON public.trusted_partner_discounts;
DROP POLICY IF EXISTS "Members can delete their own discounts" ON public.trusted_partner_discounts;
DROP POLICY IF EXISTS "Members can view active discounts from all trusted partners" ON public.trusted_partner_discounts;

CREATE POLICY "Members can view their own discounts" ON public.trusted_partner_discounts
  FOR SELECT USING (auth.uid() = trusted_partner_id);

CREATE POLICY "Members can insert their own discounts" ON public.trusted_partner_discounts
  FOR INSERT WITH CHECK (auth.uid() = trusted_partner_id);

CREATE POLICY "Members can update their own discounts" ON public.trusted_partner_discounts
  FOR UPDATE USING (auth.uid() = trusted_partner_id);

CREATE POLICY "Members can delete their own discounts" ON public.trusted_partner_discounts
  FOR DELETE USING (auth.uid() = trusted_partner_id);

CREATE POLICY "Members can view active discounts from all trusted partners" ON public.trusted_partner_discounts
  FOR SELECT USING (is_active = true);

-- Step 8: Update indexes
DROP INDEX IF EXISTS idx_merchant_discounts_merchant_id;
DROP INDEX IF EXISTS idx_merchant_discounts_active;
DROP INDEX IF EXISTS idx_trusted_partner_discounts_merchant_id;

CREATE INDEX IF NOT EXISTS idx_trusted_partner_discounts_trusted_partner_id ON public.trusted_partner_discounts(trusted_partner_id);
CREATE INDEX IF NOT EXISTS idx_trusted_partner_discounts_active ON public.trusted_partner_discounts(is_active);

-- Step 9: Update the complete_business_profile function
CREATE OR REPLACE FUNCTION public.complete_business_profile(payload jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  uid uuid := auth.uid();
  v_name text := nullif(coalesce(payload->>'name', ''), '');
  v_cat text := nullif(coalesce(payload->>'category', ''), '');
  v_street text := nullif(coalesce(payload->>'street', ''), '');
  v_suburb text := nullif(coalesce(payload->>'suburb', ''), '');
  v_city text := nullif(coalesce(payload->>'city', ''), '');
  v_prov text := nullif(coalesce(payload->>'province', ''), '');
  v_contact_email text := nullif(coalesce(payload->>'contact_email', ''), '');
  v_contact_number text := nullif(coalesce(payload->>'contact_number', ''), '');
  v_latitude double precision := public.try_cast_double(coalesce(payload->>'latitude', null));
  v_longitude double precision := public.try_cast_double(coalesce(payload->>'longitude', null));
  v_address text;
  v_business_id uuid;
BEGIN
  IF uid IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'not_authenticated');
  END IF;

  -- Build address
  v_address := array_to_string(
    array_remove(array[v_street, v_suburb, v_city, v_prov], null),
    ', '
  );
  IF v_address = '' THEN v_address := null; END IF;

  -- Validation
  IF coalesce(v_name, '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'missing_business_name');
  END IF;
  IF coalesce(v_cat, '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'missing_category');
  END IF;

  -- Ensure user has trusted_partner role in memberships table
  INSERT INTO public.memberships (user_id, role, gateway)
  VALUES (uid, 'trusted_partner', 'business_profile_completion')
  ON CONFLICT (user_id) DO UPDATE
    SET role = 'trusted_partner',
        gateway = excluded.gateway;

  -- Also ensure profiles table has trusted_partner role
  UPDATE public.profiles
  SET role = 'trusted_partner'
  WHERE id = uid AND (role IS NULL OR role != 'trusted_partner');

  -- Create/update trusted_partners table with business name
  INSERT INTO public.trusted_partners (user_id, business_name)
  VALUES (uid, v_name)
  ON CONFLICT (user_id) DO UPDATE
    SET business_name = excluded.business_name,
        updated_at = NOW();

  -- Create/update business record
  INSERT INTO public.businesses (
    owner_member_id, name, category, address, latitude, longitude, contact_email, contact_number, verified
  ) VALUES (
    uid, v_name, v_cat, v_address, v_latitude, v_longitude, v_contact_email, v_contact_number, true
  ) ON CONFLICT (owner_member_id) DO UPDATE
    SET name = excluded.name,
        category = excluded.category,
        address = excluded.address,
        latitude = excluded.latitude,
        longitude = excluded.longitude,
        contact_email = excluded.contact_email,
        contact_number = excluded.contact_number,
        verified = true
  RETURNING id INTO v_business_id;

  RETURN jsonb_build_object('ok', true, 'business_id', v_business_id);

EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('ok', false, 'error', SQLERRM);
END;
$$;

-- Step 10: Verify the changes
SELECT 'Businesses table structure:' as info;
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'businesses'
ORDER BY ordinal_position;

SELECT 'Discount table name:' as info;
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
AND table_name IN ('merchant_discounts', 'trusted_partner_discounts');

SELECT 'Discount table structure:' as info;
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'trusted_partner_discounts'
ORDER BY ordinal_position;