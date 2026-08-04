extends SceneTree

## Genere les seize captures d'acceptation des murs sans charger la run ni une
## salle de production.

const OUTPUT_DIR := "res://artifacts/labs/dynamic_arena/walls_final"
const LAB_SCENE_PATH := "res://tools/labs/dynamic_arena/DynamicArenaLab.tscn"
const ASSET_BOARD := OUTPUT_DIR + "/wall_assets_normalized.png"
const VIEWPORT_SIZE := Vector2i(1200, 896)
const STONE := 0
const WATER := 1
const ICE_SURFACE := 2
const LAVA := 3
const BASE_WALL := 0
const FIRE_WALL := 1
const ICE_WALL := 2

var lab: DynamicArenaLab = null
var failures := 0


func _initialize() -> void:
	call_deferred("_capture_all")


func _capture_all() -> void:
	root.size = VIEWPORT_SIZE
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	if not FileAccess.file_exists(ASSET_BOARD):
		push_error("Planche de normalisation absente : %s" % ASSET_BOARD)
		quit(1)
		return
	await process_frame
	var lab_scene := load(LAB_SCENE_PATH) as PackedScene
	if lab_scene == null:
		push_error("Scene du lab introuvable : %s" % LAB_SCENE_PATH)
		quit(1)
		return
	lab = lab_scene.instantiate() as DynamicArenaLab
	root.add_child(lab)
	await _settle(8)

	await _capture_single_wall("wall_base.png", BASE_WALL)
	await _capture_single_wall("wall_fire.png", FIRE_WALL)
	await _capture_single_wall("wall_ice.png", ICE_WALL)

	lab.reset_lab()
	_prepare_clean_view()
	lab.place_wall(Vector2i(3, 3), BASE_WALL)
	lab.place_wall(Vector2i(4, 3), FIRE_WALL)
	lab.place_wall(Vector2i(5, 3), ICE_WALL)
	lab.set_hovered_cell(Vector2i(4, 3))
	await _capture("wall_cycle.png")

	lab.reset_lab()
	_prepare_clean_view()
	lab.place_wall(Vector2i(4, 4), BASE_WALL)
	lab.damage_wall(Vector2i(4, 4), 16, &"NONE")
	lab.set_hovered_cell(Vector2i(4, 4))
	await _capture("wall_hp_damage.png")

	lab.reset_lab()
	_prepare_clean_view()
	lab.place_wall(Vector2i(4, 4), BASE_WALL)
	lab.damage_wall(Vector2i(4, 4), 30, &"NONE")
	lab._play_interaction_vfx(Vector2i(4, 4), "DETRUIT", Color("ff6b72"))
	lab.set_hovered_cell(Vector2i(4, 4))
	await _capture("wall_destroyed.png", 1)

	lab.reset_lab()
	_prepare_clean_view()
	lab.place_wall(Vector2i(4, 4), FIRE_WALL)
	lab.set_cell_surface(Vector2i(4, 4), WATER)
	lab.set_hovered_cell(Vector2i(4, 4))
	await _capture("fire_water_interaction.png", 1)

	lab.reset_lab()
	_prepare_clean_view()
	lab.place_wall(Vector2i(4, 4), FIRE_WALL)
	lab.set_cell_surface(Vector2i(4, 4), ICE_SURFACE)
	lab.set_hovered_cell(Vector2i(4, 4))
	await _capture("fire_ice_interaction.png", 1)

	lab.reset_lab()
	_prepare_path_view()
	lab.set_start_cell(Vector2i(0, 3))
	lab.set_destination(Vector2i(7, 3))
	lab.set_hovered_cell(Vector2i(4, 3))
	await _capture("path_before_wall.png")

	for y in range(8):
		lab.place_wall(Vector2i(4, y), BASE_WALL)
	lab.set_hovered_cell(Vector2i(4, 3))
	await _capture("path_blocked.png")

	for y in range(8):
		lab.remove_wall(Vector2i(4, y))
	lab.set_hovered_cell(Vector2i(4, 3))
	await _capture("path_restored.png")

	lab.reset_lab()
	_prepare_path_view()
	lab.set_start_cell(Vector2i(1, 3))
	lab.set_destination(Vector2i(6, 3))
	lab.place_wall(Vector2i(3, 3), BASE_WALL)
	lab.set_hovered_cell(Vector2i(3, 3))
	await _capture("los_blocked.png")

	lab.reset_lab()
	_prepare_clean_view()
	lab.place_wall(Vector2i(4, 4), BASE_WALL)
	lab.set_start_cell(Vector2i(3, 3))
	lab.set_hovered_cell(Vector2i(4, 4))
	await _capture("unit_behind_wall.png")

	lab.set_start_cell(Vector2i(5, 5))
	await _capture("unit_in_front_wall.png")

	lab.reset_lab()
	lab.set_grid_debug_visible(true)
	lab.set_path_visible(true)
	lab.set_start_cell(Vector2i(0, 4))
	lab.set_destination(Vector2i(7, 2))
	for cell in [Vector2i(1, 1), Vector2i(2, 1), Vector2i(6, 5)]:
		lab.set_cell_surface(cell, WATER)
	for cell in [Vector2i(2, 5), Vector2i(3, 5), Vector2i(6, 1)]:
		lab.set_cell_surface(cell, ICE_SURFACE)
	for cell in [Vector2i(5, 5), Vector2i(5, 6)]:
		lab.set_cell_surface(cell, LAVA)
	lab.place_wall(Vector2i(3, 2), BASE_WALL)
	lab.place_wall(Vector2i(4, 3), FIRE_WALL)
	lab.place_wall(Vector2i(5, 2), ICE_WALL)
	lab.damage_wall(Vector2i(3, 2), 16, &"NONE")
	lab.set_hovered_cell(Vector2i(4, 3))
	await _capture("final_dynamic_arena.png")

	_validate_capture_set()
	quit(1 if failures > 0 else 0)


func _capture_single_wall(file_name: String, wall_variant: int) -> void:
	lab.reset_lab()
	_prepare_clean_view()
	lab.place_wall(Vector2i(4, 4), wall_variant)
	lab.set_hovered_cell(Vector2i(4, 4))
	await _capture(file_name)


func _prepare_clean_view() -> void:
	lab.set_grid_debug_visible(false)
	lab.set_path_visible(false)


func _prepare_path_view() -> void:
	lab.set_grid_debug_visible(false)
	lab.set_path_visible(true)


func _capture(file_name: String, settle_frames := 5) -> void:
	await _settle(settle_frames)
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


func _validate_capture_set() -> void:
	var expected := [
		"wall_assets_normalized.png", "wall_base.png", "wall_fire.png", "wall_ice.png",
		"wall_cycle.png", "wall_hp_damage.png", "wall_destroyed.png",
		"fire_water_interaction.png", "fire_ice_interaction.png",
		"path_before_wall.png", "path_blocked.png", "path_restored.png",
		"los_blocked.png", "unit_behind_wall.png", "unit_in_front_wall.png",
		"final_dynamic_arena.png",
	]
	for file_name in expected:
		if not FileAccess.file_exists(OUTPUT_DIR.path_join(file_name)):
			push_error("Capture finale absente : %s" % file_name)
			failures += 1


func _settle(frame_count: int) -> void:
	for _frame in range(frame_count):
		await process_frame
