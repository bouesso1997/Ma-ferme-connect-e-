-- Ma Ferme Connectée — diagnostic complet sécurité ventes, membres et justificatifs
-- STRICTEMENT EN LECTURE SEULE : aucune donnée métier n'est lue ou modifiée.
-- À exécuter uniquement dans le SQL Editor du projet Supabase de TEST.
-- Ne transmettre ni e-mail, ni user_id, ni jeton, ni justificatif.
-- Ce script ne crée, ne modifie et ne supprime aucun objet.

-- 1) Présence des tables et état RLS.
with expected(table_name) as (
  values ('farm_members'), ('farm_sales'), ('farm_records'), ('audit_events')
)
select e.table_name,
       case when c.oid is null then 'ABSENTE' else 'PRÉSENTE' end as status,
       coalesce(c.relrowsecurity, false) as rls_enabled,
       coalesce(c.relforcerowsecurity, false) as rls_forced
from expected e
left join pg_namespace n on n.nspname = 'public'
left join pg_class c on c.relnamespace = n.oid and c.relname = e.table_name
                    and c.relkind in ('r','p')
order by e.table_name;

-- 2) Colonnes et types.
select table_name, ordinal_position, column_name, data_type, is_nullable, column_default
from information_schema.columns
where table_schema = 'public'
  and table_name in ('farm_members','farm_sales','farm_records','audit_events')
order by table_name, ordinal_position;

-- 3) Contraintes et clés.
select c.relname as table_name, con.conname as constraint_name,
       con.contype as constraint_type, pg_get_constraintdef(con.oid) as definition
from pg_constraint con
join pg_class c on c.oid = con.conrelid
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relname in ('farm_members','farm_sales','farm_records','audit_events')
order by c.relname, con.conname;

-- 4) Totaux des membres de la ferme de TEST, sans identité personnelle.
select coalesce(role::text,'(rôle vide)') as role,
       coalesce(active::text,'(statut vide)') as active,
       count(*) as nombre
from public.farm_members
where farm_id = '949e02de-01fb-46ce-8d87-68afb08e872d'
group by role, active
order by role::text, active::text;

-- 5) Politiques RLS des tables métier et du stockage.
select schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
from pg_policies
where (schemaname = 'public' and tablename in ('farm_members','farm_sales','farm_records','audit_events'))
   or (schemaname = 'storage' and tablename = 'objects')
order by schemaname, tablename, policyname;

-- 6) Fonctions de contrôle, vente, approbation, audit et membres.
select n.nspname as schema_name, p.proname as function_name,
       pg_get_function_identity_arguments(p.oid) as arguments,
       p.prosecdef as security_definer,
       coalesce(array_to_string(p.proconfig, '; '),'') as function_settings,
       pg_get_functiondef(p.oid) as definition
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.prokind = 'f'
  and (p.proname in ('has_farm_role','is_farm_admin','is_farm_member')
       or p.proname ilike '%sale%' or p.proname ilike '%approv%'
       or p.proname ilike '%audit%' or p.proname ilike '%member%')
order by p.proname, pg_get_function_identity_arguments(p.oid);

-- 7) Droits EXECUTE sur les fonctions liées aux ventes et aux rôles.
select routine_schema, routine_name, specific_name, grantee, privilege_type, is_grantable
from information_schema.routine_privileges
where routine_schema = 'public'
  and (routine_name ilike '%sale%' or routine_name ilike '%approv%'
       or routine_name in ('has_farm_role','is_farm_admin','is_farm_member'))
order by routine_name, grantee;

-- 8) Triggers liés aux ventes, membres et audit.
select event_object_schema, event_object_table, trigger_name,
       action_timing, event_manipulation, action_statement
from information_schema.triggers
where event_object_schema = 'public'
  and event_object_table in ('farm_sales','farm_members','farm_records','audit_events')
order by event_object_table, trigger_name, event_manipulation;

-- 9) Métadonnées du bucket privé des justificatifs.
select id, name, public, file_size_limit, allowed_mime_types
from storage.buckets
where id = 'farm-private-proofs' or name = 'farm-private-proofs';

-- FIN : SELECT uniquement. Aucun contenu de vente ou de justificatif n'est extrait.
