# Évolutions d’arbre pendant le combat

Date de validation : 2026-08-02  
Branche observée : `refactor/project-clean-slate`  
HEAD observé avant validation : `309a6cda9e00e8db0327ea3188d64a937a9b4673`

## Verdict

`IN_COMBAT_SKILL_EVOLUTION_COMPLETE_WITH_WARNINGS`

L’évolution est maintenant demandée et résolue dans le combat, uniquement à la fin sûre d’une action. Le seul avertissement est un échec GUT déjà présent et hors périmètre dans `test_dark_pause_menu.gd` : deux textures de focus du thème du menu pause sont nulles aux lignes 123-124. Aucun fichier du menu pause n’a été modifié.

## Audit du flux avant modification

1. `SpellCaster.begin_cast` validait la cible, collectait les `SpellModifier`, payait les PA et exécutait `on_costs_resolved`.
2. `SpellCaster.resolve_cast` résolvait, dans cet ordre : cibles et aire, impacts (dégâts, soins, boucliers et statuts), terrain, mouvements/poussées, journal et `on_cast_complete`.
3. `EventBus.spell_cast` était émis tout à la fin de `resolve_cast`, après le rapport complet (`core/spell_caster.gd`).
4. `GameManager._on_successful_spell_cast` transmettait le cast à `CharacterProgressionService.grant_cast_xp`. Le service retrouvait le `CharacterRunState` correspondant à l’instance exacte du lanceur et accordait +1 XP à la discipline du sort.
5. `DisciplineProgressState.add_xp` recalculait le rang et ajoutait chaque nouveau rang à `_pending_rank_choices`.
6. `Battle._finish_spell_resolution` rendait immédiatement le contrôle après `resolve_cast`; la mort émettait synchroniquement `unit_died`, puis `Battle._check_battle_end` pouvait terminer le combat avant qu’un choix nouvellement créé soit présenté.
7. Après victoire, `GameManager.on_battle_won` positionnait `_awaiting_post_battle_progression` et ouvrait `ProgressionChoiceScreen.tscn` tant qu’un choix restait en attente. La dernière confirmation appelait ensuite `_continue_after_progression`.
8. `SkillTreeScreen` recevait déjà un personnage et une discipline pour la consultation, mais pas une demande obligatoire `(personnage, discipline, rang)`; l’ancien choix post-combat passait par l’écran de progression séparé.

Les impacts, événements de mort, effets de terrain et mouvements du pipeline actuel sont synchrones dans `resolve_cast`. Les VFX différés passent par `SpellImpactScheduler`; les visuels de personnage éventuellement bloquants exposent `wait_for_action_visual_finished`. Aucun ordonnanceur asynchrone indépendant de « réaction » n’a été trouvé dans ce chemin.

## Nouveau flux exact

1. Le joueur lance un sort. `Battle` passe en `ANIMATING`, incrémente `trigger_sequence` et désactive les commandes.
2. `SpellCaster.begin_cast` valide et paie le coût. Un cast refusé ou annulé ne produit ni XP ni demande.
3. Le scheduler éventuel attend l’impact, puis `SpellCaster.resolve_cast` termine les cibles, impacts, statuts, terrain, mouvements, journal, hooks et rapport.
4. `EventBus.spell_cast` est émis. Le moteur existant accorde +1 XP et ajoute le rang franchi aux choix en attente.
5. `GameManager.discipline_xp_gained` fournit les rangs franchis; `Battle` crée une `EvolutionRequest` par rang et l’ajoute à la file FIFO dédupliquée.
6. `Battle._finish_spell_resolution` attend le visuel bloquant facultatif, puis une frame de nettoyage. Les morts et l’issue du combat ont donc déjà été observées. Ce point est le point sûr retenu.
7. Si la file n’est pas vide, le combat passe en `SKILL_EVOLUTION_PENDING`, affiche brièvement « ÉVOLUTION DISPONIBLE », puis en `SKILL_EVOLUTION_UI` lorsque l’arbre est ouvert.
8. `SkillTreeScreen.open_for_evolution` n’affiche que le personnage et la discipline demandés, cible le rang demandé, centre le premier choix valide et interdit fermeture, changement de discipline et sélection hors séquence.
9. La confirmation appelle `GameManager.choose_progression_upgrade`, donc `CharacterRunState.select_upgrade` et le vrai `SkillTreeResolver`.
10. `CharacterRunState` enregistre le choix et exécute `_sync_progression_modifiers_to_unit`. Le prochain `SpellCaster._gather_modifiers` du même combat lit immédiatement ces modificateurs.
11. La demande est retirée seulement après vérification que son rang n’est plus en attente. La demande suivante est traitée, puis le tour ou l’issue différée du combat reprend lorsque la file est vide.
12. `GameManager.on_battle_won` ne route plus vers un écran de progression. La présence résiduelle d’un choix est traitée comme une violation défensive et bloque la transition.

## Structure de la demande et ordre

`EvolutionRequest` contient exactement :

- `character_id`
- `discipline_id`
- `pending_rank`
- `source_spell_id`
- `trigger_sequence`
- `request_id`

`EvolutionRequestQueue` conserve l’ordre de création et déduplique sur `character_id:discipline_id:pending_rank`. Les demandes déjà persistées sont chargées au début du combat dans l’ordre héros, discipline, rang fourni par `GameManager.get_pending_progression_choices`. Pour une même discipline, les rangs restent croissants; le resolver interdit en plus tout contournement d’un rang inférieur.

## Verrouillage du combat

`TurnState` expose les états explicites `SKILL_EVOLUTION_PENDING` et `SKILL_EVOLUTION_UI`. Dans ces états :

- déplacement, attaque, sorts, fin de tour, sélection de case, plages, clic droit et raccourcis sont refusés;
- la barre d’action est désactivée et les surbrillances sont effacées;
- un début de tour ennemi est différé avant les statuts de début de tour et avant l’IA;
- victoire et défaite sont mémorisées, puis validées seulement après vidage de la file;
- le combat reste visible sous un assombrissement léger;
- le flux d’évolution n’utilise pas `Engine.time_scale` (le hit-stop historique de `battle/impact_juice.gd` reste inchangé).

Les commandes de caméra qui ne passent pas par les intentions de combat restent disponibles.

## Interface et feedback

Le `SkillTreeScreen` réel est réutilisé. Le mode évolution :

- fixe le personnage, la discipline et le rang;
- conserve l’inspection des nœuds de cette discipline;
- ne rend actionnables que les nœuds `AVAILABLE` du rang demandé;
- affiche les raisons de verrouillage, prérequis et exclusions déjà calculées par la présentation et le resolver;
- refuse explicitement un nœud invalide;
- neutralise bouton Fermer, `ui_cancel` et raccourci de fermeture;
- ferme l’écran uniquement après confirmation acceptée par le resolver.

Le feedback de 0,38 seconde réutilise le thème et l’emblème du HUD. Il affiche personnage, discipline, rang et « ÉVOLUTION DISPONIBLE ». Aucun son nouveau n’a été ajouté faute d’asset existant clairement approprié.

## Fichiers de cette implémentation

Créés :

- `battle/evolution_request.gd`
- `battle/evolution_request_queue.gd`
- `test/unit/test_in_combat_skill_evolution.gd`
- `tools/capture_in_combat_skill_evolution.gd`
- `tools/capture_in_combat_skill_evolution.tscn`
- ce rapport

Modifiés :

- `battle/battle.gd`
- `battle/turn_state.gd`
- `core/game_manager.gd`
- `ui/progression/components/skill_tree_node_detail_panel.gd`
- `ui/progression/screens/skill_tree_screen.gd`
- `ui/progression/screens/skill_tree_screen.tscn`
- `ui/progression/skill_tree_visual_state.gd`
- `ui/run/PersistentRunUI.tscn`
- `ui/run/persistent_run_ui.gd`
- `test/unit/test_elf_mage_progression_slice.gd`
- `test/unit/test_progression_lifecycle.gd`
- `test/unit/test_elf_multiple_progression_queue.gd`
- `test/unit/test_three_character_party_progression_queue.gd`

Les `.uid` générés pour les nouveaux scripts font partie de l’import Godot. Aucun fichier de StartHub, de cinématique, de récompense ou du menu pause n’a été modifié. `PersistentRunUI` refuse seulement d’ouvrir le menu pause pendant le choix obligatoire, ce qui fait partie du verrouillage des raccourcis demandé.

## Couverture automatisée

Suite dédiée `test_in_combat_skill_evolution.gd` : **13/13**, 240 assertions.

- FIFO, champs et déduplication des demandes;
- refus de toutes les intentions de combat pendant le verrou;
- seuil attendu après action complète;
- aucun écran pour cast refusé, annulé ou sans seuil;
- les 12 disciplines ouvrent chacune leurs deux choix R2 et synchronisent un vrai `SpellModifier` lu par le caster runtime;
- sélection invalide explicitement refusée;
- choix obligatoire, synchronisation immédiate et reprise correcte;
- victoire de dernière action différée;
- R2 puis R3 sans reprise intermédiaire;
- capstone R5 et reconstruction depuis snapshot;
- demandes anciennes, multi-disciplines et multi-personnages dans un ordre déterministe;
- IA suspendue avant statuts et exécution;
- choix de dernière action avant l’écran de victoire.

Régression ciblée arbres/progression/runtime/UI : **98/98**, 5 512 assertions.

- contrat complet des 12 arbres et 16 configurations par arbre;
- `SkillTreeResolver`, prérequis et exclusions;
- effets génériques réels des `SpellModifier`;
- interface responsive et révélation progressive;
- cycle de vie, persistance entre salles et files multi-héros;
- absence de choix post-combat.

GUT complet : **403/404**, 35 687/35 689 assertions. L’unique échec est `test_dark_pause_menu.gd::test_theme_uses_distinct_texture_states_and_focus_style`, lignes 123-124, déjà hors périmètre. Les suites StartHub (6/6), StartHub vertical slice (20/20) et cinématique passent dans le GUT complet.

Import Godot headless : succès. Les ressources et les onze captures ont été importées sans erreur de parsing.

## Captures

Répertoire : `artifacts/skill_trees/in_combat_captures/`

- `threshold_elf.png`
- `threshold_mage.png`
- `threshold_warrior.png`
- `focused_available_choice.png`
- `modifier_active_next_spell.png`
- `combat_resumed_after_choice.png`
- `last_action_choice_before_victory.png`
- `last_action_victory_after_choice.png`
- `resolution_1280x720.png`
- `resolution_1920x1080.png`
- `resolution_2560x1440.png`

Le contrôle visuel confirme le centrage du feedback, l’arbre focalisé, la fermeture obligatoire, le combat visible en arrière-plan et l’absence de débordement aux trois résolutions.

## État Git et limites

- Aucun `stage`, commit ou push n’a été effectué.
- L’index Git est vide.
- Le worktree contenait déjà les changements non stagés de l’implémentation des douze arbres; ils ont été conservés.
- `git diff --check` doit rester propre après l’ajout de ce rapport.
- Aucun second moteur de progression ni effet de nœud dans l’UI n’a été créé.
