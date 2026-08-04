extends Node

const OUTPUT_DIR := "res://artifacts/labs/forest_arena_integration/testv1"
const SOURCE_BACKGROUND := (
	"res://asset/map/painted/room_01_forest/forest_background_v3.png"
)
const MAP_REFERENCE := "res://tools/arena_map_editor/testv1/map_reference.png"
const MAP_LOGIC := "res://tools/arena_map_editor/testv1/map_logic.png"
const LAB_SCENE := preload(
	"res://tools/labs/forest_arena_integration/ForestArenaIntegrationTest.tscn"
)
const VIEWPORT_SIZE := Vector2i(1672, 941)
const COMPARISON_SIZE := Vector2i(1920, 1080)

var lab: ForestArenaIntegrationTest = null
var failures := 0


func _ready() -> void:
	call_deferred("_capture_all")


func _capture_all() -> void:
	get_window().size = VIEWPORT_SIZE
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	lab = LAB_SCENE.instantiate() as ForestArenaIntegrationTest
	add_child(lab)
	await _settle(10)
	if not lab.validation_errors.is_empty():
		push_error("Scene invalide : %s" % lab.validation_errors)
		get_tree().quit(1)
		return

	_copy_source_image()
	_create_comparison(MAP_REFERENCE, "map_reference_comparison.png")
	_create_comparison(MAP_LOGIC, "map_logic_comparison.png")

	lab.reset_test()
	lab.set_capture_layers(true, false, false, false, false, false, false, false)
	lab.set_debug_modes(false, false, false)
	await _capture("painted_background_only.png")

	lab.reset_test()
	lab.clear_all_surfaces()
	lab.set_capture_layers(false, true, false, false, false, false, false, false)
	lab.set_debug_modes(true, false, false)
	await _capture("dynamic_grid_only.png")

	lab.set_capture_layers(true, true, false, false, false, false, false, false)
	lab.set_debug_modes(false, false, false)
	await _capture("overlay_alignment.png")

	lab.set_debug_modes(true, false, true)
	await _capture("overlay_alignment_corners.png")

	lab.reset_test()
	lab.set_capture_layers(true, true, true, true, true, false, false, false)
	lab.set_debug_modes(true, true, true)
	await _capture("playable_border_void_debug.png")

	lab.set_capture_layers(false, true, false, false, false, false, false, false)
	lab.set_debug_modes(true, true, true)
	await _capture("border_removed_debug.png")

	lab.clear_all_surfaces()
	lab.set_capture_layers(true, true, false, false, false, false, false, false)
	lab.set_debug_modes(false, false, false)
	await _capture("neutral_tiles.png")

	_prepare_surface_demo(CellSurfaceState.DynamicSurface.FIRE, [
		Vector2i(5, 10), Vector2i(6, 10), Vector2i(7, 10),
		Vector2i(5, 11), Vector2i(6, 11),
	])
	await _capture("fire_tiles.png")

	_prepare_surface_demo(CellSurfaceState.DynamicSurface.WATER, [
		Vector2i(5, 10), Vector2i(6, 10), Vector2i(7, 10),
		Vector2i(7, 11), Vector2i(8, 11),
	])
	await _capture("water_tiles.png")

	_prepare_surface_demo(CellSurfaceState.DynamicSurface.ICE, [
		Vector2i(4, 10), Vector2i(5, 10), Vector2i(6, 10),
		Vector2i(5, 11), Vector2i(6, 11),
	])
	await _capture("ice_tiles.png")

	lab.clear_all_surfaces()
	lab.apply_surface_effect(Vector2i(5, 10), CellSurfaceState.DynamicSurface.FIRE)
	lab.apply_surface_effect(Vector2i(5, 10), CellSurfaceState.DynamicSurface.WATER)
	lab.apply_surface_effect(Vector2i(6, 10), CellSurfaceState.DynamicSurface.FIRE)
	lab.apply_surface_effect(Vector2i(6, 10), CellSurfaceState.DynamicSurface.ICE)
	lab.apply_surface_effect(Vector2i(7, 10), CellSurfaceState.DynamicSurface.WATER)
	lab.apply_surface_effect(Vector2i(7, 10), CellSurfaceState.DynamicSurface.ICE)
	lab.apply_surface_effect(Vector2i(8, 10), CellSurfaceState.DynamicSurface.ICE)
	lab.apply_surface_effect(Vector2i(8, 10), CellSurfaceState.DynamicSurface.FIRE)
	lab.set_capture_layers(true, true, true, false, false, false, false, false)
	await _capture("surface_interactions.png")

	lab.reset_test()
	lab.set_capture_layers(true, true, true, true, false, false, false, true)
	lab.set_debug_modes(false, false, false)
	lab.inspector_label.text = "MURS STATIQUES DU JSON : %d (aucun mur inventé)" % lab._static_walls.size()
	await _capture("static_walls.png")

	lab.clear_surface_effect(Vector2i(5, 7))
	lab.place_dynamic_wall(Vector2i(5, 7), DynamicWall.WallVariant.BASE)
	lab.set_capture_layers(true, true, true, true, true, false, false, true)
	lab.inspector_label.text = "MUR DYNAMIQUE 5,7 • mouvement / LOS / projectile bloqués"
	await _capture("dynamic_wall.png")

	lab.reset_test()
	lab.set_capture_layers(true, true, true, true, true, true, true, false)
	lab.set_debug_modes(true, false, false)
	await _capture("pathfinding_center.png")

	lab.set_unit_cells(Vector2i(1, 1), Vector2i(12, 13))
	lab.set_capture_layers(true, true, true, true, true, true, true, false)
	lab.set_debug_modes(true, true, true)
	await _capture("pathfinding_border.png")

	lab.reset_test()
	lab.clear_surface_effect(Vector2i(5, 7))
	lab.set_unit_cells(Vector2i(2, 7), Vector2i(8, 7))
	lab.place_dynamic_wall(Vector2i(5, 7), DynamicWall.WallVariant.BASE)
	lab.set_capture_layers(true, true, true, true, true, true, false, true)
	lab.set_debug_modes(false, false, false)
	lab.inspector_label.text = "LOS 2,7 → 8,7 : %s" % (
		"LIBRE" if lab.has_line_of_sight(Vector2i(2, 7), Vector2i(8, 7)) else "BLOQUÉE"
	)
	await _capture("los_blocked.png")

	lab.inspector_label.text = "PROJECTILE 2,7 → 8,7 : %s" % (
		"LIBRE" if lab.has_projectile_path(Vector2i(2, 7), Vector2i(8, 7)) else "BLOQUÉ"
	)
	await _capture("projectile_blocked.png")

	lab.reset_test()
	lab.set_capture_layers(true, true, true, true, true, true, false, false)
	lab.set_debug_modes(false, false, false)
	await _capture("units_on_arena.png")

	lab.clear_surface_effect(Vector2i(5, 7))
	lab.place_dynamic_wall(Vector2i(5, 7), DynamicWall.WallVariant.FIRE)
	lab.set_capture_layers(true, true, true, true, true, true, true, true)
	lab.set_debug_modes(true, true, false)
	lab.inspector_label.text = "JSON autorité • couronne non jouable • F6 prêt"
	await _settle(60)
	await _capture("final_forest_arena_test.png")

	# Exclude synchronous PNG encoding from the gameplay FPS measurement.
	await _settle(90)
	lab.reset_performance_samples()
	await _settle(180)
	_save_metrics()
	_validate_outputs()
	print("FOREST_ARENA_CAPTURE_FAILURES=%d" % failures)
	get_tree().quit(1 if failures > 0 else 0)


func _prepare_surface_demo(surface: int, cells: Array[Vector2i]) -> void:
	lab.reset_test()
	lab.clear_all_surfaces()
	for cell in cells:
		lab.apply_surface_effect(cell, surface, null)
	lab.set_capture_layers(true, true, true, false, false, false, false, false)
	lab.set_debug_modes(false, false, false)


func _copy_source_image() -> void:
	var source_path := ProjectSettings.globalize_path(SOURCE_BACKGROUND)
	var output_path := ProjectSettings.globalize_path(
		OUTPUT_DIR.path_join("source_forest_background_v3.png")
	)
	var error := DirAccess.copy_absolute(source_path, output_path)
	if error != OK:
		failures += 1


func _create_comparison(reference_path: String, output_name: String) -> void:
	var reference := Image.load_from_file(ProjectSettings.globalize_path(reference_path))
	var background := Image.load_from_file(ProjectSettings.globalize_path(SOURCE_BACKGROUND))
	if reference == null or reference.is_empty() or background == null or background.is_empty():
		failures += 1
		return
	var board := Image.create(COMPARISON_SIZE.x, COMPARISON_SIZE.y, false, Image.FORMAT_RGBA8)
	board.fill(Color("0d1520"))
	_blit_fitted(board, reference, Rect2i(24, 24, 924, 1032))
	_blit_fitted(board, background, Rect2i(972, 24, 924, 1032))
	var error := board.save_png(ProjectSettings.globalize_path(OUTPUT_DIR.path_join(output_name)))
	if error != OK:
		failures += 1


func _blit_fitted(board: Image, source: Image, target: Rect2i) -> void:
	var scale := minf(
		float(target.size.x) / float(source.get_width()),
		float(target.size.y) / float(source.get_height())
	)
	var fitted_size := Vector2i(
		maxi(1, roundi(source.get_width() * scale)),
		maxi(1, roundi(source.get_height() * scale))
	)
	var copy := source.duplicate()
	copy.convert(Image.FORMAT_RGBA8)
	copy.resize(fitted_size.x, fitted_size.y, Image.INTERPOLATE_LANCZOS)
	var position := target.position + (target.size - fitted_size) / 2
	board.blit_rect(copy, Rect2i(Vector2i.ZERO, fitted_size), position)


func _capture(file_name: String) -> void:
	await _settle(5)
	var texture := get_viewport().get_texture()
	if texture == null:
		failures += 1
		return
	var image := texture.get_image()
	if image == null or image.is_empty():
		failures += 1
		return
	var error := image.save_png(ProjectSettings.globalize_path(OUTPUT_DIR.path_join(file_name)))
	if error != OK:
		failures += 1
	else:
		print("CAPTURED %s" % file_name)


func _save_metrics() -> void:
	var metrics := lab.get_quality_metrics()
	metrics["geometry_verdict"] = ForestArenaIntegrationTest.CONFIG.geometry_match
	metrics["playable"] = lab.map_model.cells_in_category(
		ForestArenaIntegrationMap.CellCategory.PLAYABLE
	).size()
	metrics["border"] = lab.map_model.cells_in_category(
		ForestArenaIntegrationMap.CellCategory.BORDER
	).size()
	metrics["void"] = lab.map_model.cells_in_category(
		ForestArenaIntegrationMap.CellCategory.VOID
	).size()
	metrics["static_walls_from_json"] = lab._static_walls.size()
	metrics["source_image_sha256_audit"] = (
		"4F8B69ADD576DF1B74180F318C4B04B2E396F0ADA539C5F4DC3CF74D8A897DC9"
	)
	var file := FileAccess.open(
		ProjectSettings.globalize_path(OUTPUT_DIR.path_join("quality_metrics.json")),
		FileAccess.WRITE
	)
	if file == null:
		failures += 1
		return
	file.store_string(JSON.stringify(metrics, "  "))


func _validate_outputs() -> void:
	for file_name in [
		"source_forest_background_v3.png", "map_reference_comparison.png",
		"map_logic_comparison.png", "painted_background_only.png",
		"dynamic_grid_only.png", "overlay_alignment.png",
		"overlay_alignment_corners.png", "playable_border_void_debug.png",
		"border_removed_debug.png", "neutral_tiles.png", "fire_tiles.png",
		"water_tiles.png", "ice_tiles.png", "surface_interactions.png",
		"static_walls.png", "dynamic_wall.png", "pathfinding_center.png",
		"pathfinding_border.png", "los_blocked.png", "projectile_blocked.png",
		"units_on_arena.png", "final_forest_arena_test.png", "quality_metrics.json",
	]:
		if not FileAccess.file_exists(OUTPUT_DIR.path_join(file_name)):
			push_error("Sortie manquante : %s" % file_name)
			failures += 1


func _settle(frame_count: int) -> void:
	for _frame in range(frame_count):
		await get_tree().process_frame
