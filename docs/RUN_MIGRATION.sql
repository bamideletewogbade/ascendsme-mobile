-- Migration: 20260608000001_add_category_and_image_url_to_user_products
-- Run this in Supabase Dashboard → SQL Editor
--
-- AFTER running, uncomment the 'category' lines in:
--   lib/services/supabase_service.dart (createProduct + updateProduct)

ALTER TABLE user_products ADD COLUMN IF NOT EXISTS category TEXT;
ALTER TABLE user_products ADD COLUMN IF NOT EXISTS image_url TEXT;
