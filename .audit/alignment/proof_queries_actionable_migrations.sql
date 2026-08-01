-- Proof queries for actionable migration classification
-- Project: qdrotavcmmevhgveodcp
--
-- IMPORTANT:
-- 1) Run ONE section at a time (Q1, then Q2, ...).
-- 2) Copy the result table after each run.
-- 3) Paste each result back in chat with the query label.
--
-- Why: Some SQL editors only keep the last result visible when many queries run together.

-- Q1) Version drift pair mapping evidence (20251125 vs 20251202)
SELECT 'Q1_version_drift_mapping' AS query_label;
SELECT version, name
FROM supabase_migrations.schema_migrations
WHERE version IN (
  '20251125100511', '20251125100512',
  '20251202000000', '20251202000001'
)
ORDER BY version;

-- Q2) 20251125120000_fix_trusted_partner_deletion_function
-- Check function existence/signature and body fingerprint
SELECT 'Q2_trusted_partner_delete_functions' AS query_label;
SELECT
  p.proname,
  pg_get_function_identity_arguments(p.oid) AS args,
  md5(pg_get_functiondef(p.oid)) AS function_md5,
  left(pg_get_functiondef(p.oid), 400) AS function_head
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname IN ('admin_delete_trusted_partner_data', 'admin_delete_member_data')
ORDER BY p.proname;

-- Q3) 20260207182830_fix_deal_image_upload_rls
SELECT 'Q3_storage_deal_image_policies' AS query_label;
SELECT schemaname, tablename, policyname, cmd, qual, with_check
FROM pg_policies
WHERE schemaname = 'storage'
  AND tablename = 'objects'
  AND (
    policyname ILIKE '%deal image%'
    OR policyname ILIKE '%deal_images%'
    OR qual::text ILIKE '%deal_images/%'
    OR with_check::text ILIKE '%deal_images/%'
  )
ORDER BY cmd, policyname;

-- Q4) 20260518090000_allow_null_discount_id_on_deal_authorizations
SELECT 'Q4_discount_id_nullability' AS query_label;
SELECT
  table_schema,
  table_name,
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'deal_authorizations'
  AND column_name = 'discount_id';

-- Q5) 202606 RPC verification block
SELECT 'Q5_202606_rpc_verification' AS query_label;
SELECT
  p.proname,
  pg_get_function_identity_arguments(p.oid) AS args,
  p.prosecdef AS security_definer,
  p.provolatile,
  md5(pg_get_functiondef(p.oid)) AS function_md5,
  left(pg_get_functiondef(p.oid), 280) AS function_head
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname IN (
    'accept_member_terms',
    'get_member_terms_status',
    'validate_member_qr_scan',
    'accept_tp_payment_terms',
    'activate_tp_member_profile',
    'create_user_profile'
  )
ORDER BY p.proname;

-- Q6) businesses RLS recursion fix evidence
SELECT 'Q6_businesses_rls_recursion' AS query_label;
SELECT schemaname, tablename, policyname, cmd, qual, with_check
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename = 'businesses'
ORDER BY policyname, cmd;

-- Optional: quick checklist query to confirm section counts
SELECT
  'Q1-Q6 checklist' AS query_label,
  6 AS expected_sections;

-- Q7) Follow-up: unresolved checks from Q5
-- 7a) Explicit existence check for get_member_terms_status
SELECT 'Q7a_get_member_terms_status_exists' AS query_label;
SELECT
  p.proname,
  pg_get_function_identity_arguments(p.oid) AS args,
  p.prosecdef AS security_definer,
  md5(pg_get_functiondef(p.oid)) AS function_md5,
  left(pg_get_functiondef(p.oid), 280) AS function_head
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname = 'get_member_terms_status';

-- 7a2) Corrected existence check for member terms status RPC used by app/migration
SELECT 'Q7a2_member_terms_accepted_status_exists' AS query_label;
SELECT
  p.proname,
  pg_get_function_identity_arguments(p.oid) AS args,
  p.prosecdef AS security_definer,
  md5(pg_get_functiondef(p.oid)) AS function_md5,
  left(pg_get_functiondef(p.oid), 280) AS function_head
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname = 'member_terms_accepted_status';

-- 7b) create_user_profile subscription-preservation evidence
SELECT 'Q7b_create_user_profile_subscription_check' AS query_label;
SELECT
  md5(pg_get_functiondef(p.oid)) AS function_md5,
  (pg_get_functiondef(p.oid) ILIKE '%subscription%') AS has_subscription_token,
  (pg_get_functiondef(p.oid) ILIKE '%coalesce%' AND pg_get_functiondef(p.oid) ILIKE '%subscription%') AS has_coalesce_subscription_pattern,
  left(pg_get_functiondef(p.oid), 1200) AS function_head
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname = 'create_user_profile';
