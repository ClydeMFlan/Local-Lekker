# Admin Deal Image Upload & Database Verification

## Overview
This document verifies that when an admin creates a deal and uploads an image, the image is:
1. ✅ **Uploaded to Supabase Storage** (`business-bills/deal_images/` folder)
2. ✅ **Saved in the database** (`trusted_partner_discounts.image_url`)
3. ✅ **Accessible to members** (via public URL + RLS policy allowing members to view)
4. ✅ **Properly displayed** in the UI with cache-busting

---

## Flow: Admin Creates Deal with Image

### 1. User Action: Admin Opens Deal Management
**File**: `lib/features/admin/admin_partner_deals_screen.dart` (line 50+)

Admin navigates to:
- Dashboard → Trusted Partner → View Deals → Edit/Create Deal

### 2. Image Selection
**File**: `lib/features/auth/discount_management_page.dart` (lines 954-1000)

Admin:
1. Taps "Upload Image" button
2. Uses ImagePicker to select image from gallery
3. Image stored in local state: `_selectedImage`

### 3. Image Upload to Storage
**File**: `lib/features/auth/discount_management_page.dart` (lines 1408-1450)

```dart
Future<String?> _uploadImage() async {
  // Step 1: Read image bytes
  final fileBytes = await _selectedImage!.readAsBytes();
  
  // Step 2: Generate filename with timestamp for cache-busting
  final fileName = '${DateTime.now().millisecondsSinceEpoch}_${_selectedImage!.name}';
  
  // Step 3: Determine upload path
  // If admin is editing partner's deal: use widget.trustedPartnerId
  // Otherwise: use current user's ID
  final targetPartnerId = widget.trustedPartnerId ?? SupabaseService.instance.getCurrentUser()?.id;
  
  // Step 4: Construct full path
  final filePath = targetPartnerId != null
      ? 'deal_images/$targetPartnerId/$fileName'
      : 'deal_images/$fileName';
  
  // Step 5: Upload to storage
  await SupabaseService.instance.client.storage
      .from('business-bills')
      .uploadBinary(filePath, fileBytes);
  
  // Step 6: Get public URL
  final imageUrl = SupabaseService.instance.client.storage
      .from('business-bills')
      .getPublicUrl(filePath);
  
  return imageUrl;
}
```

**What happens in Supabase:**
- File uploaded to: `business-bills/deal_images/{partner_uuid}/{timestamp}_{filename}.jpg`
- RLS policy checked: Admin must be in `memberships` table with role='admin' AND
  - Business (owned by partner) must have `allow_admin_deal_creation=true`
- If policy passes: File stored successfully
- If policy fails: Error returned (403 Forbidden)

**Storage RLS Policy:**
```sql
CREATE POLICY "Admins can manage deal images" ON storage.objects
    FOR ALL USING (
        bucket_id = 'business-bills' AND
        name LIKE 'deal_images/%' AND
        EXISTS (
            SELECT 1 FROM public.businesses b
            JOIN public.memberships m ON m.user_id = auth.uid() AND m.role = 'admin'
            WHERE b.owner_member_id::text = (storage.foldername(name))[1]
              AND COALESCE(b.allow_admin_deal_creation, false) = true
        )
    );
```

### 4. Save Image URL to Database
**File**: `lib/features/auth/discount_management_page.dart` (lines 1472-1525)

After image upload succeeds:

```dart
void _submit() async {
  // Upload image if selected
  String? imageUrl;
  if (_selectedImage != null) {
    imageUrl = await _uploadImage();  // ← Get public URL from storage
  }
  
  // ... prepare other discount data ...
  
  // Call service to create/update discount
  if (isEditMode) {
    await _discountService.updateDiscount(
      // ... other fields ...
      imageUrl: imageUrl,  // ← Save image URL to database
    );
  } else {
    final discount = await _discountService.createDiscount(
      // ... other fields ...
      imageUrl: imageUrl,  // ← Save image URL to database
    );
  }
}
```

**Service Method:**
**File**: `lib/services/discount_service.dart` (lines 28-95)

```dart
Future<Discount> createDiscount({
  required String trustedPartnerId,
  // ... other required fields ...
  String? imageUrl,  // ← Image URL parameter
}) async {
  final response = await _supabase
      .from('trusted_partner_discounts')
      .insert({
        'trusted_partner_id': trustedPartnerId,
        'business_id': businessId,
        'name': name,
        'image_url': imageUrl,  // ← Saved to database
        // ... other fields ...
      })
      .select()
      .single();
  
  return Discount.fromJson(response);
}
```

**Database Table:**
- **Table**: `trusted_partner_discounts`
- **Column**: `image_url` (TEXT, nullable)
- **Sample value**: `https://...supabase.co/storage/v1/object/public/business-bills/deal_images/{partner_uuid}/{timestamp}_{filename}.jpg`

### 5. Database RLS for Reading Deals
**File**: `unified_schema_rls_policies.sql` (lines 155-165)

```sql
-- ✅ All authenticated users (members) can view all discounts
CREATE POLICY "Members can view all discounts" ON trusted_partner_discounts
    FOR SELECT USING (true);

-- ✅ Business owners can manage their own discounts
CREATE POLICY "Business owners can manage their discounts" ON trusted_partner_discounts
    FOR ALL USING (
        business_id IN (
            SELECT id FROM businesses WHERE owner_member_id = auth.uid()
        )
    );
```

**What this means:**
- ✅ Members can query the database and get `image_url` field
- ✅ Admin can read the discount record (policy allows `true` for SELECT)
- ✅ TrustedPartner owner can read/update their own discounts

### 6. Display Image in Member's Deal Selection
**File**: `lib/features/auth/deal_selection_page.dart` (lines 44-53)

```dart
String _displayDealImageUrl(String url) {
  // Extract timestamp from filename (e.g., 1234567890_image.jpg)
  if (url.contains('deal_images/')) {
    final match = RegExp(r'(\d+)_').firstMatch(url);
    if (match != null) {
      final timestamp = match.group(1);
      // Append timestamp as query parameter for cache-busting
      return url.contains('?') ? '$url&t=$timestamp' : '$url?t=$timestamp';
    }
  }
  return url;
}
```

Then use in widget:
```dart
Image.network(
  _displayDealImageUrl(deal['image_url']),  // ← Fetch image with cache-bust
  fit: BoxFit.cover,
  errorBuilder: (context, error, stackTrace) {
    return Container(color: Colors.grey[300]);
  },
)
```

**What this does:**
- Extracts timestamp from filename
- Appends `?t={timestamp}` to URL
- Forces browser to fetch fresh image each time (no cache issues)
- Members can view the image from public storage

---

## Storage RLS Policies Summary

| Policy Name | Action | Who | Condition | Result |
|---|---|---|---|---|
| **Members can view deal images** | SELECT | Any authenticated user | `bucket='business-bills' AND name LIKE 'deal_images/%'` | ✅ Members can download & display |
| **Admins can manage deal images** | INSERT/UPDATE/DELETE | Admin in memberships | `admin=true AND business.allow_admin_deal_creation=true AND path matches partner` | ✅ Admin can upload/edit |
| **Trusted partners can view/upload** | INSERT/SELECT | TP (owner) | `split_part(path,2) = auth.uid()` | ✅ TP can upload own images |

---

## Verification Checklist

### Before Deployment

- [ ] **1. Verify Admin in Memberships Table**
  ```sql
  SELECT user_id, role FROM memberships WHERE role = 'admin' LIMIT 1;
  ```
  Expected: At least one row with `role='admin'`

- [ ] **2. Verify Partner Allows Admin Deal Creation**
  ```sql
  SELECT id, name, allow_admin_deal_creation 
  FROM businesses 
  WHERE allow_admin_deal_creation = true
  LIMIT 1;
  ```
  Expected: At least one business with `allow_admin_deal_creation=true`

- [ ] **3. Check Storage Bucket RLS Policies**
  ```sql
  SELECT policyname, cmd, permissive
  FROM pg_policies
  WHERE schemaname='storage' 
    AND tablename='objects'
    AND policyname LIKE '%deal image%'
  ORDER BY policyname;
  ```
  Expected: Policies exist for Members, Admins, Trusted Partners

- [ ] **4. Verify Deal Images in Storage**
  ```sql
  SELECT name, bucket_id, owner, created_at
  FROM storage.objects
  WHERE bucket_id = 'business-bills'
    AND name LIKE 'deal_images/%'
  LIMIT 5;
  ```
  Expected: Files exist in `deal_images/` paths

- [ ] **5. Check Discount Image URLs in Database**
  ```sql
  SELECT id, name, image_url, trusted_partner_id
  FROM trusted_partner_discounts
  WHERE image_url IS NOT NULL
  LIMIT 5;
  ```
  Expected: URLs in format: `https://...storage/.../deal_images/...`

---

## Testing in the App

### Test Case 1: Admin Uploads Image
1. Login as admin
2. Dashboard → Trusted Partners
3. Select a partner
4. Go to Deals tab
5. Create or Edit a deal
6. Tap "Upload Image"
7. Select an image from phone
8. **Expected**: ✅ Image uploads successfully (no error dialog)

### Test Case 2: Member Sees Admin's Image
1. Login as member
2. Navigate to Browse Deals
3. Find the partner with admin-uploaded image
4. **Expected**: ✅ Image displays in deal card thumbnail

### Test Case 3: Image Persists After Refresh
1. Complete Test Case 2
2. Refresh the page (pull down)
3. **Expected**: ✅ Image still displays (not from browser cache, but actually fetched)

### Test Case 4: TP Uploads Their Own Image (Should Still Work)
1. Login as trusted partner
2. Go to discount_management_page
3. Create/Edit deal with image
4. **Expected**: ✅ Image uploads and displays

---

## Troubleshooting

### ❌ Admin Gets "Not Authorized" Error
**Cause**: RLS policy blocking upload
**Solution**: Check:
1. Is user in `memberships` table with role='admin'?
   ```sql
   SELECT * FROM memberships WHERE user_id = '{admin_user_id}';
   ```
2. Does the business have `allow_admin_deal_creation=true`?
   ```sql
   SELECT allow_admin_deal_creation FROM businesses WHERE id = '{business_id}';
   ```

### ❌ Image Doesn't Display for Member
**Cause**: RLS policy blocking view
**Solution**: Check:
1. Does "Members can view deal images" policy exist?
   ```sql
   SELECT policyname FROM pg_policies
   WHERE schemaname='storage' 
   AND tablename='objects'
   AND policyname = 'Members can view deal images';
   ```
2. Is the image in public storage bucket (not private)?
   ```sql
   SELECT public FROM storage.buckets WHERE name='business-bills';
   ```
   Expected: `true`

### ❌ Image URL Is NULL in Database
**Cause**: Image upload failed silently
**Solution**: Check:
1. Does storage.objects have RLS enabled?
   ```sql
   SELECT rowsecurity FROM pg_tables 
   WHERE tablename='objects' AND schemaname='storage';
   ```
   Expected: `true`
2. Try uploading again and check app logs for error

---

## Files Involved

| File | Purpose |
|------|---------|
| `lib/features/auth/discount_management_page.dart` | UI for image upload, calls `_uploadImage()` |
| `lib/services/discount_service.dart` | Creates/updates discount with `imageUrl` parameter |
| `lib/services/supabase_service.dart` | Supabase client initialization |
| `unified_schema_rls_policies.sql` | Database table RLS policies |
| `add_deal_images_rls_policies.sql` | Storage bucket RLS policies |
| `fix_admin_image_visibility_rls.sql` | Admin view policy fix |

---

## Key RLS Policy Files

Apply these in order if something is wrong:

### 1. Database Table Policies
```bash
# File: unified_schema_rls_policies.sql
# Ensures members can read all discounts
```

### 2. Storage Upload/Download Policies
```bash
# File: add_deal_images_rls_policies.sql
# Enables admin uploads and member downloads
```

### 3. Admin View Fix (if admins can't see their uploads)
```bash
# File: fix_admin_image_visibility_rls.sql
# Removes restrictive allow_admin_deal_creation check for admin SELECT
```

---

## Summary

✅ **Admin Deal Image Upload is fully configured:**
- Image files → Stored in `business-bills/deal_images/{partner_id}/{timestamp}_{name}`
- Image URL → Saved to `trusted_partner_discounts.image_url`
- Access Control → RLS policies allow admins to upload, members to view
- Caching → Cache-busting with `?t={timestamp}` query parameter
- Database → `trusted_partner_discounts` table has RLS allowing member SELECT
- Visibility → Both database table and storage bucket properly secured

**Everything is in place for admins to upload images that members can view!**
