extends SceneTree
## Reproducible, non-destructive visual review of the selection screen.
## Run with a real renderer and -- --baseline to retain before_ captures.
## Without that user argument, writes after_ captures and a separate report.

const OUTPUT := "res://artifacts/character_selection_v2/"
const SCREEN_PATH := "res://ui/selection/CharacterSelectionScreen.tscn"

var screen
var failures: Array[String] = []
var captures: Array[Dictionary] = []
var layout_checks: Array[Dictionary] = []
var checks := 0
var prefix := "after_"
var _manager_before: Dictionary = {}


func _initialize() -> void:
	if OS.get_cmdline_user_args().has("--baseline"):
		prefix = "before_"
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var ignore := FileAccess.open(OUTPUT + ".gdignore", FileAccess.WRITE)
	if ignore != null:
		ignore.close()
	_manager_before = _manager_snapshot()
	root.size = Vector2i(1440, 900)
	var packed = load(SCREEN_PATH)
	if packed == null:
		_check(false, "Selection scene can be loaded")
		_finish()
		return
	screen = packed.instantiate()
	root.add_child(screen)
	current_scene = screen
	await _settle()
	var entries: Array = screen.get_entries()
	_check(entries.size() >= 5, "All five current hero/adventure entries remain available")
	if entries.is_empty():
		_finish()
		return
	_check(screen.selected_index == 0, "Achille Catabase is selected initially")
	_check(str(entries[0].get("id", "")) == "achilles", "First entry is Achille")
	_check(str(entries[0].get("run").resource_path) == "res://data/runs/odyssey.tres", "Initial Achille keeps Catabase")
	for target_size in [Vector2i(1440, 900), Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = target_size
		await _settle()
		_check_layout("achille_%dx%d" % [target_size.x, target_size.y])
		await _capture("achille_%dx%d" % [target_size.x, target_size.y])
	root.size = Vector2i(1440, 900)
	await _settle()
	var mage_index := _entry_index(entries, "mage")
	_check(mage_index >= 0, "Mage remains browsable")
	if mage_index >= 0:
		await _click(screen._roster_buttons[mage_index])
		_check(screen.selected_index == mage_index, "Injected click selects Mage")
		_check(str(screen.get_selected_entry().get("run").resource_path) == "res://data/runs/first_run.tres", "Mage keeps the complete trio adventure")
		_check_layout("mage_1440x900")
		await _capture("mage_1440x900")
	var trial_index := entries.size() - 1
	await _click(screen._roster_buttons[trial_index])
	_check(screen.selected_index == trial_index, "Injected click selects the last adventure")
	_check(str(screen.get_selected_entry().get("run").resource_path) == "res://data/runs/philosopher_trial.tres", "Last Achille entry keeps the philosopher trial")
	_check_layout("trial_1440x900")
	await _capture("trial_1440x900")
	await _click(screen._roster_buttons[0])
	await _click(screen._tab_buttons[0])
	var guard_index := _guard_index(screen.get_selected_entry().get("unit"))
	_check(guard_index >= 0, "Achille has his actual Guard technique")
	if guard_index >= 0:
		await _click(screen._spell_buttons[guard_index])
		_check(screen.selected_spell_index == guard_index, "Injected click opens Guard details")
		await _capture("garde_1440x900")
	await _click(screen._tab_buttons[1])
	_check(screen._lore.is_visible_in_tree(), "Injected click opens history and doctrines")
	_check_layout("histoire_1440x900")
	await _capture("histoire_1440x900")
	await _click(screen._tab_buttons[0])
	var open_button = screen.find_child("ExploreMasteries", true, false)
	_check(open_button is Button, "Mastery exploration has a real button")
	if open_button is Button:
		var preview = screen.get_preview()
		var orientation_before: int = screen.orientation_index
		await _click(open_button)
		var codex = screen.get_spell_tree()
		_check(is_instance_valid(codex), "Injected click opens the consultative codex")
		if is_instance_valid(codex):
			_check(codex.is_consultative(), "Selection codex is consultative")
			_check(not screen.select_character(mage_index), "Codex blocks underlying hero changes")
			_check(not screen.open_spell_tree(), "Codex blocks duplicate opening")
			_check(_manager_snapshot() == _manager_before, "Codex exploration does not mutate GameManager")
			await _capture("codex_1440x900")
			await _press_escape()
			_check(is_instance_valid(screen), "Escape closes the codex before leaving selection")
			if is_instance_valid(screen):
				_check(screen.get_spell_tree() == null, "Escape releases the consultative codex")
				_check(screen.orientation_index == orientation_before, "Codex preserves preview orientation")
				_check(screen.get_preview() == preview, "Codex restores the existing preview widget")
				await _capture("codex_closed_1440x900")
	_check(_manager_snapshot() == _manager_before, "Browsing every hero leaves the active and next run unchanged")
	if is_instance_valid(screen):
		screen.queue_free()
	await process_frame
	await process_frame
	_check(_manager_snapshot() == _manager_before, "Closing selection releases previews without mutating GameManager")
	_finish()


func _entry_index(entries: Array, character_id: String) -> int:
	for index in range(entries.size()):
		if str(entries[index].get("id", "")) == character_id:
			return index
	return -1


func _guard_index(unit) -> int:
	if unit == null:
		return -1
	for index in range(unit.spells.size()):
		var spell = unit.spells[index]
		if spell != null and str(spell.spell_name).to_lower().contains("garde"):
			return index
	return -1


func _settle() -> void:
	for frame in range(40):
		await process_frame


func _click(button: Button) -> void:
	_check(is_instance_valid(button) and button.is_visible_in_tree() and not button.disabled, "Target button is available: %s" % button.name)
	if not is_instance_valid(button) or not button.is_visible_in_tree() or button.disabled:
		return
	var point := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	Input.parse_input_event(motion)
	await process_frame
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
	await _settle()


func _press_escape() -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_ESCAPE
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
	await _settle()


func _check_layout(label: String) -> void:
	var bounds: Rect2 = screen.get_global_rect()
	var roster_rects: Array[Rect2] = []
	var note = screen.find_child("RosterNote", true, false)
	var measured: Array[Dictionary] = []
	for button in screen._roster_buttons:
		var rect: Rect2 = button.get_global_rect()
		_check(button.is_visible_in_tree(), "%s: roster card remains visible (%s)" % [label, button.name])
		_check(bounds.grow(1.0).encloses(rect), "%s: roster card stays inside the screen (%s)" % [label, button.name])
		if note is Control and note.is_visible_in_tree():
			_check(not rect.intersects(note.get_global_rect()), "%s: roster card does not cover the group note (%s)" % [label, button.name])
		for previous in roster_rects:
			_check(not rect.intersects(previous), "%s: roster cards do not overlap" % label)
		roster_rects.append(rect)
		measured.append({"name": str(button.name), "rect": _rect_json(rect)})
	var controls: Array = [screen.start_button]
	for property in ["_spell_buttons", "_pose_buttons", "_tab_buttons"]:
		var values = screen.get(property)
		if values is Array:
			controls.append_array(values)
	for control in controls:
		if control is Control and control.is_visible_in_tree():
			_check(bounds.grow(1.0).encloses(control.get_global_rect()), "%s: action stays inside the screen (%s)" % [label, control.name])
			measured.append({"name": str(control.name), "rect": _rect_json(control.get_global_rect())})
	layout_checks.append({"state": label, "screen": _rect_json(bounds), "controls": measured})


func _rect_json(rect: Rect2) -> Array:
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]


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
		"manager_object_id": manager.get_instance_id(),
		"active_run_object_id": active.get_instance_id() if active != null else 0,
		"configured_run_object_id": configured.get_instance_id() if configured != null else 0,
		"states": states,
		"inventory_equipment": manager.get_inventory_equipment_snapshot().duplicate(true),
	}


func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	var captured := root.get_texture().get_image()
	_check(captured != null and not captured.is_empty(), "Rendered image exists: " + label)
	if captured == null or captured.is_empty():
		return
	var path := OUTPUT + prefix + label + ".png"
	_check(captured.save_png(ProjectSettings.globalize_path(path)) == OK, "Rendered image is saved: " + label)
	var jpeg_path := OUTPUT + prefix + label + ".jpg"
	_check(captured.save_jpg(ProjectSettings.globalize_path(jpeg_path), 0.9) == OK, "Lightweight review image is saved: " + label)
	captures.append({"state": label, "path": path, "jpeg_path": jpeg_path, "width": captured.get_width(), "height": captured.get_height()})


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		push_error(description)


func _finish() -> void:
	var report := {"passed": failures.is_empty(), "mode": prefix.trim_suffix("_"), "checks": checks, "failures": failures, "captures": captures, "layouts": layout_checks}
	var report_path := OUTPUT + prefix + "review.json"
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write selection quality report")
		quit(1)
		return
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("SELECTION_QUALITY_REVIEW: ", JSON.stringify({"passed": failures.is_empty(), "mode": report.mode, "checks": checks, "failures": failures, "captures": captures.size(), "report": report_path}))
	quit(0 if failures.is_empty() else 1)
