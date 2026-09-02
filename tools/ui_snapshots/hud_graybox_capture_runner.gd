extends Node

const GALLERY_SCENE := preload("res://tools/ui_snapshots/HudGrayboxGallery.tscn")
const OUTPUT_ROOT := "res://artifacts/hud_graybox_validation"
const RESOLUTIONS := [
	Vector2i(1280, 720),
	Vector2i(1200, 896),
	Vector2i(1672, 941),
	Vector2i(1920, 1080),
]
const STATES: Array[StringName] = [
	&"idle",
	&"hover",
	&"selected",
	&"unavailable",
	&"cooldown",
	&"locked",
	&"targeting_valid",
	&"targeting_invalid",
	&"resolving",
	&"enemy_turn",
]

var _manifest: Array[Dictionary] = []
var _metrics: Array[Dictionary] = []
var _requested_state: StringName = &""
var _requested_resolution := Vector2i.ZERO
var _output_root := OUTPUT_ROOT
var _preserve_color := false
var _premium_skin := false
var _output_root_explicit := false


func _ready() -> void:
	_parse_arguments()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_output_root))
	if DisplayServer.get_name() == "headless":
		push_error(
			"Le driver headless de Godot est un renderer dummy sans texture de viewport. "
			+ "Relancez ce runner avec le driver windows/opengl3."
		)
		get_tree().quit(3)
		return
	_run.call_deferred()


func _parse_arguments() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--state="):
			_requested_state = StringName(argument.trim_prefix("--state="))
		elif argument.begins_with("--resolution="):
			var parts := argument.trim_prefix("--resolution=").to_lower().split("x")
			if parts.size() == 2 and parts[0].is_valid_int() and parts[1].is_valid_int():
				_requested_resolution = Vector2i(int(parts[0]), int(parts[1]))
		elif argument.begins_with("--output-root="):
			var candidate := argument.trim_prefix("--output-root=").trim_suffix("/")
			if candidate.begins_with("res://artifacts/"):
				_output_root = candidate
				_output_root_explicit = true
		elif argument == "--preserve-color":
			_preserve_color = true
		elif argument == "--premium-achilles":
			_premium_skin = true
	if _premium_skin:
		_preserve_color = true
		if not _output_root_explicit:
			_output_root = "res://artifacts/hud_premium_achilles_validation"


func _run() -> void:
	var resolutions := RESOLUTIONS.filter(func(value):
		return _requested_resolution == Vector2i.ZERO or value == _requested_resolution
	)
	var states := STATES.filter(func(value):
		return _requested_state == &"" or value == _requested_state
	)
	if resolutions.is_empty() or states.is_empty():
		push_error("État ou résolution de graybox inconnu.")
		get_tree().quit(2)
		return
	for resolution in resolutions:
		for state_id in states:
			await _capture_state(state_id, resolution)
		_build_contact_sheet(resolution, states)
	_write_json("manifest.json", _manifest)
	_write_json("layout_metrics.json", _metrics)
	_write_validation_report()
	_write_gallery_html()
	var failed := _manifest.filter(func(entry): return entry.result != "success").size()
	print("HUD_GRAYBOX_CAPTURE_RESULT=" + JSON.stringify({
		"output": _output_root,
		"success": _manifest.size() - failed,
		"failure": failed,
	}))
	get_tree().quit(1 if failed > 0 else 0)


func _capture_state(state_id: StringName, resolution: Vector2i) -> void:
	get_tree().root.size = resolution
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_size(resolution)
	var gallery := GALLERY_SCENE.instantiate() as HudGrayboxGallery
	gallery.state_id = state_id
	gallery.premium_skin = _premium_skin
	get_tree().root.add_child(gallery)
	await gallery.gallery_ready
	# The signal is emitted from the gallery's asynchronous _ready(). Waiting one
	# frame avoids destroying the scene while that emission still locks it.
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		# A static reduced-motion state may not schedule another frame. Waiting for
		# frame_post_draw can therefore stall the last capture of a batch forever.
		# Force the completed frame synchronously before reading the viewport.
		RenderingServer.force_draw(false, 0.0)
	var image := get_tree().root.get_texture().get_image()
	if image != null and not image.is_empty() and not _preserve_color:
		# CPU-side conversion avoids the cross-CanvasLayer screen-texture
		# nondeterminism seen with a fullscreen shader on Windows/OpenGL.
		image.convert(Image.FORMAT_L8)
	var resolution_name := "%dx%d" % [resolution.x, resolution.y]
	var directory := _output_root.path_join(resolution_name)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var file_name := "%s__%s__%s.png" % [
		"hud_achilles_premium" if _premium_skin else (
			"hud_visual" if _preserve_color else "hud_graybox"
		),
		state_id,
		resolution_name,
	]
	var resource_path := directory.path_join(file_name)
	var absolute_path := ProjectSettings.globalize_path(resource_path)
	var error := image.save_png(absolute_path) if image != null else ERR_CANT_CREATE
	var valid := error == OK and _image_has_visual_range(image)
	var metrics := gallery.get_validation_metrics()
	metrics["resolution"] = [resolution.x, resolution.y]
	_metrics.append(metrics)
	_manifest.append({
		"state": String(state_id),
		"resolution": [resolution.x, resolution.y],
		"path": resource_path,
		"absolute_path": absolute_path,
		"sha256": FileAccess.get_sha256(absolute_path) if error == OK else "",
		"result": "success" if valid else "failure",
		"anchors_do_not_overlap": metrics.get("anchors_do_not_overlap", false),
		"hud_inside_viewport": metrics.get("hud_inside_viewport", false),
		"interaction_plate_text_fits": metrics.get("interaction_plate_text_fits", false),
	})
	gallery.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


func _image_has_visual_range(image: Image) -> bool:
	if image == null or image.is_empty():
		return false
	var minimum := 1.0
	var maximum := 0.0
	var step_x := maxi(1, image.get_width() / 48)
	var step_y := maxi(1, image.get_height() / 32)
	for x in range(0, image.get_width(), step_x):
		for y in range(0, image.get_height(), step_y):
			var luminance := image.get_pixel(x, y).get_luminance()
			minimum = minf(minimum, luminance)
			maximum = maxf(maximum, luminance)
	return maximum - minimum > 0.12


func _build_contact_sheet(resolution: Vector2i, states: Array) -> void:
	var entries := _manifest.filter(func(entry):
		return entry.resolution == [resolution.x, resolution.y] and entry.result == "success"
	)
	if entries.is_empty():
		return
	var thumb_width := 480
	var thumb_height := int(round(float(thumb_width) * float(resolution.y) / float(resolution.x)))
	var columns := 2
	var rows := ceili(float(entries.size()) / float(columns))
	var gap := 8
	var sheet := Image.create(
		columns * thumb_width + (columns - 1) * gap,
		rows * thumb_height + (rows - 1) * gap,
		false,
		Image.FORMAT_RGBA8
	)
	sheet.fill(Color("101214"))
	for index in entries.size():
		var source := Image.load_from_file(entries[index].absolute_path)
		if source == null or source.is_empty():
			continue
		source.convert(Image.FORMAT_RGBA8)
		source.resize(thumb_width, thumb_height, Image.INTERPOLATE_LANCZOS)
		var destination := Vector2i(
			(index % columns) * (thumb_width + gap),
			(index / columns) * (thumb_height + gap)
		)
		sheet.blit_rect(source, Rect2i(Vector2i.ZERO, source.get_size()), destination)
	var name := "%s_%dx%d.png" % [
		"contact_sheet_achilles_premium" if _premium_skin else "contact_sheet",
		resolution.x,
		resolution.y,
	]
	sheet.save_png(ProjectSettings.globalize_path(_output_root.path_join(name)))


func _write_gallery_html() -> void:
	var cards: Array[String] = []
	for entry in _manifest:
		if entry.result != "success":
			continue
		var relative := str(entry.path).trim_prefix(_output_root + "/")
		cards.append("<article><img src=\"%s\"><h2>%s</h2><p>%sx%s · %s</p></article>" % [
			relative,
			entry.state,
			entry.resolution[0],
			entry.resolution[1],
			str(entry.sha256).left(12),
		])
	var html := """<!doctype html><html lang="fr"><meta charset="utf-8"><title>HUD visual validation</title><style>body{margin:0;padding:24px;background:#111315;color:#f1f1ed;font:14px system-ui}main{display:grid;grid-template-columns:repeat(auto-fit,minmax(380px,1fr));gap:18px}article{overflow:hidden;border:1px solid #555b60;border-radius:8px;background:#1b1e21}img{display:block;width:100%%;height:auto;background:#08090a}h2,p{margin:10px 14px;text-transform:uppercase}p{color:#aeb2b5}</style><h1>Dungeon Draft — HUD Visual System v1</h1><main>%s</main></html>""" % "\n".join(cards)
	_write_text("gallery.html", html)


func _write_validation_report() -> void:
	var lines := [
		"# Validation du HUD Achille premium" if _premium_skin else "# Validation du HUD Visual System v1",
		"",
		"Le runner utilise `CombatHUDRecraftV1`, ses composants réels et le preset ",
		"de production `combat_hud_layout_run_v1_compact.tres` (144 px). Le plateau ",
		"est une fixture déterministe destinée à rendre le focus et le ciblage lisibles.",
		"",
		"États : `%s`." % "`, `".join(STATES.map(func(value): return String(value))),
		"",
		"| Résolution | Captures | Échecs | Texte contextuel tronqué | Ancres en collision | Bandeau / tour | Feedback / bandeau | Fin de tour / dock | Hors viewport |",
		"|---|---:|---:|---:|---:|---:|---:|---:|---:|",
	]
	for resolution in RESOLUTIONS:
		var resolution_array := [resolution.x, resolution.y]
		var entries := _manifest.filter(func(entry):
			return entry.resolution == resolution_array
		)
		var metrics := _metrics.filter(func(entry):
			return entry.resolution == resolution_array
		)
		lines.append("| %dx%d | %d | %d | %d | %d | %d | %d | %d | %d |" % [
			resolution.x,
			resolution.y,
			entries.size(),
			entries.filter(func(entry): return entry.result != "success").size(),
			metrics.filter(func(entry): return not entry.interaction_plate_text_fits).size(),
			metrics.filter(func(entry): return not entry.anchors_do_not_overlap).size(),
			metrics.filter(func(entry): return entry.interaction_plate_intersects_turn).size(),
			metrics.filter(func(entry): return entry.context_feedback_intersects_interaction).size(),
			metrics.filter(func(entry): return entry.end_turn_intersects_utility_dock).size(),
			metrics.filter(func(entry): return not entry.hud_inside_viewport).size(),
		])
	var sheet_prefix := "contact_sheet_achilles_premium" if _premium_skin else "contact_sheet"
	var sheet_names: Array[String] = []
	for resolution in RESOLUTIONS:
		sheet_names.append("`%s_%dx%d.png`" % [sheet_prefix, resolution.x, resolution.y])
	lines.append_array([
		"",
		"Planches : %s. La galerie interactive est `gallery.html`." % ", ".join(sheet_names),
		"",
	])
	_write_text("validation_report.md", "\n".join(lines))


func _write_json(file_name: String, value) -> void:
	_write_text(file_name, JSON.stringify(value, "\t") + "\n")


func _write_text(file_name: String, content: String) -> void:
	var file := FileAccess.open(
		ProjectSettings.globalize_path(_output_root.path_join(file_name)),
		FileAccess.WRITE
	)
	if file != null:
		file.store_string(content)
		file.close()
