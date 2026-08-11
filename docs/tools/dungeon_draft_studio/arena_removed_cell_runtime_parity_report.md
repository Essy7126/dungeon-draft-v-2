# Rapport — Removed Cell Runtime Parity

Statut : **WORKTREE_CANDIDATE**

## Reproduction contrôlée

La reproduction utilise exclusivement des `ArenaDefinition` en mémoire et des
copies sous `user://dungeon_draft_studio/`. Aucune arène de production n'est
sauvegardée.

Coordonnée principale : `(2, 2)`, cellule intérieure en pierre. Les variantes
couvrent aussi `(0, 0)` au bord et `(6, 7)` voisine de l'eau `(6, 6)`.

Avant correction :

- `erase_cell()` supprimait correctement la définition et ses dépendances ;
- `to_snapshot()` et `restore_snapshot()` conservaient le document sparse ;
- le runtime bridge projetait la coordonnée absente en `VOID/HOLE` ;
- le plan complet n'ajoutait pas de fallback pierre ;
- **mais** `ArenaTerrainVisualRenderer.update_cells()` ne supprimait pas
  `old_cells - new_cells`. Après un premier rendu puis le retrait de `(2, 2)`,
  le nœud et l'entrée de cache de cette coordonnée restaient présents ;
- `PaintedGridView.draw_logic_types` remplissait tous les types, y compris
  `HOLE`, créant une représentation pleine supplémentaire ;
- le request Tester v2 ne transportait aucun hash topologique ou ensemble de
  sol, utilisait `CACHE_MODE_IGNORE` et n'était supprimé qu'à la fin ;
- le probe validait des compteurs, sans détecter deux ensembles différents de
  même taille.

Le défaut est donc une absence de contrat de topologie de bout en bout, avec
deux manifestations reproductibles : cache de coordonnée obsolète et
remplissage debug d'un trou. La chaîne directe reconstruite intégralement sur
la baseline conservait déjà souvent la cellule absente, mais sans preuve ni
refus d'un contexte périmé.

## Correction

- service de signature stable et rapport de parité exacts ;
- VOID explicite traité avant toute résolution d'asset ;
- runtime bridge et surfaces vérifiés sur chaque coordonnée ;
- plan enrichi de `source_definition_present`, `topology_state`,
  `visibility_reason`, `resolved_texture_path` et `topology_hash` ;
- renderer synchronisé et caches entièrement vidés ;
- metadata `renderer_role = arena_floor` ;
- `HOLE` uniquement contourable dans la vue logique ;
- preview Art/Jeu auto-invalidée lorsque la même working copy est mutée ;
- request Tester v3, rechargement profond, génération unique, consommation
  one-shot et gate topologique ;
- probe de tout le SceneTree avec expected/missing/unexpected/removed/duplicate ;
- certificat de production bloqué sur toute divergence d'ensemble.

## Preuves automatisées

La suite `test_arena_removed_cell_topology_parity.gd` couvre notamment :

- retrait simple, rectangle, pinceau et inversion ;
- nettoyage obstacle/spawns/objectif/décoration ;
- snapshot 120 cellules dans une grille 14×14, sans remplissage implicite ;
- fixture 14×14 avec 12 absences, 8 VOID explicites et 20 bordures ;
- round-trip `user://` avec `CACHE_MODE_IGNORE_DEEP` ;
- `VOID → HOLE`, non walkable, non interactable et sans surface ;
- absence de fallback stone ;
- suppression immédiate du nœud/cache ;
- overlay logique sans remplissage des trous ;
- comparaison de coordonnées malgré des compteurs égaux ;
- nouveau contexte Tester et hashes identiques ;
- invalidation Undo/Redo et gate de certificat.

Les diagnostics runtime exposent le chemin réellement chargé, le
`generation_id`, les trois topology hashes, le sol attendu/rendu et toutes les
coordonnées divergentes.

Le bundle incomplet `res://data/arenas/produced/room_01_forest/` n'est jamais
chargé par ce flux et reste gelé.

## Validation du candidat

Le smoke painted réel a chargé :

```text
user://dungeon_draft_studio/arena_studio/tests/
room_01_forest_1786447187137000_2962625/arena.tres
```

Résultat observé :

```text
working_fingerprint == temporary_fingerprint == runtime_fingerprint
221cd0a14ae110605c6063cf2bed6bb99820c7d7a47f4d7efc8a8a51fc68109c

working_topology_hash == temporary_topology_hash == runtime_topology_hash
e54af18a9403ee8bf3c6cb4dd571ef31d1f90441c56f0d8906c56cafe8381a99

expected_floor_hash == rendered_floor_hash
7a1634dedc7d1e0d78e45ec9e8460845c899114d3fccd519c8a7cbcbb8bac9e5

dalles attendues/rendues : 164/164
missing/unexpected/removed/duplicate : 0/0/0/0
floor renderer/layer : 1/1
misplaced floor nodes : 0
debug filled cells : 0
request consumed once : true
produced bundle loaded : false
```

Validations finales :

- topologie dédiée : 15/15, 204 assertions ;
- Direct Test Runtime Parity : 5/5, 699 assertions ;
- Stone Floor Visibility : 6/6, 79 assertions ;
- Studio v1.2/v1.2.1 : 18/18, 980 assertions ;
- Studio 2.0 : 12/12, 423 assertions ;
- phase 10–11 / visite guidée : 10/10, 87 assertions ;
- Run Content Isolation : 14/14, 1 497 assertions ;
- Skill Tree protégé : 50/50, 521 assertions ;
- smoke painted réel : PASS ;
- smoke modular réel : PASS ;
- suite globale : 936/949, 55 118/55 175 assertions, exactement les 13
  échecs historiques ;
- `git diff --check` : PASS.

Le bundle gelé conserve ses SHA-256 de prévol :

```text
arena.tres
2d8abd212eb12ee64612079268ccca260ef21db993474b7731feb25023d7103e

modular_visual_profile.tres
9381fb5b2116a0d35a1f5013a3a7607e6dc617675bf5be79c2f619a8a58b5190
```

## Limites et avertissements

- Deux éditeurs Godot externes ont modifié en parallèle des fichiers
  Odyssey/Achilles/VFX hors périmètre. Ces changements sont conservés et ne
  font pas partie du correctif topologique.
- Une exécution Room Integration a subi une contention de fixture ; les neuf
  autres tests de cette exécution ont passé et la suite globale finale a
  ensuite validé le parcours complet.
- La preuve finale est automatisée (ensembles exacts, smoke runtime et
  SceneTree complet). Aucun jeu contractuel de captures BEFORE/AFTER
  multi-résolution n'a été ajouté au dépôt ; la revue visuelle utilisateur
  reste donc requise avant commit.
