# Architecture d'Arena Studio

Arena Studio est un `EditorPlugin` avec écran principal public (`_has_main_screen`, `_make_visible`). Son interface n'accède pas à la hiérarchie privée de l'éditeur.

## Couches

- `domain/` : ressources typées `ArenaDefinition`, cellules, obstacles, spawns et rapport ;
- `services/` : transformation, édition, bordure, synchronisation runtime, sauvegarde, migration et export ;
- `importers/` : conversion non destructive des `RoomData` existantes ;
- `validators/` : règles de production et métriques ;
- `ui/` : espace de travail et canvas ;
- `test/` : lancement direct et rendu automatisé des captures.

`ArenaDefinition` hérite de `RoomData`. Elle est donc data-driven, versionnée, sérialisable et directement compatible avec le runtime. `ArenaRuntimeBridge` remplit les champs hérités `grid_layout`, `painted_map_visual_data`, zones de spawn, rencontre et scène de combat. Aucun `.tscn` généré n'est requis pour une map normale.

Les actions UI sont routées vers `ArenaEditingService`; la vue ne décide pas si un spawn est valide. Dans le plugin, chaque trait de pinceau est enregistré comme une seule action dans `EditorUndoRedoManager`. Les snapshots de récupération sont écrits dans `user://arena_studio/recovery` et ne remplacent jamais une ressource canonique.

Le test direct écrit uniquement une requête temporaire sous `user://`, puis lance `arena_studio_test_runner.tscn`. Le runner crée une `RunData` d'une salle, appelle `GameManager.start_preconfigured_run()` avec le vrai trio de production, puis `start_next_battle()` pour entrer immédiatement dans la salle sans clic intermédiaire. Le combat chargé est la scène réelle `painted_battle.tscn`.

Huit configurations sont transportées jusqu'au runner : déplacement, vue, ligne de vue, obstacles, terrains, spawns, Y-sort/occlusion et partie complète. Elles identifient explicitement l'intention du test sans créer de seconde implémentation du combat.

La grille 64 × 64 reste fluide car le canvas ne crée aucun nœud par cellule : il dessine les overlays dans un seul `Control` et ne recalcule que lors d'une modification ou d'un input.

## Preuves automatisées

- `test/unit/test_arena_studio_v1.gd` couvre transformation, bordure, imports, édition, validation, sérialisation, déterminisme 64 × 64, UI et export ;
- `arena_studio_runtime_smoke.tscn` lance le runner exact et vérifie `painted_battle.tscn`, `GridData`, `Pathfinder`, `IsoGridView` et `YSortedWorld` ;
- `arena_studio_capture_runner.tscn` produit les vues Création/Vérification en 1280 × 720, 1920 × 1080 et 2560 × 1440 sous `res://artifacts/arena_studio/screenshots/`.
