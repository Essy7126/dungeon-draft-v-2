# Rapport de migration Arena Studio

## Ressources couvertes

- forêt : `res://data/rooms/first_run_room_01.tres` ;
- volcan : `res://data/rooms/room_05_volcano.tres` ;
- espace : `res://data/rooms/room_06_space.tres`.

Les trois maps sont ouvertes via `ArenaLegacyImporter`. L'import conserve les dimensions 14 × 14, l'origine, les deux axes, le cadrage, la scène `painted_battle.tscn`, la rencontre, les six cellules de déploiement de chaque camp, les obstacles et les terrains. Les positions sont copiées sans recalcul : la déviation attendue des centres est donc 0 px.

Le test automatisé compare chaque centre, chaque type logique, les spawns et la scène runtime avant/après import pour les trois maps. Les tests existants du runtime peint, de l'intégration forestière et de l'ancien éditeur sont également exécutés comme garde-fous.

La topologie partagée historique et les trois `RoomData` ne sont pas remplacées. Une map importée n'est écrite sous `res://data/arenas/` qu'après une action **Sauvegarder** explicite. L'ancien éditeur `res://tools/arena_map_editor/` et son dossier `testv1/` restent disponibles et inchangés.

La ressource `forest_background_v3.png` sert toujours aux comparaisons du laboratoire historique. La production utilise `forest_background_v2.webp`; changer cette image pendant une migration modifierait le cadrage et n'est donc pas automatique.

## Retour arrière

Tant qu'une nouvelle `ArenaDefinition` n'est pas ajoutée manuellement à un `RunData`, le jeu continue de charger les anciennes `RoomData`. Supprimer une ressource nouvelle sous `res://data/arenas/` suffit à abandonner une migration sans toucher aux trois salles de production.
