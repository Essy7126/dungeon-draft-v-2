extends Node
## Rendered public-menu regression. Launch with isolated APPDATA / LOCALAPPDATA.
const OUTPUT := "res://artifacts/dev/catabase-title-review"
var _checks := 0
var _failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var save_path := GameManager.expedition_save_path
	var fixture := OUTPUT.path_join("invalid-save-%d.json" % Time.get_ticks_usec())
	GameManager.expedition_save_path = fixture
	GameManager.set_reduced_motion_enabled(true)
	var title: Node = load("res://ui/TitreEcran.tscn").instantiate()
	get_tree().root.add_child(title)
	get_tree().current_scene = title
	await _settle()
	var start := title.get_node("UI/Boutons/BoutonNouvellePartie") as Button
	_check(start.has_focus() and not start.disabled, "New game is immediately keyboard-accessible")
	_check(
		title.find_child("BoutonReprendreCatabase", true, false) == null,
		"No continue action without a checkpoint",
	)
	for resolution in [
		Vector2i(1280, 720),
		Vector2i(1200, 896),
		Vector2i(1920, 1080),
		Vector2i(2560, 1080),
	]:
		get_window().size = resolution
		await _settle()
		for control in [
			title.get_node("UI/Logo"),
			title.get_node("UI/Subtitle"),
			title.get_node("UI/Boutons"),
			title.get("_motion_toggle"),
		]:
			_check(
				get_viewport().get_visible_rect().encloses(control.get_global_rect()),
				"%s fits %s" % [control.name, resolution],
			)
		await _capture("title_%dx%d" % [resolution.x, resolution.y])
	get_window().size = Vector2i(1920, 1080)
	await _settle()
	var before := await _pixels()
	await get_tree().create_timer(0.35).timeout
	_check(before == await _pixels(), "Reduced motion freezes every painted shader effect")
	var toggle := title.get("_motion_toggle") as CheckButton
	await _click(toggle)
	_check(not GameManager.is_reduced_motion_enabled(), "Actual toggle enables scene animation")
	before = await _pixels()
	await get_tree().create_timer(1.1).timeout
	_check(before != await _pixels(), "The rendered painting changes over time")
	await _capture("title_animated")
	await _click(toggle)
	_check(GameManager.is_reduced_motion_enabled(), "Actual toggle freezes the painting again")
	await _click(start)
	var selection := get_tree().current_scene as CharacterSelectionScreen
	_check(selection != null, "New game click opens real selection")
	if selection != null:
		_check(
			selection.get_entries().size() == 2,
			"Public selection contains only two Catabase appearances",
		)
		for entry in selection.get_entries():
			_check(
				(entry.run as RunData).catabase_route_enabled,
				"Every public entry launches Catabase",
			)
		await _capture("selection_catabase")
		selection.request_back()
		await _settle()
	_check(
		get_tree().current_scene.scene_file_path == "res://ui/TitreEcran.tscn",
		"Back returns to Catabase title",
	)
	# Bad saves must remain untouched, with an explicit recoverable notice.
	var file := FileAccess.open(fixture, FileAccess.WRITE)
	file.store_string('{}')
	file.close()
	var hash_before := FileAccess.get_sha256(fixture)
	get_tree().reload_current_scene()
	await _settle()
	title = get_tree().current_scene
	var resume := title.find_child("BoutonReprendreCatabase", true, false) as Button
	_check(
		resume != null and resume.has_focus(),
		"Existing checkpoint makes Continue the focused action",
	)
	if resume != null:
		await _click(resume)
		_check(
			get_tree().current_scene == title and title.get("_notice").visible,
			"Unreadable save displays a notice and keeps the menu usable",
		)
		_check(
			FileAccess.get_sha256(fixture) == hash_before,
			"Failed resume preserves the checkpoint bytes",
		)
		await _capture("title_save_notice")
	DirAccess.remove_absolute(fixture)
	GameManager.expedition_save_path = save_path
	GameManager.cleanup_run_state()
	var report := FileAccess.open(OUTPUT.path_join("report.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify({ "checks": _checks, "failures": _failures }, "\t"))
	report.close()
	print("Catabase title: %d checks, %d failures" % [_checks, _failures.size()])
	get_tree().quit(0 if _failures.is_empty() else 1)


func _settle() -> void:
	for index in range(12):
		await get_tree().process_frame
	await get_tree().create_timer(0.15).timeout


func _pixels() -> PackedByteArray:
	await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image().get_data()


func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	var result := get_viewport().get_texture().get_image().save_png(
		OUTPUT.path_join(label + ".png")
	)
	_check(result == OK, "Saved capture " + label)


func _click(button: Button) -> void:
	var point := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	Input.parse_input_event(motion)
	await get_tree().process_frame
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = point
		Input.parse_input_event(event)
		await get_tree().process_frame
	await _settle()


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		printerr(message)
