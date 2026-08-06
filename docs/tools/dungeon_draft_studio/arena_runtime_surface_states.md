# Arena Studio 2.0 — états runtime de surface

Statut : **WORKTREE_CANDIDATE**  
Date : 2026-08-06

`ArenaRuntimeProjectionService` clone le snapshot de l’arène et produit `ArenaRuntimeState` : `GridData`, layout, données peintes, profil visuel, spawns et `DynamicSurfaceService`. `ArenaRuntimeBridge.build_grid()` et `runtime_signature()` projettent également une copie et ne complètent plus la ressource source.

## Deux couches distinctes

`CellSurfaceState` conserve :

- base : normal, eau, glace, lave, void, mur ou obstacle ;
- `base_terrain_id` et `base_cell_type` ;
- surface temporaire : aucune, feu, eau ou glace ;
- durée, source et flags gameplay.

Appliquer ou expirer une surface ne change ni le terrain de base ni `ArenaDefinition`. `DynamicSurfaceVisualAdapter` rend un overlay séparé et appelle `ArenaTerrainVisualRenderer.update_cells()` pour la seule cellule signalée. Supprimer l’overlay révèle donc immédiatement la dalle de base.

La palette Arena « Simuler un état de dalle » agit sur la projection de la vue Jeu. Les tests couvrent non-mutation, restauration du type, événement, identité du nœud visuel voisin et mise à jour d’une seule cellule.

