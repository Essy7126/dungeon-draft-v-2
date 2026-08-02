# Nouvelle instance d’après-combat — rapport d’implémentation

Date de validation : 2 août 2026  
Verdict : `POST_COMBAT_REWARD_FLOW_COMPLETE_WITH_WARNINGS`

La boucle livrée est :

`Victoire → révélation → statistiques → progression récapitulative → récompense → salle suivante`

L’unique réserve finale est un échec préexistant et hors périmètre dans le menu pause. Le nouveau flux lui-même est validé.

## 1. Audit du flux de victoire

### Flux antérieur exact

1. `Unit._die()` émettait `EventBus.unit_died`.
2. `Battle._on_unit_died()` retirait l’unité de la grille et de la file des tours, puis appelait `_check_battle_end()`.
3. `_request_battle_outcome()` attendait déjà la fin de la résolution du sort et, depuis la passe d’évolution en combat, la résolution de toutes les `EvolutionRequest`.
4. `_end_battle()` verrouillait le combat, affichait le voile local de victoire et demandait à `GameManager.schedule_battle_outcome()` de terminer le délai.
5. `GameManager.on_battle_won()` validait la salle puis appelait directement `_go_to_next_room()`.
6. `_go_to_next_room()` chargeait `RoomTransitionScreen` ou le comportement final existant `RunResultScreen`.

Il n’existait donc aucun arrêt persistant entre la victoire et le changement de salle.

### Flux livré

1. Au démarrage du combat, `Battle._start_battle()` consomme d’abord l’éventuel bouclier différé, puis appelle `GameManager.begin_combat_report()`.
2. Le tracker prend le snapshot de progression initial et écoute les événements de gameplay réels.
3. La détection de victoire reste dans `Battle._check_battle_end()`.
4. La victoire reste différée tant qu’un sort, une réaction ou une `EvolutionRequest` n’est pas terminé.
5. `Battle._end_battle()` verrouille les intentions, nettoie les surbrillances et délègue le délai au `GameManager` persistant.
6. `GameManager.on_battle_won()` refuse encore la victoire si un choix d’évolution est pendant, finalise le rapport, émet `room_cleared` et `combat_report_ready`, puis ouvre `PostCombatScreen`.
7. `PostCombatScreen` ne modifie aucune progression. Il lit uniquement le rapport finalisé.
8. Une récompense proposée est sélectionnée, confirmée et appliquée exactement une fois.
9. L’écran effectue son fondu puis appelle `GameManager.complete_post_combat_transition(report_id)`.
10. Le `GameManager` charge alors `RoomTransitionScreen` ou, pour la dernière salle, conserve `RunResultScreen`.

### Disponibilité et durée de vie des données

- Les trois `CharacterRunState` et leurs `Unit` appartiennent au `GameManager` et restent disponibles entre les salles.
- La scène `Battle` peut être libérée après la victoire : le délai, le rapport final et la récompense sont possédés par le `GameManager` persistant.
- Le `CombatReport` final est conservé dans `_last_combat_report` pendant toute l’instance d’après-combat.
- Les snapshots avant/après sont des valeurs copiées, indépendantes des valeurs finales déjà présentes dans `CharacterRunState` lors du chargement de l’écran.
- `cleanup_run_state()` déconnecte ou réinitialise le tracker, le rapport, le service de récompenses, la garde de transition et les boucliers différés.
- Le bonus de PV maximum est un modificateur `Stat` de la run et disparaît avec les unités lors du nettoyage de celle-ci.

### Références anciennes

- Aucune référence à un ancien `RewardScreen`, inventaire, monnaie, boutique ou économie n’est présente dans ce nouveau chemin.
- `ProgressionChoiceScreen`, sa constante et quelques API/tests de compatibilité existent encore dans le dépôt, mais la victoire ne route jamais vers cet écran.
- Aucun arbre n’est ouvert par `PostCombatScreen` et aucun choix n’est demandé après le combat.

## 2. Architecture de CombatReport

### Modèles indépendants de l’interface

- `CombatReport` : identité du rapport, salle, dates, résultat, liste des trois rapports de héros et résultat de récompense.
- `CharacterCombatReport` : agrégats de combat, usages de sorts et progression d’un héros.
- `DisciplineProgressDelta` : valeurs XP/rang avant et après, seuil suivant, seuils franchis et nœuds acquis pour une discipline.
- `CombatReportTracker` : seul composant de collecte. Il s’abonne au début du combat et se désabonne à la finalisation ou à l’abandon.

Le rapport contient toujours les trois héros et les douze disciplines, y compris lorsqu’un héros ou une discipline n’a produit aucune action.

### Statistiques suivies et sémantique

| Statistique | Source réelle | Sémantique |
|---|---|---|
| Dégâts infligés | `EventBus.damage_dealt` | Dégâts résolus après mitigation, avant absorption de bouclier ; le montant d’un coup fatal n’est pas tronqué aux PV restants. |
| Dégâts subis | `EventBus.health_damage_taken` | Perte réelle de PV après bouclier, plafonnée aux PV disponibles. |
| Soins | `EventBus.healing_applied` | Soin réellement reçu après plafond de PV, attribué à la source. |
| Bouclier appliqué | `EventBus.shield_applied` | Gain réel de bouclier après la règle de remplacement, attribué à la source. |
| Éliminations | `EventBus.unit_killed` | Mort réelle attribuée au tueur ; garde d’idempotence de `Unit._die()`. |
| Sorts lancés | `EventBus.spell_cast` | Un cast réussi vaut un, même si un sort de zone touche plusieurs cibles. |
| Sorts par ID | `Spell.get_effective_spell_id()` | Compteur stable par identifiant de sort. |
| Cases parcourues | `Unit.moved(from, to)` | Distance de Manhattan réellement annoncée par l’unité. |

Les signaux historiques restent en place. Trois signaux supplémentaires et compatibles ont été ajoutés pour conserver la source et le montant réel des soins, boucliers et morts : `healing_applied`, `shield_applied` et `unit_killed`.

### Snapshots de progression

Au début du combat, le tracker copie pour chaque discipline :

- XP ;
- rang ;
- liste des `upgrade_id` déjà sélectionnés.

À la victoire, il relit les douze `DisciplineProgressState`, calcule les rangs franchis et soustrait les identifiants déjà présents. Chaque nouveau nœud conserve son ID, son libellé, sa description et son rang. L’interface anime exclusivement ces deltas ; elle n’accorde ni XP ni nœud.

## 3. Séquence visuelle

La scène `res://ui/post_combat/PostCombatScreen.tscn` utilise les états demandés :

| État | Contenu et interaction |
|---|---|
| `VICTORY_REVEAL` | Fond réel de la salle assombri, impact « VICTOIRE », nom de salle, animation courte et SFX existant. |
| `COMBAT_STATS` | Trois cartes, visuels réels des héros, sept statistiques essentielles et révélation courte. |
| `PROGRESSION` | Trois panneaux, quatre disciplines par héros, jauges depuis `xp_before`, pauses aux seuils, rangs et nœuds acquis. Aucun choix. |
| `REWARD_SELECTION` | Trois cartes, aucune présélection, navigation clavier/souris/manette, sélection unique et confirmation explicite. |
| `COMPLETED` | Récompense enregistrée ; les autres cartes sont inactives. |
| `TRANSITIONING` | Verrouillage, fondu puis demande de salle suivante au `GameManager`. |

Rythme du skip : le premier appui termine l’animation courante et force toutes les valeurs finales ; l’appui suivant avance de phase. Une génération de séquence invalide les anciennes coroutines et empêche un tween ou un timer terminé tardivement de modifier le nouvel état.

La direction artistique réutilise le thème des arbres, les cadres dark fantasy, les icônes existantes, le fond de salle et `CharacterPreview3D`. Le SFX court réutilisé est `res://asset/bruitage sort/MUSCPerc_Triangle 3 (ID 1689)_LaSonotheque.fr.mp3`.

## 4. Récompenses V1

`PostCombatRewardData` est une ressource data-driven avec `reward_id`, `display_name`, `description`, `icon`, `reward_type`, `value` et `target_policy`. `PostCombatRewardService` est isolé de l’interface.

| Récompense | Valeur | Cible | Application |
|---|---:|---|---|
| Souffle réparateur | 20 % | Tous les héros vivants | Soin arrondi, minimum un, plafonné aux PV maximum. |
| Vigueur durable | +10 PV | Un héros explicitement nommé sur la carte | Modificateur `Stat.FLAT` persistant pour la run et soin immédiat de 10, plafonné. |
| Égide du prochain seuil | 6 bouclier | Tous les héros vivants | Stockage temporaire par `character_id`, application au début du combat suivant puis consommation. |

Les trois propositions sont déterministes : soin d’équipe, bonus de PV ciblé sur un héros vivant choisi par index de salle, puis bouclier d’équipe. Cette stratégie rend les tests reproductibles et garde le point d’extension ouvert pour un futur tirage pseudo-aléatoire.

### Protections d’intégrité

- Le service indexe les applications par `report_id` : une seconde application renvoie `REWARD_ALREADY_APPLIED`.
- Le `GameManager` revalide le couple `reward_id`/`target_character_id` contre les options réellement offertes.
- Le bonus de PV utilise une source de modificateur unique au rapport.
- Le bouclier différé utilise une politique `max`, pas une somme, puis efface chaque entrée lors de sa consommation.
- `complete_post_combat_transition()` exige un rapport identique, un résultat réussi et la preuve d’application dans le service.
- Une garde distincte bloque une seconde transition.
- Une erreur conserve `REWARD_SELECTION`, affiche un message contrôlé et interdit le passage à la salle suivante.

## 5. Validation

### Tests dédiés

Commande GUT ciblée sur `res://test/unit/test_post_combat_flow.gd` :

- 15/15 tests passés ;
- 152 assertions passées.

Couverture : événements réels, dégâts, soins, boucliers, mort, déplacement, cast simple/zone/répété, héros inactif, snapshots, douze disciplines, zéro XP, plusieurs seuils, plusieurs héros, nœuds acquis, skip, trois récompenses, persistance, consommation, idempotence, erreur contrôlée, transition et trois résolutions.

### Faisceau progression/transition

- 92/92 tests passés ;
- 1 031 assertions passées lors de la passe ciblée avant l’ajout des deux tests finaux.

### Suite GUT complète finale

- 46 scripts ;
- 419 tests ;
- 418 tests passés ;
- 1 test échoué ;
- 35 853/35 855 assertions passées.

L’unique échec est `res://test/unit/test_dark_pause_menu.gd::test_theme_uses_distinct_texture_states_and_focus_style`, lignes 123–124 : deux textures de focus sont `null`. Cet échec était déjà présent dans la baseline (403/404 avant cette tâche) et le menu pause est explicitement hors périmètre.

Résultats complémentaires dans la suite complète :

- StartHub : 26/26 tests passés sur ses deux scripts ;
- cinématique d’introduction : tests passés, y compris les chemins d’erreur attendus ;
- arbres et résolveur : tests passés ;
- combat et progression : tests passés ;
- aucun nouvel échec introduit.

L’import Godot headless final termine avec un code 0. `git diff --check` termine également avec un code 0 et l’index Git est vide.

Les avertissements de ressources/RID encore utilisées à la sortie sont produits par le runner headless global et existaient déjà ; ils ne correspondent pas à un échec fonctionnel de ce flux.

## 6. Captures

Les fichiers sont sous `res://artifacts/post_combat/captures/` :

- `victory_reveal.png` ;
- `combat_stats.png` ;
- `progression_before.png` ;
- `progression_animating.png` ;
- `progression_threshold.png` ;
- `progression_acquired_node.png` ;
- `reward_three_cards.png` ;
- `reward_selected.png` ;
- `transition_next_room.png` ;
- `resolution_1280x720.png` ;
- `resolution_1920x1080.png` ;
- `resolution_2560x1440.png`.

Le confinement des cartes dans le panneau sûr aux trois résolutions est également testé automatiquement.

## 7. Fichiers de cette passe

### Créés

- `battle/reporting/character_combat_report.gd`
- `battle/reporting/combat_report.gd`
- `battle/reporting/combat_report_tracker.gd`
- `battle/reporting/discipline_progress_delta.gd`
- `data/post_combat/post_combat_reward_data.gd`
- `data/post_combat/post_combat_reward_service.gd`
- `data/post_combat/rewards/team_heal_percent.tres`
- `data/post_combat/rewards/hero_max_hp.tres`
- `data/post_combat/rewards/next_combat_shield.tres`
- `ui/post_combat/PostCombatScreen.tscn`
- `ui/post_combat/post_combat_screen.gd`
- `test/unit/test_post_combat_flow.gd`
- `tools/capture_post_combat_flow.gd`
- `tools/capture_post_combat_flow.tscn`
- les captures listées ci-dessus et les sidecars `.uid` générés par Godot
- ce rapport

### Modifiés pour l’intégration

- `battle/battle.gd`
- `core/event_bus.gd`
- `core/game_manager.gd`
- `core/spell_caster.gd`
- `core/spell_mods/spell_mod_skill_tree_effect.gd`
- `units/unit.gd`
- `test/unit/test_elf_mage_progression_slice.gd`
- `test/unit/test_elf_multiple_progression_queue.gd`
- `test/unit/test_three_character_party_progression_queue.gd`

Les trois tests existants ont seulement été migrés de l’attente « salle suivante immédiate » vers « écran d’après-combat, récompense confirmée, puis salle suivante ».

### Explicitement non modifiés par cette passe

- StartHub ;
- cinématique d’introduction ;
- données et interface des douze arbres ;
- menu pause ;
- `first_run.tres` ;
- ancien inventaire, monnaie, économie, équipement ou boutique.

Le worktree contenait déjà de nombreux changements non indexés issus des tâches précédentes et parallèles sur le hub, la cinématique et les arbres. Ils ont été conservés sans nettoyage ni écrasement.

## 8. Point d’extension de fin de run

Après la récompense de la dernière salle, `complete_post_combat_transition()` appelle le chemin existant `_go_to_next_room()`, lequel aboutit à `_finish_run(true)` et `RunResultScreen`. Un futur écran final pourra s’insérer à ce point, sans modifier le rapport de combat, le service de récompenses ni le flux des salles intermédiaires.

## 9. État Git

- Aucun fichier stagé par cette tâche.
- Aucun commit.
- Aucun push.
- Le worktree reste volontairement sale afin de préserver les travaux en cours des autres tâches.

## Verdict

`POST_COMBAT_REWARD_FLOW_COMPLETE_WITH_WARNINGS`

Réserve unique : échec préexistant du test de texture de focus du menu pause, hors périmètre de cette implémentation.
