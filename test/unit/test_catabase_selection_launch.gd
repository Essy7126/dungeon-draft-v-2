extends GutTest
## Actual run loading is intentional: missing room dependencies must fail this test.

const SELECTION = preload("res://ui/selection/CharacterSelectionScreen.tscn")
const MANAGER = preload("res://core/game_manager.gd")
const CATABASE := "res://data/runs/odyssey.tres"
const TRIAL := "res://data/runs/philosopher_trial.tres"
const SAVE := "user://inventory_equipment_v1.json"
var _screen: CharacterSelectionScreen
var _manager
var _global_before: Dictionary
var _save_before: String


func before_each() -> void:
	_global_before = GameManager.get_inventory_equipment_snapshot().duplicate(true)
	_save_before = FileAccess.get_sha256(SAVE) if FileAccess.file_exists(SAVE) else "absent"
	_screen = SELECTION.instantiate() as CharacterSelectionScreen
	add_child_autofree(_screen)
	await wait_process_frames(3)


func after_each() -> void:
	if _manager != null:
		_manager.cleanup_run_state()
		_manager._exit_tree()
		_manager.free()
		_manager = null
	assert_eq(GameManager.get_inventory_equipment_snapshot(), _global_before)
	assert_eq(FileAccess.get_sha256(SAVE) if FileAccess.file_exists(SAVE) else "absent", _save_before)


func test_catabase_loads_its_real_rooms_and_has_its_own_achilles_selection() -> void:
	var run := load(CATABASE) as RunData
	assert_not_null(run, "Catabase and all its real room dependencies must load")
	if run == null:
		return
	assert_gt(run.rooms.size(), 0)
	for room in run.rooms:
		assert_not_null(room)
		assert_not_null(room.battle_scene)
		assert_not_null(room.get_encounter_for_wave(0))
	var entries := _screen.get_entries()
	assert_eq(entries.size(), 5, "Catabase, the trio, and the separate trial must all remain browsable")
	assert_eq(_entry_ids(entries), [&"achilles", &"elf", &"mage", &"warrior", &"achilles"])
	assert_eq(_screen.get_selected_entry().get("id"), &"achilles")
	assert_same(_screen.get_selected_entry().get("run"), run)
	var trial_entries := entries.filter(func(entry): return entry["run"].resource_path == TRIAL)
	assert_eq(trial_entries.size(), 1)
	if trial_entries.is_empty():
		return
	assert_ne(run.resource_path, str(trial_entries[0]["run"].resource_path))


func test_catabase_selection_starts_real_champion_manager_at_first_room_without_saving() -> void:
	var run := load(CATABASE) as RunData
	assert_not_null(run)
	if run == null:
		return
	assert_same(_screen.get_selected_entry().get("run"), run)
	_manager = MANAGER.new()
	_manager._ready()
	watch_signals(_manager)
	assert_true(_screen.prepare_adventure(_manager))
	assert_same(_manager.peek_next_run_data(), run)
	assert_true(_manager.start_configured_run())
	assert_same(_manager.get_active_run_data(), run)
	assert_null(_manager.peek_next_run_data(), "Configuration is consumed exactly once")
	assert_eq(_manager.current_room_index, 0)
	assert_same(_manager.get_current_room(), run.rooms[0])
	assert_signal_emitted_with_parameters(_manager, "scene_change_requested", ["res://ui/Transitionsalle.tscn"])
	var states: Array = _manager.get_ordered_character_states()
	assert_eq(states.size(), 1)
	if states.is_empty():
		return
	var state := states[0] as CharacterRunState
	assert_eq(state.character_id, &"achilles")
	assert_true(state.uses_champion_progression())
	assert_eq(state.champion_progression.current_level, 1)
	assert_eq(state.unit.max_hp.get_int(), 110)
	assert_eq(state.unit.max_ap.get_int(), 6)
	assert_eq(state.unit.max_mp.get_int(), 3)
	assert_eq(state.unit.spells.size(), 4)
	assert_false(_manager.start_configured_run(), "The same selection cannot launch twice")


func _entry_ids(entries: Array[Dictionary]) -> Array:
	return entries.map(func(entry): return entry["id"])
