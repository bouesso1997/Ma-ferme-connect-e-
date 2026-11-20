# Conception cible — synchronisation fiable de Ma Ferme Connectée

Date : 20 novembre 2026  
Branche de travail : `travail-v30-3-reprise`

## Objectif

Permettre à plusieurs appareils autorisés de travailler sur les mêmes données sans perte silencieuse, doublon ni contournement des permissions. Cette note est une spécification de conception, pas une migration appliquée.

## Règles non négociables

1. Le serveur Supabase est la source de vérité pour les données partagées.
2. Une absence de réponse, une liste vide inattendue ou une erreur réseau ne signifie jamais « supprimer les données ».
3. Aucun téléchargement ne remplace globalement les données locales sans comparaison, sauvegarde et confirmation explicite.
4. Toute opération d'écriture est autorisée côté serveur par RLS et/ou fonction PostgreSQL. Masquer un bouton dans le navigateur n'est pas une sécurité.
5. Les identifiants stables sont créés une fois et conservés lors des synchronisations.
6. Les suppressions sont explicites, tracées et récupérables ; pas de suppression en cascade implicite depuis un appareil.
7. Les montants et états financiers validés sont calculés côté serveur, pas acceptés depuis une simple variable JavaScript.

## Modèle de synchronisation proposé

### A. Identité et métadonnées

Chaque enregistrement partagé devrait posséder, selon le schéma retenu après diagnostic :

- un identifiant UUID stable ;
- un identifiant de ferme ;
- une date de création et une date de mise à jour côté serveur ;
- l'identifiant du compte ayant créé/modifié l'enregistrement ;
- un numéro de version ou une empreinte permettant de détecter une modification concurrente ;
- un état d'archivage/suppression logique si le domaine autorise les suppressions.

Ne pas ajouter ces colonnes avant d'avoir comparé le schéma réel des tables existantes.

### B. Lecture

1. Authentifier l'utilisateur.
2. Vérifier son appartenance active à la ferme.
3. Lire uniquement les enregistrements autorisés par RLS.
4. Récupérer les changements depuis un curseur/version serveur fiable.
5. Vérifier que la réponse est complète et valide.
6. Fusionner par identifiant stable, sans vider les tableaux locaux.
7. En cas de conflit, conserver les deux versions et demander une résolution explicite ; ne pas choisir silencieusement la plus récente côté appareil.

### C. Écriture

1. Préparer une opération contenant un identifiant unique de requête.
2. Envoyer uniquement les enregistrements modifiés.
3. Le serveur vérifie le rôle, la ferme, les champs et les règles métier.
4. Le serveur applique l'opération de façon transactionnelle et idempotente.
5. Le client reçoit la version serveur acceptée ou un conflit explicite.
6. Le client marque l'opération comme synchronisée uniquement après confirmation serveur.

Une répétition de la même requête après une coupure réseau ne doit pas créer une seconde vente ou dépense.

## Permissions fonctionnelles à faire respecter côté serveur

| Action | Administrateur | Secrétariat | Responsable |
|---|---:|---:|---:|
| Consulter les données opérationnelles autorisées | Oui | Oui | Oui |
| Saisir une vente | Oui | Selon règle validée | Selon règle validée |
| Approuver/refuser une vente | Oui | Non | Non |
| Modifier/supprimer une vente approuvée | Oui, avec journal | Non | Non |
| Consulter les justificatifs de paiement | Oui | Oui | Oui |
| Modifier/supprimer les justificatifs | Oui | Non | Non |
| Gérer les membres et les rôles | Oui | Non | Non |
| Consulter les dépenses | Oui | Oui selon périmètre | Oui selon périmètre |
| Modifier/supprimer les dépenses | Oui | À définir | À définir |

Les cases « selon règle validée » doivent être tranchées avant de coder les politiques. Le tableau ne constitue pas encore une permission effective.

## Règles métier financières

- Une vente nouvellement saisie reçoit un statut serveur initial `pending`.
- Seule une vente approuvée par une fonction serveur autorisée entre dans les recettes validées.
- L'approbation conserve l'auteur, l'approbateur et l'horodatage.
- Une vente refusée reste consultable dans l'historique selon les permissions.
- Une dépense saisie ne devient pas une recette et ne peut pas modifier le statut d'une vente.
- Les totaux du tableau de bord et du PDF doivent distinguer ventes en attente, refusées et approuvées.
- Les anciennes ventes locales ne doivent jamais être automatiquement approuvées lors d'une migration.

## Tests d'acceptation avant activation

| Test | Résultat exigé |
|---|---|
| Deux appareils lisent les mêmes données | Même jeu de données autorisé |
| Appareil hors ligne puis reconnecté | Changements envoyés une seule fois |
| Requête répétée après délai réseau | Aucun doublon |
| Serveur inaccessible | Données locales conservées |
| Réponse serveur partielle/invalide | Aucune suppression locale |
| Deux personnes modifient le même enregistrement | Conflit détecté et présenté |
| Compte désactivé | Écriture refusée côté serveur |
| Responsable tente d'approuver une vente | Refus côté serveur |
| Secrétariat consulte un justificatif autorisé | Lecture permise |
| Secrétariat tente de supprimer un justificatif | Refus côté serveur |
| Restauration d'une sauvegarde | Données vérifiées avant remplacement |
| Utilisateur d'une autre ferme | Aucun accès aux données de la ferme |

## Étapes techniques dans l'ordre

1. Exécuter le diagnostic SQL en lecture seule sur le projet de test et relever les schémas, contraintes, politiques et fonctions existants.
2. Cartographier les données déjà présentes dans `farm_records` et les tables dédiées afin d'éviter une migration concurrente ou une duplication de source de vérité.
3. Décider du modèle cible par domaine (animaux, stocks, santé, ventes, dépenses, tâches, employés).
4. Préparer des migrations SQL versionnées, relisibles et réversibles autant que possible ; ne pas les exécuter avant validation du périmètre.
5. Développer les fonctions serveur et politiques RLS.
6. Développer la file d'opérations client, la détection de conflits et les confirmations de réception.
7. Tester sur un environnement isolé avec données fictives et scénarios de panne.
8. Faire une sauvegarde et une répétition de restauration.
9. Activer progressivement, domaine par domaine, après validation.

## État actuel

- Les quatre boutons de synchronisation risquée sont désactivés dans la copie de travail.
- Le code actuel repose principalement sur `localStorage` pour les données métier.
- L'authentification visible dans le prototype ne suffit pas à prouver les permissions serveur.
- Le schéma réel Supabase n'a pas encore été vérifié dans cette étape.
- Aucune migration, écriture ou suppression Supabase n'a été effectuée.

## Critère de sortie

La synchronisation ne sera considérée prête que lorsque les tests d'acceptation ci-dessus auront été exécutés et réussis, et que les règles RLS auront été vérifiées sur le projet de test. Un bouton qui affiche « synchronisé » sans accusé de réception serveur ne satisfait pas ce critère.
