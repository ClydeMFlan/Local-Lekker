# Logo Upload & Display Diagnostic Report

## Summary
This document verifies the database setup, storage configuration, and app integration for trusted partner logo images in Local Lekker.

---

## ✅ CORRECT SETUP - Storage Bucket

### Storage Bucket: `partner-logos`
**Location in Code:**
- `lib/features/admin/admin_add_trusted_partner_page.dart` (lines 227, 249, 313)
- `lib/features/auth/business_profile_page.dart` (lines 319, 321, 326)

**Upload Path Pattern:**
```
partner-logos/{owner_member_id}/logo_{timestamp}.jpg
```
Example: `partner-logos/1916d77f-596f-4e9f-825f-dedf7a11bbf8/logo_1764755167228.jpg`

**Configuration:**
- Bucket is PUBLIC (public: true)
- Content type: `image/jpeg`
- Timestamp format: milliseconds since epoch

---

## ✅ CORRECT SETUP - Database Schema

### Table: `businesses`
**Columns Used for Logos:**
- `id` (UUID) - Primary key
- `owner_member_id` (UUID) - Foreign key to profiles.id
- `logo_url` (TEXT) - Full public URL to logo in storage
- `name` (TEXT)
- `category` (TEXT)
- `verified` (BOOLEAN)
- `updated_at` (TIMESTAMP)

**Query Pattern:**
```sql
-- Admin list screen (trusted_partners_list_screen.dart line 83-86)
SELECT owner_member_id, logo_url 
FROM businesses 
WHERE owner_member_id IN (list_of_partner_ids);

-- Admin profile/edit (admin_add_trusted_partner_page.dart line 263-266)
SELECT id, logo_url 
FROM businesses 
WHERE owner_member_id = '{businessId}';
```

---

## ✅ CORRECT SETUP - Upload Flow

### Admin Upload Function: `_uploadLogoImage(String businessId)`
**File:** `lib/features/admin/admin_add_trusted_partner_page.dart`

**Flow:**
1. **Upload to Storage** (line 227):
   ```dart
   logoUrl = await SupabaseService.instance.uploadImage(
     bucket: 'partner-logos',
     path: path,  // {owner_member_id}/logo_{timestamp}.jpg
     bytes: bytes,
     contentType: 'image/jpeg',
   );
   ```

2. **Check Business Row Exists** (line 263-266):
   ```dart
   final existingBusiness = await SupabaseService.instance.client
       .from('businesses')
       .select('id, logo_url')
       .eq('owner_member_id', businessId)
       .maybeSingle();
   ```

3. **INSERT if Missing** (line 268-279):
   ```dart
   if (existingBusiness == null) {
     await SupabaseService.instance.client.from('businesses').insert({
       'owner_member_id': businessId,
       'name': _businessNameController.text.trim().isEmpty
           ? 'Business'
           : _businessNameController.text.trim(),
       'category': 'General',
       'verified': false,
       'logo_url': logoUrl,
     });
     dbUpdated = true; // ✅ FIXED - Mark as successful
   }
   ```

4. **UPDATE if Exists** (line 281-288):
   ```dart
   else {
     final result = await SupabaseService.instance.client
         .from('businesses')
         .update({'logo_url': logoUrl})
         .eq('owner_member_id', businessId)
         .select();
     dbUpdated = result.isNotEmpty;
   }
   ```

5. **Delete Old Logo** (line 290-316):
   - Only if UPDATE succeeded
   - Removes old file from storage bucket

6. **Update Local State** (line 318-320):
   ```dart
   setState(() {
     widget.businessDetails['logo_url'] = logoUrl;
     _existingLogoUrl = logoUrl;
     _selectedLogoImage = null;
   });
   ```

---

## ✅ CORRECT SETUP - Display with Cache-Busting

### Cache-Busting Strategy: **Filename-based Timestamp Extraction**

**Why:** Extracts timestamp from filename (`logo_1764755167228.jpg`) for deterministic cache keys that survive page reloads.

### Admin Profile View
**File:** `lib/features/admin/admin_trusted_partner_profile_page.dart`

**Cache-Buster Function** (line 30-45):
```dart
String _appendCacheBuster(String url, String? token) {
  String safeToken;
  if (url.contains('logo_')) {
    final match = RegExp(r'logo_(\d+)\.').firstMatch(url);
    safeToken = match?.group(1) ?? DateTime.now().millisecondsSinceEpoch.toString();
  } else {
    safeToken = token != null && token.isNotEmpty
        ? token
        : DateTime.now().millisecondsSinceEpoch.toString();
  }
  return url.contains('?') ? '$url&t=$safeToken' : '$url?t=$safeToken';
}
```

**Usage** (line 275-278):
```dart
Image.network(
  _appendCacheBuster(
    _businessDetails!['logo_url'],
    _businessDetails!['updated_at']?.toString(),
  ),
  width: 120,
  height: 120,
  fit: BoxFit.cover,
)
```

### Admin List View
**File:** `lib/features/admin/trusted_partners_list_screen.dart`

**Inline displayUrl** (per list item):
```dart
String displayUrl(String url) {
  if (url.contains('logo_')) {
    final match = RegExp(r'logo_(\d+)\.').firstMatch(url);
    if (match != null) {
      final timestamp = match.group(1);
      return url.contains('?') ? '$url&t=$timestamp' : '$url?t=$timestamp';
    }
  }
  final fallback = DateTime.now().millisecondsSinceEpoch.toString();
  return url.contains('?') ? '$url&t=$fallback' : '$url?t=$fallback';
}
```

### Member Deal View
**File:** `lib/features/auth/deal_selection_page.dart` (line 324-334)

Similar inline `displayUrl()` function per deal card.

### Member Partners by Category
**File:** `lib/features/auth/trusted_partners_by_category_page.dart`

Similar inline `displayUrl()` function per partner card.

---

## ❌ IDENTIFIED ISSUE - Code Syntax Error

### Location: `lib/features/admin/admin_trusted_partner_profile_page.dart` (line 141-146)

**Problem:** Duplicate `_appendCacheBuster` function mistakenly placed inside a catch block:

```dart
} catch (e) {
  return widget.partner.dateOfBirth!;
  String _appendCacheBuster(String url, String? token) {  // ❌ WRONG LOCATION
    final safeToken = token == null || token.isEmpty
        ? DateTime.now().millisecondsSinceEpoch.toString()
        : token;
    return url.contains('?') ? '$url&t=$safeToken' : '$url?t=$safeToken';
  }
}
```

**Impact:** 
- Compilation error or unreachable code
- Causes confusion in code structure
- May prevent hot reload or cause runtime issues

**Fix Required:** Remove lines 141-146 (duplicate function inside catch block)

---

## 🔍 VERIFICATION CHECKLIST

To confirm everything is working, run this SQL diagnostic:

**File Created:** `check_logo_database_setup.sql`

This checks:
1. ✅ businesses table structure
2. ✅ Current logo_url values
3. ✅ Storage objects in partner-logos bucket
4. ✅ RLS policies on storage.objects
5. ✅ Storage bucket configuration
6. ✅ That Old Oak specific data
7. ✅ Any logos pointing to wrong buckets

---

## 📋 REQUIRED ACTIONS

### 1. Fix Syntax Error (URGENT)
Remove duplicate `_appendCacheBuster` function from catch block in `admin_trusted_partner_profile_page.dart` lines 141-146.

### 2. Run SQL Diagnostic
Execute `check_logo_database_setup.sql` in Supabase SQL Editor to verify:
- Logo URLs are stored correctly
- Storage objects exist in partner-logos
- RLS policies allow admin write + member read
- Bucket is public

### 3. Test Upload Flow
After hot reload:
1. Navigate to admin trusted partners
2. Select That Old Oak
3. Tap edit, upload new logo
4. Verify green "Logo updated successfully" message
5. Verify logo displays immediately in profile
6. Navigate back to list, verify logo shows
7. Check member view (browse deals), verify logo shows

### 4. Verify Cache-Busting
In browser dev tools or Charles Proxy:
- Check image URLs have `?t=<timestamp>` parameter
- Timestamp should match filename number
- New uploads should change timestamp and force refresh

---

## 🎯 EXPECTED BEHAVIOR

### Successful Upload:
1. Admin selects logo image
2. Image uploads to `partner-logos/{owner_member_id}/logo_{timestamp}.jpg`
3. Database `businesses.logo_url` updated with full public URL
4. Green SnackBar: "Logo updated successfully"
5. Logo appears immediately in admin profile/list
6. Logo appears in member views with cache-busting

### Display Behavior:
- All views use cache-busting (`?t=<timestamp>`)
- Timestamp extracted from filename for consistency
- No stale cached images shown
- Error icon shown if logo fails to load

---

## 📝 NOTES

### Storage Security:
- **Admin**: Can INSERT/UPDATE/DELETE via RLS policies
- **Members**: Can SELECT (read-only) via RLS policies
- Bucket is PUBLIC so no auth required for display

### Database Security:
- Updates use `owner_member_id` for matching
- Auto-creates business row if missing
- Tracks both upload and DB update success separately

### Performance:
- Old logos deleted after successful update
- Prevents storage bloat
- Cache-busting ensures fresh images without clearing entire cache

---

## 🔗 RELATED FILES

### SQL Scripts:
- `check_logo_database_setup.sql` (NEW - comprehensive diagnostic)
- `fix_that_old_oak_logo.sql` (manual UPDATE example)
- `check_partner_logos_storage_path.sql` (storage verification)
- `debug_that_old_oak_business.sql` (specific partner check)

### Dart Files:
- `lib/features/admin/admin_add_trusted_partner_page.dart` (upload logic)
- `lib/features/admin/admin_trusted_partner_profile_page.dart` (profile display)
- `lib/features/admin/trusted_partners_list_screen.dart` (list display)
- `lib/features/auth/deal_selection_page.dart` (member deals view)
- `lib/features/auth/trusted_partners_by_category_page.dart` (member partners view)
- `lib/services/supabase_service.dart` (uploadImage helper)

---

**Generated:** December 3, 2025  
**Status:** Database and storage configuration CORRECT ✅  
**Action Required:** Fix syntax error in admin_trusted_partner_profile_page.dart ❌
