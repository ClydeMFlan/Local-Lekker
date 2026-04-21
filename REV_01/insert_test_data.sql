-- SQL Script to insert test profiles and data
-- Run this in Supabase SQL Editor to populate test data

-- Insert test auth.users records (these would normally be created by Supabase Auth)
INSERT INTO auth.users (id, email, created_at, updated_at, last_sign_in_at)
VALUES
  ('550e8400-e29b-41d4-a716-446655440000', 'john.doe@example.com', NOW(), NOW(), NOW()),
  ('550e8400-e29b-41d4-a716-446655440001', 'jane.smith@example.com', NOW(), NOW(), NOW()),
  ('550e8400-e29b-41d4-a716-446655440002', 'mike.johnson@example.com', NOW(), NOW(), NOW()),
  ('550e8400-e29b-41d4-a716-446655440003', 'sarah.williams@example.com', NOW(), NOW(), NOW())
ON CONFLICT (id) DO NOTHING;

-- Insert test profiles
INSERT INTO public.profiles (id, name, surname, email, role, category, street, suburb, city, province, contact, gender, ethnicity, date_of_birth, created_at, updated_at)
VALUES
  ('550e8400-e29b-41d4-a716-446655440000', 'John', 'Doe', 'john.doe@example.com', 'user', 'individual', '123 Main St', 'Cape Town CBD', 'Cape Town', 'Western Cape', '+27123456789', 'male', 'african', '1990-01-15', NOW(), NOW()),
  ('550e8400-e29b-41d4-a716-446655440001', 'Jane', 'Smith', 'jane.smith@example.com', 'user', 'individual', '456 Oak Ave', 'Sandton', 'Johannesburg', 'Gauteng', '+27123456790', 'female', 'white', '1985-03-22', NOW(), NOW()),
  ('550e8400-e29b-41d4-a716-446655440002', 'Mike', 'Johnson', 'mike.johnson@example.com', 'merchant', 'restaurant', '789 Pine Rd', 'Umhlanga', 'Durban', 'KwaZulu-Natal', '+27123456791', 'male', 'indian', '1982-07-10', NOW(), NOW()),
  ('550e8400-e29b-41d4-a716-446655440003', 'Sarah', 'Williams', 'sarah.williams@example.com', 'merchant', 'retail', '321 Elm St', 'Stellenbosch', 'Cape Town', 'Western Cape', '+27123456792', 'female', 'coloured', '1978-11-05', NOW(), NOW())
ON CONFLICT (id) DO NOTHING;

-- Insert memberships for the users
INSERT INTO public.memberships (user_id, role, gateway, created_at, updated_at)
VALUES
  ('550e8400-e29b-41d4-a716-446655440000', 'user', 'direct', NOW(), NOW()),
  ('550e8400-e29b-41d4-a716-446655440001', 'user', 'direct', NOW(), NOW()),
  ('550e8400-e29b-41d4-a716-446655440002', 'merchant', 'direct', NOW(), NOW()),
  ('550e8400-e29b-41d4-a716-446655440003', 'merchant', 'direct', NOW(), NOW())
ON CONFLICT (user_id) DO NOTHING;

-- Insert merchants for merchant users
INSERT INTO public.merchants (user_id, business_name, created_at, updated_at)
VALUES
  ('550e8400-e29b-41d4-a716-446655440002', 'Mike''s Restaurant', NOW(), NOW()),
  ('550e8400-e29b-41d4-a716-446655440003', 'Sarah''s Boutique', NOW(), NOW())
ON CONFLICT (user_id) DO NOTHING;

-- Insert businesses for merchants
INSERT INTO public.businesses (owner_user_id, name, category, address, latitude, longitude, contact_email, contact_number, verified, created_at, updated_at)
VALUES
  ('550e8400-e29b-41d4-a716-446655440002', 'Mike''s Restaurant', 'restaurant', '789 Pine Rd, Umhlanga, Durban, KwaZulu-Natal', -29.8487, 31.0222, 'mike.johnson@example.com', '+27123456791', true, NOW(), NOW()),
  ('550e8400-e29b-41d4-a716-446655440003', 'Sarah''s Boutique', 'retail', '321 Elm St, Stellenbosch, Cape Town, Western Cape', -33.9321, 18.8602, 'sarah.williams@example.com', '+27123456792', true, NOW(), NOW())
ON CONFLICT (owner_user_id) DO NOTHING;

-- Insert merchant discounts for testing receipt scanning
INSERT INTO public.merchant_discounts (merchant_id, name, description, percentage, fixed_amount, is_active, created_at, updated_at)
VALUES
  ('550e8400-e29b-41d4-a716-446655440002', 'Loyalty Discount', '10% off for loyal customers', 10.00, NULL, true, NOW(), NOW()),
  ('550e8400-e29b-41d4-a716-446655440002', 'Student Special', 'R50 off for students', NULL, 50.00, true, NOW(), NOW()),
  ('550e8400-e29b-41d4-a716-446655440003', 'Weekend Special', '15% off on weekends', 15.00, NULL, true, NOW(), NOW()),
  ('550e8400-e29b-41d4-a716-446655440003', 'Bulk Purchase', 'R100 off for purchases over R500', NULL, 100.00, true, NOW(), NOW())
ON CONFLICT DO NOTHING;