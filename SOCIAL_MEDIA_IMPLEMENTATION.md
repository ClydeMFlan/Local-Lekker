# Social Media Handles Implementation

## Overview
Added social media handles (Facebook, Instagram, Website, Email) to trusted partners that display as clickable icons when members view their shop.

## Database Changes
**File:** `add_social_handles_to_businesses.sql`

Added 4 new columns to the `businesses` table:
- `facebook_handle` - Facebook page URL or username
- `instagram_handle` - Instagram handle (with or without @)
- `website_url` - Business website URL
- `business_email` - Public business email for customer contact

**To apply:** Run the SQL migration in Supabase SQL Editor

## Code Changes

### 1. Business Profile Edit Screen
**File:** `lib/features/auth/business_profile_page.dart`

- Added 4 new TextEditingController fields for social media handles
- Added "Social Media & Web Presence" section in the edit form with:
  - Facebook input field (with Facebook icon)
  - Instagram input field (with camera icon)
  - Website input field (with language icon)
  - Business Email input field (with email icon)
- Controllers properly initialized, loaded from database, saved to database, and disposed
- Fields are optional (not required)

### 2. Member View - Shop Page
**File:** `lib/features/auth/trusted_partner_shop_page.dart`

- Added `url_launcher` import for opening external links
- Added `_buildSocialMediaSection()` widget that displays social media buttons
- Added `_buildSocialIcon()` helper for consistent icon styling
- Added URL formatters for Facebook and Instagram handles
- Added `_launchUrl()` method to open links in external browser
- Section only displays if at least one social handle is present
- Each icon is clickable and opens the respective platform

**Icon Colors:**
- Facebook: #1877F2 (official blue)
- Instagram: #E4405F (official pink)
- Website: #4CAF50 (green)
- Email: #FF9800 (orange)

### 3. Trusted Partners List
**File:** `lib/features/auth/trusted_partners_by_category_page.dart`

- Updated database query to fetch social media fields along with partner data
- Passes data to shop page for display

## Testing Steps

1. **Apply Database Migration:**
   ```sql
   -- Run in Supabase SQL Editor
   -- File: add_social_handles_to_businesses.sql
   ```

2. **Test as Trusted Partner:**
   - Login as trusted partner
   - Navigate to Business Profile/Details
   - Scroll to "Social Media & Web Presence" section
   - Add handles (examples):
     - Facebook: `facebook.com/mybusiness` or `@mybusiness`
     - Instagram: `@mybusiness` or `mybusiness`
     - Website: `https://mybusiness.com`
     - Email: `info@mybusiness.com`
   - Save changes
   - Verify handles are saved by refreshing the page

3. **Test as Member:**
   - Login as member
   - Navigate to "View Trusted Partners"
   - Select the trusted partner you just updated
   - Verify "Connect with us" section appears below header
   - Click each social icon and verify it opens:
     - Facebook → Opens Facebook page
     - Instagram → Opens Instagram profile
     - Website → Opens business website
     - Email → Opens mail client with email pre-filled

4. **Edge Cases to Test:**
   - Partner with no social handles → Section should not appear
   - Partner with only some handles → Only those icons should appear
   - Invalid URLs → Should show error snackbar
   - Various URL formats for Facebook/Instagram → Should normalize correctly

## URL Formatting Logic

**Facebook:**
- `https://facebook.com/page` → kept as-is
- `facebook.com/page` → adds `https://`
- `@page` → converts to `https://facebook.com/page`
- `page` → converts to `https://facebook.com/page`

**Instagram:**
- `https://instagram.com/user` → kept as-is
- `instagram.com/user` → adds `https://`
- `@user` → converts to `https://instagram.com/user`
- `user` → converts to `https://instagram.com/user`

**Email:**
- Always prepends `mailto:` for proper email client handling

## Package Dependencies
- `url_launcher: ^6.1.10` (already in pubspec.yaml)

## Notes
- All social media fields are optional
- Trusted partners can update their handles anytime
- Section auto-hides if no handles are present
- Links open in external browser/app
- Icons use brand colors for recognition
