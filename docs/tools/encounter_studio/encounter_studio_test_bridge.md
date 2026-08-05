# Pont de test direct

Le bouton **▶ Tester** ne lance pas un simulateur simplifié.

1. `EncounterTestLauncher` valide la sélection.
2. Il génère un identifiant avec l’heure et `Time.get_ticks_usec()` — jamais avec le RNG global.
3. Il copie l’EncounterDefinition, la vague, la RoomData et une RunData à une salle sous `user://dungeon_draft_studio/encounter_studio/tests/<contexte>/`.
4. La requête contient seed, héros, options et chemin de résultat.
5. L’API publique `EditorInterface.play_custom_scene()` lance `EncounterStudioTestBootstrap.tscn`.
6. Le bootstrap recharge la copie `CACHE_MODE_IGNORE`, nettoie l’ancien état puis appelle l’API publique interne `GameManager.start_direct_encounter_test()`.
7. Cette API utilise la même préparation de run et appelle `start_next_battle()` sur la vraie `battle_scene`.
8. `EncounterStudioDebugBridge` écoute le vrai `combat_report_ready`, sérialise rapport et formation, nettoie `GameManager`, conserve le dernier résultat stable puis supprime uniquement le sous-dossier temporaire possédé.

La suppression vérifie deux fois que la cible est strictement sous la racine de tests et refuse la racine elle-même. Fermer le test avant sa fin exécute également le cleanup du bridge.

Le smoke headless `EncounterStudioRuntimeSmoke.tscn` prouve : scène peinte réelle, grille 14×14, seed 424242, formation valide, Room/Encounter temporaires, GameManager actif pendant la bataille et ressource canonique inchangée. Son résultat est écrit dans `res://artifacts/encounter_studio/test_direct_runtime_smoke.json`.

