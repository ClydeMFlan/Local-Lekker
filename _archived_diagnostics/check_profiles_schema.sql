-- Check profiles table columns and their data types
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM 
    information_schema.columns 
WHERE 
    table_schema = 'public' 
    AND table_name = 'profiles'
ORDER BY 
    ordinal_position;

-- Also check if the table exists and get a count of records
SELECT 
    schemaname,
    tablename,
    tableowner
FROM 
    pg_tables 
WHERE 
    tablename = 'profiles' 
    AND schemaname = 'public';

-- Check the table structure with constraints
SELECT 
    conname as constraint_name,
    conrelid::regclass as table_name,
    pg_get_constraintdef(c.oid) as constraint_definition
FROM 
    pg_constraint c
WHERE 
    conrelid::regclass::text = 'profiles';
