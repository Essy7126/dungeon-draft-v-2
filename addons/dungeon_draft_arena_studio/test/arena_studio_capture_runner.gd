extends Control

var _studio: DungeonDraftStudioMain
var _arena: ArenaStudioMain


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
	_studio = DungeonDraftStudioMain.new()
	_studio.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_studio)
	for _frame in range(8):
		await get_tree().process_frame
	_arena = _studio.arena_studio
	var map_name := str(options.get("map", "forest"))
	var map_ids := {
		"forest": &"room_01_forest",
		"volcano": &"room_05_volcano",
		"space": &"room_06_space",
	}
	var preview := ArenaLegacyImporter.import_production(map_ids.get(map_name, &"room_01_forest"))
	ArenaEditingService.apply_safety_border(preview, 1)
	_arena._set_arena(preview, false, "capture:%s" % map_name)
	var mode := str(options.get("mode", "creation"))
	if mode == "verification":
		_arena.mode_option.select(1)
		_arena._on_mode_selected(1)
		_arena._select_verification(0)
		_arena._on_verification_cell_requested(preview.hero_spawn_zone[0])
		_arena._on_verification_cell_requested(preview.enemy_spawn_zone[0])
	elif mode in ["transform", "translation", "axis_x", "axis_y", "rotation", "scale", "pivot", "fine", "snap", "compare"]:
		_arena._on_tool_selected(ArenaStudioCanvas.Tool.TRANSFORM_GRID)
		_arena.tool_list.select(ArenaStudioCanvas.Tool.TRANSFORM_GRID)
		if mode == "compare":
			_arena.canvas.show_saved_comparison = true
			_arena.compare_button.set_pressed_no_signal(true)
		elif mode != "transform":
			_begin_visual_gesture(mode)
	elif mode == "anchors":
		_arena._on_tool_selected(ArenaStudioCanvas.Tool.CALIBRATION_ANCHORS)
		_arena.tool_list.select(ArenaStudioCanvas.Tool.CALIBRATION_ANCHORS)
	elif mode == "advanced":
		_arena.mode_option.select(2)
		_arena._on_mode_selected(2)
	elif mode == "history":
		var before := _arena.arena.to_snapshot()
		_arena.arena.grid_origin += Vector2(6, -2)
		_arena._commit_change("Deplacer la grille", before, _arena.arena.to_snapshot())
		_studio._refresh_history_controls()
		_studio._rebuild_history_menu()
		_studio.history_button.show_popup()
	elif mode == "restore":
		for scroll in _arena.find_children("*", "ScrollContainer", true, false):
			(scroll as ScrollContainer).scroll_vertical = 10000
	_arena.validate_arena()
	for _frame in range(8):
		await get_tree().process_frame
	var directory := "res://artifacts/arena_studio/screenshots"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var output := directory.path_join(
		"arena_studio_%s_%s_%dx%d.png" % [mode, map_name, requested_size.x, requested_size.y]
	)
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		push_error("Arena Studio : le renderer actif ne fournit pas d'image de viewport.")
		get_tree().quit(1)
		return
	var error := image.save_png(ProjectSettings.globalize_path(output))
	print("ARENA_STUDIO_CAPTURE ", output, " ", error_string(error))
	get_tree().quit(0 if error == OK else 1)


func _begin_visual_gesture(mode: String) -> void:
	var canvas := _arena.canvas
	var positions := canvas._transform_handle_screen_positions()
	var handle := ArenaStudioCanvas.TransformHandle.BODY
	var start := GridTransformService.image_to_view(
		_arena.arena.grid_origin, canvas.pan, canvas.zoom
	)
	var target := start + Vector2(32, -14)
	match mode:
		"axis_x":
			handle = ArenaStudioCanvas.TransformHandle.AXIS_X
			start = positions[handle]
			target = start + Vector2(22, -16)
		"axis_y":
			handle = ArenaStudioCanvas.TransformHandle.AXIS_Y
			start = positions[handle]
			target = start + Vector2(-22, -16)
		"rotation":
			handle = ArenaStudioCanvas.TransformHandle.ROTATE
			start = positions[handle]
			target = start + Vector2(28, 8)
		"scale":
			handle = ArenaStudioCanvas.TransformHandle.SCALE
			start = positions[handle]
			target = start + Vector2(32, 22)
		"pivot":
			handle = ArenaStudioCanvas.TransformHandle.PIVOT
			start = positions[handle]
			target = start + Vector2(45, -24)
	assert(canvas._begin_transform_handle(handle, start))
	var motion := InputEventMouseMotion.new()
	motion.position = target
	motion.shift_pressed = mode == "fine"
	motion.ctrl_pressed = mode != "snap" and mode == "translation"
	canvas._handle_mouse_motion(motion)


func _options() -> Dictionary:
	var result := {}
	for argument in OS.get_cmdline_user_args():
		if not "=" in argument:
			continue
		var parts := argument.trim_prefix("--").split("=", true, 1)
		result[parts[0]] = parts[1]
	return result
