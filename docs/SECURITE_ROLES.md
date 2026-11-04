# Ma Ferme Connectée — cadrage des rôles et de la sécurité

> Document de conception uniquement. Il ne modifie ni Supabase, ni les données de la ferme, ni les règles RLS, ni le comportement de l'application.

## Constat sur la version actuelle

- La connexion Supabase de l'interface vérifie uniquement un membre actif dont le rôle est `admin`.
- Les employés affichés dans le module Équipe sont des fiches locales. Leur création ne crée pas de compte Supabase Auth.
- Les ventes, tâches, dépenses et autres catégories sont conservées localement sous forme de tableaux dans `localStorage`.
- Les lignes de `farm_records` stockent un tableau complet dans `payload` (JSONB). Une politique RLS par catégorie ne peut donc pas sécuriser individuellement une vente, une tâche ou un champ de ce tableau.
- Le bouton « Marquer validée » modifie actuellement le statut localement : ce n'est pas une approbation serveur.
- La synchronisation générale reste désactivée. Le chargement général peut remplacer les données locales ; il ne doit pas être utilisé sans sauvegarde et procédure de rapprochement vérifiée.

## Matrice fonctionnelle cible à valider

| Module / action | Administrateur | Responsable | Secrétariat | Employé |
|---|---|---|---|---|
| Animaux | Lire / créer / modifier / supprimer | Lire / créer / modifier | Lecture | Accès limité aux tâches autorisées |
| Santé | Lire / créer / modifier / supprimer | Lire / créer / modifier | Aucun accès par défaut | Aucun accès par défaut |
| Stocks et rations | Lire / créer / modifier / supprimer | Lire / créer / modifier | Lecture éventuelle à confirmer | Aucun accès par défaut |
| Ventes | Toutes actions + validation finale | Lecture | Saisie et suivi, sans validation finale | Aucun accès |
| Dépenses et rentabilité | Toutes actions | Lecture seule | Aucun accès | Aucun accès |
| Tâches | Toutes actions et supervision | Créer / attribuer / suivre | Aucun accès par défaut | Lire et terminer uniquement les tâches attribuées |
| Équipe et comptes | Gérer les membres et leurs rôles | Suivi de l'équipe, sans attribution de droits | Aucun accès par défaut | Aucun accès |
| Exports PDF / sauvegardes | Tous les exports | Exports opérationnels limités | Exports des ventes autorisées | Aucun export global |

Les droits marqués « éventuel » ou « par défaut » nécessitent une validation métier avant développement.

## Principes techniques non négociables

1. L'identité d'un membre doit provenir de Supabase Auth et être reliée à `farm_members.user_id`. Une fiche d'employé locale ne constitue pas un compte.
2. Les rôles doivent être vérifiés côté serveur. Masquer un bouton dans l'interface n'est pas une protection.
3. Une vente doit être enregistrée comme opération distincte. Seul un endpoint/RPC serveur contrôlé doit pouvoir la faire passer à l'état approuvé, avec l'identité et l'horodatage de l'approbateur.
4. Une tâche doit porter un identifiant de membre assigné. Un employé ne doit pouvoir lire ou terminer que ses tâches autorisées.
5. Les dépenses et données de rentabilité doivent être protégées côté serveur, pas uniquement masquées dans le navigateur.
6. Les politiques RLS existantes sont permissives lorsqu'elles s'appliquent en OR. Toute évolution devra remplacer et tester l'ensemble cohérent des politiques concernées, pas simplement en ajouter une.
7. Aucun changement de politique, de table ou de donnée Supabase ne sera effectué avant validation du modèle et sauvegarde contrôlée.
8. La synchronisation devra utiliser des identifiants stables, des mises à jour ciblées et une stratégie de conflits. Aucun effacement global ou remplacement silencieux des données locales.

## Séquence de réalisation

1. Valider la matrice de droits et les cas limites.
2. Concevoir le modèle serveur des ventes, validations et tâches assignées.
3. Écrire des tests d'accès positifs et négatifs pour chaque rôle.
4. Préparer une migration SQL réversible et la faire relire avant toute exécution.
5. Adapter l'interface et la connexion à la réponse d'autorisation serveur.
6. Tester la synchronisation sur des données de test et vérifier les sauvegardes.
7. Proposer la fusion et la publication séparément, avec accord explicite.

## Hors périmètre de ce document

Aucune migration SQL n'est exécutée. Aucune donnée n'est lue, modifiée ou supprimée dans Supabase. Aucune fusion dans `main` et aucune publication ne sont effectuées.
