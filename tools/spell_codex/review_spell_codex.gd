extends SceneTree
## Local rendered review using cloned hero run states, never a saved game.

const OUTPUT := "res://artifacts/spell_codex/"
var screen
var unit
var state
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var ignore := FileAccess.open(OUTPUT + ".gdignore", FileAccess.WRITE)
	ignore.close()
	var catalog = load("res://ui/selection/character_selection_catalog.gd")
	var entries = catalog.get_entries()
	var backdrop = load("res://ui/selection/selection_backdrop.gd").new()
	root.add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await _open(entries[0]["unit"])
	await _capture("01_achille")
	await _exercise_navigation()
	if OS.get_cmdline_user_args().has("--baseline"):
		await _cleanup()
		quit()
		return
	state.add_spell_xp(&"achilles_spear_thrust", 3)
	screen.refresh_from_state()
	await _settle()
	screen.get_graph().inspect_node_by_id(&"achilles_spear_inexorable_point")
	await _settle()
	await _capture("02_evolution_detail")
	state.select_upgrade(&"achilles_spear_thrust", 2, &"achilles_spear_inexorable_point")
	screen.refresh_from_state()
	await _settle()
	await _capture("03_acquired")
	await _cleanup()
	await _open(entries[2]["unit"])
	await _capture("04_mage")
	await _cleanup()
	root.size = Vector2i(1200, 896)
	await _open(entries[0]["unit"])
	await _capture("05_1200x896")
	await _cleanup()
	root.size = Vector2i(1280, 720)
	await _open(entries[0]["unit"])
	await _capture("06_1280x720")
	var graph_rect: Rect2 = screen.get_layout_snapshot()["graph_scroll_global"]
	for view in screen.get_graph().get_node_views_in_focus_order():
		_check(graph_rect.grow(2).encloses(view.get_global_rect()), "Short tree node fits 720p: " + str(view.presentation_id))
	await _cleanup()
	root.size = Vector2i(1440, 900)
	await _exercise_selection_entry()
	root.size = Vector2i(2560, 1440)
	await _open(entries[0]["unit"])
	state.add_spell_xp(&"achilles_spear_thrust", 3)
	screen.refresh_from_state()
	await _settle()
	screen.get_graph().inspect_node_by_id(&"achilles_spear_inexorable_point")
	await _capture("08_2560x1440")
	await _cleanup()
	var result := {"passed": failures.is_empty(), "failures": failures}
	var report := FileAccess.open(OUTPUT + "review.json", FileAccess.WRITE)
	report.store_string(JSON.stringify(result, "\t"))
	report.close()
	backdrop.queue_free()
	await process_frame
	print("SPELL_CODEX_REVIEW: ", JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)


func _open(data) -> void:
	unit = load("res://units/unit.gd").from_data(data)
	state = load("res://characters/progression/character_run_state.gd").new()
	state.initialize(unit, data)
	screen = load("res://ui/progression/screens/skill_tree_screen.tscn").instantiate()
	root.add_child(screen)
	if not screen.open_for_state(state, data.spells[0].skill_tree.discipline_id):
		failures.append("Cannot open hero " + data.unit_name)
	await _settle()


func _settle() -> void:
	for i in range(20):
		await process_frame


func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(OUTPUT + label + ".png"))
	image.save_jpg(ProjectSettings.globalize_path(OUTPUT + label + ".jpg"), 0.84)
	var snapshot: Dictionary = screen.get_layout_snapshot()
	var viewport := Rect2(Vector2.ZERO, Vector2(root.size))
	for field in ["outer_global", "header_global", "branch_global", "detail_global", "close_global"]:
		if not viewport.grow(2).encloses(snapshot[field]):
			failures.append("Offscreen %s at %s" % [field, label])


func _cleanup() -> void:
	if is_instance_valid(screen):
		screen.close_for_run_cleanup()
		screen.queue_free()
	await process_frame
	if state != null:
		state.dispose()
	state = null
	unit = null
	await process_frame


func _exercise_navigation() -> void:
	var tabs = screen.get_tab_buttons()
	await _click(tabs[3])
	_check(screen.current_discipline_id == tabs[3].discipline_id, "Mouse selects guard")
	_check(screen.get_detail_panel().get_spell_metrics_text().contains("10 points de bouclier"), "Guard metrics refresh")
	var search: LineEdit = screen.find_child("SpellSearch", true, false)
	await _click(search)
	for character in "garde":
		await _key(character.unicode_at(0), character.unicode_at(0))
	_check(screen.get_visible_tab_buttons().size() == 1, "Typed search filters real list")
	await _key(KEY_K, 107)
	_check(screen.visible, "Typing K inside search keeps modal open")
	_check(screen.get_visible_tab_buttons().is_empty(), "Typed unmatched query shows empty result")
	screen.set_search_query("")
	await _click(screen._filter_buttons[1])
	_check(screen.get_visible_tab_buttons().is_empty(), "Ready filter with no unlocked choice")
	await _click(screen._filter_buttons[0])
	_check(screen.get_visible_tab_buttons().size() == 4, "All filter restores four spells")
	await _click(tabs[0])
	var root_view = screen.get_graph().get_first_node_view()
	root_view.grab_focus()
	await _key(KEY_RIGHT)
	_check(root.gui_get_focus_owner() != root_view, "Keyboard moves from root to alternative")
	await _click(root_view)
	_check(screen.get_detail_panel().current_presentation_id == root_view.presentation_id, "Click restores base inspector")
	var other = screen.get_graph().get_node_views_in_focus_order()[1]
	var motion := InputEventMouseMotion.new()
	motion.position = other.get_global_rect().get_center()
	Input.parse_input_event(motion)
	await _settle()
	_check(screen.get_detail_panel().current_presentation_id == root_view.presentation_id, "Hover does not replace selected inspection")


func _exercise_selection_entry() -> void:
	var selection = load("res://ui/selection/CharacterSelectionScreen.tscn").instantiate()
	root.add_child(selection)
	await _settle()
	await _click(selection._spell_buttons[3])
	await _click(selection.find_child("ExploreMasteries", true, false))
	screen = selection.get_spell_tree()
	_check(is_instance_valid(screen), "Selection button opens spell codex")
	if is_instance_valid(screen):
		_check(screen.current_discipline_id == selection.get_selected_entry()["unit"].spells[3].skill_tree.discipline_id, "Selection opens current spell")
		await _capture("07_from_selection")
		await _key(KEY_ESCAPE)
		_check(selection.get_spell_tree() == null, "Escape returns to selection")
	selection.queue_free()
	screen = null
	await _settle()


func _key(code: int, unicode_value: int = 0) -> void:
	for pressed in [true, false]:
		var key := InputEventKey.new()
		key.keycode = code
		key.physical_keycode = code
		key.unicode = unicode_value
		key.pressed = pressed
		Input.parse_input_event(key)
		await process_frame
	await _settle()


func _click(control: Control) -> void:
	var point := control.get_global_rect().get_center()
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


func _check(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)
		push_error(description)
