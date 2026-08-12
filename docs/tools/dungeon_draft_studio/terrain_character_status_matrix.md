# Terrains et statuts de personnage

Statut : **WORKTREE_CANDIDATE**.

| Terrain | TerrainEffectData | StatusData | Effet immédiat | Durée portée |
|---|---|---|---:|---:|
| Eau | `data/terrain/eau.tres` | `mouille.tres` | — | valeur canonique existante |
| Glace | `data/terrain/glace.tres` | `gele.tres` (`frozen`) | — | 1 activation, -1 PM |
| Lave | `data/terrain/lave.tres` | `brulure.tres` | 15 dégâts Feu | 3 tours, 6/tour |
| Poison | `data/terrain/poison.tres` | `poison.tres` | — | 3 tours, 4/tour |
| Vapeur | `data/terrain/vapeur.tres` | aucun | LoS bloquée | 2 tours si temporaire |
| Eau électrifiée | `data/terrain/eau_electrifiee.tres` | `mouille.tres` | 20 dégâts Foudre | Mouillé existant |

Le chemin unique est `occupation GridData -> TerrainSurfaceRuntimeService ->
TerrainEffectData -> Unit.apply_status() -> StatusData`. Les métadonnées du
statut conservent `terrain_id`, ce qui permet à l’inspecteur existant d’afficher
la source sans créer un second panneau de statuts.

Les changements d’occupation couvrent placement, mouvement, poussée,
attraction, téléportation et invocation. Le début de tour passe par la même
Resource. Un jeton de résolution empêche une double application sur une même
cellule pendant un déplacement.
