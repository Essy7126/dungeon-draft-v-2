# Catabase d’Achille — bilan d’implémentation du vertical slice

**Date :** 28 août 2026  
**Run autoritaire :** `data/runs/odyssey.tres`  
**Contrat de vision :** `docs/design/catabase_achille_vertical_slice_vision.md`

Ce bilan décrit uniquement le lot Catabase/Achille réalisé dans un worktree déjà modifié. Il ne transforme pas les autres changements présents dans le dépôt en livrables de ce lot.

## Résultat jouable

La Catabase est une run forcée de trois salles, prévue pour Achille seul :

1. **L’Ombre de Paris** enseigne un trait retardé de 18 dégâts. La cible peut l’éviter en quittant la portée ou en brisant la ligne de vue.
2. **La Porte des Cendres** oppose deux escarmoucheurs et un garde dans une arène peinte à obstacles. Le mode peinture pure conserve la topologie logique sans recouvrir l’illustration de dalles modulaires.
3. **Le Jugement de Paris** combine un champion de mêlée et Paris sur un damier grec ouvert de 13×13, calibré sur l’image native.

La durabilité ennemie croît de `52` à `160`, puis `167` PV cumulés. Les formations des salles II et III ont été vérifiées sur vingt seeds chacune.

## Mécaniques livrées

### Intention exacte de Paris

- nouvelle résolution différée `RANGED_STRIKE` ;
- préparation sans dégâts ni projectile d’impact ;
- télégraphe attaché à la cible vivante et redessiné lorsqu’elle se déplace ;
- revalidation portée + ligne de vue à l’activation suivante ;
- résolution à 18 dégâts si la cible est encore valide ;
- activation consommée sans dégâts si la cible s’est échappée ;
- projectile joué une seule fois, uniquement après une résolution valide.

### Évolution d’Achille

Les quatre disciplines atteignent le rang 2 à `3 XP` et proposent deux choix exclusifs :

- lance : dégâts ou portée ;
- percée : portée ou dégâts ;
- balayage : poussée ou dégâts ;
- garde : bouclier ou PM au tour suivant.

Le système existant d’évolution applique ces choix aux sorts runtime ; aucune nouvelle grande branche n’a été ajoutée.

### Présentation et lisibilité

- salle II rendue en peinture pure ;
- salle III remplacée par l’arène grecque `maps_achille_dalle.png` avec grille native 13×13 et RMS de calibration nul ;
- anciens occluders spatiaux retirés de la finale ;
- Paris rattaché au profil visuel du squelette distance ;
- historique de combat replié au repos ;
- inspection masquée sans cible et restaurée au survol/clic ;
- bandeau de tour raccourci, réduit en hauteur et reformulé en « À VOUS DE JOUER ».

### Mémoire immédiate

Le résultat de run affiche uniquement des faits runtime : victoire ou défaite, salles franchies, salle atteinte, seed lorsqu’elle existe et PV réels des héros. L’Archiviste produit une épitaphe factuelle, puis le bouton de la Catabase retourne directement au hub. Ce registre n’est ni sauvegardé ni archivé entre les sessions.

## Preuves exécutées avec Godot 4.7.1

| Vérification | Résultat |
|---|---:|
| Catabase : cinématique, Paris et contres | 19/19, 453 assertions |
| Contenu des trois salles et 20 seeds | 5/5, 128 assertions |
| Chronique factuelle et retour au hub | 6/6, 46 assertions |
| Contrat de production Achille | 4/4, 363 assertions |
| Télégraphes et faction squelette | 22/22, 122 assertions |
| Cinématique générique | 11/11, 48 assertions |
| Hub et lancement | 21/21, 1 558 assertions |
| HUD libéré au repos | 8/8, 71 assertions |
| Orchestration de présentation | 9/9, 47 assertions |
| Cycle de vie de progression | 18/18, 189 assertions |
| Parcours Archiviste → cinématique → run | `CATABASE_FULL_FLOW_QA_PASS`, 73,021 s |
| Captures GPU salles II et III | 1920×1080, OpenGL 3.3, code 0 |

La suite complète `test_odyssey_achilles_solo_run.gd` valide 17 tests sur 19 en headless. Les deux échecs restants sont les assertions 3D qui exigent un rendu de `SubViewport` alors que le renderer Dummy déclenche volontairement le fallback 2D. Les captures GPU réelles des salles II et III ont réussi ; ces deux échecs ne doivent néanmoins pas être présentés comme verts tant que les tests ne distinguent pas explicitement les lanes logique et GPU.

Godot signale encore des ressources/RID non libérées à la fermeture de plusieurs runners. Les tests fonctionnels passent, mais cette dette de teardown reste à corriger avant une lane release propre.

L’import global Godot termine avec le code `0`, mais il n’est pas déclarable comme propre dans l’état partagé actuel : un service Studio non suivi et extérieur à ce lot, `addons/dungeon_draft_arena_studio/services/arena_terrain_type_save_transaction_service.gd`, produit une erreur de constante à la ligne 22. Les scènes, ressources et suites Catabase ciblées chargent correctement. Ce défaut Studio doit être résolu par le propriétaire de ce changement concurrent avant toute affirmation de CI verte.

## Hors périmètre restant

- sauvegarde/reprise à la frontière de salle ;
- Archive persistante et historique de plusieurs tentatives ;
- télémétrie de playtest et `CombatRng` centralisé ;
- boss à transformation ou plusieurs phases ;
- objectifs de salle autres que l’élimination ;
- intentions exactes généralisées à tous les ennemis ;
- balance prouvée par joueurs externes ;
- profiling bas/milieu/haut de gamme ;
- audit de droits de tous les assets ;
- export distribuable et lane CI de release à zéro échec.

Ces chantiers ne doivent pas être masqués par la réussite locale du vertical slice.
