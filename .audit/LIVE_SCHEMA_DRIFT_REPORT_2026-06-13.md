# Live Supabase Schema Drift Report

Date: 2026-06-13
Project ref: qdrotavcmmevhgveodcp
Mode: Read-only metadata introspection via linked Supabase CLI

## Scope
This report compares the live linked Supabase database against:
1. The canonical migration chain in `supabase/migrations`
2. The generated types in `supabase/types.ts`
3. Runtime expectations in live Dart code under `lib/`

Supporting live metadata snapshots were captured under `.audit/live_db/`.

## Live Database Snapshot

### Live public tables
- admin_promo_keys
- archived_members
- archived_paystack_data
- archived_pending_payments
- archived_receipts
- bill_approvals
- business_bills
- business_logos
- businesses
- calibration_receipts
- chat_conversations
- chat_messages
- deal_authorizations
- deal_expiry_notifications
- deal_receipts
- member_receipts
- members_bank_accounts
- members_card_details
- memberships
- notifications
- notifications_archive
- payments
- processed_bills
- profiles
- promotion_participant_emails
- promotion_signups
- promotions
- recovery_sessions
- subscription_renewals
- subscriptions
- tp_inquiries
- tp_member_keys
- trusted_partner_bank_accounts
- trusted_partner_discounts
- trusted_partners
- user_qr_codes
- users
- virtual_receipts

### Live public views
- payment_method_analytics
- subscriptions_due_for_renewal
- tp_deals_expired_today
- tp_deals_expiring_tomorrow

### Live public materialized views
- none detected

### Live deployed edge functions
From `supabase functions list` against the linked project:
- create-payfast-checkout
- paystack-webhook
- delete-auth-user
- paystack-proxy
- send-push-notification
- send-tp-inquiry-email
- send-deal-request-email
- send-deal-approval-email
- send-chat-message-email
- send-deal-rejection-email
- send-key-request-email
- send-new-key-email
- send-promo-signup-email
- send-promo-confirmation-email
- scheduled-renewal-worker
- scheduled-deal-expiry-worker
- send-payment-success-email
- send-deal-cancellation-email

## Comparison Summary

### A. Live DB vs canonical migrations in `supabase/migrations`

#### Present in live DB but not cleanly canonicalized by the migration chain
These objects exist live and are used by runtime code, but they are not clearly established by the canonical migration chain in a single reliable path or are primarily represented in root-level SQL scripts:
- admin_promo_keys
- archived_members
- archived_paystack_data
- archived_pending_payments
- archived_receipts
- chat_conversations
- chat_messages
- deal_expiry_notifications
- deal_receipts
- member_receipts
- notifications_archive
- promotion_participant_emails
- promotion_signups
- promotions
- recovery_sessions
- tp_inquiries
- tp_member_keys
- virtual_receipts
- payment_method_analytics view
- tp_deals_expired_today view
- tp_deals_expiring_tomorrow view

Notes:
- Some of these are defined in root SQL scripts such as `add_promotions_table.sql`, `add_tp_member_keys_table.sql`, `add_chat_tables.sql`, `add_deal_expiry_management.sql`, and `create_recovery_sessions_table.sql`, but not consistently represented in the canonical migration chain.
- `subscriptions_due_for_renewal` exists live and is required by the renewal worker.

#### Present in migrations and live, but live has drifted beyond migration baseline
Key examples:
- `profiles`: live has many more operational columns and indexes than the baseline migration shape, including deactivation, verification, password, FCM, terms, and Paystack-related fields.
- `subscriptions`: live includes payment and Paystack-specific columns beyond the narrower canonical reset schema.
- `trusted_partner_discounts`: live includes city/category/schedule/once-off style columns and related indexes beyond the simpler canonical core.
- `trusted_partner_bank_accounts`: live includes paystack recipient/subaccount related fields and unique active-account constraints beyond the baseline reset migration.
- `payments`: live indexes reference `user_id` and `paystack_reference`, which do not match the simpler `member_id`-centric reset schema in `20251013223100_deploy_comprehensive_schema.sql`.

#### Missing from live DB relative to canonical migrations
No obvious top-level missing core tables were found for the main runtime path. The bigger issue is the opposite: live contains more objects and richer shapes than the canonical migration chain documents.

### B. Live DB vs `supabase/types.ts`

`supabase/types.ts` is materially stale.

#### Missing in generated types but present live
Examples include:
- businesses
- trusted_partners
- trusted_partner_discounts
- deal_authorizations
- notifications
- payments
- subscriptions
- subscription_renewals
- trusted_partner_bank_accounts
- business_bills
- business_logos
- calibration_receipts
- chat_conversations
- chat_messages
- promotions
- promotion_signups
- promotion_participant_emails
- recovery_sessions
- tp_member_keys
- deal_receipts
- member_receipts
- virtual_receipts
- notifications_archive
- archived_* tables
- views such as `subscriptions_due_for_renewal`

#### Mismatched table shapes in generated types
Examples already confirmed from prior codebase review and live metadata:
- `processed_bills` in types does not match the richer live/current schema.
- `profiles` in types omits multiple live operational fields.
- `payments` in types is not aligned with live payment fields and indexes.
- `subscriptions` is either absent or incomplete relative to live runtime expectations.

### C. Live DB vs runtime Dart `.from()` usage

#### Tables or storage buckets used in code and present live DB or live storage-adjacent usage
Confirmed code references include:
- recovery_sessions
- promotions
- promotion_signups
- promotion_participant_emails
- businesses
- profiles
- trusted_partners
- trusted_partner_bank_accounts
- trusted_partner_discounts
- tp_member_keys
- deal_authorizations
- deal_receipts
- members_bank_accounts
- members_card_details
- tp_inquiries
- payments
- notifications
- subscriptions
- subscription_renewals
- processed_bills
- user_qr_codes
- users

#### Tables or buckets used in code but not part of relational live table set
These are storage bucket usages or non-table resources, not relational-table drift by themselves:
- `promo-images`
- `partner-logos`
- `business-bills`

#### Tables present live but with no clear runtime `.from()` usage in the extracted set
These may be admin/trigger/worker/internal only or currently unused by the app runtime:
- archived_members
- archived_paystack_data
- archived_pending_payments
- archived_receipts
- bill_approvals may be partially service-driven but not broadly surfaced in the extracted `.from()` slice
- notifications_archive
- member_receipts appears more edge/report oriented than widely used
- payment_method_analytics view

## Detailed Drift Findings

### Missing tables
Relative to runtime expectations, no major relational runtime table appears missing from the live DB.

Relative to the canonical migration chain, the problem is under-documentation rather than absence: several live runtime tables are not canonically represented in `supabase/migrations`.

### Missing columns
No global column absence sweep was completed table-by-table across every runtime field reference, but several previously known runtime expectations are now confirmed to depend on richer live shapes than the canonical migration reset documents.

Likely migration-drift column groups include:
- `profiles`: `is_deactivated`, `deactivated_at`, `deactivation_reason`, verification flags, terms flags, Paystack and FCM fields.
- `subscriptions`: renewal/payment provider columns used by runtime and webhook flows.
- `payments`: `paystack_reference` and related columns implied by live indexes and runtime logic.
- `trusted_partner_discounts`: schedule/category/city/once-off and related operational fields.

### Extra columns
Live DB contains many extra operational columns beyond the canonical migration baseline. This is especially true for:
- profiles
- subscriptions
- payments
- trusted_partner_discounts
- trusted_partner_bank_accounts

### Mismatched types
Confirmed type-level drift indicators:
- `payments` appears to have a live `user_id`-centric shape while the canonical reset migration defines `member_id`.
- Runtime and edge logic rely on JSONB and text/date fields whose exact live shapes exceed the generated types and reset migration expectations.

A complete per-column type mismatch matrix would require generating a normalized expected schema model from migrations, which has not yet been materialized into a machine-readable comparison file.

### Missing policies
Not a live DB issue. Live has extensive policies beyond the canonical baseline.

The real drift is that canonical migrations do not fully explain the live policy surface for:
- chat tables
- promotions
- deal receipts
- notifications archive
- TP-member and admin promo key flows

### Missing triggers
Live DB contains numerous trigger-backed functions beyond the canonical chain, including receipt, inquiry, and updated_at style helpers.

The drift is again canonical underrepresentation, not live absence.

### Missing RPCs
No major runtime RPC appears missing from the live DB. Live function inventory includes:
- get_my_role
- prepare_user_context
- secure_get_admin_dashboard
- get_admin_dashboard
- create_user_profile
- mark_tp_key_used
- get_subscription_status
- accept_member_terms
- member_terms_accepted_status
- create_notification_bypass_rls
- complete_business_profile
- confirm_promo_signup
- get_trusted_partner_analytics
- get_business_transactions
- get_all_deal_authorizations
- get_monthly_revenue_breakdown
- get_top_deals
- get_top_members
- create_recovery_session
- check_email_exists

### RPC signature mismatches
Potential signature-risk areas remain and should be validated against exact call params in Dart:
- `accept_member_terms`
- `member_terms_accepted_status`
- analytics RPCs used by admin and TP dashboards
- `confirm_promo_signup`
- `complete_business_profile`
- `create_notification_bypass_rls`

The live DB has the RPC names. Exact call-by-call parameter compatibility was not exhaustively cross-tabulated in this pass.

### Edge functions referencing nonexistent columns or objects
No immediate live-DB missing-object failure is indicated for deployed edge functions. In fact, live DB contains the views and tables required by key deployed functions:
- `scheduled-renewal-worker` requires `subscriptions_due_for_renewal`: present live.
- `scheduled-deal-expiry-worker` requires `tp_deals_expiring_tomorrow`, `tp_deals_expired_today`, `deal_expiry_notifications`, and `expire_overdue_deals`: present live.
- `paystack-webhook` relies on `deal_receipts`, `virtual_receipts`, `promotion_participant_emails`, richer `subscriptions`, and related helpers: these are present live.

This is a major divergence from the canonical migration chain, which does not fully account for these live dependencies.

### Tables or columns used in code but not present in live DB
No clear relational table absence was found for the extracted runtime `.from()` and known RPC surface.

The storage-related resources `promo-images`, `partner-logos`, and `business-bills` are bucket references and require storage-policy verification separately from table existence.

### Tables or columns present in DB but unused in code
Likely low-usage or unused live objects include:
- archived_members
- archived_paystack_data
- archived_pending_payments
- archived_receipts
- notifications_archive
- some analytics/reporting views and admin-only support structures

These should be treated as candidates for retention-policy review, not automatic deletion.

## Highest Confidence Conclusions
1. The live Supabase database is richer and more production-evolved than the canonical migration chain in `supabase/migrations`.
2. `supabase/types.ts` does not represent the live database accurately and should not be treated as authoritative.
3. Runtime Dart services and deployed edge functions are aligned with the live DB more than with the canonical migration chain.
4. The main drift problem is canonicalization: production objects exist and are in use, but they are not fully represented in the canonical migration history.
5. No evidence in this pass suggests the live DB is missing the main relational objects required by current runtime code.

## Important Gaps Remaining
These require a second-pass normalization step if you want a stricter diff matrix:
1. Full per-column expected-vs-live comparison generated from migration DDL.
2. Exact RPC call-site parameter/signature matrix for every `client.rpc(...)` usage.
3. Storage bucket and storage policy comparison against runtime bucket usage.
4. Full column-usage extraction from Dart `select`, `insert`, and `update` maps to flag unused or missing columns precisely.

## Recommended Next Reports
1. Machine-readable normalized schema export: live tables, columns, indexes, policies, triggers, RPCs, and views.
2. Exact runtime usage matrix: table -> columns read/write -> RPC params -> edge-function dependencies.
3. Canonicalization plan: convert live-only/root-SQL objects into a coherent migration backfill sequence without modifying production data.
