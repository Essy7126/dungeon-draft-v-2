# Dungeon Draft Studio 2.0 — guide utilisateur

Statut : **WORKTREE_CANDIDATE**

Version produit candidate : **2.0.0**. Les chemins techniques sont repliés ; la barre de contexte affiche run, salle, héros, portée, usages, état, erreurs et cible de production. Le tableau **Productions et récupérations** inventorie bundles, archives, backups, transactions, drafts et transferts Lab sans suppression automatique.

## Arena — recette principale sandbox

1. choisir la run dans la barre partagée ;
2. créer une arène `MODULAR` ou `HYBRID` ;
3. dessiner les cellules puis peindre pierre, eau, glace, lave et void ;
4. placer murs, spawns et objectif ;
5. valider et tester la vue Jeu ;
6. simuler Eau, Glace ou Lave/Feu sur une cellule ;
7. ouvrir Produire, puis Exporter le kit artistique ;
8. créer `background.png` à la résolution exacte ;
9. Importer le décor, revoir avant/après et confirmer ;
10. produire sans rattacher, ou choisir run/action/index ;
11. vérifier le compte avant/après et l’index dans le résultat ;
12. recharger la run.

Retirer une salle retire seulement sa référence. Pour isoler une salle partagée, utiliser Rendre spécifique avant de la modifier.

## Skill Tree — recette run de test

1. choisir run, héros et portée ;
2. sélectionner discipline, rang et nœud ;
3. modifier l’effet dans le formulaire guidé ;
4. utiliser Prévisualiser pour le sort avant/après et les scénarios runtime ;
5. utiliser Comparer runs ;
6. revoir le plan de sauvegarde ;
7. confirmer la transaction et vérifier le chemin du profil ;
8. revenir à la run principale pour confirmer son indépendance.

## Documents sales

Lors d’un changement de contexte, choisir Sauvegarder, Brouillon, Abandonner ou Annuler. Fermer la fenêtre ou changer de run ne remplace jamais silencieusement une working copy.

Plusieurs documents dirty sont résolus dans une transaction globale : tous les plans sont préparés et stagés avant commit ; un échec restaure l’ensemble et conserve le contexte courant.
