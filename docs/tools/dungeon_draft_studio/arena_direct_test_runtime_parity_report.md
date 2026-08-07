# Arena Direct Test — Runtime Parity Fix

Date du diagnostic : 2026-08-07. Branche observée : `main`.

## Prévol

**OBSERVÉ** — `HEAD = origin/main = 29f307b5ff61822f266bbd2d14636ca8dcea2d95`, avance/retard `0/0`. Le commit `296f17c7c76626f1d2acd3cc5e650daf356d8ba8` est un ancêtre de ce HEAD.

**OBSERVÉ** — Avant l’écriture, le patch local correspondait exactement au patch annoncé `ROOM INTEGRATION AND GUIDED PIPELINE` : 9 fichiers suivis modifiés et 12 nouveaux fichiers, sans staged ni conflit. Les deux fichiers supplémentaires appartenaient exclusivement au bundle gelé autorisé ci-dessous.

### Bundle `produced` gelé

| Fichier | Taille | Dernière écriture UTC | SHA-256 prévol |
|---|---:|---|---|
| `arena.tres` | 38 204 | `2026-08-07T11:16:43.9018097Z` | `2d8abd212eb12ee64612079268ccca260ef21db993474b7731feb25023d7103e` |
| `modular_visual_profile.tres` | 358 | `2026-08-07T11:16:43.8934112Z` | `9381fb5b2116a0d35a1f5013a3a7607e6dc617675bf5be79c2f619a8a58b5190` |

**OBSERVÉ** — Une recherche exacte hors de ce dossier ne trouve aucune occurrence de `res://data/arenas/produced/room_01_forest/arena.tres`, `data/arenas/produced/room_01_forest/arena.tres` ou `produced/room_01_forest`. Aucune `RunData`, `RoomData`, `ArenaDefinition`, transaction ou manifeste ne référence ce chemin. La ressource forêt canonique observée est `res://data/arenas/room_01_forest.tres`.

**DÉCISION VALIDÉE** — Classification conservée : `UNREFERENCED_INCOMPLETE_PRODUCTION_BUNDLE`. Le bundle n’a été ni chargé, ni sauvegardé, ni normalisé, ni déplacé, ni stage.

## Chaîne réellement reproduite

```text
ArenaEditSession.working_arena
→ user://dungeon_draft_studio/arena_studio/tests/room_01_forest_3918833/arena.tres
→ user://arena_studio/test_request.json
→ arena_studio_test_runner.tscn
→ res://data/rooms/maps/painted_battle.tscn
```

| Preuve | Valeur |
|---|---|
| Fingerprint working copy | `d94341b2b1b00e947b3ceeb2709a35e8e06a08d2d2e48132b57d2a5a411de4cb` |
| Fingerprint copie `user://` | `d94341b2b1b00e947b3ceeb2709a35e8e06a08d2d2e48132b57d2a5a411de4cb` |
| Fingerprint ArenaDefinition runtime | `d94341b2b1b00e947b3ceeb2709a35e8e06a08d2d2e48132b57d2a5a411de4cb` |
| Chemin runtime chargé | même chemin temporaire `user://…/arena.tres` |
| Bundle `produced` demandé ou chargé | non |

Le runner supprime ensuite sa copie temporaire conformément au contrat `cleanup_on_load`.

## Diagnostic avant correction

**OBSERVÉ** — Sur le SceneTree réel HYBRID / `ALL_DEFINED` :

- 164 cellules de sol attendues par le render plan ;
- 111 nœuds `ArenaFeature_*` créés par le renderer historique ;
- 164 nœuds `ArenaTerrain_*` créés par `ArenaTerrainVisualRenderer` ;
- 111 cellules possédaient donc deux dalles ;
- les 164 dalles ArenaDefinition étaient enfants de `YSortedWorld` ;
- `PaintedGridView.draw_base_cells` et `draw_logic_types` étaient désactivés : la couche debug n’était pas la cause du sol massif ;
- `no_characters` était reçu et mémorisé, mais 4 vues d’unités, le déploiement et le HUD étaient quand même créés ;
- la caméra Studio était centrée en `(688, 418)` alors que le runtime était centré en `(688, 426)` à cause du profil de présentation ignoré par la preview.

**DIVERGENCE** — Le chemin confirmé était exactement le double pipeline soupçonné :

```text
ArenaRuntimeBridge → arena_visual_profile
→ battle.gd / ArenaFeatureRenderer historique
→ painted_battle.gd / ArenaVisualAssembler / ArenaTerrainVisualRenderer
```

## Correction

**DÉCISION VALIDÉE** — Une `ArenaDefinition` est désormais rendue uniquement par `ArenaVisualAssembler`. Le renderer historique reste actif pour les `RoomData` legacy.

**DÉCISION VALIDÉE** — Les dalles ArenaDefinition utilisent `ArenaTilesLayer`, parent dédié non Y-sorté. `YSortedWorld` conserve les unités, murs, décorations et occluders.

**DÉCISION VALIDÉE** — Les configurations directes sont résolues en options explicites et consommées par la vraie bataille, avec valeurs de production inchangées en l’absence de contexte de test.

**DÉCISION VALIDÉE** — Art/Jeu et `painted_battle` utilisent le même service de cadrage `cover`, le même offset de caméra et le même multiplicateur du profil de présentation. Le zoom numérique reste naturellement fonction de la taille du viewport ; à taille égale, les entrées et la sortie sont identiques.

## SceneTree après correction

Les cinq lancements obligatoires utilisent la même working copy et produisent chacun : 164 cellules attendues, 164 nœuds de dalle, 1 renderer, 0 doublon, 1 parent de sol `ArenaTilesLayer`, `y_sort_enabled = false`.

| Configuration | Mode appliqué | Héros préparés / visibles | Ennemis visibles | Déploiement | TurnQueue au constat | HUD | Debug terrain |
|---|---|---:|---:|---|---|---|---|
| `no_characters` | `visual_only` | 0 / 0 | 0 | non | non | non | non |
| `hero_trio` | `hero_preview` | 3 / 3 | 0 | non | non | non | non |
| `real_encounter` | `full_combat` | 3 / 0 avant placement | 4 | actif | non avant fin du placement | oui | non |
| `terrains` | `terrain_overlay` | 0 / 0 | 0 | non | non | non | `draw_logic_types` + `draw_void_cells` |
| `full_run` | `full_combat` | 3 / 0 avant placement | 4 | actif | non avant fin du placement | oui | non |

Exemple réel, cellule `(4, 4)` :

- chemin : `Battle/ArenaTilesLayer/ArenaTerrain_4_4` ;
- renderer : `ArenaTerrainVisualRenderer` ;
- texture : `res://tools/labs/dynamic_arena/assets/normalized/stone.png` ;
- transform : `X=(0.26875, 0)`, `Y=(0, 0.266666)`, origine `(-34.40002, -17.06665)` ;
- visible : oui ;
- parent Y-sorté : non ;
- seconde représentation de dalle : aucune.

## Validations

- scan/import Godot 4.7 : code 0 ;
- suite ciblée parité : 5/5, 699 assertions ;
- régressions working copy / renderer / pierre / Studio 1.2 / Studio 1.2.1 / trio : 57/57, 2 606 assertions ;
- cinq lancements du vrai runner : code 0 chacun ;
- suite globale : 806/819, 52 941/52 998 assertions, exactement les 13 échecs historiques annoncés.

## Empreintes du patch local préexistant

Ces empreintes ont été prises avant le correctif et servent à vérifier que le patch d’intégration n’a pas été réécrit par cette mission.

| Chemin | SHA-256 prévol |
|---|---|
| `addons/dungeon_draft_arena_studio/arena_studio_plugin.gd` | `3deb0863e42ae684582ee6a74a4e672db7021a2a51a41780a0400fd0377c9628` |
| `addons/dungeon_draft_arena_studio/services/arena_integration_service.gd` | `09b861594edfc1fb5440b923cb4d43b80ea39d4bf8b8f526bb22444c81a4ae98` |
| `addons/dungeon_draft_arena_studio/services/arena_integration_service.gd.uid` | `fc4e1443a6caf0c7f7aff4d491a53fe2b5e6f89dbf60cef5e46b03de6440f850` |
| `addons/dungeon_draft_arena_studio/services/arena_production_attachment_service.gd` | `4e5bbeb13cb2fb1ddab72cbb82b95cba80f5c529a3d779064a83080f94eecda5` |
| `addons/dungeon_draft_arena_studio/services/arena_run_authoring_service.gd` | `910c1b43dea99a11aff8383747e3ef1a6324935e6d89c7e3785f6c43e776827c` |
| `addons/dungeon_draft_arena_studio/services/room_integration_field_policy.gd` | `c8cc904ede40fcaf07f7ee2982704ccd554d445676905d16aef98dea95a54324` |
| `addons/dungeon_draft_arena_studio/services/room_integration_field_policy.gd.uid` | `d062f00d62db917bb3c4ebe9c8c62a3307dd30d2f47a5dc8abc78f9c8d99a020` |
| `addons/dungeon_draft_arena_studio/test/studio_v12_capture_matrix_runner.gd` | `1e0338a6efc806e4f2be61d42dc0bef013d6ef0d0b3d973b47529442c0e3ea1c` |
| `addons/dungeon_draft_arena_studio/test/studio_v121_capture_matrix_runner.gd` | `1b59f95180bc909bd3b9ce98d6e82ee7380e3d6987a739797dfd04ba76fa46cb` |
| `addons/dungeon_draft_arena_studio/ui/arena_studio_guided_tour.gd` | `4352e746fbc0343876c640d0e585bbcb54790ae1f39fe301ef2958117d5e2473` |
| `addons/dungeon_draft_arena_studio/ui/arena_studio_guided_tour.gd.uid` | `ea45d173007d0d4325503ea902d1490eee5bcea270e885f25f7c330c9805bef7` |
| `addons/dungeon_draft_arena_studio/ui/arena_studio_main.gd` | `fa749284f3ff49a8ae785dea213a8fa12db2d8a7b4dff24aebcd46babdb5e434` |
| `addons/dungeon_draft_arena_studio/ui/dungeon_draft_studio_main.gd` | `7a468a89844b681aaf8a045518c6305540718efd23090182ee4bfdca6e357c8c` |
| `addons/dungeon_draft_arena_studio/ui/embedded_studio_host.gd` | `a43623ccaf5bf64a30fa45c22ddd7b033ddee921a870b517693af166adb10421` |
| `docs/tools/dungeon_draft_studio/room_integration_guided_tour.md` | `50444e7825d1206c723376ffdcbdad007d145c6432791e9f4b1191bb567b6c4b` |
| `docs/tools/dungeon_draft_studio/room_integration_regression_report.md` | `f03c4c7d015445dd908bdd7e71a361679df0f3fb81d563b0aa3946f34ffc4762` |
| `docs/tools/dungeon_draft_studio/room_integration_user_guide.md` | `16990241c28debf64708f7ee37543170970051c02bfcb3afa1b98d1e36d18d32` |
| `docs/tools/dungeon_draft_studio/room_integration_verified_contract.md` | `25c87d2695f4eb0805e9ebcae9a887c016c1e156b914685f7b065a18416454f6` |
| `test/unit/test_dungeon_draft_studio_2_0.gd` | `1e2c8d9d7de83b02115c0ebb078727044e7005b7ef87480d0ed0b63359d8bea7` |
| `test/unit/test_room_integration_guided_pipeline.gd` | `c2717bce71361e96eb9f18e7eae3ac064c2bfa61c5fff88f4afebf36983f65a8` |
| `test/unit/test_room_integration_guided_pipeline.gd.uid` | `afc1a57f0dc7409c1d78318f6ffad14c0da1aac8326afa66d15c7fe352a5167c` |
