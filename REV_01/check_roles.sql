-- Check current roles in memberships table
SELECT DISTINCT role, COUNT(*) as count FROM public.memberships GROUP BY role ORDER BY role;
