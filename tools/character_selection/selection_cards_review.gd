extends "res://tools/catabase_run_balance_validation/ui_probe.gd"
## Real pointer and keyboard review; the caller isolates APPDATA before launch.


func _run() -> void:
	_output_root = _argument("output")
	DirAccess.make_dir_recursive_absolute(_output_root)
	_check(DisplayServer.get_name() != "headless", "real renderer", Vector2i(1280, 720))
	GameManager.set_reduced_motion_enabled(true)
	for dimensions in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
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
				[setup._hero_art, screen.start_button],
			)
		await _capture("main", dimensions, [setup._summary, screen.start_button])
		await _review_hover(setup, dimensions)
		_check_summary(setup, dimensions)
		await _press(screen.find_child("Socle_class", true, false))
		for id in ["assassin", "gardien", "arpenteur", "thaumaturge"]:
			await _press(screen.find_child("Choice_" + id, true, false))
			_check(setup.selection.class_id == id, "class " + id + " selected", dimensions)
			await _capture("class_" + id, dimensions, [setup._panel])
			_check_window(setup, dimensions)
			_check_summary(setup, dimensions)
		await _press(screen.find_child("ClassDetailsToggle", true, false))
		await _capture("class_details", dimensions, [setup._panel])
		await _press(screen.find_child("ConfirmPreparation", true, false))
		_check(
			screen.find_child("Socle_class", true, false).has_focus(),
			"class focus restored",
			dimensions,
		)
		await _press(screen.find_child("Socle_deck", true, false))
		await _press(screen.find_child("Starter_t01", true, false))
		await _press(screen.find_child("RemoveStarter", true, false))
		_check(screen.start_button.disabled, "incomplete deck blocks launch", dimensions)
		await _press(screen.find_child("Starter_n01", true, false))
		_check(
			screen.find_child("StarterCategory", true, false).text == "Commune · toutes classes",
			"common affinity",
			dimensions,
		)
		await _press(screen.find_child("ToggleStarter", true, false))
		_check(not screen.start_button.disabled, "fifteen copies unlock launch", dimensions)
		_check(
			setup.selection.card_families.count("n01") == 1 and setup.selection.card_families.count(
				"t01"
			)
			== 2,
			"copy replacement",
			dimensions,
		)
		await _press(screen.find_child("Starter_t01", true, false))
		await _capture(
			"deck",
			dimensions,
			[
				setup._panel,
				screen.find_child("ToggleStarter", true, false),
				screen.find_child("RemoveStarter", true, false),
			],
		)
		_check_window(setup, dimensions)
		# Every catalog pile is reachable by pointer through its scrolling grid.
		for id in setup.Catalog.starter_pool(setup.selection.class_id):
			await _press(screen.find_child("Starter_" + id, true, false))
			_check(setup._inspected == id, "inspect " + id, dimensions)
		await _press(screen.find_child("CardScalingToggle", true, false))
		_check(setup._show_scaling, "power details accessible", dimensions)
		await _capture("deck_power", dimensions, [setup._panel])
		await _press(screen.find_child("DeckHelpToggle", true, false))
		_check(setup._show_deck_help, "deck help opens above preparation", dimensions)
		await _capture("deck_help", dimensions, [setup._panel])
		var key := InputEventKey.new()
		key.keycode = KEY_ESCAPE
		key.physical_keycode = KEY_ESCAPE
		key.pressed = true
		get_viewport().push_input(key)
		await _settle()
		_check(
			not setup._show_deck_help and setup._modal == "deck",
			"Escape closes topmost help only",
			dimensions,
		)
		_check(
			screen.find_child("DeckHelpToggle", true, false).has_focus(),
			"help focus restored",
			dimensions,
		)
		# Tab never reaches a control behind the preparation overlay.
		for index in 20:
			var tab := InputEventKey.new()
			tab.keycode = KEY_TAB
			tab.pressed = true
			get_viewport().push_input(tab)
			await _settle()
			_check(setup._panel.is_ancestor_of(get_viewport().gui_get_focus_owner()), "Tab stays in preparation", dimensions)
		await _escape()
		_check(setup._modal.is_empty(), "Escape closes preparation", dimensions)
		_check(
			screen.find_child("Socle_deck", true, false).has_focus(),
			"deck focus restored",
			dimensions,
		)
		await _press(screen.find_child("Socle_elements", true, false))
		var fire: SpinBox = screen.find_child("DepartureMastery_fire", true, false)
		var water: SpinBox = screen.find_child("DepartureMastery_water", true, false)
		fire.value = 3
		water.value = 4
		_check(
			setup.selection.masteries.fire == 3 and setup.selection.masteries.water == 1,
			"four point cap",
			dimensions,
		)
		water.value = 0
		await _capture("elements", dimensions, [setup._panel, fire, water])
		_check_window(setup, dimensions)
		await _press(screen.find_child("ClosePreparation", true, false))
		await _press(screen.find_child("Socle_difficulty", true, false))
		await _press(screen.find_child("Choice_easy", true, false))
		await _capture("difficulty", dimensions, [setup._panel])
		_check_window(setup, dimensions)
		await _press(screen.find_child("ConfirmPreparation", true, false))
		var payload: Dictionary = setup.payload()
		await _press(screen.find_child("Socle_class", true, false))
		await _press(screen.find_child("Choice_assassin", true, false))
		await _press(screen.find_child("Choice_thaumaturge", true, false))
		_check(
			setup.payload() == payload,
			"class revisit preserves custom deck, masteries and difficulty",
			dimensions,
		)
		await _escape()
		await _capture("prepared", dimensions, [setup._summary, screen.start_button])
		_check_summary(setup, dimensions)
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
		screen.queue_free()
		await _settle()
		GameManager.cleanup_run_state()
		GameManager.selected_run_variant = "classic"
		var classic = load("res://ui/selection/CharacterSelectionScreen.tscn").instantiate()
		add_child(classic)
		await _settle()
		for index in 3:
			await _press(classic._roster_buttons[index])
			_check(classic.selected_index == index, "classic appearance selectable", dimensions)
		await _capture("classic", dimensions, [classic.start_button, classic._hero_art])
		classic.queue_free()
		await _settle()
	for dimensions in [Vector2i(1200, 896), Vector2i(1280, 800), Vector2i(2560, 1080)]:
		DisplayServer.window_set_size(dimensions)
		get_tree().root.size = dimensions
		GameManager.selected_run_variant = "cards"
		var screen = load("res://ui/selection/CharacterSelectionScreen.tscn").instantiate()
		add_child(screen)
		await _settle()
		var setup = screen._cards_setup
		await _capture("main", dimensions, [setup._summary, screen.start_button])
		_check_summary(setup, dimensions)
		var controls: Array[Control] = [
			screen.start_button,
			setup.find_child("CardsDepartureSummary", true, false),
		]
		controls.append_array(setup._portraits)
		controls.append_array(setup._socles.values())
		var viewport := Rect2(Vector2.ZERO, Vector2(dimensions))
		for control in controls:
			_check(
				viewport.encloses(control.get_global_rect()),
				"complete control fits " + str(control.name),
				dimensions,
			)
			for other in controls:
				if control != other:
					_check(
						not control.get_global_rect().intersects(other.get_global_rect()),
						"controls do not overlap",
						dimensions,
					)
		for key in setup._socles:
			await _press(setup._socles[key])
			_check_window(setup, dimensions)
			await _press(screen.find_child("ClosePreparation", true, false))
		screen.queue_free()
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


func _review_hover(setup, dimensions: Vector2i) -> void:
	for kind in ["class", "deck", "elements", "difficulty"]:
		var button: Button = setup._socles[kind]
		var object: Control = button.get_node("Object")
		var shader_material := object.material as ShaderMaterial
		for state in ["hover", "pressed", "focus"]:
			_check(
				button.get_theme_stylebox(state) is StyleBoxEmpty,
				"no rectangular " + state + " frame for " + kind,
				dimensions,
			)
		var focused := get_viewport().gui_get_focus_owner()
		if focused != null:
			focused.release_focus()
		var motion := InputEventMouseMotion.new()
		motion.position = button.get_global_rect().get_center()
		get_viewport().push_input(motion)
		await _settle()
		_check(
			bool(shader_material.get_shader_parameter("highlighted")),
			"pointer highlights " + kind,
			dimensions,
		)
		await super._capture("hover_" + kind, dimensions, [button])
		motion.position = Vector2(2, 2)
		get_viewport().push_input(motion)
		await _settle()
		_check(
			not bool(shader_material.get_shader_parameter("highlighted")),
			"pointer exit clears " + kind,
			dimensions,
		)
		button.grab_focus()
		await _settle()
		_check(
			bool(shader_material.get_shader_parameter("highlighted")),
			"keyboard focus highlights " + kind,
			dimensions,
		)
		await super._capture("focus_" + kind, dimensions, [button])
		button.release_focus()
		await _settle()
		_check(
			not bool(shader_material.get_shader_parameter("highlighted")),
			"focus exit clears " + kind,
			dimensions,
		)


func _escape() -> void:
	var event := InputEventAction.new()
	event.action = &"ui_cancel"
	event.pressed = true
	get_viewport().push_input(event)
	await _settle()


func _capture(label: String, dimensions: Vector2i, controls: Array) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(2, 2)
	get_viewport().push_input(motion)
	await super._capture(label, dimensions, controls)


func _check_window(setup, dimensions: Vector2i) -> void:
	var viewport := Rect2(Vector2.ZERO, Vector2(dimensions))
	_check(viewport.encloses(setup._panel.get_global_rect()), "window fits viewport", dimensions)
	for name in ["ClosePreparation", "ConfirmPreparation", "PreparationCounter"]:
		_check(setup._panel.get_global_rect().encloses(
				setup.find_child(name, true, false).get_global_rect()
			), "window encloses " + name, dimensions)


func _check_summary(setup, dimensions: Vector2i) -> void:
	var folio: Control = setup.find_child("CardsDepartureSummary", true, false)
	for label in setup._summary.find_children("*", "Label", true, false):
		_check(folio.get_global_rect().encloses(label.get_global_rect()), "summary label fits "
			+ label.text, dimensions)


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
	var observe := func():
		pressed[0] = true
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
