# VFX_FLIPBOOK_FOUNDATION_MAIN_INTEGRATION_REPORT

## 1. Verdict

`MAIN_INTEGRATION_PUSHED`

La fondation VFX Flipbook V1 est validée techniquement sur le dernier `origin/main` observé, sans régression VFX ou Studio et avec les mêmes 24 identités d'échec globales que la baseline. Le push fast-forward initial a été exécuté et vérifié sur `70c19afe70b94fea126ba37ad4f9df1c3ef00d91`. Ce verdict ne constitue pas une approbation artistique : les atlas sont des fixtures synthétiques `TECHNICAL_PLACEHOLDER`.

La présente mise à jour de confirmation est le seul delta postérieur à cette preuve distante. Elle doit être poussée à son tour par fast-forward, sans force, puis vérifiée par égalité de `HEAD`, `origin/main` et `ls-remote`.

## 2. Vérité Git initiale

- dépôt principal : `C:\Users\paolo\Documents\dungeon-draft-v-2` ;
- branche principale : `main` ;
- HEAD principal initial : `afc458ddec20f1753926405f229389214ded6059` (`maps`) ;
- `origin/main` après `git fetch --prune origin` : `afc458ddec20f1753926405f229389214ded6059` ;
- statut principal initial : propre ;
- candidat retenu : `codex/vfx-flipbook-foundation-v1-a45a62be9a0e` ;
- base candidate : `a45a62be9a0e3423029dd33d344b3b69fca3b55d` ;
- merge-base candidat / `origin/main` : `a45a62be9a0e3423029dd33d344b3b69fca3b55d` ;
- delta base candidate vers `origin/main` : uniquement `asset/map/painted/greece/map2-_achilles.png` et son `.import` ;
- intersection avec les 49 chemins Flipbook : zéro ;
- worktrees au prévol initial : 26, puis 27 après apparition du chantier Achilles, puis 28 après création du worktree d'intégration ;
- branche et chemin d'intégration étaient absents avant leur création.

Le worktree principal n'a reçu aucune écriture de cette mission hors fetch. Deux fichiers Achilles non suivis y sont apparus ensuite via le travail parallèle : `asset/map/painted/greece/maps_achille_dalle.png` et son `.import`. Ils sont préservés et sans chevauchement VFX.

## 3. Travail concurrent

Snapshot après validation technique, avant commit documentaire. Colonnes : modifications non indexées (`M`), indexées (`S`), non suivies (`?`), chevauchement avec les 49 chemins Flipbook (`VFX`).

| Worktree | Branche | HEAD | M | S | ? | VFX |
|---|---|---:|---:|---:|---:|---:|
| `dungeon-draft-v-2` | `main` | `afc458ddec20` | 0 | 0 | 2 | 0 |
| `achilles-real-sword-odyssee-v1-20260814_104556` | `integration/achilles-3d-real-sword-odyssee-v1` | `afc458ddec20` | 9 | 0 | 87 | 0 |
| `achilles-sword-shield-vertical-slice-v1-20260813_203129` | `codex/achilles-sword-shield-vertical-slice-v1` | `860823b5a439` | 0 | 0 | 0 | 0 |
| `character-integration-blender-v1` | `codex/character-integration-blender-v1` | `c372ba5bad18` | 0 | 0 | 0 | 0 |
| `character-integration-godot-sandbox-v1-20260813_171923` | `codex/character-integration-godot-sandbox-v1` | `888d2a1c6941` | 0 | 0 | 0 | 0 |
| `dungeon-draft-run-flow-closure` | détaché | `94fcdc700cf5` | 28 | 0 | 13 | 0 |
| `dungeon-draft-run-flow-closure-candidate` | détaché | `94fcdc700cf5` | 31 | 0 | 16 | 0 |
| `dungeon-draft-run-flow-closure-final` | détaché | `94fcdc700cf5` | 46 | 0 | 0 | 0 |
| `dungeon-draft-run-flow-closure-repro` | détaché | `94fcdc700cf5` | 30 | 0 | 16 | 0 |
| `dungeon-draft-run-flow-closure-repro2` | détaché | `94fcdc700cf5` | 30 | 0 | 16 | 0 |
| `vfx-flipbook-foundation-v1-8bd9d455bced` | `codex/vfx-flipbook-foundation-v1-8bd9d455bced` | `8bd9d455bced` | 5 | 0 | 36 | 41 |
| `vfx-flipbook-foundation-v1-a45a62be9a0e` | `codex/vfx-flipbook-foundation-v1-a45a62be9a0e` | `b00b040572a1` | 0 | 0 | 0 | 0 |
| `vfx-flipbook-integration-main-afc458ddec20` | `integration/vfx-flipbook-foundation-v1-main-afc458ddec20` | `72a0ed9d1b4e` | 0 | 0 | 0 | 0 |
| `hud-production-v1` | `feat/hud-production-v1` | `17f586690a5b` | 0 | 0 | 0 | 0 |
| `hud-studio-integration` | `integration/hud-studio-mvp` | `3ccbb9566b94` | 0 | 0 | 0 | 0 |
| `hud-studio-mvp` | `feat/hud-studio-mvp` | `49c912c992be` | 0 | 0 | 0 | 0 |
| `hud-studio-production-v1` | `feat/hud-studio-production-v1` | `a8730711797c` | 0 | 0 | 0 | 0 |
| `observatory-foundation` | `feature/observatory-foundation` | `52b6f4b26fb3` | 0 | 0 | 0 | 0 |
| `observatory-frontend` | `feature/observatory-frontend-v0` | `3d07c08642ad` | 0 | 0 | 0 | 0 |
| `observatory-frontend-v1` | `feature/observatory-frontend-v1` | `3d96354ab513` | 0 | 0 | 0 | 0 |
| `observatory-frontend-v1-1` | `feature/observatory-frontend-v1-1` | `688b7408aff3` | 0 | 0 | 0 | 0 |
| `observatory-live-v1-2` | `feature/observatory-live-v1-2` | `11dd7f91acbb` | 0 | 0 | 0 | 0 |
| `observatory-run-data-v1` | `feature/observatory-run-data-v1` | `4ed9f6cbb300` | 0 | 0 | 0 | 0 |
| `observatory-truth-v1-1` | `feature/observatory-truth-v1-1` | `b9e5a0161fc8` | 0 | 0 | 0 | 0 |
| `studio-unified-v1` | `integration/dungeon-draft-studio-unified-v1` | `497322cc196e` | 0 | 0 | 0 | 0 |
| `tactical-impact-v1` | `feat/tactical-impact-v1` | `b1a6922cfbcb` | 0 | 0 | 0 | 0 |
| `validation-feedback-baseline` | détaché | `1aadd1bd1dec` | 0 | 0 | 0 | 0 |
| `validation-feedback-candidate` | `feat/ui-snapshots-combat-feedback` | `2474824b78b0` | 0 | 0 | 0 | 0 |

Le worktree `8bd9d455bced` est un prédécesseur historique connu, pas un travail concurrent à fusionner. Il a été laissé intact. Les cinq worktrees Run Flow touchent notamment `docs/ai/**` ; aucune écriture partagée n'a été tentée. Aucun worktree concurrent ne touche le code, les tests, les lanceurs ou les assets Flipbook intégrés.

## 4. Audit indépendant du candidat

Le rapport `docs/tools/vfx/vfx_flipbook_foundation_v1_report.md`, le diff complet, les fichiers non suivis, les UID et les chemins générés ont été relus indépendamment.

- 49 chemins : 42 ajouts et 7 modifications ;
- 3 072 insertions, 10 suppressions de lignes ;
- aucune suppression de fichier, aucun rename, aucun sous-module, aucun symlink ;
- whitelist respectée : VFX, laboratoire, lanceurs explicitement demandés, test ciblé et `docs/tools/vfx/**` ;
- aucun `project.godot`, `docs/ai/**`, gameplay, Arena, `core/**`, `battle/**` ou carte ;
- 1 563 déclarations UID contrôlées dans l'arbre candidat, zéro doublon ;
- 16 UID nouveaux, tous résolus et sans collision avec `origin/main` ;
- `git diff --check` et `git diff --cached --check` propres ;
- artefact indésirable `test/unit/test_vfx_flipbook_foundation.gd.uid` explicitement exclu.

Corrections issues de l'audit : validation contextuelle limitée à la séquence active, invariant du module typé, manifestes malformés sûrs, fallback qualité, copie transiente, snapshot durable chargeable, Play/Pause/Scrub réels, assertions des 14 scénarios, fail-fast des captures, watchdog Smoke, lanceur Windows robuste, chaînes UTF-8 corrigées et rapport remis à jour.

Une dernière anomalie a été découverte seulement après le premier cherry-pick : la suppression d'une ligne vide terminale avait changé le SHA-256 du générateur après la génération du manifeste. Le générateur a été rejoué deux fois ; seul le manifeste a changé à la première passe, zéro octet à la seconde. La suite candidate finale est revenue à 18/18 et 462 assertions. Le candidat final propre est `b00b040572a15b4fa0d5e064455fa9a06a353a7c`.

## 5. Lanceur utilisateur

Fichiers :

- `LANCER_LAB_VFX_FLIPBOOK.cmd` ;
- `OUVRIR_LAB_VFX_FLIPBOOK_DANS_GODOT.cmd` ;
- `tools/launchers/launch_vfx_flipbook_lab.ps1` ;
- `docs/tools/vfx/vfx_flipbook_foundation_user_guide.md`.

Ordre de détection : `-GodotPath`, `GODOT4_BIN`, `GODOT_BIN`, cache utilisateur, `Get-Command godot`, `Get-Command godot4`, répertoires usuels, puis sélection manuelle hors Smoke. Seule une version 4.7 est acceptée. Le Smoke force `NoPrompt`, le contrôle de version a un timeout de 10 s et le script Smoke un watchdog de 15 s.

Matrice intégrée :

| Cas | Contexte | Résultat |
|---|---|---|
| Run `.cmd` | racine d'intégration | code 0, scène ciblée, succès Run |
| Edit `.cmd` | CWD `C:\Windows\Temp` | code 0, éditeur sur la scène ciblée |
| Smoke | jonction `C:\Users\paolo\AppData\Local\Temp\Codex VFX Integration Space 20260814` | code 0, frame 8, résidu 0 |
| Smoke cache | racine, sans chemin explicite | code 0, détection `cache utilisateur`, frame 8, résidu 0 |
| faux exécutable | chemin absent, Smoke sans dialogue | code 1, message clair, log et commande de secours |

Cinq transcripts non vides ont été écrits sous `%LOCALAPPDATA%\DungeonDraft\logs`, entre 1 688 et 2 022 octets. Le dépôt n'est pas muté par les lanceurs, à l'exception du `.uid` de test généré par un scan Godot puis supprimé du worktree avant commit.

## 6. Baseline du main

Base mesurée : `afc458ddec20f1753926405f229389214ded6059`.

Un worktree neuf a d'abord nécessité une importation complète. Les scans à froid interrompus à deux secondes ont exposé des erreurs de typage hors VFX pendant la construction du cache ; ils ne sont pas utilisés comme baseline. `Godot --headless --editor --path . --import` a fini code 0, sans parse error, puis les commandes stables suivantes ont été mesurées.

| Gate | Commande / résultat |
|---|---|
| Scan normal | `Godot --headless --editor --path . --quit-after 2` ; code 0 ; 11 `SCRIPT ERROR`, 11 appels sur placeholder, 0 parse error, 3 UID invalides uniques |
| Scan recovery | `Godot --headless --editor --recovery-mode --path . --quit-after 2` ; code 0 ; 0 script error, 0 parse error |
| VFX historique | GUT `test_vfx_lab.gd` ; code 0 ; 11/11, 638 assertions, 0,525 s GUT, 3,446 s murales |
| Studio | GUT `test_vfx_studio_slice.gd` ; code 1 ; 13/14, 215/216 assertions, 18,456 s GUT, 22,327 s murales ; un seul échec connu |
| Lanceur | N/A : absent de la base |
| Suite globale | commande canonique ci-dessous ; code 1 ; 105 scripts, 1 156 tests, 1 132 réussis, 24 échecs, 56 415/56 599 assertions, 509,931 s GUT, 521,270 s murales |

Commande globale canonique, identique avant et après :

```text
Godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://test/unit -ginclude_subdirs -gprefix=test_ -gexit
```

La première tentative globale baseline s'est terminée sans résumé au test de matrice de performance ; ce test a ensuite passé isolément 1/1, 26 assertions, 97,571 s. La relance canonique complète ci-dessus est la seule baseline globale retenue.

Le vérificateur historique observe 24 identités alors que `tools/gut_historical_allowlist.json` en attend 13. Les 11 identités supplémentaires sont donc déjà présentes sur le dernier `main`; elles ne sont pas reclassées en succès et l'allowlist n'est pas modifiée par cette mission.

Fingerprints SHA-256 baseline :

```text
shield_lifecycle.tres       d66985d018270d021dda39bc79e09e409e21a9eea3de5e09d4bd42c306501b31
lightning_multi_target.tres 81c44745be2bab9d6523c592b327a48937a34906226a886f176237464e17a02c
player_path_preview.tres    4bdb23b9160dd3c9c5a13d3de252c95ab22dc84fde67e075bbb4734553c153d2
```

Le commit `maps` est présent et ancêtre de la base.

## 7. Commit candidat

- branche : `codex/vfx-flipbook-foundation-v1-a45a62be9a0e` ;
- SHA final : `b00b040572a15b4fa0d5e064455fa9a06a353a7c` ;
- message : `feat(vfx): add flipbook foundation and standalone lab launcher` ;
- 49 fichiers, aucune suppression ;
- worktree candidat propre ;
- candidat non poussé séparément.

Validations finales candidates : Flipbook 18/18 et 462 assertions ; VFX historique 11/11 et 638 ; Studio 13/14 et 215/216 avec le seul échec connu ; générateur deux passes idempotentes ; 30 captures et trois planches candidates conservées sous `%TEMP%\codex_vfx_flipbook_candidate_integration_captures_20260814`.

## 8. Intégration

- worktree : `C:\Users\paolo\Documents\dungeon-draft-v-2-worktrees\vfx-flipbook-integration-main-afc458ddec20` ;
- branche : `integration/vfx-flipbook-foundation-v1-main-afc458ddec20` ;
- base : `afc458ddec20f1753926405f229389214ded6059` ;
- cherry-pick tenté sans résolution automatique ;
- conflit : aucun ;
- commit technique intégré final : `72a0ed9d1b4e38897620c8e634bca9e77c50f88f` ;
- `afc458d` reste ancêtre du commit technique ;
- la carte Achilles de `main` reste présente ;
- `git diff origin/main...HEAD --check` propre.

Le commit technique a été amendé avant toute publication pour incorporer le manifeste régénéré et le rapport candidat corrigé. L'historique final conserve un seul commit technique Flipbook au-dessus de `maps`.

## 9. Validation après intégration

| Gate | Résultat intégré |
|---|---|
| Scan normal stable | code 0 ; 0 script error, 0 parse error ; trois UID historiques uniques ; aucun diagnostic Flipbook |
| Scan recovery | code 0 ; 0 script error, 0 parse error |
| Flipbook | 18/18, 462 assertions, code 0, 3,794 s GUT, 6,320 s murales |
| VFX historique | 11/11, 638 assertions, code 0, 0,515 s GUT, 3,544 s murales |
| Studio | 13/14, 215/216 assertions, code 1, 19,087 s GUT, 23,734 s murales ; même échec et mêmes trois UID |
| Générateur | codes 0/0 ; 7 artefacts ; 0 différence entre les deux passes |
| Lanceurs | Run/Edit/Smoke/cache/faux chemin validés, détails section 5 |
| Captures | 30 PNG, 3 metadata, 3 planches, détails section 11 |
| Suite globale | code 1 ; 106 scripts, 1 174 tests, 1 150 réussis, 24 échecs, 56 877/57 061 assertions, 666,414 s GUT, 678,273 s murales |
| Diff | propre, aucune suppression inattendue, statut propre avant rapport |

Deux tentatives globales finales sans résumé se sont arrêtées à des endroits différents pendant des exécutions Godot parallèles. Elles sont conservées comme diagnostics, jamais utilisées comme résultats. La passe complète retenue a été lancée dans une fenêtre sans runner headless concurrent. Elle contient un `Run Summary`, aucun crash et exactement les mêmes 24 identités d'échec que la baseline : `ADDED=0`, `MISSING=0`.

Fingerprints finaux : identiques bit à bit à la section 6.

## 10. Comparaison baseline/final

| Mesure | Baseline main | Intégré | Delta |
|---|---:|---:|---:|
| Scripts globaux | 105 | 106 | +1 |
| Tests globaux | 1 156 | 1 174 | +18 |
| Tests globaux réussis | 1 132 | 1 150 | +18 |
| Échecs globaux | 24 | 24 | 0 |
| Assertions globales réussies | 56 415 | 56 877 | +462 |
| Assertions globales totales | 56 599 | 57 061 | +462 |
| Identités d'échec globales | 24 | 24 | 0, ensemble exact |
| VFX historique | 11/11, 638 | 11/11, 638 | 0 |
| Studio | 13/14, 215/216 | 13/14, 215/216 | 0 |
| Flipbook dédié | absent | 18/18, 462 | +18 tests verts |
| Parse errors scan stable | 0 | 0 | 0 |
| `RunEconomyProfile` scan stable | 11 | 0 | -11 |
| UID invalides uniques | 3 | 3 | 0 |
| Fingerprints historiques | 3 valeurs | mêmes 3 valeurs | 0 |

L'allowlist historique reste à 13 entrées alors que la baseline et le final en observent 24. Le vérificateur sort donc code 1 des deux côtés ; ce décalage préexistant est documenté, pas masqué. La gate d'intégration compare les identités réelles et n'en ajoute aucune.

## 11. Validation visuelle

Artefact final : `C:\Users\paolo\AppData\Local\Temp\codex_vfx_flipbook_main_integration_captures_rendered_20260814`.

- `1200x896` : 10 captures, metadata, planche ; code 0, `CAPTURE_SUITE_PASS`, 0 ligne `ERROR` ;
- `1280x720` : 10 captures, metadata, planche ; code 0, `CAPTURE_SUITE_PASS`, 0 ligne `ERROR` ;
- `1920x1080` : 10 captures, metadata, planche ; code 0, `CAPTURE_SUITE_PASS`, 0 ligne `ERROR` ;
- dimensions réelles vérifiées sur les 30 PNG ;
- 10/10 entrées metadata `ok` à chaque résolution.

Les trois planches ont été ouvertes en résolution originale, ainsi que les captures individuelles ADD, PREMULTIPLIED, dix instances, variantes A/B et annulation. Inspection technique : frames 2, 8, 16 et 23 cohérentes avec le scrub ; pivot et échelle lisibles ; absence de rectangle alpha parasite ; halos visibles sur fonds clair et sombre ; MIX, ADD et PREMULTIPLIED distincts ; LOW, MEDIUM et HIGH présents ; variantes A/B distinctes ; dix instances et dix visuels observés ; capture annulée en état `CANCELLED` avec zéro visuel.

La metadata annulée conserve un nœud runtime jusqu'au `clear()` final du runner (`runtime_nodes=1`, `visuals=0`). Le runner appelle ensuite `clear()` et les Smokes indépendants prouvent `residual=0`.

Une première tentative avec `--headless` a correctement révélé que le renderer dummy n'expose pas de texture viewport. Le runner, sans watchdog sur cette erreur inattendue, est resté actif ; seuls les deux processus lancés par cette mission ont été arrêtés, tandis que le Godot de la tâche parallèle a été préservé. Le dossier diagnostique incomplet `%TEMP%\codex_vfx_flipbook_main_integration_captures_20260814` et son log sont conservés. Les captures finales utilisent le renderer OpenGL réel.

Verdict visuel : preuves techniques conformes, aucune approbation artistique.

## 12. Avertissement RunEconomyProfile

Texte exact :

```text
Invalid call function 'validation_errors' in base 'Resource (RunEconomyProfile)': Attempt to call a method on a placeholder instance. Check if the script is in tool mode.
```

- baseline stable : 11 occurrences ;
- final stable : 0 occurrence ;
- classification : `PREEXISTING_OUT_OF_SCOPE_WARNING`, absent du final observé ;
- point d'émission baseline : `data/runs/run_data.gd:53`, appelé depuis les services/UI Arena Studio ;
- aucun fichier de cette mission ne contient ni ne produit directement cet appel ;
- aucune correction gameplay ou Run Economy n'a été introduite.

Les trois UID invalides uniques Studio sont également inchangés : `uid://ogq7y82pxxba`, `uid://d35rgj8t43fd`, `uid://bwxps4efrv2uk`.

## 13. Documentation

`DOCS_AI_UPDATE_DEFERRED_DUE_TO_CONCURRENT_WORK`

Les worktrees Run Flow modifient simultanément `docs/ai/CURRENT_STATE.md`, `docs/ai/DECISIONS.md`, `docs/ai/KNOWN_ISSUES.md` et `docs/ai/BALANCE_BASELINE.md`. Cette mission n'a modifié aucun de ces fichiers, n'a déclaré aucun document partagé `CURRENT` et n'a jamais touché `BALANCE_BASELINE.md`.

La vérité de la mission est consignée dans :

- `docs/tools/vfx/vfx_flipbook_foundation_v1_report.md` ;
- `docs/tools/vfx/vfx_flipbook_foundation_user_guide.md` ;
- le présent rapport dédié.

## 14. Commits finaux

- candidat : `b00b040572a15b4fa0d5e064455fa9a06a353a7c` — `feat(vfx): add flipbook foundation and standalone lab launcher` ;
- technique intégré : `72a0ed9d1b4e38897620c8e634bca9e77c50f88f` — même message ;
- documentaire initial : `70c19afe70b94fea126ba37ad4f9df1c3ef00d91` — `docs(vfx): record flipbook foundation integration` ;
- confirmation du push : commit qui porte cette mise à jour — `docs(vfx): confirm flipbook foundation main push` ;
- HEAD final : le commit de confirmation, descendant direct de `70c19af`, `72a0ed9` et `afc458d`.

Un fichier ne peut pas embarquer le SHA de son propre commit sans changer ce SHA. La valeur exacte du commit de confirmation est donc fournie par la preuve Git de l'handoff.

## 15. Push

- remote observé avant la gate finale : `afc458ddec20f1753926405f229389214ded6059` ;
- commande autorisée : `git push origin HEAD:main` ;
- force : jamais ;
- gate pré-push : `origin/main` encore égal à `afc458d`, worktree propre, diff propre, `maps` et `72a0ed9` ancêtres, validations post-commit vertes ;
- premier push : code 0, fast-forward `afc458d..70c19af`, aucune force ;
- première preuve distante : `HEAD == origin/main == git ls-remote origin refs/heads/main == 70c19afe70b94fea126ba37ad4f9df1c3ef00d91` ;
- contenu prouvé : `afc458d`, `72a0ed9` et `70c19af` tous présents/ancêtres ;
- mise à jour de confirmation : second fast-forward documentaire requis, puis nouvelle égalité des trois références ;
- SHA distant final : fourni par la preuve Git de l'handoff, car il est le SHA du commit qui contient cette ligne.

Si la politique distante refuse `HEAD:main`, aucun contournement n'est autorisé : seule la branche d'intégration peut alors être poussée et le verdict devient `MAIN_PUSH_BLOCKED_BY_REMOTE_POLICY`.

## 16. Éléments non vérifiés

- aucune approbation artistique, direction artistique finale ou qualité de production ;
- aucun asset EmberGen réel, import DCC réel ou licence commerciale externe ;
- aucune publication/release ; `COMMERCIAL_CLEARED` reste une déclaration, jamais une autorisation automatique ;
- aucune preuve absolue d'absence de toute référence Resource/RID : la suite Flipbook signale à la fermeture 6 RID texture dummy, 47 ObjectDB et 18 Resources, incluant fixtures et harness ; la preuve forte porte sur les nœuds et visuels runtime observables ;
- le confinement de chemins et les bornes de taille des manifestes restent du hardening pour des manifestes non fiables ; les fixtures versionnées sont le périmètre validé ;
- la disparition finale du warning `RunEconomyProfile` n'est pas revendiquée comme correction de sa cause racine ;
- l'allowlist globale historique est en retard de 11 identités déjà présentes sur `main` ; elle n'a pas été mise à jour hors périmètre ;
- le runner de capture n'a pas de watchdog pour une exception GDScript inattendue avant `quit()` ; le Smoke, lui, en possède un ;
- la capture annulée garde son instance runtime jusqu'au clear final, tout en ayant zéro visuel ;
- les documents partagés `docs/ai/**` sont différés ;
- les tests ont utilisé Godot 4.7.1 stable, GUT 9.7.1 et Python 3.13.9 fourni par Blender pour le vérificateur ; aucun runtime Python Codex groupé n'était configuré.

## 17. État final des worktrees

- principal préservé sur `main`/`afc458d` pendant le travail ; ses deux nouveaux fichiers Achilles non suivis appartiennent à la tâche parallèle et restent intacts ;
- candidat final conservé, propre, sur `b00b040` ;
- ancien candidat `8bd9d455bced` conservé sans nettoyage ;
- worktree d'intégration conservé sur sa branche dédiée ;
- worktrees Achilles, Run Flow, HUD, Observatory, Studio, Tactical Impact et Validation Feedback préservés ;
- aucun worktree supprimé, aucune branche supprimée, aucun reset destructif, aucun stash, aucun force push ;
- logs baseline/final, logs de lanceurs, captures candidates, captures intégrées, jonction au chemin avec espaces et diagnostics incomplets conservés pour audit ;
- après commit de confirmation et second push, le worktree d'intégration doit être propre ; le principal n'est pas nettoyé par cette mission.
