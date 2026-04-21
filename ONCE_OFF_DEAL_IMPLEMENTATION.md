# Once-Off Deal Type Implementation Summary

## Overview
Added support for "Once-Off Deals" - a new deal type that members can only purchase/redeem once. After a member successfully completes a once-off deal, it automatically disappears from their available deals list.

## Changes Made

### 1. Database Schema Changes
**File**: `add_once_off_deal_flag.sql`
- Added `is_once_off` boolean column to `trusted_partner_discounts` table (default: FALSE)
- Created index on `is_once_off` for performance

### 2. Data Model Updates
**File**: `lib/models/discount.dart`
- Added `isOnceOff` boolean field to `Discount` class
- Updated factory constructor to parse `is_once_off` from JSON
- Updated `toJson()` method to include `is_once_off`

### 3. Service Layer Updates

#### DiscountService (`lib/services/discount_service.dart`)
- **createDiscount()**: Added `isOnceOff` parameter
- **updateDiscount()**: Added `isOnceOff` parameter for editing deals
- **New Method - getCompletedDealIdsForMember()**: Fetches all completed (purchased) deals for a specific member
  - Query: Looks for deal_authorizations with status='completed' for the member
  - Returns: Set of discount_id values

#### DealAuthorizationService (`lib/services/deal_authorization_service.dart`)
- **requestDealAuthorization()**: Added validation for once-off deals
  - Checks if member has already completed this deal
  - Throws error if member tries to redeem the same once-off deal twice
  - Only validates once-off deals (selected on discount creation)

### 4. UI/UX Changes

#### DiscountManagementPage (`lib/features/auth/discount_management_page.dart`)
- **DiscountType Enum**: Added `onceOff` value (positioned between `fixedAmount` and `weight`)
  ```dart
  enum DiscountType { none, percentage, fixedAmount, onceOff, weight, billDiscount }
  ```
- **Dropdown Options**: Added "Once-Off Deal" option in deal type selector
- **Pricing Logic**: Once-off deals use fixed price (same as fixedAmount type)
  - User sets: Item Price (original) and Deal Price (final price member pays)
  - System stores: fixedAmount = itemPrice - dealPrice
- **_AddDiscountDialog**: 
  - Added `isOnceOff` boolean to track once-off selection
  - _calculateValues() handles onceOff type (same as fixedAmount)
  - _submit() includes `isOnceOff` in result map
- **_EditDiscountDialog**: Updated to support editing `isOnceOff` field
- **Creation/Edit Flow**:
  - addDiscount() passes `isOnceOff` to DiscountService.createDiscount()
  - editDiscount() passes `isOnceOff` to DiscountService.updateDiscount()

#### DealSelectionPage (`lib/features/auth/deal_selection_page.dart`)
- **Deal Type Extraction**: Added detection of `is_once_off` flag
  - Assigns display name: "Once-Off Deal"
  - Positioned in deal type order: Bill Discount > Once-Off > Weight-Based > Standard
- **Member-Specific Filtering**:
  - New logic in _loadAvailableDeals():
    1. Gets current user ID (if logged in)
    2. Calls DiscountService.getCompletedDealIdsForMember()
    3. Hides any once-off deals with completed status
    4. Shows "already redeemed" debug message
- **Existing Filters**: Once-off deals appear in:
  - Deal type dropdown (members can filter to see only once-off deals)
  - Category filter (if assigned)
  - Search functionality

## Deal Type Reference

The system now supports 4 deal types:

1. **Standard Deal** (Percentage): R50 → R45 (10% off)
2. **Fixed Amount Deal**: R50 → R40 (R10 off)
3. **Once-Off Deal** (NEW): R50 → R35 (one-time only, hides after purchase)
4. **Weight-Based Deal**: R89.99/kg → R69.99/kg (quantity in grams)
5. **Bill Discount**: X% off bill with exclusions

## Business Logic

### For Trusted Partners (Deal Creation)
1. Select "Once-Off Deal" as deal type
2. Enter item name, original price, and deal price
3. Optionally add image and schedule (date range or specific day)
4. Once created, members can view and purchase the deal

### For Members (Deal Selection)
1. Browse deals and see "Once-Off Deal" type in filter/display
2. First time: Can request/purchase the deal normally
3. Payment successful: Deal marked as 'completed' in deal_authorizations
4. Reload deal list: Once-off deal automatically hidden
5. On re-entry: "This deal is no longer available" or simply not shown

### Technical Flow
```
Member tries to purchase once-off deal
  ↓
DealAuthorizationService.requestDealAuthorization()
  ↓
Check if is_once_off = true
  ↓
If yes: Query deal_authorizations for member + discount + status='completed'
  ↓
If found: Throw "You have already redeemed this once-off deal"
  ↓
If not found: Proceed with normal deal authorization
  ↓
Payment successful → status changed to 'completed'
  ↓
Member reloads deals → getCompletedDealIdsForMember() returns this deal_id
  ↓
Deal filtered out in DealSelectionPage._loadAvailableDeals()
```

## Database Queries

### Check if member has redeemed once-off deal:
```sql
SELECT id FROM deal_authorizations 
WHERE member_id = $memberId 
  AND discount_id = $discountId 
  AND status = 'completed'
```

### Get all once-off deals available to members:
```sql
SELECT * FROM trusted_partner_discounts 
WHERE is_once_off = true AND is_active = true
```

### Find which once-off deals a member has completed:
```sql
SELECT DISTINCT discount_id FROM deal_authorizations 
WHERE member_id = $memberId AND status = 'completed'
```

## Files Modified

1. ✅ `add_once_off_deal_flag.sql` - NEW database migration
2. ✅ `lib/models/discount.dart` - Added isOnceOff field
3. ✅ `lib/services/discount_service.dart` - createDiscount, updateDiscount, getCompletedDealIdsForMember()
4. ✅ `lib/services/deal_authorization_service.dart` - Validation logic
5. ✅ `lib/features/auth/discount_management_page.dart` - UI for once-off deal creation
6. ✅ `lib/features/auth/deal_selection_page.dart` - Filtering logic and display

## Testing Checklist

- [ ] Run `add_once_off_deal_flag.sql` on Supabase database
- [ ] Create a once-off deal as trusted partner
- [ ] Verify deal appears in member's deal list with "Once-Off Deal" type
- [ ] Member purchases deal successfully
- [ ] Verify deal disappears from member's list after purchase
- [ ] Other members can still see and purchase the same deal
- [ ] Edit/update once-off deals maintains is_once_off flag
- [ ] Filter by deal type shows/hides once-off deals correctly
- [ ] Schedule feature works with once-off deals
- [ ] Bill discount and once-off are mutually exclusive

## Notes

- Once-off deals use fixed pricing (similar to fixed amount deals)
- Schedule feature (date range or specific days) works with once-off deals
- Multiple members can all redeem the same once-off deal once each
- Admin can create once-off deals for partners
- Soft-delete (is_active) still works with once-off deals
