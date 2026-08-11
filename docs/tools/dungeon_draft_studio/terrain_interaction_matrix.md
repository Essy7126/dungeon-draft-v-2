# Terrain Interaction Matrix

Statut : **WORKTREE_CANDIDATE**  
Baseline : comportement du combat de production, résolu par IDs stables.

## Matrice des surfaces dynamiques

| Surface active | Surface entrante | Résultat | Réaction | Dalle attendue |
|---|---|---|---|---|
| aucune | feu | feu | apply | lava |
| aucune | eau | eau | apply | water |
| aucune | glace | glace | apply | ice |
| feu | eau | vapeur | steam | aucune |
| eau | feu | vapeur | steam | aucune |
| feu | glace | eau | melt | water |
| glace | feu | eau | melt | water |
| eau | glace | glace | freeze | ice |
| glace | eau | glace | freeze | ice |
| eau | foudre | aucune | shock | aucune |
| autre | autre | entrante | replace | selon entrante |

La table est symétrique pour feu/eau, feu/glace et eau/glace. Eau/foudre retire
la surface et conserve les dégâts de réaction historiques.

## Réapplication identique

Chaque `TerrainEffectData` choisit une politique :

- `IGNORE` : conserve effet, source et durée actuels ;
- `REFRESH_DURATION` : remplace la durée par la durée finale entrante ;
- `REPLACE` : remplace l’effet, la source et la durée.

Les Resources eau, glace et lave actuelles utilisent la valeur rétrocompatible
`IGNORE`. La suite vérifie notamment qu’une lave à 2 tours ne revient pas à 3
après une pose identique ignorée.

## Terrain statique

Les réactions portent d’abord sur la surface dynamique. Un `terrain_id` statique
ne déclenche pas implicitement une réaction. Il reste la base immuable restaurée
à l’expiration :

| Base | Surface temporaire | Pendant | Après |
|---|---|---|---|
| pierre / NORMAL | lave | LAVA + dalle lava | pierre / NORMAL |
| eau statique / NORMAL | glace | ICE + dalle ice | eau / NORMAL |
| glace statique / ICE | feu | LAVA + dalle lava | glace / ICE |
| normal / NORMAL | eau | NORMAL + dalle water | normal / NORMAL |

## Valeurs gameplay préservées

| Effet | Durée | Trigger | Dégâts/statut | Danger IA |
|---|---:|---|---|---:|
| lave | 3 | ON_ENTER | 15 dégâts | 3.0 |
| eau | 3 | ON_ENTER | Mouillé | 0.0 |
| glace | 3 | PASSIVE | aucun | 1.5 |
| vapeur | 2 | PASSIVE | bloque la vision | selon contrat historique |

Les valeurs `forest_fire`, `forest_water` et `forest_ice` restent des fixtures de
Lab. Elles ne remplacent aucune valeur de sort.

