# Audit mécanique avant remise à zéro de la progression de l’Elfe

Date de l’audit : 25 juillet 2026

Branche auditée : `audit/elf-progression-reset`

HEAD initial : `d3f7b037a118dfef14ff2a0145a9381872027999`

## Convention de preuve

Le rapport distingue systématiquement trois niveaux :

- **PROUVÉ** : constat directement vérifiable dans un fichier, une ressource, la configuration ou la sortie d’une commande.
- **DÉDUCTION** : conséquence probable tirée du graphe de références et du comportement du code.
- **INCONNU** : usage externe, manuel ou dynamique que le dépôt ne permet pas de trancher.

Le mot « actif » signifie ici « atteignable depuis `project.godot` par le flux de lancement normal », et non « fichier techniquement chargeable depuis l’éditeur ».

## 1. Résumé exécutif

**PROUVÉ — Le prototype lancé depuis `project.godot` n’est pas une tranche Elfe.** Il ouvre `res://ui/TitreEcran.tscn`, charge `res://data/runs/run_default.tres`, impose un draft de **trois héros distincts** parmi sept, demande séparément une école parmi Rage/Foi/Nature/Ombre et un trait de départ, puis déroule cinq combats et quatre écrans de récompense.

**PROUVÉ — L’Elfe est seulement une option de héros parmi sept.** Sa ressource `res://data/units/alliés/elfe.tres` porte trois sorts historiques de Mage :

1. `res://data/spells/frappe.tres` ;
2. `res://data/spells/mur_de_glace.tres` ;
3. `res://data/spells/Mage/boule_de_feu.tres`.

Elle ne porte ni école d’énergie ni châssis dans son `UnitData`, mais `GameManager._build_heroes_from_draft()` lui affecte après instanciation l’école et le trait choisis dans le draft.

**PROUVÉ — La dette à retirer est transversale.** Ferveur, Éveil, Réaction et Empreinte traversent `EnergyTypeData`, `EnergyGauge`, `Unit`, `Spell`, `SpellCaster`, `CastContext`, `TerrainEffects`, `EventBus`, `action_bar.gd`, `inspect_panel.gd`, `unit_view.gd`, les traits, les ressources d’énergie et 39 tests GUT directement centrés sur l’économie d’énergie/Éveil/coûts/Force.

**PROUVÉ — La Réaction visible n’est pas jouable par le clic.** `ui/action_bar.gd` déclare et émet `reaction_pressed`, mais `battle/battle.gd::_setup_ui()` ne connecte pas ce signal, contrairement à `awakening_pressed`.

**PROUVÉ — La fin de run n’a aucun consommateur.** `GameManager` émet `run_won` ou `run_lost`, mais aucune autre référence à ces signaux n’existe dans le dépôt. Après la dernière victoire ou une défaite, aucune scène terminale n’est chargée.

**PROUVÉ — Les pools étendus ne pilotent aucun gameplay.** `RunData` déclare `relic_pool`, `equipment_pool`, `event_pool`, `boss_malus_pool` et `run_nodes`. `run_default.tres` charge respectivement 20, 16, 8, 5 et 6 ressources, mais aucun code runtime ne lit ces cinq champs. Ils augmentent toutefois le graphe de chargement de `run_default.tres`.

**PROUVÉ — Les validations unitaires passent, avec une réserve d’outillage.** L’import headless fiable termine avec le code 0 et un avertissement `ObjectDB`. GUT exécute 13 scripts, 73 tests et 512 assertions : 73/73 passent. Après son résumé positif, GUT 9.7.1 produit deux erreurs de parse internes à l’addon sous Godot 4.6.3 et avertit qu’il pourrait être incompatible avec cette version ; le processus retourne malgré tout 0.

**DÉDUCTION — La simplification la plus sûre est de découpler d’abord le flux de run, puis le contenu, puis l’économie d’énergie.** Retirer les ressources avant d’avoir changé les constantes de `GameManager`, `run_default.tres`, le HUD et les tests casserait l’import ou le draft. Le moteur tactique peut être conservé si les changements sont réalisés derrière les frontières existantes `UnitData → Unit`, `Battle → SpellCaster` et `RoomData → battle_scene`.

## 2. État Git et environnement

### État initial

| Élément | Valeur | Preuve |
|---|---|---|
| Branche | `audit/elf-progression-reset` | `git branch --show-current` |
| HEAD initial | `d3f7b037a118dfef14ff2a0145a9381872027999` | `git rev-parse HEAD` |
| Working tree initial | `?? .claude/` uniquement | `git status --short --branch` |
| Modification préexistante | dossier non suivi `.claude/` | non créé ni modifié par cet audit |
| Configuration projet | `config_version=5` | `project.godot` |
| Feature Godot déclarée | `4.6`, renderer `Forward Plus` | `project.godot:config/features` |
| Version locale exécutée | `4.6.3.stable.official.7d41c59c4` | binaire et métadonnées du projet |
| Version README | « Godot 4.7 » | `README.md` |
| Version CI | `GODOT_VERSION: "4.7"` | `.github/workflows/ci.yml` |
| Scène principale | UID `uid://bhxy4lh81uk3i` → `res://ui/TitreEcran.tscn` | `project.godot`, en-tête de la scène |

Le dépôt est vu avec une propriété Windows différente par le compte du bac à sable. Les commandes Git de l’audit utilisent `git -c safe.directory=C:/Users/paolo/Documents/dungeon-draft-v-2 …` ; aucune configuration Git globale ou locale n’a été changée.

### Autoloads

| Ordre | Nom | UID | Fichier résolu | Catégorie |
|---:|---|---|---|---|
| 1 | `DebugLogger` | `uid://cqowcxd62yalq` | `res://debug/debug_logger.gd` | KEEP |
| 2 | `EventBus` | `uid://b7ud323xfkfr4` | `res://core/event_bus.gd` | KEEP, avec signaux legacy à isoler |
| 3 | `CombatLogger` | `uid://doclkvcosndc2` | `res://core/combat_logger.gd` | KEEP |
| 4 | `DebugOverlay` | `uid://i5c6lt5m6q0w` | `res://debug/DebugOverlay.tscn` | KEEP |
| 5 | `GameManager` | `uid://bkqluvhsrm1gs` | `res://core/game_manager.gd` | REPLACE |
| 6 | `AudioManager` | `uid://b6yj2wg2t5akr` | `res://core/audio_manager.gd` | KEEP |
| 7 | `VFXManager` | `uid://bjqhf4gosaohn` | `res://core/vfx_manager.gd` | KEEP |

### Plugins actifs

| Plugin | Version | État |
|---|---:|---|
| GUT, `res://addons/gut/plugin.cfg` | 9.7.1 | actif |
| Meshy official plugin, `res://addons/meshy-godot-plugin/plugin.cfg` | 0.1.6 | actif |

## 3. Graphe textuel du flux actif

```text
project.godot
  run/main_scene = uid://bhxy4lh81uk3i
  → ui/TitreEcran.tscn
    → ui/titre_ecran.gd::_ready()
    → preload data/runs/run_default.tres
    → _on_nouvelle_partie()
      → GameManager.start_run(run_default)
        → mémorise _pending_run_data
        → change_scene_to_file(ui/RunDraftScreen.tscn)
          → RunDraftScreen._ready()
          → charge 7 UnitData + 4 EnergyTypeData + 4 TraitData via GameManager
          → initialise 3 slots depuis GameManager.DEFAULT_DRAFT
          → _on_start_pressed()
            → GameManager.confirm_run_draft(hero_paths, energy_paths, trait_paths)
              → _build_heroes_from_draft()
                → load(UnitData) → Unit.from_data()
                → surcharge Unit.energy_type avec le choix séparé
                → ajoute le trait de départ
                → ensure_energy_traits() + reset_combat_resources()
              → copie RunData.rooms et RunData.reward_pool seulement
              → _go_to_next_room()
                → change_scene_to_file(ui/Transitionsalle.tscn)
                  → transition_salle.gd::_ready()
                  → GameManager.get_current_room()
                  → bouton → GameManager.start_next_battle()
                    → change_scene_to_packed(RoomData.battle_scene)
                      → battle/battle.gd::_ready()
                      → get_current_room()
                      → GridData + Pathfinder + TerrainEffects
                      → SpellCaster + EnemyAI + EnemyTurnRunner
                      → DeploymentController
                      → ennemis = RoomData.enemies → Unit.from_data()
                      → héros = GameManager.get_living_heroes()
                      → déploiement → _start_battle()
                      → TurnQueue + TurnState + HUD dynamique
                      → _check_battle_end()
                        ├─ victoire → _end_battle(true)
                        │  → GameManager.on_battle_won()
                        │    ├─ dernière salle
                        │    │  → _go_to_next_room()
                        │    │  → run_won.emit() ; aucune transition
                        │    └─ autre salle
                        │       → première victoire : Marteau forcé + 2 tirages
                        │       → autres victoires : 3 tirages
                        │       → change_scene_to_file(ui/RewardScreen.tscn)
                        │         → RewardScreen._ready()
                        │         → GameManager.get_offered_rewards()
                        │         → choix ou passer
                        │         → GameManager.choose_reward()
                        │         → applique soin/stat/sort/trait/statut
                        │         → _go_to_next_room()
                        │         → ui/Transitionsalle.tscn
                        └─ défaite → _end_battle(false)
                           → GameManager.on_battle_lost()
                           → run_lost.emit() ; aucune transition
```

### Ressource de run réellement active

`ui/titre_ecran.gd` précharge directement `res://data/runs/run_default.tres`. `data/main.tscn` référence la même ressource, mais n’est pas la scène principale et n’a aucune référence entrante.

`run_default.tres` fournit, dans cet ordre :

1. `data/rooms/bible/le_gue.tres` → `data/rooms/maps/battle_salle1_iso.tscn` ;
2. `data/rooms/bible/la_forge.tres` → `data/rooms/maps/battle_salle2.tscn` ;
3. `data/rooms/bible/elite_brute.tres` → `data/rooms/maps/battle_salle2.tscn` ;
4. `data/rooms/bible/catacombes.tres` → `data/rooms/maps/battle_salle3.tscn` ;
5. `data/rooms/bible/boss_meduse.tres` → `data/rooms/maps/battle_salle3.tscn`.

La première carte est isométrique et configure `standalone_preview_without_room = true` et `temporary_iso_placeholders = true`. Les deux autres cartes actives utilisent le même `battle/battle.gd` avec un `TileMapLayer` cartésien.

### Ennemis réellement chargés par ces cinq salles

Douze `UnitData` distincts sont actifs :

- `data/units/boss/meduse.tres` ;
- `data/units/ennemie/elite_brute_gobelin.tres` ;
- `data/units/ennemie/elite_pyromage_gobelin.tres` ;
- `data/units/ennemie/GobTestUnitData_v2.tres` ;
- `data/units/ennemie/run_archer_gobelin.tres` ;
- `data/units/ennemie/run_brute_gobelin.tres` ;
- `data/units/ennemie/run_eclaireur_gobelin.tres` ;
- `data/units/ennemie/run_hurleur_gobelin.tres` ;
- `data/units/ennemie/run_lieur_gobelin.tres` ;
- `data/units/ennemie/run_porte_bouclier_gobelin.tres` ;
- `data/units/ennemie/run_pyromage_gobelin.tres` ;
- `data/units/ennemie/serpent_meduse.tres`.

Leurs huit sorts référencés explicitement sont `regard_petrifiant`, `morsure_serpent`, `braise_gobeline`, `etincelle`, `mêlée_gobelin`, `fleche`, `hurlement_drainant` et `entrave`. Les comportements avancés actifs sont `boss_roi_gobelin.gd` et quatre ressources sous `data/ai_behaviors/` : `archer_kiter`, `hurleur_drain`, `lieur_entrave` et `pyromage_poseur_de_feu`.

## 4. Tableau des systèmes

| Système | Définition / point d’entrée | Usage actif prouvé | Destination |
|---|---|---|---|
| Héros | `UnitData`, `Unit`, `GameManager.HERO_DATA_PATHS` | 7 options, 3 choisies | moteur KEEP ; catalogue QUARANTINE ; sélection REPLACE |
| Ennemis | `RoomData.enemies`, `Unit.from_data`, `EnemyAI` | 12 ressources dans le run courant | KEEP pour les 12 actives ; autres QUARANTINE |
| `UnitData` | `data/unit_data.gd` | instanciation héros et ennemis | KEEP, champs build legacy à remplacer |
| Sorts | `data/spell.gd`, 69 `.tres` | `Unit.spells`, rewards, ennemis | schéma/caster KEEP ; catalogue héros QUARANTINE |
| Écoles | `EnergyTypeData`, 4 `.tres` | draft, surcharge de chaque héros | REPLACE + ressources QUARANTINE |
| `EnergyGauge` | `units/energy_gauge.gd` | créé dans `Unit._init()` pour toute unité | REPLACE |
| Éveil | `EnergyGauge`, `Unit`, `action_bar`, `battle` | bouton connecté et activation active | REPLACE |
| Réaction | `Unit`, `EnergyTypeData`, `action_bar` | logique de mitigation active, clic non connecté | REPLACE |
| Empreinte | champs `Spell.imprint_*`, `CastContext.imprinted`, `SpellCaster` | bouton dupliqué si `can_imprint()` | REPLACE |
| Traits | `TraitData`, `TraitFactory`, 23 scripts, 28 ressources | châssis, départ, rewards | moteur KEEP ; départ/châssis QUARANTINE |
| Châssis | quatre `chassis_*.tres` et scripts | inclus dans six héros du draft | QUARANTINE |
| `SpellModifier` | `core/spell_modifier.gd`, `CastContext`, `SpellCaster` | Brassard Incendiaire + tests | KEEP |
| Récompenses | `RewardData`, `RewardScreen`, `GameManager` | pool de 33 ; 3 choix par victoire | REPLACE |
| Relique Marteau | `FIRST_REWARD_PATH` | forcée après la salle index 0 | QUARANTINE |
| Reliques | `RelicData`, 20 ressources | chargées par `run_default`, non lues | QUARANTINE |
| Équipements | `EquipmentData`, 16 ressources | chargés par `run_default`, non lus | QUARANTINE |
| Événements | `RunEventData`, 8 ressources | chargés par `run_default`, non lus | QUARANTINE |
| Malus de boss | `BossMalusData`, 5 ressources | chargés par `run_default`, non lus | QUARANTINE |
| Progression de run | `GameManager`, `RunData` | index de salle + HP persistants | REPLACE |
| Nœuds de run | `RunNodeData`, 6 ressources | chargés par `run_default`, non lus | QUARANTINE |
| Salles | `RoomData`, 7 « bible », anciennes salles | 5 utilisées | schéma KEEP ; séquence REPLACE |
| Draft | `RunDraftScreen` | flux obligatoire à 3 slots | REPLACE |
| Récompense UI | `RewardScreen` | flux obligatoire entre combats | REPLACE |
| HUD combat | `action_bar`, `inspect_panel`, `unit_view` | construit dynamiquement par `Battle` | KEEP structure ; économie legacy REPLACE |
| Elfe visuel | `ElfIsoUnitView` → `ElfVisual3D` → GLB | `elfe.tres.visual_scene` → `UnitView` | KEEP |
| Moteur tactique | grille, pathfinding, tours, cast, dégâts, terrain, IA, déploiement | instancié par `Battle` | KEEP |
| Tests | GUT + 4 scènes Elfe autonomes + CI | GUT configuré sur `test/unit` | KEEP, puis adapter explicitement |

## 5. Inventaire KEEP / QUARANTINE / REPLACE / DELETE_CANDIDATE / UNKNOWN

### KEEP

| Élément | Justification mécanique |
|---|---|
| `core/grid_data.gd`, `core/pathfinder.gd` | source de vérité grille et chemins |
| `core/turn_queue.gd`, `battle/turn_state.gd` | ordre des tours et machine d’interaction |
| `core/spell_caster.gd`, `core/cast_context.gd`, `core/damage_resolver.gd` | pipeline tactique demandé ; les branches énergie/empreinte sont à isoler, pas le pipeline |
| `core/terrain_effects.gd`, `data/units/terrain_effect_data.gd`, `data/terrain/*.tres` | terrain utile ; 14 ressources, certaines legacy mais moteur réutilisable |
| `core/enemy_ai.gd`, `battle/enemy_turn_runner.gd`, `core/ai/*.gd` | décision et exécution ennemies |
| `battle/deployment_controller.gd` | déploiement indépendant du nombre de héros |
| `core/event_bus.gd` | découplage central ; conserver l’API utile |
| `battle/battle.gd` | orchestrateur tactique actif ; garder le fichier, remplacer ses connexions legacy par étapes |
| `data/rooms/room_data.gd` | frontière data-driven salle → combat |
| `data/rooms/maps/battle_salle1_iso.tscn`, `battle/iso/iso_grid_view.gd`, `battle/iso/iso_projection.gd`, décor forêt | première carte active et pipeline isométrique testé |
| `data/unit_data.gd`, `units/unit.gd`, `units/stats.gd` | modèle de combattant ; les champs énergie/châssis sont des sous-parties REPLACE |
| `data/spell.gd` | schéma de sort encore nécessaire ; les champs `energy_cost`, `fervor_cost`, `imprint_*`, `charge_verb` sont legacy |
| `core/spell_modifier.gd`, `core/spell_mods/*`, `traits/trait_spell_modifier.gd`, `data/spell_mods/*` | extension générique utile aux améliorations de discipline ; couverte par 4 tests |
| `traits/trait.gd`, `traits/trait_data.gd`, `traits/trait_factory.gd` | infrastructure data-driven réutilisable, distincte du catalogue legacy |
| `characters/elf/ElfIsoUnitView.tscn`, `elf_iso_unit_view.gd`, `ElfVisual3D.tscn`, `elf_visual_3d.gd` | pipeline Elfe actif |
| `assets/characters/elf/elf_character_v01.glb` et textures associées | source visuelle 3D active |
| `battle/unit_view.gd`, `battle/unit_view.tscn` | point d’intégration générique de `Unit.visual_scene` |
| `debug/*`, `core/combat_logger.gd`, `core/audio_manager.gd`, `core/vfx_manager.gd` | services actifs |
| `test/unit/test_iso_*`, `test/unit/test_forest_room_iso.gd`, `test/unit/test_collision_chain.gd`, `test/unit/test_log_definitions.gd`, `test/unit/test_spell_modifier.gd` | couverture du socle à préserver |
| `.github/workflows/ci.yml`, `.gutconfig.json`, `addons/gut/` | pipeline de test ; compatibilité de version à traiter séparément |

### QUARANTINE

| Élément | Contenu |
|---|---|
| Six héros non-Elfe proposés | `Gardien.tres`, `Guerrier.tres`, `healer.tres`, `Assassin.tres`, `Necromant.tres`, `Hoplite.tres` |
| Deux héros alliés hors draft | `chevalier.tres`, `mage.tres` |
| Quatre écoles | `data/energy/rage.tres`, `foi.tres`, `nature.tres`, `ombre.tres` |
| Châssis | quatre ressources `data/traits/chassis_*.tres` et quatre scripts `traits/trait_chassis_*.gd` |
| Traits de départ | quatre `data/traits/depart_*.tres` et leurs scripts concrets lorsqu’ils ne servent plus ailleurs |
| Sorts historiques de héros | ressources sous `data/spells/Gardien`, `Guerrier`, `Healer`, `assasin`, `Hoplite`, `Necromant`, plus le catalogue `draft/` |
| Récompenses historiques | les 33 `.tres` de `data/rewards/`, dont le Marteau forcé |
| Reliques / équipement / événements / malus / nœuds | 20 + 16 + 8 + 5 + 6 ressources chargées mais non consommées par le flux |
| Ressources de traits de reliques | `data/traits/relique_*.tres`, `reward_epaule_enflamme.tres`, scripts spécialisés legacy |
| Salles hors séquence active | `arene_mouvante.tres`, `sanctuaire_objectif.tres`, `salle_1..3.tres`, `boss_colosse.tres`, `situation_totem.tres` |
| Ennemis/boss hors cinq salles actives | autres `data/units/ennemie/*.tres`, `data/units/boss/*.tres` et sorts exclusivement référencés par eux |
| Cartes de compatibilité | `battle.tscn`, `battle_salle1.tscn` et laboratoires isométriques ; techniquement valides et couverts par `test_forest_room_iso.gd` |
| Documentation historique de design | `README.md` et commentaires centrés sur écoles/Ferveur, à ne pas utiliser comme vérité de la future tranche |

### REPLACE

| Élément actif | Rôle à remplacer |
|---|---|
| `core/game_manager.gd` | catalogue 7 héros, draft 3 héros, écoles, traits, récompense forcée, séquence et fin de run |
| `ui/run_draft_screen.gd`, `ui/RunDraftScreen.tscn` | draft trois héros/écoles/traits → démarrage Elfe et disciplines |
| `data/runs/run_data.gd`, `data/runs/run_default.tres` | récompenses/pools historiques → courte progression de disciplines |
| `data/units/alliés/elfe.tres` | trois sorts Mage → quatre disciplines, un sort initial chacune, quatre emplacements |
| `units/energy_gauge.gd` | jauge de combat Ferveur/Éveil/Réaction → aucun rôle dans la cible annoncée |
| `data/energy/energy_type.gd` | modèle quatre écoles → progression XP par discipline |
| sous-système énergie de `units/unit.gd` | façades `energy_type/current_energy`, Éveil, Réaction, génération |
| sous-système build de `data/unit_data.gd` | `energy_type`, `chassis_trait`, `starting_traits`, liste historique de sorts |
| `ui/action_bar.gd` | barre Ferveur, Éveil, Garde, boutons Empreinte → quatre slots actifs |
| portions legacy de `ui/inspect_panel.gd`, `ui/combat_glossary.gd`, `battle/unit_view.gd` | explications et barres d’école |
| `ui/reward_screen.gd`, `ui/RewardScreen.tscn`, `data/rewards/reward_data.gd` | récompenses globales/traits/sorts → choix d’amélioration de discipline |
| portions de `data/spell.gd`, `core/spell_caster.gd`, `core/cast_context.gd` | `fervor_cost`, `imprint_*`, `imprinted` |
| fin de run de `GameManager` | signaux sans consommateur → écran ou retour déterministe |

### DELETE_CANDIDATE

Ces éléments ont **zéro référence entrante textuelle par chemin ou UID** dans le dépôt au moment de l’audit. Cela ne prouve pas l’absence d’ouverture manuelle depuis l’éditeur ; une validation séparée reste obligatoire.

| Élément | Références entrantes trouvées | Note |
|---|---:|---|
| `data/main.tscn` | 0 | ancien point d’entrée déclaré dans son commentaire ; charge `main.gd` et `run_default.tres` |
| `main.gd` | 1 | uniquement `data/main.tscn` |
| `ui/ecran_titre_base.tscn` | 0 | distinct de la scène principale `TitreEcran.tscn` |
| `gobtest.tscn` | 0 | scène autonome |
| `gobtest.gd` | 1 | uniquement `gobtest.tscn` |
| `test_phase_1.tscn` | 0 | scène de test historique hors GUT configuré |
| `test_phase_2.tscn` | 0 | scène de test historique hors GUT configuré |
| `data/rooms/maps/battle test.tscn` | 0 | carte/laboratoire non référencé |
| `data/rooms/maps/battle_salletest.tscn` | 0 | carte/laboratoire non référencé |
| `data/rooms/maps/batttest.tscn` | 0 | carte/laboratoire non référencé |
| `data/rooms/maps/test_battle_asphodel.tscn` | 0 | carte/laboratoire non référencé |

### UNKNOWN

| Élément | Pourquoi inconnu |
|---|---|
| Ouvertures manuelles de scènes `DELETE_CANDIDATE` | l’historique d’usage de l’éditeur n’est pas versionné |
| Assets sous `asset/` et `imported_models/` sans référence textuelle | certains peuvent être glissés manuellement, référencés par métadonnées d’import ou conservés comme sources |
| Intention future exacte des 12 ennemis actifs et des cartes 2/3 | la cible dit « courte suite de combats » sans préciser quels ennemis/cartes réutiliser |
| Besoin futur du système générique `Trait` | il peut porter les améliorations de discipline, mais ce choix d’architecture n’est pas encore décidé |
| `CharacterVisual3D` cité dans la cible | aucune classe, scène, ressource ni référence portant ce nom n’existe dans le dépôt ; le pipeline prouvé commence à `UnitView` puis `ElfIsoUnitView` et `ElfVisual3D` |
| Compatibilité réelle de GUT 9.7.1 avec Godot 4.7 CI | l’audit local utilise 4.6.3 ; le runner avertit seulement pour cette version locale |

## 6. Références entrantes importantes

Le tableau regroupe les éléments QUARANTINE, REPLACE et DELETE_CANDIDATE par frontière cohérente. « Ressource » signifie une référence `ext_resource` dans `.tres/.tscn`.

| Cible | Références entrantes / mécanisme | Conséquence probable d’une désactivation immédiate | Couverture |
|---|---|---|---|
| `GameManager` | autoload UID dans `project.godot`; appels depuis titre, draft, transition, battle, reward, `Unit` | tout le run devient inopérant | aucune couverture directe du flux complet |
| `RUN_DRAFT_SCREEN_PATH` | constante chemin dans `GameManager.start_run()` | nouvelle partie reste sans transition | pas de test de flux |
| `HERO_DATA_PATHS` | `get_draft_hero_options()` → `load(path)` ; UI construit ses choix | options absentes, valeurs par défaut invalides | pas de test du catalogue |
| Six héros non-Elfe | chemins codés dans `HERO_DATA_PATHS`; trois aussi dans `DEFAULT_DRAFT`; sorts/châssis par ressources | draft incomplet ou erreurs de chargement tant que constantes/UI inchangées | import seulement |
| `elfe.tres` | chemin dans `HERO_DATA_PATHS`; constantes et scène autonome sous `tests/characters/elf`; ressource `visual_scene` | Elfe disparaît du draft et de l’intégration visuelle | runners Elfe autonomes, pas GUT |
| Trois sorts de l’Elfe | `ext_resource` dans `elfe.tres`; Boule de feu documentée/testée par le runner Salle 1 | boutons de sort en moins ; runner visuel/cast à adapter | runner Elfe autonome |
| `ENERGY_DATA_PATHS` + 4 `.tres` | `GameManager` → `load`; références directes dans six héros; test direct `test_gain_table.gd` | draft et héros historiques cassés ; tests d’énergie échouent | `test_gain_table`, jauge, Éveil, coûts |
| `STARTING_TRAIT_PATHS` | `GameManager` → `load`; `DEFAULT_DRAFT`; `RunDraftScreen` | draft invalide si retirés avant l’UI | pas de test du draft |
| Châssis | ressources référencées par six `UnitData`; `Unit.from_data()` → `add_trait_from_data()` | génération d’école et identité des héros changent | effets indirects, pas de test de catalogue |
| `DEFAULT_DRAFT` | lu par `RunDraftScreen._init_defaults()` | sélections initiales vides ; démarrage désactivé | pas de test |
| `confirm_run_draft` | `RunDraftScreen._on_start_pressed()` | aucun héros/room/reward n’est initialisé | pas de test end-to-end |
| `UnitData.energy_type` | lu dans `Unit.from_data()` ; ensuite surchargé par `GameManager` | ennemis/héros configurés perdent leur jauge | nombreux tests de `Unit`, aucun test du draft |
| `Unit.spells` | rempli par `Unit.from_data()` et `GameManager._apply_reward()` ; lu par HUD et IA | plus de boutons ni sorts IA | coûts/caster partiellement couverts |
| `EnergyGauge` | `EnergyGauge.new(self)` dans chaque `Unit._init()` ; façades dans `Unit` | construction de toute unité casse si retiré sans façade de remplacement | 12 tests dédiés + tests indirects |
| Éveil | bouton `action_bar` → signal connecté dans `Battle`; méthodes `Unit/EnergyGauge`; signaux `EventBus` | bouton/HUD/traits et tests cassent | 12 tests dédiés |
| Réaction | bouton émet un signal non connecté ; mitigation appelée dans `Unit.take_damage()` ; paramètres dans chaque énergie | le clic est déjà sans effet ; suppression brute casse affichage et logique auto éventuelle | aucune classe de test dédiée |
| Empreinte | `action_bar` duplique les boutons ; `TurnState`, `Battle`, `SpellCaster`, `CastContext`, `Spell` | signatures et appels de cast divergent | coûts de base testés, pas de test d’empreinte isolé |
| `action_bar.gd` | `Battle._setup_ui()` → `load(path)` puis `set_script()` | combat sans contrôles | pas de test UI GUT |
| `RunData.reward_pool` | copié dans `GameManager.confirm_run_draft()` | aucune RewardScreen ; passage direct à la salle suivante si vide | pas de test de run |
| Pools étendus | champs déclarés dans `RunData`, remplis par `run_default.tres`; aucun lecteur runtime | aucun changement de gameplay, mais graphe de chargement allégé | aucun test |
| `FIRST_REWARD_PATH` | `GameManager._get_forced_reward_for_room(0)` → `load()` | première offre passe de 3 à 2 tirages si retiré seul de façon invalide, ou erreur/null selon chargement | aucun test |
| `reward_marteau_jugement.tres` | `FIRST_REWARD_PATH` + `run_default.reward_pool`; cible nommée « Gardien » | récompense sans effet si Gardien absent ; trait Marteau non attaché | pas de test spécifique |
| 33 rewards | `ext_resource` dans `run_default.tres`; RewardScreen reçoit les tirages | récompenses manquantes ou pool vide | Brassard couvert par 2 tests end-to-end |
| `RewardScreen` | chemin codé dans `GameManager.on_battle_won()` | run bloqué après victoire si scène retirée | pas de test UI |
| Reliques/équipement/events/malus/nœuds | uniquement `run_default.tres` et leurs ressources liées ; chargement par ressource, aucun lecteur | pas d’effet runtime observé ; possibles erreurs d’import si suppression partielle | aucun test |
| Séquence de 5 salles | `run_default.rooms`; copiée par `GameManager` | run vide ou raccourci | `test_forest_room_iso` vérifie surtout la première |
| Salles actives | `ext_resource` dans `run_default`; `RoomData.battle_scene/enemies` | transition ou combat invalide | première salle partiellement couverte |
| Salles/cartes legacy | références entre `RoomData` et scènes ; certaines assertions de compatibilité dans `test_forest_room_iso` | suppression casse ce test même hors flux | oui, explicitement |
| Candidats `data/main`, titre base, gobtest, phases, quatre cartes test | zéro référence scène/config/test par chemin ou UID, sauf script → scène propriétaire | aucune conséquence sur le flux principal déduite | aucune |

### Formes de chargement observées

- **UID/configuration** : scène principale et autoloads dans `project.godot`.
- **Chemin codé / `load`** : catalogues de `GameManager`, `FIRST_REWARD_PATH`, scripts UI construits dans `Battle`.
- **`preload`** : `run_default.tres` dans `titre_ecran.gd`, `unit_view.tscn` dans `Battle`, scripts utilitaires.
- **Scène/ressource** : `RunData → RoomData → PackedScene/enemies`, `UnitData → spells/châssis/visual_scene`, rewards → sort/trait/statut.
- **Classe globale** : `UnitData`, `Spell`, `EnergyTypeData`, `RewardData`, `TraitData`, etc. sont également résolus par `class_name`, même lorsqu’aucun chemin n’apparaît au site d’appel.
- **Test** : les tests chargent directement certaines ressources d’énergie, scènes et ressources du Brassard.

## 7. Contradictions et dette legacy

### Configuration et documentation

1. **PROUVÉ** — `project.godot` déclare 4.6, le poste exécute 4.6.3, alors que README et CI annoncent 4.7.
2. **PROUVÉ** — `main.gd` se décrit comme « Point d’entrée », mais `data/main.tscn` n’est pas la scène principale.
3. **PROUVÉ** — README présente les quatre écoles et la Ferveur comme définition actuelle du jeu ; c’est contradictoire avec la cible Elfe/discipline.
4. **PROUVÉ** — les commentaires `UnitData` et `EventBus` disent que l’énergie « remplace les PA », tandis que le runtime utilise explicitement PA + PM + Ferveur.

### Coûts et lexique

1. **PROUVÉ** — `Spell.energy_cost` est exporté « uniquement pour compatibilité », et `SpellCaster` l’ignore. Cependant `ui/combat_glossary.gd:173` le lit encore pour calculer un texte de coût ; `chevalier.tres` contient `energy_cost = 50.0`.
2. **PROUVÉ** — `fervor_cost` est le vrai coût de jauge du caster. `energy_cost`, `fervor_cost`, `current_energy`, « Ferveur » et « Charge » coexistent.
3. **PROUVÉ** — `GameManager.get_charge_multiplier()` est un alias de `get_fervor_multiplier()`, et `Unit.generate_charge_from_verb()` un alias de `generate_fervor_from_verb()`.
4. **PROUVÉ** — `EventBus` émet en parallèle `fervor_changed` et `charge_changed`, ainsi que les variantes de seuil.
5. **PROUVÉ** — des noms de fichiers et classes « Élan » (`trait_elan_on_turn_start`, `reward_elan_brut`, `talisman_elan_ouverture`) produisent désormais de la Ferveur.
6. **PROUVÉ** — `charge_verb` reste le nom de champ des verbes de génération, malgré l’interface Ferveur.

### Flux et données

1. **PROUVÉ** — `GameManager.DEFAULT_DRAFT` force Gardien/Foi/Posture, Guerrier/Rage/Étincelle et healer/Nature/Instinct, donc le prototype actif commence loin de l’Elfe.
2. **PROUVÉ** — l’Elfe porte trois sorts Mage et aucune notion de discipline ou d’XP.
3. **PROUVÉ** — `Unit.add_spell()` ne limite pas la taille de `Unit.spells`; RewardData peut ajouter des sorts sans plafond. La cible exige quatre emplacements.
4. **PROUVÉ** — `RunData` commente un tirage de trois récompenses après chaque salle, mais la dernière salle n’en donne pas.
5. **PROUVÉ** — le Marteau du Jugement est forcé au premier écran et cible par nom `Gardien`. Si le Gardien n’est pas vivant/sélectionné, `_resolve_reward_targets()` renvoie une liste vide ; le choix peut donc n’avoir aucun effet.
6. **PROUVÉ** — une autre récompense cible `Guerrier` par nom (`reward_coup_epaule_enflamme.tres`).
7. **PROUVÉ** — `SpellModifier.target_spell_name` filtre par nom exact de sort. Le Brassard dépend de cette convention lexicale.
8. **PROUVÉ** — le placeholder isométrique dépend du nom exact `"Eclaireur gobelin"`.
9. **PROUVÉ** — les signaux de fin de run n’ont pas de récepteur.
10. **PROUVÉ** — les cinq pools étendus sont des champs déclarés et sérialisés, mais jamais lus.

### Réaction, Éveil et Empreinte

1. **PROUVÉ** — le bouton Éveil est relié et actif.
2. **PROUVÉ** — le bouton Garde/Réaction émet, mais `Battle` ne connecte pas `reaction_pressed`.
3. **PROUVÉ** — `Unit.start_turn()` désarme les héros et peut armer automatiquement les ennemis selon leur disponibilité, ce qui coexiste avec un bouton joueur non relié.
4. **PROUVÉ** — les boutons Empreinte sont créés en doublon à partir de chaque sort dont `imprint_fervor_cost > 0`.
5. **DÉDUCTION** — retirer uniquement le HUD ne retire pas ces mécaniques : leurs effets restent dans `Unit`, `EnergyGauge`, `SpellCaster`, les traits et les événements.

### Données apparemment inertes

- `RunData.relic_pool`, `equipment_pool`, `event_pool`, `boss_malus_pool`, `run_nodes` : chargés, non lus.
- `EnergyTypeData.passive_income_per_tier` : présent et testé via helper, mais aucun appel runtime hors méthode d’accès n’a été trouvé.
- `EnergyTypeData.basic_attack_cost` : déclaré ; l’attaque de base réelle retourne la constante `Unit.BASIC_ATTACK_AP_COST = 1`.
- `EnergyTypeData.threshold` et `threshold_exit` : encore décrits comme seuil de Charge, tandis que l’activation réelle vérifie `awakening_cost`.
- `Spell.energy_cost` : ignoré par la résolution des coûts, mais lu par le glossaire.

## 8. Dépendances techniques à préserver

```text
RoomData
  → Battle
    → GridData
    → Pathfinder
    → TerrainEffects
    → SpellCaster → CastContext → DamageResolver
    → EnemyAI → EnemyTurnRunner
    → DeploymentController
    → TurnQueue
    → TurnState
    → UnitView
      → Unit.visual_scene
        → ElfIsoUnitView
          → ElfVisual3D
            → elf_character_v01.glb
    → EventBus
```

Points de contrat particulièrement sensibles :

- `GridData` reste la source de vérité après import du `TileMapLayer`.
- `SpellCaster.cast()` reste le point unique de vérification/dépense et de résolution d’un sort.
- `DamageResolver` reste le point de calcul des dégâts.
- `UnitView` déplace le combattant ; `ElfIsoUnitView` reste local à son parent et ne modifie pas la grille.
- `cast_release_reached` retarde seulement la résolution visuelle du cast ; il ne calcule pas le gameplay.
- `RoomData.battle_scene` permet de changer la séquence sans coupler `GameManager` aux cartes.
- `EnemyTurnRunner` doit rester séparé de la décision `EnemyAI`.
- `EventBus` doit conserver les signaux non legacy utilisés par logs, VFX, HUD, traits et tests.
- Le mode `temporary_iso_placeholders` masque le rendu historique sauf lorsqu’un `visual_scene` optionnel existe ; il ne doit pas masquer l’Elfe.
- Les tests ISO garantissent aussi la chargeabilité de scènes anciennes : les désactiver dans le flux n’autorise pas encore leur suppression.

## 9. Ordre de désactivation recommandé

1. **Geler les contrats à préserver.** Ajouter ultérieurement des tests ciblés sur lancement Elfe, quatre slots, séquence, victoire/défaite, sans modifier les tests pendant cet audit.
2. **Remplacer le modèle de run.** Introduire un `RunData` minimal ou un nouveau modèle de progression de disciplines, puis faire de `GameManager` son orchestrateur.
3. **Remplacer le draft.** Retirer du flux actif les listes héros/énergies/traits et construire un seul `Unit` Elfe.
4. **Créer les quatre disciplines et quatre sorts initiaux.** Modifier la ressource Elfe seulement après que leur schéma est défini.
5. **Faire respecter quatre emplacements.** Remplacer la liste ouverte/ajout de sort des rewards avant d’exposer les améliorations.
6. **Remplacer RewardScreen.** Basculer de `RewardData` vers des choix d’amélioration/XP de discipline.
7. **Retirer la récompense forcée.** Supprimer la dépendance fonctionnelle à `FIRST_REWARD_PATH` et aux cibles `Gardien`/`Guerrier`.
8. **Débrancher les pools étendus.** D’abord les retirer de `run_default`, ensuite du schéma si confirmé ; ne jamais supprimer les ressources dans la même étape.
9. **Retirer le HUD legacy.** Ferveur, Éveil, Réaction, Empreinte et glossaire après que la barre quatre slots est fonctionnelle.
10. **Retirer la logique legacy du runtime.** Façades de `Unit`, `EnergyGauge`, champs `Spell`, signaux `EventBus`, branches `SpellCaster/TerrainEffects`.
11. **Mettre à jour ou remplacer les tests legacy.** Les tests ne doivent être changés qu’une fois le nouveau contrat accepté.
12. **Quarantainer physiquement le contenu historique.** Déplacement ou exclusion d’accès dans un lot séparé, avec import et tests.
13. **Valider les DELETE_CANDIDATE.** Recherche UID, ouverture des scènes qui les référencent potentiellement, validation humaine, puis suppression dans une tâche dédiée.

## 10. Risques de régression

| Risque | Cause | Garde-fou recommandé |
|---|---|---|
| Plus aucun héros au combat | suppression du draft avant initialisation Elfe | test de `GameManager.start_run` jusqu’au déploiement |
| Elfe sans sort ou avec plus de 4 | `Unit.spells` est une liste ouverte | contrat de slots explicite |
| IA incapable de payer/caster | retrait global des coûts énergie touche aussi sorts ennemis | vérifier les 12 ennemis actifs et leurs 8 sorts |
| Régression dégâts/terrain | modification directe de `SpellCaster` pour la progression | garder progression hors résolution tactique |
| Visuel Elfe masqué | placeholder ISO ou fallback `UnitView` | test du `visual_scene` optionnel |
| Cast visuel bloquant | perte du signal `cast_release_reached` | conserver timeout et test autonome |
| Fin de run toujours bloquée | signaux sans consommateur | test victoire finale et défaite |
| Import cassé | ressources retirées avant les `ext_resource` de `run_default` | désérialiser d’abord le run minimal |
| Tests trompeusement verts | GUT retourne 0 malgré erreurs internes | analyser aussi `SCRIPT ERROR`/`Parse Error` dans la sortie |
| Écart local/CI | Godot 4.6.3 local contre 4.7 CI | aligner les versions dans un lot outillage |
| Modification accidentelle d’artefacts de test | runners Elfe écrivent PNG/JSON sous `tests/` | exécuter dans un worktree jetable ou rediriger les sorties dans une future tâche |
| Suppression de contenu manuel | zéro référence textuelle ne couvre pas l’usage éditeur | validation humaine séparée |

## 11. Tests actuels et résultats

### Commandes exécutées

Version :

```powershell
& 'C:\Users\paolo\Desktop\godot\Godot_v4.6.3-stable_win64_console.exe' --version
```

Import fiable, exécuté hors bac à sable pour permettre l’accès aux répertoires Godot sous `AppData` :

```powershell
& 'C:\Users\paolo\Desktop\godot\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --import
```

Suite GUT configurée :

```powershell
& 'C:\Users\paolo\Desktop\godot\Godot_v4.6.3-stable_win64_console.exe' --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://test/unit -ginclude_subdirs -gprefix=test_ -gexit
```

### Résultats

| Validation | Code | Résultat | Warnings / erreurs |
|---|---:|---|---|
| `--version` | 0 | `4.6.3.stable.official.7d41c59c4` | aucun |
| import headless fiable | 0 | import terminé, aucune erreur de parse projet | `WARNING: ObjectDB instances leaked at exit` |
| GUT | 0 | 13 scripts, 73 tests, 73 passants, 512 assertions, 1,556 s | avertissement de compatibilité GUT ; 2 scripts internes GUT en erreur de parse ; fuite ObjectDB ; 10 ressources encore utilisées |

Erreurs GUT exactes apparues **après** « All tests passed » :

- `res://addons/gut/godot_singletons.gd:5` : `Identifier "AccessibilityServer" not declared in the current scope.`
- `res://addons/gut/stub_params.gd:16` : `Cannot return value of type "null" because the function return type is "StringName".`

GUT affiche également :

```text
This version of GUT may not be compatible with Godot 4.6.3.
Consider changing to GUT 9.6.1.
```

**PROUVÉ** — Le code de sortie 0 ne reflète donc pas l’absence totale d’erreurs dans la sortie. La CI actuelle analyse les erreurs de parse pendant l’import, mais sa commande GUT ne filtre pas explicitement ces messages.

### Premier essai en bac à sable

Un premier import avec la même commande a retourné 0 mais n’a pas pu créer/lire les répertoires `AppData/Roaming/Godot` et `AppData/Local/Godot`. Il a produit des erreurs GUT induites par ces permissions. Ce résultat a été rejeté comme non fiable et la commande a été rejouée hors bac à sable ; seul le second résultat sert de validation projet.

### Runners non exécutés

Quatre scènes de validation Elfe existent hors du répertoire GUT configuré :

- `tests/characters/elf/ElfAnimationValidation.tscn` ;
- `tests/characters/elf/ElfInGamePreview.tscn` ;
- `tests/characters/elf/ElfVisualComponentValidation.tscn` ;
- `tests/characters/elf/ElfSalle1GameplayIntegration.tscn`.

Leurs modes automatiques sont identifiables par des arguments comme `--elf-auto-review`, `--elf-component-auto-test`, `--elf-preview-auto-review` et `--elf-salle1-auto-review`. **PROUVÉ** — ces modes appellent `save_png`, `FileAccess.WRITE` et/ou `DirAccess.make_dir_recursive_absolute` vers `res://tests/characters/elf/...`; ils peuvent écraser des captures suivies. Ils ne sont donc pas raisonnables dans une tâche qui interdit de modifier les tests et dont l’unique livrable doit être ce rapport.

### Couverture legacy à prévoir lors du reset

Tests directement liés à l’ancienne économie :

- `test_ap_costs.gd` : 7 tests ;
- `test_awakening.gd` : 6 ;
- `test_can_afford.gd` : 3 ;
- `test_energy_gauge_awakening.gd` : 6 ;
- `test_energy_gauge_gain.gd` : 6 ;
- `test_force_multiplier.gd` : 6 ;
- `test_gain_table.gd` : 5.

`test_gain_table.gd` charge explicitement Rage, Foi, Nature et Ombre et contient une assertion spécifique à la Foi. Ces 39 tests ne doivent pas être supprimés opportunément : ils devront être remplacés ou requalifiés dans le lot qui introduira le nouveau contrat de progression.

## 12. Proposition de lots de travail futurs

### Lot A — Contrat de tranche verticale

- Formaliser `DisciplineId` : Archer, Assassin, Mage, Soigneur.
- Définir XP, niveaux, choix d’amélioration et quatre slots.
- Définir précisément les quatre sorts initiaux.
- Décider si le moteur générique `Trait/SpellModifier` porte les améliorations.

### Lot B — Bootstrap Elfe

- Remplacer le draft par un démarrage Elfe unique.
- Conserver `UnitData → Unit` et `visual_scene`.
- Ajouter des tests de construction et de déploiement de l’Elfe.

### Lot C — Loadout et disciplines

- Introduire le modèle de disciplines et slots sans toucher au caster.
- Migrer `elfe.tres` hors des trois sorts Mage.
- Adapter ActionBar à quatre emplacements.

### Lot D — Progression après combat

- Remplacer `RewardData/RewardScreen` par les choix d’amélioration.
- Accorder XP par discipline au bon moment.
- Tester choix, refus, cap et persistance entre salles.

### Lot E — Run linéaire

- Construire une courte liste de `RoomData`.
- Ajouter les transitions terminales de victoire/défaite.
- Choisir explicitement quelles cartes et quels ennemis actifs sont conservés.

### Lot F — Retrait de l’économie legacy

- Retirer Éveil, Réaction, Empreinte et Ferveur du HUD.
- Retirer `EnergyGauge` et les façades de `Unit`.
- Retirer les champs legacy de `Spell/EnergyTypeData/EventBus/TerrainEffects`.
- Remplacer les 39 tests legacy par la couverture du nouveau contrat.

### Lot G — Quarantaine des contenus

- Rendre inaccessibles les six héros historiques, quatre écoles, traits de départ, châssis, rewards et pools étendus.
- Conserver d’abord les fichiers techniquement valides.
- Vérifier l’import après chaque famille.

### Lot H — Validation des suppressions

- Auditer séparément chaque `DELETE_CANDIDATE`, y compris les UID et usages manuels.
- Supprimer seulement après approbation.
- Ne pas mélanger ce lot avec les changements de gameplay.

## Conclusion

Le socle tactique demandé est déjà isolable et largement testé. Le principal obstacle n’est pas le moteur de combat, mais le fait que le flux actif, les ressources sérialisées, le HUD et une part importante des tests modélisent encore un jeu de trois héros à quatre écoles. L’Elfe dispose d’un pipeline visuel propre et générique à conserver, mais sa donnée de gameplay actuelle est un clone de loadout Mage sans discipline. La remise à zéro doit donc remplacer les frontières de run et de build avant de désactiver les ressources legacy.
