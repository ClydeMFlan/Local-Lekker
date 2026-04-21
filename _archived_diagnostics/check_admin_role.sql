SELECT p.email, p.role as profile_role, m.role as membership_role FROM profiles p LEFT JOIN memberships m ON p.id = m.user_id WHERE p.email = 'admin@locallekker.com';
