# Diagnostic des comptes individuels et des rôles

Ce diagnostic est **strictement en lecture seule**. Il ne crée aucun compte et ne modifie aucune donnée ni politique.

## Étape à effectuer

1. Ouvrir le projet Supabase de TEST, puis le SQL Editor.
2. Ouvrir le fichier [diagnostic-comptes-roles.sql](./diagnostic-comptes-roles.sql) depuis la branche de travail.
3. Copier son contenu dans le SQL Editor et exécuter.
4. Partager ici les résultats des sept blocs de résultats, en masquant toute information personnelle si l'interface en affiche malgré tout.

Le diagnostic affiche seulement :
- le nombre de membres par rôle et statut actif ;
- l'état RLS de `farm_members` ;
- les politiques RLS de cette table ;
- les fonctions de contrôle de rôle existantes ;
- les colonnes, contraintes et valeurs ENUM qui encadrent les rôles ;
- les privilèges SQL accordés sur `farm_members`.

## Correspondance prévue dans l'application

| Profil affiché | Rôle technique Supabase attendu |
|---|---|
| Administrateur | `admin` |
| Secrétariat | `secretariat` |
| Responsable | `manager` |

Le registre du personnel dans l'application n'est pas un système de création de comptes. Il ne faut pas donner accès à quelqu'un en changeant seulement le rôle dans l'interface : l'identité doit être créée par le mécanisme sécurisé Supabase, puis associée à la ferme avec des politiques RLS adaptées.

## Après réception des résultats

La prochaine étape sera de préparer les invitations individuelles et les permissions réelles. Aucun changement de schéma, de compte ou de politique ne sera appliqué sans examen des résultats et autorisation explicite pour le projet de test.
