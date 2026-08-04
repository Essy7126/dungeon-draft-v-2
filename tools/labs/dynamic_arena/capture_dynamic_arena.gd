extends SceneTree

## Genere les captures d'acceptation du laboratoire sans modifier la scene de
## production ni la scene principale du projet.

const OUTPUT_DIR := "res://artifacts/labs/dynamic_arena"
const LAB_SCENE_PATH := "res://tools/labs/dynamic_arena/DynamicArenaLab.tscn"
const VIEWPORT_SIZE := Vector2i(1200, 896)
const SURFACE_STONE := 0
const SURFACE_WATER := 1
const SURFACE_ICE := 2
const SURFACE_LAVA := 3

var lab = null
var failures := 0


func _initialize() -> void:
	call_deferred("_capture_all")


func _capture_all() -> void:
	root.size = VIEWPORT_SIZE
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	# Chargement differe : les singletons du projet sont alors enregistres avant
	# que GridData ne resolve le type Unit utilise par le jeu.
	await process_frame
	var lab_scene := load(LAB_SCENE_PATH) as PackedScene
	if lab_scene == null:
		push_error("Scene du lab introuvable : %s" % LAB_SCENE_PATH)
		quit(1)
		return
	lab = lab_scene.instantiate()
	root.add_child(lab)
	await _settle(8)

	lab.reset_lab()
	lab.set_grid_debug_visible(false)
	lab.set_path_visible(false)
	lab.set_hovered_cell(Vector2i(3, 3))
	await _capture("stone_arena.png")

	_apply_mixed_surfaces()
	lab.set_path_visible(true)
	lab.set_destination(Vector2i(6, 4))
	lab.set_hovered_cell(Vector2i(4, 4))
	await _capture("mixed_surfaces.png")

	lab.reset_lab()
	lab.set_grid_debug_visible(false)
	lab.set_start_cell(Vector2i(0, 3))
	lab.set_destination(Vector2i(7, 3))
	for y in range(8):
		lab.set_cell_surface(Vector2i(4, y), SURFACE_LAVA)
	lab.set_hovered_cell(Vector2i(4, 3))
	await _capture("path_blocked_by_lava.png")

	lab.set_cell_surface(Vector2i(4, 3), SURFACE_STONE)
	lab.set_hovered_cell(Vector2i(4, 3))
	await _capture("path_restored.png")

	lab.reset_lab()
	lab.set_grid_debug_visible(false)
	lab.set_start_cell(Vector2i(0, 3))
	lab.set_destination(Vector2i(7, 3))
	for cell in [Vector2i(3, 2), Vector2i(3, 3), Vector2i(3, 4), Vector2i(4, 4)]:
		lab.toggle_wall_at(cell)
	lab.set_hovered_cell(Vector2i(3, 3))
	await _capture("dynamic_wall.png")

	lab.reset_lab()
	_apply_mixed_surfaces()
	lab.set_grid_debug_visible(true)
	lab.set_path_visible(false)
	lab.set_hovered_cell(Vector2i(3, 3))
	await _capture("grid_debug.png")

	lab.reset_lab()
	_apply_mixed_surfaces()
	lab.set_grid_debug_visible(true)
	lab.set_path_visible(true)
	lab.set_start_cell(Vector2i(0, 4))
	lab.set_destination(Vector2i(7, 2))
	for cell in [Vector2i(4, 1), Vector2i(4, 2), Vector2i(5, 2)]:
		lab.toggle_wall_at(cell)
	lab.set_hovered_cell(Vector2i(5, 2))
	await _capture("lab_overview.png")

	quit(1 if failures > 0 else 0)


func _apply_mixed_surfaces() -> void:
	for cell in [Vector2i(1, 1), Vector2i(2, 1), Vector2i(2, 2), Vector2i(6, 5)]:
		lab.set_cell_surface(cell, SURFACE_WATER)
	for cell in [Vector2i(2, 5), Vector2i(3, 5), Vector2i(3, 6), Vector2i(6, 1)]:
		lab.set_cell_surface(cell, SURFACE_ICE)
	for cell in [Vector2i(3, 2), Vector2i(4, 2), Vector2i(4, 3), Vector2i(5, 5)]:
		lab.set_cell_surface(cell, SURFACE_LAVA)


func _capture(file_name: String) -> void:
	await _settle(5)
	var viewport_texture := root.get_texture()
	if viewport_texture == null:
		push_error("Le pilote de rendu ne fournit pas de texture de viewport.")
		failures += 1
		return
	var image := viewport_texture.get_image()
	if image == null or image.is_empty():
		push_error("La capture de viewport est vide.")
		failures += 1
		return
	var output := OUTPUT_DIR.path_join(file_name)
	var error := image.save_png(ProjectSettings.globalize_path(output))
	if error != OK:
		push_error("Capture impossible %s : %s" % [output, error_string(error)])
		failures += 1
		return
	print("CAPTURED %s %dx%d" % [output, image.get_width(), image.get_height()])


func _settle(frame_count: int) -> void:
	for _frame in range(frame_count):
		await process_frame
