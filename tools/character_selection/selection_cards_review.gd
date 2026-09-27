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
			await _capture(
				"appearance_%d" % hero,
				dimensions,
				[setup._panel, setup._preview, screen.start_button],
			)
		await _press(screen.find_child("SetupRotateRight", true, false))
		_check(setup._facing == 3, "hero rotation works", dimensions)
		await _press(screen.start_button)
		for id in ["assassin", "gardien", "arpenteur", "thaumaturge"]:
			await _press(screen.find_child("Choice_" + id, true, false))
			_check(setup.selection.class_id == id, "class " + id + " selected", dimensions)
			await _capture(
				"class_" + id,
				dimensions,
				[setup._panel, setup._preview, screen.start_button],
			)
		await _press(screen.start_button)
		await _press(screen.find_child("Starter_i_t_frost", true, false))
		await _press(screen.find_child("ToggleStarter", true, false))
		_check(screen.start_button.disabled, "incomplete deck blocks next step", dimensions)
		await _press(screen.find_child("Starter_i_t_guard", true, false))
		await _press(screen.find_child("ToggleStarter", true, false))
		_check(not screen.start_button.disabled, "five techniques unlock continuation", dimensions)
		_check(
			"i_t_guard" in setup.selection.card_families
			and "i_t_frost" not in setup.selection.card_families,
			"chosen card replaces removed card",
			dimensions,
		)
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
		_check(
			setup.payload() == payload,
			"class revisit preserves custom deck and difficulty",
			dimensions,
		)
		await _press(screen.find_child("SetupStep_4", true, false))
		var escape := InputEventAction.new()
		escape.action = &"ui_cancel"
		escape.pressed = true
		get_viewport().push_input(escape)
		await _settle()
		_check(setup.step == 3, "Escape returns one step without leaving selection", dimensions)
		await _press(screen.start_button)
		_check(
			screen.prepare_adventure(GameManager),
			"public selection prepares real run",
			dimensions,
		)
		_check(
			GameManager._cards_departure_selection == payload,
			"departure transfers complete build",
			dimensions,
		)
		_check(
			Rect2(Vector2.ZERO, Vector2(dimensions)).encloses(screen.start_button.get_global_rect()),
			"launch fully fits viewport",
			dimensions,
		)
		screen.queue_free()
		await _settle()
		GameManager.cleanup_run_state()
		GameManager.selected_run_variant = "classic"
		var classic = load("res://ui/selection/CharacterSelectionScreen.tscn").instantiate()
		add_child(classic)
		await _settle()
		for index in 3:
			await _press(classic._roster_buttons[index])
			_check(
				classic.selected_index == index,
				"classic appearance remains selectable",
				dimensions,
			)
		await _capture(
			"classic",
			dimensions,
			[classic.start_button, classic._preview, classic._roster_buttons[2]],
		)
		classic.queue_free()
		await _settle()
	var passed: bool = _checks.all(
		func(c):
			return c.passed,
	)
	var report := FileAccess.open(_output_root.path_join("report.json"), FileAccess.WRITE)
	report.store_string(
		JSON.stringify({ "passed": passed, "checks": _checks, "captures": _captures }, "\t")
	)
	report.close()
	get_tree().quit(0 if passed else 1)


func _press(button: Button) -> void:
	if button == null or button.disabled:
		_check(false, "requested button exists and is enabled", get_tree().root.size)
		push_error("Selection review: missing or disabled button")
		return
	var ancestor := button.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			ancestor.ensure_control_visible(button)
			await _settle()
		ancestor = ancestor.get_parent()
	var point := button.get_global_rect().get_center()
	# Keep the native desktop pointer free. Feed both button events in one frame
	# so an OS mouse-move from a concurrent user interaction cannot split the click.
	var pressed := [false]
	var observe := func(): pressed[0] = true
	button.pressed.connect(observe, CONNECT_ONE_SHOT)
	var button_name := str(button.name)
	var motion := InputEventMouseMotion.new()
	motion.position = point
	get_viewport().push_input(motion)
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		get_viewport().push_input(event)
	await _settle()
	_check(pressed[0], "pointer activates " + button_name, get_tree().root.size)
	if is_instance_valid(button) and button.pressed.is_connected(observe):
		button.pressed.disconnect(observe)
