-- Ma Ferme Connectée — diagnostic des comptes et rôles
-- STRICTEMENT EN LECTURE SEULE : aucune création, modification ou suppression.
-- À exécuter uniquement dans le SQL Editor du projet Supabase de TEST.
-- Ne retourne aucun email, nom, user_id ni identifiant personnel.

-- 1) Répartition des membres de la ferme par rôle et statut.
select
  coalesce(role::text, '(rôle vide)') as role,
  coalesce(active::text, '(statut vide)') as active,
  count(*) as nombre
from public.farm_members
where farm_id = '949e02de-01fb-46ce-8d87-68afb08e872d'
group by role, active
order by role::text, active::text;

-- 2) Vérifier que RLS est activé sur farm_members.
select
  c.relname as table_name,
  c.relrowsecurity as rls_enabled,
  c.relforcerowsecurity as rls_forced
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relname = 'farm_members';

-- 3) Lister les politiques RLS de farm_members (sans données personnelles).
select
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
from pg_policies
where schemaname = 'public'
  and tablename = 'farm_members'
order by policyname;

-- 4) Vérifier les fonctions de contrôle de rôle présentes.
select
  p.proname as function_name,
  p.prosecdef as security_definer,
  pg_get_function_identity_arguments(p.oid) as arguments
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in ('has_farm_role', 'is_farm_admin', 'is_farm_member')
order by p.proname;
