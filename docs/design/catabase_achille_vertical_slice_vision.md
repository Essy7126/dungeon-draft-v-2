# Vision du vertical slice — Catabase d’Achille

**Statut :** contrat d’alignement P0 pour design, art, code et QA  
**Slice autoritaire :** `data/runs/odyssey.tres`  
**Source de décision :** `docs/audits/etat_espionnage_concurrentiel_2026-08-28.md`  
**Durée visée :** 18–25 minutes, trois salles ordonnées, Achille seul

Ce document distingue volontairement l’existant des critères à atteindre. Il ne vaut pas annonce de sauvegarde, de CI de release, de télémétrie ou d’Archive persistante.

## Promesse en une phrase

> Dans une Catabase courte, Achille lit et détourne les intentions ennemies, ses actions transforment son kit pendant le combat, puis l’Archiviste consigne sans rien inventer ce que sa descente a réellement produit.

## Trois piliers non négociables

| Pilier | Expérience attendue | Ancrage actuel | Contrat du slice |
|---|---|---|---|
| **Intentions lisibles** | « J’ai compris le destin qu’on m’imposait et je l’ai retourné. » | Le Trait d’ombre du Rejeton annonce une cible, 18 dégâts et deux contres : rompre la ligne de vue ou sortir de portée (`data/spells/enemies/catabase/hellspawn_shadow_bolt.tres`). Achille dispose aussi de la poussée via `data/spells/achilles/sweep.tres`. | Toute conséquence critique est visible avant résolution ; le joueur connaît cible, ampleur et contre-jeu avant de valider son tour. |
| **Évolution par l’action** | « Mon comportement tactique a façonné cet Achille. » | Lance, Élan, Horizon et Airain ont chacune un rang 2 à 3 XP et deux choix exclusifs (`data/characters/achilles/disciplines/`). | Le premier choix significatif survient au plus tard pendant la salle II ; l’interface ne montre que le chemin actif et les deux futurs utiles, avec leur breakpoint concret. |
| **Mémoire mythologique** | « Cette tentative avait une histoire vérifiable, même en cas d’échec. » | L’écran de résultat peut restituer progression, salle atteinte, seed disponible et PV d’Achille à partir de faits runtime (`core/run_result_narrative_service.gd`, `ui/run_result_screen.gd`). | Victoire et défaite produisent immédiatement une épitaphe factuelle. Aucune phrase ne doit déduire un exploit non enregistré. Cette mémoire n’est pas encore une Archive persistante. |

Un ajout n’entre dans ce slice que s’il renforce directement au moins un pilier sans brouiller les deux autres.

## Structure verrouillée de la run actuelle

La run commence obligatoirement en salle I, sans choix de route au hub. Sa seed par défaut est `2401`. Le draft de destinations reste hors de ce P0.

| Étape | Contenu actuel | Fonction d’apprentissage | Condition de sortie attendue |
|---|---|---|---|
| **I — Le Rejeton chétif** | Duel contre `catabase_frail_hellspawn` sur l’arène peinte de forêt (`data/rooms/odyssey/room_01.tres`). | Lire le trait retardé, manipuler distance et ligne de vue, découvrir que la poussée peut aussi créer de la sécurité. | Le joueur identifie la créature comme un faible rejeton des Enfers, puis sait nommer la cible, le délai, les 18 dégâts et au moins un contre avant la première résolution. |
| **II — La Porte des Cendres** | Deux skirmishers et un garde, formations seedées, arène grecque à obstacles (`data/rooms/odyssey/room_02.tres`, `data/encounters/odyssey_room_02_encounter.tres`). | Passer du duel à une formation de mêlée ; transformer positionnement et usages répétés en premier choix d’évolution. | Au moins une discipline peut atteindre son rang 2 ; le joueur comprend exactement ce que son choix change dans l’action suivante. |
| **III — Le Jugement de Paris** | Un champion ancre la mêlée pendant que Paris réemploie son trait (`data/rooms/odyssey/room_03.tres`, `data/encounters/odyssey_room_03_encounter.tres`). Arène finale en bronze grec, grille 13×13 (`data/maps/painted/odyssey/room_03_layout.tres`, `data/maps/painted/odyssey/room_03_visual.tres`). | Retourner la règle apprise : échapper au trait tout en subissant la pression d’un protecteur de contact. Le test porte sur la maîtrise combinée, pas sur davantage de systèmes. | La victoire exige lecture, repositionnement et usage du build choisi ; Paris reste l’événement dramatique identifiable de la finale. |
| **Registre de l’Archiviste** | Résultat immédiat, seed si connue, salles franchies, salle atteinte et PV (`ui/RunResultScreen.tscn`), puis retour direct au hub. | Donner une conclusion factuelle à la réussite comme à l’échec. | Le texte correspond exactement à l’état runtime et n’invente ni build, ni exploit, ni cause de victoire. |

Les trois salles restent actuellement des combats d’élimination. Les objectifs distincts, pactes et destinations relèvent de la vraie mini-run P1, pas de ce verrou P0.

## Contrat de lisibilité

1. **Exactitude critique.** Action retardée, conséquence létale, grande zone et invocation doivent annoncer leur cellule ou cible réelle, leur moment de résolution et leur contre-jeu. Le télégraphe du Rejeton en salle I, puis celui de Paris en finale, suivent leur cible vivante et ne doivent jamais devenir un simple décor.
2. **Prévisualisation avant engagement.** Avant validation, l’interface doit exposer dégâts directs, poussée, case finale, collision, réaction de terrain et raison d’invalidité lorsqu’ils s’appliquent. Ce qui n’est pas prévisualisé ne doit pas produire une conséquence majeure inattendue.
3. **Hiérarchie immédiate.** À 1920×1080 sans zoom, héros, ennemis, danger critique et action sélectionnée doivent être distinguables. Une information critique ne dépend jamais de la couleur seule : forme, texte, animation et son la doublent selon le contexte.
4. **Divulgation progressive.** En combat, une évolution montre la discipline concernée, deux choix orthogonaux au maximum et leur effet sur le prochain usage. L’arbre global n’interrompt pas la lecture de la bataille.
5. **Grammaire visuelle unique.** Bronze, cendre et mémoire encadrent la 2,5D peinte. Échelle, ombre de contact, direction de lumière, saturation et VFX d’anticipation restent cohérents entre les trois salles.
6. **Information honnête.** L’épitaphe n’utilise que des faits présents dans le résultat de run. Une seed absente est masquée ; une donnée inconnue n’est jamais remplacée par une formulation plausible.

## Critères de réussite mesurables

| Axe | Seuil d’acceptation du slice |
|---|---|
| **Contenu déterministe** | Les trois salles chargent leurs arènes et rosters attendus ; les formations des salles II et III sont valides sur au moins 20 seeds consécutives. |
| **Compréhension du Rejeton** | Sur un test d’au moins 8 nouveaux joueurs, au moins 80 % identifient avant résolution la cible, les 18 dégâts et un des deux contres du trait dès la salle I. |
| **Justice perçue** | Au moins 90 % des dégâts critiques reçus pendant le test sont expliqués correctement par le joueur après l’événement ; aucun télégraphe affiché ne ment sur sa cible ou sa résolution. |
| **Évolution** | Au moins 90 % des runs atteignant la fin de la salle II déclenchent un choix de rang 2 ; le temps médian de choix reste inférieur à 30 secondes et le joueur peut reformuler son effet. |
| **Maîtrise finale** | La salle III réemploie effectivement le trait de Paris avec le champion vivant ; les causes d’échec permettent de distinguer erreur de lecture, positionnement et manque de dégâts. |
| **Durée** | La médiane des premières runs complètes se situe entre 18 et 25 minutes. Temps médian et p95 par tour sont relevés séparément. |
| **Mémoire factuelle** | Dans 100 % des cas QA victoire/défaite, salles franchies, salle atteinte, seed affichée et PV correspondent aux données runtime ; une seed inconnue reste invisible. |
| **Lecture visuelle** | Sur une capture avec HUD à 1920×1080, au moins 8 observateurs sur 10 désignent sans zoom Achille, les ennemis, le danger prioritaire et l’action sélectionnée. |
| **Stabilité locale** | Import Godot propre et suites ciblées Catabase/Achille sans échec. Une validation locale ne doit pas être présentée comme une CI ou un export de release. |
| **Performance** | CPU, GPU et frame time de la salle la plus chargée sont consignés à 1080p sur bas, milieu et haut de gamme avant toute affirmation de cible matérielle. |

Les mesures de playtest sont un protocole à exécuter ; l’absence actuelle de télémétrie automatisée ne doit pas être masquée par des estimations.

## Hors-périmètre gelé pour ce P0

- nouveaux héros, nouvelles Catabases, nouveaux biomes ou modes secondaires ;
- nouvelles grandes branches de compétences et objets purement statistiques supplémentaires ;
- draft de salles/pactes, économie à plusieurs monnaies, ascensions et challenges quotidiens ;
- refonte totale du moteur, du HUD ou du Studio auteur ;
- génération narrative libre ou épitaphe fondée sur des faits non capturés ;
- Archive historique persistante et hub durablement réactif ;
- sauvegarde/reprise aux frontières de salle ;
- télémétrie de production, pipeline CI de release et export distribuable ;
- promesse de support matériel, manette, remapping ou localisation tant que leur chaîne complète n’est pas validée.

Ces éléments restent nécessaires à des phases ultérieures pour certains d’entre eux ; ils ne sont simplement pas des preuves d’acceptation du slice actuel.

## Risques connus à traiter, pas à dissimuler

- **Lisibilité partielle :** Paris possède une intention critique exacte, mais les intentions futures de tous les ennemis ne sont pas encore un système général.
- **Finale encore légère :** la salle III combine Paris et un champion ; elle ne constitue pas encore un boss transformateur à plusieurs règles. Sa valeur dépend de la pression créée par cette combinaison.
- **Évolution surtout numérique :** les choix actuels modifient dégâts, portée, poussée, bouclier ou mouvement. Ils prouvent la boucle, mais pas encore l’idéal de changements de verbes recommandé par l’audit.
- **Objectifs répétitifs :** les trois salles reposent encore sur l’élimination. Formation, espace et télégraphe portent seuls la variété du P0.
- **Cohérence artistique partiellement prouvée :** les salles II et III ont été validées en capture combat à 1920×1080, avec grille et silhouettes lisibles. La forêt de la salle I, la transition chromatique entre les trois salles et un styleframe commun restent à valider ensemble.
- **Dette de ressource en salle II :** `data/rooms/odyssey/room_02.tres` embarque une définition d’arène volumineuse et des identifiants hérités de `room_05_volcano`, ce qui augmente le risque de divergence à l’édition.
- **Coût GPU :** les personnages fondés sur des `SubViewport` 768×512 en mise à jour continue restent à profiler, notamment sur GPU intégré et Steam Deck.
- **Mémoire volatile :** le registre de fin restitue des faits de la tentative courante, mais ne constitue ni sauvegarde, ni historique, ni Archive persistante.
- **Industrialisation incomplète :** déterminisme complet, sauvegarde, télémétrie, CI de release, export et droits des assets doivent encore être prouvés séparément.

## Garde-fou de production

Avant d’ajouter une mécanique au slice, l’équipe répond « oui » à au moins trois questions : change-t-elle une décision, crée-t-elle du contre-jeu, est-elle visible avant sa conséquence majeure, se réutilise-t-elle dans plusieurs rencontres, peut-elle être mesurée ou testée ? Sinon, elle reste hors scope.

Les ressources autoritaires à vérifier lors de toute modification sont :

- run et ordre : `data/runs/odyssey.tres` ;
- salles : `data/rooms/odyssey/room_01.tres`, `data/rooms/odyssey/room_02.tres`, `data/rooms/odyssey/room_03.tres` ;
- rencontres : `data/encounters/catabase_frail_hellspawn_encounter.tres`, `data/encounters/odyssey_room_02_encounter.tres`, `data/encounters/odyssey_room_03_encounter.tres` ;
- Achille et évolution : `data/units/allies/achilles.tres`, `data/characters/achilles/disciplines/` ;
- intention d'ouverture : `data/units/enemies/catabase_frail_hellspawn.tres`, `data/spells/enemies/catabase/hellspawn_shadow_bolt.tres` ;
- intention finale de Paris : `data/units/enemies/catabase_shadow_paris.tres`, `data/spells/enemies/catabase/paris_shadow_arrow.tres` ;
- finale visuelle : `data/maps/painted/odyssey/room_03_layout.tres`, `data/maps/painted/odyssey/room_03_visual.tres` ;
- résultat immédiat : `core/run_result_narrative_service.gd`, `ui/run_result_screen.gd` ;
- contrats automatisés actuels : `test/unit/test_catabase_cinematic_v4.gd`, `test/unit/test_catabase_vertical_slice_content.gd`, `test/unit/test_catabase_run_chronicle.gd`.
