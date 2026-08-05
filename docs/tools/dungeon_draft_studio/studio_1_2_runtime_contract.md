# Dungeon Draft Studio 1.2 — contrat runtime

## Autorité et isolation

`ArenaDefinition` v2 est l’unique source de vérité d’une salle. Le canvas, le mode Construction dynamique, les vues Logique/Art/Jeu et la production manipulent la même `ArenaEditSession.working_arena`. Le chemin intégré n’instancie aucun `DynamicArenaLab`; `GridData`, `DynamicCellState`, les murs instanciés et les nœuds de preview sont des caches reconstruits.

Le preview clone le snapshot avant montage. Il ne démarre ni `GameManager`, ni `TurnQueue`, ni run, et ne sauvegarde aucune ressource. Le test direct sérialise une copie sous `user://` puis ouvre la vraie scène de combat.

## Chaîne commune

`ArenaRuntimeBridge` construit les ressources de runtime et choisit les données de grille. `ArenaVisualAssembler` monte terrains modulaires, murs dynamiques et props pour le preview comme pour `painted_battle`/`modular_battle`. `GridData` et `Pathfinder` restent les implémentations gameplay existantes.

Le mode visuel choisit la scène de façon déterministe : MODULAR utilise `res://data/rooms/maps/modular_battle.tscn`; PAINTED et HYBRID utilisent `res://data/rooms/maps/painted_battle.tscn` avec overlays partagés.

## Garanties

- aucune déduction gameplay depuis une texture ;
- aucun chemin absolu sérialisé ;
- murs dynamiques enregistrés comme overlays, sans remplacer le terrain de base ;
- preview et runtime comparables par `ArenaVisualAssembler.structural_signature()` ;
- anciennes salles peintes importées sans réécriture de leurs ressources sources.
