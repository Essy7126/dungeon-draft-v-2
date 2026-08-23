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
const DEFAULT_ITEM_CATALOG: ItemCatalog = preload(
	"res://data/items/catalogs/default_item_catalog.tres"
)
const INVENTORY_CAPACITY := 24
const INVENTORY_EQUIPMENT_SNAPSHOT_VERSION := 3
const POST_COMBAT_LOOT_ITEM_ID: StringName = &"minor_healing_potion"
const STARTING_INVENTORY := [
	{"item_id": &"warrior_training_sword", "quantity": 1},
	{"item_id": &"reinforced_vest", "quantity": 1},
	{"item_id": &"runic_charm", "quantity": 1},
	{"item_id": &"minor_healing_potion", "quantity": 2},
	{"item_id": &"minor_action_scroll", "quantity": 1},
]

# --- État du run (vivant pendant tout le run) ---
var heroes: Array = []          # Array[Unit] — persistent, HP conservés
var character_states: Dictionary = {} # StringName -> CharacterRunState
var rooms: Array = []           # Array[RoomData]
var current_room_index: int = -1
var current_wave_index: int = 0
var run_seed: int = 0
var run_active: bool = false
var _active_run_name: String = ""
var _active_run_data: RunData = null
var _active_economy_profile: RunEconomyProfile = null
var _equipment_rewards_enabled := true
var _equipment_reward_pool_tag: StringName = (
	RunEconomyProfile.DEFAULT_EQUIPMENT_REWARD_POOL_TAG
)
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
var _room_combat_report: CombatReport = null
var _post_combat_background_texture: Texture2D = null
var _post_combat_reward_service := PostCombatRewardService.new()
var _equipment_reward_service := FirstRunEquipmentRewardService.new()
var _pending_next_combat_shields: Dictionary = {}
var _post_combat_transition_pending := false
var item_catalog: ItemCatalog = null
var run_inventory: RunInventory = null
var _equipment_service := EquipmentService.new()
var _item_use_service := ItemUseService.new()
var _relic_runtime_service := RelicRuntimeService.new()
var _next_run_data: RunData = null
var _next_run_start_room_index := 0
var _active_room_flow_mode: int = RunData.RoomFlowMode.SINGLE_ENCOUNTER
var _maximum_waves_per_room := 1
var _room_wave_counts := PackedInt32Array()
var _room_exit_selected := false
var _cleared_room_emitted := false

# --- Signaux (pour que l'UI réagisse sans couplage direct) ---
signal run_won
signal run_lost
signal room_cleared(index)
signal wave_cleared(room_index, wave_index, reward_multiplier)
signal discipline_xp_gained(character_id, discipline_id, amount, snapshot)
signal discipline_xp_evaluated(snapshot)
signal scene_change_requested(path)
signal combat_report_ready(report)
signal post_combat_reward_applied(result)
signal inventory_changed(snapshot)
signal equipment_changed(result)
signal item_granted(result)
signal item_used(result)


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
	var resolution := resolve_run_hero_data(run_data)
	for warning in resolution.warnings:
		push_warning(warning)
	if not resolution.is_valid():
		for error in resolution.errors:
			push_error("Resolution du contenu de run : %s" % error)
		return
	start_preconfigured_run(run_data, resolution.heroes)


func resolve_run_hero_data(
		run_data: RunData,
		allow_legacy_fallback := true
	) -> RunHeroResolution:
	return RunHeroResolver.resolve_runtime_hero_data(run_data, allow_legacy_fallback)


## Conserve le choix du hub pendant la cinematique qui precede le lancement.
func configure_next_run(run_data: RunData, room_index: int) -> bool:
	if run_data == null or room_index < 0 or room_index >= run_data.rooms.size():
		return false
	_next_run_data = run_data
	_next_run_start_room_index = room_index
	return true


## Transfere le choix au consommateur suivant, puis libere la reference temporaire.
func take_next_run_data(default_run_data: RunData) -> RunData:
	var selected_run := _next_run_data
	_next_run_data = null
	return selected_run if selected_run != null else default_run_data


func clear_next_run_configuration() -> void:
	_next_run_data = null
	_next_run_start_room_index = 0


## Configure une seule fois la salle de depart du prochain lancement de run.
func configure_next_run_start_room(room_index: int) -> void:
	_next_run_start_room_index = maxi(0, room_index)


## `hero_sources` accepte des chemins res:// vers des UnitData ou des UnitData.
func start_preconfigured_run(run_data: RunData, hero_sources: Array) -> void:
	var requested_start_room := _next_run_start_room_index
	_next_run_start_room_index = 0
	if run_data == null or requested_start_room >= run_data.rooms.size():
		push_error("Indice de salle de depart invalide : %d" % requested_start_room)
		return
	if not _prepare_preconfigured_run(run_data, hero_sources):
		return
	current_room_index = requested_start_room - 1
	_go_to_next_room()


## Pont public reserve aux outils internes : construit le meme etat de run puis
## lance directement la vraie scene de bataille, sans ecran de transition.
func start_direct_encounter_test(
		run_data: RunData,
		hero_sources: Array,
		direct_test_options: Dictionary = {}
	) -> bool:
	var allow_empty_heroes := bool(direct_test_options.get(
		"allow_empty_heroes", false
	))
	if not _prepare_preconfigured_run(
		run_data, hero_sources, allow_empty_heroes
	):
		return false
	if not direct_test_options.is_empty():
		get_tree().set_meta(
			&"arena_studio_test_options", direct_test_options.duplicate(true)
		)
	if rooms.is_empty() or rooms[0] == null or rooms[0].battle_scene == null:
		cleanup_run_state()
		return false
	current_room_index = 0
	current_wave_index = 0
	start_next_battle()
	return true

## Prepare l'etat sans changer de scene. Separe de start_preconfigured_run pour
## garder la construction testable sans dependre d'une transition graphique.
func _prepare_preconfigured_run(
		run_data: RunData,
		hero_sources: Array,
		allow_empty_heroes := false
	) -> bool:
	if run_data == null:
		push_error("Aucun RunData fourni pour le run preconfigure.")
		return false
	if hero_sources.is_empty() and not allow_empty_heroes:
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
	run_seed = _resolve_run_seed(run_data)
	current_room_index = -1
	current_wave_index = 0
	_active_room_flow_mode = run_data.room_flow_mode
	_maximum_waves_per_room = maxi(1, run_data.maximum_waves_per_room)
	_build_hidden_room_wave_counts(run_data)
	run_active = true
	_active_run_name = run_data.run_name
	_active_run_data = run_data
	_active_economy_profile = run_data.economy_profile
	_equipment_rewards_enabled = (
		_active_economy_profile.equipment_rewards_enabled
		if _active_economy_profile != null else true
	)
	_equipment_reward_pool_tag = (
		_active_economy_profile.equipment_reward_pool_tag
		if _active_economy_profile != null
		else RunEconomyProfile.DEFAULT_EQUIPMENT_REWARD_POOL_TAG
	)
	_last_run_result = {}
	_awaiting_post_battle_progression = false
	_room_outcome_resolved = false
	_battle_outcome_generation += 1
	_battle_outcome_pending = false
	_combat_report_tracker.discard()
	_last_combat_report = null
	_room_combat_report = null
	_post_combat_background_texture = null
	_post_combat_reward_service.reset()
	_progression_service.reset_run()
	_pending_next_combat_shields.clear()
	_post_combat_transition_pending = false
	_room_exit_selected = false
	_cleared_room_emitted = false
	_active_progression_screen_ref = null
	if not _initialize_inventory_state(run_data):
		push_error("Impossible d'initialiser l'inventaire de run.")
	elif _equipment_rewards_enabled and not _equipment_reward_service.reset(
			item_catalog, run_seed, _equipment_reward_pool_tag
		):
		push_error("La pioche d'equipements de la premiere run est invalide.")
	elif not _equipment_rewards_enabled:
		# Une run sans recompenses ne construit ni ne melange aucune pioche.
		_equipment_reward_service.reset()
	_ensure_persistent_run_ui()
	set_run_ui_mode(PersistentRunUIScript.RunUIMode.TRANSITION)

# Crée les héros une fois pour tout le run.
func _clear_heroes() -> void:
	for state_value in character_states.values():
		var state := state_value as CharacterRunState
		if state != null:
			if item_catalog != null:
				_equipment_service.clear_state_stats(state)
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
	_room_combat_report = null
	_post_combat_background_texture = null
	_post_combat_reward_service.reset()
	_equipment_reward_service.reset()
	_pending_next_combat_shields.clear()
	_post_combat_transition_pending = false
	_release_persistent_run_ui()
	_close_active_progression_screen()
	_awaiting_post_battle_progression = false
	_room_outcome_resolved = false
	run_active = false
	current_room_index = -1
	current_wave_index = 0
	_clear_heroes()
	_clear_inventory_state()
	rooms.clear()
	run_seed = 0
	_active_room_flow_mode = RunData.RoomFlowMode.SINGLE_ENCOUNTER
	_maximum_waves_per_room = 1
	_room_wave_counts.clear()
	_room_exit_selected = false
	_cleared_room_emitted = false
	_active_run_name = ""
	_active_run_data = null
	_active_economy_profile = null
	_equipment_rewards_enabled = true
	_equipment_reward_pool_tag = (
		RunEconomyProfile.DEFAULT_EQUIPMENT_REWARD_POOL_TAG
	)
	_last_run_result.clear()
	clear_next_run_configuration()


func _initialize_inventory_state(run_data: RunData = null) -> bool:
	_clear_inventory_state()
	item_catalog = DEFAULT_ITEM_CATALOG
	var validation := item_catalog.validate_catalog()
	if not validation.get("valid", false):
		item_catalog = null
		return false
	run_inventory = RunInventory.new()
	if not run_inventory.initialize(item_catalog, INVENTORY_CAPACITY) \
			or not _equipment_service.initialize(item_catalog) \
			or not _item_use_service.initialize(item_catalog):
		_clear_inventory_state()
		return false
	_connect_inventory_signal()
	var starting_items: Array = STARTING_INVENTORY
	if run_data != null and run_data.economy_profile != null:
		starting_items = run_data.economy_profile.starting_items
	for entry_value in starting_items:
		var item_id := StringName()
		var quantity := 1
		if entry_value is RunStartingItemData:
			var configured := entry_value as RunStartingItemData
			item_id = configured.item_id
			quantity = configured.quantity
		elif entry_value is Dictionary:
			var legacy_entry := entry_value as Dictionary
			item_id = StringName(legacy_entry.get("item_id", &""))
			quantity = int(legacy_entry.get("quantity", 1))
		else:
			_clear_inventory_state()
			return false
		var result := run_inventory.try_add(
			item_id,
			quantity,
		)
		if not result.get("success", false):
			_clear_inventory_state()
			return false
	return _relic_runtime_service.initialize(run_inventory, item_catalog, heroes)


func _clear_inventory_state() -> void:
	_relic_runtime_service.dispose()
	_disconnect_inventory_signal()
	if run_inventory != null:
		run_inventory.clear()
	run_inventory = null
	item_catalog = null


func _connect_inventory_signal() -> void:
	if run_inventory == null:
		return
	var callback := Callable(self, "_on_run_inventory_changed")
	if not run_inventory.changed.is_connected(callback):
		run_inventory.changed.connect(callback)


func _disconnect_inventory_signal() -> void:
	if run_inventory == null:
		return
	var callback := Callable(self, "_on_run_inventory_changed")
	if run_inventory.changed.is_connected(callback):
		run_inventory.changed.disconnect(callback)


func _on_run_inventory_changed() -> void:
	if run_inventory != null:
		inventory_changed.emit(run_inventory.to_snapshot())


func _inventory_failure(code: String, message: String) -> Dictionary:
	return {"success": false, "error_code": code, "error": message}


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


func get_run_inventory() -> RunInventory:
	return run_inventory


func get_item_catalog() -> ItemCatalog:
	return item_catalog


func get_relic_runtime_service() -> RelicRuntimeService:
	return _relic_runtime_service


func get_active_run_data() -> RunData:
	return _active_run_data if run_active else null


func get_active_economy_profile() -> RunEconomyProfile:
	return _active_economy_profile if run_active else null


func are_equipment_rewards_enabled() -> bool:
	return run_active and _equipment_rewards_enabled


func grant_item_to_inventory(
		definition_id: StringName,
		quantity: int = 1
	) -> Dictionary:
	if not run_active or run_inventory == null:
		return _inventory_failure("RUN_INACTIVE", "Aucune run active.")
	var result := run_inventory.try_add(definition_id, quantity)
	if result.get("success", false):
		item_granted.emit(result.duplicate(true))
	return result


func equip_inventory_item(
		instance_id: StringName,
		character_id: StringName,
		slot: int
	) -> Dictionary:
	if not run_active or run_inventory == null:
		return _inventory_failure("RUN_INACTIVE", "Aucune run active.")
	var state := get_character_state(character_id)
	var result := _equipment_service.equip(
		run_inventory,
		state,
		instance_id,
		slot,
	)
	if result.get("success", false):
		equipment_changed.emit(result.duplicate(true))
	return result


func unequip_inventory_item(
		character_id: StringName,
		slot: int
	) -> Dictionary:
	if not run_active or run_inventory == null:
		return _inventory_failure("RUN_INACTIVE", "Aucune run active.")
	var result := _equipment_service.unequip(
		run_inventory,
		get_character_state(character_id),
		slot,
	)
	if result.get("success", false):
		equipment_changed.emit(result.duplicate(true))
	return result


func use_inventory_item(
		instance_id: StringName,
		character_id: StringName
	) -> Dictionary:
	if not run_active or run_inventory == null:
		return _inventory_failure("RUN_INACTIVE", "Aucune run active.")
	var result := _item_use_service.use_item(
		run_inventory,
		get_character_state(character_id),
		instance_id,
	)
	if result.get("success", false):
		item_used.emit(result.duplicate(true))
	return result


func get_inventory_equipment_snapshot() -> Dictionary:
	if run_inventory == null:
		return {}
	var equipment := {}
	var progression := {}
	for state in get_ordered_character_states():
		if state.equipment_loadout != null:
			equipment[str(state.character_id)] = state.equipment_loadout.to_snapshot()
		progression[str(state.character_id)] = state.get_progression_snapshot()
	return {
		"version": INVENTORY_EQUIPMENT_SNAPSHOT_VERSION,
		"inventory": run_inventory.to_snapshot(),
		"equipment": equipment,
		"equipment_reward": _equipment_reward_service.snapshot(),
		"progression": progression,
	}


func restore_inventory_equipment_snapshot(snapshot: Dictionary) -> bool:
	var snapshot_version := int(snapshot.get("version", -1))
	if not run_active \
			or item_catalog == null \
			or snapshot_version not in [1, 2, INVENTORY_EQUIPMENT_SNAPSHOT_VERSION]:
		return false
	var progression_snapshot := snapshot.get("progression", {}) as Dictionary
	if snapshot_version >= 3 and not _preflight_progression_restore(progression_snapshot):
		return false
	var candidate_inventory := RunInventory.new()
	if not candidate_inventory.initialize(item_catalog, INVENTORY_CAPACITY) \
			or not candidate_inventory.restore_snapshot(
				snapshot.get("inventory", {}) as Dictionary
			):
		return false
	var equipment_snapshot := snapshot.get("equipment", {}) as Dictionary
	var candidate_loadouts: Dictionary = {}
	var seen_instance_ids := {}
	for instance in candidate_inventory.get_slots():
		if instance != null:
			seen_instance_ids[instance.instance_id] = true
	for state in get_ordered_character_states():
		var key := str(state.character_id)
		if not equipment_snapshot.has(key):
			return false
		var candidate := EquipmentLoadout.new()
		if not candidate.initialize(state.character_id) \
				or not candidate.restore_snapshot(
					equipment_snapshot[key] as Dictionary,
					item_catalog,
				):
			return false
		for instance in candidate.get_equipped_items():
			if seen_instance_ids.has(instance.instance_id):
				return false
			seen_instance_ids[instance.instance_id] = true
		candidate_loadouts[state.character_id] = candidate
	var candidate_reward_service: FirstRunEquipmentRewardService = null
	if snapshot_version >= 2:
		candidate_reward_service = FirstRunEquipmentRewardService.new()
		if not candidate_reward_service.restore_snapshot(
				snapshot.get("equipment_reward", {}) as Dictionary,
				item_catalog,
				get_ordered_character_states(),
			):
			return false
	for state in get_ordered_character_states():
		_equipment_service.clear_state_stats(state)
		state.equipment_loadout = candidate_loadouts[state.character_id]
	_disconnect_inventory_signal()
	run_inventory = candidate_inventory
	_connect_inventory_signal()
	for state in get_ordered_character_states():
		if not _equipment_service.rebuild_state(state):
			return false
	if candidate_reward_service != null:
		_equipment_reward_service = candidate_reward_service
	if not _relic_runtime_service.initialize(run_inventory, item_catalog, heroes):
		return false
	if snapshot_version >= 3:
		for state in get_ordered_character_states():
			if not state.restore_progression_snapshot(
					progression_snapshot[str(state.character_id)] as Dictionary
				):
				return false
	inventory_changed.emit(run_inventory.to_snapshot())
	return true


func _preflight_progression_restore(progression_snapshot: Dictionary) -> bool:
	var originals := {}
	var attempted: Array[CharacterRunState] = []
	var valid := true
	for state in get_ordered_character_states():
		var key := str(state.character_id)
		originals[key] = state.get_progression_snapshot()
		if not progression_snapshot.has(key) \
				or not state.restore_progression_snapshot(
					progression_snapshot[key] as Dictionary
				):
			valid = false
			break
		attempted.append(state)
	# The validation pass must have no observable effect.
	for state in attempted:
		state.restore_progression_snapshot(originals[str(state.character_id)] as Dictionary)
	return valid


func save_inventory_equipment_state(
		file_path: String = "user://inventory_equipment_v1.json"
	) -> bool:
	var snapshot := get_inventory_equipment_snapshot()
	if snapshot.is_empty():
		return false
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(snapshot, "\t"))
	return true


func load_inventory_equipment_state(
		file_path: String = "user://inventory_equipment_v1.json"
	) -> bool:
	if not FileAccess.file_exists(file_path):
		return false
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return false
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed is Dictionary and restore_inventory_equipment_snapshot(parsed)


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
	discipline_xp_evaluated.emit(result.duplicate(true))
	if not result.get("granted", false):
		DebugLogger.debug(
			DebugLogger.LogCategory.COMBAT,
			"XP refusee : %s" % str(result.get("refusal_reason", &"unknown")),
			{
				"sort": str(result.get("spell_id", &"")),
				"activation": int(result.get("activation_index", -1)),
				"xp_combat": int(result.get("combat_xp", 0)),
			},
		)
		return
	var character_id: StringName = result["character_id"]
	var discipline_id := StringName(result.get("tree_id", &""))
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


func get_progression_choice_for_request(
		request: EvolutionRequest
	) -> Dictionary:
	if request == null or not request.is_valid():
		return {}
	for choice in get_pending_progression_choices():
		if StringName(choice.get("character_id", &"")) == request.character_id \
				and StringName(choice.get("discipline_id", &"")) == request.discipline_id \
				and (request.source_spell_id == &"" \
					or StringName(choice.get("spell_id", &"")) == request.source_spell_id) \
				and int(choice.get("rank", 0)) == request.pending_rank:
			return choice.duplicate(true)
	return {}


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
	_room_combat_report = null
	current_room_index += 1
	current_wave_index = 0
	_room_exit_selected = false
	_cleared_room_emitted = false
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


func get_run_seed() -> int:
	return run_seed


# La graine gouverne le mélange de la pioche de récompenses (donc les reliques
# proposées après chaque victoire) et le placement des ennemis. Tant qu'elle
# venait telle quelle de la ressource, toutes les parties rejouaient le même
# tirage : on en tire donc une nouvelle à chaque partie, sauf pour les runs de
# test qui ont justement besoin de reproduire la même situation.
func _resolve_run_seed(run_data: RunData) -> int:
	if run_data == null or not run_data.randomize_seed_each_run:
		return run_data.default_seed if run_data != null else 0
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return int(rng.randi())


func get_active_room_flow_mode() -> int:
	return _active_room_flow_mode


func get_active_room_flow_mode_name() -> StringName:
	return (
		&"WAVE_CHAIN"
		if is_wave_chain_active()
		else &"SINGLE_ENCOUNTER"
	)


func is_wave_chain_active() -> bool:
	return _active_room_flow_mode == RunData.RoomFlowMode.WAVE_CHAIN


func get_current_encounter_definition() -> EncounterDefinition:
	var room := get_current_room()
	if room == null:
		return null
	return room.get_encounter_for_wave(current_wave_index if is_wave_chain_active() else 0)


func get_current_wave_index() -> int:
	return current_wave_index if is_wave_chain_active() else 0


func get_current_wave_number() -> int:
	return get_current_wave_index() + 1


func get_current_room_wave_count() -> int:
	var room := get_current_room()
	if room == null:
		return 0
	if not is_wave_chain_active():
		return 1 if room.get_wave_count() > 0 else 0
	if current_room_index >= 0 and current_room_index < _room_wave_counts.size():
		return _room_wave_counts[current_room_index]
	return mini(room.get_wave_count(), _maximum_waves_per_room)


func _build_hidden_room_wave_counts(run_data: RunData) -> void:
	_room_wave_counts.clear()
	if run_data == null:
		return
	if run_data.is_single_encounter_flow():
		for room_value in run_data.rooms:
			var room := room_value as RoomData
			_room_wave_counts.append(
				1 if room != null and room.get_wave_count() > 0 else 0
			)
		return
	_room_wave_counts = RunWaveCountResolver.resolve_counts(run_data, run_seed)


func is_current_room_fully_cleared() -> bool:
	if not is_wave_chain_active():
		return _room_outcome_resolved \
			and _last_combat_report != null \
			and _last_combat_report.victory
	var wave_count := get_current_room_wave_count()
	return wave_count > 0 and current_wave_index + 1 >= wave_count


func can_continue_current_room() -> bool:
	return is_wave_chain_active() \
		and run_active \
		and _last_combat_report != null \
		and _last_combat_report.victory \
		and current_wave_index + 1 < get_current_room_wave_count()


func get_current_room_reward_multiplier() -> float:
	if not is_wave_chain_active():
		return 1.0
	var room := get_current_room()
	return RoomRewardProjectionService.cumulative_reward_multiplier(
		room, current_wave_index + 1
	)


func get_current_room_ultimate_reward_chance() -> int:
	if not is_wave_chain_active():
		return 0
	var room := get_current_room()
	return RoomRewardProjectionService.ultimate_chance(
		room,
		run_seed,
		current_room_index,
		get_current_room_cleared_wave_count(),
	)


func get_current_room_cleared_wave_count() -> int:
	if not is_wave_chain_active():
		return 1 if _room_outcome_resolved \
			and _last_combat_report != null \
			and _last_combat_report.victory else 0
	var cleared_count := maxi(0, current_wave_index)
	if _room_outcome_resolved \
			and _last_combat_report != null \
			and _last_combat_report.victory:
		cleared_count += 1
	return cleared_count


func is_current_room_ultimate_reward_won() -> bool:
	if not is_wave_chain_active():
		return false
	return RoomRewardProjectionService.ultimate_won(
		get_current_room(),
		run_seed,
		current_room_index,
		get_current_room_cleared_wave_count(),
		get_current_room_wave_count(),
	)


func _make_room_reward_rng(seed_salt: int) -> RandomNumberGenerator:
	return RoomRewardProjectionService.make_room_rng(
		run_seed, current_room_index, seed_salt
	)


func get_post_combat_decision_snapshot() -> Dictionary:
	var next_health_multiplier := 1.0
	var next_attack_multiplier := 1.0
	var ultimate_gain_range := Vector2i.ZERO
	var room := get_current_room()
	if room != null and is_wave_chain_active():
		ultimate_gain_range = room.get_ultimate_reward_gain_range()
		var next_wave := room.get_wave(current_wave_index + 1)
		if next_wave != null:
			next_health_multiplier = next_wave.enemy_health_multiplier
			next_attack_multiplier = next_wave.enemy_attack_multiplier
	return {
		"room_flow_mode": get_active_room_flow_mode_name(),
		"waves_enabled": is_wave_chain_active(),
		"room_index": current_room_index,
		"wave_index": current_wave_index,
		"wave_number": get_current_wave_number(),
		"wave_count": get_current_room_wave_count(),
		"can_continue": can_continue_current_room(),
		"reward_multiplier": get_current_room_reward_multiplier(),
		"ultimate_reward_chance_percent": (
			get_current_room_ultimate_reward_chance()
		),
		"ultimate_reward_roll_resolved": is_current_room_fully_cleared(),
		"ultimate_reward_won": is_current_room_ultimate_reward_won(),
		"ultimate_reward_min_gain_per_wave": ultimate_gain_range.x,
		"ultimate_reward_max_gain_per_wave": ultimate_gain_range.y,
		"room_exit_selected": _room_exit_selected,
		"room_completed": is_current_room_fully_cleared(),
		"next_enemy_health_multiplier": next_health_multiplier,
		"next_enemy_attack_multiplier": next_attack_multiplier,
		"secured_combat_xp": _get_last_combat_progression_xp(),
		"run_inventory_item_quantity": _get_run_inventory_item_quantity(),
	}


func _get_last_combat_progression_xp() -> int:
	if _last_combat_report == null:
		return 0
	var total := 0
	for character in _last_combat_report.character_reports:
		if character == null:
			continue
		for delta in character.discipline_deltas:
			if delta != null:
				total += maxi(0, delta.xp_after - delta.xp_before)
	return total


func _get_run_inventory_item_quantity() -> int:
	if run_inventory == null:
		return 0
	var total := 0
	for instance in run_inventory.get_slots():
		if instance != null:
			total += instance.quantity
	return total


func continue_current_room_combat(report_id: StringName) -> bool:
	if not is_wave_chain_active() \
		or _post_combat_transition_pending \
		or _room_exit_selected \
		or _last_combat_report == null \
		or _last_combat_report.report_id != report_id \
		or not can_continue_current_room():
		return false
	var room := get_current_room()
	if room == null or room.battle_scene == null or not is_inside_tree():
		return false
	_post_combat_transition_pending = true
	current_wave_index += 1
	_room_outcome_resolved = false
	_room_exit_selected = false
	unbind_combat_context()
	set_run_ui_mode(PersistentRunUIScript.RunUIMode.TRANSITION)
	get_tree().change_scene_to_packed.call_deferred(room.battle_scene)
	return true


func select_current_room_exit(report_id: StringName) -> bool:
	if _last_combat_report == null \
		or _last_combat_report.report_id != report_id \
		or _post_combat_transition_pending \
		or _room_exit_selected \
		or (is_final_room() and not is_current_room_fully_cleared()):
		return false
	_room_exit_selected = true
	if is_current_room_fully_cleared():
		_emit_current_room_cleared_once()
	return true


func _emit_current_room_cleared_once() -> void:
	if _cleared_room_emitted:
		return
	_cleared_room_emitted = true
	room_cleared.emit(current_room_index)


# ============================================================
# RAPPORT ET RÉCOMPENSE D'APRÈS-COMBAT
# ============================================================

func begin_combat_report() -> CombatReport:
	if _combat_report_tracker.is_active():
		return _combat_report_tracker.get_report()
	_progression_service.begin_combat()
	var room := get_current_room()
	_post_combat_transition_pending = false
	return _combat_report_tracker.begin(
		get_ordered_character_states(),
		current_room_index,
		room.room_name if room != null else "Salle %d" % (current_room_index + 1),
		get_active_room_flow_mode_name(),
	)


func _finalize_current_combat_report(victory: bool) -> CombatReport:
	if not _combat_report_tracker.is_active():
		begin_combat_report()
	var wave_report := _combat_report_tracker.finalize(
		get_ordered_character_states(),
		victory,
	)
	if wave_report == null:
		return null
	if _room_combat_report == null \
			or _room_combat_report.room_index != wave_report.room_index:
		_room_combat_report = wave_report
	elif not _room_combat_report.merge_wave_report(wave_report):
		return null
	return _room_combat_report


func get_current_combat_report() -> CombatReport:
	return _last_combat_report


func get_post_combat_reward_options() -> Array[Dictionary]:
	if _last_combat_report == null \
			or not can_claim_post_combat_equipment(_last_combat_report.report_id):
		return []
	return _equipment_reward_service.build_options(
		_last_combat_report,
		get_ordered_character_states(),
		run_inventory,
	)


func select_post_combat_equipment(item_id: StringName) -> bool:
	if _last_combat_report == null \
			or not can_claim_post_combat_equipment(_last_combat_report.report_id):
		return false
	return _equipment_reward_service.remember_selection(
		_last_combat_report,
		item_id,
	)


func get_selected_post_combat_equipment() -> StringName:
	if _last_combat_report == null:
		return &""
	return _equipment_reward_service.get_selected_item_id(
		_last_combat_report.report_id
	)


func confirm_post_combat_equipment(
		item_id: StringName,
		target_character_id: StringName = &""
	) -> Dictionary:
	var report_id := (
		_last_combat_report.report_id
		if _last_combat_report != null else StringName()
	)
	if not can_claim_post_combat_equipment(report_id):
		var final_room := is_final_room()
		return {
			"success": false,
			"error_code": (
				"FINAL_ROOM_HAS_NO_REWARD"
				if final_room else "ROOM_REWARD_UNAVAILABLE"
			),
			"error": (
				"La salle finale ne distribue pas d'équipement."
				if final_room else (
					"Sécurisez la sortie de la salle avant de choisir l'équipement."
				)
			),
		}
	var result := _equipment_reward_service.apply(
		_last_combat_report,
		item_id,
		target_character_id,
		get_ordered_character_states(),
		run_inventory,
		_equipment_service,
	)
	if result.get("success", false):
		_last_combat_report.reward_result = result.duplicate(true)
		post_combat_reward_applied.emit(result)
	return result


func can_claim_post_combat_equipment(report_id: StringName) -> bool:
	return _equipment_rewards_enabled \
		and report_id != &"" \
		and run_active \
		and _last_combat_report != null \
		and _last_combat_report.report_id == report_id \
		and _last_combat_report.finalized \
		and _last_combat_report.victory \
		and not is_final_room() \
		and _room_exit_selected \
		and not _post_combat_transition_pending \
		and not _last_combat_report.reward_result.get("success", false) \
		and not _equipment_reward_service.has_applied(report_id)


func is_final_room() -> bool:
	return not rooms.is_empty() and current_room_index == rooms.size() - 1


func get_equipment_reward_deck_snapshot() -> Dictionary:
	return _equipment_reward_service.snapshot()


func get_post_combat_background_texture() -> Texture2D:
	return _post_combat_background_texture


func get_equipment_reward_comparison(
		item_id: StringName,
		character_id: StringName
	) -> Dictionary:
	var definition := item_catalog.get_definition(item_id) if item_catalog != null else null
	var state := get_character_state(character_id)
	if definition == null or state == null or state.equipment_loadout == null:
		return {}
	var current_instance := state.equipment_loadout.get_item(
		definition.equipment_slot
	)
	var current_definition: ItemDefinition = null
	if current_instance != null:
		current_definition = item_catalog.get_definition(
			current_instance.definition_id
		)
	var next_stats := _item_stat_totals(definition)
	var current_stats := _item_stat_totals(current_definition)
	var stat_ids := next_stats.keys()
	for stat_id in current_stats:
		if not stat_ids.has(stat_id):
			stat_ids.append(stat_id)
	var deltas := {}
	for stat_id in stat_ids:
		deltas[stat_id] = float(next_stats.get(stat_id, 0.0)) \
			- float(current_stats.get(stat_id, 0.0))
	return {
		"character_id": character_id,
		"compatible": definition.is_compatible_with(character_id),
		"slot": definition.equipment_slot,
		"item_id": definition.item_id,
		"item_name": definition.display_name,
		"current_item_id": (
			current_definition.item_id if current_definition != null else &""
		),
		"current_item_name": (
			current_definition.display_name if current_definition != null else "Aucun"
		),
		"stat_deltas": deltas,
		"new_description": definition.description,
		"current_description": (
			current_definition.description if current_definition != null else ""
		),
	}


func _item_stat_totals(definition: ItemDefinition) -> Dictionary:
	var result := {}
	if definition == null:
		return result
	for modifier in definition.stat_modifiers:
		if modifier != null:
			result[modifier.stat_id] = float(result.get(modifier.stat_id, 0.0)) \
				+ modifier.value
	return result


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
		or not _room_exit_selected \
		or _last_combat_report == null \
		or _last_combat_report.report_id != report_id:
		return false
	if not is_final_room() and _equipment_rewards_enabled:
		if can_claim_post_combat_equipment(report_id):
			return false
		if not _last_combat_report.reward_result.get("success", false) \
				or not _equipment_reward_service.has_applied(report_id):
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
func _capture_post_combat_background() -> void:
	_post_combat_background_texture = null
	if not is_inside_tree() or get_viewport() == null:
		return
	var viewport_texture := get_viewport().get_texture()
	if viewport_texture == null:
		return
	var image := viewport_texture.get_image()
	if image == null or image.is_empty():
		return
	_post_combat_background_texture = ImageTexture.create_from_image(image)


func on_battle_won() -> void:
	if not run_active or _room_outcome_resolved:
		return
	if has_pending_progression_choices():
		push_error(
			"Victoire différée : une évolution de compétence reste à résoudre en combat."
		)
		return
	if not is_wave_chain_active():
		current_wave_index = 0
	_room_outcome_resolved = true
	_room_exit_selected = false
	_capture_post_combat_background()
	_last_combat_report = _finalize_current_combat_report(true)
	wave_cleared.emit(
		current_room_index,
		current_wave_index,
		get_current_room_reward_multiplier(),
	)
	if not can_continue_current_room():
		_room_exit_selected = true
		_emit_current_room_cleared_once()
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
		"room_flow_mode": get_active_room_flow_mode_name(),
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
