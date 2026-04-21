# Remove Image Picker - Quick Fix

The app is using `image_picker` which adds CAMERA permission.

## Files affected:
1. lib/features/auth/trusted_partner_signup_page.dart
2. lib/features/auth/business_profile_page.dart
3. lib/features/auth/discount_management_page.dart
4. lib/features/admin/admin_add_trusted_partner_page.dart

## Quick Fix Options:

### Option 1: Disable logo upload temporarily
Comment out logo upload buttons in these files

### Option 2: Use file_picker instead (no camera permission)
Replace `image_picker` with `file_picker` which only accesses gallery, not camera

### Option 3: Remove logo upload entirely
Remove logo upload features completely

## Recommended: Option 2 - Use file_picker

Add to pubspec.yaml:
```yaml
  file_picker: ^8.0.0  # No camera permission
```

Replace in code:
```dart
// OLD
import 'package:image_picker/image_picker.dart';
final picker = ImagePicker();
final image = await picker.pickImage(source: ImageSource.gallery);

// NEW
import 'package:file_picker/file_picker.dart';
final result = await FilePicker.platform.pickFiles(type: FileType.image);
if (result != null) {
  final image = result.files.first;
}
```

## Immediate Fix (to unblock Play Store upload):

I'll add file_picker and update the code now...
