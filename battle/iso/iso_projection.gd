class_name IsoProjection
extends RefCounted

## Projection isometrique en losange 2:1.
## grid_origin designe le centre de la cellule (0, 0).

const DEFAULT_TILE_WIDTH := 128.0
const DEFAULT_TILE_HEIGHT := 64.0
const PICK_EPSILON := 0.0001

var tile_width: float = DEFAULT_TILE_WIDTH
var tile_height: float = DEFAULT_TILE_HEIGHT
var grid_origin: Vector2 = Vector2.ZERO


func _init(
		p_tile_width: float = DEFAULT_TILE_WIDTH,
		p_tile_height: float = DEFAULT_TILE_HEIGHT,
		p_grid_origin: Vector2 = Vector2.ZERO
	) -> void:
	tile_width = p_tile_width
	tile_height = p_tile_height
	grid_origin = p_grid_origin


func grid_to_world(grid_pos: Vector2i) -> Vector2:
	var half_width := tile_width * 0.5
	var half_height := tile_height * 0.5
	return grid_origin + Vector2(
		float(grid_pos.x - grid_pos.y) * half_width,
		float(grid_pos.x + grid_pos.y) * half_height
	)


func world_to_grid(world_pos: Vector2) -> Vector2i:
	var local_pos := world_pos - grid_origin
	var raw_grid := Vector2(
		local_pos.x / tile_width + local_pos.y / tile_height,
		local_pos.y / tile_height - local_pos.x / tile_width
	)
	var preferred := Vector2i(
		floori(raw_grid.x + 0.5),
		floori(raw_grid.y + 0.5)
	)

	# La projection inverse suffit au centre des cases. Pres des aretes, on
	# controle les losanges voisins afin d'eviter les trous dus aux arrondis de
	# flottants. Sur une frontiere partagee, la cellule arrondie est privilegiee.
	var base := Vector2i(floori(raw_grid.x), floori(raw_grid.y))
	var best := preferred
	var best_score: float = INF
	var found := false
	var half_width := tile_width * 0.5
	var half_height := tile_height * 0.5

	for x in range(base.x - 1, base.x + 3):
		for y in range(base.y - 1, base.y + 3):
			var candidate := Vector2i(x, y)
			var delta: Vector2 = world_pos - grid_to_world(candidate)
			var diamond_score: float = (
				absf(delta.x) / half_width + absf(delta.y) / half_height
			)
			if diamond_score > 1.0 + PICK_EPSILON:
				continue

			var should_replace: bool = (
				not found or diamond_score < best_score - PICK_EPSILON
			)
			if not should_replace \
					and abs(diamond_score - best_score) <= PICK_EPSILON \
					and candidate == preferred:
				should_replace = true
			if should_replace:
				best = candidate
				best_score = diamond_score
				found = true

	return best if found else preferred


func get_cell_polygon(grid_pos: Vector2i) -> PackedVector2Array:
	var center := grid_to_world(grid_pos)
	var half_width := tile_width * 0.5
	var half_height := tile_height * 0.5
	return PackedVector2Array([
		center + Vector2(0.0, -half_height),
		center + Vector2(half_width, 0.0),
		center + Vector2(0.0, half_height),
		center + Vector2(-half_width, 0.0),
	])


func get_map_bounds(cols: int, rows: int) -> Rect2:
	if cols <= 0 or rows <= 0:
		return Rect2(grid_origin, Vector2.ZERO)

	var half_width := tile_width * 0.5
	var half_height := tile_height * 0.5
	var top_left := grid_origin + Vector2(-float(rows) * half_width, -half_height)
	var bounds_size := Vector2(
		float(cols + rows) * half_width,
		float(cols + rows) * half_height
	)
	return Rect2(top_left, bounds_size)
