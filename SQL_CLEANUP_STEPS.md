# SQL File Cleanup Checklist & Commands

## Quick Summary
- **366 total SQL files**
- **147 diagnostic files** (check_*, debug_*, verify_*) → Safe to archive
- **~60 fix_* files** → Review for duplicates
- **47 add_* files** → Keep as migrations
- **16 create_* files** → Keep as functionality

---

## Step 1: Archive Diagnostic Files (147 files)

These are read-only queries and safe to archive:

```powershell
# Navigate to workspace
cd C:\Users\clyde\local_lekker

# Create archive folder
mkdir _archived_diagnostics -ErrorAction SilentlyContinue

# Move diagnostic files
Get-ChildItem -Filter "check_*.sql" | Move-Item -Destination _archived_diagnostics/
Get-ChildItem -Filter "debug_*.sql" | Move-Item -Destination _archived_diagnostics/
Get-ChildItem -Filter "verify_*.sql" | Move-Item -Destination _archived_diagnostics/

# Verify
Write-Output "Files archived: $((Get-ChildItem _archived_diagnostics).Count)"
```

---

## Step 2: Identify Duplicate Fix Files

These `fix_*` files have multiple versions - we need to keep only the latest:

### Notifications RLS Fixes (KEEP: ultimate_fix_notifications_rls.sql)
- fix_notifications_rls.sql
- fix_notifications_rls_comprehensive.sql
- fix_notifications_rls_final_comprehensive.sql
- fix_notifications_rls_ultimate.sql
- force_fix_notifications_rls.sql
- reenable_notifications_rls_correct.sql
- ultimate_fix_notifications_rls.sql ← **LATEST VERSION**
- fix_notifications_rls_with_grants.sql
- fix_notifications_rls_authenticated.sql

**Action:** Archive all except `ultimate_fix_notifications_rls.sql`

### Deal Authorization Fixes (KEEP: Latest version only)
- fix_deal_auth_update_policies.sql
- fix_deal_authorizations_schema.sql
- fix_deal_authorizations_rls.sql
- deal_authorization_fix_summary.sql
- fix_deal_authorization_rls.sql

**Action:** Keep the most comprehensive one, archive others

### Admin Fixes (KEEP: Latest version only)
- fix_admin_check.sql
- fix_admin_deal_image_upload_rls.sql
- fix_admin_deal_image_upload_rls_CORRECTED.sql ← **Likely the final one**
- fix_admin_image_visibility_rls.sql
- fix_admin_member_deletion.sql
- fix_admin_memberships_recursion.sql
- fix_admin_view_deals.sql
- fix_admin_view_trusted_partners.sql

**Action:** Archive all except corrected/final versions

### Trusted Partner Fixes (KEEP: Latest version only)
- fix_null_trusted_partner_ids.sql
- fix_trusted_partner_bank_accounts_schema.sql
- fix_trusted_partner_deletion.sql
- fix_trusted_partner_deletion_function.sql
- fix_user_ids_in_trusted_partner.sql

**Action:** Archive older versions, keep final

### Orphaned/Cleanup Fixes (REVIEW)
- cleanup_auth_user.sql
- cleanup_duplicate_notification_policies.sql
- cleanup_notifications_policies_final.sql
- cleanup_orphaned_clydemfaln.sql
- cleanup_rls_policies.sql
- cleanup_trusted_partner_bank_accounts_rls.sql
- delete_all_receipts.sql
- delete_test_receipt.sql
- delete_tp_user.sql
- delete_user_09e95df7.sql
- delete_user_cascade.sql

**Action:** Check if these have been applied; if so, archive them

---

## Step 3: Move Duplicate Fix Files

```powershell
# Create archives folder for old fixes
mkdir _archived_old_fixes -ErrorAction SilentlyContinue

# Duplicate notifications RLS fixes (keep ultimate_fix_notifications_rls.sql)
@(
    "fix_notifications_rls.sql",
    "fix_notifications_rls_comprehensive.sql",
    "fix_notifications_rls_final_comprehensive.sql",
    "fix_notifications_rls_ultimate.sql",
    "force_fix_notifications_rls.sql",
    "reenable_notifications_rls_correct.sql",
    "fix_notifications_rls_with_grants.sql",
    "fix_notifications_rls_authenticated.sql"
) | ForEach-Object { 
    if (Test-Path $_) { Move-Item $_ _archived_old_fixes/ }
}

# Duplicate deal auth fixes (keep the most comprehensive)
@(
    "fix_deal_auth_update_policies.sql",
    "fix_deal_authorizations_schema.sql",
    "deal_authorization_fix_summary.sql"
) | ForEach-Object {
    if (Test-Path $_) { Move-Item $_ _archived_old_fixes/ }
}

# Duplicate admin fixes (keep CORRECTED version)
@(
    "fix_admin_check.sql",
    "fix_admin_deal_image_upload_rls.sql",
    "fix_admin_memberships_recursion.sql",
    "fix_admin_view_deals.sql",
    "fix_admin_view_trusted_partners.sql",
    "fix_admin_member_deletion.sql"
) | ForEach-Object {
    if (Test-Path $_) { Move-Item $_ _archived_old_fixes/ }
}

Write-Output "Old fixes archived: $((Get-ChildItem _archived_old_fixes).Count)"
```

---

## Step 4: Archive Old Test/Backup Files

```powershell
# Create folder for old/test files
mkdir _archived_legacy -ErrorAction SilentlyContinue

# Move test files
@(
    "test_*.sql",
    "quick_*.sql",
    "*backup*.sql",
    "*test*.sql",
    "temporary_*.sql",
    "temp_*.sql"
) | ForEach-Object {
    Get-ChildItem -Filter $_ | Move-Item -Destination _archived_legacy/ -ErrorAction SilentlyContinue
}

Write-Output "Legacy files archived: $((Get-ChildItem _archived_legacy).Count)"
```

---

## Step 5: Validate Remaining Files

After archiving, you should have:
- **47** `add_*.sql` files
- **16** `create_*.sql` files
- **1** `unified_schema_rls_policies.sql`
- **~15-20** essential `fix_*.sql` files
- **~10** `admin_*.sql` files
- **Total: ~100-120 files**

```powershell
# Count remaining files by type
$counts = @{}
Get-ChildItem -Filter "*.sql" | ForEach-Object {
    $prefix = if ($_.Name -match '^(\w+)_') { $matches[1] } else { 'other' }
    $counts[$prefix]++
}

$counts.GetEnumerator() | Sort-Object Value -Descending | ForEach-Object {
    Write-Output "$($_.Name): $($_.Value) files"
}

Write-Output "`nTotal remaining: $((Get-ChildItem -Filter '*.sql').Count) files"
```

---

## Notes

- **unified_schema_rls_policies.sql** is your source of truth - all migrations should consolidate into this
- **add_*.sql files** should be kept and applied in order when rebuilding the database
- **create_*.sql files** define functions, RPCs, and tables - keep all
- **Latest fix files** are documented; older versions are superseded
- After cleanup, keep archives for reference (they're useful for understanding the evolution of your schema)

---

## What to Do Next

1. Run Step 1 to archive diagnostics (147 files)
2. Manually review duplicate fixes in Step 2 list
3. Run Step 3 to move old fix files
4. Run Step 5 to validate remaining files
5. Consider consolidating all `add_*.sql` into a migration sequence

