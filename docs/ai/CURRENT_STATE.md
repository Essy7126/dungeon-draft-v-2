# État courant vérifié du projet

## Achille — intégration Meshy directe dans L’Odyssée (CURRENT, 2026-08-23)

- Le candidat V3 remplace le corps canonique animé par retarget par le modèle
  Meshy direct : un mesh skinné, son rig Meshy de 24 os et ses 20 animations
  natives sont chargés ensemble dans les trois salles de L’Odyssée.
- Le routage `RunData -> RunContentProfile -> RunHeroProfile ->
  CharacterProgressionProfile` reste inchangé, comme les statistiques et les
  quatre capacités d’Achille : Frappe de lance, Percée, Balayage et Garde
  d’airain.
- Le repos utilise `Idle_11`, les déplacements de 1 à 5 cases utilisent
  `Walking`, et les chemins de 6 cases ou plus utilisent
  `run_fast_3_inplace`. La marche joue à 75 % et traverse une case en 0,40 s ;
  la course conserve une traversée vive de 0,20 s. La grille reste l’autorité
  du déplacement.
- Le billboard V3 utilise une taille d'affichage de 96 avec une caméra
	orthographique 2,6. Le profil peint emploie une base de 1,72, bornée entre
	1,50 et 1,90. Les échelles finales sont 1,806 / 1,8576 / 1,892 pour la forêt,
	le volcan et l’espace : Achille est ainsi calibré dans l'enveloppe réelle de
	l'Elfe, du Mage et du Guerrier. Les identifiants réels des ennemis Odyssée
	sont désormais reliés à leurs profils peints et leurs billboards compensent
	le cadrage natif plus petit afin de partager la même hauteur rendue.
- Le modèle Meshy ne contient aucun équipement. Le corps de grille et l’aperçu
  3D utilisent la V3 ; le portrait du HUD reste l’illustration 2D historique.
- Validation actuelle : tests ciblés proportions/V3/locomotion/Odyssée et
  squelettes 61/61 (1 102 assertions),
  Studio 19/19 (208 assertions) et binding SHA-exact 34/34 (643 assertions).
  La comparaison graphique instancie réellement les trois héros et les trois
  familles ennemies de production : Achille reste dans la bande du trio et les
  ennemis restent à ±5 % de sa hauteur rendue. Le full-flow trois salles passe
  sur `d387e4a87d95` avec 13 captures ; Achille mesure
  111,97 / 111,92 / 117,30 px dans les salles I / II / III.

## Achille — pool d’animations Meshy V3 (WORKTREE_CANDIDATE, 2026-08-23)

- L’asset `achilles_meshy_animation_pool_v3.glb` contient exactement 20 clips
  Meshy natifs sur le même rig de 24 os. Aucun retarget n’est utilisé.
- Son SHA-256 est
  `95F634EF49B04F8A01FC4B13D223F75DC3B2C7AA01CB2319194D078BF1D02FEE`.
- `CharacterAnimationSetData` porte le repos, la marche, la course, l’impact,
  le lancement générique et une clé `cast:<spell_id>` distincte pour chacune
  des quatre capacités.
- La source ne contient aucune animation de mort : le fondu de l’adaptateur
  reste le rendu prévu. Les clips impliquant une arme restent disponibles dans
  le pool, mais le modèle n’embarque ni arme, ni bouclier, ni arc.
- Les assets V1 et V2 sont conservés sans modification comme historiques ; la
  V3 est le seul candidat courant.
- Contrat, hash, inventaire et limites :
  `docs/design/achilles/achilles_meshy_animation_pool_v3.md`.

## Cohérence architecture Studio, animations et objets (WORKTREE_CANDIDATE, 2026-08-23)

- Base locale : `main` à `77799ec945071bf91b1bc4996da2b3bd7b6a81e1`.
- `CharacterAnimationSetData` est l’unique table événement → clip ; les visuels
  de production référencent la même Resource au lieu de recopier ses valeurs.
- Une session Skills ouverte depuis un run sauvegarde le profil de progression
  et, si nécessaire, le `UnitData` canonique qui rattache une nouvelle fiche
  d’animations. L’adaptateur temporaire reste non sauvegardable.
- `StudioProjectContext.active_character` représente aussi les personnages hors
  partie ; `active_hero` vaut alors `null`, sans sélection implicite divergente.
- Les runners Arena/Encounter Studio épinglent leurs seeds et les copies de
  `RunData` conservent le réglage de randomisation ainsi que les profils hors domaine.
- Les 27 objets de production, dont les 8 reliques, sont caractérisés par un
  artefact versionné. `RelicEffectRegistry` décrit les effets et
  `RelicRuntimeService` reste l’unique exécuteur.
- Statut : **WORKTREE_CANDIDATE** jusqu’au commit et à la validation interactive.

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

## Historique — création initiale de L’Odyssée (checkpoint du 2026-08-11)

> Cette section conserve la provenance du premier candidat. Son statut et ses
> chiffres ont été remplacés par l’état `PRODUCTION_RUNTIME` du 2026-08-23 en
> tête de document.

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

## Achille 3D character-only et theorycraft — checkpoint historique salle II (2026-08-20)

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
- À ce checkpoint, le choix A/B/C/D était encore en attente. Le propriétaire a
  ensuite retenu B (384) ; l’état opérationnel corrigé est documenté ci-dessous.
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

## Achille 3D — correction du binding runtime, gate salle II (2026-08-20)

```text
previous_report_claimed_3d_runtime = true
owner_observed_legacy_2d_runtime = true
claim_was_contradicted = true
binding_reverified_after_fix = true
```

- Cause vérifiée : `WRONG_WORKTREE_OR_PROJECT_LAUNCHED`. L’éditeur du
  propriétaire ouvrait `main` au HEAD `a54bc6d4c53741bc487807ff79ef292fe0b3c5ec`,
  où la façade liait encore directement le corps 2D historique.
- Statut post-publication : **PUBLISHED_ON_ORIGIN_MAIN — OWNER_REVIEW_PENDING — NOT_PRODUCTION**.
- Commit d’intégration publié : `e0b42eb75f2de46d3daa08b8ac30ae1cc354d3da`.
- Branche : `fix/achilles-odyssey-runtime-3d-binding-v1` ; base :
  `7bc3d69c0f434e8038bbb199300a96baae8443a4` ; correctif runtime :
  `59464dbc200c2168e2757c76c414b6149abebee4` ; tests :
  `d632004f28a060dccec613fd58247564fea84423`.
- La vraie salle II affiche le GLB canonique via `VIEWPORT_3D` en 384 : un
  SubViewport, une caméra, un squelette de 52 os et un mesh visible.
- Le corps 2D n’est ni instancié, ni visible, ni en traitement pendant le
  nominal ; aucun fallback n’est déclenché.
- Le fallback 2D armé reste un mode dégradé paresseux, réservé à une erreur 3D
  vérifiée et journalisée. Le portrait 2D reste autorisé uniquement dans l’UI.
- Les 34 tests obligatoires et 35 non-régressions adaptées passent. Aucun
  gameplay, sort, statistique, arme ou theorycraft n’est modifié.
- Salles I/III, transitions et résultat : non exécutés, en pause derrière la
  confirmation propriétaire.

Verdicts : `ACHILLES_3D_ROOM_II_RUNTIME_READY_FOR_OWNER_REVIEW`,
`LEGACY_2D_BODY_NOT_VISIBLE`, `FALLBACK_NOT_ACTIVE`.
