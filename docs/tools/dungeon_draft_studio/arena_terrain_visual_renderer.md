# ArenaTerrainVisualRenderer

`ArenaTerrainVisualRenderer` rend les entrées visibles du plan dans une couche Node2D. Chaque cellule possède une racine mise en cache et un enfant `Sprite2D` nommé `Visual`.

Métadonnées obligatoires : `arena_cell`, `grid_cell`, `terrain_id`, `cell_type`, `renderer_layer=terrain`. Les murs ont leur propre `renderer_layer=wall` et continuent d'utiliser `WallConfig`/`DynamicWall`.

## Projection affine

`ArenaTileProjectionService.sprite_transform` mappe l'empreinte losange de la texture source sur les quatre sommets du polygone cible. Le canvas utilise les mêmes sommets avec des UV normalisées. Il n'y a ni homographie, ni TileMapLayer global, ni choix visuel par CellType.

## Mise à jour et diagnostic

- `render_plan` reconstruit une couche complète ;
- `update_cells` crée ou actualise uniquement les cellules concernées ;
- `remove_cells` et `clear` libèrent les nœuds ;
- `node_for_cell` et `texture_for_cell` exposent les preuves ;
- `actual_render_report` recompte les vrais nœuds, chemins de texture et cellules, y compris les références supprimées invalides.

Les racines et sprites sont des Node2D, jamais des Controls : l'input demeure entièrement dans `ArenaStudioCanvas`.
