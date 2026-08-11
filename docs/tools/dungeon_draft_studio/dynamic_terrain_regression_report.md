# Dynamic Terrain Tile Replacement — Regression Report

Statut : **WORKTREE_CANDIDATE**  
Verdict : **DYNAMIC_TERRAIN_TILE_REPLACEMENT_COMPLETE_WITH_WARNINGS**.

## Baseline et sécurité

- dépôt : `C:\Users\paolo\Documents\dungeon-draft-v-2` ;
- branche : `main` ;
- HEAD/origin-main au prévol :
  `29bf19719be6988898bdbef4c16f5d5b44d7b2d6` ;
- avance/retard : `0/0` ;
- Godot : `4.7.1.stable.official.a13da4feb` ;
- GUT : `9.7.1` ;
- aucun stage, commit ou push effectué.

Sauvegarde prévol hors dépôt :
`C:\tmp\dungeon_draft_dynamic_terrain_preflight_20260811_175252`.

- patch binaire SHA-256 :
  `227395171bf5d4a15452ce1b026670572651dc87abd2c75f72ec1e48b1fc72c8` ;
- archive des nouveaux fichiers SHA-256 :
  `cacdb6ea87e32a91d8166975ab4124a5dc7d60e693be2176a3d447459fdc2942`.

Les patches Arena/production/Tester déjà présents ont été traités comme
protégés. Aucun fichier du bundle produit ni `first_run.tres` n’a été écrit par
la mission.

## Résultat fonctionnel observé

Le replay final de `first_run.tres`, salle 0, charge
`arena_principal.tres` et `painted_battle.tscn`. Boule de feu vise `(2,10)` :

- `terrain_changed` : 9 coordonnées exactes ;
- 9 états `fire/lava` durée 3 ;
- 9 nœuds `ArenaDynamicSurface` ;
- 9 bases `arena_floor` masquées ;
- durées 3 → 2 → 1 ;
- expiration au tick 3 ;
- 0 nœud dynamique résiduel ;
- 9 bases visibles restaurées ;
- fingerprint avant/après identique :
  `cb0642b784ff6dd6af8ba761b9f9d9732ffa9eada61695187d97bb7bf5e936a0`.

## Tests ciblés

| Suite | Résultat | Assertions | Lecture |
|---|---:|---:|---|
| Dynamic Terrain Tile Replacement | 11/11 | 236 | PASS |
| Forest Dynamic Grid | 13/14 | 1108/1119 | seul échec : 11 captures historiques allowlistées absentes |
| Forest Arena Integration | 11/12 | historique | seul échec : 22 captures historiques absentes |
| Direct Test Runtime Parity | 5/5 | 699 | PASS |
| Runtime Preview / Direct Test v2 | 4/4 | 54 | PASS |
| Stone Floor Visibility | 6/6 | 79 | PASS |
| Removed Cell Topology | 15/15 | 204 | PASS |
| Arena Atomic Production | 6/6 | 78 | PASS |
| Bundle Resolution | 9/9 | 95 | PASS |
| Room Wave Battle Parity | 1/1 | 371 | PASS |
| Run Content Isolation | 14/14 | 1 497 | PASS |
| Encounter Studio | 15/15 | 170 | PASS |
| Skill Tree Complete | 5/5 | 4 488 | PASS |
| Skill Tree Studio Hardening | 40/40 | 439 | PASS |
| Studio 2.0 | 11/12 | 423/424 | seul échec : deux avertissements UID du bundle protégé traités comme erreurs inattendues |

La suite dédiée couvre inventaire, IDs/textures, façade unique, vraie géométrie
Boule de feu, glace, eau, cellules invalides, durée, restauration de bases non
NORMAL, réactions, vapeur, overrides, non-mutation, adapter, preview exacte et
vingt cycles de lifecycle.

## Inventaire du patch terrain

Fichiers existants modifiés depuis le prévol : 19.

- Studio : `arena_runtime_preview.gd`, `arena_runtime_projection_service.gd`,
  `arena_runtime_state.gd`, `dynamic_surface_visual_adapter.gd`,
  `arena_terrain_visual_renderer.gd`, `arena_studio_main.gd` ;
- runtime combat : `battle.gd`, `cell_surface_state.gd`,
  `dynamic_surface_service.gd`, `terrain_interaction_resolver.gd`,
  `terrain_effects.gd` ;
- données : `terrain_effect_data.gd`, `eau.tres`, `feu.tres`, `glace.tres`,
  `lave.tres`, `vapeur.tres` ;
- tests/UI : `test_forest_dynamic_grid.gd`, `inspect_panel.gd`.

Fichiers créés : 20.

- runtime : `terrain_surface_runtime_service.gd`,
  `terrain_surface_id_resolver.gd`, `terrain_surface_visual_resolver.gd` ;
- preuve : `dynamic_terrain_runtime_trace_runner.gd/.tscn`,
  `dynamic_terrain_capture_runner.gd/.tscn` ;
- tests : `test_dynamic_terrain_tile_replacement.gd` ;
- documentation : `dynamic_terrain_current_contract.md`,
  `dynamic_terrain_runtime_architecture.md`,
  `dynamic_terrain_visual_replacement_contract.md`,
  `terrain_interaction_matrix.md`, `dynamic_terrain_user_guide.md`, le présent
  rapport ;
- six fichiers `.uid` associés aux nouveaux scripts GDScript.

## Captures

Runner : `dynamic_terrain_capture_runner.tscn`.

- 13 cas ;
- 4 résolutions : 1280×720, 1920×1080, 2560×1440, 1200×896 ;
- 52 PNG + `capture_metrics.json` ;
- échecs runner : 0 ;
- coordonnées manquantes : 0 ;
- coordonnées inattendues : 0.

Les PNG ont été inspectés réellement : texture complète, projection identique,
sol de base masqué, grille/unités/murs au-dessus, absence de doublon et retour
exact. La vapeur montre explicitement `Actif=1`, `Rendu=0`,
`Manquantes=0`.

## Suite globale finale

Export JUnit :
`res://artifacts/dynamic_terrain_tile_replacement/gut_global_postfix_1786470330.145.xml`.

- scripts : 97 ;
- tests : 980 ;
- réussis : 959 ;
- échoués : 21 ;
- assertions : 55 464 / 55 534 ;
- durée cumulée JUnit : 343,88 s ;
- durée processus : 360,2 s.

Comparaison avec le run global antérieur au dernier correctif de typage :

- avant : 957/980 tests, 55 108/55 181 assertions, 23 tests en échec ;
- final : 959/980 tests, 55 464/55 534 assertions, 21 tests en échec ;
- nouveaux échecs : 0 ;
- échecs supprimés : 2, Room Wave Battle Parity et Recraft Combat HUD ;
- 13/13 échecs de `tools/gut_historical_allowlist.json` sont toujours présents ;
- 8 échecs supplémentaires étaient déjà présents avant le correctif terrain.

Les huit divergences locales non allowlistées sont :

1. le dashboard attend encore `UNREFERENCED_INCOMPLETE_PRODUCTION_BUNDLE`, mais
   observe `OWNED_DIRTY` ;
2. deux anciens tests de production attendent des dictionnaires `visual_report`
   ou `status` désormais absents de leurs résultats de fixture ;
3. Studio 2.0 et le pipeline guidé rencontrent l’UID invalide protégé ;
4. trois tests attendent encore `first_run_room_01.tres`, alors que le
   `first_run.tres` local protégé référence déjà `arena_principal.tres`.

Ces huit tests figurent déjà dans le run pré-correctif à 23 échecs. Aucun test
terrain dynamique, de topologie, de parité Direct Test, de vague, de contenu de
run ou de Skill Tree n’ajoute un échec.

## Scan/import et intégrité

Le scan/import Godot 4.7.1 termine avec le code 0. Les deux diagnostics connus
restent :

- l’UID invalide du `modular_visual_profile.tres` protégé, avec repli sur le
  chemin texte ;
- un conflit de classe historique sous le dossier non suivi/généré
  `output/validation-feedback-candidate/`.

À la fermeture de ce scan, Godot rapporte 1 RID de texture dummy, 1 002
instances ObjectDB et 20 Resources encore en usage.

Le dossier gelé contient toujours exactement quatre fichiers, tous identiques
au prévol :

| Fichier | Octets | SHA-256 | Prévol |
|---|---:|---|---:|
| `arena.tres` | 36 077 | `34af275b7ea8a4a5f2ca87cf807a188bb6f6c0570e977fab018bdf896f58607f` | identique |
| `arena_principal.tres` | 36 384 | `3d336937938d6d506c85b15ca20bacbf9c4daf07144dc7706e92c6f169d1b520` | identique |
| `modular_visual_profile.tres` | 359 | `18e27b8b0527ec0b1de489cf7eab4d2d4b986fc99f2d2c62bc0b0a647a7c60a9` | identique |
| `production_manifest.json` | 134 800 | `0bb0c700412a2136cfe08b8bfa32567ea65373ee31600a1e09b435981899409b` | identique |

`data/runs/first_run.tres` est également identique au prévol :
`657b9c1700e10a59624a5c83602cc4dee3af88a9f60bdd0ee0f9eb24cdcc6bc1`.

La recherche exacte confirme qu’aucune Resource canonique ne référence
`.../room_01_forest/arena.tres`. La référence préexistante de `first_run.tres`
vise `.../room_01_forest/arena_principal.tres`. Le runner terrain ne charge pas
`arena.tres` comme source de reproduction.

Les trois artefacts suivis génériques réécrits mécaniquement par les tests sous
`artifacts/arena_studio/arena_studio_test/` ont été restaurés exactement depuis
`HEAD`, puisqu’ils étaient propres au prévol. Les captures et journaux propres à
la mission restent isolés sous
`artifacts/dynamic_terrain_tile_replacement/`.

## Avertissements et leaks connus

Le bundle préexistant
`data/arenas/produced/room_01_forest/arena_principal.tres` référence un UID
invalide `uid://ogq7y82pxxba` pour `modular_visual_profile.tres`. Godot utilise
le chemin texte de secours. La mission n’a pas modifié ce bundle protégé.

Les runners graphiques/headless signalent à l’arrêt des ressources/RID encore
en usage. Ces leaks existaient dans le lifecycle des scènes complètes et ne sont
pas une croissance des états de surface : le test dédié de vingt cycles passe.

La suite globale finale signale à la fermeture 74 690 instances ObjectDB, 910
Resources et des RID dummy encore en usage. Cette dette de teardown est donc
conservée comme avertissement ; elle n’est pas reproduite par les vingt cycles
du service de surface.

Deux tentatives globales intermédiaires n’ont pas valeur de résultat : la
première a atteint son timeout avec deux anciens processus graphiques encore
actifs, la seconde était privée d’écriture dans `user://` par le sandbox. Les
processus ont été nettoyés et les deux runs finaux hors sandbox ont terminé en
347,1 s et 360,2 s. Seul le second, exporté en JUnit, est la preuve chiffrée de
référence.

## État Git final

- branche : `main` ;
- HEAD = `origin/main` =
  `29bf19719be6988898bdbef4c16f5d5b44d7b2d6` ;
- avance/retard : `0/0` ;
- staged : 0 ;
- conflits : 0 ;
- `git diff --check` : code 0 ;
- le worktree reste volontairement sale : patches protégés préexistants +
  patch terrain `WORKTREE_CANDIDATE` ;
- aucun commit, push ou stage.

## Verdict

Le remplacement visuel eau/glace/lave, la durée autoritative, la restauration
exacte, les réactions, la parité Preview/Direct Test/vraie run et la
non-mutation des Resources sont démontrés. Les avertissements restants sont les
divergences locales protégées, l’UID invalide et les leaks de fermeture déjà
présents.

**DYNAMIC_TERRAIN_TILE_REPLACEMENT_COMPLETE_WITH_WARNINGS**

Le statut ne devient pas `CURRENT` sans commit puis revalidation au même SHA.
