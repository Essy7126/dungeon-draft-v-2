# Monstres de Catabase — gameplay v1

Les quatre concepts approuvés deviennent des `UnitData` indépendants. Leurs sprites peints sont portés par `characters/enemies/catabase_monsters/`. Leurs deux techniques utilisent les événements d'attaque et de sort du visuel. En mêlée, les dégâts surviennent à la pose d'impact ; les projectiles ajoutent leur temps de trajet. Les portraits sont chargés à la demande depuis `assets/characters/catabase_monsters/<famille>/portrait.tres`.

## Statistiques de base

| Adversaire | PV | PA / PM | Initiative | Prouesse | Défense | Rôle |
| --- | ---: | ---: | ---: | ---: | --- | --- |
| Sentinelle d'airain | 78 | 4 / 2 | 6 | 14 | 35 armure ; première poussée réduite de 1 par activation | Tenir les goulets, repousser |
| Rejeton de braise | 42 | 4 / 3 | 10 | 10 | Feu +35 %, glace −20 % | Tireur fragile, attaque annoncée |
| Molosse du Styx | 50 | 4 / 5 | 13 | 11 | Aucune réduction passive | Approcher vite, saigner |
| Lamie du Léthé | 54 | 4 / 3 | 8 | 8 | 20 résistance magique ; ombre +20 %, feu −15 % | Contrôler l'approche à distance |

L'armure suit la mitigation existante `armure / (armure + 100)` : 35 armure représente environ 26 % de réduction physique, pas 35 %. Aucun ennemi ne possède d'esquive aléatoire ni de sort faisant sauter un tour.

## Techniques

Chaque technique coûte 4 PA et ne peut être utilisée qu'une fois par activation. Une unité ne cumule donc pas plusieurs attaques dans son activation. Les techniques spéciales sont bloquées à la première activation et reviennent toutes les trois activations. Les descriptions indiquent les dégâts de base ; le montant effectif est calculé depuis la prouesse runtime.

| Adversaire | Technique primaire | Technique spéciale |
| --- | --- | --- |
| Sentinelle | **Estoc d'airain** : 14 physique, portée 1 | **Heurt du rempart** : 18 physique, portée 1, pousse de 1 |
| Rejeton | **Éclat de braise** : 10 feu, portée 2–5, ligne de vue | **Fournaise annoncée** : prépare 14 feu et 4 feu sur deux activations, portée 2–6 ; résolution à l'activation suivante, qui est consommée |
| Molosse | **Morsure du Styx** : 11 physique, portée 1 | **Déchirure funèbre** : 16 physique, portée 1, 3 physique sur deux activations |
| Lamie | **Trait de l'oubli** : 8 ombre, portée 2–6 | **Reflux du Léthé** : 10 ombre, portée 2–5, −1 PM pendant une activation |

Les dégâts périodiques sont fixes et respectent les défenses. Les dégâts directs suivent la prouesse : coefficient 1 pour les primaires, puis 18/14, 1,4, 16/11 et 1,25 pour les spéciales. Le multiplicateur d'expédition existant continue donc d'augmenter réellement les attaques à mesure de la descente.

La Fournaise suit la cible, mais exige encore portée et ligne de vue lors de sa résolution. Rompre cette ligne ou sortir des 2–6 cases annule dégâts et brûlure. Le lanceur ne récupère pas son activation consommée. La correction ciblée de `SpellCaster.resolve_pending_activation()` applique un statut différé uniquement après un impact valide sur une cible encore vivante ; les anciens projectiles sans statut conservent leur comportement.

## IA et placement

Les profils réutilisent les décisions génériques existantes : mêlée pour Sentinelle/Molosse ; distance avec repli pour Rejeton/Lamie. Les cibles, coûts et délais sont revérifiés par `SpellCaster`. Toutes les techniques étant offensives, elles entrent dans la sélection générique de l'IA ; aucune technique de soutien ne reste inutilisable faute de logique dédiée.

La distance minimale de placement vaut `max(5, PM + 3)`, augmentée jusqu'à `portée maximale + 1` pour un tireur. Cela donne 5 cases pour la Sentinelle, 8 pour le Molosse, 7 pour le Rejeton et la Lamie. La distance maximale ajoute 6 cases. Les restrictions de visibilité déjà enregistrées dans les salles restent appliquées. Les formations sont divisées, en double ligne ou sur les flancs.

## Intégration dans la descente

`CatabaseMonsterEncounterCatalog.configure_encounter()` est appelé seulement par `ExpeditionRunFactory.make_room()`, avant la copie et la croissance des statistiques. Les ressources de salles sources et les autres runs ne sont pas modifiées.

Le tutoriel à la profondeur 1, l'épreuve du champion de bronze à la profondeur 7 et les rencontres explicitement marquées `boss`, dont Pâris, gardent leurs compositions originales. Les autres combats normaux/élites utilisent l'intention tactique enregistrée du nœud, sans adapter la composition à la construction du joueur :

| Intention du nœud (`reward`) | Deux premiers adversaires |
| --- | --- |
| Armure, mêlée | Sentinelle + Rejeton |
| Distance, élémentaire | Rejeton + Molosse |
| Mobilité | Molosse + Lamie ; avant profondeur 5 : Molosse + Rejeton |
| Contrôle, soin, découverte | Lamie + Sentinelle ; avant profondeur 5 : Sentinelle + Rejeton |
| Vitalité | Sentinelle + Molosse |
| Signature | Sentinelle + Lamie |

À partir de la profondeur 9, un troisième adversaire s'ajoute : Rejeton si le duo comporte un Molosse, Molosse sinon. Les packs n'ont jamais deux Lamies ni deux Sentinelles. Le plafond vivant correspond exactement aux deux ou trois adversaires ; aucun budget d'invocation ne subsiste sur ces packs. Le format de combat de l'expédition reste une seule vague par nœud.

Croissance conservée : `(1 + max(0, profondeur − 5) × 0,07)`, multipliée par 1,20 pour une élite. Elle modifie uniquement les copies runtime, pas les quatre ressources de base.

## Vérification

Le flux de production artistique est documenté dans [le README du pipeline](../../tools/catabase_monster_sprite_pipeline/README.md) : vues fixes indépendantes par Meshy, revue des sources et remplacements anatomiques, préparation, articulation locale puis assemblage. La commande distante historique de spritesheets est retirée. Les textures ne sont jamais mises en miroir pour remplacer une direction manquante.

L’animation reste une marionnette 2D à mouvements modérés issue d’une seule peinture par direction. Une déformation inverse continue combine de larges influences articulaires avec un échantillonnage RGBA prémultiplié ; le gradient de déplacement borné préserve la continuité de la silhouette. Aucune nouvelle pose n’est repeinte et aucun modèle 3D n’est généré.

Les tests d'intégration se trouvent dans `test/unit/test_catabase_monsters_integration.gd`. Le probe de combat est `tools/catabase_monster_validation/combat_probe.tscn`, piloté par `tools/catabase_monster_validation/combat_probe.gd`. Le résultat d'exécution est à consulter dans le compte rendu de validation ; cette note décrit les contrats et n'affirme pas de réussite de tests non exécutés.
