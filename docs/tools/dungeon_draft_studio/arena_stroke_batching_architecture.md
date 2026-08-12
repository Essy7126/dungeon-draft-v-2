# Architecture de batching des traits Arena Studio

Statut : **WORKTREE_CANDIDATE** sur `main`, baseline `8bd9d455bced1c68acf98843e6f6d4844d4174e8`.

## Contrat

`ArenaDefinition` reste la source de vérité. `ArenaStrokeBatchService` ouvre un
trait avec un snapshot unique, déduplique les coordonnées reçues, ignore les
cellules déjà à la valeur demandée et applique seulement les mutations locales.
Le canvas est rafraîchi de manière ciblée pendant le geste. À la fermeture du
trait, le service effectue au plus une synchronisation logique, une invalidation
de preview/certificat et une action Undo.

```text
begin(snapshot) -> mutate(cells uniques) -> rendu local
finish -> sync runtime si logique -> invalidations uniques -> Undo unique
```

`stone <-> neutral` est classé visuel lorsque leurs contrats logiques sont
identiques. Eau, Glace, Lave, Poison, Vapeur et Eau électrifiée déclenchent une
synchronisation logique différée.

## Index et garanties

`ArenaDefinition` maintient un index transitoire `Vector2i ->
ArenaCellDefinition`. Il n'est ni exporté ni sérialisé, est reconstruit à la
demande et invalidé lors d'un changement de topologie. `cells` reste canonique.

- aucun `ResourceSaver.save()` pendant un trait ;
- aucune construction volontaire de `GridData` ou `Pathfinder` par cellule ;
- rectangle, flood fill et remplacement global utilisent la même transaction ;
- pinceaux 1/2/3 : footprint carré exact ;
- `Alt + clic` prélève le terrain ;
- une cellule répétée ne produit ni mutation ni invalidation supplémentaire.

## Mesures du 12 août 2026

Avant : 100 synchronisations pour 100 cellules, 571,219 à 1 104,665 ms. Après :
une synchronisation maximum, finalisation 100 cellules 1,516 ms maximum, mutation
50 cellules 2,451 ms maximum et finalisation 200 cellules/32x32 en 6,634 ms.
Rapports : `artifacts/arena_authoring_speed/stroke_baseline.json` et
`stroke_after.json`.

