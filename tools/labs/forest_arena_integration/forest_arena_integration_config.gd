@tool
class_name ForestArenaIntegrationConfig
extends Resource

## Calibration propre a testv1. Les coordonnees restent celles du JSON ; cette
## ressource ne contient aucune regle de gameplay.

@export var background_texture: Texture2D = null
@export_file("*.json") var map_definition_path := ""
@export var source_image_size := Vector2i.ZERO
@export var reference_export_resolution := Vector2i(1920, 1080)

@export_group("Projection calibree")
@export var origin := Vector2.ZERO
@export var axis_x := Vector2(41.8, 20.74)
@export var axis_y := Vector2(-41.8, 20.74)
@export var global_scale := 1.0
@export var background_offset := Vector2.ZERO
@export var tile_scale := Vector2(0.3265625, 0.3240625)
@export_range(1, 8, 1) var border_thickness := 1
@export var optional_visual_mask: Texture2D = null

@export_group("Ancres mesurees")
@export var calibration_cells: Array[Vector2i] = []
@export var calibration_pixels: Array[Vector2] = []
@export var geometry_match := "GEOMETRY_MATCH_WITH_CALIBRATION"


func cell_to_screen(cell: Vector2i) -> Vector2:
	return background_offset + global_scale * (
		origin + float(cell.x) * axis_x + float(cell.y) * axis_y
	)


func screen_to_cell(screen_position: Vector2) -> Vector2i:
	if is_zero_approx(global_scale):
		return Vector2i(-1, -1)
	var local := (screen_position - background_offset) / global_scale - origin
	var determinant := axis_x.x * axis_y.y - axis_y.x * axis_x.y
	if is_zero_approx(determinant):
		return Vector2i(-1, -1)
	var raw_x := (local.x * axis_y.y - axis_y.x * local.y) / determinant
	var raw_y := (axis_x.x * local.y - local.x * axis_x.y) / determinant
	return Vector2i(roundi(raw_x), roundi(raw_y))


func cell_polygon(cell: Vector2i) -> PackedVector2Array:
	var center := cell_to_screen(cell)
	var calibrated_x := axis_x * global_scale
	var calibrated_y := axis_y * global_scale
	return PackedVector2Array([
		center - 0.5 * calibrated_x - 0.5 * calibrated_y,
		center + 0.5 * calibrated_x - 0.5 * calibrated_y,
		center + 0.5 * calibrated_x + 0.5 * calibrated_y,
		center - 0.5 * calibrated_x + 0.5 * calibrated_y,
	])


func anchor_errors() -> PackedFloat32Array:
	var errors := PackedFloat32Array()
	for index in range(mini(calibration_cells.size(), calibration_pixels.size())):
		errors.append(cell_to_screen(calibration_cells[index]).distance_to(
			calibration_pixels[index]
		))
	return errors


func calibration_mean_error() -> float:
	var errors := anchor_errors()
	if errors.is_empty():
		return INF
	var total := 0.0
	for error in errors:
		total += error
	return total / float(errors.size())


func calibration_rms_error() -> float:
	var errors := anchor_errors()
	if errors.is_empty():
		return INF
	var sum_squared := 0.0
	for error in errors:
		sum_squared += error * error
	return sqrt(sum_squared / float(errors.size()))


func calibration_max_error() -> float:
	var maximum := 0.0
	for error in anchor_errors():
		maximum = maxf(maximum, error)
	return maximum


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if background_texture == null:
		errors.append("La texture forest_background_v3 est requise.")
	elif background_texture.get_size() != Vector2(source_image_size):
		errors.append("La resolution declaree ne correspond pas a la texture.")
	if map_definition_path.is_empty() or not FileAccess.file_exists(map_definition_path):
		errors.append("Le JSON testv1 est introuvable.")
	if source_image_size.x <= 0 or source_image_size.y <= 0:
		errors.append("La resolution source doit etre positive.")
	if global_scale <= 0.0:
		errors.append("global_scale doit etre strictement positif.")
	if border_thickness < 1:
		errors.append("La couronne doit mesurer au moins une cellule.")
	var determinant := axis_x.x * axis_y.y - axis_y.x * axis_x.y
	if is_zero_approx(determinant):
		errors.append("Les axes de calibration ne doivent pas etre colineaires.")
	if calibration_cells.size() != calibration_pixels.size():
		errors.append("Les cellules et pixels de calibration doivent correspondre.")
	if calibration_cells.size() < 9:
		errors.append("Neuf ancres reparties sont requises pour testv1.")
	if geometry_match not in [
		"GEOMETRY_MATCH_CONFIRMED", "GEOMETRY_MATCH_WITH_CALIBRATION",
	]:
		errors.append("Le verdict de geometrie n'autorise pas l'integration.")
	return errors
