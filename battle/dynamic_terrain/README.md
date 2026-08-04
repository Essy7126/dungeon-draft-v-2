# Dynamic terrain walls

Ces composants sont prêts à être branchés à `Battle`, mais la mission du lab
ne les active dans aucune salle de production.

## Responsabilités

- `DynamicWall` porte variante, PV, durée, états et capacités de blocage.
- `WallConfig` contient les valeurs et ressources d'une variante.
- `WallInteractionResolver` centralise les réactions WATER/FIRE/ICE.
- `DynamicBlockerService` superpose un objet temporaire au `GridData` existant,
  puis synchronise le `Pathfinder` existant. Il ne crée jamais de seconde grille.

`GridData.get_type(cell)` reste le terrain de base. Les appels
`is_walkable`, `is_transparent` et `is_projectile_passable` combinent ce terrain
avec les bloqueurs temporaires enregistrés. Ainsi, retirer un mur n'écrase pas
un `HOLE`, une `LAVA` localement bloquée ou un obstacle permanent.

## Intégration future dans Battle

1. Instancier un seul `DynamicBlockerService` après la création du `GridData` et
   du `Pathfinder` de `Battle`, puis appeler `configure(grid, pathfinder)`.
2. Ajouter un unique parent `YSortedWorld` commun aux vues d'unités et aux murs.
   La racine d'un mur doit être placée au centre de sa cellule, au point au sol.
3. Conserver dans `Battle` un dictionnaire `Vector2i -> DynamicWall`. Le service
   reste la source du blocage, le dictionnaire ne sert qu'au cycle de vie.
4. Au placement, vérifier limites, unité, `HOLE`, obstacle permanent et doublon;
   instancier le mur, appeler `setup(cell, variant, config)`, l'ajouter au parent
   Y-sorté, puis `register_dynamic_blocker(cell, wall)`.
5. Connecter `destroyed` pour retirer le mur du dictionnaire. Le signal
   `blocking_changed(false)` désenregistre automatiquement le bloqueur de façon
   idempotente avant la libération visuelle.
6. À chaque tour, appeler `advance_turn()` sur une copie de la liste de murs et
   résoudre `aura_damage_requested` avec les unités adjacentes de `Battle`.
7. Les sorts transmettent seulement leur élément à
   `WallInteractionResolver.resolve(wall, element)`; aucune interaction
   élémentaire ne doit être dupliquée dans les scripts de sorts.
8. Les projectiles logiques interrogent `Pathfinder.has_projectile_path` (ou le
   service), tandis que les sorts continuent d'utiliser
   `Pathfinder.has_line_of_sight`.

## API de façade attendue dans Battle

```gdscript
func spawn_wall(cell: Vector2i, config: WallConfig, source_unit) -> DynamicWall
func damage_wall(cell: Vector2i, amount: int, element: StringName) -> int
func transform_wall(cell: Vector2i, variant: DynamicWall.WallVariant) -> bool
func remove_wall(cell: Vector2i) -> bool
```

Le lab expose déjà ces quatre opérations avec ce contrat. Une transformation
réutilise la même instance et ne désenregistre donc jamais temporairement la
cellule.
