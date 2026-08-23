@tool
class_name IsoGridViewTest
extends Node2D

## COPIE DE TEST de iso_grid_view.gd.
## Difference : la grille de jeu (couche "Geometry") recopie automatiquement la
## transform ET la geometrie de tuile du "TerrainLayer" designe. Ainsi, chaque
## fois que tu modifies la perspective du terrain (skew, scale, position), la
## grille d'interaction (survol, clic, placement des persos) suit exactement.
##
## Usage : attacher ce script au noeud IsoGridView, puis renseigner
## "Terrain Layer Path" sur le TileMapLayer du terrain (ex: ../TerrainLayer).

signal cell_hovered(grid_pos: Vector2i)
signal cell_clicked(grid_pos: Vector2i)

const FOOTPRINT := Vector2i(64, 32)
const INVALID_CELL := Vector2i(-1, -1)

const TYPE_COLORS := {
	GridData.CellType.NORMAL: Color(0.12, 0.16, 0.22, 0.94),
	GridData.CellType.WALL: Color(0.34, 0.30, 0.27, 0.94),
	GridData.CellType.HOLE: Color(0.035, 0.04, 0.07, 0.96),
	GridData.CellType.LAVA: Color(0.72, 0.22, 0.07, 0.94),
	GridData.CellType.ICE: Color(0.42, 0.70, 0.88, 0.94),
	GridData.CellType.SHADOW: Color(0.11, 0.09, 0.18, 0.94),
	GridData.CellType.RUNE: Color(0.43, 0.16, 0.62, 0.94),
}

const GRID_LINE_COLOR := Color(0.95, 0.97, 0.9, 0.22)
const CENTER_COLOR := Color(0.82, 0.92, 1.0, 0.85)
const BOUNDS_COLOR := Color(1.0, 0.28, 0.70, 0.95)
const HOVER_FILL_COLOR := Color(0.35, 0.88, 1.0, 0.32)
const HOVER_LINE_COLOR := Color(0.48, 0.94, 1.0, 1.0)
const SELECTED_FILL_COLOR := Color(1.0, 0.70, 0.18, 0.36)
const SELECTED_LINE_COLOR := Color(1.0, 0.78, 0.28, 1.0)

## --- AJOUT TEST : lien vers la grille de terrain a recopier. ---
@export_node_path("TileMapLayer") var terrain_layer_path: NodePath
## Recalcule la synchro en continu dans l'editeur (live). Desactiver si ca rame.
@export var sync_live_in_editor := true

var grid: GridData = null
var debug_draw_enabled := true

@export var draw_base_cells := true
@export var draw_grid_lines := true
@export var draw_cell_centers := true
@export var draw_map_bounds := true

var _geometry_layer: TileMapLayer = null
var _hovered_cell := INVALID_CELL
var _selected_cell := INVALID_CELL
var _highlights: Dictionary = {}

## --- AJOUT TEST ---
var _terrain_layer: TileMapLayer = null
var _last_terrain_xform: Transform2D = Transform2D()


func _ready() -> void:
	if Engine.is_editor_hint():
		set_process(sync_live_in_editor)
	_sync_to_terrain()


func _process(_delta: float) -> void:
	# En editeur seulement : si la transform du terrain a change, on recale.
	if not Engine.is_editor_hint():
		return
	var terrain := _resolve_terrain_layer()
	if terrain != null and terrain.global_transform != _last_terrain_xform:
		_sync_to_terrain()


## Recopie la geometrie de tuile + la projection ecran du terrain sur la
## couche "Geometry" de la grille de jeu. C'est le coeur du test.
func _sync_to_terrain() -> void:
	var terrain := _resolve_terrain_layer()
	if terrain == null:
		return
	var layer := _ensure_geometry_layer()
	_configure_tile_set(layer)
	# Meme placement/inclinaison a l'ecran que le terrain -> les losanges de la
	# grille de jeu tombent pile sur les tuiles peintes.
	layer.global_transform = terrain.global_transform
	_last_terrain_xform = terrain.global_transform
	queue_redraw()


func _resolve_terrain_layer() -> TileMapLayer:
	if is_instance_valid(_terrain_layer):
		return _terrain_layer
	if terrain_layer_path != NodePath():
		_terrain_layer = get_node_or_null(terrain_layer_path) as TileMapLayer
	if _terrain_layer == null:
		# Repli pratique : un voisin nomme "TerrainLayer".
		_terrain_layer = get_node_or_null(^"../TerrainLayer") as TileMapLayer
	return _terrain_layer


## Couche de reference pour TOUS les calculs de grille (case, survol, placement).
## On vise le TerrainLayer directement : la grille de jeu est alors LITTERALEMENT
## celle du terrain, sans copie ni derive possible. Repli sur "Geometry" si aucun
## terrain n'est designe.
func _math_layer() -> TileMapLayer:
	var terrain := _resolve_terrain_layer()
	if terrain != null and terrain.tile_set != null:
		return terrain
	return _ensure_geometry_layer()


func setup(grid_data: GridData) -> void:
	if grid_data == null:
		push_error("IsoGridViewTest.setup() requiert un GridData valide.")
		return
	grid = grid_data
	_ensure_geometry_layer()
	_sync_to_terrain()
	_hovered_cell = INVALID_CELL
	_selected_cell = INVALID_CELL
	_highlights.clear()
	queue_redraw()


func get_geometry_layer() -> TileMapLayer:
	return _ensure_geometry_layer()


func get_hovered_cell() -> Vector2i:
	return _hovered_cell


func get_selected_cell() -> Vector2i:
	return _selected_cell


func set_debug_draw_enabled(enabled: bool) -> void:
	debug_draw_enabled = enabled
	draw_grid_lines = enabled
	draw_cell_centers = enabled
	draw_map_bounds = enabled
	queue_redraw()


func set_render_options(
		base_cells: bool,
		grid_lines: bool,
		cell_centers: bool,
		map_bounds: bool
	) -> void:
	draw_base_cells = base_cells
	draw_grid_lines = grid_lines
	draw_cell_centers = cell_centers
	draw_map_bounds = map_bounds
	debug_draw_enabled = grid_lines or cell_centers or map_bounds
	queue_redraw()


func set_selected_cell(cell: Vector2i) -> void:
	if grid == null or not grid.is_valid(cell):
		return
	if _selected_cell == cell:
		return
	_selected_cell = cell
	queue_redraw()


func clear_selection() -> void:
	if _selected_cell == INVALID_CELL:
		return
	_selected_cell = INVALID_CELL
	queue_redraw()


func highlight(
	cells: Array,
	color: Color,
	_marker: StringName = &""
	) -> void:
	if grid == null:
		return
	for cell in cells:
		if cell is Vector2i and grid.is_valid(cell):
			_highlights[cell] = color
	queue_redraw()


func clear_highlights() -> void:
	_highlights.clear()
	queue_redraw()


func grid_to_local(cell: Vector2i) -> Vector2:
	var layer := _math_layer()
	var point_in_layer := layer.map_to_local(cell)
	return to_local(layer.to_global(point_in_layer))


func local_to_grid(local_position: Vector2) -> Vector2i:
	var layer := _math_layer()
	var point_in_layer := layer.to_local(to_global(local_position))
	return layer.local_to_map(point_in_layer)


func grid_to_world(cell: Vector2i) -> Vector2:
	return grid_to_local(cell)


func world_to_grid(local_position: Vector2) -> Vector2i:
	return local_to_grid(local_position)


func get_cell_polygon(cell: Vector2i) -> PackedVector2Array:
	var layer := _math_layer()
	var center_in_layer := layer.map_to_local(cell)
	var half_size := _tile_half_size()
	var points_in_layer := PackedVector2Array([
		center_in_layer + Vector2(0.0, -half_size.y),
		center_in_layer + Vector2(half_size.x, 0.0),
		center_in_layer + Vector2(0.0, half_size.y),
		center_in_layer + Vector2(-half_size.x, 0.0),
	])
	var polygon := PackedVector2Array()
	for point in points_in_layer:
		polygon.append(to_local(layer.to_global(point)))
	return polygon


## --- AJOUT TEST : demi-taille reelle de la tuile (suit le terrain). ---
func _tile_half_size() -> Vector2:
	var layer := _math_layer()
	if layer.tile_set != null:
		return Vector2(layer.tile_set.tile_size) * 0.5
	return Vector2(FOOTPRINT) * 0.5


func get_map_bounds() -> Rect2:
	if grid == null or grid.cols <= 0 or grid.rows <= 0:
		return Rect2()

	var first_polygon := get_cell_polygon(Vector2i.ZERO)
	var minimum := first_polygon[0]
	var maximum := first_polygon[0]
	for x in range(grid.cols):
		for y in range(grid.rows):
			for point in get_cell_polygon(Vector2i(x, y)):
				minimum = minimum.min(point)
				maximum = maximum.max(point)
	return Rect2(minimum, maximum - minimum)


func get_pixel_size() -> Vector2:
	return get_map_bounds().size


func update_hover(local_position: Vector2) -> Vector2i:
	var cell := _valid_cell_at(local_position)
	if cell != _hovered_cell:
		_hovered_cell = cell
		queue_redraw()
		cell_hovered.emit(cell)
	return cell


func click_at(local_position: Vector2) -> Vector2i:
	var cell := _valid_cell_at(local_position)
	if cell != INVALID_CELL:
		set_selected_cell(cell)
		cell_clicked.emit(cell)
	return cell


func _unhandled_input(event: InputEvent) -> void:
	if grid == null:
		return
	if event is InputEventMouseMotion:
		update_hover(get_local_mouse_position())
	elif event is InputEventMouseButton \
			and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		click_at(get_local_mouse_position())


func _valid_cell_at(local_position: Vector2) -> Vector2i:
	var candidate := local_to_grid(local_position)
	if grid != null and grid.is_terrain_interactable(candidate):
		return candidate
	return INVALID_CELL


func _ensure_geometry_layer() -> TileMapLayer:
	if is_instance_valid(_geometry_layer):
		_configure_tile_set(_geometry_layer)
		return _geometry_layer

	_geometry_layer = get_node_or_null("Geometry") as TileMapLayer
	if _geometry_layer == null:
		_geometry_layer = TileMapLayer.new()
		_geometry_layer.name = "Geometry"
		add_child(_geometry_layer)
	_configure_tile_set(_geometry_layer)
	return _geometry_layer


## MODIFIE : si un terrain est designe, on copie SA geometrie de tuile
## (taille/forme/agencement) au lieu du FOOTPRINT fixe. Sinon, valeurs iso par
## defaut comme dans le script original.
func _configure_tile_set(layer: TileMapLayer) -> void:
	if layer.tile_set == null:
		layer.tile_set = TileSet.new()
	var tile_set := layer.tile_set
	var terrain := _resolve_terrain_layer()
	if terrain != null and terrain.tile_set != null:
		tile_set.tile_size = terrain.tile_set.tile_size
		tile_set.tile_shape = terrain.tile_set.tile_shape
		tile_set.tile_layout = terrain.tile_set.tile_layout
		tile_set.tile_offset_axis = terrain.tile_set.tile_offset_axis
	else:
		tile_set.tile_size = FOOTPRINT
		tile_set.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
		tile_set.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
		tile_set.tile_offset_axis = TileSet.TILE_OFFSET_AXIS_HORIZONTAL


func _draw() -> void:
	if grid == null:
		return

	for x in range(grid.cols):
		for y in range(grid.rows):
			var cell := Vector2i(x, y)
			var polygon := get_cell_polygon(cell)
			var fill_color: Color = TYPE_COLORS.get(
				grid.get_type(cell), TYPE_COLORS[GridData.CellType.NORMAL]
			)
			if draw_base_cells:
				draw_colored_polygon(polygon, fill_color)
			if _highlights.has(cell):
				draw_colored_polygon(polygon, _highlights[cell])
			if draw_grid_lines and grid.is_terrain_interactable(cell):
				_draw_polygon_outline(polygon, GRID_LINE_COLOR, 0.75)
			if draw_cell_centers:
				draw_circle(grid_to_local(cell), 1.7, CENTER_COLOR)

	if grid.is_valid(_selected_cell):
		var selected_polygon := get_cell_polygon(_selected_cell)
		draw_colored_polygon(selected_polygon, SELECTED_FILL_COLOR)
		_draw_polygon_outline(selected_polygon, SELECTED_LINE_COLOR, 2.5)

	if grid.is_valid(_hovered_cell):
		var hovered_polygon := get_cell_polygon(_hovered_cell)
		draw_colored_polygon(hovered_polygon, HOVER_FILL_COLOR)
		_draw_polygon_outline(hovered_polygon, HOVER_LINE_COLOR, 2.0)

	if draw_map_bounds:
		draw_rect(get_map_bounds(), BOUNDS_COLOR, false, 2.0)


func _draw_polygon_outline(
		polygon: PackedVector2Array,
		color: Color,
		width: float
	) -> void:
	var closed_polygon := PackedVector2Array(polygon)
	closed_polygon.append(polygon[0])
	draw_polyline(closed_polygon, color, width, true)
