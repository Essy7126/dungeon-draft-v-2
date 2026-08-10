@tool
class_name ArenaArtProjectionRenderer
extends RefCounted

const RENDERER_VERSION := "affine_raster_v1"

static var _geometry_cache := {}


static func render_pass(
		arena: ArenaDefinition,
		pass_id: StringName,
		contract: ArenaArtResolutionContract = null
	) -> Image:
	if arena == null:
		return Image.new()
	var resolved := contract if contract != null \
		else ArenaArtResolutionContract.from_arena(arena)
	var size := resolved.reference_export_size
	var transparent := pass_id in [
		&"playable_mask", &"void_mask", &"wall_mask",
		&"foreground_guide", &"alignment_markers",
	]
	var image := _background(arena, size) if not transparent \
		else Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	if transparent:
		image.fill(Color.TRANSPARENT)
	match pass_id:
		&"reference_clean":
			pass
		&"reference_grid":
			_draw_grid(image, arena, Color(0.35, 0.82, 1.0, 0.92))
		&"reference_coordinates":
			_draw_grid(image, arena, Color(0.32, 0.74, 0.96, 0.72))
			_draw_coordinates(image, arena)
		&"reference_gameplay", &"map_game_preview":
			_draw_gameplay(image, arena)
		&"reference_walls":
			image.fill(Color.TRANSPARENT)
			_draw_walls(image, arena, Color(1.0, 0.38, 0.16, 0.95))
		&"playable_mask":
			_draw_cell_mask(image, arena, &"playable")
		&"void_mask":
			_draw_cell_mask(image, arena, &"void")
		&"wall_mask":
			_draw_walls(image, arena, Color.WHITE)
		&"foreground_guide":
			_draw_foreground(image, arena)
		&"depth_guide":
			_draw_depth(image, arena)
		&"alignment_markers":
			_draw_alignment_markers(image, arena)
		_:
			_draw_gameplay(image, arena)
	return image


static func cell_center(arena: ArenaDefinition, cell: Vector2i) -> Vector2:
	return _project_point(
		arena,
		GridTransformService.cell_to_position(
			cell, arena.grid_origin, arena.axis_x, arena.axis_y
		)
	)


static func cell_polygon(arena: ArenaDefinition, cell: Vector2i) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in GridTransformService.cell_polygon(
		cell, arena.grid_origin, arena.axis_x, arena.axis_y
	):
		result.append(_project_point(arena, point))
	return result


static func wall_polygon(
		arena: ArenaDefinition,
		obstacle: ArenaObstacleDefinition
	) -> PackedVector2Array:
	var polygon := cell_polygon(arena, obstacle.cell)
	if polygon.size() != 4:
		return polygon
	var first := 0
	if obstacle.orientation == Vector2i.RIGHT:
		first = 1
	elif obstacle.orientation == Vector2i.DOWN:
		first = 2
	elif obstacle.orientation == Vector2i.LEFT:
		first = 3
	var second := (first + 1) % 4
	var center := cell_center(arena, obstacle.cell)
	var inset_a := polygon[first].lerp(center, 0.22)
	var inset_b := polygon[second].lerp(center, 0.22)
	return PackedVector2Array([
		polygon[first], polygon[second], inset_b, inset_a,
	])


static func geometry_report(arena: ArenaDefinition) -> Dictionary:
	if arena == null:
		return {"cells": {}, "walls": {}, "renderer": RENDERER_VERSION, "cache_hit": false}
	var cache_key := ArenaSnapshotService.arena_fingerprint(arena)
	if _geometry_cache.has(cache_key):
		var cached := (_geometry_cache[cache_key] as Dictionary).duplicate(true)
		cached["cache_hit"] = true
		return cached
	var cells := {}
	for definition in arena.cells:
		if definition == null or not definition.defined:
			continue
		var key := "%d,%d" % [definition.coordinate.x, definition.coordinate.y]
		cells[key] = {
			"center": _vector(cell_center(arena, definition.coordinate)),
			"corners": Array(cell_polygon(arena, definition.coordinate)).map(_vector),
		}
	var walls := {}
	for obstacle in arena.obstacles:
		if obstacle == null or obstacle.wall_id == &"":
			continue
		walls[str(obstacle.obstacle_id)] = {
			"cell": [obstacle.cell.x, obstacle.cell.y],
			"orientation": [obstacle.orientation.x, obstacle.orientation.y],
			"polygon": Array(wall_polygon(arena, obstacle)).map(_vector),
		}
	var result := {
		"cells": cells, "walls": walls, "renderer": RENDERER_VERSION,
		"cache_hit": false,
	}
	_geometry_cache[cache_key] = result.duplicate(true)
	return result


static func clear_geometry_cache() -> void:
	_geometry_cache.clear()


static func geometry_cache_size() -> int:
	return _geometry_cache.size()


static func _background(arena: ArenaDefinition, size: Vector2i) -> Image:
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(Color("101722"))
	if arena.background_path.is_empty() or not ResourceLoader.exists(arena.background_path):
		return image
	var texture := load(arena.background_path) as Texture2D
	var source := texture.get_image() if texture != null else null
	if source == null or source.is_empty() or source.get_size() != size:
		return image
	source = source.duplicate()
	source.convert(Image.FORMAT_RGBA8)
	return source


static func _draw_grid(image: Image, arena: ArenaDefinition, color: Color) -> void:
	for y in range(arena.grid_size.y):
		for x in range(arena.grid_size.x):
			var cell := Vector2i(x, y)
			var definition := arena.get_cell_definition(cell)
			if definition == null or not definition.defined:
				continue
			_draw_polygon_outline(image, cell_polygon(arena, cell), color)


static func _draw_coordinates(image: Image, arena: ArenaDefinition) -> void:
	for definition in arena.cells:
		if definition == null or not definition.defined:
			continue
		var center := cell_center(arena, definition.coordinate)
		_draw_text_3x5(
			image, "%d,%d" % [definition.coordinate.x, definition.coordinate.y],
			Vector2i(roundi(center.x) - 7, roundi(center.y) - 2),
			Color(1.0, 1.0, 1.0, 0.95)
		)
	_draw_cross(image, _project_point(arena, arena.grid_origin), Color("ffcf5a"), 7)


static func _draw_gameplay(image: Image, arena: ArenaDefinition) -> void:
	for definition in arena.cells:
		if definition == null or not definition.defined:
			continue
		var color := ArenaTerrainRegistry.color_for(definition.terrain_id)
		color.a = 0.32 if definition.playable and not definition.border else 0.58
		_fill_polygon(image, cell_polygon(arena, definition.coordinate), color)
	_draw_grid(image, arena, Color(0.45, 0.86, 1.0, 0.78))
	_draw_walls(image, arena, Color(1.0, 0.38, 0.16, 0.95))
	for spawn in arena.spawns:
		if spawn != null:
			_draw_cross(
				image, cell_center(arena, spawn.cell),
				Color("78e4ff") if spawn.is_hero() else Color("ff6b78"), 6
			)
	for objective in arena.objectives:
		if objective != null:
			_draw_cross(image, cell_center(arena, objective.cell), Color("ffd166"), 8)


static func _draw_cell_mask(
		image: Image,
		arena: ArenaDefinition,
		kind: StringName
	) -> void:
	for y in range(arena.grid_size.y):
		for x in range(arena.grid_size.x):
			var cell := Vector2i(x, y)
			var definition := arena.get_cell_definition(cell)
			var matches := false
			if kind == &"playable":
				matches = definition != null and definition.defined \
					and definition.playable and not definition.border
			else:
				matches = definition == null or not definition.defined \
					or definition.border or not definition.playable \
					or definition.cell_type == GridData.CellType.HOLE
			if matches:
				_fill_polygon(image, cell_polygon(arena, cell), Color.WHITE)


static func _draw_walls(image: Image, arena: ArenaDefinition, color: Color) -> void:
	for obstacle in arena.obstacles:
		if obstacle == null or obstacle.wall_id == &"":
			continue
		_fill_polygon(image, wall_polygon(arena, obstacle), color)


static func _draw_foreground(image: Image, arena: ArenaDefinition) -> void:
	if arena.foreground_occluder_polygon.size() < 3:
		return
	var polygon := PackedVector2Array()
	for point in arena.foreground_occluder_polygon:
		polygon.append(_project_point(arena, point))
	_fill_polygon(image, polygon, Color.WHITE)


static func _draw_depth(image: Image, arena: ArenaDefinition) -> void:
	var minimum_y := INF
	var maximum_y := -INF
	for definition in arena.cells:
		if definition != null and definition.defined:
			var y := cell_center(arena, definition.coordinate).y
			minimum_y = minf(minimum_y, y)
			maximum_y = maxf(maximum_y, y)
	var span := maxf(maximum_y - minimum_y, 1.0)
	for definition in arena.cells:
		if definition == null or not definition.defined:
			continue
		var ratio := (cell_center(arena, definition.coordinate).y - minimum_y) / span
		_fill_polygon(
			image, cell_polygon(arena, definition.coordinate),
			Color(ratio, ratio, ratio, 0.72)
		)
	_draw_grid(image, arena, Color(0.2, 0.8, 1.0, 0.75))


static func _draw_alignment_markers(image: Image, arena: ArenaDefinition) -> void:
	if not arena.calibration_pixels.is_empty():
		for point in arena.calibration_pixels:
			_draw_cross(image, _project_point(arena, point), Color("ffcf5a"), 9)
		return
	for cell in [
		Vector2i.ZERO,
		Vector2i(maxi(0, arena.grid_size.x - 1), 0),
		Vector2i(0, maxi(0, arena.grid_size.y - 1)),
	]:
		_draw_cross(image, cell_center(arena, cell), Color("ffcf5a"), 9)


static func _project_point(arena: ArenaDefinition, point: Vector2) -> Vector2:
	return arena.image_offset + point * arena.image_scale


static func _fill_polygon(image: Image, polygon: PackedVector2Array, color: Color) -> void:
	if polygon.size() < 3:
		return
	var minimum := polygon[0]
	var maximum := polygon[0]
	for point in polygon:
		minimum = minimum.min(point)
		maximum = maximum.max(point)
	var min_x := clampi(floori(minimum.x), 0, image.get_width() - 1)
	var max_x := clampi(ceili(maximum.x), 0, image.get_width() - 1)
	var min_y := clampi(floori(minimum.y), 0, image.get_height() - 1)
	var max_y := clampi(ceili(maximum.y), 0, image.get_height() - 1)
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), polygon):
				_blend_pixel(image, x, y, color)


static func _draw_polygon_outline(
		image: Image,
		polygon: PackedVector2Array,
		color: Color
	) -> void:
	for index in range(polygon.size()):
		_draw_line(image, polygon[index], polygon[(index + 1) % polygon.size()], color)


static func _draw_line(image: Image, start: Vector2, end: Vector2, color: Color) -> void:
	var steps := maxi(1, ceili(start.distance_to(end) * 1.5))
	for index in range(steps + 1):
		var point := start.lerp(end, float(index) / float(steps))
		var x := roundi(point.x)
		var y := roundi(point.y)
		if x >= 0 and y >= 0 and x < image.get_width() and y < image.get_height():
			_blend_pixel(image, x, y, color)


static func _draw_cross(
		image: Image,
		center: Vector2,
		color: Color,
		radius: int
	) -> void:
	_draw_line(image, center - Vector2(radius, 0), center + Vector2(radius, 0), color)
	_draw_line(image, center - Vector2(0, radius), center + Vector2(0, radius), color)


static func _draw_text_3x5(
		image: Image,
		text: String,
		origin: Vector2i,
		color: Color
	) -> void:
	var glyphs := {
		"0": ["111", "101", "101", "101", "111"],
		"1": ["010", "110", "010", "010", "111"],
		"2": ["111", "001", "111", "100", "111"],
		"3": ["111", "001", "111", "001", "111"],
		"4": ["101", "101", "111", "001", "001"],
		"5": ["111", "100", "111", "001", "111"],
		"6": ["111", "100", "111", "101", "111"],
		"7": ["111", "001", "010", "010", "010"],
		"8": ["111", "101", "111", "101", "111"],
		"9": ["111", "101", "111", "001", "111"],
		",": ["000", "000", "000", "010", "100"],
		"-": ["000", "000", "111", "000", "000"],
	}
	var cursor := origin.x
	for character in text:
		var rows: Array = glyphs.get(character, [])
		for y in range(rows.size()):
			for x in range(3):
				if (rows[y] as String)[x] == "1":
					var px := cursor + x
					var py := origin.y + y
					if px >= 0 and py >= 0 and px < image.get_width() and py < image.get_height():
						_blend_pixel(image, px, py, color)
		cursor += 4


static func _blend_pixel(image: Image, x: int, y: int, color: Color) -> void:
	image.set_pixel(x, y, image.get_pixel(x, y).blend(color))


static func _vector(value: Vector2) -> Array[float]:
	return [value.x, value.y]
