-- Check and fix trusted partner deletion issue
-- Run this SQL manually in your Supabase SQL editor

-- 1. Check if the user exists in all required tables
SELECT
    'User Status Check:' as check_type,
    CASE WHEN p.id IS NOT NULL THEN 'EXISTS' ELSE 'MISSING' END as profiles_status,
    CASE WHEN tp.user_id IS NOT NULL THEN 'EXISTS' ELSE 'MISSING' END as trusted_partners_status,
    CASE WHEN m.user_id IS NOT NULL THEN 'EXISTS' ELSE 'MISSING' END as memberships_status,
    p.role,
    p.admin_created,
    p.password_set
FROM profiles p
LEFT JOIN trusted_partners tp ON tp.user_id = p.id
LEFT JOIN memberships m ON m.user_id = p.id
WHERE p.id = '736ac25c-5e0b-45af-a3f0-c670c11aa222';

-- 2. If user exists in profiles but not in trusted_partners, we need to fix this
-- Option A: Delete the orphaned profile record (if they're not really a TP)
-- Option B: Create the missing trusted_partners record (if they should be a TP)

-- Option A: If this user should NOT be a trusted partner, delete their profile:
-- DELETE FROM profiles WHERE id = '736ac25c-5e0b-45af-a3f0-c670c11aa222';

-- Option B: If this user SHOULD be a trusted partner, create the missing record:
-- INSERT INTO trusted_partners (user_id, business_name, created_at)
-- VALUES ('736ac25c-5e0b-45af-a3f0-c670c11aa222', 'Business Name Here', NOW());

-- 3. Apply the improved deletion function with better error messages
CREATE OR REPLACE FUNCTION admin_delete_trusted_partner_data(tp_user_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  deleted_count JSONB;
  tp_email TEXT;
  tp_name TEXT;
  business_ids UUID[] := ARRAY[]::UUID[];
  deal_ids UUID[] := ARRAY[]::UUID[];
  col_name TEXT;
  sql TEXT;
BEGIN
  -- Verify the user exists in profiles with trusted_partner role
  SELECT p.email, p.name INTO tp_email, tp_name
  FROM profiles p
  WHERE p.id = tp_user_id AND p.role = 'trusted_partner';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'User % does not exist in profiles with trusted_partner role', tp_user_id;
  END IF;

  -- Check if they have a trusted_partners record (log but don't fail if missing)
  IF NOT EXISTS (SELECT 1 FROM trusted_partners WHERE user_id = tp_user_id) THEN
    RAISE NOTICE 'User % has trusted_partner role but no trusted_partners record - proceeding with deletion anyway', tp_user_id;
  END IF;

  -- Helper: find appropriate owner column for businesses
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'businesses' AND column_name = 'user_id') THEN
    col_name := 'user_id';
  ELSIF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'businesses' AND column_name = 'owner_member_id') THEN
    col_name := 'owner_member_id';
  ELSE
    col_name := NULL;
  END IF;

  IF col_name IS NOT NULL THEN
    sql := format('SELECT array_agg(id) FROM public.businesses WHERE %I = $1', col_name);
    EXECUTE sql INTO business_ids USING tp_user_id;
  ELSE
    business_ids := ARRAY[]::UUID[];
  END IF;

  -- Get deals for those businesses
  IF business_ids IS NOT NULL AND array_length(business_ids,1) IS NOT NULL THEN
    SELECT array_agg(id) INTO deal_ids FROM trusted_partner_discounts WHERE business_id = ANY(business_ids);
  END IF;

  deleted_count := jsonb_build_object(
    'tp_user_id', tp_user_id,
    'email', tp_email,
    'name', tp_name,
    'business_ids', COALESCE(business_ids, ARRAY[]::UUID[]),
    'deal_ids', COALESCE(deal_ids, ARRAY[]::UUID[])
  );

  -- Delete deal-related data if present
  IF deal_ids IS NOT NULL AND array_length(deal_ids,1) IS NOT NULL THEN
    EXECUTE 'DELETE FROM deal_receipts WHERE deal_id = ANY($1)' USING deal_ids;
    deleted_count := deleted_count || jsonb_build_object('deal_receipts_deleted', true);

    EXECUTE 'DELETE FROM virtual_receipts WHERE deal_id = ANY($1)' USING deal_ids;
    deleted_count := deleted_count || jsonb_build_object('virtual_receipts_deleted', true);

    EXECUTE 'DELETE FROM member_receipts WHERE deal_id = ANY($1)' USING deal_ids;
    deleted_count := deleted_count || jsonb_build_object('member_receipts_deleted', true);

    EXECUTE 'DELETE FROM deal_authorizations WHERE deal_id = ANY($1)' USING deal_ids;
    deleted_count := deleted_count || jsonb_build_object('deal_authorizations_deleted', true);

    EXECUTE 'DELETE FROM deal_images WHERE deal_id = ANY($1)' USING deal_ids;
    deleted_count := deleted_count || jsonb_build_object('deal_images_deleted', true);

    EXECUTE 'DELETE FROM trusted_partner_discounts WHERE id = ANY($1)' USING deal_ids;
    deleted_count := deleted_count || jsonb_build_object('deals_deleted', true);
  END IF;

  -- Delete processed bills for businesses
  IF business_ids IS NOT NULL AND array_length(business_ids,1) IS NOT NULL THEN
    EXECUTE 'DELETE FROM processed_bills WHERE business_id = ANY($1)' USING business_ids;
    deleted_count := deleted_count || jsonb_build_object('processed_bills_deleted', true);
  END IF;

  -- Delete businesses using detected owner column if available
  IF col_name IS NOT NULL THEN
    sql := format('DELETE FROM public.businesses WHERE %I = $1', col_name);
    EXECUTE sql USING tp_user_id;
    deleted_count := deleted_count || jsonb_build_object('businesses_deleted', true);
  END IF;

  -- Generic helper to delete from tables where column may be named user_id or member_id
  FOR col_name IN SELECT unnest(ARRAY['user_id','member_id','owner_member_id']) LOOP
    EXIT WHEN col_name IS NULL;
    -- trusted_partners
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='trusted_partners' AND column_name = col_name) THEN
      sql := format('DELETE FROM public.trusted_partners WHERE %I = $1', col_name);
      EXECUTE sql USING tp_user_id;
      deleted_count := deleted_count || jsonb_build_object('trusted_partner_record_deleted', true);
      EXIT; -- done for trusted_partners
    END IF;
  END LOOP;

  -- Tables that usually have user_id; try to delete if column exists, otherwise skip
  PERFORM 1; -- nop
  IF EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='paystack_subaccounts' AND column_name='user_id') THEN
    EXECUTE 'DELETE FROM paystack_subaccounts WHERE user_id = $1' USING tp_user_id;
    deleted_count := deleted_count || jsonb_build_object('paystack_subaccounts_deleted', true);
  END IF;

  IF EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='partner_bank_accounts' AND column_name='user_id') THEN
    EXECUTE 'DELETE FROM partner_bank_accounts WHERE user_id = $1' USING tp_user_id;
    deleted_count := deleted_count || jsonb_build_object('bank_accounts_deleted', true);
  END IF;

  IF EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='user_qr_codes' AND column_name='user_id') THEN
    EXECUTE 'DELETE FROM user_qr_codes WHERE user_id = $1' USING tp_user_id;
    deleted_count := deleted_count || jsonb_build_object('qr_codes_deleted', true);
  END IF;

  IF EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='payments' AND column_name='user_id') THEN
    EXECUTE 'DELETE FROM payments WHERE user_id = $1' USING tp_user_id;
    deleted_count := deleted_count || jsonb_build_object('payments_deleted', true);
  END IF;

  IF EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='notifications' AND column_name='user_id') THEN
    EXECUTE 'DELETE FROM notifications WHERE user_id = $1' USING tp_user_id;
    deleted_count := deleted_count || jsonb_build_object('notifications_deleted', true);
  END IF;

  IF EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='memberships' AND column_name='user_id') THEN
    EXECUTE 'DELETE FROM memberships WHERE user_id = $1' USING tp_user_id;
    deleted_count := deleted_count || jsonb_build_object('memberships_deleted', true);
  END IF;

  -- Finally delete profile if exists
  IF EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='profiles' AND column_name='id') THEN
    EXECUTE 'DELETE FROM profiles WHERE id = $1' USING tp_user_id;
    deleted_count := deleted_count || jsonb_build_object('profile_deleted', true);
  END IF;

  RETURN deleted_count::json;
EXCEPTION
  WHEN OTHERS THEN
    RAISE EXCEPTION 'Failed to delete trusted partner data: %', SQLERRM;
END;
$$;

