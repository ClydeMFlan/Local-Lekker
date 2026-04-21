# 🚀 QUICK START: Deploy Member Archive System

## 5-Minute Deployment Guide

### Step 1: Deploy Database (2 minutes)

1. Open **Supabase Dashboard**
2. Navigate to **SQL Editor**
3. Click **New Query**
4. Copy entire contents of: **`deploy_member_archive_system.sql`**
5. Paste into SQL Editor
6. Click **Run** (or press `Ctrl+Enter`)
7. Wait for completion (~10 seconds)
8. Verify output shows all ✅ checkmarks

**Expected Output**:
```
✅ archived_members table created
✅ Email index created
✅ RLS enabled
✅ 3 policies active
✅ All checks complete! System ready for testing.
```

### Step 2: Verify Deployment (1 minute)

Run this quick check query:
```sql
SELECT * FROM archived_members LIMIT 1;
```

**Expected**: Empty result (no rows yet) but no error

### Step 3: Application Code (Already Done!)

✅ `lib/services/supabase_service.dart` - Already updated
✅ `lib/features/auth/members_signup_page.dart` - Already updated

**No action needed** - code is already in your codebase!

### Step 4: Test with bekkerhenno518@gmail.com (2 minutes)

#### Test 1: Delete Member
1. Login as admin
2. Go to Members List
3. Delete: `bekkerhenno518@gmail.com`

**Verify**:
```sql
SELECT email, name, deleted_at 
FROM archived_members 
WHERE email = 'bekkerhenno518@gmail.com';
```
Should return 1 row ✅

#### Test 2: Re-signup
1. Logout
2. Click "Sign Up as Member"
3. Enter email: `bekkerhenno518@gmail.com`
4. Wait 1 second

**Expected**:
- Green message: "Welcome back! We found your previous details..."
- All fields autofill ✅

---

## That's It! 🎉

Total deployment time: **5 minutes**

## Files Reference

### Must Deploy
- ✅ `deploy_member_archive_system.sql` - **Run this in Supabase**

### Already Deployed (No Action)
- ✅ `lib/services/supabase_service.dart`
- ✅ `lib/features/auth/members_signup_page.dart`

### Documentation (Optional Reading)
- 📖 `MEMBER_ARCHIVE_IMPLEMENTATION_SUMMARY.md` - Overview
- 📖 `MEMBER_ARCHIVE_RESIGNUP_SYSTEM.md` - Technical details
- 📖 `MEMBER_ARCHIVE_TEST_CHECKLIST.md` - Full test plan
- 📖 `MEMBER_ARCHIVE_FLOW_DIAGRAM.md` - Visual flow

---

## Troubleshooting

### Issue: SQL script fails

**Error**: `relation "archived_members" already exists`
**Fix**: Table already created! Skip to Step 2 (verify)

**Error**: `permission denied`
**Fix**: Make sure you're connected as owner/postgres role

### Issue: Autofill doesn't work

**Check 1**: Verify archive exists
```sql
SELECT * FROM archived_members WHERE email = 'bekkerhenno518@gmail.com';
```

**Check 2**: Test RLS policy
```sql
-- Should return policies
SELECT * FROM pg_policies WHERE tablename = 'archived_members';
```

**Check 3**: Browser console (F12)
Look for: `getArchivedMemberByEmail: archived member found`

---

## Support

**Slack**: #local-lekker-dev  
**Docs**: See `MEMBER_ARCHIVE_IMPLEMENTATION_SUMMARY.md`  
**Issues**: Tag @copilot in comments

---

## Success Criteria

✅ SQL script runs without errors  
✅ Verify query returns empty result (no error)  
✅ Admin can delete member  
✅ Archive table populates on deletion  
✅ Signup autofills when deleted member enters email

**Status**: Ready for production! 🚀
