# Quick Fix Guide - Admin Deal Image Upload

## Step 1: Apply the RLS Policy Fix
Run this in Supabase SQL Editor:
```sql
-- Copy and paste the contents of fix_admin_deal_image_upload_rls.sql
```

## Step 2: Verify the Fix
Run this in Supabase SQL Editor:
```sql
-- Copy and paste the contents of test_admin_deal_image_upload.sql
-- Replace 'PARTNER_UUID_HERE' in Step 5 with the actual partner's user ID
```

## Step 3: Check Results
The test should show:
- ✓ Step 1: User is admin
- ✓ Step 2: List of businesses with admin deal creation enabled
- ✓ Step 3: 9 storage policies exist
- ✓ Step 4: Path parsing works correctly
- ✓ Step 5: "PASS: Upload should work!"
- ✓ Step 6: Correct number of policies

## Step 4: Test in App
1. Rebuild the Flutter app
2. As admin, go to a trusted partner's profile
3. Create or edit a deal and upload an image
4. Check console logs for:
   ```
   DEBUG: Uploading image to path: deal_images/{partner-uuid}/{filename}
   DEBUG: Image uploaded successfully: {url}
   ```

## Common Issues

### Issue: "User is NOT admin"
**Fix:** Update the user's role in memberships table:
```sql
UPDATE public.memberships 
SET role = 'admin' 
WHERE user_id = '{your-user-id}';
```

### Issue: "Partner has NOT allowed admin deal creation"
**Fix:** Enable the permission for the partner's business:
```sql
UPDATE public.businesses 
SET allow_admin_deal_creation = true 
WHERE owner_member_id = '{partner-user-id}';
```

### Issue: "Unexpected number of policies"
**Fix:** Re-run the fix_admin_deal_image_upload_rls.sql script to clean up and recreate all policies.

## Files to Use
1. `fix_admin_deal_image_upload_rls.sql` - Main fix (run first)
2. `test_admin_deal_image_upload.sql` - Verification (run second)
3. `diagnose_admin_deal_image_permissions.sql` - Additional diagnostics (optional)
