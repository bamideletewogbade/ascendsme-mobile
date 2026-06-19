-- Add `category` and `image_url` columns to `user_products` table.
-- The mobile code already reads and writes these columns; they were
-- missing from the schema. Safe to apply — both are nullable with defaults.

ALTER TABLE public.user_products
  ADD COLUMN IF NOT EXISTS category text NOT NULL DEFAULT 'General',
  ADD COLUMN IF NOT EXISTS image_url text;

-- Lower the default category constraint so existing rows stay valid.
-- New rows written by mobile will set category explicitly.
COMMENT ON COLUMN public.user_products.category IS 'Product category (e.g. Fashion, Food & Beverage, General). Shared with web.';
COMMENT ON COLUMN public.user_products.image_url IS 'Optional product image URL stored in Supabase Storage.';
