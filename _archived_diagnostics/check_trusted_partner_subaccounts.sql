-- Verify schema and data for trusted partner banking + subaccounts

-- 1) Columns present on trusted_partner_bank_accounts
SELECT 
  column_name,
  data_type,
  is_nullable,
  column_default
FROM information_schema.columns
WHERE table_schema='public'
  AND table_name='trusted_partner_bank_accounts'
ORDER BY ordinal_position;

-- 2) All current rows (masked acc numbers expected)
SELECT 
  user_id,
  account_holder_name,
  bank_name,
  account_number,
  branch_code,
  bank_account_type,
  paystack_recipient_code,
  subaccount_code,
  percentage_charge,
  subaccount_active,
  created_at,
  subaccount_created_at,
  updated_at
FROM public.trusted_partner_bank_accounts
ORDER BY created_at DESC;

-- 3) Lookup by business name (Momsie / Momsies)
-- Uses businesses.owner_member_id -> profiles.id -> tpba.user_id
SELECT 
  b.name AS business_name,
  p.id   AS partner_user_id,
  tpba.account_holder_name,
  tpba.bank_name,
  tpba.account_number,
  tpba.branch_code,
  tpba.bank_account_type,
  tpba.paystack_recipient_code,
  tpba.subaccount_code,
  tpba.percentage_charge,
  tpba.subaccount_active,
  tpba.subaccount_created_at,
  tpba.updated_at
FROM public.businesses b
JOIN public.profiles p
  ON p.id = b.owner_member_id
LEFT JOIN public.trusted_partner_bank_accounts tpba
  ON tpba.user_id = p.id AND tpba.is_active = true
WHERE lower(b.name) IN ('momsie','momsies')
ORDER BY tpba.updated_at DESC NULLS LAST, tpba.created_at DESC NULLS LAST;

-- 4) Health checks
-- Partners missing subaccount_code
SELECT 
  user_id,
  account_holder_name,
  COALESCE(subaccount_code,'') = '' AS missing_subaccount,
  subaccount_active
FROM public.trusted_partner_bank_accounts
WHERE is_active = true
ORDER BY created_at DESC;
