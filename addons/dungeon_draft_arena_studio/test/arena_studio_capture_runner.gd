extends Control

var _studio: ArenaStudioMain


func _ready() -> void:
	call_deferred("_capture")


func _capture() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var options := _options()
	var requested_size := Vector2i(
		int(options.get("width", 1280)), int(options.get("height", 720))
	)
	get_window().size = requested_size
	print("ARENA_STUDIO_CAPTURE_START ", requested_size)
	_studio = ArenaStudioMain.new()
	_studio.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_studio)
	for _frame in range(8):
		await get_tree().process_frame
	var preview := ArenaLegacyImporter.import_production(&"room_01_forest")
	ArenaEditingService.apply_safety_border(preview, 1)
	_studio._set_arena(preview, false)
	var mode := str(options.get("mode", "creation"))
	if mode == "verification":
		_studio.mode_option.select(1)
		_studio._on_mode_selected(1)
		_studio._select_verification(0)
		_studio._on_verification_cell_requested(preview.hero_spawn_zone[0])
		_studio._on_verification_cell_requested(preview.enemy_spawn_zone[0])
	_studio.validate_arena()
	for _frame in range(8):
		await get_tree().process_frame
	var directory := "res://artifacts/arena_studio/screenshots"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var output := directory.path_join(
		"arena_studio_%s_%dx%d.png" % [mode, requested_size.x, requested_size.y]
	)
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		push_error("Arena Studio : le renderer actif ne fournit pas d'image de viewport.")
		get_tree().quit(1)
		return
	var error := image.save_png(ProjectSettings.globalize_path(output))
	print("ARENA_STUDIO_CAPTURE ", output, " ", error_string(error))
	get_tree().quit(0 if error == OK else 1)


func _options() -> Dictionary:
	var result := {}
	for argument in OS.get_cmdline_user_args():
		if not "=" in argument:
			continue
		var parts := argument.trim_prefix("--").split("=", true, 1)
		result[parts[0]] = parts[1]
	return result
