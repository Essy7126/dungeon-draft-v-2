extends SceneTree
## Real-renderer review of the illustrated classic selection; never launches a run.

const OUTPUT := "res://artifacts/character_selection_classic/"
var screen
var failures: Array[String] = []
var captures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var ignore := FileAccess.open(OUTPUT + ".gdignore", FileAccess.WRITE)
	ignore.close()
	var manager := root.get_node("GameManager")
	var before: Dictionary = manager.get_inventory_equipment_snapshot().duplicate(true)
	manager.selected_run_variant = "classic"
	screen = load("res://ui/selection/CharacterSelectionScreen.tscn").instantiate()
	root.add_child(screen)
	current_scene = screen
	await _settle()
	_check(screen.get_entries().size() == 3, "Three public appearances")
	_check(screen._pose_buttons.is_empty(), "No animation controls")
	_check(screen._canvas.get_node_or_null("RotateLeft") == null, "No rotation control")
	_check(not screen.get_preview().visible, "Illustration replaces animated preview")
	for resolution in [Vector2i(1920, 1080), Vector2i(1280, 720), Vector2i(1440, 900)]:
		root.size = resolution
		await _settle()
		await _capture("classic_%dx%d" % [resolution.x, resolution.y])
		_check_layout()
	root.size = Vector2i(1920, 1080)
	for index in screen.get_entries().size():
		await _click(screen._roster_buttons[index])
		_check(screen.selected_index == index, "Mouse selects appearance %d" % index)
		_check(screen._hero_art.texture != null, "Selected illustration exists")
		_check(screen._roster_buttons[index].button_pressed, "Selection feedback")
		_check(
			screen.get_selected_entry().unit.get_effective_unit_id() == &"achilles",
			"Appearance keeps Achilles gameplay",
		)
		_check(screen._spell_buttons.size() == 4, "Four techniques remain")
		await _capture("appearance_%d" % index)
	await _click(screen._spell_buttons[3])
	_check(screen.selected_spell_index == 3, "Technique details respond to mouse")
	await _capture("guard")
	await _click(screen._tab_buttons[1])
	_check(screen._lore.is_visible_in_tree(), "History tab responds to mouse")
	await _capture("history")
	await _click(screen._lore.get_node("ExploreMasteriesFromLore"))
	_check(screen.get_spell_tree() != null, "Masteries open")
	if screen.get_spell_tree() != null:
		screen.get_spell_tree().close_screen()
		await _settle()
		_check(
			root.gui_get_focus_owner() == screen._lore.get_node("ExploreMasteriesFromLore"),
			"Focus returns after masteries",
		)
	await _click(screen._tab_buttons[0])
	await _click(screen._roster_buttons[0])
	await _capture("final_1920x1080")
	_check(
		manager.get_inventory_equipment_snapshot() == before,
		"Browsing does not change inventory",
	)
	var report := {
		"passed": failures.is_empty(),
		"checks": checks,
		"failures": failures,
		"captures": captures,
	}
	var file := FileAccess.open(OUTPUT + "review.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	quit(0 if failures.is_empty() else 1)


func _check_layout() -> void:
	var folio := screen._canvas.get_node("CharacterFolio") as Control
	_check(not folio.get_global_rect().intersects(screen._hero_art.get_global_rect()), "Hero and folio do not overlap")
	for button in screen._roster_buttons:
		_check(not button.get_global_rect().intersects(screen._hero_art.get_global_rect()), "Roster and hero do not overlap")
	_check(
		Rect2(Vector2.ZERO, Vector2(root.size)).encloses(screen.start_button.get_global_rect()),
		"Primary action fits viewport",
	)


func _settle() -> void:
	for i in range(30):
		await process_frame


func _click(button: Button) -> void:
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


func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	var screenshot := root.get_texture().get_image()
	_check(screenshot != null and not screenshot.is_empty(), "Rendered capture exists")
	if screenshot != null:
		screenshot.save_png(ProjectSettings.globalize_path(OUTPUT + label + ".png"))
		captures.append(label)


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		push_error(description)
