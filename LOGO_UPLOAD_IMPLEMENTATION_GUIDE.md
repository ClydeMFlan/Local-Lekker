# Trusted Partner Logo Upload - Implementation Guide

## Overview
Add logo upload functionality for trusted partners across signup, profile management, and display in deals.

## ✅ Completed Steps

### 1. Database Migration
Created `add_logo_url_to_businesses.sql`:
- Added `logo_url TEXT` column to `businesses` table
- Created `partner-logos` storage bucket with public access
- Added RLS policies for logo upload/update/delete/view

**To apply**: Run the SQL migration in Supabase SQL editor.

### 2. Signup Page (Partial)
Modified `lib/features/auth/trusted_partner_signup_page.dart`:
- ✅ Added imports: `dart:io`, `image_picker`
- ✅ Added state variables: `_selectedLogo`, `_picker`
- ✅ Added `_pickLogo()` method for image selection
- ✅ Added logo upload UI after business name field
- ✅ Modified BusinessProfilePage navigation to pass `initialLogoPath`

### 3. Business Profile Page (Partial)
Modified `lib/features/auth/business_profile_page.dart`:
- ✅ Added `initialLogoPath` parameter to constructor
- ✅ Added state variables: `_existingLogoUrl`, `_selectedLogoPath`, `_picker`
- ✅ Initialize `_selectedLogoPath` in initState

## ⏳ Remaining Implementation Tasks

### 4. Complete Business Profile Page Logo Handling

#### A. Add Logo Upload Method
Add after `_loadExistingData()` method:

```dart
Future<void> _pickLogo() async {
  try {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (image != null) {
      setState(() {
        _selectedLogoPath = image.path;
      });
    }
  } catch (e) {
    if (kDebugMode) {
      print('Error picking logo: $e');
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to pick image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

Future<String?> _uploadLogo(String userId) async {
  if (_selectedLogoPath == null) return _existingLogoUrl;

  try {
    final fileName = '$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';
    final bytes = await File(_selectedLogoPath!).readAsBytes();

    await SupabaseService.instance.client.storage
        .from('partner-logos')
        .uploadBinary(fileName, bytes);

    final logoUrl = SupabaseService.instance.client.storage
        .from('partner-logos')
        .getPublicUrl(fileName);

    return logoUrl;
  } catch (e) {
    if (kDebugMode) {
      print('Error uploading logo: $e');
    }
    rethrow;
  }
}
```

#### B. Add Logo UI Section
Find the form ListView in `build()` method and add after business name field:

```dart
const SizedBox(height: 16),
// Logo section
Container(
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(
    border: Border.all(color: Colors.grey.shade300),
    borderRadius: BorderRadius.circular(8),
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          const Icon(Icons.business, color: Colors.green),
          const SizedBox(width: 8),
          const Text(
            'Business Logo',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      const Text(
        'Upload your business logo to display with your deals',
        style: TextStyle(color: Colors.grey, fontSize: 12),
      ),
      const SizedBox(height: 12),
      if (_selectedLogoPath != null || _existingLogoUrl != null)
        Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _selectedLogoPath != null
                  ? Image.file(
                      File(_selectedLogoPath!),
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                    )
                  : Image.network(
                      _existingLogoUrl!,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          Container(
                        width: 80,
                        height: 80,
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.business, size: 40),
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Logo uploaded',
                      style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: _pickLogo,
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text('Change'),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: () => setState(() {
                          _selectedLogoPath = null;
                          _existingLogoUrl = null;
                        }),
                        icon: const Icon(Icons.delete, size: 16),
                        label: const Text('Remove'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        )
      else
        OutlinedButton.icon(
          onPressed: _pickLogo,
          icon: const Icon(Icons.add_photo_alternate),
          label: const Text('Upload Logo'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
          ),
        ),
    ],
  ),
),
```

#### C. Update Save Method
In the `_saveBusinessProfile()` method, add logo upload before creating/updating business:

```dart
// Upload logo if selected
String? logoUrl;
try {
  logoUrl = await _uploadLogo(user.id);
} catch (e) {
  if (kDebugMode) {
    print('Logo upload failed: $e');
  }
  // Continue even if logo upload fails
}

// Then in the business data map, add:
'logo_url': logoUrl,
```

#### D. Load Existing Logo
In `_loadExistingData()`, add to the business response section:

```dart
if (businessResponse != null) {
  _nameController.text = businessResponse['name'] ?? '';
  _addressController.text = businessResponse['address'] ?? '';
  _selectedCategory = businessResponse['category'];
  _contactEmailController.text = businessResponse['contact_email'] ?? '';
  _contactNumberController.text = businessResponse['contact_number'] ?? '';
  _existingLogoUrl = businessResponse['logo_url']; // Add this line
}
```

### 5. Display Logo on Trusted Partner Home Page

In `lib/features/auth/trusted_partner_home_page.dart`:

#### A. Add Logo State Variable
```dart
String? _businessLogoUrl;
```

#### B. Load Logo in _loadBusinessName()
```dart
Future<void> _loadBusinessName() async {
  try {
    final user = SupabaseService.instance.getCurrentUser();
    if (user == null) return;

    final business = await SupabaseService.instance.client
        .from('businesses')
        .select('name, logo_url')
        .eq('owner_member_id', user.id)
        .maybeSingle();

    if (business != null && mounted) {
      setState(() {
        _businessName = business['name'];
        _businessLogoUrl = business['logo_url'];
      });
    }
  } catch (e) {
    if (kDebugMode) {
      print('Error loading business name: $e');
    }
  }
}
```

#### C. Display Logo in Header
Find the header section (around line 400-500) and modify to include logo:

```dart
Row(
  children: [
    // Logo avatar
    if (_businessLogoUrl != null)
      CircleAvatar(
        radius: 24,
        backgroundImage: NetworkImage(_businessLogoUrl!),
        backgroundColor: Colors.grey.shade200,
        onBackgroundImageError: (_, __) {},
        child: _businessLogoUrl == null
            ? const Icon(Icons.business, size: 20)
            : null,
      )
    else
      CircleAvatar(
        radius: 24,
        backgroundColor: Colors.grey.shade200,
        child: const Icon(Icons.business, size: 20),
      ),
    const SizedBox(width: 12),
    // Existing welcome text
    Text(
      _businessName != null
          ? 'Welcome, $_businessName!'
          : 'Welcome, Partner!',
      style: const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
      ),
    ),
  ],
),
```

### 6. Display Logo in Member Deals View

#### A. Update Discount Service
In `lib/services/discount_service.dart`, modify `getAllActiveDiscountsWithTrustedPartners()`:

Change the businesses select to include logo_url:
```dart
final trustedPartner = await _supabase
    .from('businesses')
    .select('id, owner_member_id, name, logo_url')  // Add logo_url here
    .eq('owner_member_id', trustedPartnerId)
    .maybeSingle();
```

And in the return map:
```dart
'trusted_partners': {
  'business_name': trustedPartnerId != null
      ? (trustedPartnerNameMap[trustedPartnerId] ?? 'Unknown Trusted Partner')
      : 'Unknown Trusted Partner',
  'business_id': trustedPartnerId != null
      ? trustedPartnerIdMap[trustedPartnerId]
      : null,
  'logo_url': trustedPartner?['logo_url'],  // Add this
},
```

#### B. Update Manage Deals Display
In `lib/features/auth/discount_management_page.dart`, in the Manage Deals list (around line 262-360):

Modify the Row to show logo:
```dart
Row(
  children: [
    // Logo thumbnail
    if (discount.logoUrl != null)
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.network(
          discount.logoUrl!,
          width: 60,
          height: 60,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              Container(
            width: 60,
            height: 60,
            color: Colors.grey.shade200,
            child: const Icon(Icons.business, size: 24),
          ),
        ),
      )
    else
      Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Icon(Icons.business, size: 24),
      ),
    const SizedBox(width: 12),
    // Existing deal info in Expanded widget
    Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Existing deal name, discount, etc.
        ],
      ),
    ),
  ],
),
```

#### C. Update Your Discounts Display  
In `lib/features/auth/trusted_partner_home_page.dart`, in "Your Discounts" section (lines 687-718):

Similar modification to show logo thumbnail next to deal name.

### 7. Admin Add Trusted Partner (If Exists)

Search for any admin page that creates trusted partners and add logo upload there following the same pattern as signup page.

## Testing Checklist

- [ ] Run SQL migration in Supabase
- [ ] Test signup with logo upload
- [ ] Test signup without logo (optional)
- [ ] Test logo display on TP home page
- [ ] Test editing business profile and changing logo
- [ ] Test logo display in member deals view ("Your Discounts")
- [ ] Test logo display in "Manage Deals"
- [ ] Test logo display next to TP name in member app
- [ ] Verify RLS policies work (TPs can only upload their own logos)
- [ ] Test with missing/broken logo URLs (error handling)

## Database Schema Reference

```sql
-- businesses table
ALTER TABLE businesses ADD COLUMN logo_url TEXT;

-- Storage bucket
INSERT INTO storage.buckets (id, name, public)
VALUES ('partner-logos', 'partner-logos', true);

-- Logo stored as: {user_id}/{timestamp}.jpg
-- Public URL: https://{project}.supabase.co/storage/v1/object/public/partner-logos/{user_id}/{timestamp}.jpg
```

## Notes

- Logo images are resized to max 512x512 at 85% quality during selection
- Storage path: `partner-logos/{userId}/{timestamp}.jpg`
- Logos are publicly accessible (no auth required to view)
- TPs can only upload/modify their own logos (enforced by RLS)
- Logo is optional throughout the flow
- Error handling in place for broken/missing images
