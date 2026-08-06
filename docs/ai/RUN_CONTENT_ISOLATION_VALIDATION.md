# Run Content Isolation Validation

Statut : **COMPLETE WITH WARNINGS**  
Date : 2026-08-06  
Dépôt : `C:\Users\paolo\Documents\dungeon-draft-v-2`  
Branche : `main`  
HEAD initial et final validé : `bf2d6f7a8b6dabf2c8b74c5743852475f7c84e0a`  
`origin/main` observé initialement : même HEAD  
Godot : `4.7.stable.official.5b4e0cb0f`  
GUT : `9.7.1`

## Preuves fonctionnelles

**OBSERVÉ** — `RunData.content_profile` est l’autorité du chemin normal.
`GameManager.start_run()` appelle `RunHeroResolver`, qui construit trois copies
runtime de `UnitData` et ne remplace que les sorts, disciplines et slots actifs.

**OBSERVÉ** — La cinématique appelle `start_run(run_data)` pour les runs migrées.
Elle ne charge `hero_source_paths` que pour une run legacy sans profil. Le hub
continue de choisir et transmettre la `RunData` ; sa liste historique n’est plus
l’autorité des runs officielles.

**OBSERVÉ** — L’audit officiel retourne :

- trois `UnitData` de base partagés intentionnellement ;
- des textures, scènes et sons partagés par whitelist ;
- `progression_shared_count = 0` ;
- aucun conflit ;
- verdict `VALID`.

**OBSERVÉ** — Les deux tests réciproques sauvegardent puis rechargent des
fixtures sous `user://`. Une mutation de modificateur test laisse tous les
fingerprints main identiques ; une mutation de nœud main laisse tous les
fingerprints test identiques. La fixture de description portée par un profil
test temporaire atteint le runtime test via `RunHeroResolver` et n’apparaît pas
dans le runtime principal.

**OBSERVÉ** — La vue `RunContentCatalogService.as_editable_unit_view()` est
acceptée par `SkillTreeEditSession.open()`. Modifier la copie de travail ne
change pas le fingerprint du `CharacterProgressionProfile` source.

## Gates exécutés

| Gate | Résultat |
|---|---|
| Gate initial de séparation des flows | 22/22, 224 assertions |
| Nouvelle suite `test_run_content_isolation.gd` | 14/14, 1 493 assertions |
| Run, trio, GameManager, cinématique, hub | 117/117, 3 823 assertions |
| Skill Tree, sauvegarde, progression, choix en combat | 115/116, 5 644/5 645 assertions |
| `test_progression_lifecycle.gd` isolé | 17/18, 188/189 assertions |
| Arena Studio, Encounter Studio, hôte Studio | 76/76, 3 941 assertions |
| Suite globale finale | 775/788, 51 621/51 678 assertions, 77 scripts |
| Scan Godot post-migration | code 0 |
| Migration transactionnelle, passage 1 | `ok: true`, zéro partage interdit |
| Migration transactionnelle, passage 2 | `ok: true`, fingerprints identiques, aucune nouvelle cible |

Le scan conserve les diagnostics historiques suivants : quatre UID d’assets
(trois ennemis et le visuel Elfe) résolus par fallback de chemin, la redéclaration de `ItemDefinition`
sous `output/validation-feedback-candidate`, et six instances `ObjectDB` à la
fermeture. Aucun nouveau parse error ne provient des fichiers de mission.

## Échecs globaux reproduits et qualifiés

La suite globale finale a 13 tests rouges :

1. `test_dark_pause_menu.gd::test_theme_uses_distinct_texture_states_and_focus_style` — textures de focus nulles ;
2. `test_dynamic_arena.gd::test_all_sixteen_final_capture_files_are_present_and_non_empty` — capture `wall_assets_normalized.png` absente ;
3. `test_elf_archer_skill_tree.gd::test_archer_rank_two_resources_keep_their_contract` — attend un modificateur sur `eagle_eye.tres`, la Resource en porte deux ;
4. `test_elf_rank_two_disciplines.gd::test_cross_discipline_choices_install_independent_targeted_modifiers` — même dette de comptage Elfe ;
5. `test_forest_arena_integration.gd::test_les_22_captures_contractuelles_sont_presentes` — 22 captures absentes ;
6. `test_forest_dynamic_grid.gd::test_onze_captures_contractuelles_sont_presentes` — 11 captures absentes ;
7. `test_mountain_pass_blueprint.gd::test_six_exports_png_sont_pixel_alignes_en_1920_par_1080` — exports absents ;
8. `test_mountain_pass_blueprint.gd::test_logic_export_distingue_chaque_type_sans_deplacer_les_cellules` — export logic absent ;
9. `test_mountain_pass_blueprint.gd::test_foreground_est_transparent_et_ne_recouvre_aucune_cellule` — foreground absent ;
10. `test_mountain_pass_blueprint.gd::test_reference_remplit_un_environnement_bleu_gris_non_studio` — référence absente ;
11. `test_painted_run_integration.gd::test_pool_et_copies_de_production_sont_bit_a_bit_identiques` — trois images pool absentes ;
12. `test_progression_lifecycle.gd::test_return_to_title_clears_each_new_rank_two_modifier` — attend un modificateur, `eagle_eye.tres` en installe deux ;
13. `test_turn_order_timeline.gd::test_timeline_rotates_scales_animates_and_selects_units` — comparaison flottante `4.0 > 4.00000047683716`.

**HISTORIQUE** — La baseline documentaire avant cette mission signalait déjà
16 échecs globaux, notamment les assets/captures absents et les contrats hors
périmètre. Les 13 fichiers de test en échec et leurs données concernées ne sont
pas modifiés par cette mission. Pour la dette Elfe, `git show` prouve que le
HEAD initial contenait déjà deux modificateurs dans
`data/characters/elf/upgrades/eagle_eye.tres`, tandis que les tests exigeaient
un. L’échec progression est reproduit isolé. Aucun échec mission n’est nouveau.

## État Git et éléments non vérifiés

Le HEAD n’a pas changé : aucun commit, stage, push, branche, reset, stash, merge
ou rebase n’a été effectué. Le fichier de rapport Arena modifié par les tests a
été rétabli seul à son contenu initial ; aucune modification externe n’a été
fusionnée ou écrasée.

Non vérifiés manuellement : un parcours complet joué au clavier/souris depuis
le hub jusqu’à la fin des deux runs, l’équilibrage/attrition et la future UI
Studio 2.0 run-aware. Ces points ne bloquent pas l’isolation data/runtime prouvée
par les gates automatisés.

## Verdict

`RUN_CONTENT_ISOLATION_COMPLETE_WITH_WARNINGS`

L’isolation demandée est effective. Les avertissements portent sur la baseline
globale et les fuites/artefacts historiques, pas sur un partage de progression
restant.
