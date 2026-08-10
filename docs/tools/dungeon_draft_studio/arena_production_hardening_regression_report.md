# Arena Studio 2.0 — rapport de hardening production

Statut : **WORKTREE_CANDIDATE**, non committé, non poussé. Base locale observée : `main` / `5b7458becbaae6d16c2989f84fb12b60f3b4eb9c`. Date : 2026-08-10. Godot 4.7 stable, GUT 9.7.1.

Le patch local durcit working copies, snapshots, projection art v3, réimport transactionnel, production atomique, ownership, UPDATE/REPLACE, rollback, validation/métriques, preview Quick/Exact et test direct dans le SceneTree réel. Il ajoute une UX human-first, un dashboard read-only, un sandbox `user://`, des transactions de contexte triées, WeakRef/dictionnaires dans le graphe, caches par fingerprint et benchmarks 14×14/32×32/64×64.

Preuve Tester réelle : scène painted runtime, un renderer de sol, 164/164 dalles, zéro doublon, zéro mauvais parent, configuration consommée, caméra STUDIO_MATCH et fingerprints working/temp/runtime identiques (`221cd0a14ae110605c6063cf2bed6bb99820c7d7a47f4d7efc8a8a51fc68109c`). Le bundle produced gelé n’a pas été chargé.

## Validation finale

- GUT global : **889/902 tests**, **54 432/54 489 assertions**, 13 échecs ;
- comparaison d’identité : **13/13 attendus**, zéro nouvel échec, zéro échec historique manquant ;
- hardening UX/contexte : **10/10**, 87 assertions, dont le contrat 1200×896 ;
- matrice performance 14×14/32×32/64×64 : **1/1**, 26 assertions ;
- Studio 2.0 historique : **12/12**, 423 assertions ;
- Run Content Isolation : **14/14**, 1 493 assertions ;
- test direct réel : **PASS**, scène painted runtime réelle et configuration consommée ;
- audit visuel réel : **PASS** en 1280×720, 1920×1080, 2560×1440 et 1200×896 ; dialogue de production et visite guidée inspectés ;
- production atomique, art v3, intégration Room, catalogues, métriques, preview et Stone Floor : suites ciblées vertes.

L’audit 1200×896 a détecté puis fait corriger le dépassement vertical du dialogue de production : chaque onglet est désormais défilable et les boutons de confirmation restent visibles.

Les temps muraux de benchmark sont enregistrés mais ne constituent pas un seuil GUT strict sous charge globale ; l’absence de croissance ObjectDB sur 20 cycles reste bloquante. L’algorithme de composantes/articulations utilise une traversée itérative afin de couvrir la grille 64×64 sans dépassement de pile.

## Bundle produit gelé

`res://data/arenas/produced/room_01_forest/` reste classé **UNREFERENCED_INCOMPLETE_PRODUCTION_BUNDLE**. Aucune `RunData`, `RoomData`, `ArenaDefinition`, transaction ou manifeste ne référence son `arena.tres`. Le runner direct ne charge jamais ce dossier.

- `arena.tres` — 38 204 octets — SHA-256 `2d8abd212eb12ee64612079268ccca260ef21db993474b7731feb25023d7103e` ;
- `modular_visual_profile.tres` — 358 octets — SHA-256 `9381fb5b2116a0d35a1f5013a3a7607e6dc617675bf5be79c2f619a8a58b5190`.

Les hashes, tailles et dates UTC sont identiques au prévol. Les 187 fichiers Achilles/VFX/outillage non suivis et les 10 suppressions Achilles suivies sont un travail externe préservé.

## Réserves

- le scan Godot conserve l’erreur historique de classe globale dans `output/validation-feedback-candidate/data/items/item_definition.gd` ;
- les 13 échecs GUT historiques sont maintenus dans une allowlist exacte ;
- Godot signale encore les fuites RID/ObjectDB de fermeture déjà observées ;
- la revue interactive humaine des nouveaux écrans reste recommandée avant activation `CURRENT`.
- après la correction responsive finale, deux répétitions de la suite globale Windows n’ont pas atteint le résumé : une a dépassé 15 minutes en progressant dans Skill Tree ; l’autre a quitté nativement avec `-1` pendant le pipeline visuel, après réussite de la matrice performance. Aucun nouvel échec d’assertion n’est apparu avant ces interruptions. Le dernier run global complet reste 889/902 avec l’allowlist exacte ; les suites directement affectées ont ensuite réussi (10/10 UX, 12/12 pipeline visuel, 18/18 responsive, 12/12 Studio 2.0).
- les trois artefacts historiques `artifacts/arena_studio/arena_studio_test/*` ont retrouvé exactement leur contenu HEAD ; l’outil de patch a seulement ajouté leur saut de ligne terminal. Aucun rapport généré ni timestamp de test n’y subsiste.

Verdict technique : **ARENA_STUDIO_PRODUCTION_PIPELINE_COMPLETE_WITH_WARNINGS**.

**PATCH READY FOR BEGINNER PRODUCTION REVIEW**

L’audit gameplay v2.1 demeure **HISTORIQUE** : aucune modification de gameplay n’est incluse dans ce chantier.
