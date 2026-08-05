extends GutTest

const GameManagerScript = preload("res://core/game_manager.gd")
const MAGE_ISO_SCENE := preload("res://characters/mage/MageIsoUnitView.tscn")
const MAGE_VISUAL_SCENE := preload("res://characters/mage/MageVisual3D.tscn")

const ELF_PATH := "res://data/units/alliés/elfe.tres"
const MAGE_PATH := "res://data/units/alliés/mage.tres"
const WARRIOR_PATH := "res://data/units/alliés/Guerrier.tres"
const PARTY := [ELF_PATH, MAGE_PATH, WARRIOR_PATH]

var manager


func before_each() -> void:
	manager = GameManagerScript.new()
	manager._ready()


func after_each() -> void:
	if manager != null and is_instance_valid(manager):
		manager.cleanup_run_state()
		manager._exit_tree()
		manager.free()


func _run() -> RunData:
	var run := RunData.new()
	run.rooms = [RoomData.new(), RoomData.new(), RoomData.new()]
	return run


func _prepare() -> Array[CharacterRunState]:
	assert_true(manager._prepare_preconfigured_run(_run(), PARTY))
	return manager.get_ordered_character_states()


func test_replacing_run_disposes_old_mage_state_loadout_and_modifiers() -> void:
	var old_states := _prepare()
	var old_mage_state := old_states[1]
	var old_mage := old_mage_state.unit
	var old_loadout := old_mage_state.loadout
	var callback := Callable(old_mage_state, "sync_loadout_to_unit")
	var fresh_states := _prepare()
	assert_null(old_mage_state.unit)
	assert_null(old_mage_state.loadout)
	assert_false(old_loadout.changed.is_connected(callback))
	assert_true(old_mage.get_progression_spell_modifiers().is_empty())
	assert_not_same(fresh_states[1].unit, old_mage)
	assert_eq(fresh_states[1].character_id, &"mage")


func test_cleanup_removes_all_three_states_and_pending_continuations() -> void:
	var states := _prepare()
	var loadouts := states.map(func(state): return state.loadout)
	manager._awaiting_post_battle_progression = true
	manager._room_outcome_resolved = true
	manager.cleanup_run_state()
	assert_true(manager.heroes.is_empty())
	assert_true(manager.character_states.is_empty())
	assert_false(manager._awaiting_post_battle_progression)
	assert_false(manager._room_outcome_resolved)
	for index in range(3):
		assert_null(states[index].unit)
		assert_null(states[index].loadout)
		assert_false(loadouts[index].changed.is_connected(
			Callable(states[index], "sync_loadout_to_unit")
		))


func test_freeing_mage_iso_disconnects_unit_and_event_bus_signals() -> void:
	var mage := Unit.from_data(load(MAGE_PATH) as UnitData)
	var iso := MAGE_ISO_SCENE.instantiate() as MageIsoUnitView
	add_child(iso)
	await wait_process_frames(2)
	iso.bind_unit(mage)
	var moved_callback := Callable(iso, "_on_bound_unit_moved")
	var died_callback := Callable(iso, "_on_bound_unit_died")
	var damage_callback := Callable(iso, "_on_hit_resolved")
	assert_true(mage.moved.is_connected(moved_callback))
	assert_true(mage.died.is_connected(died_callback))
	assert_true(EventBus.hit_resolved.is_connected(damage_callback))
	remove_child(iso)
	iso.free()
	assert_false(mage.moved.is_connected(moved_callback))
	assert_false(mage.died.is_connected(died_callback))
	assert_false(EventBus.hit_resolved.is_connected(damage_callback))


func test_freed_mage_visual_cannot_emit_a_late_release() -> void:
	var old_visual := MAGE_VISUAL_SCENE.instantiate() as MageVisual3D
	add_child(old_visual)
	await wait_process_frames(2)
	var releases := {"count": 0}
	old_visual.cast_release_reached.connect(func(): releases["count"] += 1)
	assert_true(old_visual.play_cast_full())
	remove_child(old_visual)
	old_visual.free()
	await get_tree().create_timer(1.05).timeout
	assert_eq(releases["count"], 0)


func test_three_successive_runs_keep_fresh_mage_instances_and_one_manager_callback() -> void:
	var previous_mage: Unit = null
	for _index in range(3):
		var states := _prepare()
		var current_mage := states[1].unit
		if previous_mage != null:
			assert_not_same(current_mage, previous_mage)
		previous_mage = current_mage
		manager._ready()
		var wanted := Callable(manager, "_on_successful_spell_cast")
		assert_eq(EventBus.spell_cast.get_connections().filter(
			func(connection): return connection.get("callable") == wanted
		).size(), 1)
