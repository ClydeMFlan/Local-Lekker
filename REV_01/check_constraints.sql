-- Check all constraints on profiles and memberships tables
SELECT conname, conrelid::regclass, pg_get_constraintdef(oid)
FROM pg_constraint
WHERE conrelid IN ('public.profiles'::regclass, 'public.memberships'::regclass)
ORDER BY conrelid, conname;
