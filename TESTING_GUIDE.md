
# Manual Testing Guide for Admin Trusted Partner Creation

## Prerequisites
1. Apply all the database fixes:
   - Service role policy for trusted_partners table
   - Updated trigger function with better error handling
   - Code changes in admin_add_trusted_partner_page.dart

## Test Steps

### Step 1: Verify Database Setup
Run these queries in Supabase SQL Editor:

`sql
-- Check trigger is installed
SELECT trigger_name, event_manipulation, action_statement
FROM information_schema.triggers 
WHERE event_object_table = 'users' AND event_object_schema = 'auth';

-- Check RLS policies for trusted_partners
SELECT schemaname, tablename, policyname, cmd, qual, roles
FROM pg_policies 
WHERE tablename = 'trusted_partners';

-- Check trigger function exists
SELECT proname FROM pg_proc WHERE proname = 'handle_new_user_role_assignment';
`

### Step 2: Test in Flutter App
1. Run the app and log in as admin
2. Go to Admin → Add Trusted Partner
3. Fill in the form:
   - Name: Test
   - Surname: Partner  
   - Email: test_tp_[timestamp]@example.com
   - Business Name: Test Business
4. Click 'Next'
5. Check the success dialog appears

### Step 3: Verify Database Records
Run this query in Supabase SQL Editor (replace with actual email):

`sql
SELECT 
    'auth.users' as source,
    au.id,
    au.email,
    au.raw_user_meta_data,
    au.raw_app_meta_data,
    au.created_at
FROM auth.users au
WHERE au.email = 'your_test_email@example.com'

UNION ALL

SELECT 
    'profiles' as source,
    p.id,
    p.email,
    json_build_object(
        'name', p.name,
        'surname', p.surname,
        'role', p.role,
        'admin_created', p.admin_created,
        'password_set', p.password_set
    ) as metadata,
    null,
    p.created_at
FROM profiles p
WHERE p.email = 'your_test_email@example.com'

UNION ALL

SELECT 
    'memberships' as source,
    m.user_id as id,
    null as email,
    json_build_object('role', m.role, 'gateway', m.gateway) as metadata,
    null,
    m.created_at
FROM memberships m
JOIN profiles p ON m.user_id = p.id
WHERE p.email = 'your_test_email@example.com'

UNION ALL

SELECT 
    'trusted_partners' as source,
    tp.user_id as id,
    null as email,
    json_build_object('business_name', tp.business_name) as metadata,
    null,
    tp.created_at
FROM trusted_partners tp
JOIN profiles p ON tp.user_id = p.id
WHERE p.email = 'your_test_email@example.com'
ORDER BY created_at;
`

### Step 4: Expected Results
You should see:
1. ✅ User created in auth.users with correct metadata
2. ✅ Profile record with admin_created=true, password_set=false, role='trusted_partner'
3. ✅ Membership record with role='trusted_partner', gateway='automatic_signup'
4. ✅ Trusted partner record with business_name set
5. ✅ No errors in Flutter app logs
6. ✅ Success dialog shows in app

### Step 5: Check Logs
- Check Supabase dashboard logs for any trigger errors
- Check Flutter app logs for any errors during creation
- Look for the trigger debug messages in database logs

## Troubleshooting

### If profile is not created:
- Check trigger function is properly installed
- Check for RLS policy violations in logs

### If trusted_partners record missing:
- Verify service role policy was applied
- Check trigger error logs

### If metadata is wrong:
- Verify the string format ('true'/'false') in the Flutter code
- Check trigger function metadata parsing

### If auth creation fails:
- Check Supabase Auth configuration
- Verify email format is valid
- Check rate limits

## Success Criteria
✅ Admin can create trusted partner without errors
✅ All database records are created correctly
✅ Metadata is stored properly in auth.users
✅ Profile has correct admin_created/password_set flags
✅ Membership and trusted_partners records exist
✅ No RLS policy violations
✅ Flutter app shows success message

