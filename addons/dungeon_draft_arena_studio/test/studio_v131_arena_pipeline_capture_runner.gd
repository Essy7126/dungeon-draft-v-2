extends Control

const OUTPUT := "res://artifacts/studio_1_3_1/screenshots/after"
const SIZES := [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440)]
const CASES := [
	"01_new_modular", "02_stone", "03_water", "04_ice", "05_lava", "06_void",
	"07_walls", "08_terrains_and_walls", "09_dynamic_integrated", "10_terrain_palette",
	"11_brush_preview", "12_logic_preview", "13_art_preview", "14_game_preview",
	"15_painted_conversion_dialog", "16_hybrid_overlays", "17_standalone_lab",
	"18_transfer_detected", "19_transfer_imported", "20_production_wizard",
	"21_room_ready", "22_forest_unchanged", "23_volcano_unchanged", "24_space_unchanged",
]

var workspace: StudioWorkspace
var studio: ArenaStudioMain
var standalone_lab: DynamicArenaLab
var fixture: ArenaDefinition
var transfer_id := ""
var metrics := {"studio_product_version": StudioVersion.PRODUCT_VERSION}


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	for requested_size in SIZES:
		get_window().size = requested_size
		await get_tree().process_frame
		workspace = StudioWorkspace.new()
		workspace.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(workspace)
		for frame in range(5):
			await get_tree().process_frame
		studio = workspace.arena_studio
		var size_key := "%dx%d" % [requested_size.x, requested_size.y]
		metrics[size_key] = {}
		for case_name in CASES:
			await _configure(case_name)
			for frame in range(4):
				await get_tree().process_frame
			metrics[size_key][case_name] = _capture_metrics()
			var path := OUTPUT.path_join("arena_131_%s_%s.png" % [case_name, size_key])
			var image := get_viewport().get_texture().get_image()
			if image == null or image.is_empty() or image.save_png(
					ProjectSettings.globalize_path(path)
				) != OK:
				push_error("Capture Arena 1.3.1 impossible : %s" % path)
				get_tree().quit(1)
				return
			print("ARENA_131_CAPTURE ", path)
		_cleanup_transient_ui()
		workspace.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	var file := FileAccess.open(OUTPUT.path_join("capture_metrics.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(metrics, "  "))
		file.close()
	print("ARENA_131_CAPTURE_MATRIX_COMPLETE ", SIZES.size() * CASES.size())
	get_tree().quit()


func _configure(case_name: String) -> void:
	_cleanup_transient_ui()
	workspace.show()
	fixture = _fixture()
	studio._set_arena(fixture, true, "capture:%s:%d" % [case_name, Time.get_ticks_usec()])
	studio._show_editor_canvas(false)
	match case_name:
		"01_new_modular":
			studio._set_status("Nouvelle arène MODULAR 10 × 8 — sol complet")
		"02_stone":
			_focus_terrain(&"stone", Vector2i(2, 2))
		"03_water":
			_focus_terrain(&"water", Vector2i(3, 2))
		"04_ice":
			_focus_terrain(&"ice", Vector2i(4, 2))
		"05_lava":
			_focus_terrain(&"lava", Vector2i(5, 2))
		"06_void":
			_focus_terrain(&"void", Vector2i(6, 2))
		"07_walls":
			studio.show_dynamic_construction()
			studio._select_dynamic_tool(ArenaStudioCanvas.Tool.OBSTACLE)
			studio._set_status("Murs normal, feu et glace — couche indépendante")
		"08_terrains_and_walls":
			studio.show_dynamic_construction()
			studio._set_status("16 variantes visibles : terrains et murs assemblés ensemble")
		"09_dynamic_integrated":
			studio.show_dynamic_construction()
		"10_terrain_palette":
			studio.show_dynamic_construction()
			studio.dynamic_terrain_option.select(2)
			studio._select_dynamic_tool(ArenaStudioCanvas.Tool.TERRAIN)
		"11_brush_preview":
			studio.show_dynamic_construction()
			studio.canvas.set_brush_preview_terrain(&"lava")
			studio.canvas._hovered = Vector2i(5, 3)
			studio.canvas.queue_redraw()
		"12_logic_preview":
			await _show_preview(ArenaRuntimePreview.ViewMode.LOGIC)
		"13_art_preview":
			await _show_preview(ArenaRuntimePreview.ViewMode.ART)
		"14_game_preview":
			await _show_preview(ArenaRuntimePreview.ViewMode.GAME)
		"15_painted_conversion_dialog":
			studio.load_production(&"room_01_forest")
			studio.show_dynamic_construction()
		"16_hybrid_overlays":
			studio.load_production(&"room_01_forest")
			studio._convert_painted_to_hybrid()
			ArenaDynamicEditingService.paint_terrain(studio.arena, Vector2i(5, 4), &"water")
			ArenaDynamicEditingService.paint_terrain(studio.arena, Vector2i(6, 4), &"ice")
			ArenaDynamicEditingService.paint_terrain(studio.arena, Vector2i(7, 4), &"lava")
			studio.canvas.refresh_terrain_plan()
			studio.canvas.queue_redraw()
		"17_standalone_lab":
			workspace.hide()
			standalone_lab = (load(
				"res://tools/labs/dynamic_arena/DynamicArenaLab.tscn"
			) as PackedScene).instantiate() as DynamicArenaLab
			add_child(standalone_lab)
			await get_tree().process_frame
			standalone_lab.new_document(Vector2i(10, 8), "Lab standalone", "capture_lab")
			standalone_lab.set_cell_surface(Vector2i(3, 3), DynamicCellState.Surface.WATER)
			standalone_lab.set_cell_surface(Vector2i(4, 3), DynamicCellState.Surface.ICE)
			standalone_lab.place_wall(Vector2i(5, 4), DynamicWall.WallVariant.FIRE)
		"18_transfer_detected":
			_create_transfer()
			studio.show_lab_import_dialog()
		"19_transfer_imported":
			_create_transfer()
			var loaded := ArenaLabTransferService.load_transfer(transfer_id)
			if bool(loaded.get("ok", false)):
				studio._set_arena(loaded.arena as ArenaDefinition, true, "capture_transfer")
				studio.show_dynamic_construction()
				studio._set_status("Transfert importé sans perte — working copy")
		"20_production_wizard":
			studio.show_production_wizard()
		"21_room_ready":
			studio.show_production_wizard()
			studio.production_destination_edit.text = (
				"res://artifacts/studio_1_3_1/capture_room_ready"
			)
			await studio._run_confirmed_production()
		"22_forest_unchanged":
			studio.load_production(&"room_01_forest")
			await _show_preview(ArenaRuntimePreview.ViewMode.GAME)
		"23_volcano_unchanged":
			studio.load_production(&"room_05_volcano")
			await _show_preview(ArenaRuntimePreview.ViewMode.GAME)
		"24_space_unchanged":
			studio.load_production(&"room_06_space")
			await _show_preview(ArenaRuntimePreview.ViewMode.GAME)


func _focus_terrain(terrain_id: StringName, cell: Vector2i) -> void:
	studio.show_dynamic_construction()
	studio.canvas.selected_cells = [cell]
	studio.canvas.set_brush_preview_terrain(terrain_id)
	studio.canvas._hovered = cell
	studio.canvas.queue_redraw()
	studio._set_status("terrain_id = %s — texture réelle" % terrain_id)


func _show_preview(mode: int) -> void:
	studio.set_preview_view(mode)
	studio.runtime_preview.rebuild_now()
	await get_tree().process_frame


func _create_transfer() -> void:
	var validation := ArenaValidator.validate(fixture, false)
	var result := ArenaLabTransferService.create_transfer(fixture, validation)
	if bool(result.get("ok", false)):
		transfer_id = str(result.transfer_id)


func _cleanup_transient_ui() -> void:
	if is_instance_valid(standalone_lab):
		standalone_lab.free()
	standalone_lab = null
	if not transfer_id.is_empty():
		ArenaLabTransferService.delete_transfer(transfer_id)
		transfer_id = ""
	if studio != null and is_instance_valid(studio):
		for dialog in [studio.painted_dynamic_dialog, studio.lab_import_dialog, studio.production_dialog]:
			if dialog != null:
				dialog.hide()


func _capture_metrics() -> Dictionary:
	if standalone_lab != null and is_instance_valid(standalone_lab):
		return {
			"standalone_lab": true,
			"terrain_nodes": standalone_lab.floor_layer.get_child_count(),
			"dynamic_nodes": standalone_lab.dynamic_object_layer.get_child_count(),
		}
	var preview_report := studio.runtime_preview.assembly.get("report") as ArenaVisualAssemblyReport
	return {
		"visual_mode": studio.arena.visual_mode,
		"workspace_mode": studio.workspace_mode,
		"canvas_visible": studio.canvas.visible,
		"dynamic_palette_visible": studio.dynamic_palette.visible,
		"expected_terrain_nodes": preview_report.expected_terrain_cell_count if preview_report != null else -1,
		"rendered_terrain_nodes": preview_report.rendered_terrain_node_count if preview_report != null else -1,
		"rendered_walls": preview_report.rendered_wall_count if preview_report != null else -1,
	}


func _fixture() -> ArenaDefinition:
	var arena := ArenaDefinition.new()
	arena.set_identity("Capture Pipeline 1.3.1", "capture_pipeline_131")
	arena.visual_mode = ArenaDefinition.VisualMode.MODULAR
	arena.theme_id = &"dynamic_default"
	arena.modular_visual_profile = ArenaModularVisualProfile.new()
	arena.grid_size = Vector2i(10, 8)
	arena.grid_origin = Vector2(640, 130)
	arena.axis_x = Vector2(42, 21)
	arena.axis_y = Vector2(-42, 21)
	for y in range(arena.grid_size.y):
		for x in range(arena.grid_size.x):
			var terrain_id := &"stone"
			if x in [2, 3] and y in [2, 3]:
				terrain_id = &"water"
			elif x in [4, 5] and y in [2, 3]:
				terrain_id = &"ice"
			elif x in [6, 7] and y in [2, 3]:
				terrain_id = &"lava"
			elif Vector2i(x, y) in [Vector2i(1, 5), Vector2i(2, 5), Vector2i(7, 5)]:
				terrain_id = &"void"
			ArenaTerrainRegistry.configure_cell(arena.ensure_cell(Vector2i(x, y)), terrain_id)
	ArenaEditingService.prepare_automatically(arena)
	for value in [
		[Vector2i(3, 4), &"normal"],
		[Vector2i(4, 4), &"fire"],
		[Vector2i(5, 4), &"ice"],
	]:
		ArenaDynamicEditingService.place_wall(arena, value[0], value[1])
	var objective := ArenaObjectiveDefinition.new()
	objective.objective_id = &"capture_objective"
	objective.cell = Vector2i(6, 5)
	arena.objectives.append(objective)
	ArenaRuntimeBridge.sync_runtime_resources(arena)
	return arena
