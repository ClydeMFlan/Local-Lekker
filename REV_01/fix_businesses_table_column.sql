-- Fix the businesses table column name from owner_user_id to owner_member_id
-- This resolves the "column businesses.owner_user_id does not exist" error

-- First, add the new column
ALTER TABLE businesses ADD COLUMN owner_member_id UUID REFERENCES profiles(id);

-- Copy data from the old column to the new column
UPDATE businesses SET owner_member_id = owner_user_id;

-- Make the new column NOT NULL (assuming the old column was NOT NULL)
ALTER TABLE businesses ALTER COLUMN owner_member_id SET NOT NULL;

-- Drop the old column
ALTER TABLE businesses DROP COLUMN owner_user_id;

-- Update any policies that reference the old column name
-- Note: You may need to check and update RLS policies that reference owner_user_id