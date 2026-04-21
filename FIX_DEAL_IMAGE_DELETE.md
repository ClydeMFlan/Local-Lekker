# Fix Deal Image Delete and Toggle Issues

## Problems Identified

1. **Image disappears when toggling active/inactive** - The `_toggleDiscountActive` method recreates the Discount object but doesn't preserve the `imageUrl` field
2. **Delete button doesn't work in Edit dialog** - The `_removeImage()` method only clears the newly selected image but doesn't handle deleting existing images from the database

## Solution Overview

Three files need changes:
1. `lib/features/auth/discount_management_page.dart` - Main fix location
2. Both `AddDiscountDialog` and `EditDiscountDialog` classes need updating

---

## FIX 1: Toggle Active/Inactive Losing Image ✅ ALREADY APPLIED

**Location**: `_toggleDiscountActive` method (around line 160)

**Change**: Add missing fields when recreating Discount object

```dart
// ALREADY FIXED - Image URL and other fields now preserved
_discounts[index] = Discount(
  id: discount.id,
  trustedPartnerId: discount.trustedPartnerId,
  name: discount.name,
  description: discount.description,
  itemName: discount.itemName,
  itemPrice: discount.itemPrice,
  percentage: discount.percentage,
  fixedAmount: discount.fixedAmount,
  isActive: !discount.isActive,
  createdAt: discount.createdAt,
  updatedAt: DateTime.now(),
  imageUrl: discount.imageUrl, // ✅ ADDED
  isWeightBased: discount.isWeightBased, // ✅ ADDED
  isBillDiscount: discount.isBillDiscount, // ✅ ADDED
  billDiscountData: discount.billDiscountData, // ✅ ADDED
);
```

---

## FIX 2: Edit Dialog - Add State Variables ✅ ALREADY APPLIED

**Location**: `_EditDiscountDialogState` class (around line 1346)

**Change**: Add state variables to track existing images

```dart
// ALREADY ADDED
String? _existingImageUrl; // Track existing image from database
bool _shouldDeleteExistingImage = false; // Flag to delete existing image

@override
void initState() {
  super.initState();
  _existingImageUrl = widget.discount.imageUrl; // ✅ ADDED
  // ... rest of init
}
```

---

## FIX 3: Update _removeImage Method in EditDiscountDialog

**Location**: `_EditDiscountDialogState._removeImage()` (around line 2053)

**Current Code:**
```dart
void _removeImage() {
  setState(() {
    _selectedImage = null;
  });
}
```

**Replace With:**
```dart
void _removeImage() {
  setState(() {
    if (_selectedImage != null) {
      // Remove newly selected image
      _selectedImage = null;
    } else if (_existingImageUrl != null) {
      // Mark existing image for deletion
      _shouldDeleteExistingImage = true;
      _existingImageUrl = null; // Clear from UI
    }
  });
}
```

---

## FIX 4: Update _submit Method in EditDiscountDialog

**Location**: `_EditDiscountDialogState._submit()` (around line 2059)

**Current Code:**
```dart
Future<void> _submit() async {
  if (_formKey.currentState!.validate()) {
    // Upload image if selected
    String? imageUrl;
    if (_selectedImage != null) {
      imageUrl = await _uploadImage();
    }
    // ... rest of submit
  }
}
```

**Replace With:**
```dart
Future<void> _submit() async {
  if (_formKey.currentState!.validate()) {
    // Handle image: upload new, keep existing, or delete
    String? imageUrl = widget.discount.imageUrl; // Default to existing
    
    if (_selectedImage != null) {
      // Upload new image
      imageUrl = await _uploadImage();
    } else if (_shouldDeleteExistingImage) {
      // Mark for deletion by setting to null
      imageUrl = null;
    }
    // ... rest of submit (keeps imageUrl as-is if no changes)
  }
}
```

---

## FIX 5: Update UI to Use State Variables

**Location**: EditDiscountDialog image section (around line 1757)

**Current Code:**
```dart
] else if (widget.discount.imageUrl != null &&
    widget.discount.imageUrl!.isNotEmpty) ...[
  // Show existing image from database
  Image.network(widget.discount.imageUrl!, ...)
```

**Replace With:**
```dart
] else if (_existingImageUrl != null &&
    _existingImageUrl!.isNotEmpty) ...[
  // Show existing image from database  
  Image.network(_existingImageUrl!, ...)
```

**Explanation**: Use `_existingImageUrl` state variable instead of `widget.discount.imageUrl` so when user clicks delete, `_existingImageUrl` becomes null and the image disappears from UI immediately.

---

## Testing Checklist

After applying all fixes, test:

1. ✅ Create deal with image → Toggle inactive → Toggle active → **Image should remain visible**
2. ✅ Edit deal with existing image → Click delete button → **Image should disappear from preview**
3. ✅ Edit deal → Delete existing image → Click save → Reopen edit → **No image should show, upload button visible**
4. ✅ Edit deal → Delete existing image → Upload new image → Save → **New image should be saved**
5. ✅ Edit deal with image → Don't change anything → Save → **Existing image should remain**

---

## Manual Fix Steps (Apply in Order)

Since the file has duplicated code between AddDiscountDialog and EditDiscountDialog, and automated replacement is failing:

1. **Open** `lib/features/auth/discount_management_page.dart`

2. **Find line 2053** (`void _removeImage()` in EditDiscountDialog - after line 1990 "Update Deal")

3. **Replace the method** with the new version from FIX 3 above

4. **Find line 2059** (`Future<void> _submit()` in EditDiscountDialog)

5. **Update the first few lines** of _submit to match FIX 4 above

6. **Find line 1757** (in EditDiscountDialog's build method, image preview section)

7. **Change** `widget.discount.imageUrl` to `_existingImageUrl` in the `else if` condition and `Image.network()` call

8. **Save file** and run `flutter run`

---

## Why This Works

- **State variables** (`_existingImageUrl`, `_shouldDeleteExistingImage`) track image state separately from widget props
- **Delete logic** sets null flag instead of just clearing new selection
- **Submit logic** checks all 3 scenarios: new image, delete existing, or keep existing
- **UI reactivity** updates immediately when state changes (delete button → image disappears)
- **Database update** happens via `imageUrl: null` in the result map, which the update service handles

The key insight: widget.discount.imageUrl is immutable, so we need mutable state variables to track changes before saving.
