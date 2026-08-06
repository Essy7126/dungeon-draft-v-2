@tool
class_name PaintedMapVisualData
extends Resource

## Calibration visuelle d'une peinture. Les positions sont exprimees dans le
## repere pixel natif de l'image ; la camera applique ensuite une echelle
## uniforme. Aucune information de gameplay n'est deduite de la texture.

@export var map_id: StringName = &"painted_map"
@export var debug_name := "Painted map"
@export var background_texture: Texture2D = null
@export var foreground_texture: Texture2D = null
@export_file("*.png", "*.jpg", "*.jpeg", "*.webp") var background_texture_path := ""
@export_file("*.png", "*.jpg", "*.jpeg", "*.webp") var foreground_texture_path := ""
@export_file("*.png") var occlusion_mask_path := ""
@export var source_image_size := Vector2i.ZERO
@export var logical_grid_size := Vector2i(14, 14)

@export_group("Affine cellule vers image")
@export var grid_origin := Vector2.ZERO
@export var axis_x := Vector2(34.4, 17.066667)
@export var axis_y := Vector2(-34.4, 17.066667)
@export var image_offset := Vector2.ZERO
@export var image_scale := Vector2.ONE

@export_group("Camera")
@export var camera_offset := Vector2.ZERO
@export_range(0.5, 2.0, 0.001) var camera_zoom := 1.0
@export var crop_rect := Rect2()
@export var presentation_profile: BattlePresentationProfile = null

@export_group("Foreground")
@export var foreground_offset := Vector2.ZERO
@export var foreground_scale := Vector2.ONE
@export var foreground_occluder_polygon := PackedVector2Array()
@export var foreground_occluder_sort_y := 0.0
@export var foreground_full_hide_rect := Rect2()

@export_group("Ancres mesurees")
@export var calibration_cells: Array[Vector2i] = []
@export var calibration_pixels: Array[Vector2] = []


func cell_to_image(cell: Vector2i) -> Vector2:
	return GridTransformService.cell_to_position(cell, grid_origin, axis_x, axis_y)


func image_native_to_display(position: Vector2) -> Vector2:
	return image_offset + position * image_scale


func display_to_image_native(position: Vector2) -> Vector2:
	if absf(image_scale.x) <= 0.000001 or absf(image_scale.y) <= 0.000001:
		return Vector2(INF, INF)
	return (position - image_offset) / image_scale


func cell_to_display(cell: Vector2i) -> Vector2:
	return image_native_to_display(cell_to_image(cell))


func display_to_cell(display_position: Vector2) -> Vector2i:
	return image_to_cell(display_to_image_native(display_position))


func cell_polygon_display(cell: Vector2i) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in cell_polygon(cell):
		result.append(image_native_to_display(point))
	return result


func load_background_texture() -> Texture2D:
	if background_texture != null:
		return background_texture
	if background_texture_path.is_empty():
		return null
	return load(background_texture_path) as Texture2D


func load_foreground_texture() -> Texture2D:
	if foreground_texture != null:
		return foreground_texture
	if foreground_texture_path.is_empty():
		return null
	return load(foreground_texture_path) as Texture2D


## Reutilise directement les pixels du background dans un Polygon2D Y-sorte.
## L'occluder n'est donc ni une approximation peinte, ni une seconde texture :
## les unites derriere la ruine sont masquees, celles devant restent visibles.
func create_foreground_occluder(background: Texture2D) -> Polygon2D:
	if background == null or foreground_occluder_polygon.size() < 3:
		return null
	var occluder := Polygon2D.new()
	occluder.name = "ForegroundTowerOccluder"
	occluder.texture = background
	occluder.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	occluder.position = image_native_to_display(
		Vector2(0.0, foreground_occluder_sort_y)
	)
	var local_polygon := PackedVector2Array()
	for point in foreground_occluder_polygon:
		local_polygon.append(image_native_to_display(point) - occluder.position)
	occluder.polygon = local_polygon
	occluder.color = Color.WHITE
	# Les UV restent dans le repere pixel natif de l'image. Le polygone peut etre
	# plus large que la silhouette : les pixels recopies sont identiques au fond,
	# ce qui masque integralement un modele derriere sans bord artificiel.
	occluder.uv = foreground_occluder_polygon
	occluder.add_to_group("painted_foreground_occluders")
	return occluder


func is_position_fully_occluded(image_position: Vector2) -> bool:
	return foreground_full_hide_rect.has_area() \
		and foreground_full_hide_rect.has_point(display_to_image_native(image_position))


func image_to_cell(image_position: Vector2) -> Vector2i:
	var cell := GridTransformService.position_to_cell(
		image_position, grid_origin, axis_x, axis_y, logical_grid_size
	)
	return Vector2i(-1, -1) if cell == GridTransformService.INVALID_CELL else cell


func cell_polygon(cell: Vector2i) -> PackedVector2Array:
	return GridTransformService.cell_polygon(cell, grid_origin, axis_x, axis_y)


func image_rect() -> Rect2:
	if crop_rect.size.x > 0.0 and crop_rect.size.y > 0.0:
		return crop_rect
	return Rect2(image_offset, Vector2(source_image_size) * image_scale)


func grid_bounds() -> Rect2:
	if logical_grid_size.x <= 0 or logical_grid_size.y <= 0:
		return Rect2(grid_origin, Vector2.ZERO)
	var first := cell_polygon(Vector2i.ZERO)[0]
	var minimum := first
	var maximum := first
	for y in range(logical_grid_size.y):
		for x in range(logical_grid_size.x):
			for point in cell_polygon(Vector2i(x, y)):
				minimum = minimum.min(point)
				maximum = maximum.max(point)
	return Rect2(minimum, maximum - minimum)


func grid_bounds_display() -> Rect2:
	var native_bounds := grid_bounds()
	var first := image_native_to_display(native_bounds.position)
	var second := image_native_to_display(native_bounds.end)
	return Rect2(first.min(second), (second - first).abs())


func anchor_errors() -> PackedFloat32Array:
	var errors := PackedFloat32Array()
	for index in range(mini(calibration_cells.size(), calibration_pixels.size())):
		errors.append(cell_to_image(calibration_cells[index]).distance_to(
			calibration_pixels[index]
		))
	return errors


func calibration_rms() -> float:
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
	if background_texture == null and background_texture_path.is_empty():
		errors.append("Une texture ou un chemin de background est requis.")
	if not background_texture_path.is_empty() \
			and not ResourceLoader.exists(background_texture_path):
		errors.append("Le chemin du background n'existe pas.")
	if source_image_size.x <= 0 or source_image_size.y <= 0:
		errors.append("source_image_size doit etre renseigne.")
	if background_texture != null \
			and background_texture.get_size() != Vector2(source_image_size):
		errors.append("La resolution declaree ne correspond pas a la texture.")
	if logical_grid_size.x <= 0 or logical_grid_size.y <= 0:
		errors.append("logical_grid_size doit etre strictement positif.")
	if not GridTransformService.is_vector_finite(image_offset) \
			or not GridTransformService.is_vector_finite(image_scale) \
			or absf(image_scale.x) <= 0.000001 or absf(image_scale.y) <= 0.000001:
		errors.append("Le placement de l'image doit etre fini et non nul.")
	if not GridTransformService.is_invertible(axis_x, axis_y):
		errors.append("Les axes de calibration ne doivent pas etre colineaires.")
	if not is_equal_approx(image_scale.x, image_scale.y):
		errors.append("Le background ne peut pas recevoir une echelle non uniforme.")
	if not is_equal_approx(foreground_scale.x, foreground_scale.y):
		errors.append("Le foreground ne peut pas recevoir une echelle non uniforme.")
	if not foreground_occluder_polygon.is_empty():
		if foreground_occluder_polygon.size() < 3:
			errors.append("L'occluder foreground doit contenir au moins trois points.")
		if foreground_occluder_sort_y <= 0.0 \
				or foreground_occluder_sort_y > float(source_image_size.y):
			errors.append("Le seuil Y-sort de l'occluder foreground est invalide.")
		for point in foreground_occluder_polygon:
			if point.x < 0.0 or point.y < 0.0 \
					or point.x > float(source_image_size.x) \
					or point.y > float(source_image_size.y):
				errors.append("Un point de l'occluder foreground sort de l'image.")
				break
		if foreground_full_hide_rect.has_area() \
				and not Rect2(Vector2.ZERO, Vector2(source_image_size)).encloses(
					foreground_full_hide_rect
				):
			errors.append("La zone de masquage integral sort de l'image.")
	if presentation_profile == null:
		errors.append("Un BattlePresentationProfile est requis.")
	else:
		errors.append_array(presentation_profile.validation_errors())
	if calibration_cells.size() != calibration_pixels.size():
		errors.append("Les cellules et pixels d'ancres doivent avoir la meme taille.")
	if calibration_cells.size() < 3:
		errors.append("Au moins trois ancres reparties sont requises.")
	for cell in calibration_cells:
		if cell.x < 0 or cell.y < 0 \
				or cell.x >= logical_grid_size.x or cell.y >= logical_grid_size.y:
			errors.append("Ancre hors grille : %s." % cell)
	return errors
