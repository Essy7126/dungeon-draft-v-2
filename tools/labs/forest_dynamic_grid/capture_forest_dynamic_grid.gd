extends Node

## Genere les onze vues d'acceptation depuis la scene de laboratoire isolee.

const OUTPUT_DIR := "res://artifacts/labs/forest_dynamic_grid"
const LAB_SCENE_PATH := "res://tools/labs/forest_dynamic_grid/ForestDynamicTest.tscn"
const VIEWPORT_SIZE := Vector2i(1376, 768)
const NONE := CellSurfaceState.DynamicSurface.NONE
const FIRE := CellSurfaceState.DynamicSurface.FIRE
const WATER := CellSurfaceState.DynamicSurface.WATER
const ICE := CellSurfaceState.DynamicSurface.ICE

var lab: ForestDynamicTest = null
var failures := 0


func _ready() -> void:
	call_deferred("_capture_all")


func _capture_all() -> void:
	get_window().size = VIEWPORT_SIZE
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var packed := load(LAB_SCENE_PATH) as PackedScene
	if packed == null:
		push_error("Scene forestiere introuvable.")
		get_tree().quit(1)
		return
	lab = packed.instantiate() as ForestDynamicTest
	add_child(lab)
	await _settle(8)

	lab.reset_test()
	lab.set_capture_layers(true, false, false, 0, false, false)
	await _capture("forest_original.png")

	lab.reset_test()
	lab.set_capture_layers(false, false, false, 0, false, false)
	await _capture("forest_dynamic_neutral_grid.png")

	lab.reset_test()
	lab.set_capture_layers(false, false, false, 2, false, false)
	await _capture("forest_full_grid_alignment.png")

	lab.reset_test()
	lab.set_capture_layers(false, true, false, 0, false, false)
	await _capture("forest_with_static_walls.png")

	_prepare_surface_demo(FIRE, [
		Vector2i(4, 4), Vector2i(5, 4), Vector2i(6, 4),
		Vector2i(7, 4), Vector2i(8, 4),
	])
	await _capture("forest_fire_cells.png")

	_prepare_surface_demo(WATER, [
		Vector2i(5, 3), Vector2i(6, 3), Vector2i(7, 3),
		Vector2i(7, 4), Vector2i(8, 4),
	])
	await _capture("forest_water_cells.png")

	_prepare_surface_demo(ICE, [
		Vector2i(5, 8), Vector2i(6, 8), Vector2i(7, 8),
		Vector2i(7, 9), Vector2i(8, 9),
	])
	await _capture("forest_ice_cells.png")

	lab.reset_test()
	lab.set_capture_layers(false, false, false, 0, false, false)
	lab.set_surface(Vector2i(4, 4), FIRE)
	lab.apply_surface_effect(Vector2i(4, 4), WATER)
	lab.set_surface(Vector2i(5, 4), FIRE)
	lab.apply_surface_effect(Vector2i(5, 4), ICE)
	lab.set_surface(Vector2i(6, 4), WATER)
	lab.apply_surface_effect(Vector2i(6, 4), ICE)
	lab.set_surface(Vector2i(7, 4), ICE)
	lab.apply_surface_effect(Vector2i(7, 4), FIRE)
	await _capture("forest_surface_interactions.png")

	lab.reset_test()
	lab.set_unit_cells(Vector2i(4, 9), Vector2i(8, 2))
	lab.set_capture_layers(false, true, true, 1, true, false)
	await _capture("forest_pathfinding.png")

	lab.reset_test()
	lab.set_unit_cells(Vector2i(3, 5), Vector2i(5, 7))
	lab.set_capture_layers(false, true, true, 0, false, false)
	lab.set_unit_names_visible(false)
	await _capture("forest_units_and_walls.png")

	lab.reset_test()
	lab.set_unit_cells(Vector2i(4, 9), Vector2i(8, 2))
	lab.set_unit_names_visible(true)
	lab.set_surface(Vector2i(5, 3), FIRE)
	lab.set_surface(Vector2i(6, 3), FIRE)
	lab.set_surface(Vector2i(7, 8), WATER)
	lab.set_surface(Vector2i(8, 8), WATER)
	lab.set_surface(Vector2i(5, 9), ICE)
	lab.set_surface(Vector2i(7, 9), ICE)
	lab.set_capture_layers(false, true, true, 1, true, true)
	await _capture("forest_final_overview.png")

	_validate_outputs()
	get_tree().quit(1 if failures > 0 else 0)


func _prepare_surface_demo(surface: int, cells: Array[Vector2i]) -> void:
	lab.reset_test()
	lab.set_capture_layers(false, false, false, 0, false, false)
	for cell in cells:
		lab.set_surface(cell, surface)


func _capture(file_name: String) -> void:
	await _settle(4)
	var viewport_texture := get_viewport().get_texture()
	if viewport_texture == null:
		push_error("Texture de viewport indisponible : %s" % file_name)
		failures += 1
		return
	var image := viewport_texture.get_image()
	if image == null or image.is_empty():
		push_error("Capture vide : %s" % file_name)
		failures += 1
		return
	var output := OUTPUT_DIR.path_join(file_name)
	var error := image.save_png(ProjectSettings.globalize_path(output))
	if error != OK:
		push_error("Echec capture %s : %s" % [output, error_string(error)])
		failures += 1
		return
	print("CAPTURED %s %dx%d" % [output, image.get_width(), image.get_height()])


func _validate_outputs() -> void:
	for file_name in [
		"forest_original.png", "forest_dynamic_neutral_grid.png",
		"forest_full_grid_alignment.png", "forest_with_static_walls.png",
		"forest_fire_cells.png", "forest_water_cells.png", "forest_ice_cells.png",
		"forest_surface_interactions.png", "forest_pathfinding.png",
		"forest_units_and_walls.png", "forest_final_overview.png",
	]:
		if not FileAccess.file_exists(OUTPUT_DIR.path_join(file_name)):
			push_error("Capture manquante : %s" % file_name)
			failures += 1


func _settle(frame_count: int) -> void:
	for _frame in range(frame_count):
		await get_tree().process_frame
