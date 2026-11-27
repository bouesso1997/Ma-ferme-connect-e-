-- Ma Ferme Connectée
-- Audit RLS opérationnel : diagnostic strictement en lecture seule.
-- À exécuter dans Supabase > SQL Editor.
-- Aucune donnée ni configuration n'est modifiée.

-- 1) Tables métier présentes et état RLS (y compris les tables de reproduction).
SELECT
  c.relname AS table_name,
  c.relkind AS relation_type,
  c.relrowsecurity AS rls_enabled,
  c.relforcerowsecurity AS rls_forced
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND (c.relname LIKE 'farm_%' OR c.relname = 'audit_events')
  AND c.relkind IN ('r', 'p')
ORDER BY c.relname;

-- 2) Toutes les politiques RLS des tables métier.
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
  AND (tablename LIKE 'farm_%' OR tablename = 'audit_events')
ORDER BY tablename, policyname;

-- 3) Contraintes CHECK et clés étrangères métier.
SELECT
  c.relname AS table_name,
  con.conname AS constraint_name,
  CASE con.contype
    WHEN 'c' THEN 'CHECK'
    WHEN 'f' THEN 'FOREIGN KEY'
    WHEN 'u' THEN 'UNIQUE'
    WHEN 'p' THEN 'PRIMARY KEY'
    ELSE con.contype::text
  END AS constraint_type,
  pg_get_constraintdef(con.oid) AS definition
FROM pg_constraint con
JOIN pg_class c ON c.oid = con.conrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND (c.relname LIKE 'farm_%' OR c.relname = 'audit_events')
  AND con.contype IN ('c', 'f', 'u', 'p')
ORDER BY c.relname, constraint_type, con.conname;

-- 4) Privilèges SQL accordés aux rôles applicatifs.
SELECT
  table_name,
  grantee,
  privilege_type
FROM information_schema.role_table_grants
WHERE table_schema = 'public'
  AND table_name LIKE 'farm_%'
  AND grantee IN ('anon', 'authenticated', 'service_role')
ORDER BY table_name, grantee, privilege_type;

-- 5) Fonctions de sécurité liées aux rôles et à la ferme.
SELECT
  p.proname AS function_name,
  pg_get_function_identity_arguments(p.oid) AS arguments,
  p.prosecdef AS security_definer,
  p.provolatile AS volatility,
  has_function_privilege('anon', p.oid, 'EXECUTE') AS anon_can_execute,
  has_function_privilege('authenticated', p.oid, 'EXECUTE') AS authenticated_can_execute
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND (
    p.proname IN ('has_farm_role', 'is_farm_admin', 'is_farm_member')
    OR p.proname LIKE '%farm%'
  )
ORDER BY p.proname, arguments;
