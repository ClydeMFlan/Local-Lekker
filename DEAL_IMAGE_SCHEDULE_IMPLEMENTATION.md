# Deal Image Upload & Scheduling Implementation Plan

## Overview
Two major features to implement:
1. **Image Upload for All Deal Types** - Currently only available for Bill Discount
2. **Deal Scheduling System** - Daily, specific days, and date range scheduling

## Part 1: Image Upload for All Deal Types

### Current State
- Image upload UI exists only within `if (_selectedType == DiscountType.billDiscount)` block
- Database column `image_url` already exists in `trusted_partner_discounts` table
- Image upload methods (`_pickImage`, `_removeImage`) already exist
- Image upload state (`_selectedImage`, `_isUploadingImage`) already exists

### Implementation Steps
1. Move image upload section OUTSIDE the Bill Discount conditional block
2. Place it after ALL deal type fields (after percentage/fixed/weight fields)
3. Update both AddDiscountDialog and EditDiscountDialog
4. Ensure image is saved to Supabase storage and URL stored in database

### Files to Modify
- `lib/features/auth/discount_management_page.dart`:
  - Move image upload UI from line ~588-688 to after all type-specific fields
  - Update in both Add and Edit dialogs

## Part 2: Deal Scheduling System

### Database Schema (add_deal_schedule_columns.sql)
```sql
- schedule_type: 'always' | 'daily' | 'specific_days' | 'date_range'
- schedule_days: JSONB array for specific days
- schedule_start_date: TIMESTAMPTZ for date range
- schedule_end_date: TIMESTAMPTZ for date range
- schedule_start_time: TEXT for time ranges
- schedule_end_time: TEXT for time ranges
```

### Schedule Types

#### 1. Daily (Always Active)
- No additional fields needed
- Deal is active 24/7

#### 2. Specific Days
- Format: 
```json
[
  {
    "day": "monday",
    "allDay": true,
    "startTime": null,
    "endTime": null,
    "recurring": true
  },
  {
    "day": "friday",
    "allDay": false,
    "startTime": "17:00",
    "endTime": "22:00",
    "recurring": true
  }
]
```

#### 3. Date Range
- Start date + End date
- Optional: Start time + End time
- If no times specified, deal is active all day during the date range

### UI Components Needed

#### Schedule Button & Dialog
1. **Main Dialog**: Schedule Type Selection
   - Radio buttons: "Always Active", "Daily", "Specific Days", "Date Range"
   
2. **Specific Days Sub-Dialog**:
   - Checkboxes for days of week
   - For each selected day:
     - Toggle: "All Day" or "Specific Time"
     - If specific time: Start time picker, End time picker
     - Checkbox: "Recurring weekly"

3. **Date Range Sub-Dialog**:
   - Start date picker
   - End date picker
   - Toggle: "All Day" or "Specific Time"
   - If specific time: Start time picker, End time picker

### Schedule Display
- Show schedule summary on deal card
- Examples:
  - "Active: Always"
  - "Active: Daily (24/7)"
  - "Active: Mon, Wed, Fri (5pm-10pm)"
  - "Active: Dec 15-31 (9am-5pm)"

### Implementation Steps

#### Step 1: Database Migration
- Run `add_deal_schedule_columns.sql` in Supabase

#### Step 2: Update Discount Model
- Add schedule fields to `lib/models/discount.dart`
- Update `fromJson` and `toJson` methods

#### Step 3: Create Schedule Models
- Create `lib/models/deal_schedule.dart`
- Create `lib/models/day_schedule.dart`

#### Step 4: Create Schedule Dialog
- Create `lib/features/auth/widgets/schedule_dialog.dart`
- Implement schedule type selection
- Implement specific days picker
- Implement date range picker

#### Step 5: Update Discount Service
- Add schedule parameters to `createDiscount`
- Add schedule parameters to `updateDiscount`
- Update queries to filter by active schedule

#### Step 6: Update UI
- Add "Schedule" button to Add/Edit Deal dialogs
- Display schedule summary on deal cards
- Add schedule indicator icon

#### Step 7: Update Member-Facing Queries
- Modify `getAllActiveDiscountsWithTrustedPartners` to use `is_deal_active_now()` function
- Only show deals that are currently active based on schedule

## Testing Checklist

### Image Upload
- [ ] Can add image to Percentage deal
- [ ] Can add image to Fixed Amount deal
- [ ] Can add image to Weight-based deal
- [ ] Can add image to Bill Discount deal
- [ ] Can edit existing deals and change image
- [ ] Can remove image from deal
- [ ] Image appears on member's deal browse page
- [ ] Image uploads to Supabase storage
- [ ] Image URL saves to database

### Scheduling
- [ ] Can set deal to "Always Active"
- [ ] Can set deal to "Daily"
- [ ] Can set specific days (Mon-Sun)
- [ ] Can set all-day for specific days
- [ ] Can set time range for specific days
- [ ] Can set recurring weekly for specific days
- [ ] Can set date range with dates only
- [ ] Can set date range with dates + times
- [ ] Schedule displays correctly on deal card
- [ ] Members only see deals that are currently active
- [ ] Scheduled deals activate/deactivate automatically

## Priority Order
1. Part 1: Move image upload (Quick win, ~30 minutes)
2. Part 2: Database migration (5 minutes)
3. Part 2: Create schedule models (30 minutes)
4. Part 2: Create schedule UI (2-3 hours)
5. Part 2: Integrate schedule into deal creation (1 hour)
6. Part 2: Update member queries (30 minutes)
7. Testing (1-2 hours)

**Total Estimated Time: 6-8 hours**
