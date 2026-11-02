# Ma Ferme Connectée — rôles et sécurité (préparation V25)

Ce document fixe le comportement attendu avant activation des permissions en production. Il ne modifie pas Supabase et n'est pas une migration SQL exécutable.

## Rôles

| Fonction | Administrateur | Responsable | Secrétariat | Employé |
|---|---:|---:|---:|---:|
| Voir les animaux et leur historique | Oui | Oui | Lecture limitée | Animaux affectés |
| Créer / modifier une fiche animal | Oui | Oui | Non | Signalement uniquement |
| Préparer un mouvement / une vente | Oui | Oui | Saisie documentaire | Signaler |
| Valider définitivement une vente | Oui | Non | Non | Non |
| Consulter / gérer les stocks | Oui | Oui | Lecture limitée | Déclarer consommation |
| Préparer une dépense | Oui | Oui | Oui | Signaler un besoin |
| Approuver une dépense | Oui | Non | Non | Non |
| Consulter ventes, dépenses et rentabilité | Oui | Synthèse opérationnelle | Non | Non |
| Factures, reçus, PDF, rendez-vous | Oui | Lecture utile | Oui | Non |
| Gérer les comptes et les rôles | Oui | Non | Non | Non |
| Paramètres et sauvegardes | Oui | Non | Non | Non |

## Règles métier obligatoires

1. Chaque animal reçoit un identifiant unique et conserve son historique.
2. Un animal vendu ou décédé n'est jamais effacé : statut et date sont conservés.
3. Une vente suit les étapes brouillon → à valider → validée ou refusée.
4. Le responsable prépare une vente, mais seul l'administrateur la valide.
5. Une dépense suit le même principe. Le secrétariat saisit les justificatifs, sans pouvoir approuver.
6. Les entrées et sorties de stock sont des mouvements datés et attribués à un compte.
7. Une correction crée une écriture inverse ou une trace d'audit ; pas de suppression silencieuse.
8. Les changements de rôle, validations et opérations sensibles sont journalisés.
9. Les accès financiers sont refusés par défaut aux rôles secrétariat et employé.
10. Toute action sensible est vérifiée côté serveur par Supabase RLS ou une fonction serveur, pas seulement masquée dans l'interface.

## Schéma Supabase à confirmer avant migration

La version actuelle utilise notamment les tables farm_members et farm_records. Avant de modifier les politiques, relever précisément :
- colonnes, types et contraintes de farm_members et farm_records ;
- clés étrangères et contraintes de catégorie ;
- politiques RLS existantes pour SELECT, INSERT, UPDATE et DELETE ;
- fonctions SQL et triggers déjà installés ;
- valeurs exactes des rôles et correspondance des utilisateurs avec la ferme.

Ne pas exécuter une migration qui remplace les politiques existantes sans sauvegarde et test sur une copie. Les règles doivent filtrer chaque requête par farm_id et vérifier l'appartenance active de l'utilisateur.

## Plan de mise en œuvre et de test

1. Exporter le schéma et les politiques actuelles ; sauvegarder les données.
2. Définir les rôles canoniques : admin, manager, secretariat, employee.
3. Implémenter les contrôles serveur/RLS et tester chaque rôle avec des comptes distincts.
4. Ajouter les étapes de validation des ventes et dépenses, avec journal d'audit.
5. Connecter animaux, stocks, ventes, dépenses, santé et reproduction sans remplacer les données existantes.
6. Tester les refus d'accès, synchronisations et scénarios de reprise avant publication.

## Critères d'acceptation

- Un employé ne peut lire aucune donnée financière, même en appelant directement l'API.
- Le secrétariat ne peut valider une vente/dépense ni modifier la rentabilité.
- Le responsable ne peut valider seul les ventes ou dépenses sensibles.
- Un utilisateur d'une autre ferme ne peut lire ni modifier les données.
- La suppression d'un enregistrement sensible est refusée ou remplacée par une correction tracée.
- Les données des autres catégories restent intactes lors d'une synchronisation ciblée.
- La V12 et le site public restent inchangés tant que la publication n'est pas autorisée.
