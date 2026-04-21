# Social Media Icons Not Showing - Cache Issue

## Problem
The Facebook handle is saved in the database ✓, but doesn't appear in the member's view when opening "View Trusted Partner" → That Old Oak.

## Root Cause
The app uses a **CacheService** to cache trusted partner data for performance. The cached data was loaded BEFORE the social media columns were added to the database. Therefore:

1. ✅ Database has: `facebook_handle`, `instagram_handle`, `website_url`, `business_email`
2. ✅ Query includes these fields
3. ❌ **Cached data doesn't have these fields** (old cache)
4. ❌ App uses cached data instead of fetching fresh data

## Solution Options

### Option 1: Clear App Data (Quickest)
This will force the app to fetch fresh data from the database.

**On Android/iOS Emulator:**
- Uninstall and reinstall the app
- OR clear app data from device settings

**On Windows:**
```powershell
# Delete app data folder
Remove-Item "$env:LOCALAPPDATA\local_lekker" -Recurse -Force -ErrorAction SilentlyContinue
```

**On Web:**
- Clear browser cache (Ctrl+Shift+Delete)
- Clear localStorage for the site

### Option 2: Use Refresh Button
The Trusted Partners page has a refresh button (⟳) in the AppBar. Clicking it will:
1. Call `_loadCategories()` again
2. This should bypass the cache and fetch fresh data

Try clicking the **refresh button** on the "Trusted Partners" page.

### Option 3: Force Cache Invalidation (Code Change)
If refreshing doesn't work, the cache service might need to be cleared programmatically.

## Testing Steps

1. **Close and restart the app completely**
2. Login as member
3. Go to "View Trusted Partners"
4. **Click the refresh button (⟳) in the top-right**
5. Click on "That Old Oak"
6. Check the console/debug output for:
   ```
   🔍 DEBUG: Partner data received:
     - facebook_handle: <your_value>
     - instagram_handle: null
     - website_url: null
     - business_email: null
   ```
7. If facebook_handle shows correctly in console but icon doesn't appear:
   - The data is being passed correctly
   - The display logic needs checking
8. If facebook_handle is null in console:
   - Cache is still being used
   - Need to clear cache more forcefully

## Debug Console Output

I've added debug logging to the shop page. When you open a trusted partner's shop, you should see in the debug console what data is being received. This will tell us if:
- The data is reaching the widget (cache cleared successfully)
- The data is still missing (cache needs more forceful clearing)

## Quick Test
Run this and check the console when opening That Old Oak's shop:
```bash
flutter run -d windows
```

Look for the debug output:
```
🔍 DEBUG: Partner data received:
  - facebook_handle: <value or null>
  ...
```
