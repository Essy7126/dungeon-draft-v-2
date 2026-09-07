# Le Gué du Léthé — quatrième carte de Catabase

> État depuis l'ajout du [Temple du Serment Noir](black_oath_temple_v1.md), le 6 septembre 2026 : IV est désormais une salle intermédiaire de la run à cinq salles. Les preuves de cette fiche décrivent sa livraison initiale à quatre salles ; le contrôle Studio auparavant en échec passe dans la validation V.


Cette carte ajoute une salle IV après le Jugement silencieux. Elle utilise la scène partagée `RegisteredTerrainBattle`, avec une **nouvelle topologie** : deux espaces décalés, un passage large, de petites fosses et une nouvelle répartition des obstacles. Le centre garde une matière calme et les vrais sprites de dalles du jeu.

## Implantation tactique

| Élément | Cartes I à III | Gué du Léthé |
|---|---|---|
| Grille logique | 19 × 18 | 18 × 19 |
| Dalles visibles | 217 | 114 |
| Cases d'obstacles | 12 | 8 |
| Fosses | 16 cellules, 5 groupes | 6 cellules, 3 groupes |
| Cases praticables connectées | 205 | 106 |
| Origine native | (830.676793205, 46.528936910) | (1000, 125) |

Les axes et la taille des dalles restent identiques : `(51.6,25.8)` / `(-51.6,25.8)`, soit 103,2 × 51,6 px natifs. Deux cours décalées sont reliées par un passage de **cinq cases de large**, entièrement libre sur quatre cases de longueur. Les quatre positions de départ de chaque camp et les contraintes de formation placent les trois adversaires dans la seconde cour.

Le [générateur géométrique](../../tools/registered_terrain_authoring/generate_lethe_crossing.py) utilise uniquement la bibliothèque standard Python. Le [rapport d'auteur](../../data/arenas/lethe_crossing_v1/authoring_validation.json) vérifie la connectivité, le passage, une route entre camps de 21 cellules, les fosses et les marges. Le [guide](../../data/arenas/lethe_crossing_v1/grid_reference.png) et le [manifeste](../../data/arenas/lethe_crossing_v1/geometry_manifest.json) sont générés depuis la même définition.

```powershell
python tools/registered_terrain_authoring/generate_lethe_crossing.py --validate-only
python tools/registered_terrain_authoring/generate_lethe_crossing.py
```

La régénération conserve les paramètres artistiques du plan. Elle ne sauvegarde pas la copie de campagne ; employer ensuite sa scène de préparation.

La terre est une péninsule qui inclut tout le haut du canevas : la porte, les cyprès et l'aqueduc restent entiers. La réserve de dallage `allowed_floor_polygon` est distincte de cette berge. Cette séparation évite que le contour de support du combat ne découpe arbitrairement les grands éléments peints.

## Direction artistique

Terre ocre claire, pierre calcaire couleur miel, végétation olive et eau jade sombre. La porte grecque et l'aqueduc sont limités aux bords du paysage. Aucun sprite de premier plan, banc cosmétique, brouillard ni remplissage procédural ne passe devant le combat. Les obstacles tactiques restent des objets de la grille, avec leurs règles de collision.

Les joints intérieurs utilisent la terre neutre du bandeau grâce au paramètre local `interior_joint_land_weight: 0`. La peinture de paysage reste sous les unités et les dalles. Le bandeau suit le contour géométrique ; il ne crée aucune case supplémentaire.

## Assets originaux

Les images ont été créées avec **l'outil intégré image_gen**, puis installées dans le projet. Aucun appel API ou CLI externe de génération n'a été utilisé.

| Asset final | Préparation | Prompt exact |
|---|---|---|
| [land_composed.png](../../asset/map/painted/underworld/lethe_crossing_v1/land_composed.png) | Paysage opaque 1586 × 992 normalisé globalement en 1920 × 1200 par interpolation bicubique. | [land_composed_prompt.txt](../../asset/map/painted/underworld/lethe_crossing_v1/land_composed_prompt.txt) |
| [lethe_water.png](../../asset/map/painted/underworld/lethe_crossing_v1/lethe_water.png) | Matériau opaque 1254 × 1254, sortie générée conservée. | [lethe_water_prompt.txt](../../asset/map/painted/underworld/lethe_crossing_v1/lethe_water_prompt.txt) |
| [lethe_water.gdshader](../../asset/map/painted/underworld/lethe_crossing_v1/lethe_water.gdshader) | Déplacement très discret des UV et faible variation de reflet olive, uniquement sur le polygone d'eau. | Code local. |

Sources et empreintes SHA-256 : [manifeste des assets](../../asset/map/painted/underworld/lethe_crossing_v1/asset_manifest.json). La géométrie jouable est construite à partir des cellules ; les pixels générés ne définissent ni le dallage, ni les fosses, ni les collisions.

## Préparation

Après import des ressources, depuis la racine du projet :

```powershell
Godot --headless --path . res://test/support/PrepareCatabaseLetheRoom.tscn
```

La scène attend les autoloads, synchronise les données dérivées et sauvegarde uniquement la salle IV après comparaison du snapshot de gameplay. La run comporte les trois salles précédentes dans leur ordre, puis la nouvelle salle. La progression de production détermine la dernière salle par la longueur de la run.

## Validation du 6 septembre 2026

La [préparation persistante](../../artifacts/catabase_fourth_map_2026-09-06/prepare_room.log) termine avec `ok:true`. Les [26 tests principaux](../../artifacts/catabase_fourth_map_2026-09-06/gut_primary.log) passent **7 976 assertions** : topologie, ressources persistées, édition Studio par snapshot, formations sur vingt seeds, progression et récompenses jusqu'à la quatrième victoire. Les adversaires de IV se placent dans la seconde cour.

| Contrôle GPU | Résultat | Preuve |
|---|---|---|
| 1920 × 1080 | 4 salles, 4 déplacements/gardes, 3 transitions, 8 captures exactes | [Rapport](../../artifacts/catabase_fourth_map_2026-09-06/1920x1080/registered_terrain_report.json) |
| 1200 × 896 | 4 salles, 4 déplacements/gardes, 3 transitions, 8 captures exactes | [Rapport](../../artifacts/catabase_fourth_map_2026-09-06/1200x896/registered_terrain_report.json) |

Sur IV, les oracles mesurent **114 sprites de dalles**, 190 arêtes partagées, 1 026 points de picking intérieurs et huit ancres d'obstacles. L'écart maximal entre arêtes adjacentes est inférieur à **0,0004 px** dans les deux formats, pour une tolérance de 0,05 px. Aucun point de picking ne diverge de sa case attendue.

Les dalles complètes sont supportées par le terrain ; la marge minimale réelle dalle/rive vaut **193,803 px natifs**, et celle du bandeau/rive **152,808 px**. Le centre a zéro décor cosmétique séparé, zéro remplissage procédural et 114 matériaux à joints neutres. Le déplacement consomme deux PM et la garde deux PA ; son bouclier sourcé passe de 15 à 18 en salle IV dans le premier parcours.

Les deux captures réelles ont été inspectées : disposition différente, centre dégagé, bandeau fondu, ruines entières, absence de décor haut superposé aux dalles. La [capture compacte](../../artifacts/catabase_fourth_map_2026-09-06/1200x896/room_04_combat_1200x896.png) confirme la lisibilité en petite fenêtre.

![Le Gué du Léthé en salle IV](../../artifacts/catabase_fourth_map_2026-09-06/1920x1080/room_04_combat_1920x1080.png)

La [comparaison SHA-256](../../artifacts/catabase_fourth_map_2026-09-06/preserved_resources_report.json) confirme que les salles I, II et III et leurs rencontres sont inchangées. La run ajoute uniquement IV après III ; intro et profils restent conservés. IV réutilise deux Spectres errants et un Escarmoucheur, avec une rencontre dédiée, 160 XP de base et le profil d'économie existant.

## Périmètre et contrôle complémentaire en échec

Le [contrôle de route du hub](../../artifacts/catabase_fourth_map_2026-09-06/gut_hub_route.log) passe (1 test, 13 assertions). La [vérification complémentaire SoloRun/Studio](../../artifacts/catabase_fourth_map_2026-09-06/gut_solo_routes.log) passe 1 test sur 2 : le contrat des quatre salles passe ; la découverte globale du catalogue Studio échoue sur des erreurs de chargement du **Mage philosophe**, dont `res://assets/characters/philosopher_mage/sprites_v1/philosopher_portrait.tres` manque. Cette ressource et la run `philosopher_trial` ne font pas partie de cette carte. Le journal d'import montre la même dépendance absente.

Bilan exécuté : **28 tests réussis sur 29**, dont tous les 26 principaux. Les anciennes attentes de kit et d'économie des suites historiques n'ont pas été exécutées en bloc ; le changement de compteur de `test_achilles_theorycraft_foundation` n'est pas présenté comme une suite validée.

Au GPU, les victoires I–III sont forcées seulement pour la QA après les actions réelles. Récompenses et transitions passent par les API de production, puis IV reste en combat après sa garde. Le test GUT de progression simule les quatre victoires et vérifie que seule la quatrième termine la run. Ces contrôles ne certifient ni des victoires entièrement jouées, ni l'équilibrage, ni les événements de souris Windows. Godot signale encore des ressources non libérées à sa fermeture.

[Bilan machine, périmètre et empreintes](../../artifacts/catabase_fourth_map_2026-09-06/validation_summary.json).
