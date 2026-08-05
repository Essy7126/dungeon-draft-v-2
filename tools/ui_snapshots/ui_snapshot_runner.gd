extends Node

const Registry := preload("res://tools/ui_snapshots/ui_snapshot_registry.gd")
const GALLERY_SCENE := preload("res://tools/ui_snapshots/CombatFeedbackGallery.tscn")
const RUN: RunData = preload("res://data/runs/first_run.tres")
const RESOLUTIONS := [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440)]

var _phase := "current"
var _branch := "unknown"
var _commit := "unknown"
var _short_commit := "unknown"
var _output_root := ""
var _manifest: Array = []
var _layout_metrics: Array = []


func _ready() -> void:
	_parse_arguments()
	_branch = _git_value(["branch", "--show-current"])
	_commit = _git_value(["rev-parse", "HEAD"])
	_short_commit = _commit.left(8) if _commit.length() >= 8 else "working"
	_output_root = "res://artifacts/ui_snapshots/%s" % _short_commit
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_output_root))
	_load_existing_manifest()
	_run.call_deferred()


func _parse_arguments() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--phase="):
			_phase = argument.trim_prefix("--phase=").to_lower()
	if _phase not in ["current", "after"]:
		_phase = "current"


func _run() -> void:
	var scenarios := Registry.production_scenarios()
	_write_inventory(scenarios)
	for scenario in scenarios:
		if not scenario.is_automated():
			if _phase == "current":
				for resolution in RESOLUTIONS:
					_record_failure(scenario, resolution, scenario.blocker)
			continue
		if _phase == "after" and scenario.capture_driver not in [&"feedback_gallery", &"battle"]:
			continue
		for resolution in RESOLUTIONS:
			await _capture(scenario, resolution)
	_write_json("manifest.json", _manifest)
	_write_json("layout_metrics.json", _layout_metrics)
	_write_failures()
	_build_contact_sheet()
	_write_gallery_html()
	print("UI_SNAPSHOT_RESULT=" + JSON.stringify({
		"phase": _phase,
		"output": _output_root,
		"success": _manifest.filter(func(entry): return entry.get("result") == "success").size(),
		"failure": _manifest.filter(func(entry): return entry.get("result") == "failure").size(),
	}))
	get_tree().quit(0)


func _capture(scenario: UISnapshotScenario, resolution: Vector2i) -> void:
	get_tree().root.size = resolution
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_size(resolution)
	var scene := await _instantiate_scenario(scenario)
	if scene == null:
		_record_failure(scenario, resolution, "La scène ou sa fixture n'a pas pu être instanciée.")
		return
	for _frame in 6:
		await get_tree().process_frame
	if scene.has_method("get_layout_metrics"):
		_layout_metrics.append({
			"snapshot_id": scenario.snapshot_id(),
			"phase": _phase,
			"resolution": [resolution.x, resolution.y],
			"controls": scene.get_layout_metrics(),
		})
	else:
		_layout_metrics.append({
			"snapshot_id": scenario.snapshot_id(),
			"phase": _phase,
			"resolution": [resolution.x, resolution.y],
			"controls": _collect_layout_metrics(scene),
		})
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	var image := get_tree().root.get_texture().get_image()
	var resolution_name := "%dx%d" % [resolution.x, resolution.y]
	var directory := "%s/%s/%s" % [_output_root, _phase, resolution_name]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var file_name := "%s__%s__%s.png" % [
		scenario.screen_id, scenario.state_id, resolution_name,
	]
	var resource_path := directory.path_join(file_name)
	var absolute_path := ProjectSettings.globalize_path(resource_path)
	var error := image.save_png(absolute_path) if image != null else ERR_CANT_CREATE
	var valid_visual := error == OK and _image_has_visual_range(image)
	var entry := _manifest_entry(scenario, resolution)
	entry["png_path"] = resource_path
	entry["checksum"] = FileAccess.get_sha256(absolute_path) if error == OK else ""
	entry["result"] = "success" if valid_visual else "failure"
	entry["failure_reason"] = "" if valid_visual else (
		"Capture vide ou sans contraste (display driver %s)." % DisplayServer.get_name()
	)
	_replace_manifest_entry(entry)
	_cleanup_scene(scene)


func _instantiate_scenario(scenario: UISnapshotScenario) -> Node:
	var scene: Node = null
	match scenario.capture_driver:
		&"feedback_gallery":
			scene = GALLERY_SCENE.instantiate()
			scene.legacy_preset = _phase == "current"
		&"title":
			scene = _load_scene(scenario.scene_path)
		&"hub", &"hub_archivist":
			scene = _load_scene(scenario.scene_path)
		&"intro":
			scene = _load_scene(scenario.scene_path)
			if scene != null:
				scene.autoplay = false
		&"battle":
			GameManager.cleanup_run_state()
			if not GameManager._prepare_preconfigured_run(
				RUN, GameManager.PRODUCTION_HERO_DATA_PATHS
			):
				return null
			GameManager.current_room_index = 0
			GameManager.current_wave_index = 0
			scene = RUN.rooms[0].battle_scene.instantiate()
		_:
			return null
	if scene == null:
		return null
	get_tree().root.add_child(scene)
	await get_tree().process_frame
	match scenario.capture_driver:
		&"title":
			var animation := scene.get_node_or_null("AnimationPlayer") as AnimationPlayer
			if animation != null and animation.has_animation(&"intro"):
				animation.play(&"intro")
				animation.seek(animation.get_animation(&"intro").length, true)
				animation.play(&"idle")
		&"hub_archivist":
			var panel := scene.get_node_or_null("HubUI/ArchivistPanel")
			var archivist := scene.get_node_or_null("WorldRoot/SortableWorld/Archivist")
			if panel != null and archivist != null:
				panel.open_panel(archivist.data)
		&"intro":
			scene.synchronize_to_time(42.5)
		&"battle":
			scene.process_mode = Node.PROCESS_MODE_DISABLED
	return scene


func _load_scene(path: String) -> Node:
	if not ResourceLoader.exists(path):
		return null
	var packed := load(path) as PackedScene
	return packed.instantiate() if packed != null else null


func _cleanup_scene(scene: Node) -> void:
	if is_instance_valid(scene):
		if scene.get_parent() != null:
			scene.get_parent().remove_child(scene)
		scene.free()
	GameManager.cleanup_run_state()
	await get_tree().process_frame
	await get_tree().process_frame


func _manifest_entry(scenario: UISnapshotScenario, resolution: Vector2i) -> Dictionary:
	return {
		"snapshot_id": "%s__%s__%s__%dx%d" % [
			_phase, scenario.screen_id, scenario.state_id, resolution.x, resolution.y,
		],
		"phase": _phase,
		"screen_id": String(scenario.screen_id),
		"state_id": String(scenario.state_id),
		"scene_path": scenario.scene_path,
		"fixture_id": String(scenario.fixture_id),
		"resolution": [resolution.x, resolution.y],
		"locale": TranslationServer.get_locale(),
		"seed": 1337,
		"branch": _branch,
		"commit": _commit,
		"godot_version": str(Engine.get_version_info().get("string", "unknown")),
		"generated_at_utc": Time.get_datetime_string_from_system(true),
		"checksum": "",
		"result": "failure",
		"failure_reason": "",
		"notes": scenario.notes,
	}


func _record_failure(
		scenario: UISnapshotScenario,
		resolution: Vector2i,
		reason: String
	) -> void:
	var entry := _manifest_entry(scenario, resolution)
	entry["failure_reason"] = reason
	_replace_manifest_entry(entry)


func _replace_manifest_entry(entry: Dictionary) -> void:
	var id := str(entry.get("snapshot_id", ""))
	for index in _manifest.size():
		if str(_manifest[index].get("snapshot_id", "")) == id:
			_manifest[index] = entry
			return
	_manifest.append(entry)


func _load_existing_manifest() -> void:
	var path := ProjectSettings.globalize_path(_output_root.path_join("manifest.json"))
	if _phase == "current" or not FileAccess.file_exists(path):
		_manifest = []
		_layout_metrics = []
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	_manifest = parsed if parsed is Array else []
	var metrics_path := ProjectSettings.globalize_path(
		_output_root.path_join("layout_metrics.json")
	)
	var parsed_metrics = JSON.parse_string(FileAccess.get_file_as_string(metrics_path)) \
		if FileAccess.file_exists(metrics_path) else []
	_layout_metrics = parsed_metrics if parsed_metrics is Array else []


func _collect_layout_metrics(root_node: Node) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	_collect_controls(root_node, root_node, result)
	return result


func _collect_controls(root_node: Node, node: Node, result: Array[Dictionary]) -> void:
	if node is Control:
		var control := node as Control
		result.append({
			"node_path": str(root_node.get_path_to(control)),
			"class": control.get_class(),
			"position": [control.global_position.x, control.global_position.y],
			"size": [control.size.x, control.size.y],
			"anchors": [control.anchor_left, control.anchor_top, control.anchor_right, control.anchor_bottom],
			"offsets": [control.offset_left, control.offset_top, control.offset_right, control.offset_bottom],
			"minimum_size": [control.get_combined_minimum_size().x, control.get_combined_minimum_size().y],
			"text": control.text if control is Label or control is Button else "",
			"visible": control.visible,
		})
	for child in node.get_children():
		_collect_controls(root_node, child, result)


func _image_has_visual_range(image: Image) -> bool:
	if image == null or image.is_empty():
		return false
	var minimum := 10.0
	var maximum := -1.0
	var step_x := maxi(1, image.get_width() / 32)
	var step_y := maxi(1, image.get_height() / 24)
	for x in range(0, image.get_width(), step_x):
		for y in range(0, image.get_height(), step_y):
			var color := image.get_pixel(x, y)
			var luminance := color.get_luminance()
			minimum = minf(minimum, luminance)
			maximum = maxf(maximum, luminance)
	return maximum - minimum > 0.015


func _write_inventory(scenarios: Array[UISnapshotScenario]) -> void:
	var lines := [
		"# Inventaire des interfaces de production",
		"",
		"Commit : `%s` — branche : `%s`" % [_commit, _branch],
		"",
		"| Écran | État | Scène | Fixture | Capture | Blocage |",
		"|---|---|---|---|---|---|",
	]
	for scenario in scenarios:
		lines.append("| %s | %s | `%s` | %s | %s | %s |" % [
			scenario.screen_id,
			scenario.state_id,
			scenario.scene_path,
			scenario.fixture_id,
			"automatisée" if scenario.is_automated() else "documentée",
			scenario.blocker.replace("|", "\\|"),
		])
	_write_text("inventory.md", "\n".join(lines) + "\n")


func _write_failures() -> void:
	var lines := ["# Échecs de capture", ""]
	for entry in _manifest:
		if entry.get("result") != "failure":
			continue
		lines.append("- `%s` : %s" % [
			entry.get("snapshot_id", "unknown"),
			entry.get("failure_reason", "raison inconnue"),
		])
	if lines.size() == 2:
		lines.append("Aucun échec.")
	_write_text("capture_failures.md", "\n".join(lines) + "\n")


func _build_contact_sheet() -> void:
	var successful := _manifest.filter(func(entry):
		return entry.get("result") == "success" and entry.get("png_path", "") != ""
	)
	if successful.is_empty():
		return
	var thumb_size := Vector2i(320, 180)
	var columns := 4
	var rows := ceili(float(successful.size()) / float(columns))
	var sheet := Image.create(columns * thumb_size.x, rows * thumb_size.y, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("0c1018"))
	for index in successful.size():
		var source := Image.load_from_file(ProjectSettings.globalize_path(
			successful[index].get("png_path", "")
		))
		if source == null or source.is_empty():
			continue
		source.resize(thumb_size.x, thumb_size.y, Image.INTERPOLATE_LANCZOS)
		var destination := Vector2i(
			(index % columns) * thumb_size.x,
			(index / columns) * thumb_size.y
		)
		sheet.blit_rect(source, Rect2i(Vector2i.ZERO, thumb_size), destination)
	sheet.save_png(ProjectSettings.globalize_path(_output_root.path_join("contact_sheet.png")))


func _write_gallery_html() -> void:
	var cards := []
	for entry in _manifest:
		if entry.get("result") != "success":
			continue
		var png_path := str(entry.get("png_path", ""))
		var relative := png_path.trim_prefix(_output_root + "/")
		cards.append("<article><img src=\"%s\" loading=\"lazy\"><h2>%s / %s</h2><p>%s · %sx%s · %s</p></article>" % [
			relative,
			entry.get("screen_id", ""), entry.get("state_id", ""),
			entry.get("phase", ""), entry.get("resolution", [0, 0])[0],
			entry.get("resolution", [0, 0])[1], entry.get("checksum", "").left(12),
		])
	var html := """<!doctype html><html lang="fr"><meta charset="utf-8"><title>Dungeon Draft UI snapshots</title><style>body{margin:0;padding:24px;background:#0d1119;color:#e6dcc8;font:14px system-ui}main{display:grid;grid-template-columns:repeat(auto-fit,minmax(320px,1fr));gap:18px}article{background:#171f2c;border:1px solid #39465a;border-radius:10px;overflow:hidden}img{display:block;width:100%%;aspect-ratio:16/9;object-fit:contain;background:#080b10}h2,p{margin:10px 14px}p{color:#9caabd}</style><h1>Dungeon Draft — UI snapshots</h1><main>%s</main></html>""" % "\n".join(cards)
	_write_text("gallery.html", html)


func _git_value(arguments: Array[String]) -> String:
	var output: Array = []
	var repository := ProjectSettings.globalize_path("res://").replace("\\", "/").trim_suffix("/")
	var args := ["-c", "safe.directory=%s" % repository]
	args.append_array(arguments)
	var exit_code := OS.execute("git", args, output, true)
	return str(output[0]).strip_edges() if exit_code == 0 and not output.is_empty() else "unknown"


func _write_json(file_name: String, value) -> void:
	_write_text(file_name, JSON.stringify(value, "\t") + "\n")


func _write_text(file_name: String, content: String) -> void:
	var path := ProjectSettings.globalize_path(_output_root.path_join(file_name))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(content)
		file.close()
