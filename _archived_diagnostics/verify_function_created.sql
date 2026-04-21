-- Verify the trusted partner deletion function was created successfully

-- Check if the function exists
SELECT
    'Function Status:' as check,
    proname as function_name,
    pg_get_function_identity_arguments(oid) as arguments
FROM pg_proc
WHERE proname = 'admin_delete_trusted_partner_data';

-- Test that the function can be called (with a fake UUID to test error handling)
-- This should return an error about user not existing, proving the function works
-- SELECT admin_delete_trusted_partner_data('00000000-0000-0000-0000-000000000000'::uuid);