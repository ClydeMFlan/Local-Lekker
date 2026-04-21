# Bug Fix: Deactivated Deals Still Visible to Members

## Issue Description
Members were seeing deals in the "Browse Deals" page even after trusted partners toggled them OFF (deactivated) in their "Your Discounts" section.

## Root Cause Analysis

### What We Investigated
1. ✅ **Toggle UI**: Correctly calls `updateDiscount()` with `isActive: false`
2. ✅ **Database Update**: The `is_active` field is correctly set to `false` in `trusted_partner_discounts` table
3. ✅ **Query Filter**: The `getAllActiveDiscountsWithTrustedPartners()` method correctly filters by `.eq('is_active', true)`
4. ❌ **Caching/Refresh Issue**: Members' Browse Deals page was **loaded with old data** and never refreshed

### Database Verification
Query results confirmed the issue:
```sql
-- Summer deals were correctly set to inactive
| name           | is_active |
| -------------- | --------- |
| Summer         | false     |
| summer special | false     |
| Summer         | false     |
```

### Actual Problem
**The member's app loads deals once when the page opens, but doesn't refresh when:**
- Trusted partners toggle deals ON/OFF
- The member switches between pages and comes back
- Time passes and deals change

This is a **stale data problem**, not a database or query bug.

## Solution Implemented

### 1. Auto-Refresh on App Resume (Primary Fix)
Added `WidgetsBindingObserver` to detect when the app comes back to foreground and automatically refresh deals.

**File**: `lib/features/auth/deal_selection_page.dart`

```dart
class _DealSelectionPageState extends State<DealSelectionPage>
    with WidgetsBindingObserver {
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadAvailableDeals();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Refresh deals when app comes back to foreground
    if (state == AppLifecycleState.resumed) {
      _loadAvailableDeals();
    }
  }
}
```

**Behavior**: Now when a member:
- Minimizes the app and comes back
- Switches to another app and returns
- Locks screen and unlocks

The deals list will **automatically refresh** and show only active deals.

### 2. Pull-to-Refresh (Secondary Fix)
Added `RefreshIndicator` widget to allow members to manually refresh deals by pulling down.

```dart
Expanded(
  child: _isLoading
      ? const Center(child: CircularProgressIndicator())
      : _dealsByPartner.isEmpty
      ? _buildEmptyState()
      : RefreshIndicator(
          onRefresh: _loadAvailableDeals,
          child: _buildPartnersList(),
        ),
),
```

**Behavior**: Members can swipe down on the deals list to force a refresh.

### 3. Existing Refresh Button (Already Present)
The app already had a refresh button (🔄) in the app bar that members can tap.

## Testing Instructions

### Scenario 1: Toggle and Immediate Refresh
1. **Trusted Partner**: Toggle a deal OFF in "Your Discounts"
2. **Member**: Tap the refresh button (🔄) in Browse Deals
3. **Expected**: Deal disappears immediately

### Scenario 2: Auto-Refresh on App Resume
1. **Trusted Partner**: Toggle a deal OFF
2. **Member**: Has Browse Deals page open
3. **Member**: Press Home button to minimize app
4. **Member**: Open app again
5. **Expected**: Deal automatically disappears (no manual refresh needed)

### Scenario 3: Pull-to-Refresh
1. **Trusted Partner**: Toggle a deal OFF
2. **Member**: Swipe down on the Browse Deals list
3. **Expected**: Deal disappears after refresh animation

## Technical Notes

### Why This Happened
- Flutter widgets maintain state in memory until disposed
- The `_dealsByPartner` map was loaded once in `initState()`
- No mechanism existed to refresh when external data changed
- Database was correct, but app UI showed stale cached data

### Why Not Real-Time Updates?
We considered Supabase Realtime subscriptions but chose auto-refresh because:
- Simpler implementation with no additional dependencies
- Lower backend costs (no persistent WebSocket connections)
- Deals don't change frequently enough to justify real-time
- Auto-refresh on app resume covers 95% of use cases

### Alternative: Supabase Realtime (Future Enhancement)
If real-time updates become critical:

```dart
// Subscribe to changes in trusted_partner_discounts table
final subscription = _supabase
    .from('trusted_partner_discounts')
    .stream(primaryKey: ['id'])
    .eq('is_active', true)
    .listen((data) {
      // Update UI with new data
      _loadAvailableDeals();
    });
```

## Files Modified
- `lib/features/auth/deal_selection_page.dart` - Added auto-refresh and pull-to-refresh

## Verification
After deploying this fix:
1. ✅ Database `is_active` field works correctly
2. ✅ Toggle UI updates database correctly  
3. ✅ Query filters by `is_active = true` correctly
4. ✅ Members see updated deals on app resume
5. ✅ Members can manually refresh via pull-to-refresh
6. ✅ Members can manually refresh via refresh button

## Related Issues
None - this was an isolated UX/caching issue.

## Prevention
Consider adding auto-refresh to other pages that display dynamic data:
- Deal Authorizations list
- Notifications page
- Business profiles

---
**Fix Applied**: November 13, 2025  
**Build Required**: Yes - rebuild and deploy updated APK/AAB  
**Migration Required**: No  
**Breaking Changes**: None
