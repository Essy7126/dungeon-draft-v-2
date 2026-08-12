# Architecture terrain permanent / surface temporaire

Statut : **WORKTREE_CANDIDATE**.

## Trois couches indépendantes

1. Le terrain permanent est sérialisé dans chaque `ArenaCellDefinition`.
2. La surface temporaire est détenue par `TerrainSurfaceRuntimeService`.
3. L’interactif spatial (`vortex`) est sérialisé dans `vortex_pairs` et rendu
   dans `ArenaInteractivesLayer`, séparé du sol.

`ArenaRuntimeBridge` projette les propriétés permanentes dans `GridData` :
marchabilité, transparence, projectiles, coût, danger IA et liens de vortex.
`GridData` conserve séparément les surcharges de surface. Ainsi une vapeur
temporaire force `transparent=false` sans altérer le terrain permanent ni
`projectile_passable`; son expiration retire la surcharge et révèle exactement
les propriétés de base.

Le renderer de sol produit un nœud par cellule. Le renderer interactif produit
les extrémités A/B du vortex dans un parent distinct. Les neuf textures passent
par `ArenaTileVisualNormalizationService` : 256×128, bounds 256×128, centre
identique, tolérances centre 0,5 px et coins 0,75 px.

Preview, Tester et vraie scène utilisent tous l’ArenaDefinition projetée par le
même bridge. Tester charge exclusivement sa copie temporaire `user://` et
n’accède jamais au bundle `data/arenas/produced/room_01_forest`.
