# ArenaDefinition — schéma v3

`ArenaDefinition.CURRENT_SCHEMA_VERSION` vaut 3.

## Socle v2

- `visual_mode` : PAINTED, MODULAR ou HYBRID ;
- `theme_id` et `modular_visual_profile` ;
- cellules portant un `terrain_id` explicite ;
- obstacles portant `wall_id`, `WallConfig`, variante visuelle et orientation ;
- `objectives` ;
- `decorations` avec scène, ancre, offset, rotation, échelle et couche.

Le registre terrain partage les identités `void`, `stone`, `water`, `ice` et `lava` avec le Lab et le runtime. La lave historique du Lab reste non praticable (`GridData.WALL`) sans perdre son identité `lava`. Le registre mur partage `normal`, `fire` et `ice` avec leurs vraies `WallConfig`.

## Ajout v3

La v3 ajoute `vortex_networks`, une collection de réseaux identifiés pouvant
contenir une ou plusieurs cellules. Chaque réseau conserve son nom, son état
actif, les équipes autorisées, sa couleur d’édition, son effet à vortex unique,
sa politique de destination aléatoire et ses notes de production.

`vortex_pairs` reste lisible pour la compatibilité des ressources v2. Lors de la
migration, chaque paire historique devient un réseau à deux cellules si aucun
réseau v3 n’est déjà présent.

## Migration

`ArenaSchemaMigrator` inspecte avant mutation. v0 → v1 complète
bordure/obstacles/spawns ; v1 → v2 conserve la salle comme PAINTED et ajoute les
collections vides ; v2 → v3 convertit les paires de vortex en réseaux. Une
version future est refusée. La ressource source n’est jamais sauvegardée pendant
la migration.

Les snapshots sont déterministes. Les chemins volatils de sous-ressources (`arena.tres::Resource_xxx`) sont exclus des empreintes.
