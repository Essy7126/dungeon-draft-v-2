# La Porte des Cendres — arène enregistrée

La salle II de Catabase charge `data/rooms/odyssey/room_02.tres`, une ressource `ArenaDefinition` persistante. Elle conserve son nom et sa liaison à `data/encounters/odyssey_room_02_encounter.tres`. Le roster est lu dans cette rencontre courante, indépendamment du package visuel. La salle I utilise le même dispositif avec le plan grec et le Rejeton chétif. L’ordre des trois salles reste défini par `data/runs/odyssey.tres` ; la ressource de salle III n’est pas remplacée.

État du contenu relevé le 5 septembre 2026 : une intégration de personnage menée en parallèle a remplacé le garde de la salle II par le Spectre errant (`spectre_greatsword`). La rencontre courante contient donc deux escarmoucheurs et un spectre. Ce changement de roster ne modifie pas le modèle géométrique ni le renderer de cette carte ; les recettes de validation doivent charger la rencontre courante.

Les deux premières salles pointent `battle/painted/registered_terrain/RegisteredTerrainBattle.tscn`. Cette scène étend le combat peint de production. Le champ `registered_terrain_plan_path` sélectionne le plan de chaque salle ; les scripts de combat et de décor sont communs aux deux ambiances. Les ressources de Catabase ne dépendent pas des scènes du laboratoire grec.

Le plan infernal est `data/arenas/ashen_hell_courtyard_v1/terrain_plan.json`. Son manifeste géométrique reste la source des annotations de fosses ; le runtime vérifie ces annotations contre la grille réelle. Le guide `grid_reference.png` sert à la calibration. Le paysage final provient des assets ci-dessous.

| Asset actif | Dimensions | Rôle |
|---|---:|---|
| `asset/map/painted/underworld/ashen_hell_courtyard_v1/land_composed.png` | 1920 × 1200 | Peinture du terrain, végétation brûlée et arrière-plan rocheux ; texture limitée au polygone Land. |
| `asset/map/painted/underworld/ashen_hell_courtyard_v1/lava_material.png` | 1254 × 1254 | Surface de lave dessinée sous Land, animée par `lava_ink.gdshader`. |
| `asset/map/painted/underworld/ashen_hell_courtyard_v1/environment_clusters_chroma.png` | 1536 × 1024 | Arbre et rocher de premier plan, extraits de deux régions de l’atlas. |

Le fichier `asset_manifest.json` du même dossier archive les images générées d’origine, les prompts, les empreintes SHA-256 et les paramètres de découpe. `environment_clusters.png` est une étape rejetée avec damier peint, conservée uniquement comme source ; le plan runtime utilise `environment_clusters_chroma.png`.

L’atlas actif est une image RGB opaque sur fond magenta, sans alpha natif. Le renderer applique le shader de chroma commun avec `#ff00ff`, seuil `0.18` et adoucissement `0.16`. Le plan infernal active aussi `chroma_key.magenta_despill = 1` pour supprimer la frange magenta des pixels de transition ; la valeur par défaut du renderer reste `0` pour les autres décors. Les régions sont `[16,523,702,485]` pour l’arbre et `[718,537,810,475]` pour le rocher. Les échelles uniformes sont respectivement `0.57781201849` et `0.859375`, soit des silhouettes larges de 375 et 660 pixels natifs. Les ancres restent `(378,973.5)` et `(1728.75,1177.5)` ; aucun étirement indépendant sur X ou Y n’est appliqué.

La géométrie est identique au modèle grec accepté : canevas natif 1920 × 1200, grille 19 × 18, axes `(51.6,25.8)` et `(-51.6,25.8)`, 217 cases FLOOR, 12 obstacles sur FLOOR et 205 cases libres connectées. Les cinq groupes de fosses totalisent 16 cases VOID. Les polygones de terre, points et largeurs des berges, exclusions rocheuses, obstacles et spawns reprennent le modèle grec. Les parties masquées de la référence initiale restent des décisions d’auteur, pas des données de collision extraites de Dofus.

La présence d’une vraie dalle se lit dans les cellules canoniques d’`ArenaDefinition`, pas dans le seul `GridData.CellType`. Le bridge historique projette les 11 obstacles solides qui laissent passer la vue en type de collision `HOLE`, et le pilier opaque en `WALL`. Ces 12 obstacles restent sur FLOOR et non marchables. Ils ne sont pas les 16 fosses VOID annotées par le manifeste ; cette distinction est contrôlée par le test de projection persistée.

La palette des vraies dalles de combat et celle des props sont réglées par le plan infernal. Le bandeau décoratif garde une largeur de `0.42` cellule en espace grille et une marge de rive de 20 pixels natifs. Il n’ajoute aucune case jouable.

**La lave est uniquement visuelle.** Elle remplace l’apparence de la surface extérieure au terrain. Elle ne crée aucun type de case LAVA, dégât périodique, coût de déplacement ou collision supplémentaire. Les rencontres, la progression et l’économie sont lues depuis les ressources courantes de Catabase ; ce package visuel ne définit pas leurs règles.

`registered_terrain_plan_path` est conservé dans les snapshots d’`ArenaDefinition`, classé `ARENA_OWNED` par `RoomIntegrationFieldPolicy` et `RUNTIME_CONSUMED` par `ArenaRuntimeFieldCoverageService`. Les projections `grid_layout` et `painted_map_visual_data` sont persistées dans les deux ressources de salle. L’outil ciblé `test/support/prepare_catabase_registered_rooms.gd` permet de les régénérer sans réécrire le run ou la salle III.

Les tests ciblés sont `test/unit/test_catabase_registered_terrain.gd`, `test_catabase_vertical_slice_content.gd` et `test_catabase_enemy_combat_audit.gd`. Ils couvrent les liaisons de production, la projection persistée, la connectivité, les rosters et l’aller-retour du plan dans le Studio. Le runner `tools/registered_terrain_validation/` produit les captures et rapports dans `artifacts/catabase_registered_maps_2026-09-05/`. Ce document décrit les contrats et les sources ; il ne vaut pas attestation d’un passage GUT ou runtime.


Validation finale de cette promotion : **21 tests / 3 845 assertions** et deux parcours GPU de la vraie run réussis en **1920 × 1080** et **1200 × 896**, avec le Spectre errant courant. Les trois salles se chargent et les deux transitions passent après mouvement et garde réels. Les victoires seules sont forcées pour la QA. Voir les [rapports, captures et limites](registered_terrain_pipeline.md#validation-de-la-promotion--5-septembre-2026).
