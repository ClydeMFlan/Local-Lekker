-- Check current state of trusted partners in database
-- This will help us understand why the partner is still showing in the UI

SELECT
    'Current Trusted Partners Status:' as status,
    COUNT(*) as total_profiles_with_tp_role
FROM profiles
WHERE role = 'trusted_partner';

-- Check if there are any orphaned trusted_partners records (without profiles)
SELECT
    'Orphaned trusted_partners records:' as status,
    COUNT(*) as orphaned_tp_records
FROM trusted_partners tp
LEFT JOIN profiles p ON tp.user_id = p.id
WHERE p.id IS NULL;

-- Show details of all trusted partners currently in profiles
SELECT
    'Current TP Profiles:' as status,
    p.id,
    p.email,
    p.name,
    p.surname,
    p.role,
    p.verified,
    p.admin_created,
    p.created_at,
    CASE WHEN tp.user_id IS NOT NULL THEN 'Has TP record' ELSE 'Missing TP record' END as tp_record_status
FROM profiles p
LEFT JOIN trusted_partners tp ON p.id = tp.user_id
WHERE p.role = 'trusted_partner'
ORDER BY p.created_at DESC;

-- Check if the Edge Function URL is configured correctly
SELECT
    'Edge Function URL check:' as status,
    CASE
        WHEN current_setting('app.jwt_secret', true) IS NOT NULL THEN 'JWT configured'
        ELSE 'JWT not configured'
    END as jwt_status;