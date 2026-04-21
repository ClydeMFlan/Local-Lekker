# Issue: Facebook Handle Not Saving

## Problem
When a trusted partner adds a Facebook handle in the Business Profile Edit screen and clicks "Save Business Profile", the data doesn't persist. When reopening the edit screen, the Facebook field is empty, and members don't see the Facebook icon in the trusted partner UI.

## Root Cause
The Flutter app code was updated correctly to:
1. ✅ Display the social media input fields
2. ✅ Send the data in the payload
3. ✅ Load the data from the database

However, the **database function** `complete_business_profile()` was not updated to:
- ❌ Accept the new social media parameters from the payload
- ❌ Insert/update these fields in the businesses table

Additionally, the **database columns** may not exist if the initial migration wasn't run.

## Solution

### Step 1: Run the Complete Migration
Execute the SQL file: **`COMPLETE_SOCIAL_MEDIA_MIGRATION.sql`**

This will:
1. Add the 4 new columns to the `businesses` table (if they don't exist)
2. Update the `complete_business_profile()` function to handle social media fields

### Step 2: Test the Fix

#### As Trusted Partner:
1. Login to your trusted partner account
2. Go to Business Profile/Details
3. Scroll to "Social Media & Web Presence" section
4. Add your Facebook handle (e.g., `facebook.com/thatoldoak` or `@thatoldoak`)
5. Click "Save Business Details"
6. Navigate away, then come back to Business Profile Edit
7. ✅ Your Facebook handle should now be visible in the form

#### As Member:
1. Login as a member
2. Go to "View Trusted Partners"
3. Find "That Old Oak" (or the business you updated)
4. Click on it to view the shop
5. ✅ You should see a "Connect with us" section with a clickable Facebook button
6. Click the Facebook button
7. ✅ It should open the Facebook page in your browser

## Technical Details

### What the Migration Does

**Columns Added:**
```sql
ALTER TABLE businesses 
ADD COLUMN IF NOT EXISTS facebook_handle TEXT,
ADD COLUMN IF NOT EXISTS instagram_handle TEXT,
ADD COLUMN IF NOT EXISTS website_url TEXT,
ADD COLUMN IF NOT EXISTS business_email TEXT;
```

**Function Updated:**
The `complete_business_profile()` function now:
- Extracts social media fields from the JSON payload
- Inserts them into the businesses table on INSERT
- Updates them on CONFLICT (when updating existing business)

### Verification

After running the migration, you can verify it worked:

```sql
-- Check columns exist
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'businesses' 
AND column_name IN ('facebook_handle', 'instagram_handle', 'website_url', 'business_email');

-- Check your business data
SELECT name, facebook_handle, instagram_handle, website_url, business_email
FROM businesses
WHERE name = 'That Old Oak';
```

## Files Modified

1. **COMPLETE_SOCIAL_MEDIA_MIGRATION.sql** - Complete migration script (RUN THIS)
2. **lib/features/auth/business_profile_page.dart** - Already updated ✅
3. **lib/features/auth/trusted_partner_shop_page.dart** - Already updated ✅
4. **lib/features/auth/trusted_partners_by_category_page.dart** - Already updated ✅

## Next Steps

1. Open Supabase SQL Editor
2. Copy contents of `COMPLETE_SOCIAL_MEDIA_MIGRATION.sql`
3. Paste and run it
4. Test saving Facebook handle again
5. Verify it persists and displays to members
