-- Migration: add valid_until to invoices
-- Adds a `valid_until` column for proforma/quote expiry dates.
-- Migration-safe: only adds a nullable column — no data migration needed.

ALTER TABLE invoices
ADD COLUMN IF NOT EXISTS valid_until date;

COMMENT ON COLUMN invoices.valid_until IS
  'Expiry date for proforma quotes (status=proforma). NULL for regular invoices.';

-- Index so loadFinancials can efficiently filter proformas by business_id
-- without a sequential scan.
CREATE INDEX IF NOT EXISTS idx_invoices_biz_status_valid
  ON invoices (business_id, status)
  WHERE status = 'proforma';
