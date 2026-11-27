-- Ma Ferme Connectée
-- Diagnostic strictement en lecture seule : rôles et statuts financiers.
-- À exécuter dans Supabase > SQL Editor.
-- Cette requête ne crée, ne modifie et ne supprime aucune donnée.

-- 1) Structure de la table des membres : colonnes disponibles
SELECT
  column_name,
  data_type,
  udt_name,
  is_nullable,
  column_default
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'farm_members'
ORDER BY ordinal_position;

-- 2) Valeurs autorisées par les contraintes CHECK sur les rôles et statuts
SELECT
  c.relname AS table_name,
  con.conname AS constraint_name,
  pg_get_constraintdef(con.oid) AS definition
FROM pg_constraint AS con
JOIN pg_class AS c ON c.oid = con.conrelid
JOIN pg_namespace AS n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relname IN ('farm_members', 'farm_sales', 'farm_expenses', 'farm_payments')
  AND con.contype = 'c'
ORDER BY c.relname, con.conname;

-- 3) Politiques RLS des membres et tables financières
SELECT
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN ('farm_members', 'farm_sales', 'farm_expenses', 'farm_payments')
ORDER BY tablename, policyname;

-- 4) Activation RLS (et forçage éventuel) sur les tables concernées
SELECT
  c.relname AS table_name,
  c.relrowsecurity AS rls_enabled,
  c.relforcerowsecurity AS rls_forced
FROM pg_class AS c
JOIN pg_namespace AS n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relname IN ('farm_members', 'farm_sales', 'farm_expenses', 'farm_payments')
  AND c.relkind = 'r'
ORDER BY c.relname;

-- 5) Fonctions de contrôle des rôles : signature et mode de sécurité
SELECT
  p.proname AS function_name,
  pg_get_function_identity_arguments(p.oid) AS arguments,
  p.prosecdef AS security_definer
FROM pg_proc AS p
JOIN pg_namespace AS n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname IN ('has_farm_role', 'is_farm_admin', 'is_farm_member')
ORDER BY p.proname;
