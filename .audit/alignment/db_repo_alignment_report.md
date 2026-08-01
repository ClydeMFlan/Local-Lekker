# DB vs Repo Alignment Baseline

Generated UTC: 2026-06-18 08:14:50
Project ref: qdrotavcmmevhgveodcp
Allowlist: .audit/alignment/drift_allowlist.json

## Migration Summary
- DB applied migrations: 89
- Repo migration files: 108
- Repo migrations not applied in DB (raw): 19
- Repo migrations not applied in DB (actionable): 14
- Repo migrations not applied in DB (expected): 5
- DB-applied migrations missing in repo: 0

## Edge Function Summary
- DB deployed functions: 20
- Repo function folders: 20
- Repo functions not deployed in DB (raw): 1
- Repo functions not deployed in DB (actionable): 0
- Repo functions not deployed in DB (expected): 1
- DB deployed functions missing in repo: 1

## Classification Snapshot
- Verified classifications: 12
- Missing-required classifications: 1
- Partially-verified classifications: 0
- Still needs-proof classifications: 0

## Repo Migrations Not Applied In DB (Actionable)
- 20251125100511_update_trigger_for_trusted_partner
- 20251125100512_add_admin_created_password_set_columns
- 20251125120000_fix_trusted_partner_deletion_function
- 20260207182830_fix_deal_image_upload_rls
- 20260518090000_allow_null_discount_id_on_deal_authorizations
- 20260613000000_add_member_terms_acceptance_rpc
- 20260613010000_add_member_terms_status_rpc
- 20260613020000_fix_businesses_rls_recursion
- 20260613123000_fix_create_user_profile_date_cast
- 20260613130000_fix_create_user_profile_preserve_subscription
- 20260614093000_add_validate_member_qr_scan_rpc
- 20260617090000_add_accept_tp_payment_terms_rpc
- 20260617093000_activate_tp_member_profile_rpc
- 20260618101000_cleanup_deal_image_storage_policies

## Repo Migrations Not Applied In DB (Expected/Allowlisted)
- temp_20250915090000_create_get_my_role
- temp_20250915102000_create_complete_merchant_signup
- temp_20250916123000_fix_missing_profiles_for_memberships
- temp_20250916124500_add_validation_to_complete_merchant_signup
- temp_20250916125000_create_complete_business_profile

## DB-Applied Migrations Missing In Repo
- (none)

## Repo Functions Not Deployed In DB (Actionable)
- (none)

## Repo Functions Not Deployed In DB (Expected/Allowlisted)
- create-profile-function

## DB-Deployed Functions Missing In Repo
- create-payfast-checkout

## Proof-Based Findings (From User SQL Output)
- Q1: DB migration history contains 20251202000000 and 20251202000001, confirming timestamp drift mapping.
- Q2: admin_delete_member_data/admin_delete_trusted_partner_data exist with concrete function fingerprints (md5 provided).
- Q3: deal image storage policies exist but include duplicated/legacy variants and suspicious expressions referencing b.name in path checks; cleanup migration is required.
- Q4: deal_authorizations.discount_id is nullable (YES), so nullability migration intent is already present.
- Q7a2: member_terms_accepted_status exists as SECURITY DEFINER with expected signature; member terms status RPC migration is baseline-only-verified.
- Q7b: create_user_profile includes subscription token + coalesce subscription pattern; preserve-subscription migration is baseline-only-verified.

## Immediate Action
- Keep production stable: do not apply pending migrations blindly.
- Apply 20260618101000_cleanup_deal_image_storage_policies.sql in controlled rollout (policy dedupe + path-fix).
- Resolve remaining function drift for create-payfast-checkout (import into repo or decommission after dependency proof).
