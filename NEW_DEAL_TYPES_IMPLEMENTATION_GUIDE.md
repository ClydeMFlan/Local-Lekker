# New Deal Types Implementation - Integration Guide

## Completed Tasks ✓
1. **Database Layer** - `add_new_deal_types.sql`
   - Added `deal_type`, `custom_data`, `requires_manual_price` to `trusted_partner_discounts`
   - Added `member_entered_price`, `applied_discount_amount`, `deal_type`, `deal_snapshot` to `deal_authorizations`

2. **Model Layer** 
   - Updated `Discount.dart` with new fields and type-aware getters
   - Updated `DealAuthorization.dart` with manual pricing snapshot fields
   - Added `isBuyGet` and `isPercentItem` convenience getters

3. **Service Layer**
   - Updated `discount_service.dart` to persist new metadata fields
   - Updated `deal_authorization_service.dart` to capture snapshots
   - Updated `deal_authorization_request_page.dart` with manual price input and calculation

4. **Member UI**
   - Deal selection/browse shows new deal type badges (purple for "Buy/Get", indigo for "% Off Item")
   - Deal authorization request page now:
     - Prompts for item price on "% Off Item" deals
     - Calculates discount and total price dynamically
     - Sends manual price snapshot to backend

## Remaining Tasks

### 1. Complete Add Deal Dialog (`discount_management_page.dart` - `_AddDiscountDialogState`)

Add UI sections for new deal types after the "Exclusions Section" (around line 910):

```dart
// BUY-GET DEAL FIELDS
if (_selectedType == DiscountType.buyGet) ...[
  // Fields: Buy Item Name, Buy Price, Free Item Name, Free Item Price, Total Price
  // See implementation guide below
],

// PERCENT-ITEM DEAL FIELDS  
if (_selectedType == DiscountType.percentItem) ...[
  // Field: Discount Percentage
  // Note: Member enters price at request time
],
```

### 2. Update Form Submission (`_submit` method in `_AddDiscountDialogState`)

Map new deal types to database fields:

```dart
} else if (_selectedType == DiscountType.buyGet) {
  final buyPrice = double.tryParse(_buyItemPriceController.text) ?? 0.0;
  final freeValue = double.tryParse(_freeItemPriceController.text) ?? 0.0;
  final totalPrice = double.tryParse(_totalBuyGetPriceController.text) ?? 0.0;
  
  customData = {
    'buy_item_name': _buyItemNameController.text.trim(),
    'buy_item_price': buyPrice,
    'free_item_name': _freeItemNameController.text.trim(),
    'free_item_value': freeValue,
    'total_price': totalPrice,
  };
  
  // Set itemPrice to total for display purposes
  itemPrice = totalPrice;
  dealType = 'buy_get';
  
} else if (_selectedType == DiscountType.percentItem) {
  percentage = double.tryParse(_percentDiscountController.text) ?? 0.0;
  requiresManualPrice = true;
  dealType = 'percent_item';
  itemPrice = 0.0; // Will be set by member
}
```

### 3. Update Edit Dialog (`_EditDiscountDialogState`)

Mirror new deal type handling in initState and build methods.

### 4. Update createDiscount calls in UI

When calling `DiscountService.createDiscount()`, pass new parameters:

```dart
await _discountService.createDiscount(
  // ... existing params ...
  dealType: dealTypeEnum.toDbValue(), // 'standard', 'buy_get', 'percent_item', etc.
  customData: customData,
  requiresManualPrice: requiresManualPrice,
);
```

### 5. Update Deal Type Display Labels

Deal selection page now uses:
- `'buy_get'` → "Buy/Get"
- `'percent_item'` → "% Off Item"
- `'standard'` → "Standard Deal"
- `'bill_discount'` → "Bill Discount"
- `'once_off'` → "Once-Off Deal"
- `'weight'` → "Weight-Based"

## Key Implementation Details

### Buy-Get Deal (`buy_get`)
- Member selects item: "Buy Coffee (R75) Get Pastry Free (normally R45) for R99"
- Admin sets: buy item name, buy price, free item name, free item value, total combo price
- Member submits with quantity (qty × combo)
- Custom data structure:
  ```json
  {
    "buy_item_name": "Coffee",
    "buy_item_price": 75.00,
    "free_item_name": "Pastry",
    "free_item_value": 45.00,
    "total_price": 99.00
  }
  ```

### Percent-Item Deal (`percent_item`)
- Admin sets: item category, discount percentage
- Member enters: item price at request time (e.g., "This sweater costs R299, apply 20% off")
- Savings = member_price × (percentage / 100)
- Amount = member_price - savings
- Custom data: empty (pricing data comes from member at request time)
- `requires_manual_price = true`

### Deal Authorization Snapshot
When member requests a deal, we capture:
- `member_entered_price`: Only for `percent_item` deals
- `applied_discount_amount`: Calculated savings snapshot
- `deal_type`: Type at request time
- `deal_snapshot`: Full deal data for audit trail

## Testing Checklist

- [ ] Admin can create "Buy this get that" deal
- [ ] Admin can create "% off item" deal
- [ ] Member sees new deal type badges in browse
- [ ] Member can request "Buy/Get" deal with quantity
- [ ] Member prompted to enter price for "% off item" deals
- [ ] Calculations correct for both types
- [ ] Deal snapshot saved to DB
- [ ] Edit dialog loads and saves new types
- [ ] Deal type filter works with new types

## Database Schema Verification

```sql
-- Check new columns exist
SELECT column_name FROM information_schema.columns 
WHERE table_name = 'trusted_partner_discounts'
  AND column_name IN ('deal_type', 'custom_data', 'requires_manual_price');

SELECT column_name FROM information_schema.columns 
WHERE table_name = 'deal_authorizations'
  AND column_name IN ('member_entered_price', 'applied_discount_amount', 
                      'deal_type', 'deal_snapshot');
```
