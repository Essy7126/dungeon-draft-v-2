extends Node
const Fixture = preload("res://tools/run_explorer/route_explorer_fixture.gd")
var checks: Array[Dictionary] = []
var output := ""


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
	if not output.begins_with("res://artifacts/dev/"):
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var view = load("res://tools/run_explorer/RunExplorer.tscn").instantiate()
	add_child(view)
	for resolution in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		get_window().size = resolution
		view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		for frame in 8:
			await get_tree().process_frame
		_check("full_graph_%s" % resolution, view.canvas._buttons.size() == 55)
		for button in view.canvas._buttons.values():
			_check("node_in_map_" + str(button.name), view.map_host.get_global_rect().encloses(
					button.get_global_rect()
				))
		for id in ["d01_0", "d20_0", "d08_secret"]:
			var button: Button = view.canvas._buttons[id]
			var point := button.get_global_rect().get_center()
			for pressed in [true, false]:
				var click := InputEventMouseButton.new()
				click.button_index = MOUSE_BUTTON_LEFT
				click.position = point
				click.global_position = point
				click.pressed = pressed
				Input.parse_input_event(click)
				await get_tree().process_frame
			_check("real_selection_" + id, str(view.selected.id) == id)
			_check(
				"actions_visible_" + id,
				Rect2(Vector2.ZERO, Vector2(resolution)).encloses(
					view.play_button.get_global_rect()
				),
			)
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(
				ProjectSettings.globalize_path(
					output.path_join("%dx%d-%s.png" % [resolution.x, resolution.y, id])
				)
			)
	view.select_destination("entry")
	_check("entry_painting", view.preview.texture != null)
	var nodes := ExpeditionRouteCatalog.create_nodes(2401)
	var targets: Array[String] = ["d01_0", "d04_1", "d08_secret", "d12_0", "d16_secret", "d20_0"]
	for node in nodes:
		if (
			int(node.depth) == 8 and str(node.kind) in ["merchant", "sanctuary"]
			and not bool(node.hidden)
		):
			targets.append(str(node.id))
	for target in targets:
		var snapshot := Fixture.prepare(
			self,
			2401,
			target,
			output.path_join("fixture-" + target + ".json"),
		)
		_check("snapshot_created_" + target, not snapshot.is_empty())
		if not snapshot.is_empty():
			var prepared := ExpeditionSaveService.prepare(snapshot)
			_check("snapshot_valid_" + target, not prepared.is_empty())
			if not prepared.is_empty():
				_check(
					"snapshot_target_" + target,
					str(prepared.session.route.current_node_id) == target,
				)
				prepared.state.dispose()
	view.select_destination("d01_0")
	var original_appdata := OS.get_environment("APPDATA")
	var child: int = view.launch("play", true)
	_check("process_created", child > 0)
	_check("parent_environment_restored", OS.get_environment("APPDATA") == original_appdata)
	if child > 0:
		for second in 90:
			await get_tree().create_timer(1.0).timeout
			if not OS.is_process_running(child):
				break
		var child_report := _read_report(view.last_launch_output.path_join("preview.json"))
		_check("launched_preview_ready", bool(child_report.get("ready", false)))
		_check("launched_preview_target", str(child_report.get("current_node", "")) == "d01_0")
		_check("launched_preview_closed", not OS.is_process_running(child))
		if OS.is_process_running(child):
			OS.kill(child)
	var passed := true
	for check in checks:
		passed = passed and bool(check.passed)
	var file := FileAccess.open(output.path_join("verification.json"), FileAccess.WRITE)
	file.store_string(
		JSON.stringify({ "passed": passed, "checks": checks, "count": checks.size() }, "\t")
	)
	view.queue_free()
	await get_tree().process_frame
	GameManager.cleanup_run_state()
	get_tree().quit(0 if passed else 1)


func _check(label: String, passed: bool) -> void:
	checks.append({ "label": label, "passed": passed })
	if not passed:
		push_error("EXPLORER: " + label)


func _read_report(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return { }
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	return data if data is Dictionary else { }
