extends Node2D

const STYLE := preload("res://battle/painted/registered_terrain/terrain_style.gd")
var _palette: Dictionary = {}
var _annotation_manifest_override := ""

# ArenaDefinition is authoritative for FLOOR/VOID and gameplay. The manifest's
# pits are semantic annotations of confirmed VOID cells: a recess may open onto
# the perimeter, so connectivity to exterior alone cannot classify its artwork.
var arena: ArenaDefinition
var grid_view: Node2D
var floor_cells: Dictionary = {}
var pit_cells: Dictionary = {}
var exterior_cells: Dictionary = {}
var pit_components: Array = []
var pit_annotation_errors: Array[String] = []
var pit_annotation_path := ""
var pit_annotation_group_count := 0
var pit_boundary_edges: Array = []
var pit_wall_edges: Array = []
var perimeter_riser_edges: Array = []
const DIRECTIONS := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
const DROP := Vector2.ZERO # Ground is flush with the surrounding terrain.
const PIT_DEPTH := Vector2(0, 16)

func configure_palette(value: Dictionary) -> void:
	_palette = value.duplicate(true)
	queue_redraw()

func configure(value: ArenaDefinition, view: Node2D, annotation_manifest_path := "") -> void:
	_annotation_manifest_override = annotation_manifest_path
	arena = value
	grid_view = view
	floor_cells.clear()
	pit_cells.clear()
	exterior_cells.clear()
	pit_components.clear()
	pit_boundary_edges.clear()
	pit_wall_edges.clear()
	perimeter_riser_edges.clear()
	for cell in arena.cells:
		if cell != null and cell.defined and cell.cell_type != GridData.CellType.HOLE:
			floor_cells[cell.coordinate] = true
	pit_annotation_errors.clear()
	pit_annotation_group_count = 0
	_read_pit_semantic_annotations()
	for y in range(arena.grid_size.y):
		for x in range(arena.grid_size.x):
			var cell := Vector2i(x, y)
			if not floor_cells.has(cell) and not pit_cells.has(cell):
				exterior_cells[cell] = true
	var unseen := pit_cells.duplicate()
	while not unseen.is_empty():
		var start: Vector2i = unseen.keys()[0]
		var component: Array[Vector2i] = [start]
		unseen.erase(start)
		var index := 0
		while index < component.size():
			var cell := component[index]
			index += 1
			for direction: Vector2i in DIRECTIONS:
				var neighbor := cell + direction
				if unseen.has(neighbor):
					unseen.erase(neighbor)
					component.append(neighbor)
		pit_components.append(component)
	for cell: Vector2i in pit_cells:
		for edge_index in range(4):
			var neighbor: Vector2i = cell + DIRECTIONS[edge_index]
			if pit_cells.has(neighbor):
				continue
			var edge := {"cell": cell, "neighbor": neighbor, "edge_index": edge_index}
			pit_boundary_edges.append(edge)
			# Only far-facing walls are visible from above. Shared pit-cell edges
			# are never walls, so a two-cell cavity remains one open recess.
			if edge_index in [0, 3] and floor_cells.has(neighbor):
				pit_wall_edges.append(edge)
	for cell: Vector2i in floor_cells:
		for edge_index in [1, 2]:
			var neighbor: Vector2i = cell + DIRECTIONS[edge_index]
			if not floor_cells.has(neighbor) and not pit_cells.has(neighbor):
				perimeter_riser_edges.append({
					"cell": cell, "neighbor": neighbor, "edge_index": edge_index,
				})
	queue_redraw()

func _draw() -> void:
	if arena == null or grid_view == null:
		return
	for cell: Vector2i in pit_cells:
		draw_colored_polygon(_polygon(cell), _palette_color("floor", Color("263a35")))
	var depth := _native_vector_to_local(Vector2(0,float(_palette.get("depth_native_px",PIT_DEPTH.y))) * _tile_scale())
	for edge: Dictionary in pit_wall_edges:
		var points := _edge_points(edge)
		var wall := PackedVector2Array([points[0], points[1], points[1] + depth, points[0] + depth])
		var tint := _palette_color("back_wall",Color("65765a")) if int(edge.edge_index) == 0 else _palette_color("left_wall",Color("445b45"))
		# Clip the vertical wall to the pit union, including convex end corners.
		# Pieces have no outlines, so clipping introduces no artificial divider.
		for cell: Vector2i in pit_cells:
			for piece: PackedVector2Array in Geometry2D.intersect_polygons(wall, _polygon(cell)):
				draw_colored_polygon(piece, tint)
	for edge: Dictionary in perimeter_riser_edges:
		var points := _edge_points(edge)
		_riser(points[0], points[1], Color("929367") if int(edge.edge_index) == 1 else Color("a8a777"))

func _polygon(cell: Vector2i) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point: Vector2 in grid_view.get_cell_polygon(cell):
		result.append(to_local(grid_view.to_global(point)))
	return result

func _edge_points(edge: Dictionary) -> PackedVector2Array:
	var polygon := _polygon(edge.cell)
	var index := int(edge.edge_index)
	return PackedVector2Array([polygon[index], polygon[(index + 1) % 4]])

func _native_vector_to_local(value: Vector2) -> Vector2:
	var display_vector := value * arena.painted_map_visual_data.image_scale
	return to_local(grid_view.to_global(display_vector)) - to_local(grid_view.to_global(Vector2.ZERO))

func _riser(a: Vector2, b: Vector2, tint: Color) -> void:
	var drop := _native_vector_to_local(DROP * _tile_scale())
	if drop.is_zero_approx():
		return
	draw_colored_polygon(PackedVector2Array([a, b, b + drop, a + drop]), tint)
	draw_line(b + drop, a + drop, Color("536c52"), 1.3, true)
	draw_line(a, a + drop, Color(0.30, 0.37, 0.25, 0.55), 1.0, true)

func geometry_report() -> Dictionary:
	return {
		"authority": "ArenaDefinition.cells FLOOR/VOID; manifest.pits semantic annotation for recess artwork",
		"pit_semantic_annotation_path": pit_annotation_path,
		"pit_semantic_annotation_errors": pit_annotation_errors,
		"pit_semantic_annotation_groups": pit_annotation_group_count,
		"floor_cells": floor_cells.keys(), "pit_cells": pit_cells.keys(),
		"exterior_cells": exterior_cells.keys(), "pit_components": pit_components,
		"pit_boundary_edges": pit_boundary_edges, "pit_wall_edges": pit_wall_edges,
		"perimeter_riser_edges": perimeter_riser_edges,
		"rendered_perimeter_risers": 0 if DROP.is_zero_approx() else perimeter_riser_edges.size(),
		"peripheral_drop_native_px": DROP.y * _tile_scale(),
	}

func _tile_scale() -> float:
	var span := Vector2(absf(arena.axis_x.x) + absf(arena.axis_y.x), absf(arena.axis_x.y) + absf(arena.axis_y.y))
	return minf(span.x / 108.0, span.y / 54.0)

func _read_pit_semantic_annotations() -> void:
	pit_annotation_path = _annotation_manifest_override
	if pit_annotation_path.is_empty():
		var source_path := arena.registered_terrain_plan_path if not arena.registered_terrain_plan_path.is_empty() else arena.resource_path
		pit_annotation_path = source_path.get_base_dir().path_join("geometry_manifest.json") if not source_path.is_empty() else ""
	if not FileAccess.file_exists(pit_annotation_path):
		pit_annotation_errors.append("pit_semantic_annotation_missing")
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(pit_annotation_path))
	if not parsed is Dictionary or not parsed.get("pits", []) is Array:
		pit_annotation_errors.append("pit_semantic_annotation_invalid")
		return
	var runtime_grid := grid_view.get("grid") as GridData
	for annotation: Dictionary in parsed.get("pits", []):
		pit_annotation_group_count += 1
		for coordinate: Array in annotation.get("cells", []):
			if coordinate.size() != 2:
				pit_annotation_errors.append("pit_annotation_coordinate_invalid")
				continue
			var cell := Vector2i(int(coordinate[0]), int(coordinate[1]))
			if not arena.is_in_bounds(cell) or floor_cells.has(cell) \
					or runtime_grid == null or runtime_grid.get_type(cell) != GridData.CellType.HOLE:
				pit_annotation_errors.append("pit_annotation_is_not_canonical_void:%s" % cell)
				continue
			if pit_cells.has(cell):
				pit_annotation_errors.append("pit_annotation_duplicate:%s" % cell)
				continue
			pit_cells[cell] = true

func _palette_color(key: String, fallback: Color) -> Color:
	return STYLE.color(_palette.get(key, fallback), fallback)
