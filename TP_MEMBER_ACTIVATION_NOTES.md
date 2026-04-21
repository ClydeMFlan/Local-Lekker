# TP Member Activation - Technical Notes

## Issue Discovered
The code was attempting to update a `status` column in the `memberships` table that doesn't exist.

## Database Schema Reality
The `memberships` table only has these columns:
- `user_id` (UUID, PRIMARY KEY)
- `role` (TEXT) - Values: 'member', 'trusted_partner', 'admin'
- `gateway` (TEXT) - Payment gateway or activation method
- `created_at` (TIMESTAMP)
- `updated_at` (TIMESTAMP)

**There is NO `status` column in the memberships table.**

## TP Member Activation Flow (Corrected)

When a TP member activates their account using a trusted partner key:

### 1. Profile Update
```dart
profiles.is_tp_member = true
```

### 2. Membership Update
```dart
memberships.role = 'member'
memberships.gateway = 'trusted_partner_key'
```

### 3. QR Code Activation
- Check if user already has a QR code in `user_qr_codes` table
- If exists: Reactivate it with permanent expiry (100 years)
- If not exists: Create new QR code with permanent expiry

```dart
user_qr_codes.is_active = true
user_qr_codes.expires_at = DateTime.now() + 100 years
```

### 4. No Subscription Required
TP members bypass the subscription payment flow entirely. They don't need entries in the `subscriptions` table because:
- Their QR code is activated via the membership gateway
- Payment methods are captured by Paystack on first purchase
- Banking details are NOT required upfront

## Key Differences: Regular Member vs TP Member

| Aspect | Regular Member | TP Member |
|--------|---------------|-----------|
| Activation | Pay R99 subscription | Paste trusted partner key |
| QR Code Expiry | 30 days (renewable) | Permanent (100 years) |
| Banking Details | Not required | Not required |
| Payment Method | Paystack subscription | Paystack on first purchase |
| Subscriptions Table | Required entry | Not required |
| Membership Gateway | 'paystack' | 'trusted_partner_key' |

## Files Modified
1. `lib/features/auth/member_profile_page.dart`
   - Fixed `_verifyTrustedPartnerKey()` to use correct schema
   - Added QR code creation/reactivation logic
   - Removed non-existent `status` column reference

2. `lib/features/auth/widgets/trusted_partner_key_dialog.dart`
   - Fixed membership update to use `upsert` instead of `update`
   - Removed non-existent `status` column reference

## Testing Checklist
- [ ] TP can paste key and click "Activate"
- [ ] Profile updates: `is_tp_member` = true
- [ ] Membership updates: `gateway` = 'trusted_partner_key'
- [ ] QR code created/reactivated in `user_qr_codes`
- [ ] QR code shows as active in member home page
- [ ] TP member can toggle to member view and see QR code
- [ ] First purchase captures payment method in Paystack
- [ ] No banking details form appears
