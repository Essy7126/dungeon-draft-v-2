# Workspace détachable

Le plugin crée exactement un `StudioWorkspace`. `EmbeddedStudioHost` et `NativeStudioWindowHost` ne sont que deux hôtes capables de reparenter cette même instance : la session, la sélection et l’historique ne sont donc jamais dupliqués.

## Utilisation

Cliquez sur **Détacher** ou utilisez `Ctrl+Shift+D`. L’onglet Godot affiche alors un placeholder avec les actions de réintégration et de focus. Fermer la fenêtre native la masque et réintègre le workspace ; aucune ressource n’est sauvegardée implicitement.

Le raccourci est configurable dans Editor Settings via `dungeon_draft_studio/shortcuts/detach_workspace` (syntaxe comme `Ctrl+Shift+D`).

La fenêtre native est redimensionnable, non exclusive, avec une taille minimale de 1280 × 720 et une taille initiale de 1600 × 950. Son écran, sa position, sa taille, son état maximisé et l’état du workspace sont persistés dans `user://dungeon_draft_studio/ui_state/workspace.json`.

Le menu principal Godot **Dungeon Draft Studio : détacher / réintégrer** propose la même action. La désactivation du plugin ferme l’hôte et libère l’unique workspace proprement.
