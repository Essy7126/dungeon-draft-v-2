extends Node
## Real title -> selection -> codex navigation, in isolated user data.
var _output := ""
var _review_size := Vector2i.ZERO
var _checks := 0
var _failures: Array[String] = []
var _captures: Array[String] = []


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("review_resolution="):
			var dimensions := argument.trim_prefix("review_resolution=").split("x")
			_review_size = Vector2i(int(dimensions[0]), int(dimensions[1]))
	_run.call_deferred()


func _run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("output_dir="):
			_output = argument.trim_prefix("output_dir=")
	if _output.is_empty():
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_output)
	GameManager.set_reduced_motion_enabled(true)
	# Keep this review runner alive across the actual title scene transition.
	var title: Node = load("res://ui/TitreEcran.tscn").instantiate()
	get_tree().root.add_child(title)
	get_tree().current_scene = title
	await _settle()
	var start := title.get_node("UI/Boutons/BoutonNouvellePartie") as Button
	_check(not start.disabled, "Reduced motion ends the intro and enables the menu")
	_check(start.has_focus(), "Primary menu action has keyboard focus")
	await _capture("title", [start, title.get_node("UI/Boutons/BoutonQuitter")])
	await _click(start)
	var selection := get_tree().current_scene as CharacterSelectionScreen
	_check(selection != null, "Actual New Adventure click opens character selection")
	if selection == null:
		await _finish()
		return
	await _capture("selection", [selection.start_button, selection.get("_details")])
	var opening := selection.find_child("ExploreMasteries", true, false) as Button
	await _click(opening)
	var host := selection.get_spell_tree()
	_check(host != null and host.visible, "Actual selection button opens the grimoire")
	if host == null:
		await _finish()
		return
	var codex := host.get_champion_codex() as ChampionCodex
	_check(codex != null and codex.read_only, "Selection grimoire stays consultative")
	if codex == null:
		await _finish()
		return
	var before := codex.character_state.get_progression_snapshot()
	var nav: Dictionary = codex.get("_nav_buttons")
	await _click(nav[&"achilles_lesson_of_chiron"])
	_check(
		codex.get("_section_id") == &"achilles_lesson_of_chiron",
		"Doctrine click navigates through the material",
	)
	var nodes := codex.get_node_buttons()
	var first := nodes.values()[0] as Button
	await _click(first)
	_check(
		codex.get("_selected_node_id") == first.get_meta("mastery_id"),
		"Mouse inspects the actual mastery",
	)
	_check(codex.get_action_button().disabled, "Read-only inspection cannot spend points")
	await _capture("champion_doctrine", _codex_bounds(codex))
	await _click((codex.get("_spells") as HBoxContainer).get_child(0))
	_check(codex.get("_selected_spell") != null, "Technique strip opens real spell details")
	await _capture("champion_technique", _codex_bounds(codex))
	_check(
		codex.character_state.get_progression_snapshot() == before,
		"Navigation preserves the progression snapshot",
	)
	await _click(codex.get_close_button())
	_check(selection.get_spell_tree() == null, "Close releases the selection grimoire")
	_check(
		get_viewport().gui_get_focus_owner() != null
		and get_viewport().gui_get_focus_owner().is_visible_in_tree(),
		"Closing restores visible keyboard focus",
	)
	# Public navigation now exposes Catabase appearances only.
	_check(selection.get_entries().size() == 2, "Only Catabase remains in public selection")
	var roster: Array = selection.get("_roster_buttons")
	await _click(roster[1])
	_check(selection.get_selected_entry().get("id") == &"achilles_painted_g", "Roster selects painted Achille")
	selection.queue_free()
	get_tree().current_scene = null
	await _settle()
	# Authored Champion profile used by selection, with one disposable point.
	# The canonical expedition has its own tree and deliberately disables this currency.
	var run := load("res://data/runs/odyssey.tres") as RunData
	var resolved := RunHeroResolver.resolve_runtime_hero_data(run, false)
	_check(resolved.is_valid(), "Authored Champion profile resolves for isolated purchase fixture")
	var state := CharacterRunState.new()
	_check(
		state.initialize(Unit.from_data(resolved.heroes[0]), resolved.heroes[0]),
		"Disposable Champion state initializes",
	)
	_check(
		state.champion_progression.grant_purchased_mastery(1),
		"Authored profile permits the fixture point",
	)
	codex = load("res://ui/progression/champion/champion_codex.gd").new()
	codex.configure(state, false)
	get_tree().root.add_child(codex)
	await _settle()
	codex.inspect_node(&"achilles_wrath_focused_fury")
	await _settle()
	var action := codex.get_action_button()
	_check(not action.disabled, "Available mastery enables the primary action")
	await _capture("champion_available", _codex_bounds(codex))
	await _click(action)
	_check(
		state.champion_progression.selected_node_ids.has(&"achilles_wrath_focused_fury"),
		"Actual purchase button acquires the selected mastery",
	)
	_check(
		state.champion_progression.unspent_mastery_points == 0,
		"Purchase spends exactly one mastery point",
	)
	_check(action.disabled, "Acquired mastery cannot be purchased again")
	await _capture("champion_acquired", _codex_bounds(codex))
	codex.queue_free()
	await _settle()
	state.dispose()
	await _finish()


func _codex_bounds(codex: ChampionCodex) -> Array:
	return [
		codex.get("_main"),
		codex.get("_nav_panel"),
		codex.get("_detail_panel"),
		codex.get_action_button(),
		codex.get_close_button(),
	]


func _click(button: Button) -> void:
	_check(
		button != null and button.is_visible_in_tree() and not button.disabled,
		"Control is reachable",
	)
	if button == null:
		return
	var point := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	Input.parse_input_event(motion)
	await get_tree().process_frame
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = point
		event.global_position = point
		Input.parse_input_event(event)
		await get_tree().process_frame
	await _settle()


func _settle() -> void:
	if _review_size != Vector2i.ZERO and get_window().size != _review_size:
		get_window().mode = Window.MODE_WINDOWED
		get_window().size = _review_size
	for index in range(12):
		await get_tree().process_frame
	await get_tree().create_timer(0.2).timeout


func _capture(label: String, controls: Array) -> void:
	for control: Control in controls:
		_check(
			get_viewport().get_visible_rect().grow(2).encloses(control.get_global_rect()),
			label + " contained: " + control.name,
		)
	# Clear hover to show persistent selection and avoid screenshot tooltips.
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(2, 2)
	Input.parse_input_event(motion)
	await _settle()
	await RenderingServer.frame_post_draw
	_check(
		_review_size == Vector2i.ZERO or Vector2i(get_viewport().get_texture().get_size()) == _review_size,
		label + " requested resolution",
	)
	_check(get_viewport().get_texture().get_image().save_png(_output.path_join(label + ".png")) == OK, label
		+ " screenshot saved")
	_captures.append(label)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	GameManager.cleanup_run_state()
	await _settle()
	var file := FileAccess.open(_output.path_join("report.json"), FileAccess.WRITE)
	file.store_string(
		JSON.stringify({ "checks": _checks, "failures": _failures, "captures": _captures }, "\t")
	)
	file.close()
	print("Menu chrome: %d checks, %d failures" % [_checks, _failures.size()])
	for failure in _failures:
		printerr(failure)
	get_tree().quit(0 if _failures.is_empty() else 1)
