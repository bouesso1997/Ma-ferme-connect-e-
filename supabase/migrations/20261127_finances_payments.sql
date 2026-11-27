-- Ma Ferme Connectée
-- Migration additive : ventes, dépenses et règlements
-- À relire puis exécuter manuellement dans Supabase SQL Editor.
-- Aucun enregistrement existant n'est supprimé.

BEGIN;

ALTER TABLE public.farm_sales
  ADD COLUMN IF NOT EXISTS customer_name text;

ALTER TABLE public.farm_expenses
  ADD COLUMN IF NOT EXISTS supplier_name text;

-- Clés composites pour garantir qu'un règlement et son opération
-- appartiennent toujours à la même ferme.
CREATE UNIQUE INDEX IF NOT EXISTS farm_sales_farm_id_id_uidx
  ON public.farm_sales (farm_id, id);

CREATE UNIQUE INDEX IF NOT EXISTS farm_expenses_farm_id_id_uidx
  ON public.farm_expenses (farm_id, id);

CREATE TABLE IF NOT EXISTS public.farm_payments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  farm_id uuid NOT NULL,
  sale_id uuid,
  expense_id uuid,
  payment_date date NOT NULL DEFAULT CURRENT_DATE,
  amount numeric NOT NULL CHECK (amount > 0),
  payment_method text,
  reference text,
  created_by uuid REFERENCES auth.users(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT farm_payments_exactly_one_operation
    CHECK (((sale_id IS NOT NULL)::integer + (expense_id IS NOT NULL)::integer) = 1),
  CONSTRAINT farm_payments_sale_same_farm_fkey
    FOREIGN KEY (farm_id, sale_id)
    REFERENCES public.farm_sales (farm_id, id),
  CONSTRAINT farm_payments_expense_same_farm_fkey
    FOREIGN KEY (farm_id, expense_id)
    REFERENCES public.farm_expenses (farm_id, id)
);

CREATE INDEX IF NOT EXISTS farm_payments_farm_date_idx
  ON public.farm_payments (farm_id, payment_date DESC);

CREATE INDEX IF NOT EXISTS farm_payments_sale_idx
  ON public.farm_payments (farm_id, sale_id)
  WHERE sale_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS farm_payments_expense_idx
  ON public.farm_payments (farm_id, expense_id)
  WHERE expense_id IS NOT NULL;

ALTER TABLE public.farm_payments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS payments_select_authorized_roles ON public.farm_payments;
CREATE POLICY payments_select_authorized_roles
  ON public.farm_payments
  FOR SELECT TO authenticated
  USING (has_farm_role(farm_id, ARRAY['admin'::text, 'manager'::text, 'secretariat'::text]));

DROP POLICY IF EXISTS payments_insert_management_roles ON public.farm_payments;
CREATE POLICY payments_insert_management_roles
  ON public.farm_payments
  FOR INSERT TO authenticated
  WITH CHECK (
    has_farm_role(farm_id, ARRAY['admin'::text, 'secretariat'::text])
    AND created_by = auth.uid()
  );

DROP POLICY IF EXISTS payments_update_admin_only ON public.farm_payments;
CREATE POLICY payments_update_admin_only
  ON public.farm_payments
  FOR UPDATE TO authenticated
  USING (is_farm_admin(farm_id))
  WITH CHECK (is_farm_admin(farm_id));

DROP POLICY IF EXISTS payments_delete_admin_only ON public.farm_payments;
CREATE POLICY payments_delete_admin_only
  ON public.farm_payments
  FOR DELETE TO authenticated
  USING (is_farm_admin(farm_id));

COMMIT;

-- Vérification après exécution :
SELECT
  tablename,
  rowsecurity AS rls_enabled
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename IN ('farm_sales', 'farm_expenses', 'farm_payments')
ORDER BY tablename;
