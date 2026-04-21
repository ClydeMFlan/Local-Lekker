-- =====================================================
-- USER DELETION CASCADE FUNCTION
-- Deletes all user data when a user is removed from auth.users
-- =====================================================

-- Function to delete all user-related data
CREATE OR REPLACE FUNCTION delete_user_cascade()
RETURNS TRIGGER AS $$
BEGIN
    -- Delete in order of dependencies (child tables first)

    -- Delete virtual receipts (references deal_authorizations)
    DELETE FROM virtual_receipts
    WHERE deal_authorization_id IN (
        SELECT id FROM deal_authorizations WHERE member_id = OLD.id
    );

    -- Delete deal receipts (references deal_authorizations)
    DELETE FROM deal_receipts
    WHERE member_id = OLD.id;

    -- Delete notifications
    DELETE FROM notifications WHERE user_id = OLD.id;

    -- Delete deal authorizations (both member and trusted partner)
    DELETE FROM deal_authorizations
    WHERE member_id = OLD.id OR trusted_partner_id = OLD.id;

    -- Delete processed bills (uses member_id, not user_id)
    DELETE FROM processed_bills WHERE member_id = OLD.id;

    -- Delete payments
    DELETE FROM payments WHERE user_id = OLD.id;

    -- Delete user QR codes
    DELETE FROM user_qr_codes WHERE user_id = OLD.id;

    -- Delete subscriptions
    DELETE FROM subscriptions WHERE user_id = OLD.id;

    -- Delete memberships (if table exists)
    DELETE FROM memberships WHERE user_id = OLD.id;

    -- Delete trusted partner bank accounts
    DELETE FROM trusted_partner_bank_accounts WHERE user_id = OLD.id;

    -- Delete businesses (this will cascade to related tables)
    DELETE FROM businesses WHERE owner_member_id = OLD.id;

    -- Delete trusted partners
    DELETE FROM trusted_partners WHERE user_id = OLD.id;

    -- Finally delete the profile
    DELETE FROM profiles WHERE id = OLD.id;

    -- Log the deletion
    RAISE LOG 'User % and all associated data deleted', OLD.id;

    RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger on auth.users table
DROP TRIGGER IF EXISTS on_auth_user_deleted ON auth.users;
CREATE TRIGGER on_auth_user_deleted
    AFTER DELETE ON auth.users
    FOR EACH ROW EXECUTE FUNCTION delete_user_cascade();

-- =====================================================
-- ALTERNATIVE: Manual deletion function for admin use
-- =====================================================

-- Function to manually delete a user and all their data
CREATE OR REPLACE FUNCTION admin_delete_user(target_user_id UUID)
RETURNS TEXT AS $$
DECLARE
    user_exists BOOLEAN;
    deleted_count INTEGER := 0;
BEGIN
    -- Check if user exists in auth.users
    SELECT EXISTS(SELECT 1 FROM auth.users WHERE id = target_user_id) INTO user_exists;

    IF NOT user_exists THEN
        RETURN 'User not found in auth.users';
    END IF;

    -- Delete in order of dependencies (child tables first)

    -- Delete virtual receipts
    DELETE FROM virtual_receipts
    WHERE deal_authorization_id IN (
        SELECT id FROM deal_authorizations WHERE member_id = target_user_id
    );
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RAISE LOG 'Deleted % virtual receipts for user %', deleted_count, target_user_id;

    -- Delete deal receipts
    DELETE FROM deal_receipts WHERE member_id = target_user_id;
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RAISE LOG 'Deleted % deal receipts for user %', deleted_count, target_user_id;

    -- Delete notifications
    DELETE FROM notifications WHERE user_id = target_user_id;
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RAISE LOG 'Deleted % notifications for user %', deleted_count, target_user_id;

    -- Delete deal authorizations
    DELETE FROM deal_authorizations
    WHERE member_id = target_user_id OR trusted_partner_id = target_user_id;
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RAISE LOG 'Deleted % deal authorizations for user %', deleted_count, target_user_id;

    -- Delete processed bills (uses member_id, not user_id)
    DELETE FROM processed_bills WHERE member_id = target_user_id;
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RAISE LOG 'Deleted % processed bills for user %', deleted_count, target_user_id;

    -- Delete payments
    DELETE FROM payments WHERE user_id = target_user_id;
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RAISE LOG 'Deleted % payments for user %', deleted_count, target_user_id;

    -- Delete user QR codes
    DELETE FROM user_qr_codes WHERE user_id = target_user_id;
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RAISE LOG 'Deleted % user QR codes for user %', deleted_count, target_user_id;

    -- Delete subscriptions
    DELETE FROM subscriptions WHERE user_id = target_user_id;
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RAISE LOG 'Deleted % subscriptions for user %', deleted_count, target_user_id;

    -- Delete memberships
    DELETE FROM memberships WHERE user_id = target_user_id;
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RAISE LOG 'Deleted % memberships for user %', deleted_count, target_user_id;

    -- Delete trusted partner bank accounts
    DELETE FROM trusted_partner_bank_accounts WHERE user_id = target_user_id;
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RAISE LOG 'Deleted % trusted partner bank accounts for user %', deleted_count, target_user_id;

    -- Delete businesses (cascades to related data)
    DELETE FROM businesses WHERE owner_member_id = target_user_id;
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RAISE LOG 'Deleted % businesses for user %', deleted_count, target_user_id;

    -- Delete trusted partners
    DELETE FROM trusted_partners WHERE user_id = target_user_id;
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RAISE LOG 'Deleted % trusted partners for user %', deleted_count, target_user_id;

    -- Delete profile
    DELETE FROM profiles WHERE id = target_user_id;
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RAISE LOG 'Deleted % profiles for user %', deleted_count, target_user_id;

    -- Finally delete from auth.users
    DELETE FROM auth.users WHERE id = target_user_id;
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RAISE LOG 'Deleted % auth user records for user %', deleted_count, target_user_id;

    RETURN 'User and all associated data successfully deleted';

EXCEPTION
    WHEN OTHERS THEN
        RETURN 'Error deleting user: ' || SQLERRM;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- GRANT PERMISSIONS
-- =====================================================

-- Grant execute permission on the admin function to authenticated users
-- (you may want to restrict this to specific roles)
GRANT EXECUTE ON FUNCTION admin_delete_user(UUID) TO authenticated;

-- =====================================================
-- USAGE EXAMPLES
-- =====================================================

/*
-- Automatic deletion (trigger-based):
-- When you delete a user from Supabase Auth dashboard,
-- all associated data is automatically cleaned up

-- Manual deletion (admin function):
SELECT admin_delete_user('user-uuid-here');

-- Check what data exists for a user before deletion:
SELECT
    (SELECT COUNT(*) FROM profiles WHERE id = 'user-uuid') as profiles,
    (SELECT COUNT(*) FROM trusted_partners WHERE user_id = 'user-uuid') as trusted_partners,
    (SELECT COUNT(*) FROM businesses WHERE owner_member_id = 'user-uuid') as businesses,
    (SELECT COUNT(*) FROM subscriptions WHERE user_id = 'user-uuid') as subscriptions,
    (SELECT COUNT(*) FROM payments WHERE user_id = 'user-uuid') as payments,
    (SELECT COUNT(*) FROM notifications WHERE user_id = 'user-uuid') as notifications,
    (SELECT COUNT(*) FROM deal_authorizations WHERE member_id = 'user-uuid' OR trusted_partner_id = 'user-uuid') as deal_authorizations;
*/