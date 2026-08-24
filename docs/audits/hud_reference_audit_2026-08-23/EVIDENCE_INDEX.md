# Index des preuves

Toutes les preuves runtime et tests se rapportent au SHA `52921204c5e4b52f195f0bf0269c1530f9b59b3f`. Les runners clonés/modifiés résident exclusivement sous `artifacts/audits/.../runners`.

## Référence vidéo

- Source : `20260823-1411-38.3121186.mp4`, 392 829 854 octets.
- SHA-256 : `A1B7C49F618A04FF6795CC1076FF9D8E400FC9FBAF9544E447B31F9C21FA30B3`.
- `reference/ffprobe.json` : 181,291 s; H.264 Main 2560×1592 progressif, 30 fps, 5 435 images; AAC LC stéréo 48 kHz.
- `reference/audio-analysis.log` : audio présent et non silencieux, moyenne -33 dB, maximum -13,1 dB; contenu sémantique non transcrit.
- `reference/contact-sheet-01.png` et `contact-sheet-02.png` : couverture des deux moitiés de la vidéo.
- `reference/analysis-strip-01.png` à `analysis-strip-03.png` : échantillonnage visuel régulier sur 0–180 s.
- `reference/keyframes/` : 79 PNG; `INDEX.md` est l'autorité sémantique sur les timecodes et corrige les slugs d'extraction trompeurs.
- Détection : `scene-detection.log` et `scene-detection-005.log`; les changements automatiques ont guidé l'extraction, jamais remplacé l'inspection visuelle.
- Outil : FFmpeg/ffprobe `9.0.1-essentials_build-www.gyan.dev`, archive portable conservée sous `tools/`; aucun composant installé dans le système.
- Archive outil : 111 253 802 octets; SHA-256 `FEC81AE03971D9DD4BE3EBE02E263BD2EC1D789483F931BDBA5F5715E65DA2E9`.

Au total, l'audit conserve 160 captures PNG : 76 de Dungeon Draft et 84 de la référence (79 keyframes, 2 planches contact, 3 bandes d'analyse).

## Git et environnement

- `artifacts/audits/hud_reference_audit_2026-08-23/logs/environment_initial.txt`
- Branche `main`; HEAD initial `52921204...`; message `test(odyssey): validate refined tactical scale`.
- Godot `4.7.1.stable.official.a13da4feb` à `C:\Godot\4.7.1\Godot_v4.7.1-stable_win64_console.exe`.
- Import sandbox : `godot_import.log` (diagnostics accès `user://`).
- Import hôte : `godot_import_host.log` (exit 0, mais 697 ObjectDB/23 ressources et RID texture signalés à la fermeture).

## Tests GUT sélectionnés

Forme exacte :

```powershell
& 'C:\Godot\4.7.1\Godot_v4.7.1-stable_win64_console.exe' --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://test/unit/<script>.gd -gexit
```

| Script | Résultat | Tests | Assertions | Durée | Log / divergence |
|---|---:|---:|---:|---:|---|
| `test_recraft_combat_hud_v1` | 6/6 | 6 | 50 | 5.012 s | `gut_test_recraft_combat_hud_v1.log` |
| `test_persistent_run_combat_hud` | 2/2 | 2 | 9 | 1.026 s | log homonyme |
| `test_three_character_party_hud` | 3/3 | 3 | 13 | 1.769 s | log homonyme |
| `test_turn_order_timeline` | 1/2 | 2 | 16 | 0.536 s | attentes portrait/fallback antérieures à Meshy V3 |
| `test_dark_pause_menu` | 18/19 | 19 | 26 198 | 1.438 s | deux textures focus/theme nulles |
| `test_inventory_equipment_system` | 10/10 | 10 | 93 | 0.504 s | passe |
| `test_in_combat_skill_evolution` | 13/13 | 13 | 265 | 7.319 s | warnings textures cartes absentes |
| `test_post_combat_flow` | 19/21 | 21 | 257 | 11.999 s | reward pool null/index persistence |
| `test_run_flow_post_combat` | 4/4 | 4 | 16 | 0.844 s | passe |
| `test_room_transition_async_lifecycle` | 9/10 | 10 | 29 | 1.741 s | spy obsolète `_next_action_id` |
| `test_skill_tree_screen_complete_ui` | 3/3 | 3 | 100 | 1.904 s | passe |
| `test_odyssey_achilles_solo_run` | 17/19 | 19 | 282 | 8.225 s | SubViewport headless vide; runtime graphique passe |
| `test_first_run_v2_contract` | 9/11 | 11 | 2 133 | 10.19 s | pool reward attendu ≥14, actuel 8 / index |
| **Total sélection valide** | **114/123** | **123** | **29 461** | **52.507 s** | **9 échecs; aucune affirmation “zéro régression”** |

Une tentative ultérieure `gut_test_combat_feedback_contract.log` a été interrompue : l'argument de filtre mal interprété a lancé la suite globale. Elle est exclue des totaux et de toute conclusion.

## Runners et rapports

| Runner | Méthode | Résultat | Artefact |
|---|---|---|---|
| Odyssey validation audit | vraie `odyssey.tres`, scènes/salles/HUD; transitions forcées étiquetées | PASS | `logs/odyssey_runtime_report.json`, `runtime/odyssey/` |
| First Run capture audit | vraie `first_run.tres`, six salles/trio/HUD; Battle immobilisée en déploiement pour inventaire roster | PASS | `logs/first_run_runtime_report.json`, `runtime/first_run/` |
| Achille promotion audit | vraie Odyssey, SpellCaster/actions/VFX/mort; transitions forcées et victoire résultat synthétique étiquetées | PASS | JSON sous `runtime/odyssey_actions_1920x1080/` |
| Overlay state audit | vraies RunData/unités/UI, fond production; pas de Battle, ouvertures forcées étiquetées | PASS | `logs/overlay_capture_report.json`, 14 captures |
| Skill tree audit | fixture de présentation avec données/écran production | PASS | 20 captures |
| Evolution capture audit | fixture historique clonée | FAIL après 3 captures | `logs/evolution_capture.log` |

Commandes graphiques :

```powershell
& 'C:\Godot\4.7.1\Godot_v4.7.1-stable_win64_console.exe' --path . --rendering-method gl_compatibility <scene-runner-audit.tscn>
```

## Captures runtime

76 PNG au total; 20 noms explicitement `1280x720`, 22 `1920x1080`, plus 13 captures d'action dans un dossier explicitement 1920×1080 et autres fixtures.

- `runtime/first_run/` — 12 : six salles × 1280/1920, trio réel en déploiement.
- `runtime/odyssey/` — 14 : hub, sélection, déploiement, combat, post-combat, résultat aux tailles disponibles.
- `runtime/odyssey_actions_1920x1080/captures/` — 13 : quatre actions réelles d'Achille, dégâts, changement de salle, mort/défaite, résultat.
- `runtime/overlay_fixture/` — 14 : idle, hover tooltip, selected, input locked, tooltip épinglé + pause, inventaire, restauration, aux deux tailles.
- `runtime/skill_tree_fixture/` — 20 : branches/états, dont 1280 et 1920.
- `runtime/evolution_fixture/` — 3 seuils avant échec du runner dérivé.

Captures pivots :

| État | Preuve | Ce qu'elle démontre |
|---|---|---|
| First Run trio / déploiement | `runtime/first_run/room_01_full_roster_1280x720.png` | panneaux persistants, débordement journal, bande basse |
| Odyssey Achille | `runtime/odyssey/battle_room_01_1280x720.png` | HUD solo réel 6 PA/3 PM et quatre capacités |
| Action resolving | `runtime/odyssey_actions_1920x1080/captures/room_01_achilles_spear_thrust_action.png` | vrai SpellCaster, état sélectionné/résolution |
| Après actions | `.../room_01_after_player_actions.png` | coûts, dégâts, journal, retour contrôle |
| Défaite | `.../room_03_achilles_death.png` | mort et overlay DÉFAITE |
| Post-combat | `runtime/odyssey/post_combat_no_reward_1280x720.png` | progression plein écran réelle |
| Tooltip/pause | `runtime/overlay_fixture/tooltip_pinned_pause_1280x720.png` | layer 120 au-dessus pause 70 |
| Inventaire | `runtime/overlay_fixture/inventory_over_selected_action_1280x720.png` | modal réel, sélection derrière |
| Arbre | `runtime/skill_tree_fixture/resolution_1280x720.png` | densité et scroll à faible résolution |

## Couverture manquante

- L'audio de la vidéo n'a pas été transcrit; aucune conclusion n'est tirée de sa sémantique ou de son sound design.
- Pas de capture dédiée vraie Battle pour cible illégale, move-targeting, enemy-turn isolé ou inventaire pendant vrai ciblage; ces points sont statiques ou fixtures et étiquetés.
- Pas de mesure profiler attribuable; seulement diagnostics de fermeture.
- Pas de test clavier/souris end-to-end physique; les runners appellent des handlers production.

## Preuves d'implémentation post-audit

Cette section ne modifie pas le corpus de vérité de l'audit initial. Elle décrit
les correctifs autorisés ensuite par l'utilisateur, construits sur le HEAD
`8cea852d18b890567122a29742e25ed19b4b0246` avec un worktree non commité.

| Périmètre | Résultat | Preuve |
|---|---:|---|
| Port HUD, raccourcis, réduction de mouvement, cycle de vie, marqueurs | 19/19, 287 assertions | `test_combat_hud_port`, `test_persistent_run_combat_hud`, `test_recraft_combat_hud_v1`, `test_combat_highlight_accessibility` |
| Flow, présentation et géométrie iso | 38/38, 380 assertions | `test_run_flow_isolation`, `test_combat_presentation_orchestration`, `test_iso_grid_view` |
| Cycle de vie asynchrone fin d'action / changement de salle | 10/10, 32 assertions | `test_room_transition_async_lifecycle`; double de Battle réaligné sur `_next_action_id` |
| Frame final / post-combat / mouvement réduit | 21/23, 268/273 assertions | `test_post_combat_flow`; deux divergences de catalogue de récompenses préexistantes |
| Parcours graphique continu | PASS | `artifacts/combat_flow_validation/report.json` |

Le runner continu emploie les vraies données et scènes First Run, avec un coup
final injecté et explicitement étiqueté. Il vérifie : HUD lié pendant Battle,
overlay local, capture propre avant overlay, PostCombatScreen réel, HUD délié,
transition vers la salle 2, puis libération du HUD après nettoyage.

Captures associées :

- `artifacts/combat_flow_validation/captures/deployment_non_color_markers.png` ;
- `artifacts/combat_flow_validation/captures/victory_overlay.png` ;
- `artifacts/combat_flow_validation/captures/post_combat.png` ;
- `artifacts/combat_flow_validation/captures/room_transition.png`.

La mesure runtime passe de 1 HUD / 4 UnitView pendant Battle à 1 HUD / 0
UnitView après post-combat, puis 0 HUD / 0 UnitView après `cleanup_run_state`.
Les avertissements RID/ObjectDB de fermeture persistent, mais ne correspondent
pas à une rétention de la scène HUD mesurée.
