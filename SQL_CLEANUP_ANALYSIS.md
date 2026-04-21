# SQL Migration File Cleanup Analysis

**Generated:** January 5, 2026  
**Total SQL Files:** 366

## File Categories

| Category | Count | Purpose | Recommendation |
|----------|-------|---------|-----------------|
| `add_*` | 47 | Schema additions (columns, tables, policies) | **KEEP** - Active migrations |
| `check_*` | 115 | Diagnostic queries (schema inspection, debugging) | **ARCHIVE** - Debugging only |
| `create_*` | 16 | Create tables, functions, RPCs | **KEEP** - Core functionality |
| `debug_*` | 16 | Deep debugging queries | **ARCHIVE** - Debugging only |
| `delete_/cleanup_*` | 11 | Data cleanup, schema fixes | **REVIEW** - May be applied already |
| `fix_*` | 59 | Bug fixes and RLS corrections | **REVIEW** - May be applied already |
| `verify_*` | 16 | Verification queries | **ARCHIVE** - Debugging only |
| Other | 86 | Mixed (schema backups, tests, analytics) | **REVIEW** - Case-by-case |

---

## Cleanup Strategy

### 1. **ARCHIVE These (Safe to Move - They're Just Queries)**
You can safely move these to an `_archived_diagnostics/` folder without affecting the database:

- **All `check_*.sql` files (115 files)** - These are read-only queries for inspection
- **All `debug_*.sql` files (16 files)** - Debugging/diagnostic queries
- **All `verify_*.sql` files (16 files)** - Verification queries

**Action:** Create `_archived_diagnostics/` folder and move these 147 files there.

---

### 2. **REVIEW These (Likely Already Applied)**
These files might already be in your database. Check the `unified_schema_rls_policies.sql` to see if they're redundant:

- **`fix_*` files (59 files)** - Many seem to be iterative fixes to the same issues
  - Example: `fix_notifications_rls.sql`, `fix_notifications_rls_final_comprehensive.sql`, `fix_notifications_rls_ultimate.sql` (multiple versions of same fix)
  - Recommendation: Keep the final version, archive others

- **`delete_/cleanup_*` files (11 files)** - Data cleanup scripts
  - Check if the data they cleaned up still exists
  - If not, they've been applied and can be archived

- **Various other files** - Such as test files, analytics, etc.

---

### 3. **KEEP These (Active Schema Migrations)**
Essential files that define your current schema:

- **`add_*` files (47 files)** - These are incremental migrations
  - Each represents a schema change that may be needed for rebuilding the database
  - They should be applied in order if starting fresh

- **`create_*` files (16 files)** - Functions, RPCs, and tables
  - Core functionality definitions
  - Keep all of these

- **`unified_schema_rls_policies.sql`** - Your source of truth
  - Contains complete schema and RLS policies
  - Keep as the canonical reference

---

## Detailed File Listing by Category

### To Archive (Safe - Non-Destructive Queries)

#### Diagnostic Checks (115 files):
`check_actual_role_in_use.sql`
`check_actual_triggers.sql`
`check_admin_role.sql`
`check_all_tables_columns.sql`
`check_all_tables.sql`
`check_and_fix_duplicate_surnames.sql`
`check_and_fix_trusted_partners.sql`
`check_and_add_insert_policy.sql`
`check_auth_users_structure.sql`
`check_authorization_data.sql`
`check_bill_data_tip.sql`
`check_business_row_for_that_old_oak.sql`
`check_business_trusted_partners_relationship.sql`
`check_businesses_rls_policies.sql`
`check_businesses_rls.sql`
`check_businesses_schema.sql`
`check_businesses_schema_now.sql`
`check_businesses_structure.sql`
`check_businesses_table.sql`
`check_businesses_update_policies.sql`
`check_chat_database.sql`
`check_clydemfaln_profile.sql`
`check_combined.sql`
`check_constraints.sql`
`check_created_at.sql`
`check_current_policies.sql`
`check_deal_auth_data.sql`
`check_deal_auth_nulls.sql`
`check_deal_auth_triggers.sql`
`check_deal_auth_update_rls.sql`
`check_deal_auth_with_joins.sql`
`check_deal_authorization_structure.sql`
`check_deal_authorizations_data.sql`
`check_deal_authorizations_rls.sql`
`check_deal_authorizations_structure.sql`
`check_deal_image_storage_setup.sql`
`check_deal_notifications.sql`
`check_discount_active_status.sql`
`check_discount_id.sql`
`check_discounts_rls.sql`
`check_discounts_schema.sql`
`check_discounts_structure.sql`
`check_discounts_visibility.sql`
`check_exact_query_format.sql`
`check_existing_businesses.sql`
`check_existing_emails.sql`
`check_existing_users.sql`
`check_foreign_keys.sql`
`check_houselillian_user.sql`
`check_logo_database_setup.sql`
`check_logo_urls_in_database.sql`
`check_member_context.sql`
`check_member_signup_fields.sql`
`check_memberships.sql`
`check_memberships_data.sql`
`check_notifications_functions_triggers.sql`
`check_notifications_policies.sql`
`check_notifications_policies_detailed.sql`
`check_notifications_rls_complete.sql`
`check_notifications_select_rls.sql`
`check_partner_logos_policies.sql`
`check_partner_logos_storage_path.sql`
`check_payment.sql`
`check_payment_completed.sql`
`check_payments_columns.sql`
`check_payments_table.sql`
`check_pending.sql`
`check_pending_requests.sql`
`check_pending_without_notifications.sql`
`check_policies.sql`
`check_profile.sql`
`check_profile_data.sql`
`check_profiles.sql`
`check_profiles_schema.sql`
`check_profiles_structure.sql`
`check_qr.sql`
`check_real_profiles.sql`
`check_receipt_fields.sql`
`check_recent_signups.sql`
`check_recipient_code.sql`
`check_rls.sql`
`check_rls_policies.sql`
`check_rls_policies_now.sql`
`check_savings_calculation.sql`
`check_schemas.sql`
`check_status_constraint.sql`
`check_subscription_column.sql`
`check_table_columns.sql`
`check_tables.sql`
`check_test_discount.sql`
`check_that_old_oak_logo.sql`
`check_that_old_oak_logo_mismatch.sql`
`check_tp_all_deals.sql`
`check_tp_password_status.sql`
`check_tp_status.sql`
`check_trigger.sql`
`check_trigger_def.sql`
`check_trigger_status.sql`
`check_trusted_partner_bank_accounts_columns.sql`
`check_trusted_partner_discounts_rls.sql`
`check_trusted_partner_discounts_structure.sql`
`check_trusted_partner_notifications.sql`
`check_trusted_partner_subaccounts.sql`
`check_trusted_partner_tables.sql`
`check_trusted_partners_comprehensive.sql`
`check_trusted_partners_structure.sql`
`check_updated_at.sql`
`check_user.sql`
`check_user_authentication.sql`
`check_user_deletion_issue.sql`
`check_user_role.sql`
`check_user_sync.sql`
`check_uuid.sql`
`check_virtual_receipts_schema.sql`
`check_weight_deal_data.sql`

#### Debug Files (16 files):
`debug_admin.sql`
`debug_auth_deletion.sql`
`debug_business_id_mismatch.sql`
`debug_check.sql`
`debug_database_state.sql`
`debug_latest_authorization.sql`
`debug_notifications_rls.sql`
`debug_notifications_rls_current.sql`
`debug_notifications_rls_deep.sql`
`debug_receipt_generation.sql`
`debug_subscriptions_rls.sql`
`debug_that_old_oak_business.sql`
`debug_tp_creation.sql`
`debug_trusted_partner_deletion.sql`
`debug_trusted_partners.sql`
`debug_why_rls_still_fails.sql`

#### Verify Files (16 files):
`verify_admin_deal_upload_permissions.sql`
`verify_admin_logo_upload_fix.sql`
`verify_app_database_consistency.sql`
`verify_business_id_match.sql`
`verify_deal_authorizations_schema.sql`
`verify_function_created.sql`
`verify_logo_rls_and_storage.sql`
`verify_member_signup_setup.sql`
`verify_notifications_rls.sql`
`verify_notifications_rls_fix.sql`
`verify_remarketing_column.sql`
`verify_tables.sql`
`verify_timestamp_columns.sql`
`verify_tp_member_column.sql`
`verify_trusted_partner_data.sql`
`verify_user_profile_relationship.sql`

---

### To Review (May Be Applied Already)

#### Critical Fix Files (Duplicates/Superseded):
These have multiple versions - only the latest is needed:

- `fix_notifications_rls.sql` (original)
- `fix_notifications_rls_comprehensive.sql`
- `fix_notifications_rls_final_comprehensive.sql`
- `fix_notifications_rls_ultimate.sql` ← **KEEP THIS**
- `force_fix_notifications_rls.sql`
- `ultimate_fix_notifications_rls.sql` ← **Or this?**

**Recommendation:** Keep only the final version, archive others.

Similar patterns with:
- Multiple `fix_deal_authorizations_*.sql` files
- Multiple `fix_trusted_partner_*.sql` files
- Multiple `fix_admin_*.sql` files

---

### To Keep (Active Schema)

#### Add Migrations (47 files):
All of these should be kept as they represent incremental schema changes:
```
add_admin_businesses_rls_policy.sql
add_admin_can_create_deals_permission.sql
add_admin_created_password_flags.sql
add_admin_discounts_policy.sql
add_admin_insert_trusted_partners_policy.sql
add_admin_policies.sql
add_bank_code_to_partner_bank_accounts.sql
add_bill_data_column.sql
add_bill_discount_columns.sql
add_branch_code_column.sql
add_chat_read_receipts.sql
add_chat_tables.sql
add_deal_authorization_columns.sql
add_deal_authorization_delete_policies.sql
add_deal_category_column.sql
add_deal_delete_policies.sql
add_deal_image_column.sql
add_deal_images_rls_policies.sql
add_deal_schedule_columns.sql
add_foreign_keys.sql
add_insert_policy_safe.sql
add_is_weight_based_column.sql
add_logo_url_to_businesses.sql
add_member_read_partner_logos_policy.sql
add_member_terms_columns.sql
add_missing_deal_auth_columns.sql
add_notifications_insert_policy.sql
add_partner_logos_admin_storage_policy.sql
add_payfast_webhook_columns.sql
add_payment_methods_support.sql
add_paystack_fields_to_payments.sql
add_paystack_fields_to_profiles.sql
add_paystack_fields_to_trusted_partners.sql
add_paystack_recipient_code_column.sql
add_paystack_subaccounts.sql
add_paystack_subscription_code.sql
add_processed_bills_foreign_key.sql
add_quantity_to_deal_authorizations.sql
add_receipt_counter_to_businesses.sql
add_remarketing_id_column.sql
add_schedule_data_to_discounts.sql
add_service_role_trusted_partners_policy.sql
add_subscription_column.sql
add_tp_member_status_column.sql
add_trusted_partner_key_and_banking.sql
add_trusted_partner_terms_columns.sql
add_verified_status_column.sql
```

#### Create Statements (16 files):
```
admin_create_trusted_partner.sql
admin_delete_functions.sql
create_admin_analytics_rpc.sql
create_admin_user.sql
create_calibration_receipts_table.sql
create_check_email_function.sql
create_deal_receipts_table.sql
create_get_all_deal_authorizations_rpc.sql
create_get_business_transactions_rpc.sql
create_get_top_deals_function.sql
create_get_top_members_function.sql
create_monthly_revenue_breakdown_rpc.sql
create_notification_bypass_function.sql
create_notification_bypass_function_v2.sql
create_profile_function.sql
create_subscriptions_table.sql
```

#### Reference/Canonical:
```
unified_schema_rls_policies.sql
```

---

## Next Steps

1. **Create Archive Folder:**
   ```bash
   mkdir _archived_diagnostics
   move check_*.sql _archived_diagnostics/
   move debug_*.sql _archived_diagnostics/
   move verify_*.sql _archived_diagnostics/
   ```

2. **Consolidate Duplicate Fixes:**
   - Review all `fix_*` files
   - Keep only the final/latest version of each fix
   - Move older versions to `_archived_diagnostics/`

3. **Review Cleanup/Delete Scripts:**
   - Check if data they cleaned up still exists
   - If applied, archive them
   - Keep if they might be needed again

4. **Test Against `unified_schema_rls_policies.sql`:**
   - This is your source of truth
   - All `add_*` files should be consolidatable into this file
   - Verify no conflicts or duplicates

---

## Summary
- **Safe to Archive:** 147 files (check, debug, verify)
- **Likely Applied:** ~15-20 files (duplicate fixes)
- **Must Keep:** ~63 files (add, create) + unified schema
- **Potential Cleanup:** 100-150 files total

This would reduce your SQL files from **366 to ~150-200**, making the project much more maintainable.
