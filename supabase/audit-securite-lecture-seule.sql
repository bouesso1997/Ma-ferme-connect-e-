-- Ma Ferme Connectée — audit de sécurité Supabase
-- SCRIPT STRICTEMENT EN LECTURE SEULE : SELECT uniquement.
-- À exécuter dans Supabase > SQL Editor. Ne modifie aucune table ni politique.

-- 1) Présence des tables et activation de RLS
SELECT
  n.nspname AS schema_name,
  c.relname AS table_name,
  c.relkind AS object_type,
  c.relrowsecurity AS rls_enabled,
  c.relforcerowsecurity AS rls_forced
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relname IN ('farm_sales', 'farm_expenses', 'farm_payments')
ORDER BY c.relname;

-- 2) Politiques RLS réelles sur les opérations financières
SELECT
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual AS using_expression,
  with_check
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN ('farm_sales', 'farm_expenses', 'farm_payments')
ORDER BY tablename, cmd, policyname;

-- 3) Colonnes et contraintes des paiements
SELECT
  c.column_name,
  c.data_type,
  c.is_nullable,
  c.column_default
FROM information_schema.columns c
WHERE c.table_schema = 'public'
  AND c.table_name = 'farm_payments'
ORDER BY c.ordinal_position;

SELECT
  tc.constraint_name,
  tc.constraint_type,
  kcu.column_name,
  ccu.table_name AS referenced_table,
  ccu.column_name AS referenced_column,
  cc.check_clause
FROM information_schema.table_constraints tc
LEFT JOIN information_schema.key_column_usage kcu
  ON tc.constraint_schema = kcu.constraint_schema
 AND tc.constraint_name = kcu.constraint_name
 AND tc.table_name = kcu.table_name
LEFT JOIN information_schema.constraint_column_usage ccu
  ON tc.constraint_schema = ccu.constraint_schema
 AND tc.constraint_name = ccu.constraint_name
LEFT JOIN information_schema.check_constraints cc
  ON tc.constraint_schema = cc.constraint_schema
 AND tc.constraint_name = cc.constraint_name
WHERE tc.constraint_schema = 'public'
  AND tc.table_name = 'farm_payments'
ORDER BY tc.constraint_type, tc.constraint_name, kcu.ordinal_position;

-- 4) Politiques du stockage privé des justificatifs
SELECT
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual AS using_expression,
  with_check
FROM pg_policies
WHERE schemaname = 'storage'
  AND tablename = 'objects'
ORDER BY policyname;

-- 5) Configuration du bucket de justificatifs (sans lire les fichiers)
SELECT id, name, public, file_size_limit, allowed_mime_types
FROM storage.buckets
WHERE id = 'farm-private-proofs';

-- 6) Définition des fonctions de contrôle des rôles si elles existent
SELECT
  p.proname AS function_name,
  pg_get_function_identity_arguments(p.oid) AS arguments,
  p.prosecdef AS security_definer,
  pg_get_functiondef(p.oid) AS definition
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname IN ('has_farm_role', 'is_farm_admin', 'is_farm_member')
ORDER BY p.proname;


-- 7) Propriétaire et droits EXECUTE des fonctions de sécurité
SELECT
  p.proname AS function_name,
  pg_get_userbyid(p.proowner) AS function_owner,
  p.prosecdef AS security_definer,
  p.proconfig AS function_settings,
  has_function_privilege('anon', p.oid, 'EXECUTE') AS anon_can_execute,
  has_function_privilege('authenticated', p.oid, 'EXECUTE') AS authenticated_can_execute,
  has_function_privilege('service_role', p.oid, 'EXECUTE') AS service_role_can_execute
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname IN ('has_farm_role', 'is_farm_admin', 'is_farm_member')
ORDER BY p.proname;

-- 8) Privilèges SQL directs sur les tables financières
SELECT
  grantee,
  table_name,
  privilege_type,
  is_grantable
FROM information_schema.role_table_grants
WHERE table_schema = 'public'
  AND table_name IN ('farm_sales', 'farm_expenses', 'farm_payments')
  AND grantee IN ('anon', 'authenticated', 'service_role')
ORDER BY table_name, grantee, privilege_type;
