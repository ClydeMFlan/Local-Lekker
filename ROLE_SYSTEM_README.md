# Role System Enforcement - 3 Roles Only

## ✅ **CONFIRMED: Only 3 Valid Roles**

The Local Lekker system now enforces **exactly 3 roles**:

1. **`admin`** - Administrative users with full system access
2. **`trusted_partner`** - Business owners who can approve bills and receive payments
3. **`member`** - Regular users who can scan bills and make purchases

## 🔧 **Changes Made**

### **Database Constraints Added**
- Check constraints on `memberships.role` and `profiles.role` tables
- Only allows: `'admin'`, `'trusted_partner'`, `'member'`

### **Automatic Role Assignment**
- **Signup Mapping:**
  - `user_type: 'trusted_partner'` → `role: 'trusted_partner'`
  - `user_type: 'admin'` → `role: 'admin'`
  - `user_type: 'user'` (or any other) → `role: 'member'`

- **Database Triggers:**
  - `handle_user_role_assignment()` - Assigns roles in memberships table
  - `handle_profile_role_assignment()` - Assigns roles in profiles table

### **Data Cleanup**
- All existing invalid roles converted to `'member'` (safe default)
- Future inserts prevented from using invalid roles

## 📋 **How to Apply**

Run `enforce_three_roles_only.sql` in your Supabase SQL Editor:

```sql
-- This script will:
-- 1. Check current roles in the system
-- 2. Update any invalid roles to 'member'
-- 3. Add check constraints to prevent invalid roles
-- 4. Create triggers for automatic role assignment
-- 5. Verify the final state
```

## ✅ **Verification**

After running the script, verify:

```sql
-- Check roles in memberships
SELECT role, COUNT(*) FROM memberships GROUP BY role;

-- Check roles in profiles  
SELECT role, COUNT(*) FROM profiles GROUP BY role;

-- Should only show: admin, trusted_partner, member
```

## 🔄 **Role Assignment Flow**

1. **User Signs Up:**
   - Trusted Partner: `user_type = 'trusted_partner'` → `role = 'trusted_partner'`
   - Regular User: `user_type = 'user'` → `role = 'member'`
   - Admin: `user_type = 'admin'` → `role = 'admin'`

2. **Navigation:**
   - `admin` → AdminDashboardScreen
   - `trusted_partner` → TrustedPartnerHomePage (with bill approvals)
   - `member` → UserHomePage

3. **Permissions:**
   - Each role has appropriate RLS policies and access controls

## 🚫 **No Other Roles Allowed**

The system now strictly enforces only these 3 roles. Any attempt to create users with different roles will be automatically corrected to `'member'`.