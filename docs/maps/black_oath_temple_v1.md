# Le Temple du Serment Noir — cinquième carte de Catabase

La salle V ajoute un temple grec noir après le Gué du Léthé. Une nef centrale et deux ailes forment un nouveau plateau, avec un sol gris bleuté lisible dans une architecture de basalte sombre. La carte emploie les vraies dalles du jeu et la [pipeline partagée](registered_terrain_pipeline.md).

## Géométrie et combat

| Élément | Valeur |
|---|---|
| Canevas / grille logique | 1920 × 1200 / 18 × 18 |
| Origine native | (960, 125) |
| Axes | (51.6, 25.8) / (-51.6, 25.8) |
| Dalles | 152 sprites, 103,2 × 51,6 px natifs |
| Obstacles | 8 bases de colonnes basses |
| Cases praticables connectées | 144 sur 144 |
| Fosses latérales | 2 groupes de 2 × 2 cellules |
| Allée centrale entièrement libre | 6 cases de large sur 14 de long |
| Bandeau de raccord | 0,42 cellule, sans collision |
| Marge minimale des dalles à la réserve | 72,4 px natifs |

Le [générateur](../../tools/registered_terrain_authoring/generate_black_oath_temple.py) produit les cellules, spawns, obstacles, [manifeste](../../data/arenas/black_oath_temple_v1/geometry_manifest.json), [guide](../../data/arenas/black_oath_temple_v1/grid_reference.png) et [contrôles d'auteur](../../data/arenas/black_oath_temple_v1/authoring_validation.json). Les pixels de la peinture ne déterminent jamais la géométrie. L'allée u=6..11, v=2..15 reste entièrement libre ; les spawns opposés occupent u=7..10, v=14 pour les héros et v=3 pour les ennemis.

La [salle de campagne](../../data/rooms/odyssey/room_05.tres) conserve le renderer RegisteredTerrainBattle et sélectionne son plan local. La [rencontre dédiée](../../data/encounters/catabase_room_05_encounter.tres) réutilise un Champion et deux Spectres errants, avec 180 XP de base et le profil d'économie existant. Les récompenses et la transition IV → V utilisent GameManager ; seule la cinquième victoire termine désormais la run.

## Composition dessinée

Les deux murs arrière suivent les mêmes diagonales 2:1 que le plateau. Leur pied reste en retrait de la réserve de combat ; les grandes colonnes sortent naturellement du haut de l'image. Le bronze, les bougies et de discrètes touches violettes donnent le caractère maudit. Le centre reste une matière calme, sans autel peint, fumée ni décor haut.

Land couvre le canevas entier, afin de conserver l'architecture. La réserve de dallage indépendante est x=320..1600, y=200..950. Ce temple intérieur ne possède aucune rive : les distances aux berges sont non applicables, et l'eau est un fond uni sans texture ni shader, masqué par Land.

Le plan conserve zéro décor cosmétique séparé, zéro détail procédural et des joints intérieurs neutres (`interior_joint_land_weight:0`). Les huit bases de colonnes correspondent aux vrais obstacles de la grille. Les shaders partagés des pierres et du bandeau assurent le raccord ; aucun nouveau shader spécifique n'est nécessaire.

## Création des images

Le paysage original est créé puis corrigé avec l'outil intégré image_gen. La première composition présentait une perspective trop frontale. Une édition guidée par les diagonales de la géométrie corrige la vue ; la dernière recule les murs et leurs ornements pour dégager la nef.

| Asset final | Source | Préparation |
|---|---|---|
| [temple_composed.png](../../asset/map/painted/underworld/black_oath_temple_v1/temple_composed.png) | exec-fcecaffc-b495-4fa1-a0ee-5bc2aa8ab042.png, 1586 × 992 | Redimensionnement bicubique du canevas entier en 1920 × 1200 |

Les trois prompts exacts sont conservés : [composition](../../asset/map/painted/underworld/black_oath_temple_v1/temple_initial_prompt.txt), [orientation](../../asset/map/painted/underworld/black_oath_temple_v1/temple_camera_prompt.txt) et [recul des murs](../../asset/map/painted/underworld/black_oath_temple_v1/temple_final_prompt.txt). Les sources, empreintes et preuves figurent dans le [manifeste des assets](../../asset/map/painted/underworld/black_oath_temple_v1/asset_manifest.json).

## Caméra et proportions

Le zoom reste celui de la pipeline : `max(largeur/1920, hauteur/1200)`, multiplié par les facteurs de présentation conservés à 1. Le multiplicateur local des unités reste 1,08, et le profil partagé d'Achille donne 1,7064. Terrain, dalles, obstacles et personnages subissent la même transformation.

Le premier parcours compact a révélé onze dalles partiellement couvertes par le panneau d'inspection après une action. Le [profil local du temple](../../data/arenas/black_oath_temple_v1/presentation.tres) demande un décalage de **(160, 0) px natifs**, borné au débord disponible de la peinture avec `camera_keep_painting_in_view:true`. Le cadrage réserve la place du panneau en petite fenêtre et reste centré en grand format, où aucun débord horizontal n'est disponible. Cette contrainte évite de découvrir une bande noire lorsque l'inspection est fermée. Le zoom et la taille des personnages restent identiques ; le générateur conserve ce réglage.

L'oracle mesure les polygones complets des dalles et l'alpha des sprites effectivement affichés avant et après déplacement/garde, face au viewport et aux panneaux visibles. La comparaison entre résolutions utilise les transformations des personnages divisées par la largeur d'une dalle ; la hauteur d'une pose animée est rapportée séparément.

## Préparation et aperçu

Après import, depuis la racine du projet :

```powershell
python tools/registered_terrain_authoring/generate_black_oath_temple.py --validate-only
Godot --headless --path . res://test/support/PrepareCatabaseBlackTempleRoom.tscn
Godot --path . res://tools/registered_terrain_validation/MapPreview.tscn -- --room=res://data/rooms/odyssey/room_05.tres
```

La préparation synchronise les ressources dérivées et sauvegarde uniquement V après comparaison du snapshot de gameplay. Le lanceur IV et celui de V partagent le même helper paramétré. L'aperçu sans option de capture reste jouable.

## Validation du 6 septembre 2026

La [préparation](../../artifacts/catabase_fifth_map_2026-09-06/prepare_room.log) termine avec `ok:true`. Les [tests principaux](../../artifacts/catabase_fifth_map_2026-09-06/gut_primary.log) passent **26/26, 9 822 assertions** : topologie des cinq cartes, persistance et snapshot Studio, formations sur vingt seeds, progression et fin après la cinquième victoire. Les [routes SoloRun/Studio](../../artifacts/catabase_fifth_map_2026-09-06/gut_solo_studio_routes.log) passent **2/2, 60 assertions** ; la [route du hub](../../artifacts/catabase_fifth_map_2026-09-06/gut_hub_route.log) passe **1/1, 13 assertions**. Total ciblé : **29/29, 9 895 assertions**.

Le catalogue Studio passe dans cette validation : l'absence de portrait du Mage philosophe signalée lors de la livraison IV n'est plus présente. Aucun correctif du Mage n'a été effectué dans cette tâche.

La [comparaison de conservation](../../artifacts/catabase_fifth_map_2026-09-06/preserved_resources_report.json) vérifie les SHA-256 inchangés des salles I–IV, de leurs quatre rencontres et des profils d'économie/progression. La run ajoute V à sa liste ordonnée ; ces dix invariants ne couvrent pas les profils de présentation.

La [suite de cadrage et de parité Studio/runtime](../../artifacts/catabase_fifth_map_2026-09-06/gut_camera_framing.log) passe **9/9, 719 assertions**, dont les trois nouveaux cas : maintien de la peinture en grand format, bornage des deux axes en compact et comportement historique conservé lorsque l'option est désactivée. **Bilan des tests ciblés exécutés : 38/38, 10 614 assertions.**

| Parcours GPU final | Résultat | Preuve |
|---|---|---|
| 1920 × 1080 | 5 salles/actions, 4 transitions, 10 captures exactes | [Rapport](../../artifacts/catabase_fifth_map_2026-09-06/1920x1080_final/registered_terrain_report.json) |
| 1200 × 896 | Même parcours, proportions comparées au grand format | [Rapport](../../artifacts/catabase_fifth_map_2026-09-06/1200x896_final/registered_terrain_report.json) |

Sur V, les oracles vérifient **152 dalles, 270 arêtes partagées et 1 368 points de picking intérieurs**, sans échec de picking. L'écart maximal des arêtes adjacentes reste inférieur à **0,0003 px**, pour une tolérance de 0,05 px. Le support, le bandeau, les huit obstacles et les 152 matériaux à joints neutres passent.

| Mesure réelle de V | 1920 × 1080 | 1200 × 896 |
|---|---|---|
| Position caméra native | x=960 ; y=600 | x=1116,429 ; y=600 |
| Zoom uniforme | 1 | 0,746667 |
| Limites écran du dallage x | 392,4 à 1527,6 px | 59,392 à 907,008 px |
| Limites écran du dallage y | 219,8 à 787,4 px | 208,917 à 632,725 px |
| Dalles coupées / recouvertes par le HUD | 0 / 0 | 0 / 0 |
| Pixels opaques des unités coupés / sous le HUD | 0 / 0 | 0 / 0 |
| Hauteur opaque d'Achille, pose observée | 126,262 px | 94,276 px |

Ces mesures passent avant et après les actions. Le ratio hauteur d'Achille / largeur d'une dalle vaut environ **1,22347** dans les deux captures. La variation relative maximale des bases normalisées des quatre unités vaut **1,27 × 10⁻⁷**, bien sous la tolérance de 0,002. Les captures finales ont été inspectées : peinture couvrant l'écran, murs en retrait et panneau d'inspection compact ouvert sans dalle cachée.

![Le Temple du Serment Noir, salle V dans la run](../../artifacts/catabase_fifth_map_2026-09-06/1920x1080_final/room_05_combat_1920x1080.png)

[Capture compacte après déplacement et garde](../../artifacts/catabase_fifth_map_2026-09-06/1200x896_final/room_05_after_move_guard_1200x896.png). Les dossiers sans suffixe et `*_framed` restent les diagnostics des cadrages précédents ; seuls les dossiers `*_final` constituent les preuves finales.

## Périmètre

Les victoires I–IV sont forcées par la QA après leurs vrais déplacement et garde. Les récompenses et transitions passent par les API de production ; V reste en combat après ses actions. La fin de run après V est vérifiée par le scénario GUT de progression. Ces contrôles ne certifient pas des victoires entièrement jouées, l'équilibrage ou le routage de souris Windows.

L'analyse des silhouettes concerne les poses effectivement affichées, sans garantie sur toutes les animations, positions futures ou effets shader. Les suites historiques complètes de kit et d'économie n'ont pas été lancées. Les journaux Godot conservent des signalements de ressources non libérées à la fermeture.

[Bilan machine des validations](../../artifacts/catabase_fifth_map_2026-09-06/validation_summary.json).
