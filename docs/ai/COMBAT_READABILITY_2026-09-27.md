# Combat readability — 27 September 2026

Request: continue auditing and improving the actual game, restrained modern brown art direction. No delegation. Preserve the concurrent core, content and VFX work. Scope of this iteration: public consumable Cards combat hand and passive inspection; shared full descriptions in the loot receipt and collection.

## Audit and decisions

- Baseline actual Battle capture: `artifacts/dev/20260927-212903-readability-before-2823902d/03_combat_main.png`. 20px illustrations, duplicated names, legacy green surfaces, cramped costs and ranges. Player windows already use the brown dossier; combat was inconsistent.
- Keep the existing painted illustrations, enlarge them to 62px; single full-card click area, fixed PA/range badges, two-line names, thin rarity accent. Quiet tobacco surfaces and bronze selection. Separate the two reusable secours from consumed cards. No new animation behind text.
- Read-only delayed hover remains outside the hand and does not capture mouse input. Actual spell instance determines modified AP and effective range, class, rarity, upgraded form, self/line-of-sight targeting. Show only relevant V2 term explanations, not the incompatible legacy mark rules.
- Audit found incomplete improved descriptions: catalogue upgrade text sometimes says “Effet de base” or “Même effet”. A presentation resolver restores the full action and replaces obsolete duration/collision amounts from the resolved definition. Loot, collection and combat share this text. No balance/content change.

## Primary references

- Larian, Community Update 15: https://baldursgate3.game/news/community-update-15-absolute-frenzy_49 — hideable action subsets and filters, floating sheets, contextual equipment selection, reduce clutter while keeping necessary information. Application here: visually separate secours/cards, keep details in a passive inspector.
- Mega Crit, November 2024 Neowsletter: https://www.megacrit.com/news/2024-11-07-neowsletter-issue-4/ — larger top-bar hit areas, less wording, recognizable map icons and rarity cues. Application here: enlarge artwork and targets, suppress duplicate titles, use stable badge positions and restrained rarity color.
- Subset Games, Into the Breach: https://subsetgames.com/itb.html — official search excerpt describes telegraphed attacks (page access returned 403). Audit principle only: distinguish a known threat from an estimate. Current Catabase only forecasts some attacks; no claim of full enemy prediction and no new invented preview.
- User-provided Dofus references remain the guide for independent player windows and loot as illustrated items. No borrowed assets.

## Files and verification

`consumable_combat_card_view.gd` owns V2 faces/hover. Narrow hooks in `catabase_card_hand.gd` and `spell_hover_card.gd`; legacy versions preserve their presentation. `consumable_card_description.gd` also feeds `consumable_loot_receipt.gd`. `test_consumable_cards_readability.gd` covers complete upgraded text and presentation immutability.

`tools/consumable_cards/verify_readability.ps1 -RuntimeOnly` invokes the real selection → threshold → Battle cast → postcombat UI harness at 1280×720 and 1600×900 with isolated userdata. Checks five/seven cards, zero AP, keyboard focus, all 96 card forms fitting outside the hand, visible children ignoring mouse input, a real card cast consuming its copy, and player pages. Postcombat victory is a UI fixture, not a balance simulation. Invisible RichText scrollbars are excluded from hit-testing assertions because Godot manages their state internally.

Initial failures were corrected: invalid GDScript `is preload(...)` syntax, harness searching under Battle instead of persistent HUD, and an overstrict assertion on invisible internal scrollbars. These runs are not successes. First successful 24-capture report: `artifacts/dev/20260927-214838-combat-readability-dc5a083a/report.json`. Final checks recorded below after the explicit “Améliorée” label.

Final native report: `artifacts/dev/20260927-215205-combat-readability-2951e415/report.json`, PASS, 24 captures, both processes exit 0, no engine diagnostics. Inspected the 720p five/seven-card hand and the 900p improved Braise explanation. Tests: `artifacts/dev/20260927-215412-readability-regressions-79b5c51b/report.json`, PASS, 18 tests / 804 assertions, complete JUnit, no engine diagnostics: complete description tests (3), existing hover behavior (4), existing recraft HUD (11). The initial report writer incorrectly treated XML as JSON; the verified final report reads the saved complete JUnit and process status without rerunning the tests.

Full `dev.ps1 test cards`: `artifacts/dev/20260927-214750-test-cards-5611de39/summary.json`, 278 tests executed, 277 passed. The sole failure was the old loot assertion requiring the incomplete raw `upgradeText`. Updated that assertion to require the primary action for delta descriptions, keeping exact equality for standalone texts. Targeted rerun: `artifacts/dev/20260927-215905-readability-loot-regression-82e7f135/report.json`, all 4 loot tests passed, no diagnostics. The dev launcher retry was locked by another task (`215825…`), so the final GUT runtime used isolated userdata without import/cache changes. No other failed tests remain from the completed full run, but the full suite was not rerun after the assertion update. Final total for targeted suites: 22 passed. Formatting checks pass for the five owned helper/test/harness scripts; shared hand and hover files were not globally reformatted.

## Remaining audit areas

The pile browser still uses a textual modal; a later dedicated grid would improve large discard piles. Enemy intent presentation needs its own audit against actual telegraph data before expanding threat overlays. This iteration does not claim to resolve every game screen or validate balance.
