-- Ma Ferme Connectée — brouillon de migration Supabase
-- Branche : amelioration/statut-animaux
-- STATUT : PRÉPARATION / NON EXÉCUTÉ
--
-- IMPORTANT :
-- 1. Ne pas exécuter ce fichier en production avant revue technique et sauvegarde vérifiée.
-- 2. Migration additive : ne supprime ni ne modifie farm_records, V12, farms ou farm_members.
-- 3. Les tables sont nouvelles. Les données locales ne sont PAS importées.
-- 4. Cette première version ne remplace pas les politiques existantes de farm_records.
-- 5. Vérifier les politiques RLS de public.farms et les droits de stockage avant exécution.
--
-- Diagnostic fourni le 2026-11-04 :
-- - RLS activé, non forcé : farms, farm_members, farm_records.
-- - farm_sales, farm_tasks, audit_events absentes.
-- - storage.buckets : aucune ligne retournée.
-- - storage.objects : aucune politique retournée.
-- - has_farm_role exécutable par anon (à restreindre).
--
-- Les rôles existants sont : admin, manager, secretariat, employee.
-- Les comptes doivent être créés individuellement dans Supabase Auth et reliés
-- à farm_members.user_id. Ne jamais stocker de mot de passe dans les tables métier.

BEGIN;

-- A. Restreindre l'exécution des fonctions de contrôle existantes.
REVOKE EXECUTE ON FUNCTION public.has_farm_role(uuid, text[]) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.is_farm_admin(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.is_farm_member(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.has_farm_role(uuid, text[]) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_farm_admin(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_farm_member(uuid) TO authenticated;

-- B. Historique d'audit privé.
CREATE TABLE IF NOT EXISTS public.audit_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  farm_id uuid NOT NULL REFERENCES public.farms(id) ON DELETE CASCADE,
  actor_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  action text NOT NULL,
  entity_type text NOT NULL,
  entity_id uuid NOT NULL,
  occurred_at timestamptz NOT NULL DEFAULT now(),
  before_data jsonb,
  after_data jsonb
);

ALTER TABLE public.audit_events ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.audit_events FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.audit_events TO authenticated;

DROP POLICY IF EXISTS audit_events_admin_read ON public.audit_events;
CREATE POLICY audit_events_admin_read
ON public.audit_events FOR SELECT TO authenticated
USING (public.has_farm_role(farm_id, ARRAY['admin']::text[]));

-- C. Ventes : statut et identité d'approbation protégés.
CREATE TABLE IF NOT EXISTS public.farm_sales (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  farm_id uuid NOT NULL REFERENCES public.farms(id) ON DELETE CASCADE,
  animal_label text NOT NULL,
  sale_date date NOT NULL DEFAULT CURRENT_DATE,
  buyer text,
  weight_kg numeric(12,2) NOT NULL CHECK (weight_kg > 0),
  amount numeric(14,2) NOT NULL CHECK (amount >= 0),
  payment_reference text,
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'approved')),
  created_by uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  approved_by uuid REFERENCES auth.users(id),
  approved_at timestamptz,
  CHECK (
    (status = 'pending' AND approved_by IS NULL AND approved_at IS NULL)
    OR
    (status = 'approved' AND approved_by IS NOT NULL AND approved_at IS NOT NULL)
  )
);

ALTER TABLE public.farm_sales ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.farm_sales FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT ON TABLE public.farm_sales TO authenticated;

DROP POLICY IF EXISTS farm_sales_read_roles ON public.farm_sales;
CREATE POLICY farm_sales_read_roles
ON public.farm_sales FOR SELECT TO authenticated
USING (public.has_farm_role(farm_id, ARRAY['admin','manager','secretariat']::text[]));

DROP POLICY IF EXISTS farm_sales_secretariat_insert ON public.farm_sales;
CREATE POLICY farm_sales_secretariat_insert
ON public.farm_sales FOR INSERT TO authenticated
WITH CHECK (
  public.has_farm_role(farm_id, ARRAY['secretariat']::text[])
  AND created_by = auth.uid()
  AND status = 'pending'
  AND approved_by IS NULL
  AND approved_at IS NULL
);

-- Les modifications de vente et l'approbation passent par les fonctions contrôlées
-- ajoutées ci-dessous ; aucun UPDATE direct n'est accordé au navigateur.

-- D. Tâches : l'affectation est un compte Auth individuel.
CREATE TABLE IF NOT EXISTS public.farm_tasks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  farm_id uuid NOT NULL REFERENCES public.farms(id) ON DELETE CASCADE,
  title text NOT NULL,
  details text,
  assigned_to uuid NOT NULL REFERENCES auth.users(id),
  due_at timestamptz,
  priority text NOT NULL DEFAULT 'normal'
    CHECK (priority IN ('low','normal','high','urgent')),
  status text NOT NULL DEFAULT 'todo'
    CHECK (status IN ('todo','done')),
  created_by uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  completed_by uuid REFERENCES auth.users(id),
  completed_at timestamptz,
  completion_note text,
  completion_photo_path text,
  CHECK (
    (status = 'todo' AND completed_by IS NULL AND completed_at IS NULL)
    OR
    (status = 'done' AND completed_by IS NOT NULL AND completed_at IS NOT NULL)
  )
);

CREATE INDEX IF NOT EXISTS farm_tasks_farm_assignee_idx
ON public.farm_tasks (farm_id, assigned_to, status);

ALTER TABLE public.farm_tasks ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.farm_tasks FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT ON TABLE public.farm_tasks TO authenticated;

DROP POLICY IF EXISTS farm_tasks_read_assigned_or_supervisor ON public.farm_tasks;
CREATE POLICY farm_tasks_read_assigned_or_supervisor
ON public.farm_tasks FOR SELECT TO authenticated
USING (
  public.has_farm_role(farm_id, ARRAY['admin','manager']::text[])
  OR assigned_to = auth.uid()
);

DROP POLICY IF EXISTS farm_tasks_supervisor_insert ON public.farm_tasks;
CREATE POLICY farm_tasks_supervisor_insert
ON public.farm_tasks FOR INSERT TO authenticated
WITH CHECK (
  public.has_farm_role(farm_id, ARRAY['admin','manager']::text[])
  AND created_by = auth.uid()
  AND EXISTS (
    SELECT 1 FROM public.farm_members m
    WHERE m.farm_id = farm_tasks.farm_id
      AND m.user_id = farm_tasks.assigned_to
      AND m.active = true
  )
);

-- E. Fonctions serveur : approbation, correction admin auditée, clôture de tâche.
CREATE OR REPLACE FUNCTION public.approve_farm_sale(p_sale_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_farm_id uuid;
  v_status text;
BEGIN
  SELECT s.farm_id, s.status INTO v_farm_id, v_status
  FROM public.farm_sales s
  WHERE s.id = p_sale_id
  FOR UPDATE;

  IF v_farm_id IS NULL THEN
    RAISE EXCEPTION 'Vente introuvable';
  END IF;
  IF NOT public.has_farm_role(v_farm_id, ARRAY['admin']::text[]) THEN
    RAISE EXCEPTION 'Action réservée à l’administrateur';
  END IF;
  IF v_status <> 'pending' THEN
    RAISE EXCEPTION 'Seule une vente en attente peut être approuvée';
  END IF;

  UPDATE public.farm_sales
  SET status = 'approved',
      approved_by = auth.uid(),
      approved_at = now(),
      updated_at = now()
  WHERE id = p_sale_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_correct_farm_sale(
  p_sale_id uuid,
  p_animal_label text,
  p_sale_date date,
  p_buyer text,
  p_weight_kg numeric,
  p_amount numeric,
  p_payment_reference text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_farm_id uuid;
BEGIN
  SELECT s.farm_id INTO v_farm_id
  FROM public.farm_sales s
  WHERE s.id = p_sale_id
  FOR UPDATE;

  IF v_farm_id IS NULL THEN
    RAISE EXCEPTION 'Vente introuvable';
  END IF;
  IF NOT public.has_farm_role(v_farm_id, ARRAY['admin']::text[]) THEN
    RAISE EXCEPTION 'Action réservée à l’administrateur';
  END IF;
  IF p_weight_kg IS NULL OR p_weight_kg <= 0 OR p_amount IS NULL OR p_amount < 0 THEN
    RAISE EXCEPTION 'Poids ou montant invalide';
  END IF;

  UPDATE public.farm_sales
  SET animal_label = p_animal_label,
      sale_date = p_sale_date,
      buyer = p_buyer,
      weight_kg = p_weight_kg,
      amount = p_amount,
      payment_reference = p_payment_reference,
      updated_at = now()
  WHERE id = p_sale_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.complete_farm_task(
  p_task_id uuid,
  p_completion_note text DEFAULT NULL,
  p_completion_photo_path text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_farm_id uuid;
  v_assigned_to uuid;
  v_status text;
BEGIN
  SELECT t.farm_id, t.assigned_to, t.status
  INTO v_farm_id, v_assigned_to, v_status
  FROM public.farm_tasks t
  WHERE t.id = p_task_id
  FOR UPDATE;

  IF v_farm_id IS NULL THEN
    RAISE EXCEPTION 'Tâche introuvable';
  END IF;
  IF NOT (
    v_assigned_to = auth.uid()
    OR public.has_farm_role(v_farm_id, ARRAY['admin','manager']::text[])
  ) THEN
    RAISE EXCEPTION 'Tâche non attribuée à cet utilisateur';
  END IF;
  IF v_status <> 'todo' THEN
    RAISE EXCEPTION 'Cette tâche est déjà terminée';
  END IF;

  UPDATE public.farm_tasks
  SET status = 'done',
      completed_by = auth.uid(),
      completed_at = now(),
      completion_note = p_completion_note,
      completion_photo_path = p_completion_photo_path,
      updated_at = now()
  WHERE id = p_task_id;
END;
$$;

REVOKE ALL ON FUNCTION public.approve_farm_sale(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.admin_correct_farm_sale(uuid,text,date,text,numeric,numeric,text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.complete_farm_task(uuid,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.approve_farm_sale(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_correct_farm_sale(uuid,text,date,text,numeric,numeric,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.complete_farm_task(uuid,text,text) TO authenticated;

-- F. Journaliser automatiquement les changements de ventes et tâches.
CREATE OR REPLACE FUNCTION public.write_farm_audit_event()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_farm_id uuid;
  v_id uuid;
BEGIN
  IF TG_OP = 'DELETE' THEN
    v_farm_id := OLD.farm_id;
    v_id := OLD.id;
    INSERT INTO public.audit_events
      (farm_id, actor_id, action, entity_type, entity_id, before_data)
    VALUES
      (v_farm_id, auth.uid(), 'delete', TG_TABLE_NAME, v_id, to_jsonb(OLD));
    RETURN OLD;
  ELSIF TG_OP = 'INSERT' THEN
    v_farm_id := NEW.farm_id;
    v_id := NEW.id;
    INSERT INTO public.audit_events
      (farm_id, actor_id, action, entity_type, entity_id, after_data)
    VALUES
      (v_farm_id, auth.uid(), 'insert', TG_TABLE_NAME, v_id, to_jsonb(NEW));
    RETURN NEW;
  ELSE
    v_farm_id := NEW.farm_id;
    v_id := NEW.id;
    INSERT INTO public.audit_events
      (farm_id, actor_id, action, entity_type, entity_id, before_data, after_data)
    VALUES
      (v_farm_id, auth.uid(), 'update', TG_TABLE_NAME, v_id, to_jsonb(OLD), to_jsonb(NEW));
    RETURN NEW;
  END IF;
END;
$$;

DROP TRIGGER IF EXISTS farm_sales_audit_trigger ON public.farm_sales;
CREATE TRIGGER farm_sales_audit_trigger
AFTER INSERT OR UPDATE OR DELETE ON public.farm_sales
FOR EACH ROW EXECUTE FUNCTION public.write_farm_audit_event();

DROP TRIGGER IF EXISTS farm_tasks_audit_trigger ON public.farm_tasks;
CREATE TRIGGER farm_tasks_audit_trigger
AFTER INSERT OR UPDATE OR DELETE ON public.farm_tasks
FOR EACH ROW EXECUTE FUNCTION public.write_farm_audit_event();

-- G. Stockage privé pour justificatifs et photos de tâches.
INSERT INTO storage.buckets (id, name, public)
VALUES ('farm-private-proofs', 'farm-private-proofs', false)
ON CONFLICT (id) DO NOTHING;

CREATE OR REPLACE FUNCTION public.can_access_task_proof(p_farm_id uuid, p_task_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.farm_tasks t
    WHERE t.id = p_task_id
      AND t.farm_id = p_farm_id
      AND (
        t.assigned_to = auth.uid()
        OR public.has_farm_role(p_farm_id, ARRAY['admin','manager']::text[])
      )
  );
$$;

REVOKE ALL ON FUNCTION public.can_access_task_proof(uuid,uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.can_access_task_proof(uuid,uuid) TO authenticated;

DROP POLICY IF EXISTS farm_proofs_read ON storage.objects;
CREATE POLICY farm_proofs_read
ON storage.objects FOR SELECT TO authenticated
USING (
  bucket_id = 'farm-private-proofs'
  AND CASE
    WHEN (storage.foldername(name))[2] = 'sales'
      THEN public.has_farm_role(
        ((storage.foldername(name))[1])::uuid,
        ARRAY['admin','manager','secretariat']::text[]
      )
    WHEN (storage.foldername(name))[2] = 'tasks'
      THEN public.can_access_task_proof(
        ((storage.foldername(name))[1])::uuid,
        ((storage.foldername(name))[3])::uuid
      )
    ELSE false
  END
);

DROP POLICY IF EXISTS farm_proofs_insert ON storage.objects;
CREATE POLICY farm_proofs_insert
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'farm-private-proofs'
  AND CASE
    WHEN (storage.foldername(name))[2] = 'sales'
      THEN public.has_farm_role(
        ((storage.foldername(name))[1])::uuid,
        ARRAY['admin']::text[]
      )
    WHEN (storage.foldername(name))[2] = 'tasks'
      THEN public.can_access_task_proof(
        ((storage.foldername(name))[1])::uuid,
        ((storage.foldername(name))[3])::uuid
      )
    ELSE false
  END
);

DROP POLICY IF EXISTS farm_proofs_admin_update ON storage.objects;
CREATE POLICY farm_proofs_admin_update
ON storage.objects FOR UPDATE TO authenticated
USING (
  bucket_id = 'farm-private-proofs'
  AND public.has_farm_role(
    ((storage.foldername(name))[1])::uuid,
    ARRAY['admin']::text[]
  )
)
WITH CHECK (
  bucket_id = 'farm-private-proofs'
  AND public.has_farm_role(
    ((storage.foldername(name))[1])::uuid,
    ARRAY['admin']::text[]
  )
);

DROP POLICY IF EXISTS farm_proofs_admin_delete ON storage.objects;
CREATE POLICY farm_proofs_admin_delete
ON storage.objects FOR DELETE TO authenticated
USING (
  bucket_id = 'farm-private-proofs'
  AND public.has_farm_role(
    ((storage.foldername(name))[1])::uuid,
    ARRAY['admin']::text[]
  )
);

COMMIT;

-- Convention de chemin obligatoire dans le bucket privé :
-- <farm_id>/sales/<sale_id>/<nom_fichier>
-- <farm_id>/tasks/<task_id>/<nom_fichier>
--
-- TESTS AVANT TOUTE MISE EN SERVICE :
-- 1. Admin : lecture ventes, approbation, correction auditée, accès justificatifs.
-- 2. Secrétariat : créer/voir vente pending, impossible d'approuver ou modifier après approbation.
-- 3. Responsable : lecture ventes et justificatifs uniquement.
-- 4. Employé : aucune lecture ventes ; lecture et clôture de ses seules tâches.
-- 5. Secrétariat : lecture et clôture de ses tâches attribuées.
-- 6. Aucun membre ne peut modifier l'affectation, l'échéance ou la priorité d'une tâche via le client.
-- 7. Un utilisateur d'une autre ferme ou désactivé est refusé.
-- 8. Vérifier les privilèges sur storage.objects et les politiques RLS de public.farms.
-- 9. Vérifier les contraintes métier et la syntaxe dans un projet de test avant production.
--
-- Ce brouillon nécessite une revue avant exécution : en particulier, confirmer les
-- politiques de public.farms, les rôles exacts, le format des chemins Storage,
-- les droits de stockage par défaut et les besoins de correction/suppression.
