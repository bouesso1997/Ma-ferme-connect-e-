# Ma Ferme Connectée — plan de migration Supabase sécurisé

> Plan préparatoire uniquement. Ce document n'est pas du SQL exécutable. Aucune table, politique RLS, donnée ou configuration Supabase n'est modifiée.

## État de départ vérifié

- Branche de travail : `amelioration/statut-animaux`.
- Le fichier `index.html` indique l'interface V24.
- Aucun fichier `schema.sql` n'a été trouvé à la racine de cette branche.
- Les règles métier des ventes et tâches sont documentées dans `MODELE_SERVEUR_VENTES_TACHES.md`.
- Les ventes et tâches de l'interface actuelle sont encore principalement locales. La validation locale d'une vente n'est pas une validation serveur.
- La synchronisation générale ne doit pas être activée pendant cette préparation.

## Cible serveur

### 1. Ventes

Table dédiée `farm_sales`, une ligne par vente, avec ferme, animal/lot, date, acheteur, poids, montant, statut, créateur et horodatages.

- Secrétariat : créer et modifier uniquement les ventes en attente.
- Responsable : consulter les ventes uniquement.
- Administrateur : consulter, corriger selon procédure auditée et approuver.
- Employé : aucun accès.
- L'approbation passe par une fonction serveur contrôlée ; le navigateur ne peut pas écrire directement le statut approuvé ni les champs d'audit.

### 2. Justificatifs de paiement

Les fichiers sont stockés dans un espace privé séparé, pas dans une URL publique ni en clair dans une colonne.

- Administrateur, secrétariat et responsable : consultation via autorisation serveur et liens temporaires.
- Secrétariat et responsable : aucune modification ni suppression.
- Administrateur : modification ou suppression uniquement par une opération contrôlée et journalisée.
- Employé : aucun accès.

### 3. Tâches

Table dédiée `farm_tasks`, avec un identifiant de membre assigné (UUID Supabase Auth), créateur, échéance, priorité et état.

- Administrateur et responsable : créer, attribuer et superviser les tâches, y compris celles du secrétariat.
- Secrétariat et employé : consulter uniquement les tâches qui leur sont attribuées, les terminer et joindre une note/photo de réalisation.
- Les personnes assignées ne peuvent pas modifier l'affectation, l'échéance ou la priorité.
- Les photos sont privées et leur accès est contrôlé.

## Dépendance obligatoire : comptes des membres

Une fiche dans le registre local de l'équipe ne constitue pas un compte Supabase Auth. Avant de tester les droits par rôle, chaque personne concernée doit disposer d'un compte individuel relié à `farm_members.user_id`, avec une adhésion active à la bonne ferme et un rôle attribué par l'administrateur.

Ne jamais partager un même compte entre plusieurs employés. Ne jamais stocker les mots de passe dans les tables de la ferme.

## Étapes de réalisation

1. Confirmer les comptes individuels nécessaires et leur attribution de rôle.
2. Vérifier la structure réelle des tables, contraintes, fonctions et politiques Supabase existantes avant d'écrire une migration.
3. Préparer une migration SQL additive et réversible pour les nouvelles tables, fonctions, stockage privé et politiques.
4. Relire le SQL et les tests avant toute exécution.
5. Exécuter d'abord dans un environnement de test ou avec des données fictives.
6. Tester chaque rôle, y compris les refus : secrétaire qui tente d'approuver, responsable qui tente de créer, employé qui tente de lire une vente ou la tâche d'un autre, secrétaire/responsable qui tentent de modifier ou supprimer un justificatif.
7. Vérifier sauvegarde, restauration et rapprochement avant tout import des anciennes ventes/tâches.
8. Adapter l'interface progressivement ; ne pas activer la synchronisation générale tant que les tests ne sont pas concluants.

## Protection des données existantes

- Ne pas supprimer ni écraser les lignes de `farm_records`.
- Ne pas importer automatiquement les tableaux de `localStorage`.
- Ne pas supprimer les fermes en doublon sans audit explicite.
- Conserver V12 comme sauvegarde de référence.
- Ne pas fusionner la branche, publier ou déployer sans accord explicite.

## État

Aucune migration SQL n'a été exécutée. Aucune donnée Supabase n'a été modifiée. Ce plan doit être suivi d'une inspection en lecture seule du schéma Supabase avant toute proposition de SQL.


## Complément du diagnostic Supabase (4 novembre 2026)

Résultats communiqués depuis le SQL Editor :

- RLS activé et non forcé sur `farms`, `farm_members` et `farm_records`.
- `farm_sales`, `farm_tasks` et `audit_events` n'existent pas encore.
- Aucun bucket n'a été retourné par `storage.buckets`.
- Aucune politique n'a été retournée pour `storage.objects`.
- `has_farm_role(uuid,text[])` est exécutable par `anon` ; `is_farm_admin(uuid)` et `is_farm_member(uuid)` ne le sont pas.
- Les politiques actuelles de `farm_records` autorisent des accès par catégorie et ne suffisent pas pour appliquer les droits fins par vente ou par tâche.
- Les fonctions de contrôle existantes sont SECURITY DEFINER avec `search_path` vide.

## Brouillon SQL préparé

Fichier : `supabase/migrations/20261104000100_draft_sales_tasks_security.sql`.

Il contient une proposition additive pour les tables métier, l'audit, les fonctions contrôlées et un bucket privé. Une fonction dédiée a été ajoutée pour permettre au secrétariat de modifier une vente uniquement tant qu'elle est en attente.

**Ce fichier reste un brouillon non exécuté.** Il nécessite une revue technique avant toute exécution, notamment :
- vérifier les privilèges et politiques existants de `storage.objects` et de `public.farms` ;
- valider la convention des chemins de fichiers privés ;
- compléter les tests d'autorisation négatifs et vérifier la cohérence des fonctions SECURITY DEFINER ;
- confirmer la procédure d'ajout et de révocation des comptes Auth individuels ;
- tester sur un projet de test avec des comptes fictifs et une sauvegarde vérifiée.

Aucune donnée Supabase n'a été modifiée. Aucune fusion ni publication n'a été effectuée.
