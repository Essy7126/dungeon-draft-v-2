# Cartes peintes enregistrées sur la grille de combat

Le modèle validé dans la cour grecque est porté par [RegisteredTerrainBattle.tscn](../../battle/painted/registered_terrain/RegisteredTerrainBattle.tscn). La même scène compose le terrain, les vraies dalles de combat, les fosses, le bandeau de terre et les décors. Le biome est déclaré dans un plan JSON ; une nouvelle carte ne nécessite pas une copie du contrôleur de combat.

## Contrat de production Catabase

La run reste [odyssey.tres](../../data/runs/odyssey.tres), nommée Catabase. Les trois salles utilisent désormais le modèle partagé ; la troisième remplace son ancienne carte par une cour funéraire au centre dégagé.

| Salle | Carte | Rencontre référencée |
|---|---|---|
| I — Le Rejeton chétif | [greek_drawn_courtyard_v1](../../data/arenas/greek_drawn_courtyard_v1/terrain_plan.json) | [catabase_frail_hellspawn_encounter](../../data/encounters/catabase_frail_hellspawn_encounter.tres), un ennemi |
| II — La Porte des Cendres | [ashen_hell_courtyard_v1](../../data/arenas/ashen_hell_courtyard_v1/terrain_plan.json) | [odyssey_room_02_encounter](../../data/encounters/odyssey_room_02_encounter.tres), deux escarmoucheurs et un Spectre errant (roster courant) |
| III — Le Jugement de Paris | [silent_judgment_courtyard_v1](../../data/arenas/silent_judgment_courtyard_v1/terrain_plan.json), cour funéraire au centre dégagé | [odyssey_room_03_encounter](../../data/encounters/odyssey_room_03_encounter.tres) |

Les rencontres sont référencées par leur ressource courante, indépendamment du terrain. Pendant cette promotion, la tâche de création du Spectre errant a remplacé le garde de la salle II par `spectre_greatsword` ; le renderer et le runner lisent ce roster sans le recopier ni le figer. La promotion des maps conserve les chemins de rencontre, pas une ancienne liste d'ennemis.

Les ressources des salles I, II et III sont des `ArenaDefinition`, avec leur rencontre, leurs récompenses et leurs zones de déploiement. Leur champ `registered_terrain_plan_path` choisit le biome ; `battle_scene` pointe vers la scène partagée. Le runtime accepte également un override explicite de ce chemin sur la scène, utile aux outils. Une salle normale doit porter son choix dans sa ressource.

## Une autorité géométrique

Le modèle courant utilise un canevas natif de **1920 × 1200**, avec `axis_x = (51.6, 25.8)`, `axis_y = (-51.6, 25.8)` et `grid_origin = (830.676793205, 46.528936910)`. La projection est isométrique 2:1. La caméra adapte l'ensemble au viewport ; on ne déforme pas séparément le terrain et les dalles.

Les cellules de l'`ArenaDefinition` commandent le sol jouable, les obstacles, le placement et les clics. Le gabarit Catabase conserve **217 dalles**. `geometry_manifest.json` décrit le contour et les cinq groupes de fosses ; ces dernières sont des annotations artistiques de cellules déjà `HOLE`, sans dalle ni clic. Une fosse peut rejoindre le bord extérieur : sa connectivité seule ne détermine pas sa représentation.

Le plan de terrain décrit la terre, les berges et les pieds de massifs. Les dalles complètes doivent tenir dans cette terre et hors des exclusions de rochers. Les couronnes d'arbres ne deviennent pas automatiquement des exclusions. Les sprites, les highlights, les empreintes des unités et les arêtes des fosses doivent partager la même projection.

Le bandeau est un dessin de sol, sans collision et sans nouvelle case. Il entoure le domaine de combat fusionné, avec une largeur de **0,42 cellule** mesurée avant projection et un retrait minimal de **20 px natifs** aux rives. Il n'ajoute ni plateforme verticale ni contour distinct autour de chaque obstacle. Les fosses et dalles existantes recouvrent sa partie intérieure.

## Contenu d'un package

Un package de carte regroupe :

- une ressource `ArenaDefinition` et ses cellules/obstacles/décors ;
- `geometry_manifest.json`, synchronisé avec cette définition ;
- `terrain_plan.json`, qui choisit le terrain et la palette ;
- les images originales du biome dans `asset/map/painted/...` ;
- des références de décors partageant les mêmes coordonnées natives.

Le renderer de production se trouve dans [registered_terrain](../../battle/painted/registered_terrain/). Les scripts et shaders du laboratoire restent utiles à l'historique et aux essais ; une nouvelle ressource de production doit référencer les composants partagés de ce dossier.

## Plan de terrain

Le plan est un JSON `version: 1`. Les principales entrées sont les suivantes.

| Entrée | Contrat |
|---|---|
| `canvas_size` | `[largeur, hauteur]` du repère natif |
| `geometry_manifest_path` | Facultatif ; chemin `res://`, absolu ou relatif au dossier du plan. Défaut : `geometry_manifest.json` |
| `land_polygon` | Contour fermé de terre, points natifs ; aucune grille peinte dans cette géométrie |
| `land` | `color`, `texture_path`, `texture_scale`, `texture_repeat`, `tint` facultatif |
| `water` | Couleur, texture et éventuellement `shader_path` / paramètres du matériau |
| `shorelines` | Liste de `{points, width, color}`, en coordonnées natives |
| `soil_patches` | Polygones de variations de terrain, avec couleur ou texture facultative |
| `excluded_floor_polygons` | Liste de `{id, polygon}` représentant des pieds de rochers interdits au dallage |
| `world_decor` | Images ou scènes de décor, ancrées dans le même repère ; liste vide pour III |
| `ground_details` | Détails procéduraux et contacts ; `enabled: false` les désactive pour III |
| `floor_palette` | `shade`, `body`, `light`, `warmth`, `painted_steps`, `bevel_flatten_strength`, `shader_parameters` facultatifs, dont `interior_joint_land_weight` |
| `pit_palette`, `props_palette` | Couleurs des fosses et des objets dessinés, lues par leurs composants partagés |
| `combat_ground_band` | `enabled`, `width_cells`, `minimum_shore_clearance_native_px`, shader et paramètres facultatifs |

`texture_scale` exprime les unités natives par pixel de texture ; la terre et les matériaux des dalles restent liés à la même instance de texture, à la même échelle, à la même teinte et au même réglage de répétition. La couleur des joints peut utiliser la terre neutre du bandeau avec le paramètre local décrit ci-dessous. La terre du bandeau est également partagée avec le raccord extérieur des dalles. Une peinture unique ne doit pas introduire un deuxième contour de plateau ou des dalles intégrées dans son image.

Pour un décor d'atlas :

```json
{
  "id": "tree_foreground_left",
  "texture_path": "res://asset/map/painted/greece/greek_drawn_courtyard_v1/environment_clusters_v4.png",
  "region_px": [0, 518, 740, 506],
  "anchor": [378, 973.5],
  "pivot": [0.500443243, 0.875748165],
  "scale": 0.589622642,
  "layer": "foreground"
}
```

Le pivot est **normalisé dans la région**, et l'ancre représente le point choisi au sol. Mesurer les limites alpha avant le placement ; ajuster l'échelle uniformément. Une région d'atlas ne doit pas couper la silhouette ni contenir un fragment du groupe voisin. `layer` vaut `back`, `y_sorted` ou `foreground`. Une scène de décor peut utiliser `scene_path` avec `anchor_grid: [i,j]` ; son origine est déjà son point au sol. Ne pas dupliquer un obstacle tactique dans `world_decor`.



Pour un atlas RGB préparé sur un fond magenta, `chroma_key` accepte `color`, `threshold`, `softness` et `magenta_despill` (0 par défaut, 1 dans la Porte des Cendres). Le dernier paramètre retire la contamination rouge/bleue des pixels mélangés avec le fond et atténue leur alpha. Il est réservé aux décors détourés au magenta ; les images avec alpha natif conservent leur alpha et ignorent ce shader. Vérifier le résultat dans la scène complète, car un fond apparemment uni dans l'atlas peut laisser des franges colorées.

## Variante avec centre dégagé

La salle III conserve le paysage dans le passage natif de terrain, sous les dalles et les unités. Elle retire les couches cosmétiques séparées : aucun sprite de premier plan, aucun segment de banc extérieur et aucun contact procédural. Les douze obstacles tactiques restent déclarés et rendus par la grille.

```json
{
  "world_decor": [],
  "ground_details": {"enabled": false},
  "floor_palette": {
    "shader_parameters": {"interior_joint_land_weight": 0.0}
  }
}
```

`interior_joint_land_weight` vaut `1.0` par défaut et conserve le rendu des salles I et II. À `0.0`, les joints intérieurs utilisent `gb_soil`, avec les couleurs `band_earth`, `band_light` et `band_shadow` du plan. La texture de pierre, son alpha, les sommets et la liaison des matériaux à `Land` restent inchangés. Cette option empêche les motifs peints de Land de colorer les joints ; elle ne garantit pas à elle seule une bonne composition de la peinture. Les masses du paysage doivent rester hors du centre tactique et aucun brouillard ne passe devant les unités.

## Recette pour un nouveau biome

1. Dupliquer le package de données validé, lui attribuer un identifiant propre et conserver d'abord la topologie des cellules, la projection, les fosses et les marges aux rives.
2. Produire une peinture de terrain et des décors cohérents, puis contrôler leurs dimensions, leur alpha et leurs pieds. Le terrain ne contient aucune seconde grille. Conserver des masses simples et une lumière commune.
3. Modifier le plan du nouveau package : chemins d'images, couleurs de terre/eau, palettes du dallage, fosses, objets et bandeau. Réutiliser les composants de production, puis vérifier les joints de matière dans une capture réelle.
4. Affecter `registered_terrain_plan_path` et `RegisteredTerrainBattle.tscn` à la ressource de salle, tout en conservant sa rencontre et ses règles de progression. Adapter uniquement les zones de déploiement nécessaires à la grille validée.
5. Synchroniser les données runtime dérivées avec `ArenaRuntimeBridge.sync_runtime_resources(arena)` et sauvegarder la ressource via `ResourceSaver.save`. Pour les salles I et II, le script ciblé reste [prepare_catabase_registered_rooms.gd](../../test/support/prepare_catabase_registered_rooms.gd). Pour III, la scène [PrepareCatabaseJudgmentRoom.tscn](../../test/support/PrepareCatabaseJudgmentRoom.tscn) synchronise et sauvegarde uniquement `room_03.tres`, en contrôlant la conservation de sa rencontre et de son économie. Exécuter ces préparations après import. Cette préparation de contenu doit être explicite ; le runner QA ne sauvegarde aucune salle.
6. Importer les ressources dans Godot, puis lancer le runner GPU ci-dessous. Corriger toute erreur de géométrie, de formation, de matière ou de progression avant la revue visuelle des captures.
7. Revoir le dallage, la bande de terre, les contacts des décors, les fosses et les marges dans les résolutions réellement capturées. Une validation numérique seule ne prouve pas la qualité du dessin.

Pour préparer la salle III après import, avec le chemin local de Godot affecté à `$registeredGodot` :

```powershell
& $registeredGodot --headless --path 'C:/Users/paolo/Documents/dungeon-draft-v-2' 'res://test/support/PrepareCatabaseJudgmentRoom.tscn'
```

## Aperçu jouable d’une carte

[MapPreview.tscn](../../tools/registered_terrain_validation/MapPreview.tscn) ouvre une ressource `ArenaDefinition` avec le renderer de production et le profil de héros Catabase courant. Il duplique la ressource en mémoire et ne sauvegarde aucune modification de campagne. Depuis PowerShell, après avoir affecté le chemin local de Godot à `$registeredGodot` :

```powershell
& $registeredGodot --path 'C:/Users/paolo/Documents/dungeon-draft-v-2' 'res://tools/registered_terrain_validation/MapPreview.tscn' -- --room='res://data/rooms/odyssey/room_01.tres'
```

Remplacer `room_01.tres` par `room_02.tres` pour la carte infernale ou `room_03.tres` pour la cour du jugement silencieux. L’option utilisateur `--capture=res://artifacts/map_preview/capture.png` active le déploiement automatique, attend quatre secondes, enregistre une capture puis ferme l’aperçu. Sans cette option, la session reste jouable. Cet aperçu sert à la revue visuelle ; seul le runner suivant contrôle aussi les invariants et les transitions de la run.

## Runner QA de production

Le point d'entrée est [RegisteredTerrainQARunner.tscn](../../tools/registered_terrain_validation/RegisteredTerrainQARunner.tscn), accompagné de [son runner](../../tools/registered_terrain_validation/registered_terrain_qa_runner.gd) et d'oracles indépendants dans le même dossier.

Depuis PowerShell, avec le chemin local de Godot affecté à `$registeredGodot` :

```powershell
& $registeredGodot --path 'C:/Users/paolo/Documents/dungeon-draft-v-2' 'res://tools/registered_terrain_validation/RegisteredTerrainQARunner.tscn' -- --resolution=1920x1080 --output='C:/Users/paolo/Documents/dungeon-draft-v-2/artifacts/registered_terrain_validation/1920x1080'
```

Le runner requiert une sortie GPU. Il enregistre la résolution demandée et les dimensions effectives de chaque capture : une fenêtre maximisée ne constitue pas une preuve à la résolution demandée. Un dossier de sortie distinct évite de mélanger deux passes.

Il démarre la vraie run via `GameManager.configure_next_run` puis `start_configured_run`, ouvre chaque combat via `start_next_battle` et attend `runtime_ready_state` ainsi que `registered_terrain_ready` pour les trois cartes composées. Il place le héros par le contrôleur de déploiement réel.

Dans chacune des trois salles, les oracles vérifient :

- la bonne scène, le bon plan, les unités de la rencontre réellement instanciées et leurs ancres ;
- les 217 sprites de dalles, leurs sommets, leurs arêtes communes, les highlights, les empreintes d'unité et neuf points de picking intérieurs par dalle ;
- les cellules absentes, les cinq groupes de fosses et l'absence de murs intérieurs parasites ;
- le support des polygones complets par la terre et les exclusions de pieds de massifs ;
- les matériaux vivants des dalles et leur identité de texture avec `Land` ;
- la largeur et l'ordre de dessin du bandeau, ses marges aux rives, son absence de collision et l'absence de surfaces superposées ;
- un déplacement réel et un sort personnel de garde découvert par `is_self_only()` et `get_scaled_shield(hero) > 0`, avec occupation des cellules, dépenses effectives de PM/PA, usages, cooldown, disponibilité et delta du bouclier sourcé réellement produits. Le calcul tient compte du scaling et du multiplicateur de création ; les bonus supplémentaires de doctrine ou relique restent autorisés.

Les coordonnées d'interaction proviennent des sprites affichés, puis passent par `GridView.update_hover` et `click_at`, leurs signaux et les contrôleurs de `Battle`. **Le routage de la souris Windows n'est pas testé.** Les coûts et le sort de bouclier sont lus sur l'unité courante ; les oracles ne remplacent pas les règles du combat.

Dans les salles I et II seulement, la victoire est **explicitement forcée pour la QA** par `Battle._end_battle(true)` après ces actions. La salle III conserve son état de combat après son déplacement et sa garde ; aucune victoire ni transition de fin de run ne sont forcées dans cette salle. Le runner vérifie le rapport post-combat, le refus de progression avant récompense, l'application d'une vraie relique/équipement via `confirm_post_combat_equipment`, puis l'acceptation de `complete_post_combat_transition`. Il n'écrit jamais `current_room_index` et ne court-circuite pas `_go_to_next_room`. Cette preuve atteste la transition de production, pas une victoire jouée intégralement ni l'équilibrage des rencontres.

Dans la salle III, [quiet_center_checks.gd](../../tools/registered_terrain_validation/quiet_center_checks.gd) contrôle en plus le plan et les nœuds vivants : `world_decor` vide, absence de décors cosmétiques et de sprites non classés dans le monde, aucun remplissage de `GroundDetails`, douze cellules obstacles avec leurs visuels et 217 matériaux portant `interior_joint_land_weight = 0.0`. Les dalles doivent être au-dessus de `Land`. Ce contrôle ne certifie pas la qualité des motifs présents dans la peinture ; une revue GPU reste nécessaire.

La définition de la run conserve son empreinte SHA-256 préalable à la promotion. Les fichiers des salles I et II ainsi que les trois rencontres sont observés au début et à la fin de la passe et doivent rester identiques. Les chemins de rencontre et leurs rosters courants sont vérifiés dans chaque salle. Les anciennes empreintes des rencontres restent informatives, car des travaux concurrents ont ajouté des champs de contenu et intégré le Spectre errant dans la rencontre II. La salle III est désormais contrôlée contre son nouveau package, sa rencontre existante et le contrat de centre dégagé ; son ancienne scène et son ancienne empreinte ne constituent plus le contrat courant.

Le dossier de sortie contient `registered_terrain_report.json` et six captures : combat puis après mouvement/garde pour chacune des trois salles. Un code de sortie zéro exige un rapport `ok: true`, trois salles chargées, trois couples déplacement/garde réussis et deux transitions. La salle III est contrôlée encore en combat avant la fermeture du processus QA. Les captures seules ne constituent pas un succès. Le runner est borné à 180 secondes et produit aussi un rapport partiel si un contrôle échoue.

## Extension à trois cartes — 5 septembre 2026

La [passe GPU à 1920 × 1080](../../artifacts/catabase_third_map_2026-09-05/1920x1080/registered_terrain_report.json) passe avec trois salles composées, trois déplacements et gardes réussis, deux transitions et six captures. La salle III reste en combat après ses actions. Son oracle confirme zéro décor cosmétique, zéro remplissage de contact, douze obstacles tactiques et 217 matériaux avec des joints neutres. La [suite GUT ciblée](../../artifacts/catabase_third_map_2026-09-05/gut_maps.log) passe **13 tests / 5 565 assertions**. Les signalements de ressources non libérées à la fermeture restent présents dans ce journal.


La [passe complémentaire en 1200 × 896](../../artifacts/catabase_third_map_2026-09-05/1200x896_exact/registered_terrain_report.json) passe également : trois salles, trois déplacements et gardes, deux transitions et **six captures aux dimensions exactes**. La [capture de III en petite fenêtre](../../artifacts/catabase_third_map_2026-09-05/1200x896_exact/room_03_combat_1200x896.png) a été inspectée ; le plateau et les unités restent lisibles. Une première passe compacte avait changé de taille native en III ; le runner rétablit désormais le mode fenêtré après chaque chargement et refuse les captures de taille différente. Cette reprise exacte constitue la preuve compacte.

Le bilan ci-dessous est conservé comme **historique de la première promotion, limitée aux salles I et II**. Ses assertions de conservation de l’ancienne salle III et ses cinq captures décrivent cet état antérieur ; elles ne décrivent pas le contrat actuel de la cour du jugement silencieux.

## Validation de la promotion — 5 septembre 2026

La [comparaison des données natives](../../artifacts/catabase_registered_maps_2026-09-05/geometry_inheritance_report.json) passe ses **35 contrôles** : projection, cellules, fosses, obstacles, spawns, terre, rives et largeur du bandeau sont identiques entre les deux packages.

La [passe GUT finale](../../artifacts/catabase_registered_maps_2026-09-05/gut_current_with_spectre.log), après l'intégration du Spectre errant, passe **21 tests / 3 845 assertions**. Elle couvre les maps, la persistance Studio, les formations, le Rejeton, la frontière entre combats et les boucliers sourcés.

| Parcours GPU de production | Résultat | Preuve |
|---|---|---|
| 1920 × 1080 | Trois salles chargées, deux transitions, cinq captures, aucune erreur d'oracle | [Rapport](../../artifacts/catabase_registered_maps_2026-09-05/current_1920x1080/registered_terrain_report.json) |
| 1200 × 896 | Trois salles chargées, deux transitions, cinq captures, aucune erreur d'oracle | [Rapport](../../artifacts/catabase_registered_maps_2026-09-05/current_1200x896/registered_terrain_report.json) |

Les deux cartes ont chacune leurs **217 vraies dalles**, des arêtes et empreintes alignées, leurs matériaux raccordés à Land et au bandeau, et une marge de rive minimale de **26,434 px natifs**. Le déplacement réel consomme les PM attendus ; la garde consomme ses PA et crée ou renforce son bouclier sourcé. La rencontre II contient le roster courant de deux escarmoucheurs et un Spectre errant. Les empreintes des rencontres restent stables durant chaque passe ; celles de la run et de la salle III correspondent au contrat antérieur à cette promotion.

Les captures inspectées comprennent la [map infernale dans la run en 1920 × 1080](../../artifacts/catabase_registered_maps_2026-09-05/current_1920x1080/room_02_combat_1920x1080.png) et en [1200 × 896](../../artifacts/catabase_registered_maps_2026-09-05/current_1200x896/room_02_combat_1200x896.png), avec le nouveau spectre. Le premier plan ne présente plus la frange magenta détectée dans le premier aperçu.

Le parcours a détecté puis permis de corriger un défaut réel entre deux combats : les `SpellCaster` réutilisent leurs IDs locaux alors que l'unité persiste. Le cache `Unit._resolved_combat_effects` est désormais vidé dans `reset_combat_resources()`. Le [test de non-régression](../../test/unit/test_combat_effect_dedup_lifecycle.gd) a échoué avant cette correction puis passé après ; il conserve la déduplication pendant un même combat, y compris entre activations. Une compatibilité de construction du glossaire est également corrigée avec `SpellCaster.new(null, null, null)`.

**Limites :** les victoires sont forcées par la QA après les vrais déplacement et garde ; les récompenses et transitions passent ensuite par les API de production. Ces preuves ne certifient ni une victoire jouée entièrement, ni l'équilibrage, ni le routage de souris Windows. Une ancienne suite `test_odyssey_achilles_solo_run.gd` a aussi été essayée : 9/20 tests passent ; ses attentes sur l'ancien kit, les vues 3D et l'économie ne correspondent plus aux changements concurrents. Elle n'est pas présentée comme une validation globale. Les processus Godot signalent encore des ressources non libérées à la fermeture.
