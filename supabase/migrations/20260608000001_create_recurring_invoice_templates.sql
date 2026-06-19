/*
  # Create recurring_invoice_templates table

  ## Problem
  The mobile app uses the `recurring_invoice_templates` table for managing
  recurring/automated invoices, but the table doesn't exist in the Supabase
  project. This causes the error:
    "could not find the table public recurring invoice templates in the schema cache"

  The table is shared with the AscendSME web platform (ascendsme-b repo).
  RLS policies already exist in migration 20260605000001.

  ## Schema
  Mirrors the web platform's expected schema for recurring invoice templates.
*/

CREATE TABLE IF NOT EXISTS public.recurring_invoice_templates (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id     UUID NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  customer_name   TEXT NOT NULL,
  customer_id     UUID,
  customer_email  TEXT,
  description     TEXT NOT NULL DEFAULT '',
  total_amount    NUMERIC(10,2) NOT NULL DEFAULT 0,
  frequency       TEXT NOT NULL CHECK (frequency IN ('weekly', 'monthly', 'quarterly', 'yearly')),
  day_of_month    INT CHECK (day_of_month IS NULL OR day_of_month BETWEEN 1 AND 31),
  day_of_week     INT CHECK (day_of_week IS NULL OR day_of_week BETWEEN 0 AND 6),
  next_invoice_date DATE NOT NULL,
  last_invoice_date DATE,
  line_items      JSONB NOT NULL DEFAULT '[]'::jsonb,
  is_active       BOOLEAN NOT NULL DEFAULT true,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.recurring_invoice_templates IS
  'Recurring invoice templates for automated invoice generation. Shared with web.';

COMMENT ON COLUMN public.recurring_invoice_templates.frequency IS
  'Invoice generation frequency: weekly, monthly, quarterly, yearly';

COMMENT ON COLUMN public.recurring_invoice_templates.day_of_month IS
  'Day of month for monthly/quarterly/yearly frequency (1-31)';

COMMENT ON COLUMN public.recurring_invoice_templates.day_of_week IS
  'Day of week for weekly frequency (0=Monday, 6=Sunday)';

-- Index for efficient business-scoped queries
CREATE INDEX IF NOT EXISTS idx_recurring_templates_business
  ON public.recurring_invoice_templates (business_id);
CREATE INDEX IF NOT EXISTS idx_recurring_templates_active_next
  ON public.recurring_invoice_templates (business_id, is_active, next_invoice_date);

-- Auto-update updated_at on row modification
CREATE OR REPLACE FUNCTION public.update_recurring_template_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_recurring_template_updated_at
  ON public.recurring_invoice_templates;
CREATE TRIGGER trigger_recurring_template_updated_at
  BEFORE UPDATE ON public.recurring_invoice_templates
  FOR EACH ROW EXECUTE FUNCTION public.update_recurring_template_updated_at();
