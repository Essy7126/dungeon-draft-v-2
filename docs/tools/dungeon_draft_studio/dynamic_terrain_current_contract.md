# Dynamic terrain — contrat courant observé

Statut documentaire : `WORKTREE_CANDIDATE`

Ce document décrit le checkout local avant l'unification runtime. Il distingue les
faits relus dans le code et les Resources des comportements qui doivent encore être
prouvés dans une scène exécutée.

## 1. Autorité gameplay actuelle

**OBSERVÉ** — `TerrainEffects` possède actuellement l'état gameplay des effets de
terrain de la bataille réelle par l'intermédiaire de l'unique `GridData` :

- `place_effect()` écrit `data`, `duration` et le nom dans `GridData._effects` ;
- `_set_effect_cell()` remplace éventuellement le `GridData.CellType` ;
- `on_turn_start()` et `on_enter_cell()` appliquent dégâts et statuts ;
- `tick_all_effects()` décrémente la durée au début de chaque round après le
  premier ;
- `get_ai_danger_weight()` expose le danger porté par `TerrainEffectData`.

`SpellCaster._resolve_cell_terrain()` duplique éventuellement le
`TerrainEffectData`, applique les deltas Skill Tree de durée et de dégâts, puis
appelle exclusivement `TerrainEffects.place_effect()` pour chaque cellule de la
zone. Le rapport historique `terrain_changed` est alimenté depuis le résultat
`changed`.

## 2. Autorité visuelle actuelle

**OBSERVÉ** — Le visuel dynamique n'est pas piloté par `TerrainEffects`.
`DynamicSurfaceVisualAdapter` écoute un `DynamicSurfaceService`, résout une
`SurfaceConfig`, puis demande à `ArenaTerrainVisualRenderer` de créer un sprite par
cellule.

**DIVERGENCE** — Cet adaptateur n'écoute donc pas les surfaces réellement posées
par les sorts dans les batailles. Il n'existe aucun événement visuel commun entre
les deux systèmes.

## 3. Service utilisé dans la preview

**OBSERVÉ** — `ArenaRuntimeProjectionService` construit un `ArenaRuntimeState`, qui
instancie son propre `DynamicSurfaceService`. `ArenaRuntimeState.update_surface()`
appelle `DynamicSurfaceService.apply_surface_effect()`.

La preview consomme ainsi les `SurfaceConfig` du thème, et non les
`TerrainEffectData` résolus par les sorts.

## 4. Service utilisé dans la vraie bataille

**OBSERVÉ** — `Battle._setup_logic()` crée `TerrainEffects.new(grid)` et transmet
cette façade à `SpellCaster` et `EnemyAI`. Aucun `DynamicSurfaceService` ni
`DynamicSurfaceVisualAdapter` n'est créé par `Battle`, `PaintedBattle` ou
`ModularBattle` dans le checkout initial.

**DIVERGENCE** — Les vraies batailles ont l'état gameplay mais aucun adaptateur de
remplacement de dalle. Les previews ont un état et un visuel séparés.

## 5. Différences TerrainEffectData / SurfaceConfig

**OBSERVÉ** — Les Resources de sorts sont l'autorité gameplay actuelle :

| Effet | TerrainEffectData | SurfaceConfig de preview |
|---|---|---|
| Lave | durée 3 par défaut, 15 dégâts, `ON_ENTER`, CellType `LAVA`, danger IA 3.0 | durée 2, 2 dégâts de début de tour |
| Eau | durée 3, `ON_ENTER`, statut Mouillé, aucun override de CellType | durée 2, aucun statut |
| Glace | durée 3, `PASSIVE`, CellType `ICE`, danger IA 1.5 | durée 2, comportement visuel seulement |

**DÉCISION VALIDÉE** — Les durées, dégâts, triggers, statuts et poids IA restent
ceux du `TerrainEffectData` final. Les `SurfaceConfig` ne deviennent pas une source
gameplay.

## 6. Restauration actuelle

**OBSERVÉ** — `TerrainEffects._clear_to_normal()` efface l'effet puis appelle
inconditionnellement :

```gdscript
_grid.set_type(cell, GridData.CellType.NORMAL)
```

Cette méthode est utilisée à l'expiration et par certaines réactions.

**DIVERGENCE** — Le véritable type initial n'est pas mémorisé. Une dalle statique
eau, glace, lave, ombre ou rune est donc perdue après un effet temporaire.

`DynamicSurfaceService` possède déjà un `CellSurfaceState.base_cell_type` et un
`base_terrain_id`, mais `clear_surface()` ne restaure pas explicitement le type ;
ce service constitue une seconde autorité indépendante et ne corrige pas la
bataille réelle.

## 7. Appelants dépendant de TerrainEffects

**OBSERVÉ** — Les dépendances directes caractérisées sont :

- `SpellCaster` et `SpellModTerrainOnAffectedCells` pour la pose ;
- `Battle` pour création, entrée sur une cellule, début de tour et tick de round ;
- `EnemyAI` pour le poids de danger ;
- `InspectPanel` pour l'affichage d'une cellule ;
- les tests gameplay historiques, notamment Skill Tree et progression Mage.

Les signatures publiques historiques doivent rester compatibles.

## 8. Modes sans adaptateur visuel dynamique

**OBSERVÉ** — Aucun adaptateur connecté à `TerrainEffects` n'est présent dans :

- `PaintedBattle` ;
- `ModularBattle` ;
- le chemin hybride assemblé par Arena Studio ;
- le test direct, qui instancie la vraie scène de bataille ;
- les scènes RoomData legacy.

La preview Arena possède un adaptateur, mais raccordé à son autorité parallèle.

## Trace prioritaire avant correction

**OBSERVÉ dans le code et les Resources** :

```text
Boule de feu (mage_fireball, croix rayon 2)
→ lave.tres (durée 3, dégâts 15, ON_ENTER, CellType LAVA)
→ SpellCaster._resolve_impacts()
→ SpellCaster._resolve_cell_terrain()
→ TerrainEffects.place_effect()
→ GridData.set_effect() + GridData.set_type(LAVA)
→ aucun adaptateur visuel de bataille
→ tick_all_effects() au début des rounds 2, 3 et 4
→ _clear_to_normal()
→ CellType NORMAL forcé
```

**OBSERVÉ dans la scène exécutée** — Le traceur a chargé la vraie run
`res://data/runs/first_run.tres`, salle d'index 0, actuellement intégrée par une
transaction `UPDATE` committée vers
`res://data/arenas/produced/room_01_forest/arena_principal.tres`.

Le cast réel sur `(2, 10)` a produit exactement les neuf coordonnées :

```text
0,10  1,10  2,8  2,9  2,10  2,11  2,12  3,10  4,10
```

- `terrain_changed` est exactement égal à cette liste ;
- les neuf cellules passent de `NORMAL` à `LAVA` ;
- leur durée initiale est 3, puis 2, 1 et expiration au troisième tick ;
- le fingerprint de la RoomData reste
  `cb0642b784ff6dd6af8ba761b9f9d9732ffa9eada61695187d97bb7bf5e936a0` ;
- aucun `ArenaDynamicSurfaceLayer` n'existe ;
- chaque cellule conserve uniquement son nœud `arena_floor`, terrain `normal`,
  visible pendant toute la durée ;
- aucune texture lave n'est rendue ;
- l'expiration remet les neuf CellType à `NORMAL`.

**DIVERGENCE** — Le gameplay du cast, sa zone et sa durée fonctionnent, mais la
dalle n'est pas remplacée visuellement. La restauration observée n'est correcte
que parce que les neuf bases choisies sont déjà `NORMAL` ; le retour forcé à
`NORMAL` reste incorrect pour toute base différente.

## Conclusion initiale

**DÉCISION VALIDÉE** — L'architecture cible doit avoir une seule autorité runtime
des surfaces. `TerrainEffects` restera la façade compatible ; la preview et les
adaptateurs visuels devront consommer cette même autorité. Le catalogue Arena
restera l'autorité des textures, tandis que `TerrainEffectData` restera l'autorité
gameplay.
