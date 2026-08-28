# Brouillon de salle : Terrain → Créer les combats → Tester → Intégrer

Date : 2026-08-28. Statut réel : **`WORKTREE_CANDIDATE`**. Aucun commit, aucune
promotion `CURRENT`, aucune publication sur une partie officielle.

Ce chantier **remplace** le parcours candidat précédent
(`Terrain → Intégrer dans une run → Continuer vers Rencontres`) et son rapport
`terrain_encounters_continuation_report.md`, supprimé.

---

## 1. Autorité de brouillon retenue

**PROUVÉ** — L'autorité unique du brouillon de salle est la **working copy
`ArenaDefinition` de Terrain** (`ArenaEditSession.working_arena`).

```
ArenaDefinition (working copy Terrain)  ← autorité unique
├── données Terrain    : ses propres @export (grille, cases, décor, calibration)
└── données Rencontres : les champs hérités de RoomData classés GAMEPLAY_OWNED
                         par RoomIntegrationFieldPolicy
                         (encounter_definition, waves, plage de vagues,
                          récompense ultime)
```

**Pourquoi celle-ci** :

- `ArenaDefinition extends RoomData` — **PROUVÉ**
  (`addons/dungeon_draft_arena_studio/domain/arena_definition.gd:3`). Elle porte
  déjà les deux moitiés : aucun second format persistant n'est nécessaire.
- La liste des champs « moitié Rencontres » n'est pas recopiée : elle est
  **demandée à `RoomIntegrationFieldPolicy`** à l'exécution
  (`RoomDraftAuthority.gameplay_property_names`). Un futur champ de gameplay
  ajouté à `RoomData` est donc couvert sans nouvelle édition.
- Rencontres n'édite **pas une copie** : `EncounterEditSession.draft_room` est
  *l'instance même* de `working_arena`. Il n'y a donc aucune synchronisation à
  faire au changement d'onglet, implicite ou non.
- La `RunData` vue par Rencontres en mode brouillon est un **porteur en
  mémoire** (`RoomDraftAuthority.build_context_run`) : `resource_path` vide,
  jamais sauvegardé, `rooms[0]` = le brouillon lui-même. Il n'est jamais
  l'autorité ; il ne sert qu'à présenter le brouillon aux services Rencontres,
  qui raisonnent en « partie → salle ».
- La partie active n'est lue que pour ses règles (`room_flow_mode`,
  `maximum_waves_per_room`, `content_profile`, `economy_profile`, seed).

**PROUVÉ** — Séparation des historiques : `ArenaEditSession.apply_snapshot()`
capture la moitié Rencontres avant `restore_snapshot()` et la replace après.
Annuler/Rétablir dans Terrain ne touche donc jamais aux rencontres, et
réciproquement — `ArenaDefinition.to_snapshot()` (l'instantané du domaine
Terrain) ne contient pas le gameplay.

**PROUVÉ** — Isolation canonique : `ArenaEditSession.open()` appelle
`RoomDraftAuthority.isolate_gameplay_into()`, qui recopie profondément les
`EncounterDefinition` et `RoomWaveData` de la source et conserve les tables
`source ↔ copie`. La working copy ne partage jamais une instance canonique.

**PROUVÉ** — Projection runtime : un document d'auteur ne porte pas ses
projections (`grid_layout`, `painted_map_visual_data`, `battle_scene`).
`EncounterEditSession.runtime_room()` les reconstruit à la lecture, en cache par
empreinte, sans jamais muter l'autorité.

---

## 2. Parcours utilisateur final

1. **Terrain** — l'utilisateur construit sa salle.
2. **Créer les combats de la salle** — action principale unique de la barre du
   Studio, entre « Tester » et « Intégrer à la partie ».
   Aide affichée : *« Choisissez les ennemis, organisez les vagues et vérifiez
   leur placement sur ce terrain. »*
3. **Rencontres** s'ouvre sur le brouillon, avec la bannière
   *« Brouillon de salle — pas encore intégré à une partie »* suivie du rappel
   de la partie de contexte en lecture seule.
4. Ennemis, vagues, formations, quantités, placements sont définis sur le
   brouillon.
5. **Tester** construit un contexte temporaire sous `user://` depuis le
   brouillon actif et la run de contexte.
6. Retour dans **Terrain** : terrain, rencontres et les deux historiques sont
   conservés.
7. **Intégrer à la partie** reste la dernière étape et la seule qui écrit sous
   `res://`.

### Ce que fait — et ne fait pas — « Créer les combats de la salle »

**PROUVÉ** (`test/unit/test_room_draft_encounters.gd`) :

| Exigence | Vérification |
|---|---|
| reste dans la working copy | `encounter.session.draft_room` est `terrain.arena` (identité) |
| n'ouvre pas l'assistant Intégrer | `production_dialog.visible == false` |
| ne modifie aucun fichier canonique | SHA-256 avant/après de la run, de ses salles et de leurs rencontres |
| ne change pas `RunData.rooms` | comparaison du tableau et de `stable_value(run)` |
| ne crée rien sous `res://data/encounters/` | listage du dossier avant/après |
| ouvre le bon brouillon et la bonne run | `draft_room`, `context_run`, porteur sans chemin |
| retour sans perte | aller-retour complet avec Annuler/Rétablir des deux côtés |

---

## 3. Fichiers modifiés

**PROUVÉ** — Implémentation :

| Fichier | Rôle |
|---|---|
| `addons/dungeon_draft_arena_studio/domain/room_draft_authority.gd` | **nouveau** — l'autorité, le porteur, les projections, les libellés |
| `addons/dungeon_draft_arena_studio/services/room_draft_save_service.gd` | **nouveau** — brouillon complet sous `user://` |
| `addons/dungeon_draft_arena_studio/domain/arena_edit_session.gd` | isolation profonde du gameplay, historique Terrain non destructeur |
| `addons/dungeon_draft_arena_studio/encounter/domain/encounter_edit_session.gd` | mode brouillon, `runtime_room()`, DISCARD sans fichier |
| `addons/dungeon_draft_arena_studio/encounter/ui/encounter_studio_main.gd` | bannière, ouverture du brouillon, sauvegarde locale, contexte lecture seule |
| `addons/dungeon_draft_arena_studio/encounter/services/encounter_save_service.gd` | refus explicite de la sauvegarde canonique en mode brouillon |
| `addons/dungeon_draft_arena_studio/encounter/services/encounter_validation_service.gd` | validation sur la projection runtime du brouillon |
| `addons/dungeon_draft_arena_studio/encounter/services/encounter_test_launcher.gd` | terrain courant + héros et règles de la run de contexte |
| `addons/dungeon_draft_arena_studio/services/room_integration_field_policy.gd` | `merge_draft_into_room()`, `publication_summary()` |
| `addons/dungeon_draft_arena_studio/services/arena_production_attachment_service.gd` | intention explicite `publish_draft_gameplay` |
| `addons/dungeon_draft_arena_studio/services/arena_integration_service.gd` | plan : décision gameplay, rencontres du brouillon |
| `addons/dungeon_draft_arena_studio/services/arena_runtime_bridge.gd` | la projection runtime transporte la moitié Rencontres (correction de régression) |
| `addons/dungeon_draft_arena_studio/ui/arena_studio_main.gd` | action `open_room_encounters()`, case d'intention, plan enrichi ; **suppression** du parcours candidat |
| `addons/dungeon_draft_arena_studio/ui/dungeon_draft_studio_main.gd` | action principale dans la barre du Studio, ouverture du brouillon |
| `addons/dungeon_draft_arena_studio/ui/terrain/terrain_header_bar.gd` | action et aide dans l'en-tête de domaine |

**PROUVÉ** — Validation :

| Fichier | Rôle |
|---|---|
| `test/unit/test_room_draft_encounters.gd` | **nouveau** — parcours, isolation, aller-retour, contextes, brouillon, test runtime |
| `test/unit/test_room_draft_publication.gd` | **nouveau** — frontière `RoomIntegrationFieldPolicy`, deux intentions |
| `test/unit/test_terrain_test_integration_path.gd` | suppression des 5 tests du parcours candidat |
| `test/unit/test_room_integration_guided_pipeline.gd` | suppression du test et de la fixture du parcours candidat (retour à l'état HEAD) |
| `addons/dungeon_draft_arena_studio/test/terrain_studio_capture_runner.gd` | vues de capture du nouveau parcours |
| Le présent rapport | remplace `terrain_encounters_continuation_report.md` |

---

## 4. Données écrites à chaque action

**PROUVÉ** :

| Action | Écriture |
|---|---|
| Créer les combats de la salle | **aucune** |
| Éditer ennemis / vagues / placements | **aucune** (mémoire seule, dans l'autorité) |
| Changement d'onglet | **aucune** |
| Enregistrer le brouillon (Rencontres) | `user://dungeon_draft_studio/room_draft/<id>.json` |
| Décision `DRAFT` du contexte, en mode brouillon | même fichier `user://` |
| Décision `SAVE` du contexte, en mode brouillon | même fichier `user://` — la sauvegarde canonique est refusée (`room_draft_not_publishable`) |
| Tester | `user://dungeon_draft_studio/encounter_studio/tests/<contexte>/` uniquement |
| Intégrer à la partie | transaction existante, `res://` |

---

## 5. Intégration finale : la frontière traitée explicitement

**PROUVÉ** — Deux intentions coexistent au niveau de `RoomIntegrationFieldPolicy` :

| Intention | Fonction | Gameplay publié |
|---|---|---|
| Mettre à jour le terrain (historique, **inchangé**) | `merge_arena_into_room()` | celui du disque, vérifié inchangé à chaque phase |
| Publier la salle complète (**nouveau, explicite**) | `merge_draft_into_room()` | celui du brouillon |

- **PROUVÉ** — L'intention n'est **jamais déduite** : elle vient d'une case à
  cocher décochée par défaut (`PublishDraftGameplayCheck`), visible uniquement
  pour l'action « Mettre à jour », et transportée sous la clé
  `publish_draft_gameplay`. Sans elle,
  `ArenaProductionAttachmentService.plan()` renvoie `preserves_gameplay = true`
  et toutes les vérifications de préservation du disque restent actives.
- **PROUVÉ** — Les actions APPEND / INSERT / REPLACE publient déjà le document
  complet : l'option y est ignorée.
- **PROUVÉ** — L'identité de la salle cible (`room_name`) est conservée dans les
  deux cas. Publier des affrontements ne renomme jamais une salle.
- **PROUVÉ** — Le plan de confirmation affiche désormais, en plus de la
  destination, des fichiers et des avertissements existants : la décision
  gameplay en clair (conservé / remplacé), le détail de ce qui est conservé,
  remplacé ou publié, le nombre de nouvelles rencontres à créer et la liste des
  rencontres déjà partagées.

---

## 6. Tests exécutés et comparaison avec la baseline

**PROUVÉ** — Godot 4.7 stable, GUT 9.7.1, `APPDATA` isolé.
Commande : `--headless --path . --script addons/gut/gut_cmdln.gd -gconfig= -gtest=<suites> -gexit`.

- Baseline (worktree **avant** modification, HEAD `0bdc254` + candidat) :
  `artifacts/room_draft_v1/baseline_worktree.log`
- Après modification : `artifacts/room_draft_v1/after_worktree.log`

| Suite | Baseline | Après |
|---|---:|---:|
| test_terrain_studio_refonte | 45 / 45 | 45 / 45 |
| test_terrain_studio_novice_scenario | 1 / 1 | 1 / 1 |
| test_arena_studio_history_transform_v11 | 16 / 16 | 16 / 16 |
| test_encounter_studio_v1 | 14 / 17 | 14 / 17 |
| test_dungeon_draft_studio_2_0 | 16 / 16 | 16 / 16 |
| test_dungeon_draft_studio_v12 | 6 / 8 | 6 / 8 |
| test_dungeon_draft_studio_v121 | 10 / 10 | 10 / 10 |
| test_arena_atomic_production_v2 | 8 / 8 | 8 / 8 |
| test_arena_integration_gate_policy | 10 / 10 | 10 / 10 |
| test_room_integration_guided_pipeline | 15 / 15 | 14 / 14 |
| test_terrain_test_integration_path | 12 / 12 | 7 / 7 |
| test_arena_runtime_preview_and_direct_test_v2 | 4 / 4 | 4 / 4 |
| test_arena_direct_test_runtime_parity | 6 / 6 | 6 / 6 |
| **test_room_draft_encounters** (nouveau) | — | **12 / 12** |
| **test_room_draft_publication** (nouveau) | — | **6 / 6** |
| **TOTAL** | **163 / 168** | **175 / 180** |

Les écarts d'effectif sont expliqués : −6 tests du parcours candidat supprimés
(5 dans `test_terrain_test_integration_path`, 1 dans
`test_room_integration_guided_pipeline`), +18 tests nouveaux.

**PROUVÉ** — Les **5 échecs après modification sont exactement les 5 échecs de
la baseline**, nom pour nom :

1. `test_encounter_studio_v1 :: test_external_room_and_encounter_changes_survive_final_reopen`
2. `test_encounter_studio_v1 :: test_pont_test_direct_prepare_copie_temporaire_sans_muter_canonique`
3. `test_encounter_studio_v1 :: test_sauvegarde_enfants_parents_rechargement_recuperation_et_chemins_surs`
4. `test_dungeon_draft_studio_v12 :: test_painted_and_hybrid_rooms_use_the_expected_runtime_scene`
5. `test_dungeon_draft_studio_v12 :: test_production_is_complete_reloadable_idempotent_and_portable`

Aucun échec nouveau. Ce sont donc des échecs **historiques au périmètre
comparé**, et non des régressions — la comparaison a bien été exécutée avant
modification, sur le même périmètre et la même commande.

### Une régression a été trouvée et corrigée en cours de route

**PROUVÉ** — Une première exécution après modification donnait 6 échecs :
`test_arena_runtime_preview_and_direct_test_v2 :: test_game_preview_is_run_aware_when_exact_context_is_available`
tombait. Cause : l'isolation profonde du gameplay rend
`working_arena.encounter_definition` sans chemin de fichier, or
`ArenaDefinition.to_snapshot()` ne transporte que ce chemin — la projection
runtime perdait donc la rencontre. Correction dans
`ArenaRuntimeBridge._runtime_projection_copy()`, qui reprend désormais la moitié
Rencontres. La suite est repassée à 4 / 4.

## 7. Captures inspectées

**PROUVÉ** — Vrai `StudioWorkspace`, rendu OpenGL, runners terminés avec
`failures=0` aux deux résolutions, `hors_ecran=0` rapporté à chaque vue.
Fichiers : `artifacts/terrain_studio/screenshots/terrain_studio_<vue>_<W>x<H>.png`.

| Vue | 1280 × 720 | 1920 × 1080 | Inspection |
|---|:--:|:--:|---|
| `terrain_encounters_action` | ✔ | ✔ | Barre du Studio : « Terrain valide · Brouillon · Tester · **Créer les combats** · Intégrer à la partie ». Aucun bouton concurrent. |
| `room_draft_encounters` | ✔ | ✔ | Bannière « Brouillon de salle — pas encore intégré à une partie » + contexte lecture seule. Aperçu de la carte, chronologie, composition, validation remplis. Rencontre marquée **PARTAGÉE** (« Ressource externe • 12 affrontement(s), 3 salle(s) ») : la détection du partage fonctionne sur le brouillon. |
| `back_to_terrain` | ✔ | ✔ | Terrain intact au retour, mêmes actions. |
| `room_draft_integration_plan` | ✔ | ✔ | Assistant, onglet « 4 — Production » : la case **« Publier aussi les affrontements du brouillon » est visible et décochée**, suivie du plan (destination, fichiers, conflits, partie, action, index exact, salle cible). |

**PROUVÉ** — Test automatisé complémentaire
(`test_no_primary_action_is_offscreen_at_both_resolutions`) : aucune action
principale de la barre du Studio ne sort de l'écran en 1280 × 720 ni en
1920 × 1080.

**À CONFIRMER** — Deux vues demandées ne sont **pas** capturées : « test du
brouillon » (elle exige de lancer une vraie partie depuis le runner) et
« résultat après intégration vérifiée » (elle exigerait une écriture réelle sous
`res://` pendant la capture).

**PROUVÉ** — Limite visuelle connue et non traitée : à 1280 px, la colonne
Composition de Rencontres reste tronquée. C'est la limite de largeur
préexistante de cet inspecteur ; il n'a pas été refondu.

## 8. Limites restantes

**PROUVÉ** — Non fait, et non revendiqué :

1. **Phase d'écriture dédiée des nouvelles `EncounterDefinition`.** La
   transaction de salle complète n'a pas été étendue avec les phases
   « écrire les nouvelles rencontres » puis « relire leurs références ». Les
   rencontres créées dans le brouillon sont publiées comme **sous-ressources de
   la salle**, pas comme fichiers séparés sous `res://data/encounters/`. Le plan
   les annonce comme telles. L'invariant demandé — rien sous
   `res://data/encounters/` avant l'intégration — est respecté ; la création de
   fichiers dédiés à la publication reste à faire.
2. **Échecs injectés après chaque phase d'écriture** de la publication de salle
   complète : non couverts par un test dédié. Les points d'injection existants
   (`before_attachment`, `after_attachment`) et leur rollback restent en place
   et testés par la suite historique, mais pas avec l'intention brouillon.
3. **Collision de chemin et conflit externe** au moment de la publication d'un
   brouillon : couverts par les mécanismes existants, pas par un test dédié à ce
   parcours.
4. **Rencontres partagées** : la **détection** est **PROUVÉE** en mode brouillon
   par la capture `room_draft_encounters` — la rencontre reprise de la salle
   canonique est annoncée « Ressource externe • 12 affrontement(s), 3 salle(s) »
   et l'affrontement est marqué PARTAGÉE. Le choix explicite « modifier le
   partagé » vs « dupliquer pour cet affrontement », et l'abandon sans mutation
   de la source, réutilisent le mécanisme existant (`_ensure_editable`,
   `_usage_summary`, tables `source ↔ copie` transmises par Terrain).
   **À CONFIRMER** — aucun test automatisé dédié au mode brouillon n'a été écrit
   pour ces deux derniers chemins.
5. **Nettoyage du `GameManager` et suppression du dossier temporaire** après un
   vrai test runtime : **À CONFIRMER**. Le test automatisé vérifie la
   construction du contexte, sa localisation sous `user://`, son contenu et
   l'absence de mutation ; il ne lance pas la scène (API éditeur absente en
   test) et ne peut donc pas observer le nettoyage post-partie.
6. **Recette humaine dans l'éditeur Godot** : non effectuée.
