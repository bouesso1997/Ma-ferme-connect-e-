# Matrice des droits — Ma Ferme Connectée

## État technique vérifié dans la copie de travail

- La connexion actuelle utilise Supabase Auth par mot de passe.
- Après authentification, le code interroge `farm_members` pour la ferme sélectionnée.
- Le code n'accepte actuellement que `role = 'admin'` avec `active = true`.
- La session est conservée uniquement dans la variable JavaScript `cloudSession` pendant la vie de la page.
- Les boutons de synchronisation restent désactivés : la lecture/écriture actuelle n'est pas assez sûre pour être ouverte à plusieurs profils.
- Le registre du personnel ne crée pas de compte Supabase Auth.

## Matrice fonctionnelle cible

| Fonction | Administrateur | Secrétariat | Responsable |
|---|---:|---:|---:|
| Consulter les animaux, stocks, tâches et santé | Oui | Oui | Oui |
| Ajouter / modifier les données d'élevage | Oui | Selon attribution | Oui |
| Consulter ventes et justificatifs de paiement | Oui | Oui | Oui |
| Créer une vente en attente | Oui | Oui | Oui |
| Approuver une vente et la compter dans le chiffre d'affaires | Oui | Non | Non |
| Modifier / supprimer une vente validée | Oui | Non | Non |
| Consulter dépenses et rentabilité | Oui | Selon autorisation | Non |
| Ajouter une dépense | Oui | Oui | Selon attribution |
| Gérer les comptes, rôles et invitations | Oui | Non | Non |
| Modifier les paramètres de ferme | Oui | Non | Non |

Cette matrice est une cible métier à confirmer avant son implémentation. Les droits sensibles doivent être appliqués par Supabase RLS et, si nécessaire, par des fonctions serveur — jamais seulement en masquant des boutons dans le navigateur.

## Conditions avant d'ouvrir les profils

1. Examiner les quatre résultats du fichier `diagnostic-comptes-roles.sql`.
2. Confirmer les valeurs exactes permises par la colonne `farm_members.role` et la structure de la table.
3. Vérifier que les politiques RLS empêchent un membre de s'attribuer lui-même le rôle admin ou de modifier son statut.
4. Créer les comptes individuels via invitations Supabase Auth, sans mot de passe partagé.
5. Associer chaque identité à la ferme avec un rôle attribué côté serveur.
6. Tester chaque profil avec deux comptes distincts et vérifier les refus d'accès, notamment sur les ventes et dépenses.
7. Tester expiration de session, déconnexion, réinitialisation de mot de passe et révocation d'un membre.

## Limites actuelles — ne pas présenter comme terminé

- Seul le profil admin est accepté par le contrôle actuel de connexion.
- Aucune invitation de compte n'est encore intégrée à l'application.
- Les rôles secrétariat et responsable ne sont pas encore utilisables dans la connexion.
- Les synchronisations restent désactivées.
- Les autorisations de vente et de dépense ne sont pas encore garanties par une validation serveur.
- Aucune validation multi-utilisateur en navigateur n'a été réalisée.

## Prochaine action nécessaire

Exécuter le diagnostic strictement en lecture seule dans le projet Supabase de TEST et transmettre les résultats non sensibles. Ne pas coller de clé, mot de passe, jeton, adresse e-mail ni identifiant personnel. Aucun changement de schéma ou de politique n'est inclus dans cette étape.
