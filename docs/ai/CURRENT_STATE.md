# État candidat vérifié du projet

## Arena authoring, décor, timing et réseaux (WORKTREE_CANDIDATE, 2026-08-12)

- Baseline poussée : `main` à `8bd9d455bced1c68acf98843e6f6d4844d4174e8`.
- Statut : **WORKTREE_CANDIDATE**, jamais CURRENT avant commit et revalidation
  au même SHA.
- Batching des traits, palette rapide, transaction de décor, timing des statuts
  de terrain et réseaux de vortex sont implémentés dans le patch local.
- Nouvelles suites : 69/69, 216 assertions ; seuils de performance passés ;
  matrice visuelle 88/88 aux quatre résolutions.
- `produced/room_01_forest` reste gelé et n'est chargé ni par Tester ni par le
  catalogue de décors.

## Catalogue complet des terrains (WORKTREE_CANDIDATE, 2026-08-12)

- Baseline locale : `main` à `8bd9d455bced1c68acf98843e6f6d4844d4174e8`.
- Arena Studio expose Pierre, Neutre, Eau, Glace, Lave, Poison, Vapeur, Eau
  électrifiée et Vortex apparié ; `VOID` reste topologique.
- Les effets sont data-driven et communs à Studio, preview, Tester et runtime.
- Suite dédiée : 64/64 tests, 317 assertions.
- Statut : **WORKTREE_CANDIDATE** ; aucun commit, stage ou push.

## L’Odyssée — Achille solo (WORKTREE_CANDIDATE, 2026-08-11)

- Dépôt : `C:\Users\paolo\Documents\dungeon-draft-v-2`.
- Branche observée : `main` ; HEAD de base :
  `29bf19719be6988898bdbef4c16f5d5b44d7b2d6`.
- Une troisième run officielle, **L’Odyssée**, est disponible après la
  principale et la run de test. Elle contient Achille seul et exactement trois
  salles `SINGLE_ENCOUNTER`, sans vague.
- Le contenu suit la chaîne `RunData -> RunContentProfile -> RunHeroProfile ->
  CharacterProgressionProfile`. Les profils existants principal/test conservent
  leurs empreintes et leur trio historique.
- Validation ciblée finale : 19/19 tests, 277 assertions. Suite globale : 935/949
  tests, 55 117/55 175 assertions. Les 13 échecs historiques restent présents ;
  le quatorzième concerne la signature structurelle Studio v12 modifiée par le
  travail Arena/VFX concurrent, hors périmètre Odyssey.
- Runner graphique réel : PASS à 1920×1080 et 1280×720 ; hub, trois combats,
  déploiement, HUD Achille, ancres, post-combat et résultat vérifiés. Quatorze
  captures ont été inspectées.
- Une partie humaine non forcée de la première salle reste requise. Ce candidat
  ne promeut pas le worktree en `CURRENT`.

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
# Candidat local Arena Studio 2.0 — 2026-08-10

Statut : **WORKTREE_CANDIDATE**, pas CURRENT. Base : `main` à `5b7458becbaae6d16c2989f84fb12b60f3b4eb9c`. Le patch local Arena Studio 2.0.0 est en validation finale ; il n’est ni committé ni poussé. La version poussée et la candidate locale doivent rester distinguées.

Le dossier `res://data/arenas/produced/room_01_forest/` est gelé comme `UNREFERENCED_INCOMPLETE_PRODUCTION_BUNDLE` tant qu’aucune référence n’est démontrée. L’audit gameplay v2.1 est **HISTORIQUE** ; aucune règle de gameplay ne change dans ce patch.

Preuves Arena Studio 2.0 : dernier global complet 889/902 et 54 432/54 489 assertions avec exactement les 13 échecs historiques ; après la correction responsive finale, UX 10/10 (87), pipeline visuel 12/12 (130), responsive 18/18 (980), Studio 2.0 12/12 (423) et captures réelles multi-résolution PASS. Les deux répétitions globales Windows post-correction ont été interrompues au niveau processus sans nouvel échec d’assertion ; voir `docs/tools/dungeon_draft_studio/arena_production_hardening_regression_report.md`.

## Achille 3D character-only et theorycraft — checkpoint salle II (2026-08-20)

- Statut : **WORKTREE_CANDIDATE — NOT_CURRENT — NOT_PRODUCTION**.
- Dépôt : `Essy7126/dungeon-draft-v-2` ; branche :
  `integration/achilles-3d-character-theorycraft-v1` ; base :
  `2d99ea4137ba1893e486b3ff1e39a73e66d0a469` ; commit d’implémentation :
  `98834c07a630ec2ae0dfd8f105f3b3a07d11f856`.
- Validation ciblée Godot 4.7.1 : personnage 74 tests mécaniques,
  63 PASS / 11 PENDING derrière la gate, 1 804 assertions ; theorycraft
  55/55, 1 197 assertions. La suite globale observée reste à 1 275/1 307
  avec 32 échecs historiques ou hors périmètre ; faute de baseline globale
  strictement comparable au même périmètre, « zéro nouvel échec » reste
  `BLOCKED`. L’import termine mais n’est pas qualifié de propre.
- Le backend canonique 3D est intégré comme présentation `SubViewport`
  `character-only`, sans instance d’équipement séparée. Le profil vérifié porte
  `equipment_enabled = false` et `weapon_profile = null`.
- L’intégration runtime d’armes est différée au laboratoire dédié. Les concepts
  épée-bouclier et arc du laboratoire de theorycraft restent conceptuels, non
  chargeables par le runtime et non activés. Aucun build de laboratoire n’est
  actif.
- La preuve runtime est volontairement bornée à la salle II de L’Odyssée. Les
  salles I et III, les transitions normales et l’écran de résultat restent en
  pause derrière la gate humaine ; le smoke trois salles n’a pas été exécuté.
- Le propriétaire doit répondre A (256), B (384), C (512), ou D (rejeter le
  `SubViewport` et utiliser des sprites prérendus). 384 est seulement la
  recommandation technique non décisionnelle issue du benchmark.
- Le root motion reste `ROOT_MOTION_UNCLASSIFIED`. Les translations X/Z sont
  neutralisées localement dans la présentation sans réécrire les actions ni la
  hiérarchie source.
- Les temps GPU sont `NOT_MEASURED`. Le second cycle 512 ne montre pas de hausse
  supplémentaire, mais la rétention/plateau du cache de rendu n’est pas
  attribuée causalement au seul `SubViewport`. Des warnings de teardown
  renderer/RID/ObjectDB subsistent à la fermeture.
- La source 3D canonique et le backend 3D n’exposent aucune arme. En revanche,
  le fallback 2D hérité contient visiblement des pixels d’épée et de bouclier :
  `LEGACY_2D_BAKED_WEAPON_PIXELS_OBSERVED`. La conformité globale sans arme est
  donc `BLOCKED_LEGACY_2D_FALLBACK_WEAPON_VISUAL_DIVERGENCE`.

## Achille 3D — promotion runtime Odyssée B/384 (2026-08-20)

Cette section remplace l’état opérationnel du checkpoint salle II ci-dessus.

- Statut : **CURRENT_ON_LOCAL_INTEGRATION_BRANCH — NOT_MERGED_TO_MAIN**.
- Décision propriétaire : **B, SubViewport 384 × 384**.
- Commit d’implémentation :
  `0d0eeaf96acc35b9cc40fe5c2c1ba52cedd0c852` sur
  `integration/achilles-3d-character-theorycraft-v1`.
- Le corps de combat 2D armé n’est plus référencé par l’adaptateur ni par son
  profil. Le warm-up et les erreurs utilisent un secours invisible garantissant
  uniquement le contrat d’action.
- Le runner graphique dédié passe dans les trois salles réelles avec le backend
  3D actif en 384, sans ancien visuel 2D mis en cache, sans arme ni équipement,
  avec ombre, portrait d’initiative, déplacement, Garde et nettoyage validés.
- Le portrait 2D raffiné reste volontairement une icône du HUD/timeline ; il ne
  remplace jamais le modèle 3D sur la grille.
- Preuve durable :
  `C:\Dungeon_Draft_Production\Achilles\Integration\ACHILLES_3D_ODYSSEY_RUNTIME_PROMOTION_V1_20260820`.
- Bornes : actions déclenchées programmatiquement, transitions de victoire
  synthétiques, root motion non classifié, GPU non mesuré, diagnostics teardown
  OpenGL persistants et warning UID Guerrier historique.
