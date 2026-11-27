-- Diagnostic en lecture seule : structure et sécurité des tables financières
-- À exécuter dans Supabase > SQL Editor.
-- Cette requête ne crée, ne modifie et ne supprime aucune donnée.

-- 1) Colonnes et types des tables financières existantes
SELECT
  c.table_name,
  c.ordinal_position,
  c.column_name,
  c.data_type,
  c.udt_name,
  c.is_nullable,
  c.column_default
FROM information_schema.columns AS c
WHERE c.table_schema = 'public'
  AND c.table_name IN ('farm_sales', 'farm_expenses', 'farm_payments')
ORDER BY c.table_name, c.ordinal_position;

-- 2) Activation de RLS sur ces tables
SELECT
  t.tablename,
  t.rowsecurity AS rls_enabled,
  t.forcerowsecurity AS rls_forced
FROM pg_tables AS p
JOIN pg_class AS t ON t.relname = p.tablename
JOIN pg_namespace AS n ON n.oid = t.relnamespace
WHERE p.schemaname = 'public'
  AND t.relnamespace = 'public'::regnamespace
  AND t.relname IN ('farm_sales', 'farm_expenses', 'farm_payments')
ORDER BY t.relname;

-- 3) Politiques RLS actuellement en place
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
  AND tablename IN ('farm_sales', 'farm_expenses', 'farm_payments')
ORDER BY tablename, policyname;

-- 4) Clés primaires, contraintes uniques et clés étrangères
SELECT
  tc.table_name,
  tc.constraint_name,
  tc.constraint_type,
  kcu.column_name,
  ccu.table_name AS foreign_table_name,
  ccu.column_name AS foreign_column_name
FROM information_schema.table_constraints AS tc
LEFT JOIN information_schema.key_column_usage AS kcu
  ON tc.constraint_schema = kcu.constraint_schema
 AND tc.table_name = kcu.table_name
 AND tc.constraint_name = kcu.constraint_name
LEFT JOIN information_schema.constraint_column_usage AS ccu
  ON tc.constraint_schema = ccu.constraint_schema
 AND tc.table_name = ccu.table_name
 AND tc.constraint_name = ccu.constraint_name
WHERE tc.constraint_schema = 'public'
  AND tc.table_name IN ('farm_sales', 'farm_expenses', 'farm_payments')
ORDER BY tc.table_name, tc.constraint_name, kcu.ordinal_position;
