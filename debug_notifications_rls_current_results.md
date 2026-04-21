# Debug Results: Notifications RLS

Please run the following SQL in your Supabase SQL editor and paste the results here:

```sql
-- List all policies for notifications
SELECT 
    policyname, 
    cmd, 
    permissive, 
    roles, 
    qual::text as using_clause, 
    with_check::text as with_check_clause
FROM pg_policies
WHERE tablename = 'notifications';

-- Show current session role
SELECT current_user, session_user, current_role;

-- Show auth context
SELECT auth.uid(), auth.role(), auth.email();

-- Show table structure
SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'notifications';

-- Show triggers
SELECT * FROM information_schema.triggers WHERE event_object_table = 'notifications';

-- Show foreign keys
SELECT 
    tc.constraint_name, 
    kcu.column_name, 
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name 
FROM 
    information_schema.table_constraints AS tc 
    JOIN information_schema.key_column_usage AS kcu
      ON tc.constraint_name = kcu.constraint_name
    JOIN information_schema.constraint_column_usage AS ccu
      ON ccu.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY' AND tc.table_name='notifications';

-- Show all roles
SELECT rolname FROM pg_roles;
```

Paste the output here so I can analyze for hidden issues (restrictive policies, triggers, foreign keys, or role problems).
