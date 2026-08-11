# Dynamic Terrain Visual Replacement Contract

Statut : **WORKTREE_CANDIDATE**

## Contrat utilisateur

Une surface eau, glace ou lave remplace entièrement la dalle tactique existante
pendant la durée finale du `TerrainEffectData`. À la même frame logique que
l’expiration gameplay, la dalle dynamique disparaît et la dalle originale
réapparaît exactement. Aucune `ArenaDefinition`, `RunData` ou Resource de map
n’est sauvegardée.

## Résolution visuelle

Le runtime transmet uniquement `visual_terrain_id` et `theme_id` à
`TerrainSurfaceVisualResolver`. Celui-ci charge l’`ArenaTerrainDefinition` du
catalogue puis sa `base_texture` :

| visual_terrain_id | définition catalogue | asset |
|---|---|---|
| `water` | `catalog/terrains/water.tres` | `water.png` |
| `ice` | `catalog/terrains/ice.tres` | `ice.png` |
| `lava` | `catalog/terrains/lava.tres` | `lava.png` |

Aucun chemin d’asset n’est dupliqué dans `SpellCaster`, `TerrainEffects`,
`Battle`, la preview ou l’adaptateur.

## Invariants par cellule

Pendant une surface visuelle active :

- un seul nœud porte `renderer_role = dynamic_surface` ;
- son parent porte le rôle `arena_dynamic_surface_layer` ;
- son `arena_cell` est identique à la cellule gameplay ;
- sa projection utilise le même polygone que la dalle de base ;
- tout nœud de rôle `arena_floor` ou `terrain_floor` de cette cellule est masqué ;
- grille, highlights, murs et unités restent au-dessus.

Après retrait :

- le nœud dynamique n’existe plus ;
- la visibilité originale de chaque renderer de base est restaurée ;
- aucun renderer de base supplémentaire n’est créé ;
- aucune autre cellule n’est actualisée.

## Surfaces sans dalle

`steam` est un état gameplay valide sans `visual_terrain_id`. L’adaptateur retire
la dalle dynamique et réaffiche la base. Il peut conserver la durée gameplay de
la vapeur sans créer de dalle fantôme. Les métriques comparent les cellules
rendues aux cellules qui possèdent réellement un `visual_terrain_id`, pas à
toutes les surfaces gameplay actives.

## Topologie

Une cellule absente de la base capturée ne peut pas être rendue dynamiquement.
Cela couvre les VOID, cases retirées, hors-grille, murs structurels et obstacles
structurels. Le pipeline ne crée jamais une seconde grille ou un second
`Pathfinder`.

## Critère de parité

Pour chaque cast :

```text
coordonnées CastReport.terrain_changed
= coordonnées des états runtime attendus
= coordonnées des dalles dynamiques attendues
```

Exceptions explicites : une réaction sans asset, comme vapeur, possède un état
runtime mais aucune dalle attendue.

Le runner graphique produit 52 PNG (13 cas × 4 résolutions) avec :

- `missing_cells = 0` ;
- `unexpected_cells = 0` ;
- neuf dalles lava pour Boule de feu ;
- treize dalles ice pour Mur de glace ;
- une dalle water pour eau et pour la fonte feu + glace ;
- zéro dalle pour vapeur ;
- zéro nœud après expiration/restauration.

