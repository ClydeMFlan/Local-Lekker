# Database Schema Updates Required for Deactivation Feature

## Overview
This document outlines the database column additions required to support the account deactivation feature.

## Required Column Additions

### 1. Profiles Table

Add the following columns to support deactivation:

```sql
-- Add deactivation columns to profiles table
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS is_deactivated BOOLEAN DEFAULT FALSE;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS deactivation_reason TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS deactivated_at TIMESTAMP WITH TIME ZONE;
```

**Column Details:**

| Column | Type | Default | Purpose |
|--------|------|---------|---------|
| `is_deactivated` | BOOLEAN | FALSE | Flag indicating if account is deactivated |
| `deactivation_reason` | TEXT | NULL | User-provided reason for deactivation |
| `deactivated_at` | TIMESTAMP WITH TIME ZONE | NULL | Timestamp when account was deactivated |

### 2. Trusted Partners Table (Optional Enhancement)

Add optional deactivation flag for consistency:

```sql
-- Optional: Add deactivation flag to trusted_partners table
ALTER TABLE trusted_partners ADD COLUMN IF NOT EXISTS is_deactivated BOOLEAN DEFAULT FALSE;
```

This allows for faster queries filtering by trusted_partners instead of joining with profiles.

### 3. Subscriptions Table (Member-Specific)

The following update should be made to the subscriptions table:

```sql
-- Update subscription status to support 'deactivated' status
-- The 'status' column should support values like:
-- 'active', 'payment_failed', 'deactivated', 'expired', etc.

-- Example of checking if deactivated subscriptions exist:
SELECT COUNT(*) FROM subscriptions 
WHERE status = 'deactivated' 
AND user_id = 'member-uuid';
```

**Status Values:**
- `active` - Subscription is active
- `payment_failed` - Payment processing failed
- `deactivated` - User deactivated account
- `expired` - Subscription period expired
- `renewal_pending` - Awaiting renewal payment

### 4. User QR Codes Table (Member-Specific)

The following column should already exist but needs updating during deactivation:

```sql
-- Deactivate all active QR codes for a member
UPDATE user_qr_codes 
SET is_active = FALSE
WHERE user_id = 'member-uuid' AND is_active = TRUE;
```

## RLS Policy Updates

### Profiles Table - RLS Policies

Ensure RLS policies respect the deactivated status:

```sql
-- Members should not see deactivated accounts (except their own)
CREATE POLICY "Members can view active trusted partners" ON profiles
    FOR SELECT USING (
        role = 'trusted_partner' 
        AND is_deactivated = FALSE
        OR id = auth.uid()  -- Can always see own profile
    );

-- Deactivated TP deals should not be visible to members
CREATE POLICY "Members can view only active deals" ON trusted_partner_discounts
    FOR SELECT USING (
        is_active = TRUE
        AND trusted_partner_id NOT IN (
            SELECT id FROM profiles 
            WHERE is_deactivated = TRUE
        )
    );
```

## Indexes for Performance

Add indexes to improve query performance for deactivation features:

```sql
-- Index for faster deactivation queries
CREATE INDEX IF NOT EXISTS idx_profiles_is_deactivated 
ON profiles(is_deactivated, role);

CREATE INDEX IF NOT EXISTS idx_profiles_deactivated_at 
ON profiles(deactivated_at) 
WHERE is_deactivated = TRUE;

-- If using trusted_partners table deactivation flag
CREATE INDEX IF NOT EXISTS idx_trusted_partners_is_deactivated 
ON trusted_partners(is_deactivated);

-- For subscription queries
CREATE INDEX IF NOT EXISTS idx_subscriptions_status_deactivated 
ON subscriptions(user_id, status) 
WHERE status = 'deactivated';
```

## Migration Script Template

Use this template to create a migration SQL file:

```sql
-- Migration: Add deactivation support to profiles
-- Date: 2026-01-09

-- 1. Add deactivation columns to profiles
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS is_deactivated BOOLEAN DEFAULT FALSE;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS deactivation_reason TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS deactivated_at TIMESTAMP WITH TIME ZONE;

-- 2. Add deactivation flag to trusted_partners (optional)
ALTER TABLE trusted_partners ADD COLUMN IF NOT EXISTS is_deactivated BOOLEAN DEFAULT FALSE;

-- 3. Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_profiles_is_deactivated 
ON profiles(is_deactivated, role);

CREATE INDEX IF NOT EXISTS idx_profiles_deactivated_at 
ON profiles(deactivated_at) 
WHERE is_deactivated = TRUE;

CREATE INDEX IF NOT EXISTS idx_trusted_partners_is_deactivated 
ON trusted_partners(is_deactivated);

CREATE INDEX IF NOT EXISTS idx_subscriptions_status_deactivated 
ON subscriptions(user_id, status) 
WHERE status = 'deactivated';

-- 4. Update RLS policies (if needed)
-- See RLS Policy section above

-- Verification
SELECT 
    column_name, 
    data_type, 
    is_nullable
FROM information_schema.columns
WHERE table_name = 'profiles' 
AND column_name IN ('is_deactivated', 'deactivation_reason', 'deactivated_at');
```

## Data Migration

### For Existing Deactivated Accounts

If there are existing deactivated accounts (from manual database updates):

```sql
-- Initialize deactivation timestamps for existing records
UPDATE profiles 
SET deactivated_at = NOW()
WHERE is_deactivated = TRUE AND deactivated_at IS NULL;

-- Set default reason for existing deactivations
UPDATE profiles 
SET deactivation_reason = 'User requested deactivation'
WHERE is_deactivated = TRUE AND deactivation_reason IS NULL;
```

## Verification Queries

After applying migrations, verify the schema:

```sql
-- Check columns exist
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns
WHERE table_name IN ('profiles', 'trusted_partners', 'subscriptions')
AND column_name IN ('is_deactivated', 'deactivation_reason', 'deactivated_at');

-- Check indexes created
SELECT indexname, indexdef 
FROM pg_indexes 
WHERE tablename IN ('profiles', 'trusted_partners', 'subscriptions')
AND indexname LIKE '%deactivat%';

-- Count deactivated accounts
SELECT role, COUNT(*) as deactivated_count
FROM profiles
WHERE is_deactivated = TRUE
GROUP BY role;

-- Check for inconsistencies
SELECT id, role, is_deactivated, deactivated_at, deactivation_reason
FROM profiles
WHERE is_deactivated = TRUE
ORDER BY deactivated_at DESC;
```

## Backup Recommendations

Before applying schema changes, backup your database:

```bash
# Using Supabase CLI
supabase db pull

# Or create manual backup in Supabase dashboard
# Settings → Database → Backups
```

## Troubleshooting

### Column Already Exists
If column exists, the `IF NOT EXISTS` clause prevents errors.

### Index Creation Failures
- Ensure table exists and is not locked
- Check column names match exactly
- Verify data types are correct

### RLS Policy Conflicts
- Drop existing conflicting policies first
- Test policies with sample queries
- Use `SET LOCAL role to [role]` to test as specific role

### Performance Issues
- Run `ANALYZE` command after large migrations
- Check query plans with `EXPLAIN ANALYZE`
- Monitor table size growth
- Consider partitioning if tables become very large

## Support

For questions or issues with schema changes:
1. Review the implementation document
2. Check Supabase documentation on migrations
3. Test changes in a development environment first
4. Keep database backups before major changes
