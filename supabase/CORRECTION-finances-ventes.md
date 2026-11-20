# Correction financière — ventes et recettes

Branche : `travail-v30-3-reprise`  
Portée : copie de travail uniquement. Aucun changement sur `main`, le site publié ou Supabase.

## Changements réalisés

- Toute nouvelle vente locale reçoit le statut `pending`.
- Les anciennes ventes qui n'ont pas de statut sont traitées comme « En attente » ; aucune n'est automatiquement approuvée.
- La liste des ventes affiche le statut et ne propose plus de suppression locale depuis cette interface.
- Le tableau de bord calcule les recettes uniquement à partir des ventes portant le statut `approved`.
- Les ventes en attente et refusées sont exclues des recettes.
- Le rapport imprimable/PDF applique la même règle et affiche le statut de chaque vente.
- Le tableau de bord précise le nombre de ventes en attente et rappelle que la validation locale ne fait pas foi.

## Limite de sécurité essentielle

Cette modification corrige la règle de calcul et l'interface. Elle ne crée pas le processus sécurisé d'approbation. Aucun bouton local ne permet d'approuver une vente. Le statut `approved` devra être attribué exclusivement par une fonction serveur Supabase après contrôle du rôle administrateur, avec journalisation de l'approbateur et de la date.

Tant que cette fonction serveur et les politiques RLS ne sont pas implémentées et testées, les montants affichés restent indicatifs et les données locales ne constituent pas une comptabilité certifiée.

## Contrôles statiques effectués

- Vérification de la présence du statut initial `pending`.
- Vérification du filtre `approved` dans le calcul du tableau de bord et du rapport PDF.
- Vérification de l'exclusion des ventes sans statut des recettes.
- Vérification de l'absence de commande de suppression de vente dans l'interface et son gestionnaire.
- Vérification de l'absence de doublons d'identifiants HTML dans le fichier examiné.

Aucun test navigateur réel, test multi-utilisateur ou test Supabase n'a été exécuté dans cette étape.

## Complément — identifiants et dépenses locales

- Les nouvelles ventes et dépenses locales reçoivent désormais un identifiant stable généré côté navigateur et un horodatage de création. Cela prépare une future synchronisation idempotente, sans rendre ces valeurs fiables côté serveur.
- Le bouton et le gestionnaire de suppression locale des dépenses ont été retirés de l'interface. Une correction devra être conçue comme une opération d'administration traçable côté serveur.
- Ces changements ne créent pas encore de journal d'audit Supabase et ne sécurisent pas les données stockées dans le navigateur. La validation serveur et les politiques RLS restent indispensables.
