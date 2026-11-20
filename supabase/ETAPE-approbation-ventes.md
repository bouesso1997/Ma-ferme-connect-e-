# Étape suivante — sécurisation serveur des ventes et des comptes

Branche : `travail-v30-3-reprise`

## État actuel du logiciel

- Les ventes créées localement sont en attente par défaut.
- Le tableau de bord et les rapports distinguent ventes approuvées, encaissements réellement saisis, dépenses et créances connues.
- Les paiements restent des données locales : leur historique n'est pas encore validé par Supabase.
- La connexion actuelle accepte le rôle administrateur actif uniquement.
- Les synchronisations générales restent désactivées.
- Les boutons et calculs du navigateur ne constituent pas une autorisation serveur.

## Action à faire : un diagnostic unique, sans modification

1. Ouvrir le projet Supabase de TEST, puis **SQL Editor**.
2. Ouvrir le fichier [diagnostic-securite-complet.sql](./diagnostic-securite-complet.sql).
3. Copier tout le contenu dans SQL Editor et l'exécuter.
4. Partager ici les résultats des neuf sections, en texte ou en captures lisibles.

Le script ne lit aucune vente individuelle, aucun justificatif, aucun e-mail et aucun identifiant personnel. Il consulte les métadonnées de la base et compte les membres par rôle/statut. Il ne crée, ne modifie et ne supprime rien.

**Ne partage aucun mot de passe, jeton, clé Supabase, adresse e-mail, identifiant utilisateur ni justificatif.**

## Ce que les résultats permettront de confirmer

- Les colonnes et contraintes réellement présentes dans `farm_sales`, `farm_members` et `audit_events`.
- Les politiques RLS et les droits SQL déjà configurés.
- Les protections empêchant un membre de s'attribuer le rôle administrateur.
- L'existence éventuelle d'une fonction serveur d'approbation.
- Les règles du bucket privé des justificatifs.
- La migration à adapter au schéma existant, sans créer une deuxième source de ventes.

## Règles de sécurité visées

- Une vente est créée en attente côté serveur.
- Seul un administrateur actif peut approuver ou refuser.
- L'approbateur et la date de décision sont inscrits côté serveur.
- Les clients ne peuvent pas modifier directement le statut d'approbation.
- Le secrétariat et le responsable ne peuvent pas approuver, modifier ou supprimer une vente validée.
- Les justificatifs restent privés ; les trois rôles autorisés peuvent les consulter, tandis que les modifications restent réservées à l'administrateur.
- Les permissions sont appliquées par RLS et fonctions PostgreSQL, pas par de simples contrôles d'interface.

## Après le diagnostic

Je comparerai les résultats au code et préparerai une migration SQL ciblée, documentée et réversible autant que possible. Elle restera non exécutée tant que le schéma et les politiques ne seront pas confirmés.

Aucun changement de Supabase, de `main`, du site publié, de V12 ou de V24 n'est effectué dans cette étape.
