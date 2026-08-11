extends Control

const OUTPUT := "res://artifacts/arena_permanent_tile_alignment/captures"
const SIZES := [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440)]
const TEST_OPTIONS := {
	"spawn_enemies": false,
	"spawn_heroes": false,
	"deployment_enabled": false,
	"hud_enabled": false,
	"combat_enabled": false,
	"draw_base_cells": false,
	"draw_grid_lines": true,
	"draw_cell_centers": false,
	"draw_map_bounds": false,
	"draw_logic_types": false,
	"draw_void_cells": false,
	"draw_coordinates": false,
	"draw_spawns": false,
	"draw_calibration": false,
}

var _content: CanvasItem = null
var _overlay_layer: CanvasLayer
var _overlay_label: Label
var _captures: Array[Dictionary] = []
var _failures: Array[String] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	_build_overlay()
	for size in SIZES:
		get_window().size = size
		await _wait_frames(4)
		await _capture_canvas_case("01_stone", size, _filled_arena(&"stone"),
			"STONE — terrain permanent normalisé")
		await _capture_canvas_case("02_neutral", size, _filled_arena(&"neutral"),
			"NEUTRAL — même empreinte 256×128 que stone")
		await _capture_canvas_case("03_stone_neutral_checker", size, _checker_arena(),
			"DAMIER STONE / NEUTRAL — bords et grille communs")
		await _capture_canvas_case("04_water_permanent", size, _filled_arena(&"water"),
			"WATER — terrain permanent peignable")
		await _capture_canvas_case("05_ice_permanent", size, _filled_arena(&"ice"),
			"ICE — terrain permanent peignable")
		await _capture_palette_case("06_lava_disabled", size, &"lava")
		await _capture_palette_case("07_dropdown_contract", size, &"neutral")
		await _capture_preview_case("08_preview", size, _mixed_arena(),
			"PREVIEW — working copy projetée")
		await _capture_direct_case(size, _mixed_arena())
		await _capture_runtime_case(size, _mixed_arena())
	_write_report()
	print("PERMANENT_TILE_CAPTURE_COMPLETE=", JSON.stringify({
		"ok": _failures.is_empty(),
		"capture_count": _captures.size(),
		"failures": _failures,
		"produced_bundle_loaded": false,
	}))
	get_tree().quit(0 if _failures.is_empty() else 1)


func _capture_canvas_case(
		case_name: String,
		size: Vector2i,
		arena: ArenaDefinition,
		title: String
	) -> void:
	_clear_content()
	var canvas := ArenaStudioCanvas.new()
	canvas.name = "PermanentTileStudioCanvas"
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.show_grid = true
	canvas.grid_opacity = 0.72
	canvas.background_opacity = 0.0
	add_child(canvas)
	move_child(canvas, 0)
	_content = canvas
	_frame_arena(arena, size)
	canvas.set_arena(arena)
	_set_overlay(title, arena)
	await _save_case(case_name, size, arena, {
		"view": "studio_canvas",
		"terrain_map": _terrain_map(arena),
	})


func _capture_palette_case(
		case_name: String,
		size: Vector2i,
		selected_id: StringName
	) -> void:
	_clear_content()
	var arena := _mixed_arena()
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	move_child(panel, 0)
	_content = panel
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 80)
	margin.add_theme_constant_override("margin_top", 120)
	margin.add_theme_constant_override("margin_right", 80)
	margin.add_theme_constant_override("margin_bottom", 80)
	panel.add_child(margin)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 48)
	margin.add_child(columns)
	var list := VBoxContainer.new()
	list.custom_minimum_size.x = minf(920.0, size.x * 0.55)
	list.add_theme_constant_override("separation", 12)
	columns.add_child(list)
	var title := Label.new()
	title.text = "AUTORITÉ DES TERRAINS PERMANENTS"
	title.add_theme_font_size_override("font_size", 28)
	list.add_child(title)
	var option := OptionButton.new()
	option.custom_minimum_size = Vector2(780, 56)
	list.add_child(option)
	var selected_index := 0
	var entries := ArenaPermanentTerrainPaintService \
		.get_paintable_permanent_terrains(arena, true)
	for entry in entries:
		var enabled := bool(entry.enabled)
		var text := "%s  •  %s  •  %s" % [
			entry.display_name,
			entry.stable_id,
			"ACTIF" if enabled else "INACTIF — %s" % entry.reason,
		]
		option.add_item(text)
		var index := option.item_count - 1
		option.set_item_metadata(index, entry.stable_id)
		option.set_item_disabled(index, not enabled)
		if StringName(entry.stable_id) == selected_id:
			selected_index = index
		var row := Label.new()
		row.text = ("✓  " if enabled else "⊘  ") + text
		row.add_theme_font_size_override("font_size", 20)
		row.add_theme_color_override(
			"font_color", Color("b8f5c8") if enabled else Color("f4b3a8")
		)
		list.add_child(row)
	option.select(selected_index)
	var preview_canvas := ArenaStudioCanvas.new()
	preview_canvas.custom_minimum_size = Vector2(size.x * 0.34, size.y * 0.6)
	columns.add_child(preview_canvas)
	_frame_arena(arena, Vector2i(int(size.x * 0.34), int(size.y * 0.6)))
	preview_canvas.set_arena(arena)
	_set_overlay(
		"LAVA DÉSACTIVÉE — parité GridData non certifiée" \
		if selected_id == &"lava" else
		"DROPDOWN — aucune option fantôme active",
		arena
	)
	await _save_case(case_name, size, arena, {
		"view": "terrain_dropdown",
		"entries": entries.map(func(value): return {
			"stable_id": str(value.stable_id),
			"enabled": bool(value.enabled),
			"reason": str(value.reason),
		}),
	})


func _capture_preview_case(
		case_name: String,
		size: Vector2i,
		arena: ArenaDefinition,
		title: String
	) -> void:
	_clear_content()
	var preview := ArenaRuntimePreview.new()
	preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(preview)
	move_child(preview, 0)
	_content = preview
	await _wait_frames(2)
	preview.set_arena(arena, false)
	preview.set_view_mode(ArenaRuntimePreview.ViewMode.GAME)
	var rebuilt := preview.rebuild_now()
	var parity := preview.parity_with_runtime()
	if not rebuilt or not bool(parity.get("ok", false)):
		_fail("preview_parity_%dx%d:%s" % [size.x, size.y, parity])
	_set_overlay(title, arena)
	await _save_case(case_name, size, arena, {
		"view": "runtime_preview",
		"parity": parity,
	})


func _capture_direct_case(size: Vector2i, arena: ArenaDefinition) -> void:
	var prepared := ArenaDirectTestService.prepare(arena, null, &"no_characters")
	if not bool(prepared.get("ok", false)):
		_fail("direct_prepare_%dx%d:%s" % [size.x, size.y, prepared])
		return
	var request := prepared.request as Dictionary
	var temporary := ResourceLoader.load(
		request.arena_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as ArenaDefinition
	if temporary == null:
		_fail("direct_load_%dx%d" % [size.x, size.y])
		ArenaDirectTestService.cleanup_context(request)
		return
	await _capture_preview_case(
		"09_direct_test", size, temporary,
		"TEST DIRECT — working/temp/runtime fingerprints identiques"
	)
	if request.working_fingerprint != request.temporary_fingerprint \
			or request.working_fingerprint != request.runtime_fingerprint:
		_fail("direct_fingerprint_%dx%d" % [size.x, size.y])
	var last := _captures[-1]
	last["direct_request"] = {
		"arena_path": request.arena_path,
		"working_fingerprint": request.working_fingerprint,
		"temporary_fingerprint": request.temporary_fingerprint,
		"runtime_fingerprint": request.runtime_fingerprint,
		"produced_bundle_loaded": false,
	}
	_captures[-1] = last
	ArenaDirectTestService.cleanup_context(request)


func _capture_runtime_case(size: Vector2i, arena: ArenaDefinition) -> void:
	_clear_content()
	var run := RunData.new()
	run.run_name = "Permanent tile capture runtime"
	run.rooms = [arena]
	if not GameManager._prepare_preconfigured_run(run, [], true):
		_fail("runtime_prepare_%dx%d" % [size.x, size.y])
		return
	GameManager.current_room_index = 0
	get_tree().set_meta(&"arena_studio_test_options", TEST_OPTIONS.duplicate(true))
	var battle := (load(ArenaDefinition.MODULAR_BATTLE_SCENE) as PackedScene).instantiate()
	add_child(battle)
	move_child(battle, 0)
	_content = battle as CanvasItem
	await _wait_frames(14)
	var runtime_room := battle.get("room_data") as ArenaDefinition
	var runtime_grid := battle.get("grid") as GridData
	if runtime_room == null or runtime_grid == null:
		_fail("runtime_scene_contract_%dx%d" % [size.x, size.y])
	_set_overlay("VRAIE BATAILLE MODULAIRE — même ArenaDefinition temporaire", arena)
	await _save_case("10_runtime_battle", size, arena, {
		"view": "modular_battle_runtime",
		"room_fingerprint": ArenaSnapshotService.arena_fingerprint(runtime_room),
		"working_fingerprint": ArenaSnapshotService.arena_fingerprint(arena),
		"produced_bundle_loaded": false,
	})
	get_tree().remove_meta(&"arena_studio_test_options")
	GameManager.cleanup_run_state()


func _save_case(
		case_name: String,
		size: Vector2i,
		arena: ArenaDefinition,
		metrics: Dictionary
	) -> void:
	await _wait_frames(6)
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var file_name := "%s_%dx%d.png" % [case_name, size.x, size.y]
	var path := OUTPUT.path_join(file_name)
	var ok := image != null and not image.is_empty() \
		and image.save_png(ProjectSettings.globalize_path(path)) == OK
	if not ok:
		_fail("capture_failed:%s" % file_name)
	metrics.merge({
		"case": case_name,
		"resolution": [size.x, size.y],
		"path": path,
		"ok": ok,
		"arena_fingerprint": ArenaSnapshotService.arena_fingerprint(arena),
	}, true)
	_captures.append(metrics)


func _filled_arena(terrain_id: StringName) -> ArenaDefinition:
	var arena := _arena_fixture()
	for definition in arena.cells:
		if definition != null:
			ArenaDynamicEditingService.paint_terrain(
				arena, definition.coordinate, terrain_id
			)
	return arena


func _checker_arena() -> ArenaDefinition:
	var arena := _arena_fixture()
	for definition in arena.cells:
		if definition != null:
			ArenaDynamicEditingService.paint_terrain(
				arena, definition.coordinate,
				&"neutral" if (definition.coordinate.x + definition.coordinate.y) % 2 == 0 \
				else &"stone"
			)
	return arena


func _mixed_arena() -> ArenaDefinition:
	var arena := _arena_fixture()
	var ids := [&"stone", &"neutral", &"water", &"ice"]
	for definition in arena.cells:
		if definition != null:
			ArenaDynamicEditingService.paint_terrain(
				arena, definition.coordinate,
				ids[(definition.coordinate.x + definition.coordinate.y) % ids.size()]
			)
	return arena


func _arena_fixture() -> ArenaDefinition:
	var arena := ArenaDefinition.new()
	arena.set_identity("Capture terrain permanent", "permanent_tile_capture")
	arena.visual_mode = ArenaDefinition.VisualMode.MODULAR
	arena.theme_id = &"forest"
	arena.grid_size = Vector2i(7, 5)
	arena.modular_visual_profile = ArenaModularVisualProfile.new()
	arena.modular_visual_profile.theme_id = &"forest"
	arena.modular_visual_profile.hybrid_floor_policy = (
		ArenaModularVisualProfile.HybridFloorPolicy.ALL_DEFINED
	)
	for y in range(arena.grid_size.y):
		for x in range(arena.grid_size.x):
			ArenaTerrainRegistry.configure_cell(
				arena.ensure_cell(Vector2i(x, y)), &"stone"
			)
	ArenaRuntimeBridge.sync_runtime_resources(arena)
	return arena


func _frame_arena(arena: ArenaDefinition, size: Vector2i) -> void:
	var axis_width := clampf(size.x / 13.0, 86.0, 150.0)
	arena.axis_x = Vector2(axis_width, axis_width * 0.5)
	arena.axis_y = Vector2(-axis_width, axis_width * 0.5)
	arena.grid_origin = Vector2(size.x * 0.5, size.y * 0.14)
	ArenaRuntimeBridge.sync_runtime_resources(arena)


func _terrain_map(arena: ArenaDefinition) -> Dictionary:
	var result := {}
	for definition in arena.cells:
		if definition != null:
			result["%d,%d" % [definition.coordinate.x, definition.coordinate.y]] = str(
				definition.terrain_id
			)
	return result


func _build_overlay() -> void:
	_overlay_layer = CanvasLayer.new()
	_overlay_layer.layer = 100
	add_child(_overlay_layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(24, 24)
	panel.custom_minimum_size = Vector2(760, 86)
	_overlay_layer.add_child(panel)
	_overlay_label = Label.new()
	_overlay_label.add_theme_font_size_override("font_size", 19)
	_overlay_label.add_theme_color_override("font_color", Color.WHITE)
	_overlay_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	_overlay_label.add_theme_constant_override("shadow_offset_x", 2)
	_overlay_label.add_theme_constant_override("shadow_offset_y", 2)
	panel.add_child(_overlay_label)


func _set_overlay(title: String, arena: ArenaDefinition) -> void:
	_overlay_label.text = (
		"ARENA PERMANENT TILE ALIGNMENT — WORKTREE CANDIDATE\n%s\n"
		+ "Cells=%d • fingerprint=%s"
	) % [title, arena.cells.size(), ArenaSnapshotService.arena_fingerprint(arena)]


func _clear_content() -> void:
	if is_instance_valid(_content):
		_content.free()
	_content = null
	GameManager.cleanup_run_state()
	if get_tree().has_meta(&"arena_studio_test_options"):
		get_tree().remove_meta(&"arena_studio_test_options")


func _write_report() -> void:
	var file := FileAccess.open(OUTPUT.get_base_dir().path_join("capture_report.json"), FileAccess.WRITE)
	if file == null:
		_fail("capture_report_write_failed")
		return
	file.store_string(JSON.stringify({
		"schema_version": 1,
		"mission": "ARENA PERMANENT TILE ALIGNMENT AND TERRAIN BRUSH PARITY FIX",
		"captures": _captures,
		"failures": _failures,
		"produced_bundle_loaded": false,
	}, "  "))
	file.close()


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _wait_frames(count: int) -> void:
	for _frame in range(count):
		await get_tree().process_frame
