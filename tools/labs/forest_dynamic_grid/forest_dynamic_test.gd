class_name ForestDynamicTest
extends Node2D

## Prototype isole de la grille dynamique forestiere. La texture peinte reste
## un decor peripherique ; toutes les cases jouables sont rendues depuis le
## RoomGridLayout dans l'unique repere PaintedMapVisualData.

const INVALID_CELL := Vector2i(-1, -1)
const NATIVE_IMAGE_SIZE := Vector2(1376.0, 768.0)
const NORMALIZED_TILE_SIZE := Vector2(256.0, 128.0)
const FOREST_ROOM: RoomData = preload("res://data/rooms/first_run_room_01.tres")
const TEST_DATA: ForestDynamicTestData = preload(
	"res://tools/labs/forest_dynamic_grid/forest_dynamic_test_data.tres"
)
const STATIC_WALL_SCENE := preload(
	"res://tools/labs/forest_dynamic_grid/StaticForestWall.tscn"
)
const TEST_UNIT_SCENE := preload(
	"res://tools/labs/forest_dynamic_grid/ForestTestUnit.tscn"
)
const NONE_CONFIG: SurfaceConfig = preload(
	"res://battle/dynamic_terrain/surface_configs/forest_none.tres"
)
const FIRE_CONFIG: SurfaceConfig = preload(
	"res://battle/dynamic_terrain/surface_configs/forest_fire.tres"
)
const WATER_CONFIG: SurfaceConfig = preload(
	"res://battle/dynamic_terrain/surface_configs/forest_water.tres"
)
const ICE_CONFIG: SurfaceConfig = preload(
	"res://battle/dynamic_terrain/surface_configs/forest_ice.tres"
)
const SURFACE_CONFIGS: Array[SurfaceConfig] = [
	NONE_CONFIG, FIRE_CONFIG, WATER_CONFIG, ICE_CONFIG,
]
const SURFACE_MODULATES := {
	CellSurfaceState.DynamicSurface.FIRE: Color(0.92, 0.82, 0.70, 1.0),
	CellSurfaceState.DynamicSurface.WATER: Color(0.78, 0.91, 0.92, 1.0),
	CellSurfaceState.DynamicSurface.ICE: Color(0.86, 0.94, 0.92, 1.0),
}

@onready var forest_background: Node2D = $ForestBackground
@onready var background_sprite: Sprite2D = $ForestBackground/BackgroundSprite
@onready var base_tile_layer: Node2D = $BaseTileLayer
@onready var surface_state_layer: Node2D = $SurfaceStateLayer
@onready var dynamic_wall_layer: Node2D = $DynamicWallLayer
@onready var units_layer: Node2D = $DynamicWallLayer/Units
@onready var foreground_occlusion: Node2D = $DynamicWallLayer/ForegroundOcclusion
@onready var grid_debug: PaintedGridView = $GridDebug
@onready var path_line: Line2D = $SurfaceStateLayer/PathLine
@onready var camera: Camera2D = $Camera2D
@onready var ui: CanvasLayer = $UI
@onready var status_label: Label = $UI/Panel/Margin/VBox/Status

var grid: GridData = null
var pathfinder: Pathfinder = null
var terrain_effects: TerrainEffects = null
var blocker_service: DynamicBlockerService = null
var surface_service: DynamicSurfaceService = null
var room_layout: RoomGridLayout = null
var visual_data: PaintedMapVisualData = null

var hero_cell := Vector2i(4, 9)
var enemy_cell := Vector2i(8, 2)
var selected_surface := CellSurfaceState.DynamicSurface.FIRE
var current_path: Array = []
var _base_tiles: Dictionary = {}
var _surface_tiles: Dictionary = {}
var _static_walls: Dictionary = {}
var _steam_markers: Dictionary = {}
var _hero_marker: ForestTestUnit = null
var _enemy_marker: ForestTestUnit = null
var _tower_occluder: Polygon2D = null


func _ready() -> void:
	room_layout = FOREST_ROOM.grid_layout
	visual_data = FOREST_ROOM.painted_map_visual_data
	grid = GridData.new(room_layout.logical_size.x, room_layout.logical_size.y)
	room_layout.apply_to_grid(grid)
	pathfinder = Pathfinder.new(grid)
	terrain_effects = TerrainEffects.new(grid)
	blocker_service = DynamicBlockerService.new()
	blocker_service.configure(grid, pathfinder)
	surface_service = DynamicSurfaceService.new()
	surface_service.configure(grid, SURFACE_CONFIGS)
	surface_service.surface_changed.connect(_on_surface_changed)
	surface_service.steam_requested.connect(_on_steam_requested)

	background_sprite.texture = visual_data.load_background_texture()
	grid_debug.configure(
		visual_data,
		room_layout,
		FOREST_ROOM.hero_spawn_zone,
		FOREST_ROOM.enemy_spawn_zone
	)
	grid_debug.setup(grid)
	grid_debug.set_process_unhandled_input(false)
	_build_base_tiles()
	_build_surface_tiles()
	_build_static_walls()
	_build_units()
	_build_foreground_occluder()
	_connect_ui()
	set_grid_debug_mode(0)
	set_background_as_peripheral(true)
	_update_path()
	_update_status()
	get_viewport().size_changed.connect(_fit_camera)
	_fit_camera()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_F, KEY_1:
				select_surface(CellSurfaceState.DynamicSurface.FIRE)
			KEY_W, KEY_2:
				select_surface(CellSurfaceState.DynamicSurface.WATER)
			KEY_I, KEY_3:
				select_surface(CellSurfaceState.DynamicSurface.ICE)
			KEY_C, KEY_0:
				select_surface(CellSurfaceState.DynamicSurface.NONE)
			KEY_G:
				set_grid_debug_mode(0 if grid_debug.visible else 1)
			KEY_R:
				reset_test()
			KEY_T:
				advance_turn()
		return
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_event := event as InputEventMouseButton
		var canvas_position: Vector2 = (
			get_viewport().get_canvas_transform().affine_inverse() * mouse_event.position
		)
		var cell := visual_data.image_to_cell(to_local(canvas_position))
		if selected_surface == CellSurfaceState.DynamicSurface.NONE:
			clear_surface(cell)
		else:
			apply_surface_effect(cell, selected_surface, null)


func _build_base_tiles() -> void:
	for cell in room_layout.walkable_cells():
		var tile := _new_painted_neutral_tile(cell)
		tile.name = "Neutral_%d_%d" % [cell.x, cell.y]
		base_tile_layer.add_child(tile)
		_base_tiles[cell] = tile


func _new_painted_neutral_tile(cell: Vector2i) -> Polygon2D:
	# Une cellule neutre est une vraie dalle opaque, decoupee dans la peinture
	# validee. Elle conserve ainsi exactement la pierre, la mousse, les ombres et
	# l'eclairage de l'arene au lieu de poser un carrelage generique par-dessus.
	var tile := Polygon2D.new()
	var source_polygon := visual_data.cell_polygon(cell)
	var center := visual_data.cell_to_image(cell)
	var local_polygon := PackedVector2Array()
	for point in source_polygon:
		local_polygon.append(point - center)
	tile.position = center
	tile.polygon = local_polygon
	tile.texture = background_sprite.texture
	tile.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	tile.uv = source_polygon
	tile.color = Color.WHITE
	return tile


func _build_surface_tiles() -> void:
	for cell in room_layout.walkable_cells():
		var sprite := _new_tile_sprite(NONE_CONFIG.texture, cell)
		sprite.name = "Surface_%d_%d" % [cell.x, cell.y]
		sprite.visible = false
		surface_state_layer.add_child(sprite)
		_surface_tiles[cell] = sprite


func _new_tile_sprite(texture: Texture2D, cell: Vector2i) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = true
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.position = visual_data.cell_to_image(cell)
	var polygon := visual_data.cell_polygon(cell)
	var minimum := polygon[0]
	var maximum := polygon[0]
	for point in polygon:
		minimum = minimum.min(point)
		maximum = maximum.max(point)
	var calibrated_size := maximum - minimum
	# Le losange normalise occupe 256 x 128 ; les dimensions viennent du
	# polygone calibre, pas d'une conversion gameplay secondaire.
	sprite.scale = calibrated_size / NORMALIZED_TILE_SIZE
	return sprite


func _build_static_walls() -> void:
	for cell in TEST_DATA.all_static_wall_cells():
		assert(grid.is_terrain_interactable(cell), "Mur statique hors sol : %s" % cell)
		assert(not FOREST_ROOM.hero_spawn_zone.has(cell), "Mur sur spawn heros : %s" % cell)
		assert(not FOREST_ROOM.enemy_spawn_zone.has(cell), "Mur sur spawn ennemi : %s" % cell)
		var wall := STATIC_WALL_SCENE.instantiate() as StaticForestWall
		wall.configure(cell)
		wall.position = visual_data.cell_to_image(cell)
		dynamic_wall_layer.add_child(wall)
		assert(blocker_service.register_dynamic_blocker(cell, wall))
		_static_walls[cell] = wall
		_set_base_tile_visible(cell, false)


func _build_units() -> void:
	_hero_marker = TEST_UNIT_SCENE.instantiate() as ForestTestUnit
	dynamic_wall_layer.add_child(_hero_marker)
	_enemy_marker = TEST_UNIT_SCENE.instantiate() as ForestTestUnit
	dynamic_wall_layer.add_child(_enemy_marker)
	set_unit_cells(hero_cell, enemy_cell)


func _build_foreground_occluder() -> void:
	var occluder := visual_data.create_foreground_occluder(background_sprite.texture)
	if occluder != null:
		dynamic_wall_layer.add_child(occluder)
		_tower_occluder = occluder


func _connect_ui() -> void:
	$UI/Panel/Margin/VBox/Buttons/Fire.pressed.connect(
		func(): select_surface(CellSurfaceState.DynamicSurface.FIRE)
	)
	$UI/Panel/Margin/VBox/Buttons/Water.pressed.connect(
		func(): select_surface(CellSurfaceState.DynamicSurface.WATER)
	)
	$UI/Panel/Margin/VBox/Buttons/Ice.pressed.connect(
		func(): select_surface(CellSurfaceState.DynamicSurface.ICE)
	)
	$UI/Panel/Margin/VBox/Buttons/Clear.pressed.connect(
		func(): select_surface(CellSurfaceState.DynamicSurface.NONE)
	)
	$UI/Panel/Margin/VBox/Reset.pressed.connect(reset_test)


func select_surface(surface: int) -> void:
	selected_surface = surface
	_update_status()


func apply_surface_effect(cell: Vector2i, effect: int, source_unit = null) -> Dictionary:
	if not grid.is_terrain_interactable(cell) or grid.is_cell_dynamically_blocked(cell):
		return {"handled": false, "surface": get_surface(cell), "steam": false}
	var result := surface_service.apply_surface_effect(cell, effect, source_unit)
	_update_status()
	return result


func set_surface(cell: Vector2i, surface: int, source_unit = null) -> bool:
	if surface == CellSurfaceState.DynamicSurface.NONE:
		return clear_surface(cell)
	return bool(apply_surface_effect(cell, surface, source_unit).handled)


func clear_surface(cell: Vector2i) -> bool:
	if not surface_service.has_state(cell):
		return false
	var changed := surface_service.clear_surface(cell)
	_update_status()
	return changed


func refresh_surface_layer() -> void:
	surface_service.refresh_surface_layer()
	for cell in _surface_tiles:
		_refresh_surface_visual(cell)


func get_surface(cell: Vector2i) -> int:
	return surface_service.get_surface(cell)


func get_surface_state(cell: Vector2i) -> CellSurfaceState:
	return surface_service.get_state(cell)


func advance_turn() -> Array[Vector2i]:
	var expired := surface_service.advance_turn()
	refresh_surface_layer()
	_update_status()
	return expired


func get_turn_start_damage(cell: Vector2i) -> int:
	return surface_service.get_turn_start_damage(cell)


func reset_test() -> void:
	surface_service.reset()
	clear_steam_markers()
	hero_cell = FOREST_ROOM.hero_spawn_zone[0]
	enemy_cell = FOREST_ROOM.enemy_spawn_zone[0]
	set_unit_cells(hero_cell, enemy_cell)
	set_static_walls_visible(true, false)
	_update_path()
	_update_status()


func set_static_walls_visible(visible_now: bool, expose_floor := true) -> void:
	for cell in _static_walls:
		(_static_walls[cell] as StaticForestWall).visible = visible_now
		_set_base_tile_visible(cell, not visible_now and expose_floor)


func set_unit_cells(new_hero_cell: Vector2i, new_enemy_cell: Vector2i) -> void:
	assert(grid.is_terrain_interactable(new_hero_cell))
	assert(grid.is_terrain_interactable(new_enemy_cell))
	hero_cell = new_hero_cell
	enemy_cell = new_enemy_cell
	_hero_marker.configure(hero_cell, 0, "HERO")
	_enemy_marker.configure(enemy_cell, 1, "IA")
	_hero_marker.position = visual_data.cell_to_image(hero_cell)
	_enemy_marker.position = visual_data.cell_to_image(enemy_cell)
	_update_path()


func move_hero_to(cell: Vector2i) -> bool:
	if not grid.is_walkable(cell):
		return false
	hero_cell = cell
	_hero_marker.set_logical_cell(cell)
	_hero_marker.position = visual_data.cell_to_image(cell)
	_update_path()
	return true


func compute_ai_path() -> Array:
	return pathfinder.find_path(enemy_cell, hero_cell)


func get_current_path() -> Array:
	return current_path.duplicate()


func has_line_of_sight(from: Vector2i, to: Vector2i) -> bool:
	return pathfinder.has_line_of_sight(from, to)


func has_projectile_path(from: Vector2i, to: Vector2i) -> bool:
	return pathfinder.has_projectile_path(from, to)


func is_unit_visually_behind_wall(unit_cell: Vector2i, wall_cell: Vector2i) -> bool:
	var unit_position := visual_data.cell_to_image(unit_cell)
	var wall_position := visual_data.cell_to_image(wall_cell)
	return unit_position.y < wall_position.y and absf(unit_position.x - wall_position.x) <= 35.0


func is_unit_visually_in_front_of_wall(unit_cell: Vector2i, wall_cell: Vector2i) -> bool:
	var unit_position := visual_data.cell_to_image(unit_cell)
	var wall_position := visual_data.cell_to_image(wall_cell)
	return unit_position.y > wall_position.y and absf(unit_position.x - wall_position.x) <= 35.0


func is_unit_hidden_by_tower(cell: Vector2i) -> bool:
	var image_position := visual_data.cell_to_image(cell)
	return image_position.y < visual_data.foreground_occluder_sort_y \
			and visual_data.is_position_fully_occluded(image_position)


func set_grid_debug_mode(mode: int) -> void:
	grid_debug.visible = mode > 0
	if mode <= 0:
		return
	grid_debug.set_render_options(false, true, mode >= 2, mode >= 2)
	grid_debug.set_debug_layers(false, mode >= 2, mode >= 2, mode >= 2, mode >= 2)


func set_background_as_peripheral(enabled: bool) -> void:
	# La peinture et les cellules neutres partagent exactement la meme couleur :
	# aucune dalle transparente et aucune rupture de colorimetrie au bord.
	background_sprite.modulate = Color.WHITE


func set_capture_layers(
		background_only: bool,
		walls_visible: bool,
		units_visible: bool,
		grid_mode: int,
		path_visible: bool,
		ui_visible: bool
	) -> void:
	base_tile_layer.visible = not background_only
	surface_state_layer.visible = not background_only
	set_static_walls_visible(walls_visible and not background_only, true)
	var show_units := units_visible and not background_only
	_hero_marker.visible = show_units
	_enemy_marker.visible = show_units
	if _tower_occluder != null:
		_tower_occluder.visible = show_units
	set_grid_debug_mode(grid_mode if not background_only else 0)
	path_line.visible = path_visible and not background_only
	ui.visible = ui_visible
	set_background_as_peripheral(not background_only)


func set_unit_names_visible(visible_now: bool) -> void:
	if _hero_marker != null:
		(_hero_marker.get_node("Name") as Label).visible = visible_now
	if _enemy_marker != null:
		(_enemy_marker.get_node("Name") as Label).visible = visible_now


func clear_steam_markers() -> void:
	for marker in _steam_markers.values():
		if marker != null and is_instance_valid(marker):
			marker.queue_free()
	_steam_markers.clear()


func surface_count(surface: int) -> int:
	var count := 0
	for cell in room_layout.walkable_cells():
		if get_surface(cell) == surface:
			count += 1
	return count


func get_static_wall_cells() -> Array[Vector2i]:
	return TEST_DATA.all_static_wall_cells()


func _on_surface_changed(cell: Vector2i, _previous: int, _surface: int) -> void:
	_refresh_surface_visual(cell)


func _refresh_surface_visual(cell: Vector2i) -> void:
	if not _surface_tiles.has(cell):
		return
	var sprite := _surface_tiles[cell] as Sprite2D
	var surface := get_surface(cell)
	if surface == CellSurfaceState.DynamicSurface.NONE:
		sprite.visible = false
		return
	var config := surface_service.configs.get(surface) as SurfaceConfig
	sprite.texture = config.texture if config != null else NONE_CONFIG.texture
	sprite.self_modulate = SURFACE_MODULATES.get(surface, Color(1, 1, 1, 0.7))
	sprite.visible = true


func _on_steam_requested(cell: Vector2i) -> void:
	if _steam_markers.has(cell):
		var previous = _steam_markers[cell]
		if previous != null and is_instance_valid(previous):
			previous.queue_free()
	var marker := Node2D.new()
	marker.name = "Steam_%d_%d" % [cell.x, cell.y]
	marker.position = visual_data.cell_to_image(cell)
	var cloud := Polygon2D.new()
	cloud.polygon = PackedVector2Array([
		Vector2(-26, 2), Vector2(-18, -14), Vector2(-7, -18),
		Vector2(0, -32), Vector2(12, -20), Vector2(25, -13),
		Vector2(29, 2), Vector2(0, 13),
	])
	cloud.color = Color(0.88, 0.96, 1.0, 0.78)
	marker.add_child(cloud)
	var label := Label.new()
	label.text = "VAPEUR"
	label.position = Vector2(-29, -51)
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color.WHITE)
	marker.add_child(label)
	surface_state_layer.add_child(marker)
	_steam_markers[cell] = marker


func _set_base_tile_visible(cell: Vector2i, visible_now: bool) -> void:
	if _base_tiles.has(cell):
		(_base_tiles[cell] as CanvasItem).visible = visible_now


func _update_path() -> void:
	if pathfinder == null:
		return
	current_path = pathfinder.find_path(hero_cell, enemy_cell)
	path_line.clear_points()
	for cell in current_path:
		path_line.add_point(visual_data.cell_to_image(cell))


func _update_status() -> void:
	if status_label == null or surface_service == null:
		return
	var selected_name: String = ["NONE", "FIRE", "WATER", "ICE"][selected_surface]
	status_label.text = (
		"Surface : %s  |  chemin : %d cases  |  murs statiques : %d\n"
		+ "F/W/I ou 1/2/3, C pour effacer, clic pour appliquer, T tour, G grille, R reset"
	) % [selected_name, current_path.size(), _static_walls.size()]


func _fit_camera() -> void:
	if camera == null:
		return
	var viewport_size := Vector2(get_viewport_rect().size)
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var fit := minf(viewport_size.x / NATIVE_IMAGE_SIZE.x, viewport_size.y / NATIVE_IMAGE_SIZE.y)
	camera.position = NATIVE_IMAGE_SIZE * 0.5
	camera.zoom = Vector2.ONE * fit
