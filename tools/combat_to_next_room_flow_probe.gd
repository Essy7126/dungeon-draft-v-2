extends Node

## Validation graphique continue du dernier impact jusqu'a la transition vers
## la salle suivante. Le coup lethal est injecte par le runner ; toutes les
## scenes, donnees de run, HUD et transitions sont celles de production.

const FIRST_RUN := preload("res://data/runs/first_run.tres")
const OUTPUT_DIR := "res://artifacts/combat_flow_validation"
const REPORT_PATH := OUTPUT_DIR + "/report.json"
const TIMEOUT_MSEC := 12000

var _requested_scenes: Array[String] = []
var _checks: Dictionary = {}
var _lifecycle_metrics: Dictionary = {}
var _captures: Array[String] = []


func start() -> void:
	_run()


func _run() -> void:
	GameManager.cleanup_run_state()
	GameManager.set_reduced_motion_enabled(true)
	_capture_lifecycle_metrics(&"baseline")
	GameManager.scene_change_requested.connect(_on_scene_change_requested)
	var run := FIRST_RUN.duplicate(true) as RunData
	run.run_name = "Validation HUD impact vers salle suivante"
	run.randomize_seed_each_run = false
	run.default_seed = 230826
	run.rooms = [FIRST_RUN.rooms[0], FIRST_RUN.rooms[1]]
	var economy := RunEconomyProfile.new()
	economy.equipment_rewards_enabled = false
	run.economy_profile = economy
	if not GameManager.start_direct_encounter_test(
		run,
		GameManager.PRODUCTION_HERO_DATA_PATHS,
	):
		_fail("initialisation directe de la First Run impossible")
		return

	await get_tree().scene_changed
	var battle := get_tree().current_scene
	if battle == null or not battle.has_method("_check_battle_end"):
		_fail("la vraie scene Battle n'a pas ete chargee")
		return
	if not await _wait_until(func(): return bool(battle.runtime_ready_state)):
		_fail("Battle n'a pas atteint runtime_ready_state")
		return
	_checks["production_battle_loaded"] = true
	_capture_lifecycle_metrics(&"battle_loaded")
	_checks["deployment_marker_capture_saved"] = await _capture_frame(
		"deployment_non_color_markers.png"
	)
	_checks["persistent_hud_bound"] = (
		GameManager.get_persistent_run_ui()
		.get_combat_hud_lifecycle_snapshot()["bound_context_id"]
		== battle.get_instance_id()
	)

	var deployment = battle.get("_deployment")
	if deployment != null and deployment.is_active():
		var deploy_guard := 0
		while deployment.is_active() and deploy_guard < 12:
			deploy_guard += 1
			var placed := false
			for cell in deployment.get("_deploy_zone"):
				if not battle.grid.has_unit(cell):
					deployment.on_cell_clicked(cell)
					placed = true
					break
			if not placed:
				break
	if deployment != null and deployment.is_active():
		_fail("le deploiement de production n'a pas pu etre termine")
		return
	await get_tree().process_frame
	_checks["combat_report_started"] = (
		GameManager._combat_report_tracker.is_active()
	)

	var heroes: Array = battle.units.filter(
		func(unit): return unit != null and unit.team == 0 and unit.is_alive
	)
	var enemies: Array = battle.units.filter(
		func(unit): return unit != null and unit.team == 1 and unit.is_alive
	)
	if heroes.is_empty() or enemies.is_empty():
		_fail("le roster reel de la salle est incomplet")
		return
	for enemy_value in enemies.duplicate():
		var enemy := enemy_value as Unit
		if enemy != null and enemy.is_alive:
			enemy.take_damage(100000, heroes[0])
	if not await _wait_until(func():
		return is_instance_valid(battle.get("_outcome_overlay"))
	):
		_fail("l'overlay de victoire local n'a pas ete presente")
		return
	_checks["local_victory_overlay"] = (
		is_instance_valid(battle.get("_outcome_overlay"))
		and battle.get("_outcome_overlay").get_snapshot()["visible"]
	)
	_checks["combat_hud_hidden_during_outcome"] = not battle.action_bar.visible
	_checks["victory_capture_saved"] = await _capture_frame(
		"victory_overlay.png"
	)
	var outcome_snapshot := GameManager.get_battle_outcome_transition_snapshot()
	_checks["battlefield_frame_captured_before_overlay"] = (
		outcome_snapshot["background_captured"]
		and outcome_snapshot["background_ready"]
	)

	if not await _wait_until(func():
		return _requested_scenes.has(GameManager.POST_COMBAT_SCREEN_PATH)
	):
		_fail("PostCombatScreen n'a pas ete demande apres la victoire")
		return
	await get_tree().scene_changed
	var post_combat := get_tree().current_scene
	if post_combat == null or not post_combat.has_method("advance_or_skip"):
		_fail("PostCombatScreen reel n'a pas ete charge")
		return
	_checks["post_combat_loaded"] = true
	_capture_lifecycle_metrics(&"post_combat_loaded")
	_checks["post_combat_capture_saved"] = await _capture_frame(
		"post_combat.png"
	)
	_checks["combat_hud_unbound_after_scene_change"] = (
		GameManager.get_persistent_run_ui()
		.get_combat_hud_lifecycle_snapshot()["bound_context_id"] == 0
	)

	var phase_guard := 0
	while phase_guard < 8 \
			and not _requested_scenes.has(GameManager.ROOM_TRANSITION_SCREEN_PATH):
		phase_guard += 1
		post_combat.advance_or_skip()
		await get_tree().process_frame
		await get_tree().process_frame
	if not await _wait_until(func():
		return _requested_scenes.has(GameManager.ROOM_TRANSITION_SCREEN_PATH)
	):
		_fail("la sortie du post-combat n'a pas rejoint la transition de salle")
		return
	await get_tree().scene_changed
	_checks["room_transition_loaded"] = (
		get_tree().current_scene != null
		and get_tree().current_scene.scene_file_path \
			== GameManager.ROOM_TRANSITION_SCREEN_PATH
	)
	_checks["next_room_selected"] = GameManager.current_room_index == 1
	_checks["reduced_motion_remained_active"] = (
		GameManager.is_reduced_motion_enabled()
	)
	_capture_lifecycle_metrics(&"room_transition_loaded")
	_checks["room_transition_capture_saved"] = await _capture_frame(
		"room_transition.png"
	)
	_finish()


func _wait_until(predicate: Callable) -> bool:
	var deadline := Time.get_ticks_msec() + TIMEOUT_MSEC
	while Time.get_ticks_msec() < deadline:
		if predicate.call():
			return true
		await get_tree().process_frame
	return false


func _on_scene_change_requested(path: String) -> void:
	_requested_scenes.append(path)


func _finish() -> void:
	var passed := true
	for value in _checks.values():
		passed = passed and bool(value)
	GameManager.cleanup_run_state()
	for _index in 4:
		await get_tree().process_frame
	_capture_lifecycle_metrics(&"after_run_cleanup")
	_checks["persistent_hud_released_after_cleanup"] = (
		int(_lifecycle_metrics[&"after_run_cleanup"]["persistent_hud_nodes"]) == 0
	)
	passed = passed and _checks["persistent_hud_released_after_cleanup"]
	_write_report(passed, "")
	print("COMBAT_TO_NEXT_ROOM_FLOW=" + ("PASS" if passed else "FAIL"))
	get_tree().quit(0 if passed else 1)


func _fail(message: String) -> void:
	_checks["failure"] = false
	_write_report(false, message)
	push_error("COMBAT FLOW VALIDATION: " + message)
	GameManager.cleanup_run_state()
	for _index in 4:
		await get_tree().process_frame
	get_tree().quit(1)


func _write_report(passed: bool, error: String) -> void:
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(OUTPUT_DIR)
	)
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"passed": passed,
		"method": "coup lethal injecte, scenes/HUD/RunData de production",
		"checks": _checks,
		"lifecycle_metrics": _lifecycle_metrics,
		"captures": _captures,
		"requested_scenes": _requested_scenes,
		"error": error,
	}, "\t"))
	file.close()


func _capture_frame(file_name: String) -> bool:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		return false
	var capture_directory := OUTPUT_DIR.path_join("captures")
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(capture_directory)
	)
	var path := capture_directory.path_join(file_name)
	var error := image.save_png(ProjectSettings.globalize_path(path))
	if error == OK:
		_captures.append(path)
	return error == OK


func _capture_lifecycle_metrics(stage: StringName) -> void:
	var root := get_tree().root
	_lifecycle_metrics[stage] = {
		"object_count": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"node_count": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"resource_count": int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
		"persistent_run_ui_nodes": root.find_children(
			"PersistentRunUI", "", true, false
		).size(),
		"persistent_hud_nodes": root.find_children(
			"CombatHUDRecraftV1", "", true, false
		).size(),
		"unit_view_group_nodes": get_tree().get_nodes_in_group("unit_views").size(),
		"bound_context_id": (
			GameManager.get_persistent_run_ui()
			.get_combat_hud_lifecycle_snapshot()
			.get("bound_context_id", 0)
			if GameManager.get_persistent_run_ui() != null
			else 0
		),
	}
