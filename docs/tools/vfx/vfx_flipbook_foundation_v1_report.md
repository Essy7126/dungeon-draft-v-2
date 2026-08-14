# VFX_FLIPBOOK_FOUNDATION_V1_REPORT

Statut : `WORKTREE_CANDIDATE`

Date de revalidation : 2026-08-14

Worktree : `C:\Users\paolo\Documents\dungeon-draft-v-2-worktrees\vfx-flipbook-foundation-v1-a45a62be9a0e`

Branche : `codex/vfx-flipbook-foundation-v1-a45a62be9a0e`

Base candidate : `a45a62be9a0e3423029dd33d344b3b69fca3b55d`

`origin/main` audité : `afc458ddec20f1753926405f229389214ded6059`

Godot : `4.7.1.stable.official.a13da4feb`

GUT : `9.7.1`

## 1. Verdict

`TECHNICAL_CANDIDATE_WITH_PREEXISTING_WARNING`

La fondation flipbook V1, son laboratoire autonome et ses lanceurs Windows sont techniquement validés dans le worktree candidat. La suite dédiée passe 18/18 tests et 462 assertions. La suite VFX historique reste à 11/11 et 638 assertions. Le slice Studio reproduit exactement sa baseline exploitable : 13/14, 215/216, même test unique en échec et mêmes trois UID invalides hors VFX.

Le candidat n'est pas `CURRENT`, n'est pas une approbation artistique et ne contient aucun asset EmberGen de production. Il ne modifie ni gameplay, ni sort, ni Arena, ni carte, ni personnage, ni terrain, ni `project.godot`.

## 2. Vérité Git et concurrence

- Le worktree principal est resté en lecture seule et propre ; seul `git fetch` y a été exécuté.
- `origin/main` descend de la base candidate. Le seul commit entre les deux est `afc458d maps`, qui ajoute deux fichiers sous `asset/map/painted/greece/` et ne chevauche pas le candidat.
- 26 worktrees ont été inventoriés avant modification. Aucun worktree actif hors des deux candidats flipbook ne touche `vfx/**`, le plugin VFX partagé, `core/vfx_manager.gd`, `project.godot`, ce laboratoire ou les tests VFX.
- Le candidat antérieur basé sur `8bd9d455bced` a été conservé intact. Le candidat `a45a62be9a0e` a été retenu car sa base est l'ancêtre immédiat du dernier `main`.
- Cinq worktrees Run Flow modifient `docs/ai/CURRENT_STATE.md`, `DECISIONS.md`, `KNOWN_ISSUES.md` et/ou `BALANCE_BASELINE.md`. La future intégration ne doit donc pas écrire ces fichiers et doit utiliser `DOCS_AI_UPDATE_DEFERRED_DUE_TO_CONCURRENT_WORK`.
- État candidat stabilisé avant stage : 7 fichiers suivis modifiés, 42 fichiers non suivis autorisés, 0 suppression et 0 fichier staged.
- `test/unit/test_vfx_flipbook_foundation.gd.uid`, généré par un scan éditeur, a été explicitement retiré. Le UID du nouveau smoke sous `tools/labs/**` est conservé avec son script.

## 3. Audit indépendant et corrections

L'audit n'a pas repris le rapport précédent comme preuve. Il a relu le diff, les ressources, le runtime, le validateur, les services, les tests, les logs et les captures. Les écarts suivants ont été corrigés avant validation :

- Play lançait auparavant une instance figée à 48 % ; il démarre maintenant une vraie animation traitée par le runtime.
- Le scrub additionnait 48 % et la valeur demandée ; il recrée maintenant une instance propre et applique un temps absolu.
- Le validateur appliquait le contexte de la séquence jouée à toutes les séquences ; les contraintes contextuelles ne concernent plus que les modules activés de la séquence sélectionnée.
- Un `VFXFlipbookModuleData` dont le `module_type` était falsifié pouvait suivre le chemin procédural ; l'invariant typé est désormais rejeté.
- Un manifeste sans variante pouvait être déclaré éligible et une variante non-Dictionary pouvait provoquer une erreur non contrôlée ; les deux cas sont couverts.
- Le manifeste refusait les fallbacks MEDIUM/HIGH pourtant contractuels ; LOW reste obligatoire et les deux qualités supérieures sont optionnelles avec comparaison sûre à la Resource.
- Le manifeste contrôle maintenant structure et schema de la Resource, types imbriqués, champs non vides, hashes hexadécimaux, path du manifeste et divergences Resource/JSON.
- La copie et l'historique perdaient un asset transitoire sans path ; les snapshots mémoire peuvent maintenant partager sa référence immuable, tandis qu'un snapshot durable exige toujours un path existant et rechargeable comme `VFXFlipbookAsset`.
- Les scénarios du lab pouvaient passer avec `ok` implicite ; ils vérifient maintenant créations, états et résidus réels.
- Le runner de captures échoue si un scénario n'est pas `ok` et convertit les PNG en RGBA8 avant la planche de contact.
- Les noms de fixtures mojibake ont été remplacés par une chaîne ASCII correcte.
- Le launcher Smoke est strictement non interactif, possède un watchdog de 15 secondes et valide `--version` dans un job temporisé.
- Le launcher est ASCII pour Windows PowerShell 5.1, protège l'initialisation et les logs, transmet les arguments sans parseur maison et produit une commande manuelle PowerShell littérale sûre.

## 4. Architecture livrée

- `VFXFlipbookVariant` : variantes typées et fallback LOW/MEDIUM/HIGH descendant uniquement.
- `VFXFlipbookAsset` : contrat atlas, sampling, blending, pivot, taille, statuts art/licence et manifeste.
- `VFXFlipbookModuleData` : module concret `FlipbookModule` avec ancre et paramètres visuels.
- `VFXFlipbookVisual` : `Sprite2D`, frame, qualité effective, variante, blend MIX/ADD/PREMULTIPLIED et introspection.
- Registre/runtime : ajout strictement additif du module flipbook, sans refactor général.
- Snapshot/copie/draft : type concret, champs spécifiques, partage immuable mémoire, reload durable par path et refus avant écriture si non persistant.
- Manifeste V1 : validation JSON, schema, types, layout, textures, dimensions, checksums, licence, divergence Resource et indicateur `is_release_eligible()`.
- Fixtures : six atlas synthétiques A/B en LOW/MEDIUM/HIGH, Resource, profil et manifeste sous chemins `test`.
- Lab : scène autonome, vraie `VFXLayer`, vrai runner/runtime/context, contrôles et 14 scénarios contractuels.

## 5. Fichiers et périmètre

Fichiers suivis modifiés :

- `vfx/runtime/vfx_execution_context.gd`
- `vfx/runtime/vfx_module_registry.gd`
- `vfx/runtime/vfx_profile_validator.gd`
- `vfx/services/vfx_draft_service.gd`
- `vfx/services/vfx_profile_copy_service.gd`
- `vfx/services/vfx_profile_snapshot_service.gd`
- `vfx/services/vfx_studio_document.gd`

Nouveaux groupes versionnés :

- `vfx/data/vfx_flipbook_*.gd` et UID ;
- `vfx/modules/vfx_flipbook_visual.gd` et UID ;
- `vfx/services/vfx_flipbook_manifest_service.gd` et UID ;
- `vfx/assets/flipbooks/test/**` ;
- `vfx/profiles/test/synthetic_flipbook_*.tres` ;
- `vfx/manifests/test/synthetic_flipbook_foundation.json` ;
- `tools/labs/vfx_flipbook_foundation/**` ;
- `test/unit/test_vfx_flipbook_foundation.gd` ;
- les deux `.cmd`, `tools/launchers/launch_vfx_flipbook_lab.ps1`, le guide et ce rapport.

Aucun fichier n'est supprimé. `git diff --check` est propre. Aucun chemin gameplay/Arena/carte/personnage/terrain n'entre dans le diff.

## 6. Lanceur utilisateur

Fichiers :

- `LANCER_LAB_VFX_FLIPBOOK.cmd` lance le lab ;
- `OUVRIR_LAB_VFX_FLIPBOOK_DANS_GODOT.cmd` ouvre l'éditeur sur le lab ;
- `tools/launchers/launch_vfx_flipbook_lab.ps1` expose `Run`, `Edit` et `Smoke` ;
- `docs/tools/vfx/vfx_flipbook_foundation_user_guide.md` décrit le parcours utilisateur en français.

Ordre de détection vérifié : `-GodotPath`, `GODOT4_BIN`, `GODOT_BIN`, cache utilisateur, `Get-Command godot`, `Get-Command godot4`, répertoires usuels puis boîte de dialogue hors Smoke. Seule une version `4.7` est acceptée. Cache et logs restent sous `%LOCALAPPDATA%\DungeonDraft`.

Matrice Windows exécutée :

- Smoke par `-GodotPath` : code 0, frame 8, résidu 0 ;
- Smoke par `GODOT4_BIN` : code 0 ;
- Smoke par détection automatique/cache : code 0 ;
- chemin projet contenant des espaces : code 0 ;
- appel depuis `C:\Windows\Temp` : code 0 ;
- arguments Godot supplémentaires : transmis et visibles dans la commande manuelle ;
- Run graphique réel via `.cmd` : code 0 ;
- Edit graphique réel ciblé via `.cmd` : code 0 ;
- faux exécutable : code 1, message clair, log et commande de secours ;
- parser Windows PowerShell 5.1 et contrôle ASCII : code 0.

Logs finaux représentatifs :

- `%LOCALAPPDATA%\DungeonDraft\logs\vfx_flipbook_lab_smoke_20260814_110003_746.log`
- `%LOCALAPPDATA%\DungeonDraft\logs\vfx_flipbook_lab_run_20260814_110045_989.log`
- `%LOCALAPPDATA%\DungeonDraft\logs\vfx_flipbook_lab_edit_20260814_110056_890.log`
- `%LOCALAPPDATA%\DungeonDraft\logs\vfx_flipbook_lab_smoke_20260814_110136_402.log` pour l'échec contrôlé.

## 7. Scans Godot et warning Studio

Commande normale : `Godot --headless --editor --path . --quit-after 2`.

- pré-scan indépendant : code 0, 11 `SCRIPT ERROR`, 6 occurrences `invalid UID`, 3 UID uniques, 0 erreur de parse ;
- scan final : code 0, exactement les mêmes 11 messages, les mêmes 6 occurrences et les mêmes 3 UID ;
- texte exact des 11 erreurs : `Invalid call function 'validation_errors' in base 'Resource (RunEconomyProfile)': Attempt to call a method on a placeholder instance. Check if the script is in tool mode.` ;
- traces limitées à `data/runs/run_data.gd` et au plugin Studio hors diff ;
- classification : `PREEXISTING_OUT_OF_SCOPE_WARNING`.

Commande recovery : `Godot --headless --editor --recovery-mode --path . --quit-after 2`.

- code 0 ;
- 0 `SCRIPT ERROR` ;
- 0 erreur de parse ;
- scan interrompu proprement par la sortie demandée.

## 8. Tests

Fondation flipbook :

```text
Godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gconfig= -gtest=res://test/unit/test_vfx_flipbook_foundation.gd -gexit
```

- code 0 ;
- 18/18 tests ;
- 462 assertions ;
- 3,991 s GUT sur la passe finale après synchronisation du checksum générateur ;
- 0 échec.

VFX historique :

- code 0 ;
- 11/11 tests ;
- 638 assertions ;
- 0,518 s GUT ;
- 0 échec.

Studio :

- une première tentative a subi un crash natif Godot `0xC0000005` avant le banner GUT alors qu'un autre processus Godot appartenant à une tâche parallèle était déjà actif ; cette tentative ne constitue pas une mesure ;
- relance exploitable : code GUT 1, 13/14, 215/216, 14,69 s ;
- même échec `test_dungeon_draft_studio_registers_vfx_as_fourth_shared_domain` ;
- mêmes trois UID préexistants, aucun diagnostic flipbook.

Fingerprints historiques inchangés :

```text
shield_lifecycle.tres       d66985d018270d021dda39bc79e09e409e21a9eea3de5e09d4bd42c306501b31
lightning_multi_target.tres 81c44745be2bab9d6523c592b327a48937a34906226a886f176237464e17a02c
player_path_preview.tres    4bdb23b9160dd3c9c5a13d3de252c95ab22dc84fde67e075bbb4734553c153d2
```

## 9. Générateur et manifeste

Après synchronisation du checksum avec le script générateur final, le générateur a été exécuté deux fois : codes 0/0, 7 artefacts contrôlés, seul le manifeste a été ajusté par la première passe et aucune différence n'existe entre les deux passes.

Hashes finaux :

```text
variant_a_low.png     2c00cc2cad52e1eba3e4547f9516b37481081adea1630a905d92642433ed5546
variant_a_medium.png  09fc1f968c6bc4627cfec118ffda13517730673f4187c2751c9bad49f598918c
variant_a_high.png    c67a091b10545a9e77b3a21fb02c529f691ef688abc893e68a085d85f219befd
variant_b_low.png     2b586b48f21b3e039e092c27a4d1c12d60360d95472151200afd8ddbb6583ba9
variant_b_medium.png  1cd9b507c9b0463a6728a6c0710b11ddff4a4024c6da9624171988543ea61c99
variant_b_high.png    190cfbd9b034e01964322262f0eecaed964643ac21fc01ab21ecf77652b3ae9b
manifest JSON         58efefb7bba8b3759edae8968977d66d291206d9d2861e4e6efd93c3c7c0c34d
```

`is_release_eligible()` reste un indicateur déclaratif : `INTERNAL_TEST` et `EVALUATION_ONLY` sont refusés ; `COMMERCIAL_CLEARED` n'est que potentiellement éligible et ne publie rien.

## 10. Captures et inspection visuelle

Artefacts : `C:\Users\paolo\AppData\Local\Temp\codex_vfx_flipbook_candidate_integration_captures_20260814`.

- 1200×896 : 10 captures, 1 metadata JSON, 1 planche de contact ;
- 1280×720 : 10 captures, 1 metadata JSON, 1 planche de contact ;
- 1920×1080 : 10 captures, 1 metadata JSON, 1 planche de contact ;
- total : 30 captures et 3 planches ;
- trois runners commit-gate : code 0, `CAPTURE_SUITE_PASS`, aucune ligne `ERROR`.

Les trois planches et les images individuelles ADD, PREMULTIPLIED, 10 instances, variantes A/B et annulation ont été ouvertes et inspectées. Sont confirmés : ordre de sampling cohérent avec les progressions (frames 2, 8, 16, 23…), pivot et échelle lisibles, alpha sans rectangle parasite, halo clair et sombre, MIX/ADD/PREMULTIPLIED, LOW/MEDIUM/HIGH, variantes distinctes, dix instances visibles et capture annulée sans visuel.

La capture annulée conserve temporairement un nœud runtime en état `CANCELLED` afin de rendre l'état inspectable, mais contient 0 visuel. Le smoke `Clear` confirme séparément 0 instance et 0 enfant après nettoyage.

Verdict visuel : `TECHNICALLY_VALIDATED_SYNTHETIC_FIXTURES`, sans approbation artistique.

## 11. Cycle de vie et diagnostics de fin de processus

Les assertions couvrent complete, cancel, clear, timeout, parent freed, 100 cycles play/clear, 20 complétions et 10 instances simultanées. Elles observent 0 enfant/visuel après nettoyage.

La passe GUT finale signale néanmoins à la fermeture du processus dummy : 6 RID texture, 47 ObjectDB et 18 Resources encore référencées. Ce diagnostic inclut les fixtures chargées et le harness GUT ; il n'est pas présenté comme une preuve d'absence totale de référence ou matériau. La preuve contractuelle est limitée aux nœuds et visuels runtime observables, et le rapport d'intégration devra comparer le même diagnostic sur l'état intégré.

## 12. Performance et poids

- Layout : 8×4, 32 frames.
- LOW : cellules 16×16, atlas 128×64.
- MEDIUM : cellules 32×32, atlas 256×128.
- HIGH : cellules 64×64, atlas 512×256.
- Charge fonctionnelle : 10 instances simultanées et 100 cycles sans résidu de nœud.
- Non mesuré : FPS GPU soutenu, VRAM cible, vrais atlas EmberGen et charge supérieure à 10 instances.

## 13. Travail concurrent préservé

- Le principal n'a reçu aucune écriture de projet.
- Les deux assets `maps` restent hors candidat.
- Aucun fichier Arena, carte, personnage, terrain, sort, gameplay ou `project.godot` n'est modifié.
- Aucun fichier `docs/ai/**` n'est modifié.
- Aucun worktree ni branche concurrente n'a été déplacé, nettoyé, stashé ou supprimé.
- Les artefacts, logs, branches et worktrees restent disponibles pour audit.

## 14. Éléments non vérifiés ou non-objectifs

- Approbation artistique humaine.
- Asset EmberGen réel, trial, export ou pipeline de production.
- Profilage GPU/VRAM et autres OS/renderers.
- Publication de catalogue ou raccordement à un sort de production.
- Confinement sandbox de chemins issus d'un manifeste hostile ; le manifeste V1 actuel est un fichier versionné de confiance.
- Suite globale complète sur ce candidat ; elle est une gate obligatoire de la phase d'intégration sur `origin/main` avant/après cherry-pick.

## 15. Git candidat

- Branche : `codex/vfx-flipbook-foundation-v1-a45a62be9a0e`.
- Base : `a45a62be9a0e3423029dd33d344b3b69fca3b55d`.
- Message prévu : `feat(vfx): add flipbook foundation and standalone lab launcher`.
- Un seul commit candidat doit contenir la fondation, fixtures, tests, lab, runner, launchers, guide et présent rapport.
- Le SHA du commit ne peut pas être auto-référencé dans son propre contenu ; il sera consigné dans le rapport d'intégration.
- Aucun push de la branche candidate n'est prévu.
