# Dynamic Terrain Runtime Architecture

Statut : **WORKTREE_CANDIDATE**  
Mission : **DYNAMIC TERRAIN TILE REPLACEMENT — WATER ICE AND LAVA RUNTIME UNIFICATION**

## Décision validée

Une bataille possède une seule autorité d’état des surfaces :
`TerrainSurfaceRuntimeService`. `TerrainEffects` reste la façade publique du
combat. `DynamicSurfaceService` reste une façade de compatibilité pour le Lab et
les anciennes previews, mais délègue au même service runtime.

```text
SpellCaster
  -> TerrainEffects (API historique)
  -> TerrainSurfaceRuntimeService (état unique)
  -> GridData (type et payload gameplay)
  -> surface_changed / facts structurés
  -> DynamicSurfaceVisualAdapter
  -> ArenaDynamicSurfaceLayer
```

`TerrainEffectData` est l’autorité gameplay. Le catalogue Arena est l’autorité
visuelle. Les `SurfaceConfig` ne fournissent jamais la durée ou les dégâts d’un
vrai sort.

## État d’une cellule

`CellSurfaceState` conserve séparément :

- la base immuable : `base_cell_type`, `base_terrain_id`, praticabilité et
  transparence ;
- la surface temporaire : effet actif, `surface_id`, `visual_terrain_id`, durée
  restante, lanceur, sort et flags gameplay.

Exemple réel :

```text
base_cell_type = NORMAL
base_terrain_id = stone
surface_id = fire
visual_terrain_id = lava
remaining_duration = 3
```

À expiration, le service efface le payload GridData, restaure le vrai
`base_cell_type`, vide la surface et émet un fait `expired`. Il ne force jamais
la cellule à `NORMAL` quand la base était glace, lave, ombre ou rune.

## Capture de la base

La capture est explicite et intervient dans `Battle` après :

1. la création de `GridData` ;
2. l’application du layout ;
3. l’import du terrain statique ;
4. la création de la topologie ;
5. les obstacles permanents.

Elle précède le premier cast, mouvement ou tick :

```gdscript
terrain_effects.capture_base_state(room_data, grid)
```

Pour une `ArenaDefinition`, seules les cellules canoniques définies, jouables et
non structurelles sont capturées. Les trous, murs, cases retirées et obstacles
structurels ne peuvent pas recevoir de surface. Pour une `RoomData` legacy, la
base est inférée depuis `GridData`.

## Compatibilité publique

Les méthodes historiques restent disponibles sur `TerrainEffects` :

- `place_effect` ;
- `get_effect_data` ;
- `get_ai_danger_weight` ;
- `on_turn_start` ;
- `on_enter_cell` ;
- `tick_all_effects`.

Les lectures explicites ajoutées sont `get_surface_state`, `get_surface_id`,
`get_visual_terrain_id`, `get_remaining_duration`, `get_base_state`,
`can_receive_surface` et `active_surface_cells`.

Les rapports historiques `changed`, `reaction`, `same` et `terrain_changed`
sont conservés. Chaque mutation peut aussi exposer un `terrain_event` avec les
surfaces précédente/entrante/résolue, la réaction, la durée, le sort, le lanceur
et les flags gameplay/visuel.

## Identifiants stables

| Resource | surface_id | visual_terrain_id |
|---|---:|---:|
| `lave.tres` / `feu.tres` | `fire` | `lava` |
| `eau.tres` | `water` | `water` |
| `glace.tres` | `ice` | `ice` |
| `vapeur.tres` | `steam` | vide |

Le resolver reconnaît encore les noms français des Resources legacy et avertit
en mode éditeur. Les nouvelles interactions ne comparent jamais ces noms.

## Intégration des scènes

Ordre logique commun aux batailles peintes, modulaires et previews :

```text
background
ArenaTilesLayer                 base non Y-sortée
ArenaDynamicSurfaceLayer       remplacements non Y-sortés
grid / highlights
YSortedWorld                   unités, murs, occlusion
foreground / HUD
```

Une seule instance `ArenaDynamicSurface_*` peut exister par cellule. Le renderer
de base n’est ni détruit ni recréé : il est masqué pendant la surface visuelle,
puis retrouve exactement sa visibilité précédente.

## Lifecycle et nettoyage

`reset()` efface toutes les surfaces via le même chemin que l’expiration. La
fermeture du combat déconnecte l’adaptateur et restaure toute visibilité de base
encore mémorisée. Vingt cycles application/expiration sont couverts par la suite
ciblée sans croissance d’état ni signal dupliqué.

## Preuve runtime intégrée

Sur `first_run.tres`, salle 0, `painted_battle.tscn`, Boule de feu vise `(2,10)`
et produit exactement :

```text
0,10  1,10  2,8  2,9  2,10  2,11  2,12  3,10  4,10
```

Les neuf bases sont masquées, les neuf nœuds lava sont rendus pendant les durées
3, 2 et 1, puis supprimés au tick 3. Le fingerprint de la salle reste
`cb0642b784ff6dd6af8ba761b9f9d9732ffa9eada61695187d97bb7bf5e936a0`.

