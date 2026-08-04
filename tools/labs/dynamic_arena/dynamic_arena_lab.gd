class_name DynamicArenaLab
extends Node2D

## Laboratoire isole : une instance de GridData, le Pathfinder partage et la
## facade IsoGridView existante. Aucun RoomData ni regle de run n'est charge.

const GRID_SIZE := Vector2i(8, 8)
const START_CELL := Vector2i(1, 3)
const DESTINATION_CELL := Vector2i(6, 3)
const INVALID_CELL := Vector2i(-1, -1)
const NORMALIZED_TILE_SIZE := Vector2(256.0, 128.0)
const LOGICAL_FOOTPRINT := Vector2(64.0, 32.0)
const TILE_SCALE := LOGICAL_FOOTPRINT / NORMALIZED_TILE_SIZE
const CAMERA_MARGIN := 0.78

const CellStateScript := preload("res://tools/labs/dynamic_arena/dynamic_cell_state.gd")
const WallScene := preload("res://tools/labs/dynamic_arena/DynamicWall.tscn")

const TEXTURE_PATHS := {
	DynamicCellState.Surface.STONE: "res://tools/labs/dynamic_arena/assets/normalized/stone.png",
	DynamicCellState.Surface.WATER: "res://tools/labs/dynamic_arena/assets/normalized/water.png",
	DynamicCellState.Surface.ICE: "res://tools/labs/dynamic_arena/assets/normalized/ice.png",
	DynamicCellState.Surface.LAVA: "res://tools/labs/dynamic_arena/assets/normalized/lava.png",
}

const SURFACE_COLORS := {
	DynamicCellState.Surface.STONE: Color("a8b5c3"),
	DynamicCellState.Surface.WATER: Color("38c8ed"),
	DynamicCellState.Surface.ICE: Color("c8f4ff"),
	DynamicCellState.Surface.LAVA: Color("ff6537"),
}

@onready var floor_layer: Node2D = $FloorLayer
@onready var surface_vfx_layer: Node2D = $SurfaceVFXLayer
@onready var dynamic_object_layer: Node2D = $DynamicObjectLayer
@onready var unit_layer: Node2D = $UnitLayer
@onready var grid_view: IsoGridView = $GridDebugLayer
@onready var camera: Camera2D = $Camera2D
@onready var path_line: Line2D = $SurfaceVFXLayer/PathLine
@onready var destination_marker: Line2D = $SurfaceVFXLayer/DestinationMarker
@onready var unit_marker: Node2D = $UnitLayer/TestUnit

@onready var selected_state_label: Label = $CanvasLayer/Toolbar/Margin/VBox/SelectedState
@onready var hovered_label: Label = $CanvasLayer/Toolbar/Margin/VBox/Hovered
@onready var current_surface_label: Label = $CanvasLayer/Toolbar/Margin/VBox/CurrentSurface
@onready var walkable_label: Label = $CanvasLayer/Toolbar/Margin/VBox/Walkable
@onready var coordinates_label: Label = $CanvasLayer/Toolbar/Margin/VBox/Coordinates
@onready var path_length_label: Label = $CanvasLayer/Toolbar/Margin/VBox/PathLength
@onready var mode_label: Label = $CanvasLayer/Toolbar/Margin/VBox/Mode

var grid: GridData = null
var pathfinder: Pathfinder = null
var cell_states: DynamicCellState = null
var start_cell := START_CELL
var destination_cell := DESTINATION_CELL
var hovered_cell := INVALID_CELL
var selected_surface := DynamicCellState.Surface.STONE
var current_path: Array = []
var path_recalculation_count := 0

var _textures: Dictionary = {}
var _tile_sprites: Dictionary = {}
var _walls: Dictionary = {}
var _grid_debug_visible := true
var _path_visible := true
var _unit_moving := false


func _ready() -> void:
	grid = GridData.new(GRID_SIZE.x, GRID_SIZE.y)
	cell_states = CellStateScript.new()
	cell_states.configure(grid, DynamicCellState.Surface.STONE, {
		DynamicCellState.Surface.STONE: true,
		DynamicCellState.Surface.WATER: true,
		DynamicCellState.Surface.ICE: true,
		DynamicCellState.Surface.LAVA: false,
	})
	pathfinder = Pathfinder.new(grid)
	cell_states.cell_surface_changed.connect(_on_cell_surface_changed)
	cell_states.cell_blocking_changed.connect(_on_cell_blocking_changed)

	grid_view.setup(grid)
	grid_view.set_render_options(false, true, false, true)
	# Le lab centralise les commandes souris afin que les cases bloquees restent
	# modifiables. IsoGridView reste la facade unique de conversion et de debug.
	grid_view.set_process_unhandled_input(false)
	_load_textures()
	_build_floor()
	reset_lab()
	get_viewport().size_changed.connect(_fit_camera)
	_fit_camera()
	queue_redraw()


func _draw() -> void:
	if grid_view == null or grid == null:
		return
	var bounds := grid_view.get_map_bounds().grow(72.0)
	draw_rect(bounds, Color("111a28"), true)
	draw_rect(bounds, Color("32445a"), false, 3.0)
	var platform := PackedVector2Array([
		Vector2(bounds.position.x + bounds.size.x * 0.5, bounds.position.y - 18.0),
		Vector2(bounds.end.x + 44.0, bounds.position.y + bounds.size.y * 0.5),
		Vector2(bounds.position.x + bounds.size.x * 0.5, bounds.end.y + 18.0),
		Vector2(bounds.position.x - 44.0, bounds.position.y + bounds.size.y * 0.5),
	])
	draw_colored_polygon(platform, Color("182536"))
	draw_polyline(PackedVector2Array(Array(platform) + [platform[0]]), Color("3a526c"), 2.0, true)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		set_hovered_cell(_cell_from_viewport(event.position))
		return
	if event is InputEventMouseButton and event.pressed:
		var cell := _cell_from_viewport(event.position)
		if not grid.is_valid(cell):
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.ctrl_pressed:
				toggle_wall_at(cell)
			else:
				selected_surface = cell_states.cycle_surface(cell)
				grid_view.set_selected_cell(cell)
			_update_toolbar()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			set_destination(cell)
			get_viewport().set_input_as_handled()
		return
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_1:
			_select_surface(DynamicCellState.Surface.STONE, true)
		KEY_2:
			_select_surface(DynamicCellState.Surface.WATER, true)
		KEY_3:
			_select_surface(DynamicCellState.Surface.ICE, true)
		KEY_4:
			_select_surface(DynamicCellState.Surface.LAVA, true)
		KEY_R:
			reset_lab()
		KEY_G:
			set_grid_debug_visible(not _grid_debug_visible)
		KEY_P:
			set_path_visible(not _path_visible)
		KEY_ENTER, KEY_SPACE:
			move_unit_along_current_path()
		_:
			return
	get_viewport().set_input_as_handled()


func reset_lab() -> void:
	for wall in _walls.values():
		if is_instance_valid(wall):
			wall.queue_free()
	_walls.clear()
	cell_states.reset(DynamicCellState.Surface.STONE, false)
	start_cell = START_CELL
	destination_cell = DESTINATION_CELL
	selected_surface = DynamicCellState.Surface.STONE
	hovered_cell = INVALID_CELL
	path_recalculation_count = 0
	for cell in _tile_sprites:
		_update_cell_visual(cell)
	grid_view.clear_selection()
	grid_view.clear_highlights()
	pathfinder.sync()
	_place_unit_marker(start_cell)
	_update_destination_marker()
	_recalculate_path(false)
	_update_toolbar()


func set_cell_surface(cell: Vector2i, surface: int) -> bool:
	return cell_states.set_surface(cell, surface)


func get_cell_surface(cell: Vector2i) -> int:
	return cell_states.get_surface(cell)


func is_cell_walkable(cell: Vector2i) -> bool:
	return cell_states.is_effectively_walkable(cell)


func set_start_cell(cell: Vector2i) -> bool:
	if not grid.is_valid(cell):
		return false
	start_cell = cell
	_place_unit_marker(cell)
	_recalculate_path()
	return true


func set_destination(cell: Vector2i) -> bool:
	if not grid.is_valid(cell):
		return false
	destination_cell = cell
	_update_destination_marker()
	_recalculate_path()
	_update_toolbar()
	return true


func toggle_wall_at(cell: Vector2i) -> bool:
	if not grid.is_valid(cell):
		return false
	if _walls.has(cell):
		var existing = _walls[cell]
		_walls.erase(cell)
		if is_instance_valid(existing):
			existing.queue_free()
		cell_states.set_blocker(cell, false)
		return false
	var wall := WallScene.instantiate() as DynamicWall
	wall.setup(cell)
	wall.position = _cell_position_in(dynamic_object_layer, cell)
	dynamic_object_layer.add_child(wall)
	_walls[cell] = wall
	cell_states.set_blocker(cell, true)
	return true


func has_wall(cell: Vector2i) -> bool:
	return _walls.has(cell) and cell_states.has_blocker(cell)


func get_current_path() -> Array:
	return current_path.duplicate()


func set_grid_debug_visible(enabled: bool) -> void:
	_grid_debug_visible = enabled
	grid_view.visible = enabled
	_update_toolbar()


func set_path_visible(enabled: bool) -> void:
	_path_visible = enabled
	path_line.visible = enabled
	destination_marker.visible = enabled
	_update_toolbar()


func set_hovered_cell(cell: Vector2i) -> void:
	hovered_cell = cell if grid != null and grid.is_valid(cell) else INVALID_CELL
	grid_view.clear_highlights()
	if grid != null and grid.is_valid(hovered_cell):
		grid_view.highlight([hovered_cell], Color(0.18, 0.86, 1.0, 0.24))
	_update_toolbar()


func move_unit_along_current_path() -> void:
	if _unit_moving or current_path.size() < 2:
		return
	_unit_moving = true
	var travel_path := current_path.duplicate()
	for index in range(1, travel_path.size()):
		var tween := create_tween()
		tween.set_trans(Tween.TRANS_SINE)
		tween.set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(
			unit_marker,
			"position",
			_cell_position_in(unit_layer, travel_path[index]),
			0.13
		)
		await tween.finished
	start_cell = destination_cell
	_unit_moving = false
	_recalculate_path()
	_update_toolbar()


func _select_surface(surface: int, apply_to_hovered: bool) -> void:
	selected_surface = surface
	if apply_to_hovered and grid.is_valid(hovered_cell):
		set_cell_surface(hovered_cell, surface)
		grid_view.set_selected_cell(hovered_cell)
	_update_toolbar()


func _on_cell_surface_changed(
	cell: Vector2i,
	_previous_surface: int,
	_surface: int,
	walkability_changed: bool
	) -> void:
	_update_cell_visual(cell)
	if walkability_changed:
		pathfinder.sync()
	_recalculate_path(false)
	_update_toolbar()


func _on_cell_blocking_changed(_cell: Vector2i, _blocked: bool) -> void:
	pathfinder.sync()
	_recalculate_path(false)
	_update_toolbar()


func _recalculate_path(synchronize_grid := true) -> void:
	if pathfinder == null:
		return
	current_path = pathfinder.find_path(
		start_cell,
		destination_cell,
		null,
		synchronize_grid
	)
	path_recalculation_count += 1
	var points := PackedVector2Array()
	for cell in current_path:
		points.append(_cell_position_in(surface_vfx_layer, cell))
	path_line.points = points
	path_line.default_color = Color("64e5ff") if not current_path.is_empty() else Color("ff526d")
	_update_toolbar()


func _load_textures() -> void:
	for surface in TEXTURE_PATHS:
		var texture := load(TEXTURE_PATHS[surface]) as Texture2D
		if texture == null:
			push_error("Tuile normalisee absente : %s" % str(TEXTURE_PATHS[surface]))
		_textures[surface] = texture


func _build_floor() -> void:
	for child in floor_layer.get_children():
		child.queue_free()
	_tile_sprites.clear()
	for diagonal in range(GRID_SIZE.x + GRID_SIZE.y - 1):
		for x in range(GRID_SIZE.x):
			var y := diagonal - x
			if y < 0 or y >= GRID_SIZE.y:
				continue
			var cell := Vector2i(x, y)
			var sprite := Sprite2D.new()
			sprite.name = "Cell_%d_%d" % [x, y]
			sprite.centered = true
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			sprite.scale = TILE_SCALE
			sprite.position = _cell_position_in(floor_layer, cell)
			sprite.z_index = diagonal
			floor_layer.add_child(sprite)
			_tile_sprites[cell] = sprite


func _update_cell_visual(cell: Vector2i) -> void:
	var sprite := _tile_sprites.get(cell) as Sprite2D
	if sprite == null:
		return
	var surface := cell_states.get_surface(cell)
	sprite.texture = _textures.get(surface) as Texture2D
	sprite.modulate = Color.WHITE


func _update_destination_marker() -> void:
	destination_marker.position = _cell_position_in(surface_vfx_layer, destination_cell)


func _place_unit_marker(cell: Vector2i) -> void:
	unit_marker.position = _cell_position_in(unit_layer, cell)


func _cell_position_in(parent: Node2D, cell: Vector2i) -> Vector2:
	var in_grid := grid_view.grid_to_local(cell)
	return parent.to_local(grid_view.to_global(in_grid))


func _cell_from_viewport(viewport_position: Vector2) -> Vector2i:
	var canvas_position := get_viewport().get_canvas_transform().affine_inverse() * viewport_position
	var local_in_grid := grid_view.to_local(canvas_position)
	var candidate := grid_view.local_to_grid(local_in_grid)
	return candidate if grid != null and grid.is_valid(candidate) else INVALID_CELL


func _fit_camera() -> void:
	if grid_view == null or grid == null:
		return
	var bounds := grid_view.get_map_bounds().grow(70.0)
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	camera.position = grid_view.to_global(bounds.get_center())
	var factor := minf(viewport_size.x / bounds.size.x, viewport_size.y / bounds.size.y)
	factor = clampf(factor * CAMERA_MARGIN, 0.5, 2.25)
	camera.zoom = Vector2(factor, factor)


func _update_toolbar() -> void:
	if not is_node_ready() or cell_states == null:
		return
	selected_state_label.text = "Etat selectionne : %s" % cell_states.surface_name(selected_surface)
	selected_state_label.add_theme_color_override(
		"font_color", SURFACE_COLORS.get(selected_surface, Color.WHITE)
	)
	if not grid.is_valid(hovered_cell):
		hovered_label.text = "Cellule survolee : —"
		current_surface_label.text = "Type actuel : —"
		walkable_label.text = "Praticabilite : —"
		coordinates_label.text = "Coordonnees : —"
	else:
		hovered_label.text = "Cellule survolee : (%d, %d)" % [hovered_cell.x, hovered_cell.y]
		current_surface_label.text = "Type actuel : %s%s" % [
			cell_states.get_surface_name(hovered_cell),
			" + MUR" if has_wall(hovered_cell) else "",
		]
		var walkable := cell_states.is_effectively_walkable(hovered_cell)
		walkable_label.text = "Praticabilite : %s" % ("OUI" if walkable else "BLOQUEE")
		walkable_label.add_theme_color_override(
			"font_color", Color("75f0b3") if walkable else Color("ff6b72")
		)
		coordinates_label.text = "Coordonnees : Vector2i(%d, %d)" % [hovered_cell.x, hovered_cell.y]
	path_length_label.text = "Chemin courant : %d pas (%d cellules)" % [
		maxi(0, current_path.size() - 1), current_path.size()
	]
	mode_label.text = "Grille [G] : %s   |   Chemin [P] : %s   |   Murs : %d" % [
		"ON" if _grid_debug_visible else "OFF",
		"ON" if _path_visible else "OFF",
		_walls.size(),
	]
