-- ========================================
-- EXTRACT ALL TRUSTED PARTNER RELATED TABLES AND FIELDS
-- ========================================

-- 1. Find all tables with "trusted_partner" in the name
SELECT 
    table_schema,
    table_name,
    table_type
FROM 
    information_schema.tables
WHERE 
    table_name LIKE '%trusted%partner%'
    OR table_name LIKE '%trusted_partner%'
ORDER BY 
    table_schema, table_name;

-- 2. Get detailed schema for trusted_partners table
SELECT 
    column_name,
    data_type,
    character_maximum_length,
    column_default,
    is_nullable,
    udt_name
FROM 
    information_schema.columns
WHERE 
    table_name = 'trusted_partners'
ORDER BY 
    ordinal_position;

-- 3. Get detailed schema for trusted_partner_bank_accounts table
SELECT 
    column_name,
    data_type,
    character_maximum_length,
    column_default,
    is_nullable,
    udt_name
FROM 
    information_schema.columns
WHERE 
    table_name = 'trusted_partner_bank_accounts'
ORDER BY 
    ordinal_position;

-- 4. Get detailed schema for trusted_partner_discounts table
SELECT 
    column_name,
    data_type,
    character_maximum_length,
    column_default,
    is_nullable,
    udt_name
FROM 
    information_schema.columns
WHERE 
    table_name = 'trusted_partner_discounts'
ORDER BY 
    ordinal_position;

-- 5. Check for any other tables that reference trusted_partners
SELECT 
    tc.table_name AS referencing_table,
    kcu.column_name AS referencing_column,
    ccu.table_name AS referenced_table,
    ccu.column_name AS referenced_column
FROM 
    information_schema.table_constraints AS tc
    JOIN information_schema.key_column_usage AS kcu
      ON tc.constraint_name = kcu.constraint_name
      AND tc.table_schema = kcu.table_schema
    JOIN information_schema.constraint_column_usage AS ccu
      ON ccu.constraint_name = tc.constraint_name
      AND ccu.table_schema = tc.table_schema
WHERE 
    tc.constraint_type = 'FOREIGN KEY'
    AND (ccu.table_name LIKE '%trusted_partner%' OR tc.table_name LIKE '%trusted_partner%')
ORDER BY 
    tc.table_name;

-- 6. Get all indexes on trusted_partner tables
SELECT 
    schemaname,
    tablename,
    indexname,
    indexdef
FROM 
    pg_indexes
WHERE 
    tablename LIKE '%trusted_partner%'
ORDER BY 
    tablename, indexname;

-- 7. Check profiles table for trusted_partner role
SELECT 
    column_name,
    data_type,
    character_maximum_length,
    column_default,
    is_nullable
FROM 
    information_schema.columns
WHERE 
    table_name = 'profiles'
ORDER BY 
    ordinal_position;

-- 8. Get sample data from trusted_partners table (limit 5)
SELECT * FROM trusted_partners LIMIT 5;

-- 9. Get sample data from trusted_partner_bank_accounts table (limit 5)
SELECT * FROM trusted_partner_bank_accounts LIMIT 5;

-- 10. Get sample data from trusted_partner_discounts table (limit 5)
SELECT * FROM trusted_partner_discounts LIMIT 5;

-- 11. Count records in each trusted_partner table
SELECT 'trusted_partners' AS table_name, COUNT(*) AS record_count FROM trusted_partners
UNION ALL
SELECT 'trusted_partner_bank_accounts' AS table_name, COUNT(*) AS record_count FROM trusted_partner_bank_accounts
UNION ALL
SELECT 'trusted_partner_discounts' AS table_name, COUNT(*) AS record_count FROM trusted_partner_discounts;

-- 12. Check RLS policies on trusted_partner tables
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM 
    pg_policies
WHERE 
    tablename LIKE '%trusted_partner%'
ORDER BY 
    tablename, policyname;

-- 13. Get all columns from all tables with full details
SELECT 
    t.table_name,
    c.column_name,
    c.data_type,
    c.character_maximum_length,
    c.column_default,
    c.is_nullable,
    c.udt_name,
    c.ordinal_position
FROM 
    information_schema.tables t
    JOIN information_schema.columns c 
      ON t.table_name = c.table_name
WHERE 
    t.table_name LIKE '%trusted_partner%'
    AND t.table_schema = 'public'
ORDER BY 
    t.table_name, c.ordinal_position;

-- 14. Check businesses table for trusted_partner relationship
SELECT 
    column_name,
    data_type,
    character_maximum_length,
    column_default,
    is_nullable
FROM 
    information_schema.columns
WHERE 
    table_name = 'businesses'
ORDER BY 
    ordinal_position;

-- 15. Get relationship between profiles and trusted_partners
SELECT 
    p.id,
    p.name,
    p.surname,
    p.email,
    p.role,
    p.contact,
    p.street,
    p.city,
    p.province,
    tp.user_id,
    tp.business_name,
    tp.created_at AS tp_created_at
FROM 
    profiles p
    LEFT JOIN trusted_partners tp ON p.id = tp.user_id
WHERE 
    p.role = 'trusted_partner'
LIMIT 10;

-- 16. Check if businesses table has owner_member_id linking to trusted partners
SELECT 
    b.id AS business_id,
    b.name AS business_name,
    b.owner_member_id,
    b.category,
    b.address,
    b.contact_email,
    b.contact_number,
    b.verified,
    p.name AS owner_name,
    p.surname AS owner_surname,
    p.role AS owner_role,
    tp.business_name AS tp_business_name
FROM 
    businesses b
    LEFT JOIN profiles p ON b.owner_member_id = p.id
    LEFT JOIN trusted_partners tp ON b.owner_member_id = tp.user_id
WHERE 
    p.role = 'trusted_partner' OR tp.user_id IS NOT NULL
LIMIT 10;

-- 17. Full trusted partner data with all relationships
-- Note: trusted_partner_bank_accounts links to users via user_id
-- Note: trusted_partner_discounts links to users via trusted_partner_id
SELECT 
    p.id AS profile_id,
    p.name,
    p.surname,
    p.email,
    p.contact,
    p.street,
    p.city,
    p.province,
    tp.business_name AS tp_business_name,
    tp.created_at AS tp_created_at,
    b.id AS business_id,
    b.name AS business_name,
    b.verified AS business_verified,
    b.category AS business_category,
    b.address AS business_address,
    tpba.id AS bank_account_id,
    tpba.bank_name,
    tpba.account_number,
    tpba.account_holder_name,
    tpba.branch_code,
    tpba.account_type,
    tpba.is_active AS bank_account_active,
    COUNT(DISTINCT tpd.id) AS discount_count,
    COUNT(DISTINCT pb.id) AS processed_bills_count
FROM 
    profiles p
    LEFT JOIN trusted_partners tp ON p.id = tp.user_id
    LEFT JOIN businesses b ON p.id = b.owner_member_id
    LEFT JOIN trusted_partner_bank_accounts tpba ON p.id = tpba.user_id
    LEFT JOIN trusted_partner_discounts tpd ON p.id = tpd.trusted_partner_id
    LEFT JOIN processed_bills pb ON p.id = pb.partner_id
WHERE 
    p.role = 'trusted_partner'
GROUP BY 
    p.id, p.name, p.surname, p.email, p.contact, p.street, p.city, p.province,
    tp.business_name, tp.created_at,
    b.id, b.name, b.verified, b.category, b.address,
    tpba.id, tpba.bank_name, tpba.account_number, 
    tpba.account_holder_name, tpba.branch_code, tpba.account_type, tpba.is_active
ORDER BY p.name, p.surname
LIMIT 10;

-- 18. Simple query to see all columns in trusted_partner_bank_accounts
SELECT * FROM trusted_partner_bank_accounts LIMIT 1;

-- 19. Check data integrity - trusted partners without businesses
SELECT 
    p.id,
    p.name,
    p.surname,
    p.email,
    tp.business_name AS tp_business_name,
    b.id AS business_id
FROM 
    profiles p
    JOIN trusted_partners tp ON p.id = tp.user_id
    LEFT JOIN businesses b ON p.id = b.owner_member_id
WHERE 
    p.role = 'trusted_partner'
    AND b.id IS NULL;

-- 20. Check data integrity - businesses without bank accounts
SELECT 
    b.id AS business_id,
    b.name AS business_name,
    b.owner_member_id,
    p.name AS owner_name,
    p.surname AS owner_surname,
    tpba.id AS bank_account_id
FROM 
    businesses b
    JOIN profiles p ON b.owner_member_id = p.id
    LEFT JOIN trusted_partner_bank_accounts tpba ON p.id = tpba.user_id
WHERE 
    p.role = 'trusted_partner'
    AND tpba.id IS NULL;
