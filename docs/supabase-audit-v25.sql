-- Ma Ferme Connectée — audit Supabase en lecture seule
-- À exécuter dans Supabase > SQL Editor sur le projet de test.
-- Ces requêtes ne modifient aucune table, donnée, fonction ni politique.

-- 1) Colonnes et types des tables utilisées par l'application
select table_schema, table_name, ordinal_position, column_name, data_type,
       udt_name, is_nullable, column_default
from information_schema.columns
where table_schema = 'public'
  and table_name in ('farm_members', 'farm_records')
order by table_name, ordinal_position;

-- 2) Clés, contraintes et règles CHECK des deux tables
select tc.table_name, tc.constraint_name, tc.constraint_type,
       kcu.column_name, ccu.table_name as foreign_table,
       ccu.column_name as foreign_column, checkc.check_clause
from information_schema.table_constraints tc
left join information_schema.key_column_usage kcu
  on tc.constraint_schema = kcu.constraint_schema
 and tc.constraint_name = kcu.constraint_name
left join information_schema.constraint_column_usage ccu
  on tc.constraint_schema = ccu.constraint_schema
 and tc.constraint_name = ccu.constraint_name
left join information_schema.check_constraints checkc
  on tc.constraint_schema = checkc.constraint_schema
 and tc.constraint_name = checkc.constraint_name
where tc.table_schema = 'public'
  and tc.table_name in ('farm_members', 'farm_records')
order by tc.table_name, tc.constraint_type, tc.constraint_name;

-- 3) État RLS et politiques actuellement en place
select n.nspname as schema_name, c.relname as table_name,
       c.relrowsecurity as rls_enabled,
       c.relforcerowsecurity as rls_forced
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relname in ('farm_members', 'farm_records');

select schemaname, tablename, policyname, permissive, roles,
       cmd, qual, with_check
from pg_policies
where schemaname = 'public'
  and tablename in ('farm_members', 'farm_records')
order by tablename, policyname;

-- 4) Triggers et fonctions attachés à ces tables
select event_object_table, trigger_name, action_timing,
       event_manipulation, action_statement
from information_schema.triggers
where trigger_schema = 'public'
  and event_object_table in ('farm_members', 'farm_records')
order by event_object_table, trigger_name;

select n.nspname as schema_name, p.proname as function_name,
       pg_get_function_identity_arguments(p.oid) as arguments,
       pg_get_functiondef(p.oid) as definition
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and (p.proname ilike '%farm%' or p.proname ilike '%record%' or p.proname ilike '%member%')
order by p.proname;

-- 5) Valeurs de rôles/catégories déjà présentes (sans exposer les payloads)
select role, active, count(*) as member_count
from public.farm_members
group by role, active
order by role, active;

select category, count(*) as record_rows
from public.farm_records
group by category
order by category;

-- IMPORTANT : ne partagez jamais votre mot de passe ni une clé secrète.
-- Vous pouvez copier ici les résultats de ces requêtes ; masquez les e-mails si présents.
