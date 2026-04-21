-- Comprehensive SQL query to check deal fields used to trigger and count deal request notifications for trusted partners

-- Count total pending deal authorizations
SELECT COUNT(*) as total_pending_deals FROM deal_authorizations WHERE status = 'pending';

-- Count total deal request notifications
SELECT COUNT(*) as total_deal_request_notifications FROM notifications WHERE type = 'deal_request';

-- Find pending deal authorizations without corresponding notifications
SELECT da.id, da.member_id, da.trusted_partner_id, da.discount_id, da.status, da.authorization_type, da.payment_method, da.amount, da.notes, da.rejection_reason, da.created_at, da.updated_at, da.approved_at, da.completed_at
FROM deal_authorizations da
LEFT JOIN notifications n ON (n.data->>'deal_authorization_id')::uuid = da.id AND n.type = 'deal_request'
WHERE da.status = 'pending' AND n.id IS NULL;

-- Show all pending deal authorizations with their notification status
SELECT
    da.id as deal_auth_id,
    da.member_id,
    da.trusted_partner_id,
    da.discount_id,
    da.status,
    da.authorization_type,
    da.payment_method,
    da.amount,
    da.notes,
    da.rejection_reason,
    da.created_at as deal_created_at,
    da.updated_at,
    da.approved_at,
    da.completed_at,
    n.id as notification_id,
    n.user_id as notification_user_id,
    n.type as notification_type,
    n.title as notification_title,
    n.message as notification_message,
    n.data as notification_data,
    n.created_at as notification_created_at,
    n.is_read
FROM deal_authorizations da
LEFT JOIN notifications n ON (n.data->>'deal_authorization_id')::uuid = da.id AND n.type = 'deal_request'
WHERE da.status = 'pending'
ORDER BY da.created_at DESC;

-- Show notification data structure for deal requests
SELECT
    n.id,
    n.user_id,
    n.type,
    n.title,
    n.message,
    n.data->>'deal_authorization_id' as deal_auth_id,
    n.data->>'member_id' as member_id,
    n.data->>'amount' as amount,
    n.created_at,
    n.is_read
FROM notifications n
WHERE n.type = 'deal_request'
ORDER BY n.created_at DESC;