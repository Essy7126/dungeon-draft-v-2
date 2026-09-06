extends SceneTree
## Real selection -> real Catabase introduction -> first room -> deployment.
## This dedicated process never calls save/load and verifies the existing save hash.

const OUTPUT := "res://artifacts/catabase_selection_launch/"
const SELECTION := "res://ui/selection/CharacterSelectionScreen.tscn"
const CATABASE := "res://data/runs/odyssey.tres"
const INTRO := "res://cinematics/intro/intro_cinematic.tscn"
const TRANSITION := "res://ui/Transitionsalle.tscn"
const SAVE := "user://inventory_equipment_v1.json"
var _manager: Node
var _save_before: String
var _run_data
var checks := 0
var failures: Array[String] = []
var captures: Array[Dictionary] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var ignore := FileAccess.open(OUTPUT + ".gdignore", FileAccess.WRITE)
	if ignore != null:
		ignore.close()
	_save_before = _save_fingerprint()
	_manager = root.get_node("GameManager")
	_check(not _manager.run_active, "Review starts in its own fresh process")
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280, 720)
	DisplayServer.window_set_size(root.size)
	_run_data = load(CATABASE)
	_check(_run_data != null, "Actual Catabase resource and all room dependencies load")
	if _run_data == null:
		await _finish()
		return
	_check(not _run_data.rooms.is_empty(), "Actual Catabase has playable rooms")
	for room in _run_data.rooms:
		_check(room != null and room.battle_scene != null and room.get_encounter_for_wave(0) != null, "Actual room content resolves: %s" % room.room_name)
	var selection = load(SELECTION).instantiate()
	root.add_child(selection)
	current_scene = selection
	await _settle()
	var entries: Array = selection.get_entries()
	var ids: Array = entries.map(func(entry): return str(entry.id))
	_check(ids == ["achilles", "elf", "mage", "warrior", "achilles"], "All five authored hero/adventure choices remain in order")
	var selected: Dictionary = selection.get_selected_entry()
	_check(selected.get("run") == _run_data and str(selected.get("id")) == "achilles", "Initial selection is Achille in Catabase")
	var achilles_runs: Array[String] = []
	for entry in entries:
		if str(entry.id) == "achilles":
			achilles_runs.append(entry.run.resource_path)
	_check(achilles_runs == [CATABASE, "res://data/runs/philosopher_trial.tres"], "Catabase and the trial retain separate Achille choices")
	await _capture("selection_1280x720")
	root.size = Vector2i(1920, 1080)
	DisplayServer.window_set_size(root.size)
	await _settle()
	await _capture("selection_1920x1080")
	root.size = Vector2i(1280, 720)
	DisplayServer.window_set_size(root.size)
	await _settle()
	if selected.get("run") != _run_data:
		await _finish()
		return
	await _click(selection.start_button)
	if not await _wait_for_scene(INTRO):
		await _finish()
		return
	_check(_manager.peek_next_run_data() == _run_data, "Catabase configuration reaches the actual cinematic")
	var intro = current_scene
	_check(intro.sequence == _run_data.intro_sequence, "The cinematic resolves Catabase's own introduction")
	await _capture("catabase_introduction")
	await _click(intro.get_node("SkipButton") as Button)
	if not await _wait_for_scene(TRANSITION):
		await _finish()
		return
	_check(_manager.run_active and _manager.get_active_run_data() == _run_data, "Skipping the actual introduction starts the selected Catabase")
	_check(_manager.peek_next_run_data() == null, "The run configuration is consumed once")
	_check(_manager.current_room_index == 0 and _manager.get_current_room() == _run_data.rooms[0], "The run starts at its real first room")
	var states: Array = _manager.get_ordered_character_states()
	_check(states.size() == 1 and str(states[0].character_id) == "achilles", "The playable party contains only Achille")
	if not states.is_empty():
		_check(states[0].uses_champion_progression() and states[0].champion_progression.current_level == 1, "Achille starts with the Champion level-one progression")
		_check(states[0].unit.spells.size() == 4, "Achille starts with all four techniques")
	await _capture("first_room_transition")
	var battle_path: String = _run_data.rooms[0].battle_scene.resource_path
	await _click(current_scene.get_node("Contenu/BoutonContinuer") as Button)
	if not await _wait_for_scene(battle_path):
		await _finish()
		return
	var deployment = current_scene.get("_deployment")
	_check(deployment != null and deployment.is_active(), "The actual first battle is ready for player deployment")
	var units: Array = current_scene.get("units")
	_check(not units.is_empty(), "The actual encounter spawns its units")
	await _capture("first_battle_deployment")
	await _finish()


func _wait_for_scene(path: String) -> bool:
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < 20000:
		if is_instance_valid(current_scene) and current_scene.scene_file_path == path:
			await _settle()
			_check(true, "Real scene reached: " + path)
			return true
		await create_timer(0.1).timeout
	_check(false, "Timed out waiting for actual scene: " + path)
	return false


func _click(button: Button) -> void:
	_check(is_instance_valid(button) and button.is_visible_in_tree() and not button.disabled, "Real input target is available")
	if not is_instance_valid(button) or not button.is_visible_in_tree() or button.disabled:
		return
	var point := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	Input.parse_input_event(motion)
	await process_frame
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
	await _settle()


func _settle() -> void:
	await create_timer(0.7).timeout
	for frame in 4:
		await process_frame


func _capture(label: String) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(2, root.size.y - 2)
	Input.parse_input_event(motion)
	await create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	var captured := root.get_texture().get_image()
	_check(captured != null and not captured.is_empty(), "Actual viewport captured: " + label)
	if captured == null or captured.is_empty():
		return
	var path := OUTPUT + label
	_check(captured.save_png(ProjectSettings.globalize_path(path + ".png")) == OK, "PNG written: " + label)
	_check(captured.save_jpg(ProjectSettings.globalize_path(path + ".jpg"), 0.9) == OK, "JPEG written: " + label)
	captures.append({"name": label, "path": path + ".png", "jpeg": path + ".jpg", "size": str(root.size)})


func _save_fingerprint() -> String:
	return FileAccess.get_sha256(SAVE) if FileAccess.file_exists(SAVE) else "absent"


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		push_error(description)


func _finish() -> void:
	if is_instance_valid(current_scene):
		var scene := current_scene
		current_scene = null
		scene.queue_free()
		await process_frame
		await process_frame
	if _manager != null:
		_manager.clear_next_run_configuration()
		_manager.cleanup_run_state()
	_check(_save_fingerprint() == _save_before, "Launching the review never writes the player's saved build")
	var report := {"passed": failures.is_empty(), "checks": checks, "failures": failures, "captures": captures, "run_resource": CATABASE, "actual_rooms_loaded": _run_data != null, "writes_player_save": false}
	var file := FileAccess.open(OUTPUT + "review.json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))
		file.close()
	print("CATABASE_SELECTION_LAUNCH_REVIEW: ", JSON.stringify({"passed": report.passed, "checks": checks, "captures": captures.size(), "failures": failures}))
	quit(0 if failures.is_empty() else 1)
