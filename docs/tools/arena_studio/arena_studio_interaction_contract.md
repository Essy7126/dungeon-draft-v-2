# Contrat d'interaction d'Arena Studio 1.1

## Représentation canonique

La calibration est l'affine `P(x, y) = O + xU + yV`, où `O` est
`grid_origin`, `U` est `axis_x` et `V` est `axis_y`. Ces trois valeurs sont
exprimées dans le repère pixel natif de l'image et appartiennent à la copie de
travail `ArenaDefinition`. La topologie (`RoomGridLayout`, types, obstacles,
terrains, spawns et rencontres) ne change jamais pendant une transformation.

`GridTransformService` est l'autorité mathématique partagée par le Studio,
`PaintedMapVisualData` et les tests. Le viewport ne doit pas réimplémenter
l'affine : il convertit seulement image native ↔ écran en tenant compte de
`image_offset`, `image_scale`, du pan et du zoom.

## Repères et conversions

- cellule logique : coordonnées entières `(x, y)` de `RoomGridLayout` ;
- image native : pixels de la texture source, repère de la calibration ;
- image affichée : `image_offset + image_native * image_scale` ;
- viewport : `pan + image_affichée * zoom` ;
- écran : coordonnées locales du `Control` après les transformations Godot.

Un delta écran est reconverti en delta image native avant de modifier la
calibration. Le pan, le zoom, la sélection, la visibilité des calques et le
pivot d'édition ne modifient jamais `O`, `U` ou `V`.

## Historique avant la V1.1

Arena Studio envoyait les snapshots complets dans `EditorUndoRedoManager`, ou
dans un `UndoRedo` de secours unique. Le booléen `dirty` était positionné par
les callbacks. Cette architecture mélangeait potentiellement les documents et
ne savait pas reconnaître un retour exact à la version sauvegardée.

Encounter Studio possède son propre parcours de working copy et conserve son
historique existant. La barre commune doit seulement l'exposer ; une action
Arena ne doit jamais entrer dans son historique.

## Historique et working copy V1.1

Chaque `ArenaEditSession` possède :

- une `ArenaDefinition` source, jamais modifiée par les gestes ;
- une copie de travail indépendante ;
- un `StudioHistoryController` local limité à 100 actions ;
- le snapshot et le fingerprint de la dernière sauvegarde ;
- les préférences d'édition non canoniques (pivot, calques, snap).

Une action stocke un snapshot avant et après. Une prévisualisation de drag ne
crée aucune action ; le relâchement gauche en crée exactement une avec
`commit_action(false)`. Échap, clic droit, changement d'outil, de map ou
d'onglet, perte de focus et désactivation restaurent le snapshot initial.

Le marqueur « Modifiée » compare le fingerprint stable de la working copy au
fingerprint sauvegardé. Undo jusqu'à ce fingerprint rend le document propre ;
Redo ou une nouvelle branche le rend à nouveau modifié.

## Outils disponibles avant modification

Le Studio proposait sélection, pan, ajout/retrait de cellules, bordure,
obstacles, terrains, spawns et vérification. Trois poignées techniques
modifiaient l'origine et les deux axes, sans outil Transform dédié, rotation,
échelle, pivot, annulation transactionnelle ni historique visible.

## Sauvegarde et récupération

- canonique : `res://data/arenas/<arena_id>.tres`, via `ResourceSaver` ;
- récupération : `user://dungeon_draft_studio/arena_studio/recovery/` ;
- points nommés :
  `user://dungeon_draft_studio/arena_restore_points/<map_id>/` ;
- test direct : contexte temporaire sous
  `user://dungeon_draft_studio/arena_studio/tests/`.

La sauvegarde synchronise les sous-ressources runtime, vérifie le résultat,
met à jour le fingerprint sauvegardé et conserve l'historique. Aucun chemin
Windows absolu n'est sérialisé.

## Responsabilités des modules

Le module Arènes édite la projection, la topologie et les métadonnées d'une
`ArenaDefinition`, valide la working copy, gère ses points de restauration et
lance une fixture temporaire dans le vrai combat.

Le module Rencontres édite les runs, vagues, compositions, formations et
contraintes de placement. Il ne modifie pas la calibration visuelle. La
coquille Dungeon Draft Studio ne fait que sélectionner le fournisseur
d'historique de l'onglet actif.

## Invariants runtime

- `PaintedMapVisualData` et `PaintedGridView` consomment la calibration
  sauvegardée ;
- unités, spawns, highlights et clics partagent cellule ↔ image ;
- `RoomGridLayout` reste l'autorité topologique ;
- le background, le foreground et les occluders en pixels ne sont pas déplacés
  par une transformation de grille ;
- les ressources forêt, volcan et espace ne sont jamais modifiées par les
  tests ;
- l'ancien éditeur `res://tools/arena_map_editor/` reste intact.

## Problèmes constatés au baseline

1. historique Arena raccordé à l'historique global de Godot ;
2. `dirty` booléen au lieu d'un fingerprint de contenu ;
3. absence de working copy garantie à l'ouverture d'un `.tres` ;
4. drag de calibration sans annulation sûre ni action nommée par geste ;
5. absence de rotation, échelle, pivot, snap et calques verrouillables ;
6. auto-fit existant mais sans diagnostic de condition ni aperçu avant/après ;
7. test direct forçant une sauvegarde et programmant deux changements de scène ;
8. requêtes de test persistantes pouvant devenir obsolètes ;
9. toolbar trop large à 1280×720 ;
10. suites unitaires vertes mais pas de test du vrai `play_custom_scene` ;
11. leaks ObjectDB/RID déjà présents dans le baseline Encounter Studio.

## Contrat livré en 1.1

La session Arena est désormais l'unique autorité pour la copie de travail,
l'historique et le marqueur de sauvegarde. Un geste transforme seulement
`grid_origin`, `axis_x` et `axis_y` de cette copie. La ressource de production
ne reçoit ces champs et les ancres qu'après validation et clic explicite sur
Sauvegarder ; les textures, calques, occlusions, réglages caméra, topologie et
données de gameplay sont conservés depuis la version disque la plus récente.

Le gizmo capture Shift (précision fine) et Ctrl (inversion temporaire du snap)
au moment de l'appui. Le mouvement est toujours recalculé depuis le snapshot de
départ. Relâcher termine une action unique ; Échap, clic droit ou interruption
restaure exactement ce snapshot. Le pivot, le pan, le zoom, la sélection et les
calques sont des préférences d'éditeur et ne salissent pas la map.
