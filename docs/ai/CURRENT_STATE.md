# État candidat vérifié du projet

> Statut : **WORKTREE_CANDIDATE — DUNGEON DRAFT STUDIO 2.0 WITH WARNINGS**

- Date de vérification : 2026-08-06
- Branche : `main`
- HEAD : `bf2d6f7a8b6dabf2c8b74c5743852475f7c84e0a`
- Godot : `4.7.stable.official.5b4e0cb0f`
- GUT : `9.7.1`
- Dépôt : `C:\Users\paolo\Documents\dungeon-draft-v-2`

## Contrats actifs

- `first_run.tres` reste `SINGLE_ENCOUNTER`, six salles, et référence
  `main_content_profile.tres`.
- `fixed_trio_prototype_run.tres` reste `WAVE_CHAIN`, quatre salles, et référence
  `test_content_profile.tres`.
- Chaque `RunData` officielle choisit trois `RunHeroProfile` dans l’ordre Elfe,
  Mage, Guerrier.
- Les bases `UnitData` sont partagées intentionnellement ; les graphes de
  progression modifiables sont propres à la run.
- `GameManager.start_run()` résout le contenu depuis la `RunData` ; les APIs
  d’injection explicite restent disponibles.
- Le hub transmet la `RunData` ; la liste globale historique n’est plus
  l’autorité des runs officielles.
- Audit officiel : `progression_shared_count = 0`, verdict `VALID`.

## Validation courante

- scan Godot : code 0 avec diagnostics historiques ;
- isolation réciproque : 14/14, 1 493 assertions ;
- run/trio/GameManager/hub : 117/117, 4 908 assertions ;
- Arena/Encounter/Studio : 76/76, 3 941 assertions ;
- suite globale finale : 787/800, 52 044/52 101 assertions ;
- 13 échecs baseline qualifiés dans
  `docs/ai/RUN_CONTENT_ISOLATION_VALIDATION.md` ;
- aucun échec nouveau dans le périmètre de la mission.

Le projet n’est pas globalement vert à cause d’assets/captures absents, de
contrats Elfe historiques, de textures de pause nulles et d’une comparaison
flottante. Le worktree ne doit pas être présenté comme `CURRENT` avant
intégration explicite par l’utilisateur.

## Studio 2.0 candidat

- une instance `StudioProjectContext` est partagée entre Arena, Encounter et
  Skill Tree ;
- la barre expose run, salle, héros, portée, état, chemins, usages et génération ;
- Arena édite la séquence réelle de `RunData.rooms`, sans suppression physique ;
- production et rattachement demandent run, action et index, puis rechargent et
  vérifient la référence exacte ;
- le pipeline grid-first exporte un manifeste art v2 et réimporte un décor
  conforme sans recalibrer ;
- la projection runtime et les surfaces temporaires ne mutent pas
  `ArenaDefinition` ;
- Skill Tree édite le `CharacterProgressionProfile` canonique et conserve le
  `UnitData` comme adaptateur non sauvegardable ;
- les 33 types d’effets et 13 classes concrètes cataloguées possèdent un
  descripteur métier ; aucun fallback « effet spécialisé » n’est affiché.

Preuves 2.0 courantes : 12/12 tests, 423 assertions et six captures inspectées
en 1280×720 / 1920×1080. Le détail reste candidat dans
`docs/tools/dungeon_draft_studio/studio_2_0_regression_report.md`.

## Item Studio V1 — WORKTREE_CANDIDATE séparé

- Date : 2026-08-07
- Branche : `main`
- HEAD de base : `29f307b5ff61822f266bbd2d14636ca8dcea2d95`
- Statut : **WORKTREE_CANDIDATE — ne modifie pas le statut CURRENT**
- Tests : Item Studio 30/30, 190 assertions ; smoke PASS ; captures inspectées ;
  suite globale 836/849, avec les mêmes 13 échecs que la baseline.
- Non vérifié : revue humaine interactive et activation à un commit intégré.

Le Dungeon Draft Studio possède localement un troisième domaine **OBJETS** relié
au `StudioProjectContext`, au dirty state, aux générations et à l’historique. Il
édite le catalogue runtime actuel sur working copy, sauvegarde les brouillons
hors production, publie par transaction vérifiée et projette les effets via les
services runtime isolés. RUN_SPECIFIC et les reliques restent explicitement
différés. Cette section candidate ne promeut pas le worktree en CURRENT.
