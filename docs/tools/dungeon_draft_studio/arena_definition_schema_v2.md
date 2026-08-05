# ArenaDefinition — schéma v2

`ArenaDefinition.CURRENT_SCHEMA_VERSION` vaut 2.

## Champs ajoutés

- `visual_mode` : PAINTED, MODULAR ou HYBRID ;
- `theme_id` et `modular_visual_profile` ;
- cellules portant un `terrain_id` explicite ;
- obstacles portant `wall_id`, `WallConfig`, variante visuelle et orientation ;
- `objectives` ;
- `decorations` avec scène, ancre, offset, rotation, échelle et couche.

Le registre terrain partage les identités `void`, `stone`, `water`, `ice` et `lava` avec le Lab et le runtime. La lave historique du Lab reste non praticable (`GridData.WALL`) sans perdre son identité `lava`. Le registre mur partage `normal`, `fire` et `ice` avec leurs vraies `WallConfig`.

## Migration

`ArenaSchemaMigrator` inspecte avant mutation. v0 → v1 complète bordure/obstacles/spawns ; v1 → v2 conserve la salle comme PAINTED et ajoute les collections vides. Une version future est refusée. La ressource source n’est jamais sauvegardée pendant la migration.

Les snapshots sont déterministes. Les chemins volatils de sous-ressources (`arena.tres::Resource_xxx`) sont exclus des empreintes.
