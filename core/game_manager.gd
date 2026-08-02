# core/game_manager.gd
# ============================================================
# GAME MANAGER — Chef d'orchestre du RUN (autoload/singleton).
#
# RESPONSABILITÉ : transporter l'état du run d'une salle à l'autre.
#   - possède les héros (et donc leurs HP qui persistent : pas de regen)
#   - connaît la liste des salles et l'avancement
#   - enchaîne les combats
#   - conserve la progression de discipline entre les salles
#
# CE QU'IL NE FAIT PAS (volontairement) :
#   - il ne calcule aucun combat (ça reste dans battle.gd)
#   - il ne stocke aucun état local de combat (turn_queue, highlights...)
# On garde ce manager "boring" : il transporte, il ne joue pas.
# ============================================================
extends Node

# --- Configuration du run ---
# Le build de production appartient au run : les batailles reçoivent le trio
const WARRIOR_DATA_PATH := "res://data/units/alliés/Guerrier.tres"
const ELF_DATA_PATH := "res://data/units/alliés/elfe.tres"
const MAGE_DATA_PATH := "res://data/units/alliés/mage.tres"

const PRODUCTION_HERO_DATA_PATHS = [
	ELF_DATA_PATH,
	MAGE_DATA_PATH,
	WARRIOR_DATA_PATH,
]

const RUN_RESULT_SCREEN_PATH := "res://ui/RunResultScreen.tscn"
const TITLE_SCREEN_PATH := "res://ui/TitreEcran.tscn"
const PROGRESSION_CHOICE_SCREEN_PATH := "res://ui/progression/ProgressionChoiceScreen.tscn"
const ROOM_TRANSITION_SCREEN_PATH := "res://ui/Transitionsalle.tscn"
const POST_COMBAT_SCREEN_PATH := "res://ui/post_combat/PostCombatScreen.tscn"
const PERSISTENT_RUN_UI_SCENE := preload("res://ui/run/PersistentRunUI.tscn")
const PersistentRunUIScript := preload("res://ui/run/persistent_run_ui.gd")

# --- État du run (vivant pendant tout le run) ---
var heroes: Array = []          # Array[Unit] — persistent, HP conservés
var character_states: Dictionary = {} # StringName -> CharacterRunState
var rooms: Array = []           # Array[RoomData]
var current_room_index: int = -1
var run_active: bool = false
var _active_run_name: String = ""
var _last_run_result: Dictionary = {}
var _awaiting_post_battle_progression: bool = false
var _room_outcome_resolved: bool = false
var _active_progression_screen_ref: WeakRef = null
var _progression_service := CharacterProgressionService.new()
var _persistent_run_ui: PersistentRunUI = null
var _battle_outcome_generation := 0
var _battle_outcome_pending := false
var _combat_report_tracker := CombatReportTracker.new()
var _last_combat_report: CombatReport = null
var _post_combat_reward_service := PostCombatRewardService.new()
var _pending_next_combat_shields: Dictionary = {}
var _post_combat_transition_pending := false

# --- Signaux (pour que l'UI réagisse sans couplage direct) ---
signal run_won
signal run_lost
signal room_cleared(index)
signal discipline_xp_gained(character_id, discipline_id, amount, snapshot)
signal scene_change_requested(path)
signal combat_report_ready(report)
signal post_combat_reward_applied(result)


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
	start_preconfigured_run(run_data, PRODUCTION_HERO_DATA_PATHS)

## `hero_sources` accepte des chemins res:// vers des UnitData ou des UnitData.
func start_preconfigured_run(run_data: RunData, hero_sources: Array) -> void:
	if not _prepare_preconfigured_run(run_data, hero_sources):
		return
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
		hero.reset_combat_resources()
		var character_state := CharacterRunState.new()
		if not character_state.initialize(hero, data, data.active_spell_slots):
			push_error("Impossible d'initialiser l'etat du personnage : %s" % hero.unit_id)
			_dispose_prepared_characters(prepared_heroes, prepared_states)
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
	prepared_heroes.clear()
	prepared_states.clear()

func _initialize_run_state(run_data: RunData) -> void:
	rooms = run_data.rooms.duplicate()
	current_room_index = -1
	run_active = true
	_active_run_name = run_data.run_name
	_last_run_result = {}
	_awaiting_post_battle_progression = false
	_room_outcome_resolved = false
	_battle_outcome_generation += 1
	_battle_outcome_pending = false
	_combat_report_tracker.discard()
	_last_combat_report = null
	_post_combat_reward_service.reset()
	_pending_next_combat_shields.clear()
	_post_combat_transition_pending = false
	_active_progression_screen_ref = null
	_ensure_persistent_run_ui()
	set_run_ui_mode(PersistentRunUIScript.RunUIMode.TRANSITION)

# Crée les héros une fois pour tout le run.
func _clear_heroes() -> void:
	for state_value in character_states.values():
		var state := state_value as CharacterRunState
		if state != null:
			state.dispose()
	for hero in heroes:
		if hero == null:
			continue
		hero.clear_progression_spell_modifiers()
	heroes.clear()
	character_states.clear()


func cleanup_run_state() -> void:
	_battle_outcome_generation += 1
	_battle_outcome_pending = false
	_combat_report_tracker.discard()
	_last_combat_report = null
	_post_combat_reward_service.reset()
	_pending_next_combat_shields.clear()
	_post_combat_transition_pending = false
	_release_persistent_run_ui()
	_close_active_progression_screen()
	_awaiting_post_battle_progression = false
	_room_outcome_resolved = false
	run_active = false
	current_room_index = -1
	_clear_heroes()
	rooms.clear()
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
# RAPPORT ET RÉCOMPENSE D'APRÈS-COMBAT
# ============================================================

func begin_combat_report() -> CombatReport:
	if _combat_report_tracker.is_active():
		return _combat_report_tracker.get_report()
	var room := get_current_room()
	_post_combat_transition_pending = false
	return _combat_report_tracker.begin(
		get_ordered_character_states(),
		current_room_index,
		room.room_name if room != null else "Salle %d" % (current_room_index + 1),
	)


func _finalize_current_combat_report(victory: bool) -> CombatReport:
	if not _combat_report_tracker.is_active():
		begin_combat_report()
	return _combat_report_tracker.finalize(
		get_ordered_character_states(),
		victory,
	)


func get_current_combat_report() -> CombatReport:
	return _last_combat_report


func get_post_combat_reward_options() -> Array[Dictionary]:
	return _post_combat_reward_service.build_options(
		_last_combat_report,
		get_ordered_character_states(),
	)


func confirm_post_combat_reward(
		reward_id: StringName,
		target_character_id: StringName = &""
	) -> Dictionary:
	if _last_combat_report == null:
		return {
			"success": false,
			"error_code": "COMBAT_REPORT_MISSING",
			"error": "Rapport de combat indisponible.",
		}
	var selected_option: Dictionary = {}
	for option in get_post_combat_reward_options():
		if StringName(option.get("reward_id", &"")) != reward_id:
			continue
		if StringName(option.get("target_character_id", &"")) != target_character_id:
			continue
		selected_option = option
		break
	if selected_option.is_empty():
		return {
			"success": false,
			"error_code": "REWARD_OPTION_INVALID",
			"error": "Cette proposition de récompense n’est plus valide.",
		}
	var result := _post_combat_reward_service.apply(
		_last_combat_report,
		selected_option.get("reward") as PostCombatRewardData,
		target_character_id,
		get_ordered_character_states(),
		_pending_next_combat_shields,
	)
	if result.get("success", false):
		_last_combat_report.reward_result = result.duplicate(true)
		post_combat_reward_applied.emit(result)
	return result


func complete_post_combat_transition(report_id: StringName) -> bool:
	if _post_combat_transition_pending \
		or _last_combat_report == null \
		or _last_combat_report.report_id != report_id \
		or not _last_combat_report.reward_result.get("success", false) \
		or not _post_combat_reward_service.has_applied(report_id):
		return false
	_post_combat_transition_pending = true
	_go_to_next_room()
	return true


func apply_pending_next_combat_rewards() -> Dictionary:
	return _post_combat_reward_service.consume_next_combat_shields(
		get_ordered_character_states(),
		_pending_next_combat_shields,
	)


func get_pending_next_combat_shields() -> Dictionary:
	return _pending_next_combat_shields.duplicate(true)

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
	if has_pending_progression_choices():
		push_error(
			"Victoire différée : une évolution de compétence reste à résoudre en combat."
		)
		return
	_room_outcome_resolved = true
	_last_combat_report = _finalize_current_combat_report(true)
	room_cleared.emit(current_room_index)
	_awaiting_post_battle_progression = false
	combat_report_ready.emit(_last_combat_report)
	_request_scene_change(
		POST_COMBAT_SCREEN_PATH,
		PersistentRunUIScript.RunUIMode.NON_COMBAT,
	)


func _continue_after_progression() -> void:
	_go_to_next_room()


func choose_progression_upgrade(
		character_id: StringName,
		discipline_id: StringName,
		choice_rank: int,
		upgrade_id: StringName
	) -> bool:
	var state := get_character_state(character_id)
	if state == null or not state.select_upgrade(discipline_id, choice_rank, upgrade_id):
		return false
	return true

# Appelé par battle quand le joueur PERD le combat.
func on_battle_lost() -> void:
	if not run_active or _room_outcome_resolved:
		return
	_room_outcome_resolved = true
	_finalize_current_combat_report(false)
	_finish_run(false)

func _finish_run(victory: bool) -> void:
	_battle_outcome_generation += 1
	_battle_outcome_pending = false
	run_active = false
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

# ============================================================
# LECTURE DES HÉROS (par battle, par l'UI)
# ============================================================

# Les héros encore vivants, à déployer dans la salle.
func get_living_heroes() -> Array:
	return get_ordered_heroes().filter(func(u): return u.is_alive)
