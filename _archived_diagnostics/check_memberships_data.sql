SELECT m.user_id, m.role, m.gateway, p.email, p.name, p.surname FROM memberships m LEFT JOIN profiles p ON m.user_id = p.id ORDER BY m.role, p.created_at;
