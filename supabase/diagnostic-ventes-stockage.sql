-- Ma Ferme Connectée — diagnostic complémentaire ventes et justificatifs
-- STRICTEMENT EN LECTURE SEULE. À exécuter uniquement sur le projet Supabase de TEST.
-- Ne retourne ni contenu de justificatif, ni e-mail, ni identifiant personnel.

-- 1) Bucket de justificatifs : existence et visibilité publique
select id, name, public, file_size_limit, allowed_mime_types
from storage.buckets
where id = 'farm-private-proofs' or name = 'farm-private-proofs';

-- 2) Politiques appliquées aux objets du stockage
select schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
from pg_policies
where schemaname = 'storage'
  and tablename = 'objects'
order by policyname;

-- 3) Fonctions de vente déjà présentes (nom, signature, sécurité, droits)
select n.nspname as schema_name,
       p.proname as function_name,
       pg_get_function_identity_arguments(p.oid) as arguments,
       p.prosecdef as security_definer,
       p.provolatile as volatility,
       pg_get_userbyid(p.proowner) as owner,
       coalesce(array_to_string(p.proconfig, '; '), '') as function_settings
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and (
    p.proname ilike '%sale%'
    or p.proname ilike '%vent%'
    or p.proname ilike '%approv%'
    or p.proname ilike '%audit%'
  )
order by p.proname, pg_get_function_identity_arguments(p.oid);

-- 4) Privilèges d'exécution sur les fonctions de vente trouvées
select routine_schema, routine_name, specific_name,
       grantee, privilege_type, is_grantable
from information_schema.routine_privileges
where routine_schema = 'public'
  and (
    routine_name ilike '%sale%'
    or routine_name ilike '%vent%'
    or routine_name ilike '%approv%'
  )
order by routine_name, grantee;

-- 5) Types enum et valeurs éventuelles liés aux ventes/statuts
select n.nspname as schema_name, t.typname as type_name,
       e.enumsortorder, e.enumlabel
from pg_type t
join pg_namespace n on n.oid = t.typnamespace
join pg_enum e on e.enumtypid = t.oid
where n.nspname = 'public'
  and (t.typname ilike '%sale%' or t.typname ilike '%vent%' or t.typname ilike '%status%')
order by t.typname, e.enumsortorder;

-- 6) Triggers existants sur les tables de ventes et d'audit
select event_object_table as table_name, trigger_name,
       action_timing, event_manipulation, action_statement
from information_schema.triggers
where trigger_schema = 'public'
  and event_object_table in ('farm_sales', 'farm_records', 'audit_events')
order by event_object_table, trigger_name, event_manipulation;
