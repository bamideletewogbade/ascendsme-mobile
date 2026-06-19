/*
  # Fix Missing RLS Policies for Mobile App

  ## Problem
  The mobile app gets "new row violates row-level security policy" errors because:
  1. `receipts` — RLS was never enabled (policies were created but ignored)
  2. `recurring_invoice_templates` — no RLS policies at all
  3. `inventory_reservations` — no INSERT/UPDATE/DELETE policies for business owners
  4. `payroll_runs` — no INSERT/UPDATE/DELETE policies
  5. `shop_orders` / `shop_order_items` — missing INSERT/UPDATE policies
  6. `subscription_tiers` / `business_subscriptions` — missing SELECT policies for mobile
  7. `support_requests` — missing INSERT policy
  8. `crm_profiles` / `crm_interactions` / `customer_groups` — missing INSERT/UPDATE policies
  9. `payment_transactions` — missing INSERT/SELECT policies
  10. `business_documents` — missing INSERT policy for mobile users

  ## Solution
  Enable RLS on tables that have it missing, and add consistent policies
  mirroring the web platform's pattern:
    business_id IN (SELECT id FROM businesses WHERE user_id = auth.uid())
*/

-- ── 1. receipts — ENABLE RLS (was missing!) ───────────────────────────────
ALTER TABLE public.receipts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own receipts" ON public.receipts;
CREATE POLICY "Users can view own receipts"
  ON public.receipts FOR SELECT
  TO authenticated
  USING (
    business_id IN (
      SELECT id FROM public.businesses WHERE user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Users can create own receipts" ON public.receipts;
CREATE POLICY "Users can create own receipts"
  ON public.receipts FOR INSERT
  TO authenticated
  WITH CHECK (
    business_id IN (
      SELECT id FROM public.businesses WHERE user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Users can update own receipts" ON public.receipts;
CREATE POLICY "Users can update own receipts"
  ON public.receipts FOR UPDATE
  TO authenticated
  USING (
    business_id IN (
      SELECT id FROM public.businesses WHERE user_id = auth.uid()
    )
  )
  WITH CHECK (
    business_id IN (
      SELECT id FROM public.businesses WHERE user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Users can delete own receipts" ON public.receipts;
CREATE POLICY "Users can delete own receipts"
  ON public.receipts FOR DELETE
  TO authenticated
  USING (
    business_id IN (
      SELECT id FROM public.businesses WHERE user_id = auth.uid()
    )
  );

-- ── 2. recurring_invoice_templates ───────────────────────────────────────
ALTER TABLE public.recurring_invoice_templates ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own recurring templates" ON public.recurring_invoice_templates;
CREATE POLICY "Users can view own recurring templates"
  ON public.recurring_invoice_templates FOR SELECT
  TO authenticated
  USING (
    business_id IN (
      SELECT id FROM public.businesses WHERE user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Users can create own recurring templates" ON public.recurring_invoice_templates;
CREATE POLICY "Users can create own recurring templates"
  ON public.recurring_invoice_templates FOR INSERT
  TO authenticated
  WITH CHECK (
    business_id IN (
      SELECT id FROM public.businesses WHERE user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Users can update own recurring templates" ON public.recurring_invoice_templates;
CREATE POLICY "Users can update own recurring templates"
  ON public.recurring_invoice_templates FOR UPDATE
  TO authenticated
  USING (
    business_id IN (
      SELECT id FROM public.businesses WHERE user_id = auth.uid()
    )
  )
  WITH CHECK (
    business_id IN (
      SELECT id FROM public.businesses WHERE user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Users can delete own recurring templates" ON public.recurring_invoice_templates;
CREATE POLICY "Users can delete own recurring templates"
  ON public.recurring_invoice_templates FOR DELETE
  TO authenticated
  USING (
    business_id IN (
      SELECT id FROM public.businesses WHERE user_id = auth.uid()
    )
  );

-- ── 3. inventory_reservations ─────────────────────────────────────────────
ALTER TABLE public.inventory_reservations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own reservations" ON public.inventory_reservations;
CREATE POLICY "Users can view own reservations"
  ON public.inventory_reservations FOR SELECT
  TO authenticated
  USING (
    business_id IN (
      SELECT id FROM public.businesses WHERE user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Users can create own reservations" ON public.inventory_reservations;
CREATE POLICY "Users can create own reservations"
  ON public.inventory_reservations FOR INSERT
  TO authenticated
  WITH CHECK (
    business_id IN (
      SELECT id FROM public.businesses WHERE user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Users can update own reservations" ON public.inventory_reservations;
CREATE POLICY "Users can update own reservations"
  ON public.inventory_reservations FOR UPDATE
  TO authenticated
  USING (
    business_id IN (
      SELECT id FROM public.businesses WHERE user_id = auth.uid()
    )
  )
  WITH CHECK (
    business_id IN (
      SELECT id FROM public.businesses WHERE user_id = auth.uid()
    )
  );

-- ── 4. payroll_runs ───────────────────────────────────────────────────────
ALTER TABLE public.payroll_runs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own payroll runs" ON public.payroll_runs;
CREATE POLICY "Users can view own payroll runs"
  ON public.payroll_runs FOR SELECT
  TO authenticated
  USING (
    business_id IN (
      SELECT id FROM public.businesses WHERE user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Users can create own payroll runs" ON public.payroll_runs;
CREATE POLICY "Users can create own payroll runs"
  ON public.payroll_runs FOR INSERT
  TO authenticated
  WITH CHECK (
    business_id IN (
      SELECT id FROM public.businesses WHERE user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Users can update own payroll runs" ON public.payroll_runs;
CREATE POLICY "Users can update own payroll runs"
  ON public.payroll_runs FOR UPDATE
  TO authenticated
  USING (
    business_id IN (
      SELECT id FROM public.businesses WHERE user_id = auth.uid()
    )
  )
  WITH CHECK (
    business_id IN (
      SELECT id FROM public.businesses WHERE user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Users can delete own payroll runs" ON public.payroll_runs;
CREATE POLICY "Users can delete own payroll runs"
  ON public.payroll_runs FOR DELETE
  TO authenticated
  USING (
    business_id IN (
      SELECT id FROM public.businesses WHERE user_id = auth.uid()
    )
  );

-- ── 5. support_requests ───────────────────────────────────────────────────
ALTER TABLE public.support_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own support requests" ON public.support_requests;
CREATE POLICY "Users can view own support requests"
  ON public.support_requests FOR SELECT
  TO authenticated
  USING (
    user_id = auth.uid()
    OR business_id IN (
      SELECT id FROM public.businesses WHERE user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Users can create support requests" ON public.support_requests;
CREATE POLICY "Users can create support requests"
  ON public.support_requests FOR INSERT
  TO authenticated
  WITH CHECK (
    user_id = auth.uid()
  );

-- ── 6. payment_transactions ───────────────────────────────────────────────
ALTER TABLE public.payment_transactions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own payment transactions" ON public.payment_transactions;
CREATE POLICY "Users can view own payment transactions"
  ON public.payment_transactions FOR SELECT
  TO authenticated
  USING (
    business_id IN (
      SELECT id FROM public.businesses WHERE user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Users can create own payment transactions" ON public.payment_transactions;
CREATE POLICY "Users can create own payment transactions"
  ON public.payment_transactions FOR INSERT
  TO authenticated
  WITH CHECK (
    business_id IN (
      SELECT id FROM public.businesses WHERE user_id = auth.uid()
    )
  );

-- ── 7. business_documents — add INSERT policy for mobile ──────────────────
DROP POLICY IF EXISTS "Users can upload own documents" ON public.business_documents;
CREATE POLICY "Users can upload own documents"
  ON public.business_documents FOR INSERT
  TO authenticated
  WITH CHECK (
    business_id IN (
      SELECT id FROM public.businesses WHERE user_id = auth.uid()
    )
  );

-- ── 8. invoices — ensure DELETE policy exists (for void/cancel) ───────────
DROP POLICY IF EXISTS "Users can delete own invoices" ON public.invoices;
CREATE POLICY "Users can delete own invoices"
  ON public.invoices FOR DELETE
  TO authenticated
  USING (
    business_id IN (
      SELECT id FROM public.businesses WHERE user_id = auth.uid()
    )
  );

-- ── 9. user_products — ensure UPDATE/DELETE policies for mobile ───────────
DROP POLICY IF EXISTS "Users can update own products" ON public.user_products;
CREATE POLICY "Users can update own products"
  ON public.user_products FOR UPDATE
  TO authenticated
  USING (
    business_id IN (
      SELECT id FROM public.businesses WHERE user_id = auth.uid()
    )
  )
  WITH CHECK (
    business_id IN (
      SELECT id FROM public.businesses WHERE user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Users can delete own products" ON public.user_products;
CREATE POLICY "Users can delete own products"
  ON public.user_products FOR DELETE
  TO authenticated
  USING (
    business_id IN (
      SELECT id FROM public.businesses WHERE user_id = auth.uid()
    )
  );

-- ── 10. shop_orders — ensure INSERT/UPDATE policies ───────────────────────
DROP POLICY IF EXISTS "Users can create own orders" ON public.shop_orders;
CREATE POLICY "Users can create own orders"
  ON public.shop_orders FOR INSERT
  TO authenticated
  WITH CHECK (
    business_id IN (
      SELECT id FROM public.businesses WHERE user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Users can update own orders" ON public.shop_orders;
CREATE POLICY "Users can update own orders"
  ON public.shop_orders FOR UPDATE
  TO authenticated
  USING (
    business_id IN (
      SELECT id FROM public.businesses WHERE user_id = auth.uid()
    )
  )
  WITH CHECK (
    business_id IN (
      SELECT id FROM public.businesses WHERE user_id = auth.uid()
    )
  );

-- ── 11. crm_profiles — ensure INSERT/UPDATE policies ──────────────────────
ALTER TABLE public.crm_profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own crm profiles" ON public.crm_profiles;
CREATE POLICY "Users can view own crm profiles"
  ON public.crm_profiles FOR SELECT
  TO authenticated
  USING (
    business_id IN (
      SELECT id FROM public.businesses WHERE user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Users can upsert own crm profiles" ON public.crm_profiles;
CREATE POLICY "Users can upsert own crm profiles"
  ON public.crm_profiles FOR INSERT
  TO authenticated
  WITH CHECK (
    business_id IN (
      SELECT id FROM public.businesses WHERE user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Users can update own crm profiles" ON public.crm_profiles;
CREATE POLICY "Users can update own crm profiles"
  ON public.crm_profiles FOR UPDATE
  TO authenticated
  USING (
    business_id IN (
      SELECT id FROM public.businesses WHERE user_id = auth.uid()
    )
  )
  WITH CHECK (
    business_id IN (
      SELECT id FROM public.businesses WHERE user_id = auth.uid()
    )
  );

-- ── 12. shops — ensure INSERT/UPDATE policies ─────────────────────────────
ALTER TABLE public.shops ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own shop" ON public.shops;
CREATE POLICY "Users can view own shop"
  ON public.shops FOR SELECT
  TO authenticated
  USING (
    business_id IN (
      SELECT id FROM public.businesses WHERE user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Users can upsert own shop" ON public.shops;
CREATE POLICY "Users can upsert own shop"
  ON public.shops FOR INSERT
  TO authenticated
  WITH CHECK (
    business_id IN (
      SELECT id FROM public.businesses WHERE user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Users can update own shop" ON public.shops;
CREATE POLICY "Users can update own shop"
  ON public.shops FOR UPDATE
  TO authenticated
  USING (
    business_id IN (
      SELECT id FROM public.businesses WHERE user_id = auth.uid()
    )
  )
  WITH CHECK (
    business_id IN (
      SELECT id FROM public.businesses WHERE user_id = auth.uid()
    )
  );

COMMENT ON TABLE public.receipts IS 'Stores receipts (Realized Revenue) — RLS: business owner access via business_id → user_id lookup.';
COMMENT ON TABLE public.recurring_invoice_templates IS 'Recurring invoice templates — RLS: business owner access.';
COMMENT ON TABLE public.inventory_reservations IS 'Inventory reservations for invoices/bookings/orders — RLS: business owner access.';
COMMENT ON TABLE public.payroll_runs IS 'Monthly payroll runs — RLS: business owner access.';
