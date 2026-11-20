# Étape suivante — sécurisation des ventes et justificatifs

Branche : `travail-v30-3-reprise`

## Objectif

Préparer une approbation des ventes réellement contrôlée par Supabase, et non par une variable JavaScript modifiable dans le navigateur. Le diagnostic complémentaire ne change aucune donnée.

## Diagnostic à exécuter

1. Ouvrir le projet Supabase de TEST, puis SQL Editor.
2. Ouvrir le fichier [diagnostic-ventes-securite.sql](./diagnostic-ventes-securite.sql) et exécuter son contenu.
3. Ouvrir le fichier [diagnostic-ventes-stockage.sql](./diagnostic-ventes-stockage.sql) et exécuter son contenu.
4. Copier les résultats des deux exécutions dans la conversation, ou joindre des captures lisibles.

Ces deux scripts sont en lecture seule : ils interrogent les métadonnées des tables, politiques, fonctions, privilèges, types et bucket. Ils ne créent, ne modifient et ne suppriment rien.

Ne transmettre aucun mot de passe, jeton, clé privée, adresse e-mail, contenu de justificatif ou donnée personnelle. Les résultats demandés portent sur la structure et les règles d'accès, pas sur les ventes individuelles.

## Ce qui sera vérifié

- Structure réelle de `farm_sales`, `farm_members` et `farm_records`.
- RLS activé et politiques réellement présentes.
- Rôle actif et fonctions de contrôle existantes.
- Existence du bucket privé `farm-private-proofs`.
- Politiques de lecture et d'ajout des justificatifs.
- Fonctions d'approbation ou d'audit déjà présentes, et leurs privilèges d'exécution.
- Triggers et types de statut déjà définis.

## Règles fonctionnelles à appliquer

| Action | Administrateur | Secrétariat | Responsable |
|---|---:|---:|---:|
| Consulter les ventes autorisées | Oui | À confirmer | À confirmer |
| Saisir une vente | Oui | À confirmer | À confirmer |
| Approuver ou refuser une vente | Oui | Non | Non |
| Consulter les justificatifs | Oui | Oui | Oui |
| Ajouter/remplacer/supprimer un justificatif | Oui | Non | Non |

La consultation des justificatifs par les trois rôles est une exigence déjà exprimée. Les autres droits marqués « À confirmer » ne seront pas inventés.

## Après réception des résultats

1. Comparer le schéma réel avec les tables déjà utilisées pour éviter les doublons.
2. Écrire une migration adaptée aux colonnes et contraintes constatées.
3. Prévoir une fonction serveur qui vérifie l'appartenance active à la ferme et le rôle administrateur, puis inscrit l'approbateur et l'horodatage dans le journal.
4. Verrouiller les mises à jour directes du statut par les clients et appliquer les politiques RLS correspondantes.
5. Tester avec trois comptes fictifs (admin, secrétariat, responsable), puis vérifier les refus d'accès.
6. Ne déployer qu'après tests concluants et sauvegarde vérifiée.

## État

- Aucun SQL de migration exécuté.
- Aucune donnée Supabase modifiée.
- Aucune activation de l'approbation côté application.
- Les boutons de synchronisation risquée restent désactivés.
- Les ventes locales non approuvées ne sont pas comptées dans les recettes validées.

**Important :** ne pas exécuter de script de migration avant lecture des diagnostics. Les noms de colonnes et les rôles réels doivent être confirmés par la base de test.
