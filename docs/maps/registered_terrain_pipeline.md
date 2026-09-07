# Cartes peintes enregistrées sur la grille de combat

Le modèle utilise [RegisteredTerrainBattle.tscn](../../battle/painted/registered_terrain/RegisteredTerrainBattle.tscn). Une scène partagée compose le terrain, les vraies dalles de combat, les fosses, le bandeau de terre et les décors à partir d'un plan JSON. Chaque nouvelle carte porte sa propre topologie et son biome, sans copier le contrôleur de combat.

## Contrat de production Catabase

La run [odyssey.tres](../../data/runs/odyssey.tres), nommée Catabase, comporte désormais **cinq salles**, dans cet ordre :

| Salle | Carte | Rencontre |
|---|---|---|
| I — Le Rejeton chétif | [La Cour des Sources](greek_drawn_courtyard_v1.md) | `catabase_frail_hellspawn_encounter.tres` |
| II — La Porte des Cendres | [La Porte des Cendres](ashen_hell_courtyard_v1.md) | `odyssey_room_02_encounter.tres` |
| III — Le Jugement silencieux | [Le Parvis du Jugement](silent_judgment_courtyard_v1.md) | `odyssey_room_03_encounter.tres` |
| IV — Le Gué du Léthé | [Le Gué du Léthé](lethe_crossing_v1.md) | `catabase_room_04_encounter.tres` |
| V — Le Temple du Serment Noir | [Le Temple du Serment Noir](black_oath_temple_v1.md) | `catabase_room_05_encounter.tres` |

La salle V clôt la run avec Paris, boss à deux formes, accompagné des deux spectres déjà présents dans cette rencontre. Paris est absent des quatre salles précédentes ; la salle III accueille un Champion et un spectre. Les rencontres sont des ressources indépendantes du terrain et le runner vérifie leurs rosters courants, sans les recopier. La fin de run dépend de la dernière entrée de `RunData.rooms` ; IV devient une salle intermédiaire avec récompense d'équipement avant V.

Chaque salle est une `ArenaDefinition` avec rencontre, récompenses et zones de déploiement. `registered_terrain_plan_path` sélectionne son plan ; `battle_scene` sélectionne la scène partagée. Un override explicite du plan sur la scène reste disponible aux outils. Une salle normale porte son choix dans sa ressource persistée.

## Une autorité géométrique

Le canevas natif est **1920 × 1200**. Les axes `(51.6,25.8)` et `(-51.6,25.8)` donnent une projection dimétrique 2:1 et des dalles de 103,2 × 51,6 px natifs. La caméra transforme l'ensemble : terrain, dalles, obstacles, highlights et clics partagent le même repère.

Les trois premières cartes conservent leur topologie commune de 217 dalles et leur origine `(830.676793205,46.528936910)`. IV possède 114 dalles ; V en possède 152. Ces deux cartes varient le contour, les fosses, les obstacles et l'origine. **217 n'est pas une constante du renderer ni un objectif pour les futures cartes.** Le manifeste de chaque package décrit les listes canoniques et les comptes attendus ; les oracles recomptent les listes et les confrontent aux éléments réellement rendus.

Les cellules de l'`ArenaDefinition` commandent le sol jouable, les obstacles, le placement et les clics. Les fosses annotent des cellules sans dalle ni clic. Les polygones complets des dalles doivent tenir sur la terre et rester hors des exclusions de rochers ; contrôler leurs centres seulement serait insuffisant. Les surfaces jouables doivent rester connectées après exclusion des obstacles.

Le bandeau est du dessin de sol sans collision. Il suit l'union des dalles et fosses vérifiées, sur **0,42 cellule**. En extérieur, sa distance aux rives réelles respecte le minimum déclaré, actuellement **20 px natifs**. Il ne crée ni case, ni plateforme verticale, ni bordure supplémentaire autour de chaque obstacle. L'intérieur sans rive possède un contrat distinct décrit ci-dessous.

## Contenu d'un package

- `arena.tres` : cellules, obstacles, projection, rencontre de test et présentation ;
- `geometry_manifest.json` : topologie canonique, projection, fosses, spawns, compteurs et contraintes d'auteur ;
- `terrain_plan.json` : terre, rives, matières, palettes et décor ;
- images originales et prompts dans `asset/map/painted/...` ;
- outil de préparation de la salle et, pour une nouvelle topologie, générateur géométrique reproductible et guides.

Les scripts et shaders de production résident dans [registered_terrain](../../battle/painted/registered_terrain/README.md). Le laboratoire conserve les essais historiques ; les nouvelles scènes utilisent les composants partagés.

## Plan de terrain

Le plan est un JSON `version:1`.

| Entrée | Contrat |
|---|---|
| `canvas_size` | Taille du repère natif |
| `geometry_manifest_path` | Chemin explicite facultatif ; défaut : manifeste voisin |
| `land_polygon` | Contour natif de terre ou du sol intérieur, sans grille peinte |
| `land`, `water` | Couleur, texture, échelle, répétition, teinte et shader facultatif |
| `shorelines` | Tableau explicite de polylignes natives ; `[]` pour un intérieur sans rive |
| `allowed_floor_polygon` | Réserve de composition facultative, contrôlée par l'oracle de support |
| `minimum_floor_margin_px` | Distance minimale des dalles complètes à la limite de cette réserve |
| `minimum_floor_shore_clearance_native_px` | Contrainte extérieure facultative mesurée sur les rives réellement rendues |
| `excluded_floor_polygons` | Pieds de massifs interdits aux dalles |
| `world_decor` | Scènes ou images ancrées dans le repère ; vide pour III, IV et V |
| `ground_details` | Détails procéduraux ; désactivés pour III, IV et V |
| `floor_palette`, `props_palette`, `pit_palette` | Palettes des éléments de combat |
| `combat_ground_band` | Largeur, marge et palette du raccord |
| `soil_patches` | Variations de terrain facultatives hors des réserves calmes |

Une peinture complète utilise `texture_scale:[1,1]` et `texture_repeat:false`. Les matériaux des dalles partagent l'instance de texture Land, son échelle, sa teinte et son réglage de répétition. Aucun raster ne redéfinit les collisions ou le contour tactique.

Pour un décor d'atlas, `region_px` délimite le fragment et `pivot` est normalisé dans cette région ; `anchor` donne son point natif au sol. Pour une scène, `anchor_grid` réutilise la grille. Mesurer la silhouette entière, son alpha et son ombre : une ancre extérieure ne prouve pas l'absence de recouvrement. Ne jamais dupliquer un obstacle tactique dans le décor. Les détails des couches, contacts et détourage chromatique sont décrits dans le [README du renderer](../../battle/painted/registered_terrain/README.md).

### Intérieur sans rive

Le [plan du temple](../../data/arenas/black_oath_temple_v1/terrain_plan.json) couvre tout le canevas avec Land et déclare `shorelines:[]`. Sa réserve autorisée va de `(320,200)` à `(1600,950)`, avec une marge minimale de dalle de 60 px natifs. Aucune contrainte `minimum_floor_shore_clearance_native_px` n'est déclarée.

Les oracles exigent alors zéro rive déclarée **et** zéro nœud de rive rendu. Les mesures aux berges portent `shoreline_clearance_applicable:false` et une distance `null` : **N/A**, aucune fausse rive n'est créée au bord de l'image. Les vérifications de support restent actives : chaque dalle complète dans Land et la réserve, marge à la réserve, exclusions éventuelles, et bandeau contenu dans Land comme dans la réserve. Le retrait de construction du bandeau au contour de Land reste distinct d'une distance à une berge réelle.

## Centre de combat dégagé

III, IV et V retirent les couches cosmétiques séparées : aucun sprite de premier plan ni banc extérieur. Les obstacles tactiques restent déclarés et rendus par la grille.

```json
{
  "world_decor": [],
  "ground_details": {"enabled": false},
  "floor_palette": {
    "shader_parameters": {"interior_joint_land_weight": 0.0}
  }
}
```

À `0.0`, les joints intérieurs utilisent la terre neutre du bandeau. Le défaut `1.0` préserve le rendu des salles I et II. Cette option change la couleur des joints, sans modifier les sommets, l'alpha, la pierre ou le gameplay. Elle ne peut pas corriger une masse peinte dans le combat : la peinture et l'assemblage final nécessitent une revue visuelle.

## Recette d'une nouvelle carte

1. Choisir une silhouette tactique et ses passages. Définir les cellules, obstacles, fosses et spawns dans un générateur ou des données explicites. Pour une variation de topologie, ne pas conserver les anciens compteurs ou les anciennes sondes de calibration.
2. Vérifier la connectivité des cases praticables, la largeur des passages et les distances des formations. Produire le manifeste et l'`ArenaDefinition` depuis cette autorité.
3. Placer le sol autour de l'enveloppe complète du dallage et du bandeau, avec une marge suffisante. Définir la réserve de composition et les pieds de massifs exclus. Déclarer les rives réelles en extérieur ou un tableau vide pour un intérieur.
4. Créer le paysage et ses matières, puis contrôler dimensions, silhouettes et positions. Le paysage ne contient ni seconde grille, ni plateforme de combat peinte.
5. Configurer le plan : assets, palettes, matières, bandeau et décor. Vérifier le raccord extérieur et les joints dans une capture réelle. Contrôler le cadrage avec le HUD visible avant et après les actions.
6. Rattacher le plan, la scène et la rencontre à la salle. Synchroniser les données dérivées avec `ArenaRuntimeBridge.sync_runtime_resources`, puis sauvegarder explicitement avec contrôle du snapshot de gameplay.
7. Importer, préparer la salle, exécuter les tests ciblés et les oracles GPU. Revoir les captures aux dimensions exactes demandées. Comparer les proportions entre résolutions et corriger toute erreur avant de déclarer la carte validée.

Depuis la racine du projet, après import, préparer V :

```powershell
Godot --headless --path . res://test/support/PrepareCatabaseBlackTempleRoom.tscn
```

Les préparations précédentes restent disponibles : `prepare_catabase_registered_rooms.gd` pour I/II, `PrepareCatabaseJudgmentRoom.tscn` pour III et `PrepareCatabaseLetheRoom.tscn` pour IV, toutes sous `test/support`. Chaque préparateur cible ses salles ; le runner QA ne sauvegarde aucune ressource de salle.

## Aperçu jouable

[MapPreview.tscn](../../tools/registered_terrain_validation/MapPreview.tscn) ouvre une salle avec le renderer et le héros Catabase courants. Il duplique les ressources en mémoire.

```powershell
Godot --path . res://tools/registered_terrain_validation/MapPreview.tscn -- --room=res://data/rooms/odyssey/room_05.tres
```

Sans `--capture`, la session reste jouable. `--capture=res://artifacts/map_preview/room_05.png` active le déploiement automatique, attend quatre secondes, capture puis ferme l'aperçu.

## Cadrage et proportions

La caméra cadre le rectangle complet de la peinture. Son zoom uniforme est `max(largeur_fenêtre / largeur_canevas, hauteur_fenêtre / hauteur_canevas)`, multiplié par les réglages de zoom de la peinture et de la présentation. Sa position est le centre du canevas plus leurs décalages. Ce calcul couvre le canevas ; il ne réserve pas automatiquement les panneaux du HUD et ne recadre pas selon le nombre de dalles.

L'échelle d'unité est un calcul distinct. Avec les axes actuels, le facteur de grille vaut 1,5 ; la base de vue `0.58` donne une racine à `0.87`. Le profil d'Achille garde sa base `1.58`, multipliée par le réglage global de présentation `1.08`, soit `1.7064` pour son visuel optionnel. Les autres familles conservent leurs profils propres. Le zoom uniforme s'applique aux unités et aux dalles ensemble : il ne change pas leur ratio. Changer seulement la topologie ne change donc pas la taille relative des personnages.

V demande dans [presentation.tres](../../data/arenas/black_oath_temple_v1/presentation.tres) un décalage **local** `camera_offset_adjustment = Vector2(160,0)` vers la droite de la caméra, afin de déplacer le plateau vers la gauche à l'écran et libérer l'inspecteur. L'option locale `camera_keep_painting_in_view = true` borne ce décalage à la marge réellement disponible dans la peinture après cadrage : aucune bande noire ne doit apparaître lorsque l'inspecteur est fermé. Le décalage horizontal effectif vaut donc 0 en 1920 × 1080 et environ 156,429 px natifs en 1200 × 896. La validation porte sur ces deux contraintes ensemble : peinture couvrant le cadre et plateau dégagé des panneaux visibles. Le multiplicateur de caméra reste `1.0`, celui des unités `1.08` et le profil partagé d'Achille reste inchangé.

L'[oracle de cadrage](../../tools/registered_terrain_validation/framing_proportion_checks.gd) mesure V avant et après déplacement/garde. Il projette les 152 polygones de dalle vivants, relève la caméra, puis teste le cadre de fenêtre et les surfaces visibles du HUD. Il lit les pixels alpha de la pose courante des sprites pour mesurer les silhouettes d'unités, leur hauteur relative aux dalles et leur éventuel masquage. Les compteurs de dalle restent issus du manifeste pour les contrôles topologiques.

La comparaison entre deux passes porte sur les bases transformées de chaque vue et de son visuel, normalisées par la largeur réelle de sa dalle, ainsi que sur son échelle de présentation. La tolérance relative est de **0,2 %**. Les hauteurs opaques sont des instantanés dépendant de l'animation et ne servent pas de référence anatomique rigide. Les masques HUD sont des rectangles conservateurs ; les effets créés par shader, les futures positions de combat et les masses peintes dans Land nécessitent encore une revue visuelle.

## Runner QA des cinq salles

[RegisteredTerrainQARunner.tscn](../../tools/registered_terrain_validation/RegisteredTerrainQARunner.tscn) démarre la vraie run via GameManager et traverse les cinq cartes. Il restaure la fenêtre à la taille demandée après chaque chargement, attend sa stabilisation et refuse les captures d'autres dimensions.

Première passe :

```powershell
Godot --path . res://tools/registered_terrain_validation/RegisteredTerrainQARunner.tscn -- --resolution=1920x1080 --output=res://artifacts/registered_terrain_validation/1920x1080
```

Seconde passe, après réussite de la première et avec le même état de la carte :

```powershell
Godot --path . res://tools/registered_terrain_validation/RegisteredTerrainQARunner.tscn -- --resolution=1200x896 --output=res://artifacts/registered_terrain_validation/1200x896 --compare-report=res://artifacts/registered_terrain_validation/1920x1080/registered_terrain_report.json
```

Un dossier distinct est nécessaire pour chaque passe. Sans `--compare-report`, le rapport indique `cross_resolution_framing.status: "not_requested"` ; une passe seule ne certifie pas la stabilité entre deux résolutions. Les oracles vérifient :

- les cinq chemins de salle ordonnés, les plans, les rencontres et les unités réellement instanciées ;
- la topologie de IV différente de III, et les compteurs recalculés depuis les listes de chaque manifeste ;
- les sprites, sommets, arêtes partagées, highlights, empreintes et points de picking ;
- les dalles complètes dans Land et la réserve autorisée, les marges et exclusions, et les distances aux berges lorsqu'elles existent ;
- les matériaux vivants liés à Land, le bandeau, ses marges, son ordre de dessin et son absence de collision ;
- le centre calme de III, IV et V : aucun décor séparé, joints neutres et obstacles tactiques attendus ;
- dans chaque salle, un déplacement et une garde réels, avec occupation, dépenses de PM/PA, usages et bouclier sourcé ;
- en V, le cadrage réel et les silhouettes avant/après actions, puis les proportions entre résolutions lorsque le rapport précédent est fourni.

Les points d'interaction partent des sprites affichés puis passent par `GridView.update_hover` / `click_at` et les contrôleurs réels. Les événements de souris Windows ne sont pas certifiés.

Les victoires de **I, II, III et IV sont forcées pour la QA**, après leurs actions. Le runner exige ensuite les récompenses et transitions publiques de production ; il ne modifie pas directement l'index de salle. V reste en combat après son déplacement et sa garde, avant fermeture du processus. Cette preuve ne vaut ni victoire jouée intégralement, ni équilibrage de la rencontre, ni validation de la fin de run au GPU.

Un succès exige **cinq salles, cinq couples déplacement/garde, quatre transitions et dix captures aux dimensions exactes**, sans erreur d'oracle. Les empreintes de la run, des salles et des rencontres sont observées au début et à la fin ; les fichiers doivent rester stables pendant la passe.

## Extension à cinq cartes — 6 septembre 2026

La [fiche du Temple du Serment Noir](black_oath_temple_v1.md) rassemble son art, ses données et ses preuves finales. La première passe compacte sans décalage local a détecté onze dalles recouvertes par l'inspecteur après l'action ; les unités et leurs proportions passaient. Les premières passes servent au diagnostic et ne constituent pas la validation finale du cadrage.

Les passes avec décalage constant, dans les dossiers `*_framed`, restent également intermédiaires : les contrôles tactiques passaient, mais l'inspection visuelle montrait du noir à droite en grande fenêtre. La configuration finale borne ce décalage au débord de peinture disponible. Ses preuves doivent provenir des deux dossiers `*_final`, avec comparaison du second rapport au premier ; leur état est consigné dans la fiche du temple. Les preuves historiques suivantes conservent leur périmètre d'origine.

## Extension à quatre cartes — 6 septembre 2026

Les résultats de cette extension sont consignés dans la [fiche du Gué du Léthé](lethe_crossing_v1.md). Les preuves datées ci-dessous décrivent leurs anciennes versions à trois ou deux cartes.

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
