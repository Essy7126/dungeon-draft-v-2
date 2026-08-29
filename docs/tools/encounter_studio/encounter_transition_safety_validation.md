# S0 — Sécurisation des brouillons et transitions du Studio de rencontres

**Statut : PROUVÉ (16/16 puis 20/20, vérifié directement par exécution GUT le 29/08/2026).**
**WORKTREE_CANDIDATE — NOT_CURRENT — NOT_PRODUCTION.**

Ce rapport documente exclusivement le lot S0 (« terminer la sécurisation des
brouillons et transitions »). Il ne couvre ni G5 (diagnostics compréhensibles)
ni G6 (finition visuelle/accessibilité), traités dans des rapports séparés
une fois S0 entièrement validé.

## 1. Correction de la contradiction du rapport G3/G4

`docs/tools/encounter_studio/encounter_g3_g4_validation.md` affirmait à un
endroit une exécution à **13/15 passants** sur
`test/unit/test_room_draft_encounters.gd`, avec deux échecs non
investigués plus avant (RAPPORTÉ, à confirmer). Cette affirmation est
remplacée par le résultat réellement démontré ici : **16/16 passants**
(15 tests d'origine + 1 nouveau test ajouté par ce lot, voir §4). Le rapport
G3/G4 lui-même n'a pas été réécrit — le triptyque de preuve interdit toute
correction silencieuse — mais son affirmation de 13/15 doit désormais être
lue comme obsolète, remplacée par ce document.

## 2. Deux causes racines identifiées et corrigées

### 2.1 `draft_content_mismatch` — classification de champs incohérente au rechargement

**PROUVÉ.** `ArenaDefinition.authoring_document` (`addons/dungeon_draft_arena_studio/domain/arena_definition.gd:74`)
est un marqueur d'édition **volontairement non sérialisé**
(`docs/ai/DECISIONS.md:266-278` : « Le document d'auteur est marqué par
`ArenaDefinition.authoring_document`, non sérialisé »). `RoomIntegrationFieldPolicy.classification_for()`
(`addons/dungeon_draft_arena_studio/services/room_integration_field_policy.gd:99-123`)
l'utilise pour décider si `enemies`, `background_image`,
`arena_visual_profile` et `battle_scene` sont `GAMEPLAY_OWNED` (inclus dans
l'empreinte de contenu) ou `DERIVED_RUNTIME` (exclus).

`EncounterStudioMain.save_room_draft()`
(`addons/dungeon_draft_arena_studio/encounter/ui/encounter_studio_main.gd:1319-1349`)
vérifie l'enregistrement en rechargeant le brouillon
(`RoomDraftSaveService.load_draft()`) puis en comparant son empreinte à
celle du brouillon vivant. `RoomDraftSaveService.load_draft()`
(`addons/dungeon_draft_arena_studio/services/room_draft_save_service.gd:95-113`)
reconstruit systématiquement un `ArenaDefinition.new()` frais via
`restore_snapshot()`, qui ne touche jamais `authoring_document` — celui-ci
reste donc à sa valeur par défaut (`false`) sur la copie relue, quelle que
soit la valeur réelle du brouillon vivant (`true` pour un brouillon ouvert
depuis Terrain via `ArenaEditSession.open()`, `false` pour un `ArenaDefinition`
construit directement, comme dans les fixtures de test). Les deux dictionnaires
comparés (`gameplay_state()`) n'ont alors pas le même jeu de clés, et la
comparaison SHA-256 échoue même quand le contenu réel (roster, vagues,
`living_enemy_cap`, etc.) est strictement identique.

**Correction retenue (root cause, pas un contournement d'assertion) :**
dans `save_room_draft()`, aligner explicitement `authoring_document` de la
copie rechargée sur celle du brouillon vivant *avant* de comparer les
empreintes — puisque ce marqueur représente un mode d'édition transitoire,
non un contenu, il ne doit jamais faire partie de ce qui est comparé comme
« contenu potentiellement différent ». Fichier modifié :
`addons/dungeon_draft_arena_studio/encounter/ui/encounter_studio_main.gd`
(bloc de vérification de `save_room_draft()`, ~15 lignes ajoutées).

Une première tentative avait consisté à forcer `authoring_document = true`
directement dans `RoomDraftSaveService.load_draft()` (en écho à
`ArenaEditSession.open()`). Cette approche faisait passer les deux tests
initialement visés, mais cassait un troisième test
(`test_room_draft_success_failure_sharing_and_context_exclusion` dans
`test/unit/test_encounter_document_safety.gd`, qui construit son
`ArenaDefinition` de brouillon directement, sans passer par
`ArenaEditSession`, donc avec `authoring_document = false` sur le brouillon
vivant lui-même) — la correction a donc été déplacée du point de rechargement
générique vers le point de comparaison spécifique, seul endroit qui connaît
la valeur réellement attendue. Ce changement de direction est signalé ici
explicitement (pas de correction silencieuse) : la version initiale a été
entièrement retirée avant la version finale.

### 2.2 `test_dirty_draft_uses_the_four_explicit_decisions`, cas `DRAFT`

**PROUVÉ.** Cause unique avec 2.1 : `resolve_pending_transition(ACTION_DRAFT)`
route, pour le domaine `encounter`, vers `_context_draft()` →
`save_room_draft()` (`encounter_studio_main.gd:1385-1390`). L'échec de
`save_room_draft()` (même cause que 2.1) se propageait tel quel comme échec
de toute la transaction (`StudioContextTransitionTransactionService.execute()`
retournant `ok:false`), ce qui explique pourquoi seul le cas `DRAFT` échouait
parmi les trois décisions testées (`CANCEL` et `DISCARD` n'appellent jamais
`save_room_draft()`). La correction de 2.1 résout ce cas sans modification
supplémentaire.

## 3. Vérifications complémentaires demandées par S0

### 3.1 Passage direct vers le brouillon (Rencontres propre, Terrain modifié)

**PROUVÉ**, déjà correct avant ce lot (fixé lors du travail G3/G4 précédent) :
`EncounterStudioMain.open_room_draft()` (lignes 604-627) ouvre directement le
brouillon quand `session.is_dirty()` est faux, sans jamais déclencher de
décision sur Terrain. Vérifié par les tests existants
(`test_creating_encounters_opens_the_terrain_draft_directly_when_encounters_is_clean`
et les tests de round-trip dans `test_room_draft_encounters.gd`).

### 3.2 Transition déjà en attente au moment d'`open_room_draft()`

**Défaut réel trouvé et corrigé.** `open_room_draft()` ne vérifiait jamais
`project_context.has_pending_transition()` avant d'emprunter la branche
d'ouverture directe (§3.1). Si une décision SAVE/DRAFT/DISCARD/CANCEL était
déjà ouverte ailleurs dans le Studio (ex. un autre domaine modifié, une
navigation en attente) au moment où `open_room_draft()` était appelé avec
Rencontres propre, le code changeait silencieusement l'autorité du document
de Rencontres sans jamais toucher à la transition en attente — exactement le
risque décrit dans la consigne (écraser/résoudre implicitement une décision
ouverte, changer l'autorité pendant qu'une décision reste ouverte).

**Correction :** garde explicite ajoutée en tête d'`open_room_draft()`
(`encounter_studio_main.gd`) : si `project_context.has_pending_transition()`
est vrai, l'ouverture est refusée (retour `false`), un message clair est
affiché (`_set_status`), et rien n'est modifié — ni la transition en attente,
ni l'état de Rencontres.

**Nouveau test** (§4) :
`test_opening_a_room_draft_never_overrides_a_pending_transition` — dirtie le
domaine `arena` (sans toucher Rencontres), déclenche une décision en attente
via `context.request_room()`, puis appelle `open_room_draft()` : vérifie que
l'ouverture est refusée, que la transition en attente est préservée
**à l'identique** (`assert_eq` sur le dictionnaire complet), que Rencontres
ne bascule pas en mode brouillon, et que le domaine `arena` reste marqué
modifié.

### 3.3 Examen du verrou global (`request_dirty_transition`)

**PROUVÉ.** Trois sites d'appel recensés par grep exhaustif sur `addons/` :
`arena_studio_main.gd:1576` (intent `terrain_home`, requester `arena`),
`encounter_studio_main.gd:1516` (divers intents, requester `encounter`, via
`_request_navigation`), et la définition elle-même dans
`studio_project_context.gd:236`. Aucun autre domaine (items, skills) ne
l'utilise actuellement.

Le mécanisme est **déjà scopé par domaine**, pas globalement verrouillé :
`resolve_pending_transition()` (`studio_project_context.gd:268-303`)
n'invoque `StudioContextTransitionTransactionService.execute()` que sur
`_pending_transition.dirty_domains` — c'est-à-dire uniquement les domaines
réellement marqués modifiés au moment de la demande, pas tous les domaines
enregistrés. Une transition où seul `encounter` est modifié n'appelle donc
jamais les handlers `save/draft/discard` de `arena` — confirmé
empiriquement par `test_dirty_draft_uses_the_four_explicit_decisions` (seul
`encounter` est dirtié, et le brouillon Terrain reste non publié après les
trois décisions) et par le nouveau test 3.2 (le domaine `arena` reste
inchangé pendant qu'une transition portant sur lui seul est en attente).
**Conclusion : aucun nouveau contrat n'était nécessaire ici** — le risque
décrit dans la consigne (« une transition locale à Rencontres ne doit jamais
sauvegarder/abandonner Terrain ») était déjà couvert par la conception
existante ; seul le défaut du §3.2 (contournement du verrou par la branche
d'ouverture directe) constituait un trou réel.

### 3.4 Sauvegarde et restauration du brouillon

**PROUVÉ**, vérifié par `test_saving_a_room_draft_only_writes_under_user_and_restores_everything` :
écriture exclusivement sous `user://` (chemin vérifié par assertion), sous-
ressources de gameplay copiées en profondeur
(`RoomDraftAuthority.isolate_gameplay_into`), contenu restauré identique
(fingerprint, sélection de salle/affrontement, `living_enemy_cap`, roster),
aucune Resource canonique modifiée (hashes SHA-256 de `data/` inchangés
avant/après, voir §5).

## 4. Fichiers modifiés

| Fichier | Changement |
|---|---|
| `addons/dungeon_draft_arena_studio/encounter/ui/encounter_studio_main.gd` | (a) `save_room_draft()` : alignement de `authoring_document` sur la copie rechargée avant comparaison d'empreinte (§2.1). (b) `open_room_draft()` : garde contre une transition déjà en attente (§3.2). |
| `test/unit/test_room_draft_encounters.gd` | Nouveau test `test_opening_a_room_draft_never_overrides_a_pending_transition` (§3.2). |

`addons/dungeon_draft_arena_studio/services/room_draft_save_service.gd` a
été temporairement modifié puis **restauré à l'identique de la baseline**
(tentative de correction abandonnée, voir §2.1) — `git diff` sur ce fichier
est vide à la fin de ce lot.

Aucun autre fichier de production n'a été touché par S0.

## 5. Résultats exacts et empreintes

Exécutions GUT réelles (`Godot_v4.7-stable_win64_console.exe --headless
--script addons/gut/gut_cmdln.gd -gconfig= -gtest=... -gexit`), le
29/08/2026 :

| Suite | Résultat |
|---|---|
| `test_room_draft_encounters.gd` | **16/16** (15 tests d'origine + le nouveau test §3.2) |
| `test_encounter_document_safety.gd` | **20/20** (3 échecs avant correction, tous dus à la même cause racine §2.1) |
| `test_encounter_shared_reference_graph.gd` | **8/8** |
| `test_room_draft_publication.gd` | **8/8** |
| `test_room_transition_async_lifecycle.gd` | **10/10** |

`git diff --check` : aucune sortie (propre). `git status --short data/` :
aucune sortie (aucun fichier de production modifié, ajouté ou supprimé).

**Empreintes `data/`** (SHA-256, 383 fichiers, calculées avant le premier
test à risque et re-calculées après l'intégralité des exécutions ci-dessus) :
**0 différence** — aucun fichier ajouté, modifié ou supprimé sous `data/`
pendant toute la durée de S0. Manifestes conservés dans le répertoire de
travail temporaire de session (hors dépôt) :
`dd_data_protect/manifest_before.json` et `manifest_after.json`.

## 6. Risques résiduels

- La suite GUT du projet présente des ralentissements I/O intermittents et
  imprévisibles sur cet environnement (probablement liés à la synchronisation
  OneDrive du répertoire de travail) : certaines exécutions de
  `test_encounter_document_safety.gd` ont pris entre 47 secondes et plus de
  10 minutes pour un contenu de test identique, sans lien avec les
  changements de ce lot. Ce n'est pas un défaut du code testé, mais un point
  de vigilance pour toute automatisation future (CI) sur ce projet.
- Les fuites RID/ObjectDB/orphelins signalées en fin d'exécution GUT
  (des centaines d'objets, plusieurs dizaines de RID) sont **RAPPORTÉES**
  comme dette technique préexistante (déjà notées dans les rapports G1-G4) —
  aucune preuve n'a été établie ici qu'elles sont corrigées, et aucune
  affirmation en ce sens n'est faite.
- §3.3 conclut qu'aucun nouveau contrat de transition scopée n'était
  nécessaire ; si un futur domaine (items, skills) devait un jour combiner
  transitions locales et globales de façon plus complexe, ce point mériterait
  d'être réexaminé — à ce jour, aucun signe d'un tel besoin.

## 7. Critères S0 — statut final

- [x] `test_room_draft_encounters.gd` passe à 16/15+1 (16/16, dépassant le critère 15/15 grâce au nouveau test de régression).
- [x] Cas de corruption ciblé (`draft_content_mismatch`) : corrigé et testé.
- [x] Quatre décisions (`SAVE`, `DRAFT`, `DISCARD`, `CANCEL`) : toutes passantes.
- [x] Transition déjà en attente : défaut trouvé, corrigé, testé.
- [x] Sauvegarde/restauration exacte : passante.
- [x] Empreintes des ressources protégées identiques avant/après : confirmé (0 diff / 383 fichiers).
- [x] Aucun nouveau fichier dans un catalogue de production.
- [x] Suites directement affectées (sécurité documentaire, contexte partagé, transitions, sauvegarde, brouillons, intégration Terrain→Rencontres) : toutes passantes.
- [x] `git diff --check` propre.

**S0 est validé. G5 peut commencer.**

`WORKTREE_CANDIDATE — NOT_CURRENT — NOT_PRODUCTION`
