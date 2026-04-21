-- Allow admin to view all trusted partner discounts (deals)
DROP POLICY IF EXISTS "Admin can view all trusted partner discounts" ON trusted_partner_discounts;

CREATE POLICY "Admin can view all trusted partner discounts"
  ON trusted_partner_discounts
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- Verify the policy was created
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual
FROM pg_policies
WHERE tablename = 'trusted_partner_discounts' AND policyname LIKE '%Admin%';
