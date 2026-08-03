# Mountain Pass — logique conservée, blueprint 2D 16:9

## Statut

Le layout tactique `mountain_pass_blockout` reste le blockout jouable autoritaire. Sa représentation de validation artistique est désormais un blueprint 2D isométrique plein écran de 1920×1080. Le blueprint n’est jamais utilisé pour déduire collisions, terrain, déploiements ou pathfinding.

La scène de combat de production `data/rooms/maps/mountain_pass_blockout_battle.tscn` et son renderer historique `battle/iso/mountain_pass_blockout_view.gd` n’ont pas été modifiés. Tant que la référence artistique n’est pas validée, le nouveau renderer n’est utilisé que par le laboratoire et les exporteurs.

## Chemins réellement utilisés

- Layout autoritaire : `data/maps/mountain_pass_blockout.tres`
- Adaptateur de ressource : `data/maps/mountain_pass_blockout_data.gd`
- RoomData : `data/rooms/mountain_pass_blockout_test.tres`
- Adaptateur RoomData : `data/rooms/mountain_pass_blockout_room_data.gd`
- Scène de combat laissée intacte : `data/rooms/maps/mountain_pass_blockout_battle.tscn`
- Renderer historique du diorama : `battle/iso/mountain_pass_blockout_view.gd`
- Nouveau renderer blueprint : `battle/iso/mountain_pass_blueprint_view.gd`
- Laboratoire adapté : `battle/iso/mountain_pass_blockout_lab.tscn`
- Contrôleur du laboratoire : `battle/iso/mountain_pass_blockout_lab.gd`
- Exporteur Godot : `tools/export_mountain_pass_blockout.gd`
- Exporteur PowerShell déterministe : `tools/export_mountain_pass_blockout.ps1`
- Bootstrap de combat historique : `tools/MountainPassBlockoutDebug.tscn`
- Tests logiques historiques : `test/unit/test_mountain_pass_blockout.gd`
- Tests visuels 16:9 : `test/unit/test_mountain_pass_blueprint.gd`
- Anciennes captures : `artifacts/maps/mountain_pass_blockout/`
- Nouvelles captures : `artifacts/maps/mountain_pass_blueprint/`

## Layout autoritaire inchangé

```text
XXXX......XXXX
XX..........XX
X.......EEE..X
........EEE...
.........RR...
....#....RR...
..##..........
......~~~.....
XX...~~~~#....
XX..A.~...#...
...AAA..##....
X..AA........X
XX..........XX
XXXX......XXXX
```

| Type | Nombre |
|---|---:|
| Normal `.` | 133 |
| ICE `~` | 8 |
| Alliés `A` | 6 |
| Ennemis `E` | 6 |
| Obstacles `#` | 7 |
| Ruine `R` | 4 |
| VOID `X` | 32 |
| Total | 196 |

Les 153 cellules traversables, les onze cellules bloquantes, la distance minimale de dix pas entre camps et l’absence de goulot obligatoire restent couvertes par les tests historiques. Aucun second moteur de grille n’a été ajouté.

## Ancien pipeline visuel identifié

Le diorama 2048×2048 était dessiné par `MountainPassBlockoutView` puis reproduit dans l’ancien exporteur PowerShell. Les formes responsables de la composition isolée étaient :

- `_draw_environment_back` / `Back` : frise de montagnes et épaules latérales détachées ;
- `_draw_cliffs` / `DrawCliffs` : extrusion verticale uniforme le long de la plateforme ;
- `_draw_obstacles` / `Obstacles` : volumes extrudés au-dessus des empreintes ;
- `_draw_environment_front` / `Front` : rochers de présentation détachés ;
- canvas carré, origine `(1024,650)` et panneaux de comparaison carrés.

Ces éléments n’ont pas été supprimés du renderer de production. Ils sont désactivés dans le nouveau pipeline par séparation : le laboratoire et les exporteurs utilisent exclusivement `MountainPassBlueprintView`, et écrivent dans un nouveau dossier. L’ancien dossier reste disponible pour la comparaison gauche/droite.

## Calibration du blueprint

- Canvas : `1920×1080`, ratio 16:9.
- Projection : dimétrique 2:1, sans convergence.
- Cellule affichée : `96×48 px`.
- `axis_x = Vector2(48,24)`.
- `axis_y = Vector2(-48,24)`.
- `grid_origin = Vector2(960,232)`.
- Bounds exacts de la grille : position `(288,208)`, taille `1344×672`.
- Sommet : `y=208` ; bas : `y=880`.
- Occupation horizontale : `1344 / 1920 = 70 %`.
- Bounds de scène utile : position `(24,72)`, taille `1872×984`.

Conversion :

```gdscript
screen_position = Vector2(960, 232) + cell.x * Vector2(48, 24) + cell.y * Vector2(-48, 24)
```

Les 196 centres sont uniques et le round-trip centre → cellule est testé. Les axes globaux des autres maps ne changent pas.

## Architecture graphique

`MountainPassBlueprintView.GRAPHIC_CATEGORIES` déclare les douze couches de lecture :

1. `DISTANT_BACKGROUND`
2. `REAR_MOUNTAINS`
3. `REAR_CLIFFS`
4. `NON_PLAYABLE_SNOW`
5. `WALKABLE_SNOW`
6. `OLD_ROAD`
7. `ICE`
8. `BLOCKED_ROCKS`
9. `RUIN`
10. `VOID_RAVINES`
11. `FRONT_CLIFFS`
12. `FOREGROUND_OCCLUSION_GUIDE`

Le ciel bleu-gris remplit le canvas. Les montagnes sont des masses de fond continues, séparées par l’ouverture du col. La vieille route entre par le bas-gauche et ressort par le haut-droit. Les 32 cellules VOID restent présentes dans les données, le debug et le masque logique, mais ne possèdent plus de face supérieure dans `reference` ou `clean`. Chaque groupe connecté devient une masse irrégulière de ravin ; chaque arête interne entre plateforme et VOID reçoit une bande de falaise orientée vers le ravin. La grille de référence ne trace que les 164 cellules appartenant à la plateforme.

Les sept `#` sont regroupés depuis leurs composantes logiques en trois volumes bas 1×1 et deux volumes allongés 1×2. Les quatre `R` produisent un seul volume bas couvrant l’empreinte 2×2. Ces six volumes sont dérivés de `obstacle_groups()` et n’ajoutent aucune coordonnée visuelle autoritaire.

Le guide de foreground est un PNG RGBA indépendant. Son premier pixel opaque se situe à `y=895`, sous le bas exact de la grille à `y=880` ; il ne recouvre donc aucune cellule. Il est désactivé par défaut dans le laboratoire.

## Laboratoire

Ouvrir `res://battle/iso/mountain_pass_blockout_lab.tscn`.

- Le `Sprite2D` `BlueprintBackground` affiche un PNG exporté comme fond simple.
- `IsoGridView` est transparent et conserve la façade de projection/clic/highlight.
- `UnitPreviewLayer`, `OverlayPreviewLayer`, `TerrainEffectLayer` et `VFXLayer` restent séparés.
- `ForegroundGuide` affiche la couche RGBA optionnelle.

Raccourcis :

- `M` : clean, reference, logic, debug ;
- `G` : grille logique dynamique ;
- `T` : couleurs des types de terrain ;
- `F` : guide d’occlusion ;
- `U` : silhouettes d’unités de calibration.

## Exports

Génération déterministe sans Godot installé :

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\export_mountain_pass_blockout.ps1
```

Génération depuis Godot avec un renderer graphique (le renderer dummy de
`--headless` ne peut pas capturer un `SubViewport`) :

```powershell
godot --rendering-method gl_compatibility --audio-driver Dummy --path . -s res://tools/export_mountain_pass_blockout.gd
```

Les deux exporteurs ciblent `artifacts/maps/mountain_pass_blueprint/` et produisent :

- `mountain_pass_blueprint_reference.png` : environnement et grille fine, pour Nano Banana ;
- `mountain_pass_blueprint_clean.png` : même composition sans grille ;
- `mountain_pass_blueprint_logic.png` : types logiques en aplats et centres ;
- `mountain_pass_blueprint_foreground_guide.png` : RGBA transparent, occlusions seules ;
- `mountain_pass_blueprint_debug.png` : coordonnées, centres, origine, axes et bounds ;
- `mountain_pass_blueprint_comparison.png` : ancien diorama à gauche, blueprint in-game à droite.

Tous font exactement 1920×1080. Aucun personnage, HUD, texte ou effet de combat n’apparaît dans `reference` ou `clean`.

## Validation

`test_mountain_pass_blueprint.gd` vérifie : dimensions, projection, cellule 96×48, bounds 1344×672, 196 centres, layout/comptages, douze catégories, six PNG, couleurs du masque, transparence et absence d’intersection du foreground, fond bleu-gris et architecture du laboratoire. Il vérifie aussi que la grille de référence exclut exactement les 32 VOID, que chaque frontière plateforme↔VOID possède une transition ne couvrant pas le centre X et que les volumes obstacles conservent les tailles `[1,1,1,2,2,4]`.

Les tests historiques continuent de couvrir GridData, Pathfinder, TerrainEffects, déploiements, projection ISO et autres maps. Toute régression logique doit être corrigée sans modifier le layout ci-dessus.

## Limites

- Il s’agit d’un blueprint en aplats, pas de l’art final.
- Les PNG sont ignorés par `.gitignore` avec le dossier `artifacts/` ; ils doivent être régénérés après un clone.
- La scène de combat de production conserve volontairement l’ancien renderer tant que la référence artistique n’est pas validée.
- `tools/MountainPassBlockoutDebug.tscn` lance toujours le combat historique ; le laboratoire blueprint s’ouvre directement depuis sa scène dédiée.

L’image à transmettre à Nano Banana est :

`artifacts/maps/mountain_pass_blueprint/mountain_pass_blueprint_reference.png`
