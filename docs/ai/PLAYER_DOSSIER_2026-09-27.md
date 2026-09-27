# Player dossier · 27 September 2026

Request: make the actual player windows legible and polished. Scope: public consumable Cards profile in ExpeditionScreen, inventory, collection, characteristics and mastery. Preserve rule/economy/save behavior and legacy profiles.

Audit: consumable_cards_workshop rendered every item/family and its actions in one vertical text list. Illustrations already exist but were unused. Character statistics were absent from this profile's characteristics window. Parent scrolling made navigation/actions disappear.

Final direction explicitly requested by the user: restrained modern brown. Tobacco and deep brown surfaces, ivory text, bronze selection. Painted assets remain recognizable and enlarged; independent scrolling for collection/details; six equipment slots around the actual hero preview; prepared/reserve and rarity labels accompany color. Original static etched-aureole shader behind the hero. Ornamental full-screen frame removed from the V2 player windows, victory receipt and level announcement.

References: user-provided Dofus 3 screenshots (paperdoll + inventory + independent stats); Larian Patch 3 https://baldursgate3.game/news/patch-3-mac-support-magic-mirror-more_93 (inventory and character-sheet consistency); Mega Crit https://megacrit.com/news/2024-11-07-neowsletter-issue-4/ (larger hit targets, quiet top bar, rarity cues). Official Dofus 3.7 devblog found but blocked by anti-bot; no claims based on its unread content.

Decisions: presentation only, no balance changes, no invented statistics. Existing card/item illustrations enlarged, restrained static shader rather than animation behind text. Rarity names accompany color.

Files: `ui/expedition/consumable_player_dossier.gd` specializes the existing workshop and invokes existing state/economy transactions. `player_dossier_skin.gd` owns spacing, color and typography; `dossier_sanctuary.gdshader` is the original procedural decoration. Narrow hooks in ExpeditionScreen mount the dossier with internal scrolling. Loot tile and result-row surfaces share the brown skin; acquisition and postcombat ordering stay unchanged. `tools/consumable_cards/verify_dossier.ps1` validates the real screens, with isolated userdata. `-RuntimeOnly` skips the exclusive import lock and performs no editor import.

Checks passed: 22 native captures at 1280×720 and 1600×900, no engine diagnostics, equipment/relic actions, prepare/reserve, live search, attribute persistence, readonly combat inspection, 48 families with persistent action buttons, 96 base/upgraded drop previews inside the viewport, receipt acknowledgement and save/restore. Report: `artifacts/dev/20260927-201419-player-dossier-3127699d/report.json`. Actual screenshots inspected, including 900p characteristics and deck and 720p inventory and hover.

Regression checks passed: 40 GUT tests across consumable integration (9), immutable loot receipt (4), post-combat flow (27). No engine diagnostics. Report: `artifacts/dev/20260927-201613-dossier-regressions-0b02e81e/report.json`.

Full `dev.ps1 test cards` attempted: `20260927-201135-test-cards-450cc8c2` stopped at import (0 tests) because a concurrently edited permutation VFX script had an inferred-type parse error. That script was corrected by its ongoing task; no edit to it here. Retry `20260927-201332-test-cards-d11e2ac8` was refused because another dev command held the engine lock. These attempts are NOT successful suite validation. Runtime checks above ran after the parse correction. No delegation; other tasks' modifications preserved.

Final change: same brown window/background/button skin on the victory receipt and level announcement. Final native verification: `artifacts/dev/20260927-201942-player-dossier-6bcc5db2/report.json` PASS, 22 captures, all four native processes exited 0, no engine diagnostics. Inspected the final loot hover as well. Formatting verified on the five owned GDScript components/harness files; the shared ExpeditionScreen was not globally reformatted.
