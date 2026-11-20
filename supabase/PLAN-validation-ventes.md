# Ma Ferme Connectée — conception du circuit de validation des ventes

## État audité sur la branche travail-v30-3-reprise

Le formulaire `saleForm` ajoute les ventes à `data.sales`, puis appelle `save()`. Le stockage utilisé est `localStorage`.

La fonction `dashboard()` additionne actuellement tous les montants de `data.sales` pour calculer les recettes et la rentabilité. L'export PDF refait également cette somme sans filtre de statut.

La fonction `renderSales()` affiche toutes les ventes et permet leur suppression depuis l'interface. Aucun statut de validation n'est affiché. Le code de connexion Supabase vérifie le rôle administrateur dans `farm_members`, mais aucun appel de synchronisation des ventes vers `farm_sales` n'a été trouvé. La synchronisation générale reste désactivée.

## Règles métier à implémenter

1. Une vente saisie par un membre autorisé reçoit le statut `pending`.
2. Une vente `pending` est visible dans la liste de contrôle, mais n'entre ni dans les recettes, ni dans le bénéfice, ni dans les totaux du rapport PDF.
3. Seul un administrateur actif de la ferme peut approuver ou rejeter une vente.
4. L'approbation et le rejet sont exécutés côté serveur, jamais sur la seule base d'un bouton ou d'une variable JavaScript.
5. L'identité de l'approbateur et l'horodatage de décision sont conservés côté serveur.
6. Une vente approuvée ne peut pas être modifiée ou supprimée par le secrétariat ou le responsable.
7. Toute modification sensible d'une vente approuvée doit être réservée à l'administrateur et tracée.
8. Le total des recettes est la somme des ventes dont le statut serveur est `approved` uniquement.

## Modèle de statuts proposé

- `pending` : en attente de décision
- `approved` : approuvée par un administrateur
- `rejected` : rejetée par un administrateur

Les valeurs finales et les noms des colonnes seront adaptés au schéma réel déjà installé, après lecture du diagnostic SQL. Ne pas créer une deuxième table de ventes si `farm_sales` existe déjà.

## Contrat de sécurité à vérifier avant le code

- RLS activée et forcée si nécessaire sur la table de ventes.
- Les membres autorisés peuvent créer une vente en attente uniquement.
- Un membre non administrateur ne peut ni choisir `approved`, ni modifier le statut après création.
- La validation est réalisée par une fonction PostgreSQL sécurisée qui vérifie le rôle actif dans `farm_members`.
- La fonction renseigne elle-même l'identité et la date de décision.
- Les droits EXECUTE sont accordés uniquement aux rôles authentifiés nécessaires.
- Les politiques ne font pas confiance à un `farm_id`, `user_id` ou rôle fourni librement par le navigateur.
- Les ventes d'une autre ferme ne sont jamais accessibles.

## Tests d'acceptation obligatoires

1. Un compte secrétariat crée une vente : elle apparaît en attente.
2. Cette vente n'augmente pas les recettes, le bénéfice ou le PDF financier.
3. Le secrétariat ne peut pas approuver, rejeter, modifier ou supprimer la vente.
4. Le responsable ne peut pas approuver, rejeter, modifier ou supprimer la vente.
5. L'administrateur actif peut approuver la vente.
6. Après approbation, le montant est inclus une seule fois dans les recettes et le PDF.
7. Un utilisateur sans rôle actif ne peut ni lire ni modifier les ventes de la ferme.
8. Les tentatives de falsification du statut par requête REST sont refusées par PostgreSQL.
9. Une vente d'une autre ferme reste inaccessible.
10. Les ventes historiques locales sont importées avec un statut à examiner ; aucune ne doit être automatiquement approuvée.

## Blocage actuel

Le script `diagnostic-ventes-securite.sql` est en lecture seule. Il faut ses résultats pour adapter la migration au schéma et aux politiques existants. Aucun SQL de modification ne doit être appliqué avant cette vérification. Ne pas activer la synchronisation générale ni publier cette branche en production avant les tests.
