# Contrat d'autorité topologique Arena

Statut : **WORKTREE_CANDIDATE**

Ce contrat définit la forme tactique indépendamment du rectangle `grid_size`.
Le rectangle délimite seulement les coordonnées possibles ; il ne crée aucune
cellule. `ArenaDefinition.cells` est l'autorité canonique.

## États canoniques

- **Retirée** : aucune `ArenaCellDefinition`. Elle est absente des cellules
  déclarées, définies, visibles et jouables. La projection donne `HOLE`, aucun
  spawn/obstacle/objectif/décor ne peut rester, et aucun nœud de sol n'existe.
- **VOID** : définition absente, `defined == false`, `terrain_id == "void"` ou
  `cell_type == HOLE`. Elle ne reçoit ni dalle, ni input tactique, ni état de
  surface dynamique.
- **Bordure** : définition présente et état `border`. Elle reste distincte
  d'une cellule retirée, peut être visible selon la politique de sol, mais est
  exclue du gameplay.
- **Non jouable visible** : définition présente et non VOID, par exemple un
  obstacle ou un terrain bloquant. L'impraticabilité seule ne masque pas son
  sol.
- **Jouable** : définition présente, non VOID, hors bordure, praticable et non
  bloquée par un obstacle.

## Signature stable

`ArenaTopologySignatureService` produit, triés par `y` puis `x`, les ensembles
`declared_cells`, `defined_cells`, `visible_floor_cells`, `playable_cells`,
`border_cells`, `void_cells`, `removed_cells`, `blocked_cells`, obstacles,
spawns héros/ennemis, objectifs et décorations. Une coordonnée est encodée
`"x,y"`.

Chaque ensemble possède un SHA-256. Le hash topologique global contient la
taille logique et les ensembles exacts. Il ne dépend ni de l'ordre des
subresources, ni d'un `instance_id`, ni du SceneTree, ni d'un cache.

## Chaîne obligatoire

La même signature doit être obtenue sur :

1. la working copy ;
2. le snapshot restauré ;
3. la copie temporaire rechargée avec `CACHE_MODE_IGNORE_DEEP` ;
4. l'`ArenaDefinition` reçue par le runner ;
5. la projection runtime.

Le sol attendu vient uniquement de `ArenaTerrainRenderPlanService`. Le sol
rendu est l'ensemble des nœuds `renderer_role = arena_floor` sous
`ArenaTilesLayer`. Le gate compare les coordonnées exactes :

```text
canonical_topology_hash == temporary_topology_hash
canonical_topology_hash == runtime_topology_hash
expected_floor_hash == rendered_floor_hash
removed_cells_rendered == []
unexpected_cells == []
missing_cells == []
duplicate_cells == []
```

Une égalité de compteurs n'est jamais une preuve de parité.

## Rendu et caches

Une reconstruction complète vide nœuds, entrées, textures et signature de
géométrie avant d'appliquer le plan. Une mise à jour incrémentale calcule
`old_cells - new_cells` et supprime ces coordonnées dans la même frame. Une
définition absente ne peut jamais recevoir le fallback `stone`.

`PaintedGridView` peut entourer un `HOLE` en mode diagnostic, mais ne le remplit
jamais. Art, Jeu et les modes de test normaux n'activent aucune couche logique.

## Tester et invalidation

Chaque lancement crée un `generation_id`, un dossier `user://` unique et un
request de contrat v3. Le request contient fingerprints, topology hashes,
visible-floor hash et ensemble de sol attendu. Le runner le supprime juste
après lecture et refuse toute divergence avant de lancer le combat.

Une modification topologique incrémente `ArenaEditSession.topology_generation`.
La validation, les previews, le résultat runtime, le certificat d'intégration
et le plan de production précédents sont alors obsolètes.

