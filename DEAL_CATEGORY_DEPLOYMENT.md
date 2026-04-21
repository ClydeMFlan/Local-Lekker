# Deal Category Feature - Deployment Steps

## Step 1: Apply Database Migration

1. **Open Supabase Dashboard**
   - Go to: https://supabase.com/dashboard
   - Select project: `local_lekker`

2. **Navigate to SQL Editor**
   - Click **SQL Editor** in left sidebar
   - Click **New Query**

3. **Run Migration Script**
   - Open file: `add_deal_category_column.sql`
   - Copy entire contents
   - Paste into SQL Editor
   - Click **Run** (or press Ctrl+Enter)
   - Wait for success message

4. **Verify Migration**
   - The verification queries at the end should show:
     - ✅ Column `deal_category` exists and is NOT NULL
     - ✅ Default value is 'Other'
     - ✅ Index exists for performance

## Step 2: Pull Latest Code Changes

The following files have been modified:

```bash
# Model updates
lib/models/discount.dart

# Service updates
lib/services/discount_service.dart

# UI - Trusted Partner deal management
lib/features/auth/discount_management_page.dart

# UI - Admin deal management
lib/features/admin/admin_trusted_partner_profile_page.dart

# UI - Member deal browsing
lib/features/auth/deal_selection_page.dart

# Documentation
DEAL_CATEGORY_IMPLEMENTATION.md
```

## Step 3: Test the Feature

### Quick Test Flow
1. **Login as Trusted Partner**
   - Create a new deal
   - See category dropdown (should show all 8 options)
   - Select "Food and Drink"
   - Create deal
   - Verify it saves with correct category

2. **Login as Admin**
   - Navigate to a trusted partner profile
   - Create a deal for them
   - See category dropdown
   - Select "Entertainment"
   - Verify deal is created with category

3. **Login as Member**
   - Go to "Browse Deals"
   - See category filter dropdown
   - Select "Food and Drink"
   - Verify only Food and Drink deals display
   - Try other categories
   - Verify filtering works correctly

### Edge Cases
- [ ] Create deal without selecting category - should show validation error
- [ ] Edit deal and change category - verify category updates
- [ ] Mix category filtering with search - should work together
- [ ] Mix category filtering with deal type - should work together
- [ ] Empty state - when no deals match selected category

## Step 4: Production Deployment

### Before Going Live
1. ✅ Database migration applied successfully
2. ✅ Code changes pulled and tested locally
3. ✅ All test flows completed without errors
4. ✅ No console errors or warnings

### Deployment Checklist
- [ ] Backup Supabase database (automated, but good to verify)
- [ ] Deploy Flutter app with code changes
- [ ] Test on physical device/emulator
- [ ] Monitor error logs for 24 hours
- [ ] Confirm no regression in deal creation/editing
- [ ] Verify member filtering works end-to-end

## Rollback Plan

If issues occur:

### Database Rollback
```sql
-- If needed, remove the column (data loss - use only if critical)
ALTER TABLE public.trusted_partner_discounts 
DROP COLUMN IF EXISTS deal_category CASCADE;

-- Drop the index if it causes issues
DROP INDEX IF EXISTS idx_trusted_partner_discounts_deal_category;
```

### Code Rollback
- Revert commits to affected files
- Redeploy previous app version
- No data migration issues (only additive changes)

## Monitoring

### What to Watch
- Deal creation success rate (should not drop)
- Deal editing success rate (should not drop)
- Member deal browsing performance (should be same or faster)
- Error logs for category-related issues
- User feedback about filter functionality

### Key Metrics
- Time to create deal (should be <2 seconds)
- Time to filter deals (should be <1 second)
- Deal count accuracy when filtering
- Category dropdown load time

## Troubleshooting

### Category dropdown not showing in app
**Solution**: Ensure code changes were pulled correctly
```bash
git pull
flutter pub get
flutter clean
flutter run
```

### Deals not filtering by category
**Solution**: Check that database migration ran successfully
```sql
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'trusted_partner_discounts' 
AND column_name = 'deal_category';
```

### Validation error on deal creation
**Solution**: Category selection is now required - users must select a category
- Inform users they need to select a category
- Provide UI hint/help text if needed

### Performance degradation
**Solution**: If filtering slows down, verify index exists
```sql
SELECT indexname, tablename 
FROM pg_indexes 
WHERE tablename = 'trusted_partner_discounts' 
AND indexname LIKE '%deal_category%';
```

## Support

For issues:
1. Check Supabase dashboard for any errors
2. Review error logs in app
3. Verify database migration succeeded
4. Check that all code files were updated
5. Test on clean rebuild (flutter clean + pub get)

## Timeline

- **Migration**: 5 minutes
- **Code deployment**: 10 minutes
- **Testing**: 30 minutes
- **Production deployment**: 15 minutes

**Total**: ~1 hour including testing

## Notes

- No user communication needed - feature is additive
- Existing deals automatically assigned 'Other' category
- No action required from users
- Feature immediately available after deployment
