# Dungeon Draft Studio 2.0 — guide utilisateur

Statut : **WORKTREE_CANDIDATE**

Version produit candidate : **2.0.0**. Les chemins techniques sont repliés ; la barre de contexte affiche run, salle, héros, portée, usages, état, erreurs et cible de production. Le tableau **Productions et récupérations** inventorie bundles, archives, backups, transactions, drafts et transferts Lab sans suppression automatique.

## Arena — recette principale sandbox

1. choisir la run dans la barre partagée ;
2. créer une arène `MODULAR` ou `HYBRID` ;
3. dessiner les cellules puis choisir dans **Sols sans effet** (Pierre,
   Neutre) ou **Terrains à effet** (Eau, Glace, Lave, Poison, Vapeur, Eau
   électrifiée) ; utiliser Retirer/clic droit pour VOID ;
4. placer murs, spawns et objectif ;
5. pour un vortex, choisir **Interactifs > Vortex apparié**, cliquer A puis B ;
6. valider et tester la vue Jeu ;
7. simuler une surface temporaire sans modifier le terrain permanent ;
8. ouvrir Produire, puis Exporter le kit artistique ;
9. créer `background.png` à la résolution exacte ;
10. Importer le décor, revoir avant/après et confirmer ;
11. produire sans rattacher, ou choisir run/action/index ;
12. vérifier le compte avant/après et l’index dans le résultat, puis recharger.

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
