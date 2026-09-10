extends Node
## True scene transitions and pointer input; use a unique --output per execution.
## --ending=skip|natural --appearance=classic|painted_g --output=res://artifacts/...
var _output := "res://artifacts/dev/catabase-threshold-flow"
var _ending := "skip"
var _appearance := "painted_g"
var _report: Dictionary = { "ok": false, "checks": [], "captures": [], "journeys": [] }
var _previous_save_hash := ""
var _failed := false
var _finishing := false


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			_output = argument.trim_prefix("--output=")
		elif argument.begins_with("--ending="):
			_ending = argument.trim_prefix("--ending=")
		elif argument.begins_with("--appearance="):
			_appearance = argument.trim_prefix("--appearance=")
	if (
		not _output.begins_with("res://artifacts/") or ".." in _output
		or _ending not in ["skip", "natural"] or _appearance not in ["classic", "painted_g"]
	):
		push_error("THRESHOLD_QA: invalid arguments")
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_output))
	_report["ending"] = _ending
	_report["appearance"] = _appearance
	GameManager.cleanup_run_state()
	GameManager.cancel_expedition_replacement()
	GameManager.expedition_save_path = _output.path_join("checkpoint.json")
	if FileAccess.file_exists(GameManager.expedition_save_path):
		_fail("Use a new report directory; existing checkpoint preserved")
		return
	var previous := FileAccess.open(GameManager.expedition_save_path, FileAccess.WRITE)
	previous.store_string("{\"previous_saved_adventure\":true}")
	previous.close()
	_previous_save_hash = FileAccess.get_sha256(GameManager.expedition_save_path)
	get_tree().current_scene = null
	var title: Node = load("res://ui/TitreEcran.tscn").instantiate()
	get_tree().root.add_child.call_deferred(title)
	await _frames(5)
	get_tree().current_scene = title
	await _capture("01-title.png")
	await _click(title.get_node("UI/Boutons/BoutonNouvellePartie"))
	if not await _until(
		func():
			return get_tree().current_scene is CharacterSelectionScreen,
		15,
		"title opens selection",
	):
		return
	var selection := get_tree().current_scene as CharacterSelectionScreen
	await _frames(8)
	await _click(selection._roster_buttons[1 if _appearance == "painted_g" else 0])
	await _capture("02-selection.png")
	await _click(selection.start_button)
	if not await _until(
		func():
			return selection._is_replacement_open(),
		5,
		"replacement confirmation appears",
	):
		return
	await _capture("02-replacement.png")
	await _click(selection._replacement_dialog.get_ok_button())
	_report["replacement_after_click"] = {
		"visible": selection._is_replacement_open() if is_instance_valid(selection) else false,
		"transitioning": selection._transitioning if is_instance_valid(selection) else true,
		"status": selection._status.text if is_instance_valid(selection) else "left selection",
	}

	if not await _until(
		func():
			return get_tree().current_scene is IntroCinematic,
		15,
		"selection opens cinematic",
	):
		return
	var cinematic := get_tree().current_scene as IntroCinematic
	await _frames(8)
	if _ending == "skip":
		await _click(cinematic.skip_button)
	if not await _until(
		func():
			var current := get_tree().current_scene
			return (
				current != null
				and current.scene_file_path == GameManager.CATABASE_THRESHOLD_SCREEN_PATH
			),
		85,
		"cinematic opens threshold",
	):
		return
	var hall = get_tree().current_scene
	if not await _until(
		func():
			return hall.is_ready_for_play(),
		20,
		"threshold navigation and actor ready",
	):
		return
	if not _check(
		not GameManager.run_active and GameManager.expedition == null,
		"entry precedes run initialization",
	):
		return
	if not _check(
		FileAccess.get_sha256(GameManager.expedition_save_path) == _previous_save_hash,
		"previous save unchanged before gate",
	):
		return
	if not _check(
		hall.get_entry_state().variant == ("painted_g" if _appearance == "painted_g" else ""),
		"selected appearance visible at threshold",
	):
		return
	_report["entry_state"] = hall.get_entry_state()
	_report["actor_profile"] = str(hall.player.sprite_profile.profile_id)
	await _capture("03-entry.png")
	for landmark_id in ["statue_memory", "zeus_memory", "fallen_oath", "threshold_gate"]:
		var landmark_index := -1
		for index: int in hall.definition.landmarks.size():
			if str(hall.definition.landmarks[index].id) == landmark_id:
				landmark_index = index
		if not _check(landmark_index >= 0, "authored landmark exists: " + landmark_id):
			return
		var landmark: Dictionary = hall.definition.landmarks[landmark_index]
		var focus: Array = landmark.get("focus", landmark.point)
		var plaque: Array = landmark.get("hit_polygon", [])
		if not _check(
			plaque.size() >= 3
			and Geometry2D.is_point_in_polygon(hall.point(focus), hall.polygon(plaque)),
			"click targets the painted plaque or door: " + landmark_id,
		):
			return
		var journey: Dictionary = { "landmark": landmark_id, "departure": _movement_snapshot(hall) }
		_report.journeys.append(journey)
		var started_usec: int = await _pointer(hall.world.to_global(hall.point(focus)))
		journey["requested"] = _movement_snapshot(hall)
		if not _check(
			hall.interactions.pending == landmark_index or hall.interactions.active,
			"plaque click requests its safe approach: " + landmark_id,
		):
			return
		if landmark_id == "threshold_gate":
			if not _check(hall.is_player_moving(), "gate capture follows real walking"):
				return
			await _capture("04-threshold_gate-walking.png")
			journey["in_motion"] = _movement_snapshot(hall)
			journey["capture_elapsed_seconds"] = (Time.get_ticks_usec() - started_usec) / 1000000.0
		if not await _until(
			func():
				return hall.interactions.active,
			90,
			"pointer approach reaches " + landmark_id,
		):
			return
		journey["elapsed_seconds"] = (Time.get_ticks_usec() - started_usec) / 1000000.0
		journey["arrival"] = _movement_snapshot(hall)
		if not _check(
			hall.interactions.selected == landmark_index,
			"arrival opens the requested landmark: " + landmark_id,
		):
			return
		if not _check(
			FileAccess.get_sha256(GameManager.expedition_save_path) == _previous_save_hash,
			"reading and walking preserve save: " + landmark_id,
		):
			return
		await _capture("04-" + landmark_id + ".png")
		if landmark_id != "threshold_gate":
			await _click(hall.find_child("CloseMemory", true, false))
	var threshold_instance_id: int = hall.get_instance_id()
	await _click(hall.find_child("CrossThreshold", true, false))
	if not await _until(
		func():
			return (
				GameManager.run_active and GameManager.expedition != null
				and GameManager.current_room_index == 0
				and not GameManager.has_next_run_configuration()
			),
		30,
		"gate starts the configured expedition",
	):
		return
	if not await _until(
		func():
			return not is_instance_id_valid(threshold_instance_id),
		30,
		"combat replaces threshold scene",
	):
		return
	if not _check(
		GameManager.expedition.route.current_node_id == "d01_0",
		"first authored combat is d01_0",
	):
		return
	if not _check(
		FileAccess.get_sha256(GameManager.expedition_save_path) != _previous_save_hash
		and not ExpeditionSaveService.read_snapshot(GameManager.expedition_save_path).is_empty(),
		"first checkpoint committed after gate",
	):
		return
	await _frames(45)
	await _capture("05-combat.png")
	if _failed:
		return
	_report["ok"] = true
	_report["run_variants"] = GameManager.get_active_run_data().hero_visual_variants
	_report["node_id"] = GameManager.expedition.route.current_node_id
	_write_report()
	print(
		"CATABASE_THRESHOLD_FLOW_PASS ending=%s appearance=%s report=%s"
		% [_ending, _appearance, _output]
	)
	await _finish(0)


func _movement_snapshot(hall) -> Dictionary:
	var state: Dictionary = hall.get_movement_state()
	var position: Vector2 = hall.player.position
	var target: Vector2 = state.destination
	var route: Array = []
	for waypoint: Vector2 in state.path:
		route.append([waypoint.x, waypoint.y])
	return {
		"position": [position.x, position.y],
		"destination": [target.x, target.y],
		"path": route,
		"path_index": state.path_index,
		"moving": state.moving,
		"world_clock": hall.clock,
		"pending_landmark": hall.interactions.pending,
		"active_landmark": hall.interactions.selected if hall.interactions.active else -1,
		"run_active": GameManager.run_active,
	}


func _pointer(point: Vector2, target_viewport: Viewport = null) -> int:
	var target := target_viewport if target_viewport != null else get_viewport()
	target.notify_mouse_entered()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	target.push_input(motion, true)
	await _frames(2)
	var hovered := target.gui_get_hovered_control()
	if not _report.has("pointer_targets"):
		_report["pointer_targets"] = []
	_report.pointer_targets.append(
		{
			"point": [point.x, point.y],
			"viewport": str(target.get_path()),
			"hovered": str(hovered.get_path()) if hovered != null else "none",
		}
	)
	var pressed_usec := 0
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		if pressed:
			pressed_usec = Time.get_ticks_usec()
		target.push_input(event, true)
		await _frames(2)
	return pressed_usec


func _click(control: Control) -> void:
	if not is_instance_valid(control) or not control.is_visible_in_tree():
		_fail("A required action is not visible")
		return
	await _frames(2)
	# Embedded dialogs own a viewport: include its window offset and canvas transform.
	var screen_point := control.get_screen_transform() * (control.size * 0.5)
	var root_point := get_viewport().get_screen_transform().affine_inverse() * screen_point
	await _pointer(root_point)


func _frames(count: int) -> void:
	for index in count:
		await get_tree().process_frame


func _until(condition: Callable, seconds: float, label: String) -> bool:
	var start := Time.get_ticks_msec()
	while not _failed and (Time.get_ticks_msec() - start) / 1000.0 < seconds:
		if bool(condition.call()):
			return _check(true, label)
		await get_tree().process_frame
	return _check(false, label + " (timeout)")


func _capture(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := _output.path_join(file_name)
	if image.save_png(ProjectSettings.globalize_path(path)) != OK:
		_fail("Cannot save capture " + path)
	else:
		_report.captures.append(path)


func _check(value: bool, label: String) -> bool:
	_report.checks.append({ "label": label, "passed": value })
	if not value:
		_fail(label)
	return value


func _write_report() -> void:
	var file := FileAccess.open(_output.path_join("flow-report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(_report, "  "))
	file.close()


func _fail(message: String) -> void:
	if _failed:
		return
	_failed = true
	_report["error"] = message
	_write_report()
	push_error("CATABASE_THRESHOLD_FLOW_FAIL: " + message)
	_finish.call_deferred(2)


func _finish(exit_code: int) -> void:
	if _finishing:
		return
	_finishing = true
	var current := get_tree().current_scene
	var probes: Dictionary = { }
	if is_instance_valid(current) and current.has_method("_begin_battle_shutdown"):
		_report["shutdown_scene"] = current.scene_file_path
		probes = {
			"effects": weakref(current.terrain_effects),
			"runtime": weakref(current.terrain_effects.runtime_service),
			"grid": weakref(current.grid),
		}
		_report["terrain_before_shutdown"] = _terrain_probe(probes)
	if is_instance_valid(current) and current != self:
		get_tree().current_scene = null
		current.queue_free()
	GameManager.cleanup_run_state()
	await _frames(3)
	_report["terrain_after_shutdown"] = _terrain_probe(probes)
	_write_report()
	# Let the mixer release stopped/paused WAV playbacks after scene teardown.
	await get_tree().create_timer(0.20, true, false, true).timeout
	get_tree().quit(2 if _failed else exit_code)


func _terrain_probe(probes: Dictionary) -> Dictionary:
	var result: Dictionary = { }
	for key: String in probes:
		var retained: Object = (probes[key] as WeakRef).get_ref()
		result[key + "_retained"] = retained != null
		if key == "runtime" and retained != null:
			result["cells"] = retained._states.size()
			result["grid_bound"] = retained.grid != null
			result["applied_relays"] = retained.surface_applied.get_connections().size()
	return result
