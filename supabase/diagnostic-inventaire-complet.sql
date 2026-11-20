-- Ma Ferme Connectée — inventaire technique complet
-- DIAGNOSTIC STRICTEMENT EN LECTURE SEULE.
-- Aucune création, modification ou suppression de données, tables, fonctions ou politiques.
-- À exécuter uniquement dans le SQL Editor du projet Supabase de TEST.
-- Ne pas transmettre de mots de passe, jetons, clés privées, e-mails ou données personnelles.

-- 1) Présence des tables métier attendues
with expected(table_name) as (
  values
    ('farm_members'),
    ('farm_records'),
    ('farm_animals'),
    ('farm_stocks'),
    ('farm_sales'),
    ('farm_expenses'),
    ('farm_tasks'),
    ('farm_health'),
    ('audit_events')
)
select e.table_name,
       case when c.oid is null then 'ABSENTE' else 'PRÉSENTE' end as status,
       coalesce(c.relrowsecurity, false) as rls_enabled,
       coalesce(c.relforcerowsecurity, false) as rls_forced
from expected e
left join pg_namespace n on n.nspname = 'public'
left join pg_class c on c.relnamespace = n.oid
                    and c.relname = e.table_name
                    and c.relkind in ('r', 'p')
order by e.table_name;

-- 2) Colonnes, types, nullabilité et valeurs par défaut
select table_name, ordinal_position, column_name, data_type,
       is_nullable, column_default
from information_schema.columns
where table_schema = 'public'
  and table_name in (
    'farm_members', 'farm_records', 'farm_animals', 'farm_stocks',
    'farm_sales', 'farm_expenses', 'farm_tasks', 'farm_health', 'audit_events'
  )
order by table_name, ordinal_position;

-- 3) Contraintes : clés primaires/étrangères, unicité et contrôles
select c.relname as table_name, con.conname as constraint_name,
       con.contype as constraint_type,
       pg_get_constraintdef(con.oid) as definition
from pg_constraint con
join pg_class c on c.oid = con.conrelid
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relname in (
    'farm_members', 'farm_records', 'farm_animals', 'farm_stocks',
    'farm_sales', 'farm_expenses', 'farm_tasks', 'farm_health', 'audit_events'
  )
order by c.relname, con.conname;

-- 4) Index existants
select t.relname as table_name, i.relname as index_name,
       ix.indisprimary as is_primary,
       ix.indisunique as is_unique,
       pg_get_indexdef(i.oid) as definition
from pg_index ix
join pg_class t on t.oid = ix.indrelid
join pg_class i on i.oid = ix.indexrelid
join pg_namespace n on n.oid = t.relnamespace
where n.nspname = 'public'
  and t.relname in (
    'farm_members', 'farm_records', 'farm_animals', 'farm_stocks',
    'farm_sales', 'farm_expenses', 'farm_tasks', 'farm_health', 'audit_events'
  )
order by t.relname, i.relname;

-- 5) Politiques RLS existantes
select schemaname, tablename, policyname, permissive, roles,
       cmd, qual, with_check
from pg_policies
where schemaname = 'public'
  and tablename in (
    'farm_members', 'farm_records', 'farm_animals', 'farm_stocks',
    'farm_sales', 'farm_expenses', 'farm_tasks', 'farm_health', 'audit_events'
  )
order by tablename, policyname;

-- 6) Fonctions de sécurité et fonctions métier liées à la ferme
select n.nspname as schema_name, p.proname as function_name,
       pg_get_function_identity_arguments(p.oid) as arguments,
       p.prosecdef as security_definer,
       pg_get_functiondef(p.oid) as definition
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and (
    p.proname in ('has_farm_role', 'is_farm_admin', 'is_farm_member')
    or p.proname ilike '%farm%'
    or p.proname ilike '%sale%'
  )
order by p.proname, arguments;

-- 7) Déclencheurs sur les tables métier
select c.relname as table_name, t.tgname as trigger_name,
       pg_get_triggerdef(t.oid) as definition
from pg_trigger t
join pg_class c on c.oid = t.tgrelid
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and not t.tgisinternal
  and c.relname in (
    'farm_members', 'farm_records', 'farm_animals', 'farm_stocks',
    'farm_sales', 'farm_expenses', 'farm_tasks', 'farm_health', 'audit_events'
  )
order by c.relname, t.tgname;

-- 8) Résumé des volumes par table (nombre de lignes uniquement)
-- Les comptages sont globaux à chaque table ; ils n'affichent aucun contenu métier.
select 'farm_members' as table_name, count(*) as row_count from public.farm_members
union all select 'farm_records', count(*) from public.farm_records
union all select 'farm_animals', count(*) from public.farm_animals
union all select 'farm_stocks', count(*) from public.farm_stocks
union all select 'farm_sales', count(*) from public.farm_sales
union all select 'farm_expenses', count(*) from public.farm_expenses
union all select 'farm_tasks', count(*) from public.farm_tasks
union all select 'farm_health', count(*) from public.farm_health
union all select 'audit_events', count(*) from public.audit_events
order by table_name;

-- FIN : ce script ne doit produire que des résultats de lecture.
