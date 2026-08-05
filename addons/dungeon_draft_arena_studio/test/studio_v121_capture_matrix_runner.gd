extends Control

const OUTPUT := "res://artifacts/studio_1_2_1/screenshots/after"
const SIZES := [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440)]
const CASES := [
	"01_dynamic_integrated", "02_dynamic_detached", "03_dynamic_focus",
	"04_canvas_editable", "05_palette_terrain", "06_palette_wall",
	"07_transform_gizmo", "08_axes_xy", "09_translation", "10_rotation",
	"11_scale", "12_pivot", "13_angle_handle", "14_angle_open",
	"15_angle_closed", "16_preserve_x", "17_preserve_y",
	"18_anchors_separate", "19_gameplay_separate", "20_forest",
	"21_volcano", "22_space",
]

var studio: StudioWorkspace
var arena: ArenaStudioMain
var metrics := {}


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	for requested_size in SIZES:
		get_window().size = requested_size
		await get_tree().process_frame
		studio = StudioWorkspace.new()
		studio.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(studio)
		for frame in range(8):
			await get_tree().process_frame
		arena = studio.arena_studio
		var key := "%dx%d" % [requested_size.x, requested_size.y]
		metrics[key] = {}
		for case_name in CASES:
			_configure(case_name)
			for frame in range(5):
				await get_tree().process_frame
			metrics[key][case_name] = _capture_metrics()
			var output := OUTPUT.path_join(
				"studio_v121_%s_%s.png" % [case_name, key]
			)
			var image := get_viewport().get_texture().get_image()
			if image == null or image.is_empty() or image.save_png(
					ProjectSettings.globalize_path(output)
				) != OK:
				push_error("Capture 1.2.1 impossible : %s" % output)
				get_tree().quit(1)
				return
			print("STUDIO_V121_CAPTURE ", output)
		studio.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	var file := FileAccess.open(OUTPUT.path_join("capture_metrics.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(metrics, "  "))
		file.close()
	print("STUDIO_V121_CAPTURE_MATRIX_COMPLETE ", SIZES.size() * CASES.size())
	get_tree().quit()


func _configure(case_name: String) -> void:
	_reset_ui()
	match case_name:
		"01_dynamic_integrated":
			arena.show_dynamic_construction()
		"02_dynamic_detached":
			arena.show_dynamic_construction()
			studio.set_detached_state(true)
			studio.detach_button.text = "RÉINTÉGRER"
		"03_dynamic_focus":
			arena.show_dynamic_construction()
			arena.set_focus_map(true)
		"04_canvas_editable":
			arena.show_dynamic_construction()
			arena.canvas.selected_cells = [Vector2i(5, 5), Vector2i(6, 5)]
			arena.canvas.queue_redraw()
			arena._set_status("Canvas actif — sélection et peinture utilisent le routeur unique")
		"05_palette_terrain":
			arena.show_dynamic_construction()
			arena.dynamic_terrain_option.select(3)
			arena._select_dynamic_tool(ArenaStudioCanvas.Tool.TERRAIN)
		"06_palette_wall":
			arena.show_dynamic_construction()
			arena.dynamic_wall_option.select(1)
			arena._select_dynamic_tool(ArenaStudioCanvas.Tool.OBSTACLE)
		"07_transform_gizmo", "08_axes_xy", "13_angle_handle":
			_select_transform()
		"09_translation":
			_select_transform()
			_apply_snapshot(GridTransformService.translate(
				GridTransformSnapshot.from_arena(arena.arena), Vector2(65, -24)
			))
			arena.canvas._live_transform_text = "Déplacement  +65, -24 px"
		"10_rotation":
			_select_transform()
			var value := GridTransformSnapshot.from_arena(arena.arena)
			_apply_snapshot(GridTransformService.rotate_around(
				value, GridTransformService.logical_grid_center(value, arena.arena.grid_size), deg_to_rad(12.0)
			))
			arena.canvas._live_transform_text = "Rotation  +12,00 deg"
		"11_scale":
			_select_transform()
			var value := GridTransformSnapshot.from_arena(arena.arena)
			_apply_snapshot(GridTransformService.scale_around(
				value, GridTransformService.logical_grid_center(value, arena.arena.grid_size), 1.18
			))
			arena.canvas._live_transform_text = "Échelle  118,00 %"
		"12_pivot":
			_select_transform()
			arena.canvas.place_editor_pivot_on_origin()
			arena.canvas._live_transform_text = "Pivot d'éditeur sur l'origine O — document inchangé"
		"14_angle_open":
			_select_transform()
			_apply_angle(150.0, GridTransformService.AngleMode.SYMMETRIC)
		"15_angle_closed":
			_select_transform()
			_apply_angle(55.0, GridTransformService.AngleMode.SYMMETRIC)
		"16_preserve_x":
			_select_transform()
			_apply_angle(92.0, GridTransformService.AngleMode.PRESERVE_X)
		"17_preserve_y":
			_select_transform()
			_apply_angle(105.0, GridTransformService.AngleMode.PRESERVE_Y)
		"18_anchors_separate":
			arena._select_tool_and_preset(ArenaStudioCanvas.Tool.CALIBRATION_ANCHORS, 0)
			arena._set_status("Mode Ancres — gizmo affine masqué, résidus isolés")
		"19_gameplay_separate":
			arena.set_preview_view(ArenaRuntimePreview.ViewMode.GAME)
			arena.runtime_preview.rebuild_now()
		"20_forest":
			arena.set_preview_view(ArenaRuntimePreview.ViewMode.GAME)
			arena.runtime_preview.rebuild_now()
		"21_volcano":
			arena.load_production(&"room_05_volcano")
			arena.set_preview_view(ArenaRuntimePreview.ViewMode.GAME)
			arena.runtime_preview.rebuild_now()
		"22_space":
			arena.load_production(&"room_06_space")
			arena.set_preview_view(ArenaRuntimePreview.ViewMode.GAME)
			arena.runtime_preview.rebuild_now()


func _reset_ui() -> void:
	studio.set_detached_state(false)
	studio.detach_button.text = "Détacher"
	if arena.focus_map_enabled:
		arena.set_focus_map(false)
	arena.workspace_preset = 0
	arena.left_panel.show()
	arena.right_panel.show()
	arena.bottom_drawer_content.hide()
	arena.load_production(&"room_01_forest")
	# Chaque capture part de la source canonique : aucune transformation d'un
	# cas précédent ne peut contaminer le cas suivant.
	if arena.edit_session != null and arena.edit_session.source_arena != null:
		arena.edit_session.apply_snapshot(arena.edit_session.source_arena.to_snapshot())
		arena._activate_session(arena.edit_session)
	arena.canvas.center_editor_pivot()
	arena.canvas.set_angle_mode(GridTransformService.AngleMode.SYMMETRIC)
	arena._show_editor_canvas(false)
	arena.tool_list.select(ArenaStudioCanvas.Tool.SELECT)
	arena._on_tool_selected(ArenaStudioCanvas.Tool.SELECT)
	arena.canvas._live_transform_text = ""


func _select_transform() -> void:
	arena._select_tool_and_preset(ArenaStudioCanvas.Tool.TRANSFORM_GRID, 0)
	arena.canvas.grid_selected = true
	arena.canvas.queue_redraw()


func _apply_snapshot(value: GridTransformSnapshot) -> void:
	value.apply_to(arena.arena)
	ArenaRuntimeBridge.sync_runtime_resources(arena.arena)
	arena.canvas.queue_redraw()
	arena._refresh_transform_inspector()


func _apply_angle(degrees: float, mode: int) -> void:
	arena.canvas.set_angle_mode(mode)
	var result := GridTransformService.set_grid_angle(
		GridTransformSnapshot.from_arena(arena.arena), deg_to_rad(degrees), mode
	)
	if bool(result.get("ok", false)):
		_apply_snapshot(result.snapshot as GridTransformSnapshot)
		arena.canvas._live_transform_text = "Angle de la grille  %.1f deg — %s" % [
			degrees, ["Symétrique", "Conserver X", "Conserver Y"][mode]
		]


func _capture_metrics() -> Dictionary:
	return {
		"workspace_mode": arena.workspace_mode,
		"canvas_visible": arena.canvas.visible,
		"canvas_pixels": [arena.view_stack.size.x, arena.view_stack.size.y],
		"canvas_children": arena.view_stack.get_child_count(),
		"session_key": arena.edit_session.session_key,
		"history_identity": arena.edit_session.history.get_instance_id(),
		"input_router_identity": arena.canvas.input_router.get_instance_id(),
		"gizmo_visible": arena.canvas.affine_gizmo.visible,
		"dynamic_palette_visible": arena.dynamic_palette.visible,
		"window_count": _count_type(studio, "Window"),
		"popup_count": _count_type(studio, "Popup"),
	}


func _count_type(root: Node, requested: String) -> int:
	var result := 0
	for child in root.get_children():
		if child.is_class(requested):
			result += 1
		result += _count_type(child, requested)
	return result
