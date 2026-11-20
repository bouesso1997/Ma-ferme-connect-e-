# Audit sécurité — accès à l'interface et comptes

Branche auditée : `travail-v30-3-reprise`
Fichier observé : `index.html`
Nature : inspection statique du code, sans connexion au projet Supabase.

## Constatations vérifiées

1. Les panneaux Animaux, Santé, Alimentation, Stocks, Ventes, Finances, Caméras, Automatisation, Tâches, Équipe et Paramètres sont présents dans le document HTML.
2. La navigation par `data-page` et la fonction `go(id)` changent l'affichage des panneaux côté navigateur.
3. Le code de connexion Supabase vérifie actuellement uniquement l'association d'un membre actif dont le rôle est `admin`.
4. Le registre du personnel est enregistré dans les données locales. Il ne crée pas d'utilisateur Supabase.
5. Les données métier sont chargées depuis `localStorage`; les opérations de synchronisation générale restent désactivées dans cette copie.
6. Les contrôles visuels de navigation ne constituent pas une protection des données : un masquage dans JavaScript ne remplace jamais les politiques RLS du serveur.
7. La page ne doit donc pas être présentée comme un espace privé multi-utilisateur ou comme une application déjà sécurisée pour les données financières.

## Décisions de conception à conserver

| Fonction | Administrateur | Secrétariat | Responsable |
|---|---|---|---|
| Consulter les ventes et justificatifs | Oui | Oui | Oui |
| Créer une vente à soumettre | Oui | Oui | Selon autorisation à définir |
| Approuver une vente | Oui | Non | Non |
| Modifier/supprimer une vente approuvée | Oui, avec journal d'audit | Non | Non |
| Consulter les dépenses et rentabilité | Oui | À confirmer | Non par défaut |
| Modifier/supprimer les dépenses | Oui | Non par défaut | Non |
| Gérer les membres et rôles | Oui | Non | Non |
| Gérer animaux, stocks et tâches | Oui | Selon permissions attribuées | Oui, selon périmètre |

Les droits indiqués « à confirmer » doivent être décidés avant mise en production. Les restrictions doivent être appliquées côté base de données, pas uniquement dans l'interface.

## Conditions avant activation des rôles non-admin

- Confirmer le schéma réel de `farm_members`, les valeurs de rôle et les statuts.
- Examiner les politiques RLS sur `farm_members`, ventes, dépenses, animaux, stocks, tâches, santé et stockage privé.
- Vérifier les fonctions SQL qui contrôlent les rôles et leurs privilèges.
- Définir une procédure d'invitation individuelle ; aucun mot de passe partagé ou stocké dans le registre.
- Construire une matrice de tests avec trois comptes distincts et un compte non membre.
- Tester les refus d'accès directement via l'API, pas seulement en cachant les boutons.
- Vérifier qu'un secrétariat ne peut ni approuver une vente ni modifier/supprimer les justificatifs si cette règle est retenue.
- Vérifier qu'un responsable ne peut pas consulter les données financières si son rôle ne l'autorise pas.
- Vérifier qu'un utilisateur désactivé perd immédiatement l'accès.

## Limite actuelle

Aucun compte réel, politique RLS, fonction SQL ou table n'a été modifié dans le cadre de cet audit. Aucune requête n'a été exécutée sur Supabase. Le diagnostic lecture seule `diagnostic-comptes-roles.sql` doit être examiné avant de préparer une migration.
