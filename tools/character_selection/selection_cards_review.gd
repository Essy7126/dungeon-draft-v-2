extends "res://tools/catabase_run_balance_validation/ui_probe.gd"
## Public setup: actual pointer input, deck edits, revisits and departure payload.

func _run() -> void:
	_output_root = _argument("output")
	DirAccess.make_dir_recursive_absolute(_output_root)
	GameManager.set_reduced_motion_enabled(true)
	for dimensions in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(1200, 896)]:
		DisplayServer.window_set_size(dimensions)
		get_tree().root.size = dimensions
		GameManager.selected_run_variant = "cards"
		var screen = load("res://ui/selection/CharacterSelectionScreen.tscn").instantiate()
		add_child(screen)
		await _settle()
		var setup = screen._cards_setup
		for hero in 3:
			await _press(screen.find_child("Choice_%d" % hero, true, false))
			_check(setup.hero == hero, "appearance chosen by pointer", dimensions)
			await _capture("appearance_%d" % hero, dimensions, [setup._panel, setup._preview, screen.start_button])
		await _press(screen.find_child("SetupRotateRight", true, false))
		_check(setup._facing == 3, "hero rotation works", dimensions)
		await _press(screen.start_button)
		for id in ["assassin", "gardien", "arpenteur", "thaumaturge"]:
			await _press(screen.find_child("Choice_" + id, true, false))
			_check(setup.selection.class_id == id, "class " + id + " selected", dimensions)
			await _capture("class_" + id, dimensions, [setup._panel, setup._preview, screen.start_button])
		await _press(screen.start_button)
		await _press(screen.find_child("Starter_i_t_frost", true, false))
		await _press(screen.find_child("ToggleStarter", true, false))
		_check(screen.start_button.disabled, "incomplete deck blocks next step", dimensions)
		await _press(screen.find_child("Starter_i_t_guard", true, false))
		await _press(screen.find_child("ToggleStarter", true, false))
		_check(not screen.start_button.disabled, "five techniques unlock continuation", dimensions)
		await _capture("cards", dimensions, [setup._panel, setup._preview, screen.start_button])
		await _press(screen.start_button)
		await _press(screen.find_child("Choice_easy", true, false))
		await _capture("difficulty", dimensions, [setup._panel, screen.start_button])
		await _press(screen.start_button)
		await _capture("review", dimensions, [setup._panel, screen.start_button])
		var payload: Dictionary = setup.payload()
		await _press(screen.find_child("SetupStep_1", true, false))
		await _press(screen.find_child("Choice_assassin", true, false))
		await _press(screen.find_child("Choice_thaumaturge", true, false))
		_check(setup.payload() == payload, "class revisit preserves custom deck and difficulty", dimensions)
		await _press(screen.find_child("SetupStep_4", true, false))
		_check(screen.prepare_adventure(GameManager), "public selection prepares real run", dimensions)
		_check(GameManager._cards_departure_selection == payload, "departure transfers complete build", dimensions)
		_check(Rect2(Vector2.ZERO, Vector2(dimensions)).encloses(screen.start_button.get_global_rect()), "launch fully fits viewport", dimensions)
		screen.queue_free()
		await _settle()
		GameManager.cleanup_run_state()
	var passed: bool = _checks.all(func(c): return c.passed)
	var report := FileAccess.open(_output_root.path_join("report.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify({"passed": passed, "checks": _checks, "captures": _captures}, "\t"))
	report.close()
	get_tree().quit(0 if passed else 1)


func _press(button: Button) -> void:
	if button == null or button.disabled:
		push_error("Selection review: missing or disabled button")
		return
	var point := button.get_global_rect().get_center()
	get_viewport().warp_mouse(point)
	var motion := InputEventMouseMotion.new()
	motion.position = point
	get_viewport().push_input(motion)
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		get_viewport().push_input(event)
		await get_tree().process_frame
	await _settle()
