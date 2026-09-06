extends SceneTree
## Native-renderer review. All XP and purchases belong to temporary local heroes.
## Never starts a run or saves a build. Captures PNG + lightweight JPEG evidence.

const OUTPUT := "res://artifacts/dynamic_mastery/"
const CONTENT_PROFILE_PATH := "res://data/runs/profiles/odyssey_content_profile.tres"
const CODEX_PATH := "res://ui/progression/champion/champion_codex.gd"
const SAVE_PATH := "user://inventory_equipment_v1.json"
const FIRST := &"achilles_wrath_focused_fury"
const SECOND := &"achilles_wrath_opening_slash"
var _state
var _codex
var _profile
var _profile_before := ""
var _manager_before: Dictionary
var _save_before := ""
var _closed := false
var failures: Array[String] = []
var captures: Array[Dictionary] = []
var layouts: Array[Dictionary] = []
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var ignore := FileAccess.open(OUTPUT + ".gdignore", FileAccess.WRITE)
	if ignore != null:
		ignore.close()
	_manager_before = _manager_snapshot()
	_save_before = _save_fingerprint()
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	if not _create_fixture(0):
		_finish()
		return
	await _open(true)
	var untouched: Dictionary = _state.get_progression_snapshot().duplicate(true)
	for dimensions in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		await _resize(dimensions)
		await _click_named("FitGraph")
		_check_layout("initial_%dx%d" % [dimensions.x, dimensions.y])
		await _capture("initial_%dx%d" % [dimensions.x, dimensions.y])
	await _resize(Vector2i(1280, 720))
	await _click_named("FitGraph")
	await _click_node(SECOND)
	_check(_codex.get_action_button().disabled, "Initial prerequisite cannot be acquired in consultation")
	await _capture("prerequisite_1280x720")
	var graph = _codex.get_graph()
	var zoom_before: float = graph.get_navigation_snapshot().zoom
	await _wheel(graph.get_global_rect().get_center(), MOUSE_BUTTON_WHEEL_UP)
	_check(float(graph.get_navigation_snapshot().zoom) > zoom_before, "Real mouse wheel zooms the graph")
	var pan_before: Vector2 = graph.get_navigation_snapshot().pan_offset
	await _drag(graph.get_global_rect().get_center(), Vector2(75, 34))
	_check(not (graph.get_navigation_snapshot().pan_offset as Vector2).is_equal_approx(pan_before), "Real middle-button drag pans the graph")
	await _capture("pan_zoom_1280x720")
	await _click_named("FitGraph")
	await _select_section(&"achilles_aegis_of_aeacus")
	await _capture("aegis_1280x720")
	await _select_section(&"advanced")
	await _capture("advanced_consultation_1280x720")
	await _select_section(&"attributes")
	await _capture("attributes_consultation_1280x720")
	await _click_spell(3)
	await _capture("guard_consultation_1280x720")
	_check(_state.get_progression_snapshot() == untouched, "All consultation interactions leave temporary Champion unchanged")
	await _close_and_dispose()
	if not _create_fixture(1700):
		_finish()
		return
	await _open(false)
	await _resize(Vector2i(1280, 720))
	await _click_named("NextAvailable")
	var selected := StringName(_codex.get_graph().get_navigation_snapshot().selected_node_id)
	_check(selected != &"" and bool(_state.evaluate_mastery_node(selected).get("allowed", false)), "Next available inspects a legally purchasable mastery")
	await _click_node(FIRST)
	_check(not _codex.get_action_button().disabled, "Legal fixture permits the first mastery")
	await _capture("available_1280x720")
	var points_before: int = _state.champion_progression.unspent_mastery_points
	var view_before: Dictionary = _codex.get_graph().get_navigation_snapshot()
	await _click(_codex.get_action_button())
	_check(_state.champion_progression.selected_node_ids.has(FIRST), "Real purchase click acquires the isolated fixture mastery")
	_check(_state.champion_progression.unspent_mastery_points == points_before - 1, "Purchase spends exactly its authored cost")
	_check(_codex.get_action_button().disabled, "An acquired mastery cannot be purchased twice")
	_check(float(_codex.get_graph().get_navigation_snapshot().zoom) == float(view_before.zoom), "Purchasing preserves the current zoom")
	_check(Vector2(_codex.get_graph().get_navigation_snapshot().pan_offset).is_equal_approx(Vector2(view_before.pan_offset)), "Purchasing preserves the current pan")
	await _click_node(SECOND)
	for dimensions in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		await _resize(dimensions)
		await _click_named("FitGraph")
		_check_layout("progression_%dx%d" % [dimensions.x, dimensions.y])
		await _capture("progression_%dx%d" % [dimensions.x, dimensions.y])
	await _resize(Vector2i(1280, 720))
	await _select_section(&"attributes")
	await _capture("attributes_progression_1280x720")
	await _click_spell(0)
	await _capture("strike_progression_1280x720")
	await _select_section(&"advanced")
	await _capture("advanced_progression_1280x720")
	await _close_and_dispose()
	_check(_manager_snapshot() == _manager_before, "Review leaves the active run, next run, inventory and turn untouched")
	_check(_save_fingerprint() == _save_before, "Review neither creates nor modifies the player's saved build")
	_finish()


func _create_fixture(xp: int) -> bool:
	# Resolve the authored roster without loading unrelated rooms under active editing.
	var fixture_run = load("res://data/runs/run_data.gd").new()
	fixture_run.content_profile = load(CONTENT_PROFILE_PATH)
	var resolution = load("res://core/run_content/run_hero_resolver.gd").resolve_runtime_hero_data(fixture_run, false)
	_check(resolution.is_valid(), "Catabase hero data resolves")
	if not resolution.is_valid():
		return false
	var data = resolution.heroes[0]
	_profile = data.progression_profile
	_profile_before = load("res://core/run_content/run_progression_clone_service.gd").semantic_fingerprint(_profile)
	_state = load("res://characters/progression/character_run_state.gd").new()
	var initialized: bool = _state.initialize(load("res://units/unit.gd").from_data(data), data)
	_check(initialized, "Temporary Champion initializes")
	if not initialized:
		return false
	if xp > 0:
		_state.begin_encounter()
		_check(bool(_state.award_encounter_xp(&"dynamic_mastery_visual_fixture", xp, true).get("granted", false)), "Fixture receives legal encounter XP")
	return true


func _open(read_only: bool) -> void:
	_codex = load(CODEX_PATH).new()
	_codex.configure(_state, read_only)
	_closed = false
	_codex.close_requested.connect(func() -> void: _closed = true)
	root.add_child(_codex)
	await _settle()
	_check(_codex.get_graph() != null, "Codex owns a dynamic mastery graph")


func _close_and_dispose() -> void:
	await _click(_codex.get_close_button())
	_check(_closed, "Real close button emits close_requested")
	_codex.queue_free()
	await process_frame
	_codex = null
	_check(load("res://core/run_content/run_progression_clone_service.gd").semantic_fingerprint(_profile) == _profile_before, "Browsing and purchases preserve the authored profile")
	_state.dispose()
	_state = null
	_profile = null
	await process_frame


func _resize(dimensions: Vector2i) -> void:
	root.size = dimensions
	DisplayServer.window_set_size(dimensions)
	await _settle()


func _select_section(section: StringName) -> void:
	var navigation: Dictionary = _codex.get("_nav_buttons")
	_check(navigation.has(section), "Section button exists: %s" % section)
	if navigation.has(section):
		await _click(navigation[section])


func _click_spell(index: int) -> void:
	var spells := _codex.get("_spells") as HBoxContainer
	await _click(spells.get_child(index) as Button)


func _click_node(node_id: StringName) -> void:
	var nodes: Dictionary = _codex.get_node_buttons()
	_check(nodes.has(node_id), "Mastery is present: %s" % node_id)
	if not nodes.has(node_id):
		return
	_codex.get_graph().center_on_node(node_id)
	await _settle()
	await _click(nodes[node_id])
	_check(StringName(_codex.get_graph().get_navigation_snapshot().selected_node_id) == node_id, "Real node click inspects %s" % node_id)


func _click_named(node_name: String) -> void:
	var button := _codex.find_child(node_name, true, false) as Button
	_check(button != null, "Toolbar button exists: " + node_name)
	if button != null:
		await _click(button)


func _click(button: Button) -> void:
	_check(is_instance_valid(button) and button.is_visible_in_tree() and not button.disabled, "Interaction target is visible and enabled: %s" % button.name)
	if not is_instance_valid(button) or not button.is_visible_in_tree() or button.disabled:
		return
	var point := button.get_global_rect().get_center()
	_mouse_motion(point)
	await process_frame
	for pressed in [true, false]:
		_mouse_button(point, MOUSE_BUTTON_LEFT, pressed)
		await process_frame
	await _settle()


func _wheel(point: Vector2, wheel_button: int) -> void:
	_mouse_motion(point)
	await process_frame
	_mouse_button(point, wheel_button, true)
	await process_frame
	_mouse_button(point, wheel_button, false)
	await _settle()


func _drag(origin: Vector2, delta: Vector2) -> void:
	_mouse_motion(origin)
	await process_frame
	_mouse_button(origin, MOUSE_BUTTON_MIDDLE, true)
	await process_frame
	for step in range(1, 7):
		var motion := InputEventMouseMotion.new()
		motion.position = origin + delta * float(step) / 6.0
		motion.relative = delta / 6.0
		motion.button_mask = MOUSE_BUTTON_MASK_MIDDLE
		Input.parse_input_event(motion)
		await process_frame
	_mouse_button(origin + delta, MOUSE_BUTTON_MIDDLE, false)
	await _settle()


func _mouse_motion(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	Input.parse_input_event(motion)


func _mouse_button(point: Vector2, index: int, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = index
	event.position = point
	event.pressed = pressed
	Input.parse_input_event(event)


func _settle() -> void:
	# Elapsed time also covers uncapped native renders: navigation is interpolated.
	await create_timer(0.42).timeout
	for frame in 4:
		await process_frame


func _check_layout(label: String) -> void:
	var bounds := Rect2(Vector2.ZERO, Vector2(root.size))
	var measured: Array[Dictionary] = []
	for control in [_codex.get_graph(), _codex.get_action_button(), _codex.get_close_button(), _codex.find_child("ZoomIn", true, false), _codex.find_child("ZoomOut", true, false), _codex.find_child("FitGraph", true, false), _codex.find_child("NextAvailable", true, false)]:
		_check(control is Control and control.is_visible_in_tree(), "%s: main interaction remains visible" % label)
		if control is Control and control.is_visible_in_tree():
			_check(bounds.grow(1).encloses(control.get_global_rect()), "%s: %s remains in the viewport" % [label, control.name])
			measured.append({"name": str(control.name), "rect": str(control.get_global_rect())})
	layouts.append({"state": label, "viewport": str(root.size), "controls": measured})


func _manager_snapshot() -> Dictionary:
	var manager := root.get_node_or_null("GameManager")
	if manager == null:
		return {"missing": true}
	var states: Array = []
	for state in manager.get_ordered_character_states():
		states.append({"object_id": state.get_instance_id(), "progression": state.get_progression_snapshot().duplicate(true)})
	var active = manager.get_active_run_data()
	var configured = manager.peek_next_run_data()
	return {
		"active_run": active.get_instance_id() if active != null else 0,
		"configured_run": configured.get_instance_id() if configured != null else 0,
		"room": manager.current_room_index, "wave": manager.current_wave_index,
		"run_active": manager.run_active, "states": states,
		"inventory": manager.get_inventory_equipment_snapshot().duplicate(true),
		"progression_screen": manager.get_active_progression_screen(),
		"scene": current_scene.get_instance_id() if current_scene != null else 0,
		"paused": paused,
	}


func _save_fingerprint() -> String:
	return FileAccess.get_sha256(SAVE_PATH) if FileAccess.file_exists(SAVE_PATH) else "absent"


func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	var captured := root.get_texture().get_image()
	_check(captured != null and not captured.is_empty(), "Image rendered: " + label)
	if captured == null or captured.is_empty():
		return
	var path := OUTPUT + label + ".png"
	var jpeg := OUTPUT + label + ".jpg"
	_check(captured.save_png(ProjectSettings.globalize_path(path)) == OK, "PNG saved: " + label)
	_check(captured.save_jpg(ProjectSettings.globalize_path(jpeg), 0.9) == OK, "JPEG saved: " + label)
	captures.append({"state": label, "path": path, "jpeg": jpeg, "width": captured.get_width(), "height": captured.get_height()})


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		push_error(description)


func _finish() -> void:
	var report := {"passed": failures.is_empty(), "checks": checks, "failures": failures, "captures": captures, "layouts": layouts, "fixture_xp": [0, 1700], "writes_player_save": false}
	var file := FileAccess.open(OUTPUT + "review.json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))
		file.close()
	else:
		push_error("Unable to write dynamic mastery review report")
		quit(1)
		return
	print("DYNAMIC_MASTERY_REVIEW: ", JSON.stringify({"passed": report.passed, "checks": checks, "captures": captures.size(), "failures": failures}))
	quit(0 if failures.is_empty() else 1)
