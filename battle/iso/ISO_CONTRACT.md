# Contrat isometrique — Dungeon Draft v2

Version validee : **Godot 4.6.3.stable.official.7d41c59c4**.

## Autorites separees

- `GridData` est l'autorite logique : cellules, occupation, marchabilite,
  terrain, portee, pathfinding, ligne de vue et effets. Le gameplay reste en
  `Vector2i`.
- Le `TileMapLayer` interne a `IsoGridView` est l'autorite geometrique de
  projection. Les conversions utilisent exclusivement `map_to_local()` et
  `local_to_map()` ; les changements de repere utilisent `to_global()` et
  `to_local()`.
- `IsoGridView` est la facade entre la logique et le rendu. Les noms de
  compatibilite `grid_to_world()` et `world_to_grid()` manipulent, dans ce
  prototype, des coordonnees locales a `IsoGridView`.
- `Camera2D` est l'autorite de cadrage. Elle centre le `Rect2` complet retourne
  par `get_map_bounds()` et calcule le zoom ; aucun offset de camera n'entre
  dans la projection.
- Le Y-sort du conteneur d'unites et de props est l'autorite de profondeur. Le
  pivot d'un personnage ou d'un objet haut est son point de contact avec le sol.

## Convention visuelle

- Footprint logique initial : **64 x 32 pixels**, ratio **2:1**.
- Forme : grille isometrique en losange, layout `DIAMOND_DOWN`.
- Axe logique `+X` : bas-droite.
- Axe logique `+Y` : bas-gauche.
- La position d'un personnage ou d'un prop est le centre logique de sa cellule,
  au niveau de ses pieds. Sa texture se developpe principalement au-dessus de
  ce pivot.
- Les textures peuvent etre beaucoup plus hautes et plus larges que le
  footprint 64 x 32.
- La projection visuelle ne change ni les regles, ni le pathfinding, ni les
  collisions tactiques.
- Le footprint 64 x 32 reste provisoire jusqu'au premier test avec personnages
  et decors rendus.

## Architecture de rendu cible

La composition future separera probablement :

1. `LogicLayer`
2. `FloorLayer`
3. `FloorDetailLayer`
4. `GridOverlayLayer`
5. `TerrainEffectLayer`
6. `UnitsLayer`
7. `PropLayer`
8. `ForegroundLayer`
9. `VFXLayer`

Les futurs rendus Meshy et Blender devront reprendre exactement l'orientation,
le footprint et le pivot au sol decrits ici. Leur taille d'image ne devra jamais
redefinir les coordonnees logiques.
