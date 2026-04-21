-- Check notifications for the trusted partner
SELECT * FROM notifications
WHERE user_id = (SELECT id FROM auth.users WHERE email = 'houselillian5@gmail.com')
ORDER BY created_at DESC;

-- Check deal authorizations
SELECT * FROM deal_authorizations
ORDER BY created_at DESC
LIMIT 5;
