# Audit technique — synchronisation cloud (20 novembre 2026)

Branche examinée : `travail-v30-3-reprise`  
Fichier examiné : `index.html`  
Nature : audit statique en lecture seule. Aucun appel Supabase n'a été exécuté et aucune donnée n'a été modifiée.

## Résumé

La synchronisation générale reste désactivée dans l'interface, ce qui est prudent. Toutefois, les commandes de lecture et de synchronisation Santé comportent des risques de perte ou de duplication. Elles ne doivent pas être utilisées avec des données importantes avant correction et essais sur une base isolée.

## Constats vérifiés dans le code

### 1. Chargement général (`cloudPull`) — risque élevé de remplacement local

- La fonction lit les lignes de `farm_records` pour la ferme.
- Elle construit un nouvel objet à partir de tableaux vides.
- Pour chaque catégorie valide, elle ajoute les éléments trouvés.
- Elle finit par remplacer intégralement `data` par cet objet puis appelle `save()`.
- Une catégorie absente, vide, mal formée ou non représentée dans la réponse serveur devient donc vide localement après confirmation.
- Les données présentes uniquement dans les tables dédiées (par exemple `farm_animals`) ne sont pas incluses dans cette lecture de `farm_records`.

**Décision :** ne pas utiliser « Charger depuis le serveur » sur un appareil contenant des données à conserver. La sauvegarde JSON est une précaution utile mais ne corrige pas le risque de divergence entre les tables.

### 2. Envoi Santé (`healthPush`) — risque de duplication logique

- Le code recherche toutes les lignes `farm_records` de catégorie `health` pour la ferme.
- S'il en trouve plusieurs, il envoie le même tableau local complet dans le champ `payload` de chacune de ces lignes.
- Au chargement Santé, le code concatène les tableaux de toutes les lignes `health`.
- Si plusieurs lignes existent, les mêmes entrées peuvent donc être répétées dans le résultat chargé.

**Décision :** ne pas lancer l'envoi Santé avant d'avoir vérifié le nombre de lignes `health` et défini une règle serveur d'unicité.

### 3. Chargement Santé (`healthPull`)

- Il remplace le tableau Santé local par la concaténation des tableaux trouvés côté serveur.
- Les autres catégories restent intactes.
- En cas de plusieurs lignes Santé, les doublons éventuels sont conservés.
- Si aucune ligne n'est trouvée, le code ne modifie pas le tableau local.

**Décision :** le périmètre est limité, mais l'opération doit rester suspendue tant que le nombre de lignes et leur contenu ne sont pas contrôlés.

### 4. Session et rôles

- La session est conservée uniquement dans la variable JavaScript `cloudSession` en mémoire.
- Aucun mécanisme de restauration de session après rechargement de page n'a été identifié dans le code examiné.
- La connexion vérifie un rôle `admin` actif dans `farm_members`. Les rôles secrétariat et responsable ne sont donc pas admis par ce parcours de connexion.
- Le bouton de déconnexion efface la variable de session côté page et le champ mot de passe ; aucun appel de révocation du jeton n'est effectué dans ce gestionnaire.

**Décision :** prévoir une gestion de session officielle, des contrôles de rôle par opération et une déconnexion adaptée au cycle de vie Supabase. Les permissions ne doivent jamais reposer uniquement sur l'interface.

### 5. Stockage local

- Les données métier sont chargées depuis et sauvegardées dans `localStorage`.
- La fonction `save()` n'envoie pas les données vers Supabase.
- Une sauvegarde locale JSON est proposée, mais elle ne constitue pas une sauvegarde cloud ni une synchronisation multi-appareils.

## Plan de correction recommandé

1. Maintenir l'envoi général désactivé.
2. Suspendre temporairement les boutons de chargement/envoi Santé dans la version destinée aux essais tant que les données de test n'ont pas été vérifiées.
3. Établir un inventaire en lecture seule des lignes `farm_records` par ferme et par catégorie, ainsi que des tables dédiées.
4. Définir une source de vérité par domaine : animaux, stocks, ventes, dépenses, tâches, employés et santé.
5. Remplacer les remplacements complets par une synchronisation transactionnelle avec identifiants stables, contraintes d'unicité, journal de changements et gestion explicite des conflits.
6. Faire appliquer les droits par RLS et fonctions serveur ; ne pas faire confiance aux rôles ou statuts fournis par le navigateur.
7. Tester les scénarios : serveur vide, données locales seules, données serveur seules, données des deux côtés, réseau interrompu, doublons, deux appareils et droits insuffisants.
8. N'activer la synchronisation qu'après validation de ces essais et sauvegarde/restauration vérifiée.

## Limites de cet audit

Cet examen porte sur le code HTML/JavaScript de la branche de travail. Il ne prouve pas l'état réel des tables, contraintes, politiques RLS, fonctions ou privilèges Supabase. Le diagnostic SQL en lecture seule déjà préparé doit être exécuté sur l'environnement de test et ses résultats examinés avant de préparer une migration.

Aucun changement n'a été apporté à `main`, au site publié, aux versions V12/V24 ou à Supabase.
