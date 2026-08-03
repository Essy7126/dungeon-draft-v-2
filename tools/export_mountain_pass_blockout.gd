extends SceneTree

## Exporte le blueprint 2D 16:9 sans toucher aux anciens artefacts diorama.

const OUTPUT_DIR := "res://artifacts/maps/mountain_pass_blueprint"
const LEGACY_DIR := "res://artifacts/maps/mountain_pass_blockout"
const DATA_PATH := "res://data/maps/mountain_pass_blockout.tres"
const VIEW_SCRIPT := preload("res://battle/iso/mountain_pass_blueprint_view.gd")
const CANVAS_SIZE := Vector2i(1920, 1080)

const EXPORTS := [
	["mountain_pass_blueprint_reference.png", MountainPassBlueprintView.RenderMode.REFERENCE],
	["mountain_pass_blueprint_clean.png", MountainPassBlueprintView.RenderMode.CLEAN],
	["mountain_pass_blueprint_logic.png", MountainPassBlueprintView.RenderMode.LOGIC],
	["mountain_pass_blueprint_foreground_guide.png", MountainPassBlueprintView.RenderMode.FOREGROUND_GUIDE],
	["mountain_pass_blueprint_debug.png", MountainPassBlueprintView.RenderMode.DEBUG],
]


func _initialize() -> void:
	call_deferred("_export_all")


func _export_all() -> void:
	print("START mountain_pass_blueprint export")
	var absolute_output := ProjectSettings.globalize_path(OUTPUT_DIR)
	DirAccess.make_dir_recursive_absolute(absolute_output)
	var data := load(DATA_PATH) as MountainPassBlockoutData
	if data == null:
		push_error("Ressource de blockout introuvable.")
		quit(1)
		return
	var failures := 0
	for spec in EXPORTS:
		print("RENDERING %s" % str(spec[0]))
		var mode := int(spec[1])
		var image := await _render_mode(data, mode)
		var path := OUTPUT_DIR.path_join(str(spec[0]))
		var error := image.save_png(ProjectSettings.globalize_path(path))
		if error != OK:
			push_error("Echec export %s (code %d)." % [path, error])
			failures += 1
		else:
			print("EXPORTED %s %dx%d" % [path, image.get_width(), image.get_height()])
	if failures == 0:
		failures += await _export_comparison()
	quit(1 if failures > 0 else 0)


func _render_mode(data: MountainPassBlockoutData, mode: int) -> Image:
	var viewport := SubViewport.new()
	viewport.size = CANVAS_SIZE
	viewport.transparent_bg = mode == MountainPassBlueprintView.RenderMode.FOREGROUND_GUIDE
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var view := VIEW_SCRIPT.new() as MountainPassBlueprintView
	view.blockout_data = data
	view.render_mode = mode
	view.grid_origin = MountainPassBlueprintView.DEFAULT_GRID_ORIGIN
	view.axis_x = MountainPassBlueprintView.DEFAULT_AXIS_X
	view.axis_y = MountainPassBlueprintView.DEFAULT_AXIS_Y
	view.show_unit_preview = false
	viewport.add_child(view)
	await process_frame
	await process_frame
	await process_frame
	var image := viewport.get_texture().get_image()
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	viewport.queue_free()
	return image


func _export_comparison() -> int:
	var legacy_path := ProjectSettings.globalize_path(
		LEGACY_DIR.path_join("mountain_pass_blockout_reference.png")
	)
	var blueprint_path := ProjectSettings.globalize_path(
		OUTPUT_DIR.path_join("mountain_pass_blueprint_clean.png")
	)
	var legacy_image := Image.load_from_file(legacy_path)
	var blueprint_image := Image.load_from_file(blueprint_path)
	if legacy_image == null or legacy_image.is_empty():
		push_error("Ancien diorama absent pour la comparaison : %s" % legacy_path)
		return 1
	if blueprint_image == null or blueprint_image.is_empty():
		push_error("Blueprint absent pour la comparaison : %s" % blueprint_path)
		return 1

	var viewport := SubViewport.new()
	viewport.size = CANVAS_SIZE
	viewport.transparent_bg = false
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)

	var canvas := Control.new()
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport.add_child(canvas)
	var background := ColorRect.new()
	background.color = Color("d9e5ea")
	background.position = Vector2.ZERO
	background.size = Vector2(CANVAS_SIZE)
	canvas.add_child(background)

	_add_comparison_panel(
		canvas,
		legacy_image,
		Rect2(32, 96, 904, 952),
		"ANCIEN DIORAMA / OBJET ISOLE"
	)
	_add_comparison_panel(
		canvas,
		blueprint_image,
		Rect2(984, 96, 904, 952),
		"NOUVEAU BLUEPRINT / CADRAGE IN-GAME"
	)

	await process_frame
	await process_frame
	await process_frame
	var comparison := viewport.get_texture().get_image()
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	viewport.queue_free()
	var output := OUTPUT_DIR.path_join("mountain_pass_blueprint_comparison.png")
	var error := comparison.save_png(ProjectSettings.globalize_path(output))
	if error != OK:
		push_error("Echec export %s (code %d)." % [output, error])
		return 1
	print("EXPORTED %s %dx%d" % [output, comparison.get_width(), comparison.get_height()])
	return 0


func _add_comparison_panel(
	parent: Control,
	image: Image,
	rect: Rect2,
	title: String
) -> void:
	var panel := ColorRect.new()
	panel.color = Color("465b67")
	panel.position = rect.position
	panel.size = rect.size
	parent.add_child(panel)
	var label := Label.new()
	label.position = rect.position + Vector2(20, 12)
	label.size = Vector2(rect.size.x - 40, 42)
	label.text = title
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color("f4f7f8"))
	parent.add_child(label)
	var texture_rect := TextureRect.new()
	texture_rect.position = rect.position + Vector2(20, 62)
	texture_rect.size = rect.size - Vector2(40, 82)
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_rect.texture = ImageTexture.create_from_image(image)
	parent.add_child(texture_rect)
