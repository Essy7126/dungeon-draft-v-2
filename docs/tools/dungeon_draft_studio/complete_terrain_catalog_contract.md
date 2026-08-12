# Catalogue complet des terrains — contrat candidat

Statut : **WORKTREE_CANDIDATE** — 2026-08-12.

## Décision validée

Arena Studio expose huit terrains permanents et un interactif spatial :

| ID stable | Nom | CellType | Effet | Entrée | Début de tour |
|---|---|---:|---|---:|---:|
| `stone` | Pierre | NORMAL | aucun | non | non |
| `neutral` | Neutre beige | NORMAL | aucun | non | non |
| `water` | Eau | NORMAL | Mouillé | oui | rafraîchi |
| `ice` | Glace | ICE | Gelé | oui | rafraîchi |
| `lava` | Lave | LAVA | 15 dégâts directs + Brûlure | oui | non |
| `poison` | Poison | NORMAL | Poison | oui | rafraîchi |
| `steam` | Vapeur | NORMAL | bloque la LoS | permanent | permanent |
| `electrified_water` | Eau électrifiée | NORMAL | 20 dégâts Foudre + Mouillé | oui | non |
| `vortex` | Vortex apparié | interactif | téléportation bidirectionnelle | oui | sans objet |

Toutes les dalles sont praticables, coûtent 1 PM et sont productibles. La
vapeur seule est opaque à la LoS ; elle laisse passer les projectiles. `VOID`
reste une suppression topologique et ne fait pas partie du catalogue visuel.

## Autorités

- `ArenaTerrainDefinition` porte texture, spatialité, coût et déclencheurs.
- `TerrainEffectData` porte dégâts, statut, élément et danger IA.
- `StatusData` porte durée et modification réelle de l’unité.
- `get_placeable_terrain_definitions()` est l’autorité commune palette/brush.
- les surfaces temporaires restent dans `TerrainSurfaceRuntimeService` et ne
  mutent jamais `ArenaDefinition`.

L’inventaire technique complet est
`artifacts/complete_terrain_catalog/asset_inventory.json`.
