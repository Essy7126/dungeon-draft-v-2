# Épreuve jouable sur le Gué du Léthé

La carte de sélection **L’Épreuve du Dialecticien** charge directement `data/rooms/philosopher_trial.tres`. Cette room est une copie indépendante du Gué du Léthé ; la campagne et sa carte source ne sont pas modifiées. Elle conserve les 114 cellules, les obstacles et la présentation du Léthé, avec un mage, un spectre et huit dalles permanentes supplémentaires.

Depuis la racine du projet, régénérer avec l’exécutable Godot du projet :

```powershell
Godot --headless --path . res://tools/philosopher_sprite_pipeline/build_trial_room.tscn
```

`trial_terrain_layout.gd` contient la disposition. Le générateur copie via `RoomDataSnapshotService`, peint via `ArenaDynamicEditingService`, crée le réseau avec `ArenaVortexNetworkService` et synchronise les ressources dérivées avec `ArenaRuntimeBridge`. Il écrit uniquement la room propre à l’épreuve et vérifie que la source est restée intacte. Les chemins de textures, de présentation et de terrain enregistré restent ceux du Léthé.

| Élément | Cellules |
| --- | --- |
| Eau | (5,5), (6,5), (7,5) |
| Glace | (5,7), (6,7) |
| Lave | (8,7), (8,8) |
| Eau électrifiée | (9,9) |
| Paire de vortex | (9,6) ↔ (7,4) |
| Départs d’Achille | (4,3), (5,3), (4,4), (5,4) |
| Mage / spectre | (9,7) / (7,7) |

La paire `philosopher_trial_portals` est bidirectionnelle et ouverte aux deux équipes. Les départs sont sans danger. Une route ordinaire relie les départs et les ennemis sans traverser de dalle nocive ni de vortex. La paire proche du mage lui fournit aussi une vraie position de lancement avantageuse dès le premier tour ; elle peut donc être observée sans scénario artificiel.

Tests GUT dédiés : `test/unit/test_philosopher_trial_terrain.gd` pour la room publiée et sa régénération, `test/unit/test_philosopher_terrain_ai.gd` pour les décisions et effets de terrain. Le probe d’entrée de l’épreuve vérifie séparément l’ouverture depuis la sélection et le rendu de chaque dalle enregistrée en combat.

La rencontre est copiée dans la room : elle autorise uniquement les deux départs ennemis sûrs. Sa distance minimale réserve le départ arrière au mage. Cette contrainte locale évite que le planificateur générique interprète les cellules de départ comme de simples préférences et fasse apparaître un adversaire ailleurs, notamment sur une dalle nocive. Le test de premier tour utilise ce planificateur réel.

Les cellules sont explicitement dupliquées une par une après le snapshot : une copie profonde de conteneur Godot ne suffit pas à détacher les Resource qu’il contient. L’assertion finale compare toujours l’empreinte complète de la source ; elle liste les champs divergents si une régression brise cette isolation.
