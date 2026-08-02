# Mountain Pass Blockout

## Objectif

Ce blockout est le squelette technique et visuel de `mountain_pass_blockout_test`, une salle de combat 2D isométrique représentant un ancien col enneigé. Il sert simultanément de RoomData jouable, de référence géométrique pour une future peinture, de modèle de calibration et de démonstration de l’alignement grille/décor/pathfinding/overlays/unités.

Ce n’est pas une map artistique finale. Aucun asset enneigé généré précédemment, aucune 3D et aucune perspective ne sont utilisés.

## Constat d’architecture

- `GridData` demeure l’autorité logique des types, occupations et propriétés de cellules.
- `Pathfinder` conserve `AStarGrid2D`, la distance de Manhattan et quatre voisins orthogonaux.
- `TerrainEffects` et le `CellType.ICE` existants sont réutilisés. ICE est traversable ; aucune glissade spéculative n’est ajoutée.
- `RoomData` fournit les zones de déploiement. La sous-classe dédiée les dérive des symboles A/E de l’unique layout.
- `Battle` continue de créer GridData, Pathfinder, TerrainEffects, SpellCaster et les overlays. L’adaptateur local ne spécialise que l’import initial.
- La vue dédiée expose la même façade `grid_to_local`, `local_to_grid`, `highlight` et `cell_clicked` que les autres grilles.
- Les unités restent ancrées par les pieds au centre de cellule dans `YSortedWorld`, dont le tri Y est activé.
- `Camera2D` cadre le canvas technique complet de 2048×2048.

Le contrat ISO historique de `IsoGridView` utilise 64×32. Il n’a pas été modifié globalement. Cette map possède sa calibration isolée : 128×64 natif et 96×48 à l’échelle d’export 0,75.

## Projection et cadrage

- Projection : dimétrique 2:1, orthographique, sans convergence.
- Cellule native : `128 × 64 px`.
- Échelle d’aperçu/export : `0,75`.
- Cellule affichée : `96 × 48 px`.
- `axis_x = Vector2(48, 24)`.
- `axis_y = Vector2(-48, 24)`.
- `grid_origin = Vector2(1024, 650)`.
- Canvas : `2048 × 2048 px`.
- Bounds logiques 14×14 : position `(352, 626)`, taille `1344 × 672`.
- Bounds réels de plateforme : position `(496, 698)`, taille `1056 × 528`.
- Falaises : profondeur visuelle `58 px`.
- Obstacles : hauteur `34 px` ; landmark : `50 px`.

Conversion :

```gdscript
screen_position = grid_origin + cell.x * axis_x + cell.y * axis_y
```

L’inverse résout les deux axes réguliers, puis arrondit au centre de la cellule. Les 196 centres sont distincts et le round-trip centre → cellule est testé.

## Layout autoritaire

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

Légende : `.` neige praticable, `~` glace praticable, `#` obstacle bloquant, `R` ruine bloquante, `X` absence de plateforme, `A` déploiement allié, `E` déploiement ennemi.

Statistiques exactes :

| Type | Nombre |
|---|---:|
| Normal `.` | 133 |
| Glace `~` | 8 |
| Alliés `A` | 6 |
| Ennemis `E` | 6 |
| Obstacles `#` | 7 |
| Ruine `R` | 4 |
| Vide `X` | 32 |
| Total | 196 |

Les 153 cellules traversables représentent 78,06 %. Les 11 cellules bloquantes représentent 5,61 %, les 32 vides 16,33 %, soit 21,94 % non traversables.

## Terrains, obstacles et déploiements

- ICE : `(6,7)`, `(7,7)`, `(8,7)`, `(5,8)`, `(6,8)`, `(7,8)`, `(8,8)`, `(6,9)`.
- Alliés : `(4,9)`, `(3,10)`, `(4,10)`, `(5,10)`, `(3,11)`, `(4,11)`.
- Ennemis : `(8,2)`, `(9,2)`, `(10,2)`, `(8,3)`, `(9,3)`, `(10,3)`.
- Ruine 2×2 : `(9,4)`, `(10,4)`, `(9,5)`, `(10,5)`.
- Obstacles isolés : `(4,5)`, `(9,8)`, `(10,9)`.
- Obstacles 1×2 : `(2,6)-(3,6)` et `(8,10)-(9,10)`.

La route ancienne est une classification strictement visuelle déclarée dans `road_visual_cells`. Elle relie les secteurs A/E par une bande oblique de trois à quatre cellules et ne modifie aucun type ni coût de déplacement.

## Intention tactique et composition

Le centre reste ouvert pour les zones d’effet, poussées, déplacements de groupe et combats multi-unités. Les obstacles asymétriques et le landmark bas créent des contournements sans fermer une moitié de la map. Le Pathfinder existant mesure une distance minimale de 10 pas entre les zones A et E. Le test d’articulation confirme qu’aucune cellule praticable hors spawn ne coupe à elle seule toutes les routes entre camps.

La surface tactique est sobre : neige, vieille route et glace. Les masses montagneuses, épaules rocheuses et volumes de premier plan portent le biome hors grille. Les falaises ne sont produites que le long des arêtes exposées ; l’indentation gauche reste une absence de plateforme et jamais une crevasse ajoutée dans une cellule traversable.

## Édition et calibration

Ouvrir `res://battle/iso/mountain_pass_blockout_lab.tscn`.

- `F1` : référence/debug.
- `M` : parcourir référence, clean, debug, masque et guide de hauteur.
- `G` : afficher l’overlay recalculé (coordonnées, centres, origine et axes).
- L’inspecteur expose origine, preview scale, axes, profondeurs/hauteurs, zoom et offset caméra.

Après une modification de `mountain_pass_blockout.tres`, régénérer les exports :

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\export_mountain_pass_blockout.ps1
```

Pour lancer directement la salle avec le trio standard, exécuter `res://tools/MountainPassBlockoutDebug.tscn`. Ce bootstrap de debug ne modifie ni la main scene ni le flux de production.

## Remplacement par une map peinte

1. Peindre sur `mountain_pass_blockout_reference.png` sans déplacer la géométrie des losanges, les empreintes ou les arêtes.
2. Conserver exactement le canvas 2048×2048 et les centres définis par l’origine et les axes.
3. Importer la peinture comme background dans la vue dédiée, sans en déduire de cellules.
4. Produire séparément un foreground transparent limité aux bords/coins. Il sert à l’occlusion artistique, jamais aux collisions.
5. Vérifier dans le laboratoire les centres, contours, spawns, ICE, obstacles et pivots de pieds.
6. Conserver le masque logique pour les contrôles, mais ne pas l’afficher en production.

La future image peinte n’est jamais autoritaire pour le gameplay. `RoomData` et `GridData` restent les sources de vérité. Le décor doit respecter ce blockout ; aucune collision, marchabilité ou portée ne doit être déduite automatiquement des pixels.

## Exports

Tous les fichiers sont déterministes et font 2048×2048 :

- `mountain_pass_blockout_reference.png` : Nano Banana, grille fine, sans texte/UI/personnage.
- `mountain_pass_blockout_clean.png` : même cadrage sans grille.
- `mountain_pass_blockout_debug.png` : coordonnées, centres, types, spawns, origine, axes et arêtes de falaise.
- `mountain_pass_blockout_logic_mask.png` : aplats par type logique.
- `mountain_pass_blockout_height_guide.png` : niveaux de gris par hauteur.
- `mountain_pass_blockout_comparison.png` : référence, clean et debug côte à côte.

## Limites connues

- Le blockout reste volontairement schématique et n’est pas l’art final.
- La glace initiale conserve la classification ICE traversable. Elle ne reçoit pas automatiquement un effet temporaire ni une glissade.
- Les obstacles sont intégrés au background technique ; leurs empreintes logiques, elles, restent dans GridData. Une future occlusion fine pourra les séparer en props Y-sortés sans changer les cellules.
- Le footprint 96×48 est local à cette map ; le 64×32 historique reste inchangé ailleurs.
