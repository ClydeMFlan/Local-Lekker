# Testing Checklist - Admin Edit & Image Visibility

## Test 1: Admin Edit Trusted Partner
1. **Access Edit**:
   - [ ] Login as admin
   - [ ] Navigate to Trusted Partners list
   - [ ] Open a partner's profile
   - [ ] Verify Edit button (pencil icon) appears in AppBar
   - [ ] Click Edit button

2. **Edit Form Display**:
   - [ ] All fields pre-populated with existing data
   - [ ] Existing logo displays (if present)
   - [ ] Password fields show "New Password (Optional)" label
   - [ ] Page title shows "Edit Trusted Partner"
   - [ ] Button shows "Save Changes"

3. **Update Fields**:
   - [ ] Change business name
   - [ ] Update personal info (name, contact, etc.)
   - [ ] Change logo (tap existing → select new)
   - [ ] Optionally set new password
   - [ ] Click Save Changes

4. **Verify Updates**:
   - [ ] Success message appears
   - [ ] Returns to profile page
   - [ ] Updated data displays correctly
   - [ ] New logo shows if uploaded
   - [ ] Business name updated in both tables

## Test 2: Logo Visibility for Members
1. **Upload Logo as Admin**:
   - [ ] Edit trusted partner
   - [ ] Upload business logo
   - [ ] Save changes

2. **Verify Member View**:
   - [ ] Login as member
   - [ ] Navigate to Browse Deals
   - [ ] Find partner with uploaded logo
   - [ ] Verify logo displays in partner card header
   - [ ] Logo loads without errors
   - [ ] Fallback icon shows if logo fails

## Test 3: Deal Image Visibility for Members
1. **Create Deal with Image**:
   - [ ] Admin or TP creates new deal
   - [ ] Upload deal image during creation
   - [ ] Save deal

2. **Verify Member View**:
   - [ ] Login as member
   - [ ] Navigate to Browse Deals
   - [ ] Expand partner with image deal
   - [ ] Verify deal image displays in card
   - [ ] Image loads correctly
   - [ ] Tap image to view full size

## Test 4: Password Reset (Edit Mode)
1. **Reset Password**:
   - [ ] Admin edits trusted partner
   - [ ] Enter new password (min 6 chars)
   - [ ] Confirm password matches
   - [ ] Save changes
   - [ ] Success message appears

2. **Verify New Password**:
   - [ ] Logout
   - [ ] Login as trusted partner
   - [ ] Use NEW password
   - [ ] Login succeeds

## Test 5: Optional Fields (Edit Mode)
1. **Partial Update**:
   - [ ] Edit trusted partner
   - [ ] Leave password fields blank
   - [ ] Update only business name
   - [ ] Save changes
   - [ ] Verify only business name updated
   - [ ] Password remains unchanged

## Expected Behaviors:
- Edit navigates to same page as Add (reused component)
- All fields optional except email & business name
- Logo replacement uploads new file, updates URL
- Password reset without requiring current password
- Profile page reloads after edit completes
- Member views already support image display (no changes needed)

## Known Issues to Monitor:
- Logo URL format must be public Supabase storage URL
- Deal images stored in `business-bills` bucket under `deal_images/` folder
- Image upload requires admin deal creation permission flag
- Discount service query includes `image_url` field (confirmed)

## Quick Debug Commands:
```sql
-- Check logo URL for partner
SELECT owner_member_id, name, logo_url 
FROM businesses 
WHERE owner_member_id = '{user_id}';

-- Check deal images
SELECT id, name, image_url 
FROM trusted_partner_discounts 
WHERE trusted_partner_id = '{user_id}' AND is_active = true;

-- Verify public bucket access
SELECT * FROM storage.buckets WHERE id IN ('partner-logos', 'business-bills');
```
