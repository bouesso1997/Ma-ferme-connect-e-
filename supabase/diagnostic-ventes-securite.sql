-- Ma Ferme Connectée — diagnostic pré-validation des ventes
-- SCRIPT STRICTEMENT EN LECTURE SEULE : aucune création, modification ou suppression.
-- À exécuter dans Supabase SQL Editor sur le projet de TEST, puis partager le résultat
-- (sans e-mail, identifiant utilisateur ni jeton d'accès).

-- 1) Colonnes des tables concernées
select table_name, ordinal_position, column_name, data_type, is_nullable, column_default
from information_schema.columns
where table_schema = 'public'
  and table_name in ('farm_sales', 'farm_members', 'farm_records')
order by table_name, ordinal_position;

-- 2) Contraintes déclarées sur les ventes et les membres
select c.relname as table_name, con.conname as constraint_name,
       con.contype as constraint_type, pg_get_constraintdef(con.oid) as definition
from pg_constraint con
join pg_class c on c.oid = con.conrelid
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relname in ('farm_sales', 'farm_members', 'farm_records')
order by c.relname, con.conname;

-- 3) Activation de RLS et politiques existantes
select c.relname as table_name, c.relrowsecurity as rls_enabled,
       c.relforcerowsecurity as rls_forced
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relkind = 'r'
  and c.relname in ('farm_sales', 'farm_members', 'farm_records')
order by c.relname;

select schemaname, tablename, policyname, permissive, roles,
       cmd, qual, with_check
from pg_policies
where schemaname = 'public'
  and tablename in ('farm_sales', 'farm_members', 'farm_records')
order by tablename, policyname;

-- 4) Fonctions de droits présentes (signature et définition)
select n.nspname as schema_name, p.proname as function_name,
       pg_get_function_identity_arguments(p.oid) as arguments,
       pg_get_functiondef(p.oid) as definition
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in ('has_farm_role', 'is_farm_admin', 'is_farm_member')
order by p.proname;

-- 5) État de présence des tables (sans lire les données métier)
select t.table_name,
       case when c.oid is null then 'ABSENTE' else 'PRÉSENTE' end as status
from (values ('farm_sales'), ('farm_members'), ('farm_records')) as t(table_name)
left join pg_class c on c.relname = t.table_name
left join pg_namespace n on n.oid = c.relnamespace and n.nspname = 'public'
order by t.table_name;
