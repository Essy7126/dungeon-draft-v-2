extends Control

const OUTPUT := "res://artifacts/studio_1_2/screenshots"
const SIZES := [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440)]
const CASES := [
	"02_integrated_after", "03_dedicated_window", "04_maximized_window",
	"05_focus_map", "06_dynamic_construction", "07_calibration", "08_gameplay",
	"09_preview_logic", "10_preview_art", "11_preview_game", "12_lab_import",
	"13_transfer_detected", "14_production_wizard", "15_room_ready",
	"16_forest", "17_volcano", "18_space", "19_modular_fixture", "20_hybrid_fixture",
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
		_copy_before_capture(requested_size)
		studio = StudioWorkspace.new()
		studio.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(studio)
		for _frame in range(8):
			await get_tree().process_frame
		arena = studio.arena_studio
		var key := "%dx%d" % [requested_size.x, requested_size.y]
		metrics[key] = {}
		for case_name in CASES:
			await _configure(case_name)
			for _frame in range(4):
				await get_tree().process_frame
			var ratio := arena.canvas_occupation_ratio()
			metrics[key][case_name] = {
				"canvas_ratio": [ratio.x, ratio.y],
				"canvas_pixels": [arena.view_stack.size.x, arena.view_stack.size.y],
				"left_visible": arena.left_panel.visible,
				"right_visible": arena.right_panel.visible,
				"drawer_visible": arena.bottom_drawer_content.visible,
			}
			var output := OUTPUT.path_join("studio_v12_%s_%s.png" % [case_name, key])
			var image := get_viewport().get_texture().get_image()
			if image == null or image.is_empty() or image.save_png(
					ProjectSettings.globalize_path(output)
				) != OK:
				push_error("Capture impossible : %s" % output)
				get_tree().quit(1)
				return
			print("STUDIO_V12_CAPTURE ", output)
		studio.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	var file := FileAccess.open(OUTPUT.path_join("capture_metrics.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(metrics, "  "))
		file.close()
	print("STUDIO_V12_CAPTURE_MATRIX_COMPLETE ", SIZES.size() * 20)
	get_tree().quit()


func _configure(case_name: String) -> void:
	_reset_ui()
	match case_name:
		"03_dedicated_window":
			studio.set_detached_state(true)
			studio.detach_button.text = "RÉINTÉGRER LA FENÊTRE"
		"04_maximized_window":
			studio.set_detached_state(true)
			studio.detach_button.text = "FENÊTRE MAXIMISÉE"
			arena.apply_workspace_preset(3)
		"05_focus_map":
			arena.set_focus_map(true)
		"06_dynamic_construction":
			arena.show_dynamic_construction()
		"07_calibration":
			arena.apply_workspace_preset(1)
		"08_gameplay":
			arena.apply_workspace_preset(2)
		"09_preview_logic":
			arena.set_preview_view(ArenaRuntimePreview.ViewMode.LOGIC)
			arena.runtime_preview.rebuild_now()
		"10_preview_art":
			arena.set_preview_view(ArenaRuntimePreview.ViewMode.ART)
			arena.runtime_preview.rebuild_now()
		"11_preview_game":
			arena.set_preview_view(ArenaRuntimePreview.ViewMode.GAME)
			arena.runtime_preview.rebuild_now()
		"12_lab_import":
			arena._set_arena(_modular_fixture(), true, "capture:lab_import")
			arena.show_dynamic_construction()
			arena._set_status("Transfert Lab importé — aucune donnée perdue")
		"13_transfer_detected":
			arena._set_status("Transfert Dynamic Arena Lab détecté — cliquez sur Lab pour l'importer")
		"14_production_wizard":
			arena.show_production_wizard()
			arena.production_tabs.current_tab = 3
		"15_room_ready":
			arena.show_production_wizard()
			arena.production_result_text.text = (
				"[font_size=30][b][color=green]SALLE PRÊTE[/color][/b][/font_size]\n\n"
				+ "✓ Définition  ✓ Grille  ✓ Pathfinding  ✓ Spawns\n"
				+ "✓ Rendu  ✓ Preview runtime  ✓ Ressources rechargées  ✓ Test direct"
			)
			arena.production_tabs.current_tab = 4
			arena.production_dialog.get_ok_button().hide()
		"16_forest":
			arena.load_production(&"room_01_forest")
			arena.set_preview_view(ArenaRuntimePreview.ViewMode.GAME)
			arena.runtime_preview.rebuild_now()
		"17_volcano":
			arena.load_production(&"room_05_volcano")
			arena.set_preview_view(ArenaRuntimePreview.ViewMode.GAME)
			arena.runtime_preview.rebuild_now()
		"18_space":
			arena.load_production(&"room_06_space")
			arena.set_preview_view(ArenaRuntimePreview.ViewMode.GAME)
			arena.runtime_preview.rebuild_now()
		"19_modular_fixture":
			arena._set_arena(_modular_fixture(), true, "capture:modular")
			arena.set_preview_view(ArenaRuntimePreview.ViewMode.GAME)
			arena.runtime_preview.rebuild_now()
		"20_hybrid_fixture":
			var hybrid := ArenaLegacyImporter.import_production(&"room_01_forest")
			hybrid.visual_mode = ArenaDefinition.VisualMode.HYBRID
			hybrid.modular_visual_profile = ArenaModularVisualProfile.new()
			for cell in [Vector2i(6, 4), Vector2i(7, 4), Vector2i(7, 5)]:
				var definition := hybrid.ensure_cell(cell)
				ArenaTerrainRegistry.configure_cell(definition, &"water")
			ArenaRuntimeBridge.sync_runtime_resources(hybrid)
			arena._set_arena(hybrid, true, "capture:hybrid")
			arena.set_preview_view(ArenaRuntimePreview.ViewMode.GAME)
			arena.runtime_preview.rebuild_now()


func _reset_ui() -> void:
	if arena.production_dialog != null:
		arena.production_dialog.hide()
	studio.set_detached_state(false)
	studio.detach_button.text = "Détacher la fenêtre"
	if arena.focus_map_enabled:
		arena.set_focus_map(false)
	arena.apply_workspace_preset(0)
	arena.load_production(&"room_01_forest")
	arena._show_editor_canvas()


func _copy_before_capture(size: Vector2i) -> void:
	var source := "res://artifacts/arena_studio/screenshots/arena_studio_creation_forest_%dx%d.png" % [size.x, size.y]
	var target := OUTPUT.path_join("studio_v12_01_integrated_before_%dx%d.png" % [size.x, size.y])
	if FileAccess.file_exists(source):
		DirAccess.copy_absolute(
			ProjectSettings.globalize_path(source), ProjectSettings.globalize_path(target)
		)


func _modular_fixture() -> ArenaDefinition:
	var value := ArenaDefinition.new()
	value.set_identity("Fixture modulaire Lab", "fixture_modulaire_lab")
	value.visual_mode = ArenaDefinition.VisualMode.MODULAR
	value.theme_id = &"dynamic_default"
	value.modular_visual_profile = ArenaModularVisualProfile.new()
	value.grid_size = Vector2i(12, 9)
	value.axis_x = Vector2(32, 16)
	value.axis_y = Vector2(-32, 16)
	for y in range(value.grid_size.y):
		for x in range(value.grid_size.x):
			var terrain_id: StringName = [&"stone", &"water", &"ice", &"stone"][(x + y) % 4]
			ArenaTerrainRegistry.configure_cell(value.ensure_cell(Vector2i(x, y)), terrain_id)
	ArenaEditingService.prepare_automatically(value)
	for entry in [[Vector2i(5, 4), &"fire"], [Vector2i(7, 4), &"ice"]]:
		var wall := ArenaObstacleDefinition.new()
		wall.cell = entry[0]
		wall.wall_id = entry[1]
		wall.wall_config = ArenaWallRegistry.config_for(entry[1])
		value.obstacles.append(wall)
	ArenaRuntimeBridge.sync_runtime_resources(value)
	return value
