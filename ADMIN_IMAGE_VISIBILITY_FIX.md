# Admin Deal Image Display Issue - Diagnosis & Fix

## Problem Summary
When a **Trusted Partner (TP) uploads a deal image**, the image is **visible to all members and TP members**.
When an **Admin uploads a deal image** to a TP's deal, the image **does not display** to anyone (including the admin).

## Root Cause Analysis

### Current RLS Policy Structure
Looking at `fix_admin_deal_image_upload_rls.sql`, the admin SELECT policy is:

```sql
CREATE POLICY "Admins can view deal images for authorized partners" ON storage.objects
    FOR SELECT USING (
        bucket_id = 'business-bills' AND
        name LIKE 'deal_images/%' AND
        EXISTS (
            SELECT 1
            FROM public.memberships m
            WHERE m.user_id = auth.uid()
              AND m.role = 'admin'
        ) AND
        EXISTS (
            SELECT 1
            FROM public.businesses b
            WHERE b.owner_member_id::text = split_part(name, '/', 2)
              AND COALESCE(b.allow_admin_deal_creation, false) = true  -- ← RESTRICTIVE!
        )
    );
```

### The Problem
The admin policy has TWO conditions joined by AND:
1. User is admin ✓
2. **Business has `allow_admin_deal_creation=true`** ← This fails if the partner hasn't enabled this flag!

When `allow_admin_deal_creation=false`:
- Admin SELECT policy fails
- BUT "Members can view deal images" is unconditional, so members CAN see the image
- Admin can see it in the "Members" context but not explicitly as admin

### Why TP Images Work
TP upload policy uses:
```sql
CREATE POLICY "Trusted partners can view deal images" ON storage.objects
    FOR SELECT USING (
        bucket_id = 'business-bills' AND
        name LIKE 'deal_images/%' AND
        split_part(name, '/', 2) = auth.uid()::text  -- ← Direct ownership check
    );
```
This only checks if the uploader is the owner - no business permission check needed.

## Solution

### Fix 1: Remove Restrictive Condition from Admin SELECT Policy
The admin SELECT policy should allow admins to view ANY deal image they upload, regardless of `allow_admin_deal_creation`.

**File**: `fix_admin_image_visibility_rls.sql` (already created)

Changes:
- Drop "Admins can view deal images for authorized partners"
- Create new "Admins can view deal images" (without the allow_admin_deal_creation check)
- Keep "Members can view deal images" (unconditional)
- Keep "Trusted partners can view deal images" (ownership-based)

### Fix 2: Apply SQL Migration to Supabase
Run `fix_admin_image_visibility_rls.sql` in Supabase SQL Editor

### Fix 3: Verify with Test Query
Run `diagnose_deal_image_policies.sql` to confirm policies are correct

## Testing After Fix

### Test Case 1: Admin Uploads Image
1. Login as Admin
2. Go to Trusted Partners → Partner Profile → Deals tab
3. Create new deal or edit existing
4. Upload an image
5. **Expected**: Image appears in deal thumbnail immediately

### Test Case 2: Member Views Admin-Uploaded Image
1. Login as Member
2. Go to Browse Deals
3. Find the partner with admin-uploaded image
4. **Expected**: Image displays correctly in deal card

### Test Case 3: TP Views Own Upload (Should Still Work)
1. Login as TP
2. Go to discount_management_page
3. Create/edit deal with image
4. **Expected**: Image displays in TP's own deal list

## Database RLS Policy Reference

### Final Correct Policies
```
Storage bucket: business-bills
Path pattern: deal_images/{trusted_partner_id}/{filename}

Policies needed:
1. "Admins can view deal images" → SELECT, no business permission check
2. "Members can view deal images" → SELECT, unrestricted (all authenticated users)
3. "Trusted partners can view deal images" → SELECT, ownership-based
4. "Admins can upload deal images..." → INSERT, WITH CHECK for business permission
5. "Trusted partners can upload deal images" → INSERT, ownership-based
6. (UPDATE and DELETE policies for both)
```

## Files Involved

### Code Changes
- `lib/features/admin/admin_partner_deals_screen.dart` - Added debug logging for image loading
- `lib/services/discount_service.dart` - Added logging for image URL handling

### SQL Files Created
- `fix_admin_image_visibility_rls.sql` - Main fix (NEEDS TO BE APPLIED)
- `diagnose_deal_image_policies.sql` - Verification query

### Status
🔴 **ACTION REQUIRED**: Run `fix_admin_image_visibility_rls.sql` in Supabase SQL Editor to apply the fix
