-- Test the trusted partner deletion function directly
-- Replace 'YOUR_TP_USER_ID_HERE' with the actual user ID from the pending tab

-- First, check if the user exists and is a trusted partner
SELECT
    'User Check:' as status,
    p.id,
    p.email,
    p.name,
    p.surname,
    p.role,
    p.verified,
    CASE WHEN tp.user_id IS NOT NULL THEN 'Has trusted_partners record' ELSE 'Missing trusted_partners record' END as tp_status
FROM profiles p
LEFT JOIN trusted_partners tp ON p.id = tp.user_id
WHERE p.id = 'YOUR_TP_USER_ID_HERE';

-- Test the deletion function (uncomment and replace with actual ID)
-- SELECT admin_delete_trusted_partner_data('YOUR_TP_USER_ID_HERE'::uuid);

-- After deletion, check if the user still exists
-- SELECT 'Post-deletion check:' as status, COUNT(*) as remaining_profiles
-- FROM profiles WHERE id = 'YOUR_TP_USER_ID_HERE';