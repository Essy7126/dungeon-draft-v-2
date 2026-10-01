extends SceneTree
## Isolated real navigation from the Cards selection into the production run.

const SCREEN := "res://ui/selection/CharacterSelectionScreen.tscn"
const OUTPUT := "res://artifacts/dev/selection-reference-v3/navigation/"
var checks: Array[Dictionary] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	root.size = Vector2i(1280, 720)
	var manager := root.get_node("GameManager")
	manager.selected_run_variant = "cards"
	var screen = load(SCREEN).instantiate()
	root.add_child(screen)
	current_scene = screen
	await _settle()
	await _press(screen.find_child("SetupBack", true, false))
	await _wait_scene("res://ui/TitreEcran.tscn")
	_check(
		current_scene.scene_file_path == "res://ui/TitreEcran.tscn",
		"Retour opens the existing title",
	)
	var title := current_scene
	current_scene = null
	root.remove_child(title)
	title.queue_free()
	screen = load(SCREEN).instantiate()
	root.add_child(screen)
	current_scene = screen
	await _settle()
	await _press(screen.find_child("SetupRefuge", true, false))
	await _settle()
	_check(current_scene != screen, "Sanctuaire opens its existing destination")
	if current_scene != screen:
		var refuge := current_scene
		current_scene = null
		root.remove_child(refuge)
		refuge.queue_free()
		screen = load(SCREEN).instantiate()
		root.add_child(screen)
		current_scene = screen
		await _settle()
	await _press(screen.start_button)
	await _wait_scene("res://cinematics/intro/intro_cinematic.tscn")
	_check(
		current_scene.scene_file_path == "res://cinematics/intro/intro_cinematic.tscn",
		"Franchir le seuil reaches the production introduction",
	)
	if current_scene.scene_file_path == "res://cinematics/intro/intro_cinematic.tscn":
		await _press(current_scene.get_node("SkipButton"))
		await _wait_scene("res://hub/catabase_threshold/CatabaseThreshold.tscn")
		_check(
			manager.has_catabase_threshold_configuration(),
			"Selected build reaches the real threshold",
		)
		var launched: Dictionary = manager.finish_catabase_threshold()
		_check(launched.get("success", false), "Threshold commits the selected Cards run")
		_check(manager.run_active and manager.selected_run_variant == "cards", "Cards run starts")
		_check(
			manager.get_ordered_character_states().size() == 1,
			"Selected hero transfers into the run",
		)
		if manager.run_active:
			var battle_path: String = manager.get_current_room().battle_scene.resource_path
			await _wait_scene(battle_path)
			_check(current_scene.scene_file_path == battle_path, "First production battle opens")
			_check(
				current_scene.get("_deployment") != null and current_scene._deployment.is_active(),
				"Player deployment is active",
			)
			RenderingServer.force_draw(false)
			root.get_texture().get_image().save_png(
				ProjectSettings.globalize_path(OUTPUT + "first_battle.png")
			)
	var scene := current_scene
	current_scene = null
	if is_instance_valid(scene):
		scene.queue_free()
	await _settle()
	manager.cleanup_run_state()
	var passed := checks.all(
		func(check):
			return check.passed,
	)
	var file := FileAccess.open(OUTPUT + "report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({ "passed": passed, "checks": checks }, "\t"))
	file.close()
	quit(0 if passed else 1)


func _press(button: Button) -> void:
	_check(
		button != null and button.is_visible_in_tree() and not button.disabled,
		"Navigation target is usable",
	)
	if button == null or button.disabled:
		return
	var point := button.get_global_rect().get_center()
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		root.push_input(event)
	await _settle()


func _wait_scene(path: String) -> void:
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < 20000:
		if is_instance_valid(current_scene) and current_scene.scene_file_path == path:
			await _settle()
			return
		await create_timer(.1).timeout
	_check(false, "Scene reached: " + path)


func _settle() -> void:
	for frame in 8:
		await process_frame


func _check(passed: bool, description: String) -> void:
	checks.append({ "passed": passed, "description": description })
	if not passed:
		push_error(description)
