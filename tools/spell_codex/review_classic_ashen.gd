extends SceneTree
## Native visual review using disposable trio states, never a saved run.

const OUTPUT := "res://artifacts/mastery_atlas/"
var _screen
var _state
var _failures: Array[String] = []
var _captures := 0
var _checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var fixture = load("res://data/runs/run_data.gd").new()
	fixture.content_profile = load("res://data/runs/profiles/main_content_profile.tres")
	var resolution = load("res://core/run_content/run_hero_resolver.gd").resolve_runtime_hero_data(fixture, false)
	var backdrop: Control = load("res://ui/selection/selection_backdrop.gd").new()
	root.add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for hero_id in [&"warrior", &"mage", &"elf"]:
		root.size = Vector2i(1440, 900)
		var hero
		for candidate in resolution.heroes:
			if candidate.get_effective_unit_id() == hero_id:
				hero = candidate
		_state = load("res://characters/progression/character_run_state.gd").new()
		_check(_state.initialize(load("res://units/unit.gd").from_data(hero), hero), "State initializes: " + str(hero_id))
		_screen = load("res://ui/progression/screens/skill_tree_screen.tscn").instantiate()
		root.add_child(_screen)
		_check(_screen.open_for_state(_state), "Screen opens: " + str(hero_id))
		await _settle()
		var snapshot: Dictionary = _state.get_progression_snapshot()
		var tabs: Array = _screen.get_tab_buttons()
		await _click(tabs[1])
		_check(_screen.current_discipline_id == tabs[1].discipline_id, "Material preserves tab click: " + str(hero_id))
		await _click(tabs[0])
		_check(_state.get_progression_snapshot() == snapshot, "Inspection preserves progression: " + str(hero_id))
		await _capture("classic_%s_1440x900" % hero_id)
		if hero_id == &"warrior":
			var spell = _state.unit.spells[0]
			_state.add_spell_xp(spell.get_effective_spell_id(), spell.skill_tree.ranks[1].required_total_xp)
			_screen.refresh_from_state()
			await _settle()
			var choices: Array = _screen.get_graph().get_node_views_in_focus_order()
			if choices.size() > 1:
				await _click(choices[1])
			await _capture("classic_warrior_available_1440x900")
			root.size = Vector2i(1280, 720)
			await _settle()
			await _capture("classic_warrior_available_1280x720")
			root.size = Vector2i(1920, 1080)
			await _settle()
			await _capture("classic_warrior_available_1920x1080")
		_screen.close_for_run_cleanup()
		_screen.queue_free()
		await process_frame
		_state.dispose()
		_state = null
		await process_frame
	backdrop.queue_free()
	await process_frame
	var report := {"passed": _failures.is_empty(), "captures": _captures, "checks": _checks, "failures": _failures}
	var file := FileAccess.open(OUTPUT + "classic_review.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("CLASSIC_ASHEN_REVIEW: ", JSON.stringify(report))
	quit(0 if _failures.is_empty() else 1)


func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(OUTPUT + label + ".png"))
	image.save_jpg(ProjectSettings.globalize_path(OUTPUT + label + ".jpg"), 0.88)
	_captures += 1
	var bounds := Rect2(Vector2.ZERO, Vector2(root.size))
	var layout: Dictionary = _screen.get_layout_snapshot()
	for key in ["outer_global", "header_global", "branch_global", "detail_global", "close_global"]:
		_check(bounds.grow(2).encloses(layout[key]), "Visible %s in %s" % [key, label])
	for panel in [_screen.get("_character_header"), _screen.get("_branch_navigation"), _screen.get("_canvas_surface"), _screen.get_detail_panel()]:
		var surface := panel.get_node("AshenMaterialLayer/MaterialSurface") as Control
		_check(surface.size.is_equal_approx(panel.size), "Material fits " + str(panel.name))


func _settle() -> void:
	for index in range(16):
		await process_frame


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


func _check(value: bool, message: String) -> void:
	_checks += 1
	if not value:
		_failures.append(message)
