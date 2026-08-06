# ArenaTerrainRenderPlanService

Ce service pur transforme une Arena et son profil en plan déterministe trié par `(y, x)`. Chaque entrée contient `cell`, `terrain_id`, `texture`, `texture_path`, `cell_type`, `polygon`, `visible`, `skip_reason`, `is_border` et `visual_layer`.

## Politiques

| Mode | Politique de sol |
|---|---|
| PAINTED | aucune dalle ; `base_floor_intentionally_painted=true` |
| MODULAR | toutes les cellules définies non VOID, bordures comprises |
| HYBRID + NONE | aucune dalle |
| HYBRID + NON_BASE_TERRAINS | uniquement les terrains différents de `base_terrain_id` |
| HYBRID + ALL_DEFINED | toutes les cellules définies non VOID |

Le plan expose les comptes attendus totaux et par `terrain_id`, les cellules ignorées et leurs raisons. Il produit une erreur pour profil absent, terrain inconnu, texture absente, cellule hors grille ou politique incompatible. Une cellule VOID est intentionnellement ignorée, pas considérée comme texture manquante.

Le plan est l'unique liste de cellules à rendre. Le canvas peut mettre à jour une entrée avec `entry_for`; previews, runtime et production consomment `build`.
