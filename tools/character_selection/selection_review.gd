extends SceneTree
## Reproducible rendered review. Run with --script and a normal renderer.

const OUTPUT := "res://artifacts/character_selection/"
var screen
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var ignore := FileAccess.open(OUTPUT + ".gdignore", FileAccess.WRITE)
	ignore.close()
	screen = load("res://ui/selection/CharacterSelectionScreen.tscn").instantiate()
	root.add_child(screen)
	current_scene = screen
	await _settle()
	await _capture("01_achille")
	await _click(screen._spell_buttons[3])
	_check(screen.selected_spell_index == 3, "Clicking guard selects its real details")
	await _capture("02_garde")
	await _click(screen._tab_buttons[1])
	_check(screen._lore.visible, "Lore tab can be opened by mouse")
	await _capture("03_histoire")
	await _click(screen._roster_buttons[2])
	_check(screen.selected_index == 2, "Mouse selects Mage")
	await _click(screen._tab_buttons[0])
	await _capture("04_mage")
	screen.select_character(0)
	root.size = Vector2i(1200, 896)
	await _settle()
	await _capture("05_1200x896")
	root.size = Vector2i(1920, 1080)
	await _settle()
	await _capture("06_1920x1080")
	# Verify the real title -> selection -> intro route, without starting combat.
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	Input.parse_input_event(escape)
	await process_frame
	escape = escape.duplicate()
	escape.pressed = false
	Input.parse_input_event(escape)
	await _settle()
	_check(current_scene.scene_file_path == "res://ui/TitreEcran.tscn", "Escape returns to title without error")
	var title = current_scene
	title.get_node("UI/Boutons/BoutonNouvellePartie").pressed.emit()
	await _settle()
	_check(current_scene.has_method("select_character"), "Title opens selection")
	if current_scene.has_method("select_character"):
		var selection = current_scene
		await _click(selection.start_button)
		_check(current_scene.scene_file_path == "res://cinematics/intro/intro_cinematic.tscn", "Primary button opens intro")
		var manager := root.get_node("GameManager")
		var chosen = manager.peek_next_run_data()
		_check(chosen != null and chosen.resource_path == "res://data/runs/odyssey.tres", "Selected Catabase run reaches intro")
		manager.clear_next_run_configuration()
	if is_instance_valid(current_scene):
		current_scene.queue_free()
	await process_frame
	await process_frame
	var result := {"passed": failures.is_empty(), "failures": failures, "sizes": ["1440x900", "1200x896", "1920x1080"]}
	var file := FileAccess.open(OUTPUT + "review.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	file.close()
	print("CHARACTER_SELECTION_REVIEW: ", JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)


func _settle() -> void:
	for i in range(35):
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
	var image := root.get_texture().get_image()
	_check(image != null and not image.is_empty(), "Viewport image exists: " + label)
	if image != null:
		image.save_png(ProjectSettings.globalize_path(OUTPUT + label + ".png"))
		image.save_jpg(ProjectSettings.globalize_path(OUTPUT + label + ".jpg"), 0.83)


func _check(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)
		push_error(description)
