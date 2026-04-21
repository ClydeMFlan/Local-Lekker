-- Check profiles table structure to ensure all member signup fields exist
SELECT '=== PROFILES TABLE STRUCTURE ===' as info;
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_name = 'profiles' AND table_schema = 'public'
ORDER BY ordinal_position;

-- Check if all required columns for member signup exist
SELECT '=== MEMBER SIGNUP FIELD CHECK ===' as info;
SELECT
    'name' as field,
    CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'name') THEN 'EXISTS' ELSE 'MISSING' END as status
UNION ALL
SELECT 'surname', CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'surname') THEN 'EXISTS' ELSE 'MISSING' END
UNION ALL
SELECT 'email', CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'email') THEN 'EXISTS' ELSE 'MISSING' END
UNION ALL
SELECT 'street', CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'street') THEN 'EXISTS' ELSE 'MISSING' END
UNION ALL
SELECT 'suburb', CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'suburb') THEN 'EXISTS' ELSE 'MISSING' END
UNION ALL
SELECT 'city', CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'city') THEN 'EXISTS' ELSE 'MISSING' END
UNION ALL
SELECT 'province', CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'province') THEN 'EXISTS' ELSE 'MISSING' END
UNION ALL
SELECT 'contact', CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'contact') THEN 'EXISTS' ELSE 'MISSING' END
UNION ALL
SELECT 'gender', CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'gender') THEN 'EXISTS' ELSE 'MISSING' END
UNION ALL
SELECT 'ethnicity', CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'ethnicity') THEN 'EXISTS' ELSE 'MISSING' END
UNION ALL
SELECT 'date_of_birth', CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'date_of_birth') THEN 'EXISTS' ELSE 'MISSING' END
UNION ALL
SELECT 'role', CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'role') THEN 'EXISTS' ELSE 'MISSING' END;