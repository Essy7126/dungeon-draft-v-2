# Contrat runtime des arènes

Audit réalisé sur `C:\Users\p.montebello\Documents\GitHub\dungeon-draft-v-2`, branche `main`, HEAD initial `a967f6f429e844ae782cc7f0f1184f5525933ed7`, avec Godot `4.7.1.stable.official.a13da4feb`. Le dépôt était propre avant l'intervention.

## Structure actuelle d'une salle peinte

Une salle de production est une `RoomData`. Elle référence une unique scène `res://data/rooms/maps/painted_battle.tscn`, un `RoomGridLayout`, un `PaintedMapVisualData`, une rencontre, des zones de spawn et un roster. `PaintedBattle` hérite du combat commun puis remplit le `GridData` du combat avec `RoomGridLayout.apply_to_grid()`.

La chaîne effective est :

`RoomData` → `PaintedBattle` → `GridData` → `Pathfinder` / `TerrainEffects` / déploiement / IA.

Le background est un `Sprite2D` en pixels natifs. Il n'existe pas de `SubViewport` dans la scène de combat peinte. Une `Camera2D` applique un cadrage uniforme de type cover. Les unités et les occluders sont placés sous `YSortedWorld`, qui active le Y-sort. Les trois salles peintes utilisent une grille 14 × 14 et la même scène de combat.

## Sources de vérité

- `GridData` est l'autorité spatiale mutable pendant un combat : types, occupation, effets et bloqueurs dynamiques.
- `RoomGridLayout` est la déclaration initiale des types de cellules.
- `PaintedMapVisualData` est l'autorité de projection cellule ↔ pixel, de cadrage et d'occlusion peinte.
- `Pathfinder` est l'unique implémentation de navigation, d'accessibilité, de ligne de vue et de trajet projectile.
- `RoomData` est le point d'entrée chargé par `GameManager` et consommé par `battle.gd`.
- `EncounterDefinition` et `EncounterFormationPlanner` définissent le roster réel et son placement.

Arena Studio ne remplace aucun de ces services. `ArenaDefinition` hérite de `RoomData` et produit ses sous-ressources runtime en mémoire avant sauvegarde ou test.

## Paramètres mesurés

| Map | Image production | Origine | Axe droite | Axe gauche | Caméra |
| --- | --- | --- | --- | --- | --- |
| Forêt | `forest_background_v2.webp`, 1376 × 768 | (688, 164.97778) | (34.4, 17.066667) | (-34.4, 17.066667) | offset (0, 34), zoom 1.1 |
| Volcan | `volcano_background_v2.jpg`, 1376 × 768 | (695, 172.5) | (34.65, 17.5) | (-34.65, 17.5) | offset (0, 32), zoom 1.1 |
| Espace | `space_background_source.jpg`, 1376 × 768 | (693.5, 137) | (34.825, 17.5) | (-34.825, 17.5) | offset (0, 30), zoom 1.1 |

La topologie commune contient 153 cases marchables, 11 obstacles et 32 cellules vides. Les zones de déploiement de production comptent six cellules héros et six cellules ennemies. Le volcan applique 14 cellules de lave ; l'espace applique 14 cellules de glace.

`forest_background_v3.png` (1672 × 941) reste l'image de référence du laboratoire historique. La production validée utilise encore `forest_background_v2.webp`; Arena Studio conserve ce choix lors d'un import afin de garantir une migration sans variation visuelle.

## Systèmes réutilisés

- conversion affine : `GridTransformService`, appelée par `PaintedMapVisualData` et Arena Studio ;
- grille : `GridData` ;
- navigation et accessibilité : `Pathfinder` ;
- LOS/projectiles : `Pathfinder.trace_line()`, `has_line_of_sight()` et `has_projectile_path()` ;
- types de terrain et obstacles : `GridData.CellType` et `GridData.PROPERTIES` ;
- chargement de salle : `RoomData` / `GameManager` ;
- combat direct : `painted_battle.tscn` ;
- héros de production : Elfe, Mage et Guerrier chargés par `GameManager.start_preconfigured_run()` ;
- Y-sort et occlusion : `YSortedWorld` et les données d'occluder de `PaintedMapVisualData`.

## Incompatibilités corrigées

L'ancienne inversion de `PaintedMapVisualData.image_to_cell()` arrondissait directement les coordonnées affines. Elle est remplacée par `GridTransformService`, qui contrôle le déterminant relatif, inverse la matrice, choisit une candidate et confirme l'appartenance au losange. La conversion cellule → position et le polygone passent par le même service.

`RoomGridLayout` ne permettait qu'un seul type de terrain explicite par ressource. Le champ additif `cell_type_overrides` accepte plusieurs types tout en préservant intégralement `terrain_cell_type` et `terrain_cells` pour les salles existantes.

## Stratégie de migration

`ArenaLegacyImporter` lit les `RoomData` forêt, volcan et espace sans les modifier. Il construit une `ArenaDefinition` en mémoire, copie calibration, topologie, terrains, obstacles, spawns, rencontre et scène runtime, puis vérifie une signature avant/après. Une sauvegarde explicite produit une nouvelle ressource sous `res://data/arenas/`; les ressources historiques restent la solution de repli.

## Invariants à ne pas casser

- aucune donnée de gameplay ne doit être déduite silencieusement des pixels ;
- le zoom et le déplacement de la vue ne modifient jamais la calibration ;
- les bordures existent visuellement mais deviennent `HOLE` dans `GridData` ;
- tous les spawns doivent être dans des cellules marchables, hors bordure et hors obstacle ;
- les états de terrain mutables restent dans `GridData`/`TerrainEffects`, jamais dans la ressource source ;
- une définition identique génère les mêmes lignes, types, positions et chemins ;
- aucun chemin Windows absolu ne peut être sauvegardé ;
- l'ancien éditeur `res://tools/arena_map_editor/testv1/` reste intact.
