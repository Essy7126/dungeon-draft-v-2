extends Node

const OUTPUT_DIR := "res://artifacts/run_flow_isolation_closure/hub"
const HUB_SCENE := preload("res://hub/StartHub.tscn")

var _failures: Array[String] = []
var _results := {
	"mission_id": "RUN_FLOW_ISOLATION_V1_CLOSURE",
	"viewport": [1920, 1080],
	"main_run": {},
	"test_run": {},
}


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	get_window().size = Vector2i(1920, 1080)
	# Keep the validation runner alive while the real launch path replaces scenes.
	get_tree().current_scene = null
	await _settle(2)
	if await _run_main_path():
		await _run_test_path()
	await _finish()


func _run_main_path() -> bool:
	var launch := await _select_run_from_real_hub(0)
	if launch.is_empty():
		return false
	var run := launch.run as RunData
	if not _require(run.run_name == "Principal", "main_hub_selected_wrong_run"):
		return false
	GameManager.start_preconfigured_run(run, launch.hero_sources as Array)
	var first_battle := await _wait_for_room_battle("")
	if not _require(first_battle != null, "main_first_battle_not_loaded"):
		return false
	await _settle(4)
	if not _require(GameManager.run_active, "main_run_not_active"):
		return false
	if not _require(GameManager.current_room_index == 0, "main_room_one_not_active"):
		return false
	var main_report := GameManager.get_current_combat_report()
	if main_report == null:
		main_report = GameManager.begin_combat_report()
	if not _require(main_report != null, "main_report_not_started"):
		return false
	var first_battle_path := first_battle.scene_file_path
	GameManager.on_battle_won()
	var screen := await _wait_for_post_combat()
	if not _require(screen != null, "main_post_combat_not_loaded"):
		return false
	var snapshot := GameManager.get_post_combat_decision_snapshot()
	var phases := await _advance_to_phase(screen, &"COMBAT_STATS")
	if not _require(not phases.has(&"ROOM_DECISION"), "main_wave_decision_seen"):
		return false
	if not _require(await _capture("main_hub_combat_stats"), "main_stats_capture_failed"):
		return false
	phases.append_array(await _advance_to_phase(screen, &"PROGRESSION"))
	phases.append_array(await _advance_to_phase(screen, &"REWARD_SELECTION"))
	if not _require(screen.get_phase_name() == &"REWARD_SELECTION", "main_reward_not_reached"):
		return false
	if not _require(await _capture("main_hub_reward"), "main_reward_capture_failed"):
		return false
	var options := GameManager.get_post_combat_reward_options()
	if not _require(options.size() == 2, "main_reward_option_count"):
		return false
	var reward_id := StringName(options[0].get("reward_id", &""))
	if not _require(screen.select_reward_by_id(reward_id), "main_reward_select_failed"):
		return false
	if not _require(screen.confirm_selected_reward(), "main_reward_confirm_failed"):
		return false
	screen.transition_duration = 0.0
	var post_combat_path := screen.scene_file_path
	screen.advance_or_skip()
	var second_battle := await _wait_for_room_battle(post_combat_path)
	if not _require(second_battle != null, "main_room_two_battle_not_loaded"):
		return false
	if not _require(GameManager.current_room_index == 1, "main_room_index_not_incremented"):
		return false
	if not _require(GameManager.current_wave_index == 0, "main_wave_index_not_zero"):
		return false
	if not _require(await _capture("main_hub_room_two"), "main_room_two_capture_failed"):
		return false
	_results.main_run = {
		"hub_path": ["Hub", "Archiviste", "Principal"],
		"selected_resource": run.resource_path,
		"first_battle_scene": first_battle_path,
		"room_flow_mode": str(GameManager.get_active_room_flow_mode_name()),
		"waves_enabled": snapshot.get("waves_enabled", true),
		"room_decision_seen": phases.has(&"ROOM_DECISION"),
		"combat_stats_seen": phases.has(&"COMBAT_STATS"),
		"progression_seen": phases.has(&"PROGRESSION"),
		"reward_seen": phases.has(&"REWARD_SELECTION"),
		"reward_applied": true,
		"next_room_index": GameManager.current_room_index,
		"next_wave_index": GameManager.current_wave_index,
		"next_battle_scene": second_battle.scene_file_path,
	}
	await _detach_current_scene()
	GameManager.cleanup_run_state()
	return true


func _run_test_path() -> bool:
	var launch := await _select_run_from_real_hub(1)
	if launch.is_empty():
		return false
	var run := launch.run as RunData
	if not _require(run.run_name == "Run de test", "test_hub_selected_wrong_run"):
		return false
	GameManager.start_preconfigured_run(run, launch.hero_sources as Array)
	var first_battle := await _wait_for_room_battle("")
	if not _require(first_battle != null, "test_first_battle_not_loaded"):
		return false
	var first_battle_path := first_battle.scene_file_path
	await _settle(4)
	var deck_before := GameManager.get_equipment_reward_deck_snapshot()
	var test_report := GameManager.get_current_combat_report()
	if test_report == null:
		test_report = GameManager.begin_combat_report()
	if not _require(test_report != null, "test_report_not_started"):
		return false
	GameManager.on_battle_won()
	var screen := await _wait_for_post_combat()
	if not _require(screen != null, "test_post_combat_not_loaded"):
		return false
	var phases := await _advance_to_phase(screen, &"ROOM_DECISION")
	if not _require(screen.get_phase_name() == &"ROOM_DECISION", "test_decision_not_reached"):
		return false
	if not _require(await _capture("test_hub_wave_decision"), "test_decision_capture_failed"):
		return false
	screen.transition_duration = 0.0
	var post_combat_path := screen.scene_file_path
	if not _require(await screen.choose_continue_room(), "test_continue_rejected"):
		return false
	var next_battle := await _wait_for_room_battle(post_combat_path)
	if not _require(next_battle != null, "test_next_battle_not_loaded"):
		return false
	var deck_after := GameManager.get_equipment_reward_deck_snapshot()
	if not _require(GameManager.current_wave_index == 1, "test_wave_index_not_incremented"):
		return false
	if not _require(deck_after == deck_before, "test_reward_deck_changed"):
		return false
	_results.test_run = {
		"hub_path": ["Hub", "Archiviste", "Run de test"],
		"selected_resource": run.resource_path,
		"first_battle_scene": first_battle_path,
		"room_flow_mode": str(GameManager.get_active_room_flow_mode_name()),
		"room_decision_seen": phases.has(&"ROOM_DECISION"),
		"wave_index_after_continue": GameManager.current_wave_index,
		"next_battle_scene": next_battle.scene_file_path,
		"reward_deck_unchanged": deck_after == deck_before,
	}
	await _detach_current_scene()
	GameManager.cleanup_run_state()
	return true


func _select_run_from_real_hub(run_index: int) -> Dictionary:
	GameManager.cleanup_run_state()
	var hub := HUB_SCENE.instantiate()
	add_child(hub)
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	var controller := hub.get_node("HubController") as StartHubController
	controller.movement.movement_speed = 1200.0
	controller.transition_fade_duration = 0.0
	controller.cinematic_open_callable = func(_scene_path): return true
	if not _require(controller.request_interaction(controller.archivist) != null, "hub_interaction_rejected"):
		hub.queue_free()
		return {}
	for _frame in 180:
		await get_tree().process_frame
		if not controller.movement.is_moving():
			break
	if not _require(controller.archivist_panel.visible, "hub_archivist_panel_hidden"):
		hub.queue_free()
		return {}
	controller.archivist_panel.get_node("%RunButton").pressed.emit()
	var selector := controller.archivist_panel.get_node("%RunSelector") as OptionButton
	if not _require(selector.item_count == 2, "hub_run_count_mismatch"):
		hub.queue_free()
		return {}
	selector.select(run_index)
	selector.item_selected.emit(run_index)
	if not _require(await _capture("hub_run_%d_selection" % run_index), "hub_selection_capture_failed"):
		hub.queue_free()
		return {}
	controller.archivist_panel.get_node("%ConfirmRunButton").pressed.emit()
	await get_tree().process_frame
	if not _require(controller.get_state() == StartHubController.HubState.TRANSITIONING, "hub_transition_not_started"):
		hub.queue_free()
		return {}
	var selected := GameManager.take_next_run_data(null)
	var hero_sources: Array = controller.archivist.data.hero_sources.duplicate()
	hub.queue_free()
	await get_tree().process_frame
	if not _require(selected != null, "hub_selected_run_missing"):
		return {}
	return {"run": selected, "hero_sources": hero_sources}


func _wait_for_post_combat() -> PostCombatScreen:
	for _frame in 240:
		await get_tree().process_frame
		if get_tree().current_scene is PostCombatScreen:
			return get_tree().current_scene as PostCombatScreen
	return null


func _wait_for_room_battle(previous_path: String) -> Node:
	var scene := await _wait_for_scene_change(previous_path)
	if scene == null:
		return null
	if scene.scene_file_path == "res://ui/Transitionsalle.tscn":
		var transition_path := scene.scene_file_path
		var button := scene.get_node_or_null("Contenu/BoutonContinuer") as Button
		if button == null:
			return null
		button.pressed.emit()
		scene = await _wait_for_scene_change(transition_path)
	return scene


func _wait_for_scene_change(previous_path: String) -> Node:
	for _frame in 360:
		await get_tree().process_frame
		var current := get_tree().current_scene
		if current != null and current.scene_file_path != previous_path:
			return current
	return null


func _advance_to_phase(screen: PostCombatScreen, target: StringName) -> Array[StringName]:
	var phases: Array[StringName] = [screen.get_phase_name()]
	for _step in 30:
		if screen.get_phase_name() == target:
			break
		screen.advance_or_skip()
		await _settle(2)
		if not phases.has(screen.get_phase_name()):
			phases.append(screen.get_phase_name())
	return phases


func _capture(file_name: String) -> bool:
	await get_tree().create_timer(0.35).timeout
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		return false
	return image.save_png(ProjectSettings.globalize_path(
		"%s/%s.png" % [OUTPUT_DIR, file_name]
	)) == OK


func _detach_current_scene() -> void:
	var current := get_tree().current_scene
	if current != null:
		get_tree().current_scene = null
		current.queue_free()
	await _settle(3)


func _settle(frame_count: int) -> void:
	for _frame in frame_count:
		await get_tree().process_frame


func _require(condition: bool, code: String) -> bool:
	if condition:
		return true
	_failures.append(code)
	push_error("RUN_FLOW_HUB_SMOKE: %s" % code)
	return false


func _finish() -> void:
	_results["failures"] = _failures.duplicate()
	_results["passed"] = _failures.is_empty()
	var file := FileAccess.open(ProjectSettings.globalize_path(
		"%s/hub_runtime_snapshot.json" % OUTPUT_DIR
	), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(_results, "  "))
		file.close()
	else:
		_failures.append("hub_report_write_failed")
	GameManager.cleanup_run_state()
	print("RUN_FLOW_HUB_SMOKE=%s" % ("PASS" if _failures.is_empty() else "FAIL"))
	get_tree().quit(0 if _failures.is_empty() else 1)
