# Recette de validation finale — Ma Ferme Connectée

Branche : `travail-v30-3-reprise`

Ce document sépare les contrôles déjà effectués des essais qui restent obligatoires. Une vérification statique du code ne remplace jamais un essai réel dans un navigateur ou sur Supabase.

## 1. Contrôles déjà effectués sur la copie de travail

- [x] Les deux blocs JavaScript de `index.html` se compilent sans erreur de syntaxe.
- [x] Aucun identifiant HTML dupliqué parmi les 255 identifiants contrôlés.
- [x] Les commandes de synchronisation générale et Santé sont désactivées dans l'interface.
- [x] Ventes en attente par défaut ; les ventes en attente/refusées sont exclues du chiffre d'affaires.
- [x] Les recettes connues sont distinguées des ventes approuvées ; les historiques de paiement incomplets restent « à vérifier ».
- [x] La restauration locale exige une sauvegarde préalable et accepte les anciennes sauvegardes en initialisant les nouveaux tableaux absents.
- [x] Les modifications récentes de gestion des stocks, lots, santé et reproduction restent locales dans cette copie.

**Limite :** aucun de ces contrôles ne prouve encore le bon fonctionnement dans Safari/Chrome, sur iPhone/Android, ni la bonne application des politiques Supabase.

## 2. Recette fonctionnelle à exécuter dans le navigateur de test

### Données d'élevage
- [ ] Créer, modifier et consulter un animal ; vérifier code, catégorie, sexe, dates et poids.
- [ ] Ajouter plusieurs pesées et vérifier l'historique ainsi que la courbe.
- [ ] Enregistrer naissances, sevrages et mortalités ; vérifier les totaux.
- [ ] Enregistrer un inventaire physique daté ; vérifier les catégories non comptées.
- [ ] Enregistrer une saillie, une gestation et une échéance ; vérifier le calendrier.

### Stocks et santé
- [ ] Réceptionner un aliment en kg avec coût ; vérifier le stock, le mouvement et la charge correspondante.
- [ ] Distribuer des aliments par catégorie et lot ; vérifier le stock restant et le récapitulatif journalier.
- [ ] Vérifier qu'une sortie supérieure au stock disponible est refusée.
- [ ] Ajouter un soin avec prochaine échéance ; vérifier l'historique et les alertes.
- [ ] Vérifier les autorisations de notifications sur un appareil de test.

### Commerce et finances
- [ ] Créer une vente avec client, quantité, poids et montant ; vérifier la référence interne et le statut « en attente ».
- [ ] Vérifier qu'une vente en attente ne compte pas dans le chiffre d'affaires.
- [ ] Vérifier qu'un paiement supérieur au solde est refusé.
- [ ] Vérifier les paiements partiels, le solde restant et les anciens dossiers « à vérifier ».
- [ ] Saisir une dépense dans chacune des six catégories ; vérifier les totaux mensuels et annuels.
- [ ] Vérifier que les charges partagées non affectées restent visibles comme non affectées.
- [ ] Vérifier les rapports PDF et les totaux avec les mêmes filtres que le tableau de bord.

### Sauvegarde et restauration
- [ ] Exporter une sauvegarde JSON et vérifier qu'elle contient les données attendues.
- [ ] Restaurer une copie de sauvegarde sur un profil de navigateur de test.
- [ ] Tester un fichier invalide et vérifier que les données existantes restent intactes.
- [ ] Vérifier la compatibilité d'une ancienne sauvegarde sans les nouveaux tableaux.
- [ ] Vérifier qu'un échec de sauvegarde préalable bloque la restauration.

### Compatibilité
- [ ] Tester Safari sur iPhone et Chrome sur ordinateur.
- [ ] Vérifier les formulaires, tableaux, menus et PDF sur petit écran.
- [ ] Vérifier l'installation PWA et le comportement hors connexion.
- [ ] Vérifier qu'une actualisation de page ne fait pas disparaître les données locales.

## 3. Recette de sécurité Supabase — bloquée jusqu'au diagnostic

Exécuter d'abord `diagnostic-securite-complet.sql` dans le projet de TEST et examiner les neuf résultats. Aucune migration ne doit être écrite à partir d'un schéma supposé.

Après validation du diagnostic :
- [ ] Confirmer l'isolation des données par `farm_id`.
- [ ] Confirmer que les utilisateurs anonymes n'accèdent à aucune donnée privée.
- [ ] Tester un compte administrateur, un compte secrétariat et un compte responsable distincts.
- [ ] Confirmer qu'un membre ne peut pas s'attribuer le rôle administrateur.
- [ ] Confirmer que seul l'administrateur peut approuver/refuser une vente.
- [ ] Confirmer que le statut d'approbation ne peut pas être modifié directement par le navigateur.
- [ ] Confirmer que les événements d'approbation sont audités côté serveur.
- [ ] Tester lecture et dépôt des justificatifs selon les rôles ; vérifier qu'un rôle non autorisé ne peut ni lire ni modifier.
- [ ] Tester expiration, déconnexion, révocation et réinitialisation des comptes.
- [ ] Tester la synchronisation avec plusieurs appareils et vérifier l'absence de doublons et de perte de données.

## 4. Conditions de mise en production

La version ne peut être déclarée finale que lorsque :
1. les essais fonctionnels critiques sont réussis ;
2. les droits et l'approbation sont appliqués côté serveur ;
3. la synchronisation fonctionne sans écrasement ni doublon ;
4. la sauvegarde et la restauration ont été testées ;
5. les trois profils ont passé les tests d'accès et de refus ;
6. les rapports et calculs ont été comparés à des données de contrôle.

Tant que ces conditions ne sont pas satisfaites, la copie reste une version de travail. Ne pas activer la synchronisation ni publier cette branche en production.

## 5. Prochaine dépendance

Le seul élément qui manque pour concevoir la sécurisation Supabase sans supposition est le résultat des neuf sections du diagnostic en lecture seule. Les tests navigateur peuvent être réalisés en parallèle, mais aucune migration de production n'est autorisée par ce document.
