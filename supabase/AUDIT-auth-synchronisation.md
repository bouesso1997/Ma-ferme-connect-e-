# Audit technique — authentification et synchronisation (branche travail-v30-3-reprise)

Audit statique du fichier `index.html` (lecture du code, sans connexion à Supabase).

## Ce qui est réellement présent

- Les données métier principales sont chargées depuis `localStorage` avec la clé `mfc_integrated_v1`.
- La fonction `save()` écrit uniquement dans `localStorage`.
- La configuration du projet (URL et ID de ferme) est conservée localement. La clé publique est demandée dans le formulaire et n'est pas réécrite dans la configuration persistée par le code observé.
- La connexion appelle Supabase Auth avec `grant_type=password`.
- Après connexion, l'application interroge `farm_members` et vérifie qu'une ligne correspond à l'utilisateur connecté, à l'ID de ferme saisi, avec `role = admin` et `active = true`.
- L'application affiche explicitement que l'envoi général est désactivé.
- La session est conservée uniquement dans la variable JavaScript `cloudSession` ; le code observé ne met pas en place de restauration persistante de session après rechargement.
- Le formulaire de vente, le tableau de ventes, le tableau de bord financier et le rapport PDF lisent les ventes depuis le tableau local `data.sales`.
- Aucun appel à `farm_sales` pour créer, approuver ou synchroniser les ventes n'a été identifié dans l'audit du fichier.

## Ce que cet audit ne prouve pas

Cet audit ne valide pas les politiques RLS, les privilèges SQL, les fonctions serveur ni le comportement réel de Supabase. La simple vérification du rôle dans l'interface ne remplace jamais les contrôles RLS côté base.

## Conséquence pour la suite

Ne pas activer la synchronisation générale. Ne pas créer de bouton local « Approuver » qui ferait croire à une validation sécurisée. La prochaine implémentation doit être serveur d'abord : fonction PostgreSQL de validation, vérification du rôle actif, journalisation de l'approbateur, politiques RLS et tests avec des comptes de rôles distincts.

## Entrée nécessaire avant migration

Exécuter `diagnostic-ventes-securite.sql` sur le projet Supabase de test et examiner ses résultats avant de rédiger le SQL de modification. Le script de diagnostic est en lecture seule.

## Correctifs de concurrence de session — 20 novembre 2026

- Le renouvellement de session est maintenant associé à l'époque de session qui l'a déclenché.
- Une nouvelle connexion ne peut plus attendre ni réutiliser la promesse de renouvellement d'une ancienne session.
- Le nettoyage d'une promesse ne peut plus effacer celle d'une session plus récente.
- Une réponse tardive d'une ancienne tentative de connexion ne peut plus remplacer le message d'état d'une session plus récente.
- Le renouvellement ne change pas lui-même l'époque de session : une actualisation valide ne se fait pas interpréter comme une déconnexion.

Ces contrôles ont été vérifiés par inspection statique du code. Ils n'ont pas encore été validés par des essais navigateur ou par des sessions Supabase réelles. Les opérations de synchronisation générale et Santé restent désactivées.
