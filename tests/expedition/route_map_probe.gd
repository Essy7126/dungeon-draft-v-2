extends Node
## Real map UI, simulated route progress, no player save or combat mutation.
const ROUTE_VIEW := preload("res://ui/expedition/expedition_route_view.gd")
var _failures: Array[String] = []
var _checks := 0
var _output := ""
var _view: Control


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var resolution := Vector2i(1280, 720)
	var progress := 5
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("resolution="):
			var parts := argument.trim_prefix("resolution=").split("x")
			resolution = Vector2i(int(parts[0]), int(parts[1]))
		if argument.begins_with("progress="):
			progress = clampi(int(argument.trim_prefix("progress=")), 0, 19)
	get_window().size = resolution
	_output = "res://artifacts/route_map/%dx%d" % [resolution.x, resolution.y]
	if progress != 5:
		_output += "-choices"
	DirAccess.make_dir_recursive_absolute(_output)
	var previous_motion := GameManager.is_reduced_motion_enabled()
	GameManager.set_reduced_motion_enabled(true)
	var session := ExpeditionSession.new()
	session.route.initialize(2401)
	for depth in progress:
		var available := session.route.get_available_nodes()
		session.route.choose_node(str(available[0].id))
		if session.route.phase == "combat":
			session.route.mark_combat_won()
		session.route.complete_current_node()
	session.route.reveal_hidden_node("d08_secret")
	var before := session.route.to_snapshot()
	var background := ColorRect.new()
	background.color = Color("171917")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	add_child(margin)
	_view = ROUTE_VIEW.new()
	margin.add_child(_view)
	_view.configure(session, "", false)
	await _capture("01_detail")
	var scroll := _view.find_child("RouteMapScroll", true, false) as ScrollContainer
	var scroll_before := scroll.scroll_vertical
	await _click(_view.find_child("ExpandFullRoute", true, false))
	var overview := _view.find_child("FullRouteOverview", true, false)
	_check(overview != null, "Mouse opens the full route")
	if overview != null:
		var canvas := overview.find_child("OverviewMapCanvas", true, false) as ExpeditionMapCanvas
		var host := overview.find_child("OverviewMapArea", true, false) as Control
		for button in canvas._buttons.values():
			_check(
				host.get_global_rect().encloses(button.get_global_rect()),
				"Overview destination fits: " + str(button.name),
			)
		await _capture("02_overview")
		await _click(canvas._buttons["d20_0"])
		_check(
			str(_view.get("_selected_node_id")) == "d20_0",
			"Full map mouse selection reaches boss",
		)
		_check(session.route.to_snapshot() == before, "Selection does not mutate route")
		_check(
			_view.find_child("CommitDestination", true, false).disabled,
			"Cannot jump to a future node",
		)
		await _capture("03_boss_inspected")
		var escape := InputEventKey.new()
		escape.keycode = KEY_ESCAPE
		escape.pressed = true
		get_viewport().push_input(escape)
		await _settle()
		_check(_view.find_child("FullRouteOverview", true, false) == null, "Escape folds the map")
		_check(scroll.scroll_vertical == scroll_before, "Detail scroll position preserved")
	_check(session.route.to_snapshot() == before, "Opening and folding never changes progress")
	var report := {
		"checks": _checks,
		"failures": _failures,
		"passed": _failures.is_empty(),
		"resolution": str(resolution),
		"rendered": DisplayServer.get_name() != "headless",
	}
	var file := FileAccess.open(_output.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	GameManager.set_reduced_motion_enabled(previous_motion)
	print("ROUTE_MAP_REVIEW: " + JSON.stringify(report))
	get_tree().quit(0 if _failures.is_empty() else 1)


func _click(control: Control) -> void:
	_check(control != null, "Mouse target exists")
	if control == null:
		return
	var point := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	get_viewport().push_input(motion)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		get_viewport().push_input(event)
		await get_tree().process_frame
	await _settle()


func _settle() -> void:
	for frame in 8:
		await get_tree().process_frame


func _capture(label: String) -> void:
	await _settle()
	var bounds := get_viewport().get_visible_rect()
	for button in _view.find_children("*", "Button", true, false):
		if button.is_visible_in_tree() and not str(button.name).begins_with("Destination_"):
			_check(
				bounds.encloses(button.get_global_rect()),
				"Visible action fits: " + str(button.name),
			)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		_check(image.save_png(_output.path_join(label + ".png")) == OK, "Screenshot saved")


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
