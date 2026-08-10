# Couverture des champs runtime Arena

Statut : **WORKTREE_CANDIDATE**.

`ArenaRuntimeFieldCoverageService` relie chaque propriété Arena/Room à son consommateur : projection runtime, assembleur visuel, pathfinding, rencontre, manifest-only ou editor-only. La readiness refuse une propriété gameplay non supportée.

Le preview exact et Tester utilisent `ArenaRuntimeProjectionService`, `ArenaRuntimeBridge`, `ArenaVisualAssembler`, la vraie scène battle et `RunHeroResolver`. Le test direct copie la Room complète sous `user://`, compare working/temp/runtime fingerprints et interdit toute dépendance vers `res://data/arenas/produced/`.

La preuve runtime enregistre chemin chargé, scène, script, dalles attendues/rendues, doublons, parent Y-sort, consommation de configuration, héros, caméra et absence du bundle produced. Le certificat de production peut référencer ce résultat uniquement si son fingerprint correspond à la working copy courante.
