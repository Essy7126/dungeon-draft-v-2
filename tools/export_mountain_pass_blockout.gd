extends SceneTree

const OUTPUT_DIR := "res://artifacts/maps/mountain_pass_blockout"
const DATA_PATH := "res://data/maps/mountain_pass_blockout.tres"
const VIEW_SCRIPT := preload("res://battle/iso/mountain_pass_blockout_view.gd")

const EXPORTS := [
	["mountain_pass_blockout_reference.png", MountainPassBlockoutView.RenderMode.REFERENCE],
	["mountain_pass_blockout_clean.png", MountainPassBlockoutView.RenderMode.CLEAN],
	["mountain_pass_blockout_debug.png", MountainPassBlockoutView.RenderMode.DEBUG],
	["mountain_pass_blockout_logic_mask.png", MountainPassBlockoutView.RenderMode.LOGIC_MASK],
	["mountain_pass_blockout_height_guide.png", MountainPassBlockoutView.RenderMode.HEIGHT_GUIDE],
]


func _initialize() -> void:
	call_deferred("_export_all")


func _export_all() -> void:
	print("START mountain_pass_blockout export")
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
		var image := await _render_mode(data, int(spec[1]))
		var path := OUTPUT_DIR.path_join(str(spec[0]))
		var error := image.save_png(ProjectSettings.globalize_path(path))
		if error != OK:
			push_error("Echec export %s (code %d)." % [path, error])
			failures += 1
		else:
			print("EXPORTED %s %dx%d" % [path, image.get_width(), image.get_height()])
	if failures == 0:
		failures += _export_comparison()
	quit(1 if failures > 0 else 0)


func _render_mode(data: MountainPassBlockoutData, mode: int) -> Image:
	var viewport := SubViewport.new()
	viewport.size = data.canvas_size
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var view := VIEW_SCRIPT.new() as MountainPassBlockoutView
	view.blockout_data = data
	view.render_mode = mode
	view.grid_origin = data.grid_origin
	view.preview_scale = data.preview_scale
	view.axis_x = data.axis_x
	view.axis_y = data.axis_y
	view.cliff_depth = data.cliff_depth
	view.obstacle_height = data.obstacle_height
	view.landmark_height = data.landmark_height
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
	var comparison := Image.create(2048, 2048, false, Image.FORMAT_RGBA8)
	comparison.fill(Color("c7cdd2"))
	var names := [
		"mountain_pass_blockout_reference.png",
		"mountain_pass_blockout_clean.png",
		"mountain_pass_blockout_debug.png",
	]
	var panel_size := Vector2i(640, 640)
	var origins := [Vector2i(32, 704), Vector2i(704, 704), Vector2i(1376, 704)]
	for index in range(names.size()):
		var absolute_path := ProjectSettings.globalize_path(OUTPUT_DIR.path_join(names[index]))
		var panel := Image.load_from_file(absolute_path)
		if panel == null or panel.is_empty():
			push_error("Image absente pour la comparaison : %s" % absolute_path)
			return 1
		panel.resize(panel_size.x, panel_size.y, Image.INTERPOLATE_LANCZOS)
		comparison.fill_rect(
			Rect2i(origins[index] - Vector2i(5, 5), panel_size + Vector2i(10, 10)),
			Color("47535d")
		)
		comparison.blit_rect(panel, Rect2i(Vector2i.ZERO, panel_size), origins[index])
	var output := OUTPUT_DIR.path_join("mountain_pass_blockout_comparison.png")
	var error := comparison.save_png(ProjectSettings.globalize_path(output))
	if error != OK:
		push_error("Echec export %s (code %d)." % [output, error])
		return 1
	print("EXPORTED %s %dx%d" % [output, comparison.get_width(), comparison.get_height()])
	return 0
