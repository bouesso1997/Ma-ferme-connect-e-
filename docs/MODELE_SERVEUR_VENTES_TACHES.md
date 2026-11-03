# Ma Ferme Connectée — modèle serveur proposé pour ventes et tâches

> Proposition de conception uniquement. Ce fichier n'est pas une migration SQL et ne doit pas être exécuté. Aucun objet ni aucune donnée Supabase ne sont modifiés.

## Pourquoi le modèle actuel ne suffit pas

Le code actuel conserve les ventes et tâches dans des tableaux du navigateur (`localStorage`). Une vente créée reçoit le statut local `À valider`, puis le bouton de validation change ce statut dans le navigateur. Une tâche conserve le nom libre du responsable (`who`), sans identifiant de compte. Le registre d'équipe précise lui-même qu'ajouter un employé ne crée pas de compte de connexion.

Les tableaux complets enregistrés dans `farm_records.payload` ne permettent pas à RLS de limiter une personne à une vente ou une tâche particulière. Il faut des lignes serveur séparées.

## Tables à introduire après validation

### `farm_sales`

- `id` : UUID généré par le serveur.
- `farm_id` : ferme propriétaire.
- `animal_label` : identifiant de l'animal ou du lot.
- `sale_date` : date de vente.
- `buyer` : acheteur.
- `weight_kg`, `amount` : valeurs numériques positives.
- `payment_proof` : référence ou note de justificatif (ne pas y stocker de document privé en clair).
- `status` : `pending` ou `approved`.
- `created_by`, `created_at` : identité et date définies côté serveur.
- `approved_by`, `approved_at` : identité et date définies exclusivement par l'action serveur d'approbation.

Règles visées :
- Secrétariat : créer, consulter et corriger une vente tant qu'elle est `pending` (non validée). Il ne peut jamais modifier le statut d'approbation ni corriger une vente après validation. Il peut consulter les justificatifs de paiement, sans pouvoir les modifier ni les supprimer.
- Responsable : consulter les ventes et leurs justificatifs de paiement uniquement ; il ne peut ni créer, ni modifier, ni approuver une vente, ni modifier ou supprimer un justificatif.
- Administrateur : consulter, corriger selon procédure auditée, approuver et consulter les justificatifs de paiement. La gestion des justificatifs (modification ou suppression) doit être réservée à une action administrateur auditée.
- Employé : aucun accès aux ventes.

L'approbation doit être une fonction serveur transactionnelle qui vérifie le rôle admin, la ferme, le statut courant `pending`, puis écrit `approved`, `approved_by` et `approved_at`. Un client ne doit jamais pouvoir envoyer directement ces trois champs.

### `farm_tasks`

- `id` : UUID généré par le serveur.
- `farm_id` : ferme propriétaire.
- `title`, `details`, `due_date`, `priority`.
- `assigned_to` : UUID du compte Supabase Auth membre de la ferme.
- `created_by`, `created_at`.
- `status` : `todo` ou `done`.
- `completed_by`, `completed_at`.

Règles visées :
- Administrateur et responsable : créer, attribuer et superviser les tâches, y compris celles du secrétariat.
- Secrétariat : consulter son planning, lire les tâches qui lui sont attribuées, les terminer et ajouter une note ou une photo de réalisation. Il ne peut pas réattribuer les tâches ni modifier les paramètres définis par le responsable ou l'administrateur.
- Employé : lire uniquement les tâches qui lui sont attribuées, les terminer et joindre une note ainsi qu'une photo comme preuve de réalisation, sans changer le responsable, l'échéance ou la priorité.
- Les autres rôles n'ont pas accès aux tâches, sauf décision métier contraire.

La clôture d'une tâche doit être limitée côté serveur à l'employé assigné ou à un responsable/admin autorisé. Les champs d'affectation et de création restent protégés.

## Contrôles communs

- Toute opération vérifie l'appartenance active à la ferme et le rôle côté serveur.
- Les clés étrangères relient `farm_id` à `farms` et les utilisateurs à `auth.users`.
- Les contraintes contrôlent les statuts et valeurs positives.
- RLS doit être activé sur les deux tables. Les politiques existantes permissives sur `farm_records` ne doivent pas être considérées comme remplacées par de nouvelles politiques : elles sont évaluées en OR.
- Les fonctions RPC doivent vérifier `auth.uid()`, le rôle et le `farm_id`, et empêcher l'usurpation des champs d'audit.
- Tests négatifs obligatoires : secrétaire qui tente d'approuver, employé qui lit la vente, employé qui consulte la tâche d'un autre, utilisateur inactif, membre d'une autre ferme.

## Compatibilité et migration des données existantes

1. Ne pas déplacer automatiquement les tableaux existants.
2. Créer d'abord les nouvelles tables et tester avec des données fictives.
3. Faire une sauvegarde vérifiée avant toute migration réelle.
4. Importer les ventes/tâches historiques seulement après comparaison et détection des doublons.
5. Garder les anciens enregistrements `farm_records` en lecture seule pendant une période de contrôle.
6. Adapter ensuite l'interface pour lire/écrire les lignes serveur et afficher les erreurs d'autorisation.
7. N'activer les nouveaux boutons qu'après tests avec chaque rôle.

## Décisions métier à confirmer avant SQL

- Confirmé : le secrétariat peut corriger une vente déjà saisie tant qu'elle est `pending`. Après approbation, toute correction doit suivre une procédure réservée à l'administrateur et tracée dans l'audit.
- Confirmé : le responsable peut consulter les ventes uniquement. Il ne peut ni en créer, ni en modifier, ni les approuver.
- Confirmé : un employé peut ajouter une note et une photo comme preuve de réalisation de sa tâche.
- Confirmé : le secrétariat doit disposer de son propre planning et pouvoir suivre les tâches qui lui sont attribuées.
- Confirmé : l'administrateur, le secrétariat et le responsable peuvent consulter les justificatifs de paiement. Le secrétariat et le responsable ne peuvent ni les modifier ni les supprimer.

Aucune réponse ne doit être déduite automatiquement des anciens profils d'exemple.
