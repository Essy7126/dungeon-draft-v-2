# core/game_manager.gd
# ============================================================
# GAME MANAGER — Chef d'orchestre du RUN (autoload/singleton).
#
# RESPONSABILITÉ : transporter l'état du run d'une salle à l'autre.
#   - possède les héros (et donc leurs HP qui persistent : pas de regen)
#   - connaît la liste des salles et l'avancement
#   - enchaîne les combats
#   - distribue les récompenses entre les salles
#
# CE QU'IL NE FAIT PAS (volontairement) :
#   - il ne calcule aucun combat (ça reste dans battle.gd)
#   - il ne stocke aucun état local de combat (turn_queue, highlights...)
# On garde ce manager "boring" : il transporte, il ne joue pas.
# ============================================================
extends Node

# --- Configuration du run ---
# Options disponibles dans l'ecran de draft. Le build appartient au run,
# pas au combat : les batailles recoivent des heros deja configures.
const GUARDIAN_DATA_PATH := "res://data/units/alliés/Gardien.tres"
const WARRIOR_DATA_PATH := "res://data/units/alliés/Guerrier.tres"
const ELF_DATA_PATH := "res://data/units/alliés/elfe.tres"
const MAGE_DATA_PATH := "res://data/units/alliés/mage.tres"

const HERO_DATA_PATHS = [
	GUARDIAN_DATA_PATH,
	WARRIOR_DATA_PATH,
	"res://data/units/alliés/healer.tres",
	"res://data/units/alliés/Assassin.tres",
	"res://data/units/alliés/Necromant.tres",
	"res://data/units/alliés/Hoplite.tres",
	ELF_DATA_PATH,
]

const ENERGY_DATA_PATHS = [
	"res://data/energy/rage.tres",
	"res://data/energy/foi.tres",
	"res://data/energy/nature.tres",
	"res://data/energy/ombre.tres",
]

const STARTING_TRAIT_PATHS = [
	"res://data/traits/depart_etincelle_flux.tres",
	"res://data/traits/depart_posture_defensive.tres",
	"res://data/traits/depart_sang_vif.tres",
	"res://data/traits/depart_instinct_tactique.tres",
]

const DEFAULT_DRAFT = [
	{ "hero_path": GUARDIAN_DATA_PATH, "energy_path": "res://data/energy/foi.tres", "trait_path": "res://data/traits/depart_posture_defensive.tres" },
	{ "hero_path": WARRIOR_DATA_PATH, "energy_path": "res://data/energy/rage.tres", "trait_path": "res://data/traits/depart_etincelle_flux.tres" },
	{ "hero_path": "res://data/units/alliés/healer.tres", "energy_path": "res://data/energy/nature.tres", "trait_path": "res://data/traits/depart_instinct_tactique.tres" },
]

const RUN_DRAFT_SCREEN_PATH := "res://ui/RunDraftScreen.tscn"
const RUN_RESULT_SCREEN_PATH := "res://ui/RunResultScreen.tscn"
const TITLE_SCREEN_PATH := "res://ui/TitreEcran.tscn"
const PROGRESSION_CHOICE_SCREEN_PATH := "res://ui/progression/ProgressionChoiceScreen.tscn"
const REWARD_SCREEN_PATH := "res://ui/RewardScreen.tscn"
const ROOM_TRANSITION_SCREEN_PATH := "res://ui/Transitionsalle.tscn"
const FIRST_REWARD_PATH := "res://data/rewards/reward_marteau_jugement.tres"
const PERSISTENT_RUN_UI_SCENE := preload("res://ui/run/PersistentRunUI.tscn")
const PersistentRunUIScript := preload("res://ui/run/persistent_run_ui.gd")

# Nombre de récompenses proposées après chaque salle.
const REWARDS_OFFERED := 3

# --- État du run (vivant pendant tout le run) ---
var heroes: Array = []          # Array[Unit] — persistent, HP conservés
var character_states: Dictionary = {} # StringName -> CharacterRunState
var rooms: Array = []           # Array[RoomData]
var reward_pool: Array = []     # Array[RewardData]
var current_room_index: int = -1
var run_active: bool = false
var _pending_run_data: RunData = null
var _active_run_name: String = ""
var _last_run_result: Dictionary = {}
var _awaiting_post_battle_progression: bool = false
var _room_outcome_resolved: bool = false
var _active_progression_screen_ref: WeakRef = null
var _progression_service := CharacterProgressionService.new()
var _persistent_run_ui: PersistentRunUI = null
var _battle_outcome_generation := 0
var _battle_outcome_pending := false

# Récompenses actuellement proposées (lues par l'écran de récompense).
var _offered_rewards: Array = []

# --- Signaux (pour que l'UI réagisse sans couplage direct) ---
signal run_won
signal run_lost
signal room_cleared(index)
signal discipline_xp_gained(character_id, discipline_id, amount, snapshot)
signal scene_change_requested(path)


func _ready() -> void:
	_connect_progression_service()


func _connect_progression_service() -> void:
	var callback := Callable(self, "_on_successful_spell_cast")
	if not EventBus.spell_cast.is_connected(callback):
		EventBus.spell_cast.connect(callback)


func _exit_tree() -> void:
	_disconnect_progression_service()


func _disconnect_progression_service() -> void:
	var callback := Callable(self, "_on_successful_spell_cast")
	if EventBus.spell_cast.is_connected(callback):
		EventBus.spell_cast.disconnect(callback)


func is_progression_service_connected() -> bool:
	return EventBus.spell_cast.is_connected(
		Callable(self, "_on_successful_spell_cast")
	)

# ============================================================
# DÉMARRAGE D'UN RUN
# ============================================================

func start_run(run_data: RunData) -> void:
	if run_data == null:
		push_error("Aucun RunData fourni.")
		return
	cleanup_run_state()
	_pending_run_data = run_data
	_request_scene_change(RUN_DRAFT_SCREEN_PATH)

## Lance un run deja configure sans passer par le draft historique.
## `hero_sources` accepte des chemins res:// vers des UnitData ou des UnitData.
func start_preconfigured_run(run_data: RunData, hero_sources: Array) -> void:
	if not _prepare_preconfigured_run(run_data, hero_sources):
		return
	_go_to_next_room()

func confirm_run_draft(hero_paths: Array, energy_paths: Array, trait_paths: Array = []) -> void:
	if _pending_run_data == null:
		push_error("Aucun RunData en attente pour le draft.")
		return
	var run_data := _pending_run_data
	_pending_run_data = null
	if not _build_heroes_from_draft(hero_paths, energy_paths, trait_paths):
		cleanup_run_state()
		return
	_initialize_run_state(run_data)
	_go_to_next_room()

## Prepare l'etat sans changer de scene. Separe de start_preconfigured_run pour
## garder la construction testable sans dependre d'une transition graphique.
func _prepare_preconfigured_run(run_data: RunData, hero_sources: Array) -> bool:
	if run_data == null:
		push_error("Aucun RunData fourni pour le run preconfigure.")
		return false
	if hero_sources.is_empty():
		push_error("Aucun heros fourni pour le run preconfigure.")
		return false

	var hero_data_list: Array[UnitData] = []
	var requested_ids := {}
	for source in hero_sources:
		var data := _resolve_unit_data(source)
		if data == null:
			push_error("UnitData preconfigure invalide : %s" % str(source))
			return false
		var character_id := data.get_effective_unit_id()
		if not _is_valid_character_id(character_id):
			push_error("Identifiant de personnage preconfigure invalide : %s" % character_id)
			return false
		if requested_ids.has(character_id):
			push_error("Identifiant de personnage duplique : %s" % character_id)
			return false
		requested_ids[character_id] = true
		hero_data_list.append(data)

	# La nouvelle equipe est entierement construite hors de l'etat courant.
	# Ainsi, meme un echec inattendu d'initialisation preserve la run precedente
	# et ne laisse aucun personnage partiellement rattache au manager.
	var prepared_heroes: Array[Unit] = []
	var prepared_states: Dictionary = {}
	for data in hero_data_list:
		var hero := Unit.from_data(data)
		# Unit.from_data conserve l'energy_type et les traits propres au UnitData.
		# Aucun choix d'ecole ou trait de draft n'est applique sur cette voie.
		hero.reset_combat_resources()
		var character_state := CharacterRunState.new()
		if not character_state.initialize(hero, data, data.active_spell_slots):
			push_error("Impossible d'initialiser l'etat du personnage : %s" % hero.unit_id)
			_dispose_prepared_characters(prepared_heroes, prepared_states)
			hero.clear_traits()
			return false
		prepared_heroes.append(hero)
		prepared_states[character_state.character_id] = character_state

	cleanup_run_state()
	heroes.assign(prepared_heroes)
	character_states.assign(prepared_states)
	_initialize_run_state(run_data)
	return true

func _resolve_unit_data(source) -> UnitData:
	if source is UnitData:
		return source
	if source is String or source is StringName:
		return load(str(source)) as UnitData
	return null


func _is_valid_character_id(character_id: StringName) -> bool:
	var normalized := str(character_id).strip_edges()
	return normalized != "" and normalized != "unit_data:unassigned"


func _dispose_prepared_characters(
		prepared_heroes: Array[Unit],
		prepared_states: Dictionary
	) -> void:
	for state_value in prepared_states.values():
		var state := state_value as CharacterRunState
		if state != null:
			state.dispose()
	for hero in prepared_heroes:
		if hero != null:
			hero.clear_progression_spell_modifiers()
			hero.clear_traits()
	prepared_heroes.clear()
	prepared_states.clear()

func _initialize_run_state(run_data: RunData) -> void:
	rooms = run_data.rooms.duplicate()
	reward_pool = run_data.reward_pool.duplicate()
	current_room_index = -1
	run_active = true
	_active_run_name = run_data.run_name
	_last_run_result = {}
	_offered_rewards = []
	_awaiting_post_battle_progression = false
	_room_outcome_resolved = false
	_battle_outcome_generation += 1
	_battle_outcome_pending = false
	_active_progression_screen_ref = null
	_ensure_persistent_run_ui()
	set_run_ui_mode(PersistentRunUIScript.RunUIMode.TRANSITION)

func cancel_run_draft() -> void:
	cleanup_run_state()
	_request_scene_change(TITLE_SCREEN_PATH)

func get_fervor_multiplier() -> float:
	return 1.0

func get_charge_multiplier() -> float:
	return get_fervor_multiplier()

func get_default_draft() -> Array:
	return DEFAULT_DRAFT.duplicate(true)

func get_draft_hero_options() -> Array:
	return _load_draft_options(HERO_DATA_PATHS)

func get_draft_energy_options() -> Array:
	return _load_draft_options(ENERGY_DATA_PATHS)

func get_draft_trait_options() -> Array:
	return _load_draft_options(STARTING_TRAIT_PATHS)

func _load_draft_options(paths: Array) -> Array:
	var options: Array = []
	for path in paths:
		var data = load(path)
		if data == null:
			push_warning("Option de draft introuvable : %s" % path)
			continue
		options.append({ "path": path, "data": data })
	return options

# Cree les heros UNE fois pour tout le run, depuis le draft.
func _build_heroes_from_draft(
		hero_paths: Array,
		energy_paths: Array,
		trait_paths: Array = []
	) -> bool:
	cleanup_run_state()
	for i in range(hero_paths.size()):
		var path: String = hero_paths[i]
		var data = load(path)
		if data == null:
			push_error("Heros introuvable : %s" % path)
			cleanup_run_state()
			return false
		var hero := Unit.from_data(data)
		if i < energy_paths.size():
			var energy = load(energy_paths[i]) as EnergyTypeData
			if energy != null:
				hero.energy_type = energy
				hero.current_energy = energy.start_energy
		if i < trait_paths.size():
			var trait_path: String = trait_paths[i]
			if trait_path != "":
				var starting_trait = load(trait_path) as TraitData
				if starting_trait != null:
					hero.add_trait_from_data(starting_trait)
				else:
					push_warning("Trait de depart introuvable : %s" % trait_path)
		hero.ensure_energy_traits()
		hero.reset_combat_resources()
		heroes.append(hero)
	return not heroes.is_empty()

func _clear_heroes() -> void:
	for state_value in character_states.values():
		var state := state_value as CharacterRunState
		if state != null:
			state.dispose()
	for hero in heroes:
		if hero == null:
			continue
		hero.clear_progression_spell_modifiers()
		if hero.has_method("clear_traits"):
			hero.clear_traits()
	heroes.clear()
	character_states.clear()


func cleanup_run_state() -> void:
	_battle_outcome_generation += 1
	_battle_outcome_pending = false
	_release_persistent_run_ui()
	_close_active_progression_screen()
	_awaiting_post_battle_progression = false
	_room_outcome_resolved = false
	_pending_run_data = null
	_offered_rewards.clear()
	run_active = false
	current_room_index = -1
	_clear_heroes()
	rooms.clear()
	reward_pool.clear()
	_active_run_name = ""
	_last_run_result.clear()


func _ensure_persistent_run_ui() -> PersistentRunUI:
	if is_instance_valid(_persistent_run_ui):
		return _persistent_run_ui
	_persistent_run_ui = PERSISTENT_RUN_UI_SCENE.instantiate() as PersistentRunUI
	if _persistent_run_ui == null:
		push_error("Impossible d'instancier l'interface persistante de run.")
		return null
	add_child(_persistent_run_ui)
	return _persistent_run_ui


func _release_persistent_run_ui() -> void:
	if not is_instance_valid(_persistent_run_ui):
		_persistent_run_ui = null
		return
	_persistent_run_ui.unbind_combat_context()
	if _persistent_run_ui.get_parent() != null:
		_persistent_run_ui.get_parent().remove_child(_persistent_run_ui)
	_persistent_run_ui.free()
	_persistent_run_ui = null


func has_persistent_run_ui() -> bool:
	return run_active and is_instance_valid(_persistent_run_ui)


func get_persistent_run_ui() -> PersistentRunUI:
	return _persistent_run_ui if is_instance_valid(_persistent_run_ui) else null


func bind_combat_context(context: Node) -> CanvasLayer:
	if not run_active or context == null:
		return null
	var run_ui := _ensure_persistent_run_ui()
	if run_ui == null:
		return null
	return run_ui.bind_combat_context(context)


func unbind_combat_context(expected_context: Node = null) -> void:
	if is_instance_valid(_persistent_run_ui):
		_persistent_run_ui.unbind_combat_context(expected_context)


func set_run_ui_mode(mode: PersistentRunUI.RunUIMode) -> void:
	if is_instance_valid(_persistent_run_ui):
		_persistent_run_ui.set_ui_mode(mode)


func get_run_ui_mode() -> PersistentRunUI.RunUIMode:
	if is_instance_valid(_persistent_run_ui):
		return _persistent_run_ui.get_ui_mode()
	return PersistentRunUIScript.RunUIMode.NON_COMBAT

func get_character_state(character_id: StringName) -> CharacterRunState:
	return character_states.get(character_id) as CharacterRunState


## Retrouve l'etat par l'identite runtime exacte de l'unite, jamais par son nom.
func get_character_state_for_unit(unit: Unit) -> CharacterRunState:
	if unit == null:
		return null
	for state_value in character_states.values():
		var state := state_value as CharacterRunState
		if state != null and state.unit == unit:
			return state
	return null


## Vue defensive des heros dans l'ordre de la composition.
func get_ordered_heroes() -> Array[Unit]:
	var ordered: Array[Unit] = []
	for hero in heroes:
		if hero is Unit:
			ordered.append(hero)
	return ordered


## Etats ordonnes par composition, avec rattachement par identite runtime.
func get_ordered_character_states() -> Array[CharacterRunState]:
	var ordered: Array[CharacterRunState] = []
	for hero in heroes:
		var state := get_character_state_for_unit(hero as Unit)
		if state != null:
			ordered.append(state)
	return ordered


func _on_successful_spell_cast(caster, spell, report: Dictionary) -> void:
	var result := _progression_service.grant_cast_xp(
		character_states,
		caster as Unit,
		spell as Spell,
		report
	)
	if result.is_empty():
		return
	var character_id: StringName = result["character_id"]
	var discipline_id: StringName = result["discipline_id"]
	var amount: int = result["gained_xp"]
	discipline_xp_gained.emit(character_id, discipline_id, amount, result.duplicate(true))
	DebugLogger.info(
		DebugLogger.LogCategory.COMBAT,
		"+%d XP %s" % [amount, result["discipline_display_name"]],
		{
			"personnage": caster.unit_name,
			"xp": result["xp"],
			"rang": result["rank"],
			"prochain_seuil": result["next_required_total_xp"],
		}
	)


func get_pending_progression_choices() -> Array[Dictionary]:
	var pending: Array[Dictionary] = []
	for state in get_ordered_character_states():
		pending.append_array(state.get_pending_progression_choices())
	return pending


func get_next_pending_progression_choice() -> Dictionary:
	var pending := get_pending_progression_choices()
	return pending[0].duplicate(true) if not pending.is_empty() else {}


func has_pending_progression_choices() -> bool:
	return not get_next_pending_progression_choice().is_empty()


func register_progression_screen(screen: Control) -> bool:
	if screen == null:
		return false
	var active := get_active_progression_screen()
	if active != null and active != screen:
		return false
	_active_progression_screen_ref = weakref(screen)
	return true


func unregister_progression_screen(screen: Control) -> void:
	if get_active_progression_screen() == screen:
		_active_progression_screen_ref = null


func get_active_progression_screen() -> Control:
	if _active_progression_screen_ref == null:
		return null
	var screen := _active_progression_screen_ref.get_ref() as Control
	if screen == null:
		_active_progression_screen_ref = null
	return screen


func has_active_progression_screen() -> bool:
	return get_active_progression_screen() != null


func _close_active_progression_screen() -> void:
	var screen := get_active_progression_screen()
	_active_progression_screen_ref = null
	if screen == null:
		return
	if screen.has_method("close_for_run_cleanup"):
		screen.close_for_run_cleanup()
	elif screen.is_inside_tree():
		screen.queue_free()

# ============================================================
# PROGRESSION ENTRE LES SALLES
# ============================================================

# Passe à la salle suivante, ou termine le run s'il n'y en a plus.
func _go_to_next_room() -> void:
	unbind_combat_context()
	set_run_ui_mode(PersistentRunUIScript.RunUIMode.TRANSITION)
	current_room_index += 1
	# Plus de salle = run gagné.
	if current_room_index >= rooms.size():
		_finish_run(true)
		return
	# On (re)charge l'écran de transition pour la nouvelle salle.
	_request_scene_change(
		ROOM_TRANSITION_SCREEN_PATH,
		PersistentRunUIScript.RunUIMode.TRANSITION
	)

# Appelé par Transitionsalle au clic sur "Continuer".
func start_next_battle() -> void:
	var room = get_current_room()
	if room == null or room.battle_scene == null:
		push_error("Aucune battle_scene assignée dans RoomData index %d" % current_room_index)
		return
	_room_outcome_resolved = false
	unbind_combat_context()
	set_run_ui_mode(PersistentRunUIScript.RunUIMode.TRANSITION)
	get_tree().change_scene_to_packed.call_deferred(room.battle_scene)

# La salle en cours (lue par battle au démarrage).
func get_current_room() -> RoomData:
	if current_room_index < 0 or current_room_index >= rooms.size():
		return null
	return rooms[current_room_index]

# ============================================================
# FIN DE COMBAT
# ============================================================

# Le délai d'écran de victoire appartient au GameManager persistant, jamais à
# la Battle qui va être retirée de l'arbre. Une génération annule proprement
# le délai si la run est nettoyée ou remplacée entre-temps.
func schedule_battle_outcome(victory: bool, delay_seconds: float) -> void:
	if not run_active or _room_outcome_resolved or _battle_outcome_pending:
		return
	_battle_outcome_pending = true
	_battle_outcome_generation += 1
	var generation := _battle_outcome_generation
	_complete_battle_outcome_after_delay(victory, delay_seconds, generation)


func _complete_battle_outcome_after_delay(
	victory: bool,
	delay_seconds: float,
	generation: int
	) -> void:
	if not is_inside_tree():
		return
	var tree := get_tree()
	if tree == null:
		return
	if delay_seconds > 0.0:
		await tree.create_timer(delay_seconds).timeout
	if not is_inside_tree() \
			or generation != _battle_outcome_generation \
			or not run_active:
		return
	_battle_outcome_pending = false
	if victory:
		on_battle_won()
	else:
		on_battle_lost()

# Appelé par battle quand le joueur GAGNE le combat.
func on_battle_won() -> void:
	if not run_active or _room_outcome_resolved:
		return
	_room_outcome_resolved = true
	room_cleared.emit(current_room_index)
	_awaiting_post_battle_progression = true
	if has_pending_progression_choices():
		_request_scene_change(PROGRESSION_CHOICE_SCREEN_PATH)
		return
	_awaiting_post_battle_progression = false
	_continue_after_progression()


func _continue_after_progression() -> void:
	var has_next = current_room_index + 1 < rooms.size()
	if not has_next:
		_go_to_next_room()
		return

	_offered_rewards = _build_reward_offer()
	if _offered_rewards.is_empty():
		_go_to_next_room()
		return

	_request_scene_change(REWARD_SCREEN_PATH)


func choose_progression_upgrade(
		character_id: StringName,
		discipline_id: StringName,
		choice_rank: int,
		upgrade_id: StringName
	) -> bool:
	var state := get_character_state(character_id)
	if state == null or not state.select_upgrade(discipline_id, choice_rank, upgrade_id):
		return false
	if _awaiting_post_battle_progression and not has_pending_progression_choices():
		_awaiting_post_battle_progression = false
		_continue_after_progression()
	return true

# Appelé par battle quand le joueur PERD le combat.
func on_battle_lost() -> void:
	if not run_active or _room_outcome_resolved:
		return
	_room_outcome_resolved = true
	_finish_run(false)

# ============================================================
# RÉCOMPENSES
# ============================================================

func _build_reward_offer() -> Array:
	# Un run sans pool de récompenses ne doit jamais ouvrir RewardScreen,
	# y compris dans la première salle qui possède une récompense forcée.
	if reward_pool.is_empty():
		return []
	var forced_reward = _get_forced_reward_for_room(current_room_index)
	if forced_reward != null:
		var offer: Array = [forced_reward]
		offer.append_array(_draw_rewards(REWARDS_OFFERED - 1, [forced_reward]))
		return offer
	return _draw_rewards(REWARDS_OFFERED)

# Tire `count` récompenses au hasard dans le pool (sans doublon).
func _draw_rewards(count: int, excluded: Array = []) -> Array:
	var excluded_paths := {}
	for reward in excluded:
		if reward != null:
			excluded_paths[_resource_path_key(reward)] = true

	var pool: Array = []
	for reward in reward_pool:
		if reward == null:
			continue
		if excluded_paths.has(_resource_path_key(reward)):
			continue
		pool.append(reward)
	pool.shuffle()
	return pool.slice(0, min(count, pool.size()))

func _resource_path_key(resource: Resource) -> String:
	if resource == null:
		return ""
	if resource.resource_path != "":
		return resource.resource_path
	return str(resource.get_instance_id())

func _get_forced_reward_for_room(room_index: int) -> RewardData:
	if room_index != 0:
		return null
	return load(FIRST_REWARD_PATH) as RewardData

# Lu par l'écran de récompense pour afficher les choix.
func get_offered_rewards() -> Array:
	return _offered_rewards

# Appelé par l'écran de récompense quand le joueur a choisi.
# `chosen_hero` n'est utilisé que pour les récompenses à cible CHOICE.
func choose_reward(reward: RewardData, chosen_hero: Unit = null) -> void:
	if reward != null:
		var targets = _resolve_reward_targets(reward, chosen_hero)
		_apply_reward(reward, targets)
	_offered_rewards = []
	_go_to_next_room()

func _finish_run(victory: bool) -> void:
	_battle_outcome_generation += 1
	_battle_outcome_pending = false
	run_active = false
	_offered_rewards = []
	_awaiting_post_battle_progression = false
	_close_active_progression_screen()
	_record_run_result(victory)
	if victory:
		run_won.emit()
	else:
		run_lost.emit()
	_request_scene_change(RUN_RESULT_SCREEN_PATH)

func _record_run_result(victory: bool) -> void:
	_last_run_result = {
		"victory": victory,
		"run_name": _active_run_name,
	}

func get_last_run_result() -> Dictionary:
	return _last_run_result.duplicate(true)

func return_to_title() -> void:
	cleanup_run_state()
	_request_scene_change(TITLE_SCREEN_PATH)


func _request_scene_change(
		path: String,
		ui_mode: PersistentRunUI.RunUIMode = PersistentRunUI.RunUIMode.NON_COMBAT
	) -> void:
	unbind_combat_context()
	set_run_ui_mode(ui_mode)
	scene_change_requested.emit(path)
	if is_inside_tree():
		get_tree().change_scene_to_file.call_deferred(path)

# Détermine quels héros reçoivent la récompense selon sa cible.
func _resolve_reward_targets(reward: RewardData, chosen_hero: Unit) -> Array:
	var living = get_living_heroes()
	if reward.forced_unit_name.strip_edges() != "":
		var forced = _hero_by_name(living, reward.forced_unit_name)
		return [forced] if forced != null else []
	match reward.target:
		RewardData.Target.ALL:
			return living
		RewardData.Target.LOWEST_HP:
			var u = _hero_by_hp(living, true)
			return [u] if u != null else []
		RewardData.Target.HIGHEST_HP:
			var u = _hero_by_hp(living, false)
			return [u] if u != null else []
		RewardData.Target.CHOICE:
			return [chosen_hero] if chosen_hero != null else []
	return []

# Applique tous les effets d'une récompense aux cibles.
func _apply_reward(reward: RewardData, targets: Array) -> void:
	for hero in targets:
		if hero == null:
			continue
		# 1. Soin immédiat.
		if reward.heal_amount > 0:
			hero.heal(reward.heal_amount)
		# 2. Bonus de stat principal.
		if reward.stat != RewardData.StatKind.NONE:
			_apply_stat_mod(hero, reward.stat, reward.stat_amount, reward.stat_is_percent)
		# 3. Malus de stat (malédiction).
		if reward.malus_stat != RewardData.StatKind.NONE:
			_apply_stat_mod(hero, reward.malus_stat, reward.malus_amount, reward.malus_is_percent)
		# 4. Nouveau sort.
		if reward.spell != null:
			var character_state := get_character_state_for_unit(hero)
			if character_state != null:
				character_state.loadout.learn_spell(reward.spell)
			else:
				hero.add_spell(reward.spell)
		if reward.trait_data != null:
			hero.add_trait_from_data(reward.trait_data)
		# 5. Statut permanent (saignement de malédiction, etc.).
		if reward.status_effect != null:
			hero.apply_status(reward.status_effect)
		print("Récompense « %s » appliquée à %s." % [reward.reward_name, hero.unit_name])

# Applique un modificateur permanent à une stat du héros.
# Gère le cas spécial des PV max : un gain de max soigne d'autant,
# et on garde current_hp dans [1, max] (une malédiction ne tue pas).
func _apply_stat_mod(hero: Unit, stat_kind: int, amount: float, is_percent: bool) -> void:
	var stat = _get_stat(hero, stat_kind)
	if stat == null:
		return
	var before_max = hero.max_hp.get_int()
	var mtype = Stat.ModType.PERCENT if is_percent else Stat.ModType.FLAT
	stat.add_modifier(amount, mtype, "reward", -1)

	if stat_kind == RewardData.StatKind.MAX_HP:
		var after_max = hero.max_hp.get_int()
		var delta = after_max - before_max
		if delta > 0:
			hero.current_hp += delta   # un gain de PV max soigne d'autant
		hero.current_hp = clampi(hero.current_hp, 1, after_max)
	hero.stats_changed.emit(hero)

# Renvoie l'objet Stat correspondant à un StatKind.
func _get_stat(hero: Unit, stat_kind: int):
	match stat_kind:
		RewardData.StatKind.MAX_HP:     return hero.max_hp
		RewardData.StatKind.ATTACK:     return hero.attack_power
		RewardData.StatKind.MAX_MP:     return hero.max_mp
		RewardData.StatKind.MAX_AP:     return hero.max_ap
		RewardData.StatKind.INITIATIVE: return hero.initiative
	return null

# Héros vivant avec le moins (ou le plus) de PV.
func _hero_by_name(living: Array, unit_name: String) -> Unit:
	var wanted := unit_name.strip_edges().to_lower()
	for u in living:
		if u != null and u.unit_name.to_lower() == wanted:
			return u
	for u in living:
		if u != null and wanted in u.unit_name.to_lower():
			return u
	return null
func _hero_by_hp(living: Array, lowest: bool) -> Unit:
	var best: Unit = null
	for u in living:
		if best == null:
			best = u
			continue
		if lowest and u.current_hp < best.current_hp:
			best = u
		elif not lowest and u.current_hp > best.current_hp:
			best = u
	return best

# ============================================================
# LECTURE DES HÉROS (par battle, par l'UI)
# ============================================================

# Les héros encore vivants, à déployer dans la salle.
func get_living_heroes() -> Array:
	return get_ordered_heroes().filter(func(u): return u.is_alive)
