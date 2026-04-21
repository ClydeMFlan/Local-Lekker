# Database Tables Analysis - Unused Tables Report

**Analysis Date:** November 7, 2025  
**Total Tables:** 24

## Summary

✅ **USED TABLES (23)** - Keep these  
❌ **UNUSED TABLES (1)** - Can be safely removed  

---

## ✅ USED TABLES (DO NOT REMOVE)

### Core User & Authentication
1. **users** - Core authentication (Supabase Auth)
2. **profiles** - User profile data across all user types
3. **memberships** - Role assignments (member/trusted_partner/admin)

### Member Features
4. **subscriptions** - Member subscription records and expiration
5. **user_qr_codes** - Member QR codes for payments
6. **subscription_renewals** - Subscription renewal history
   - Used in: `lib/services/subscription_service.dart` (line 143)

### Trusted Partner Features  
7. **trusted_partners** - Business partner records
8. **businesses** - Business information and locations
9. **trusted_partner_bank_accounts** - Bank details for payouts (14 references)
   - Used in: `business_profile_page.dart`, `paystack_service.dart`, `bank_account_service.dart`
10. **trusted_partner_discounts** - Discount offers by businesses

### Deal & Authorization System
11. **deal_authorizations** - Deal approval/rejection records
12. **deal_receipts** - Payment receipts for deals (12 references)
   - Used in: `deal_authorization_service.dart`, `deal_payment_webview_page.dart`, `savings_service.dart`, `member_receipts_page.dart`

### Notification System
13. **notifications** - Push notifications and alerts

### Receipt Processing
14. **processed_bills** - Scanned receipt data from businesses
15. **business_bills** - Storage bucket reference for receipt images
16. **bill_approvals** - Receipt approval workflow (7 references)
   - Used in: `lib/services/bill_approval_service.dart`
17. **calibration_receipts** - Template receipts for OCR calibration (3 references)
   - Used in: `lib/services/business_bill_service.dart` (lines 342, 357, 376)
18. **business_logos** - Business logo images (2 references)
   - Used in: `lib/services/business_bill_service.dart` (line 205)

### Payment Processing
19. **payments** - Payment transaction records
20. **virtual_receipts** - Digital receipt generation (5 references)
   - Used in: `discount_service.dart` (lines 422, 443, 502), `deal_payment_webview_page.dart` (line 367)
21. **member_receipts** - Member receipt history (2 references)
   - Used in: `lib/services/discount_service.dart` (lines 464, 486)

### Member Payment Methods
22. **members_bank_accounts** - Member bank details for payouts (6 references)
   - Used in: `paystack_service.dart` (lines 332, 465), `member_profile_page.dart` (lines 1074, 1591, 1612, 1619)
23. **members_card_details** - Member card tokenization (12 references)
   - Used in: `paystack_service.dart` (8 occurrences), `member_profile_page.dart` (4 occurrences)

---

## ❌ UNUSED TABLES (CAN BE REMOVED)

### 1. payment_schedules ❌
**Status:** COMPLETELY UNUSED  
**References:** 0  
**Search Result:** No matches in entire codebase  

**Recommendation:** **SAFE TO DELETE**

This table appears to have been planned for recurring payment scheduling but was never implemented in the application code.

---

## ⚠️ IMPORTANT NOTE ABOUT RECEIPT SCANNING

**Receipt scanning IS still active** and in use throughout the application:
- `calibration_receipts` table: **ACTIVELY USED** for business auto-detection during receipt scanning
- `business_bills` table: **ACTIVELY USED** for storing business receipt templates
- Multiple scanner screens use these features:
  - `StandaloneReceiptScanner`
  - `BillScannerDialog`
  - `TrustedPartnerCalibrationScreen`
  - `BusinessBillScannerDialog`

The calibration system allows trusted partners to upload template receipts, which are then used to automatically identify businesses when members scan receipts.

---

## Implementation Notes

### Tables That Appear Unused But Are Actually Used:

1. **subscription_renewals** - Has 1 reference (subscription_service.dart)
2. **bill_approvals** - Has 7 references (bill_approval_service.dart)
3. **calibration_receipts** - Has 3 references (business_bill_service.dart)
4. **business_logos** - Has 2 references (business_bill_service.dart)
5. **virtual_receipts** - Has 5 references (discount_service.dart, deal_payment_webview_page.dart)
6. **member_receipts** - Has 2 references (discount_service.dart)
7. **deal_receipts** - Has 12 references (multiple services and pages)
8. **members_bank_accounts** - Has 6 references (paystack_service.dart, member_profile_page.dart)
9. **members_card_details** - Has 12 references (paystack_service.dart, member_profile_page.dart)

---

## Deletion SQL Script

```sql
-- ONLY TABLE THAT CAN BE SAFELY REMOVED
DROP TABLE IF EXISTS payment_schedules CASCADE;
```

---

## Critical Warning ⚠️

**DO NOT DELETE ANY OTHER TABLES** without first:
1. Removing all code references
2. Testing the entire application flow
3. Creating a database backup
4. Verifying with the team that the feature is deprecated

All 23 other tables have active code references and are part of the application's core functionality.

---

## Database Table Usage Map

| Table Name | References | Status | Primary Feature |
|------------|-----------|--------|-----------------|
| users | Core | ✅ Used | Authentication |
| profiles | Many | ✅ Used | User Data |
| memberships | Many | ✅ Used | Role Management |
| subscriptions | Many | ✅ Used | Subscription System |
| user_qr_codes | Many | ✅ Used | Payment QR Codes |
| trusted_partners | Many | ✅ Used | Business Management |
| businesses | Many | ✅ Used | Business Info |
| trusted_partner_discounts | Many | ✅ Used | Discount Offers |
| deal_authorizations | Many | ✅ Used | Deal Processing |
| notifications | Many | ✅ Used | Push Notifications |
| processed_bills | Many | ✅ Used | Receipt Scanning |
| business_bills | Many | ✅ Used | Receipt Storage |
| payments | Many | ✅ Used | Payment Processing |
| trusted_partner_bank_accounts | 14 | ✅ Used | Business Payouts |
| subscription_renewals | 1 | ✅ Used | Renewal History |
| bill_approvals | 7 | ✅ Used | Approval Workflow |
| calibration_receipts | 3 | ✅ Used | OCR Templates |
| virtual_receipts | 5 | ✅ Used | Digital Receipts |
| member_receipts | 2 | ✅ Used | Member History |
| deal_receipts | 12 | ✅ Used | Deal Receipts |
| members_bank_accounts | 6 | ✅ Used | Member Payouts |
| members_card_details | 12 | ✅ Used | Card Storage |
| business_logos | 2 | ✅ Used | Logo Images |
| **payment_schedules** | **0** | **❌ UNUSED** | **Not Implemented** |

---

## Conclusion

Out of 24 database tables, **only 1 table (payment_schedules) is unused** and can be safely deleted. All other 23 tables are actively referenced in the application code and are essential for the app's functionality.

**Next Steps:**
1. ✅ Remove `payment_schedules` table from Supabase
2. ✅ Remove any RLS policies associated with it
3. ✅ Document the deletion in migration history
