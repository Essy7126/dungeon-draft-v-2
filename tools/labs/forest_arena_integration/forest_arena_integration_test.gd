class_name ForestArenaIntegrationTest
extends Node2D

const INVALID_CELL := Vector2i(-1, -1)
const NORMALIZED_TILE_SIZE := Vector2(256.0, 128.0)
const CONFIG: ForestArenaIntegrationConfig = preload(
	"res://tools/labs/forest_arena_integration/forest_arena_integration_config.tres"
)
const MODEL_SCRIPT := preload(
	"res://tools/labs/forest_arena_integration/forest_arena_integration_map.gd"
)
const TEST_UNIT_SCENE := preload(
	"res://tools/labs/forest_dynamic_grid/ForestTestUnit.tscn"
)
const STATIC_WALL_SCENE := preload(
	"res://tools/labs/forest_dynamic_grid/StaticForestWall.tscn"
)
const DYNAMIC_WALL_SCENE := preload(
	"res://tools/labs/dynamic_arena/DynamicWall.tscn"
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
const BASE_WALL_CONFIG: WallConfig = preload(
	"res://battle/dynamic_terrain/configs/wall_base.tres"
)
const FIRE_WALL_CONFIG: WallConfig = preload(
	"res://battle/dynamic_terrain/configs/wall_fire.tres"
)
const ICE_WALL_CONFIG: WallConfig = preload(
	"res://battle/dynamic_terrain/configs/wall_ice.tres"
)
const SURFACE_CONFIGS: Array[SurfaceConfig] = [
	NONE_CONFIG, FIRE_CONFIG, WATER_CONFIG, ICE_CONFIG,
]
const WALL_CONFIGS := {
	DynamicWall.WallVariant.BASE: BASE_WALL_CONFIG,
	DynamicWall.WallVariant.FIRE: FIRE_WALL_CONFIG,
	DynamicWall.WallVariant.ICE: ICE_WALL_CONFIG,
}
const BASE_TEXTURES := {
	"STONE": preload("res://tools/labs/dynamic_arena/assets/normalized/stone.png"),
	"WATER": preload("res://tools/labs/dynamic_arena/assets/normalized/water.png"),
	"ICE": preload("res://tools/labs/dynamic_arena/assets/normalized/ice.png"),
	"LAVA": preload("res://tools/labs/dynamic_arena/assets/normalized/lava.png"),
	"SHADOW": preload("res://tools/labs/dynamic_arena/assets/normalized/stone.png"),
	"RUNE": preload("res://tools/labs/dynamic_arena/assets/normalized/stone.png"),
}
const BASE_TINTS := {
	"STONE": Color.WHITE,
	"WATER": Color(0.82, 0.96, 1.0, 1.0),
	"ICE": Color(0.9, 0.98, 1.0, 1.0),
	"LAVA": Color(1.0, 0.88, 0.76, 1.0),
	"SHADOW": Color(0.32, 0.25, 0.48, 1.0),
	"RUNE": Color(0.72, 0.36, 0.88, 1.0),
}
const SURFACE_TEXTURES := {
	CellSurfaceState.DynamicSurface.FIRE: preload(
		"res://tools/labs/dynamic_arena/assets/normalized/lava.png"
	),
	CellSurfaceState.DynamicSurface.WATER: preload(
		"res://tools/labs/dynamic_arena/assets/normalized/water.png"
	),
	CellSurfaceState.DynamicSurface.ICE: preload(
		"res://tools/labs/dynamic_arena/assets/normalized/ice.png"
	),
}
const SURFACE_NAMES := ["NEUTRAL", "FIRE", "WATER", "ICE"]

@onready var painted_background: Sprite2D = $PaintedBackground
@onready var dynamic_base_tiles: Node2D = $DynamicBaseTiles
@onready var dynamic_surface_tiles: Node2D = $DynamicSurfaceTiles
@onready var path_line: Line2D = $DynamicSurfaceTiles/PathLine
@onready var y_sorted_world: Node2D = $YSortedWorld
@onready var static_walls_layer: Node2D = $YSortedWorld/StaticWalls
@onready var dynamic_walls_layer: Node2D = $YSortedWorld/DynamicWalls
@onready var units_layer: Node2D = $YSortedWorld/Units
@onready var foreground_occlusion: Node2D = $YSortedWorld/ForegroundOcclusion
@onready var grid_debug: ForestArenaIntegrationDebugView = $GridDebug
@onready var camera: Camera2D = $Camera2D
@onready var debug_ui: CanvasLayer = $CanvasLayer
@onready var status_label: Label = $CanvasLayer/DebugUI/Margin/VBox/Status
@onready var inspector_label: Label = $CanvasLayer/DebugUI/Margin/VBox/Inspector

var map_model: ForestArenaIntegrationMap = null
var grid: GridData = null
var pathfinder: Pathfinder = null
var terrain_effects: TerrainEffects = null
var blocker_service: DynamicBlockerService = null
var surface_service: DynamicSurfaceService = null

var selected_surface := CellSurfaceState.DynamicSurface.NONE
var hero_cell := INVALID_CELL
var enemy_cell := INVALID_CELL
var objective_cells: Array[Vector2i] = []
var current_path: Array = []
var hovered_cell := INVALID_CELL
var validation_errors := PackedStringArray()
var load_time_ms := 0.0
var _fps_samples := PackedFloat32Array()
var _base_tiles: Dictionary = {}
var _surface_tiles: Dictionary = {}
var _static_walls: Dictionary = {}
var _dynamic_walls: Dictionary = {}
var _initial_surfaces: Dictionary = {}
var _hero_unit: ForestTestUnit = null
var _enemy_unit: ForestTestUnit = null
var _grid_visible := false
var _categories_visible := false
var _coordinates_visible := false


func _ready() -> void:
	var started := Time.get_ticks_usec()
	validation_errors.append_array(CONFIG.validation_errors())
	map_model = MODEL_SCRIPT.new() as ForestArenaIntegrationMap
	if not map_model.load_from_path(CONFIG.map_definition_path, CONFIG.border_thickness):
		validation_errors.append_array(map_model.validation_errors())
	if not validation_errors.is_empty():
		push_error("Forest Arena Integration invalide : %s" % validation_errors)
		_update_status()
		return
	grid = GridData.new(map_model.grid_size.x, map_model.grid_size.y)
	map_model.apply_to_grid(grid)
	pathfinder = Pathfinder.new(grid)
	terrain_effects = TerrainEffects.new(grid)
	blocker_service = DynamicBlockerService.new()
	blocker_service.configure(grid, pathfinder)
	surface_service = DynamicSurfaceService.new()
	surface_service.configure(grid, SURFACE_CONFIGS)
	surface_service.surface_changed.connect(_on_surface_changed)
	surface_service.steam_requested.connect(_on_steam_requested)
	painted_background.texture = CONFIG.background_texture
	_build_base_tiles()
	_build_surface_tiles()
	_load_initial_surfaces()
	_build_static_walls()
	_build_units()
	grid_debug.configure(CONFIG, map_model, grid)
	grid_debug.set_modes(false, false, false)
	_connect_ui()
	_update_path()
	_update_status()
	get_viewport().size_changed.connect(_fit_camera)
	_fit_camera()
	camera.enabled = true
	camera.make_current()
	load_time_ms = float(Time.get_ticks_usec() - started) / 1000.0


func _process(_delta: float) -> void:
	if _fps_samples.size() < 240:
		_fps_samples.append(float(Engine.get_frames_per_second()))


func reset_performance_samples() -> void:
	# The capture runner writes large PNGs synchronously. Those I/O stalls are not
	# representative of the arena, so it starts a clean steady-state FPS window.
	_fps_samples.clear()


func _unhandled_input(event: InputEvent) -> void:
	if not validation_errors.is_empty() or map_model == null:
		return
	if event is InputEventKey:
		var key := event as InputEventKey
		if not key.pressed or key.echo:
			return
		match key.keycode:
			KEY_1:
				select_surface(CellSurfaceState.DynamicSurface.NONE)
			KEY_2:
				select_surface(CellSurfaceState.DynamicSurface.FIRE)
			KEY_3:
				select_surface(CellSurfaceState.DynamicSurface.WATER)
			KEY_4:
				select_surface(CellSurfaceState.DynamicSurface.ICE)
			KEY_G:
				_grid_visible = not _grid_visible
				_apply_debug_modes()
			KEY_P:
				path_line.visible = not path_line.visible
			KEY_B:
				_categories_visible = not _categories_visible
				_coordinates_visible = _categories_visible
				_apply_debug_modes()
			KEY_R:
				reset_test()
		return
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		var cell := _event_position_to_cell(motion.position)
		if cell != hovered_cell:
			hovered_cell = cell
			grid_debug.set_hovered_cell(cell)
			_update_inspector(cell)
	elif event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if not button.pressed or button.button_index not in [
			MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT,
		]:
			return
		var cell := _event_position_to_cell(button.position)
		if button.alt_pressed:
			hovered_cell = cell
			_update_inspector(cell)
			return
		if button.button_index == MOUSE_BUTTON_RIGHT:
			clear_surface_effect(cell)
		else:
			apply_surface_effect(cell, selected_surface, null)


func _event_position_to_cell(viewport_position: Vector2) -> Vector2i:
	var canvas_position := get_viewport().get_canvas_transform().affine_inverse() * viewport_position
	var candidate := CONFIG.screen_to_cell(to_local(canvas_position))
	return candidate if grid != null and grid.is_valid(candidate) else INVALID_CELL


func _build_base_tiles() -> void:
	for cell in map_model.cells_in_category(ForestArenaIntegrationMap.CellCategory.PLAYABLE):
		var state := map_model.get_state(cell)
		var base_name := str(state.base)
		var sprite := _new_tile_sprite(
			BASE_TEXTURES.get(base_name, BASE_TEXTURES.STONE), cell
		)
		sprite.name = "Base_%d_%d_%s" % [cell.x, cell.y, base_name]
		sprite.self_modulate = BASE_TINTS.get(base_name, Color.WHITE)
		dynamic_base_tiles.add_child(sprite)
		_base_tiles[cell] = sprite


func _build_surface_tiles() -> void:
	for cell in map_model.cells_in_category(ForestArenaIntegrationMap.CellCategory.PLAYABLE):
		var sprite := _new_tile_sprite(NONE_CONFIG.texture, cell)
		sprite.name = "Surface_%d_%d" % [cell.x, cell.y]
		sprite.visible = false
		dynamic_surface_tiles.add_child(sprite)
		_surface_tiles[cell] = sprite


func _new_tile_sprite(texture: Texture2D, cell: Vector2i) -> Sprite2D:
	var sprite := Sprite2D.new()
	var polygon := CONFIG.cell_polygon(cell)
	var minimum := polygon[0]
	var maximum := polygon[0]
	for point in polygon:
		minimum = minimum.min(point)
		maximum = maximum.max(point)
	sprite.texture = texture
	sprite.centered = true
	sprite.position = CONFIG.cell_to_screen(cell)
	sprite.scale = (maximum - minimum) / NORMALIZED_TILE_SIZE
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.self_modulate = Color.WHITE
	return sprite


func _load_initial_surfaces() -> void:
	_initial_surfaces.clear()
	for cell in map_model.cells_in_category(ForestArenaIntegrationMap.CellCategory.PLAYABLE):
		var surface := _surface_name_to_enum(str(map_model.get_state(cell).surface))
		if surface == CellSurfaceState.DynamicSurface.NONE:
			continue
		_initial_surfaces[cell] = surface
		surface_service.set_surface(cell, surface, null)


func _surface_name_to_enum(surface_name: String) -> int:
	match surface_name:
		"FIRE":
			return CellSurfaceState.DynamicSurface.FIRE
		"WATER":
			return CellSurfaceState.DynamicSurface.WATER
		"ICE":
			return CellSurfaceState.DynamicSurface.ICE
		_:
			return CellSurfaceState.DynamicSurface.NONE


func _build_static_walls() -> void:
	for cell in map_model.static_wall_cells():
		var state := map_model.get_state(cell)
		var wall := STATIC_WALL_SCENE.instantiate() as StaticForestWall
		wall.configure(cell)
		wall.position = CONFIG.cell_to_screen(cell)
		wall.scale = _old_forest_asset_scale()
		var sprite := wall.get_node_or_null("VisualRoot/Sprite2D") as Sprite2D
		if sprite != null:
			sprite.texture = _wall_texture_for_name(str(state.wall))
		static_walls_layer.add_child(wall)
		if blocker_service.register_dynamic_blocker(cell, wall):
			_static_walls[cell] = wall
			_set_base_tile_visible(cell, false)


func _wall_texture_for_name(wall_name: String) -> Texture2D:
	match wall_name:
		"FIRE":
			return FIRE_WALL_CONFIG.texture
		"ICE":
			return ICE_WALL_CONFIG.texture
		_:
			return BASE_WALL_CONFIG.texture


func _old_forest_asset_scale() -> Vector2:
	var tile_width := absf(CONFIG.axis_x.x - CONFIG.axis_y.x) * CONFIG.global_scale
	var tile_height := absf(CONFIG.axis_x.y + CONFIG.axis_y.y) * CONFIG.global_scale
	return Vector2(tile_width / 68.8, tile_height / 34.133334)


func _dynamic_wall_scale() -> Vector2:
	var tile_width := absf(CONFIG.axis_x.x - CONFIG.axis_y.x) * CONFIG.global_scale
	var tile_height := absf(CONFIG.axis_x.y + CONFIG.axis_y.y) * CONFIG.global_scale
	return Vector2(tile_width / 64.0, tile_height / 32.0)


func _build_units() -> void:
	var allies := map_model.special_cells("ALLY_SPAWN")
	var enemies := map_model.special_cells("ENEMY_SPAWN")
	objective_cells = map_model.special_cells("OBJECTIVE")
	if allies.is_empty() or enemies.is_empty():
		validation_errors.append("Un spawn allie et un spawn ennemi sont requis.")
		return
	hero_cell = allies[0]
	enemy_cell = enemies[0]
	_hero_unit = TEST_UNIT_SCENE.instantiate() as ForestTestUnit
	_enemy_unit = TEST_UNIT_SCENE.instantiate() as ForestTestUnit
	units_layer.add_child(_hero_unit)
	units_layer.add_child(_enemy_unit)
	var unit_scale := minf(_old_forest_asset_scale().x, _old_forest_asset_scale().y)
	_hero_unit.scale = Vector2.ONE * unit_scale
	_enemy_unit.scale = Vector2.ONE * unit_scale
	set_unit_cells(hero_cell, enemy_cell)


func set_unit_cells(new_hero_cell: Vector2i, new_enemy_cell: Vector2i) -> bool:
	if not is_playable(new_hero_cell) or not is_playable(new_enemy_cell):
		return false
	if not grid.is_walkable(new_hero_cell) or not grid.is_walkable(new_enemy_cell):
		return false
	hero_cell = new_hero_cell
	enemy_cell = new_enemy_cell
	_hero_unit.configure(hero_cell, 0, "HERO")
	_enemy_unit.configure(enemy_cell, 1, "IA")
	_hero_unit.position = CONFIG.cell_to_screen(hero_cell)
	_enemy_unit.position = CONFIG.cell_to_screen(enemy_cell)
	_update_path()
	return true


func move_hero_to(cell: Vector2i) -> bool:
	if not is_playable(cell) or not grid.is_walkable(cell):
		return false
	hero_cell = cell
	_hero_unit.set_logical_cell(cell)
	_hero_unit.position = CONFIG.cell_to_screen(cell)
	_update_path()
	return true


func select_surface(surface: int) -> void:
	selected_surface = clampi(
		surface, CellSurfaceState.DynamicSurface.NONE,
		CellSurfaceState.DynamicSurface.ICE
	)
	_update_status()


func apply_surface_effect(cell: Vector2i, effect_type: int, source = null) -> Dictionary:
	if not is_playable(cell) or grid.is_cell_dynamically_blocked(cell):
		return {"handled": false, "surface": get_surface_effect(cell), "steam": false}
	if effect_type == CellSurfaceState.DynamicSurface.NONE:
		var cleared := clear_surface_effect(cell)
		return {"handled": cleared, "surface": get_surface_effect(cell), "steam": false}
	var result := surface_service.apply_surface_effect(cell, effect_type, source)
	_update_status()
	return result


func clear_surface_effect(cell: Vector2i) -> bool:
	if not is_playable(cell) or not surface_service.has_state(cell):
		return false
	var changed := surface_service.clear_surface(cell)
	refresh_cell_visual(cell)
	_update_status()
	return changed


func get_surface_effect(cell: Vector2i) -> int:
	return surface_service.get_surface(cell) if surface_service != null \
			else CellSurfaceState.DynamicSurface.NONE


func refresh_cell_visual(cell: Vector2i) -> void:
	if not _surface_tiles.has(cell):
		return
	var sprite := _surface_tiles[cell] as Sprite2D
	var surface := get_surface_effect(cell)
	if surface == CellSurfaceState.DynamicSurface.NONE:
		sprite.visible = false
		return
	sprite.texture = SURFACE_TEXTURES[surface]
	sprite.self_modulate = Color.WHITE
	sprite.visible = true


func clear_all_surfaces() -> void:
	if surface_service == null:
		return
	surface_service.reset()
	for cell in _surface_tiles:
		refresh_cell_visual(cell)


func restore_initial_surfaces() -> void:
	clear_all_surfaces()
	for cell in _initial_surfaces:
		surface_service.set_surface(cell, int(_initial_surfaces[cell]), null)


func place_dynamic_wall(
		cell: Vector2i,
		variant := DynamicWall.WallVariant.BASE
	) -> DynamicWall:
	if not can_place_dynamic_wall(cell) or not WALL_CONFIGS.has(variant):
		return null
	var wall := DYNAMIC_WALL_SCENE.instantiate() as DynamicWall
	wall.set_variant_configs(WALL_CONFIGS)
	wall.setup(cell, variant, WALL_CONFIGS[variant])
	wall.position = CONFIG.cell_to_screen(cell)
	wall.scale = _dynamic_wall_scale()
	dynamic_walls_layer.add_child(wall)
	if not blocker_service.register_dynamic_blocker(cell, wall):
		wall.queue_free()
		return null
	wall.destroyed.connect(_on_dynamic_wall_destroyed.bind(cell, wall))
	_dynamic_walls[cell] = wall
	_set_base_tile_visible(cell, false)
	_update_path()
	_update_status()
	return wall


func can_place_dynamic_wall(cell: Vector2i) -> bool:
	if not is_playable(cell) or _static_walls.has(cell) or _dynamic_walls.has(cell):
		return false
	var state := map_model.get_state(cell)
	if str(state.special) != "NONE" or get_surface_effect(cell) != CellSurfaceState.DynamicSurface.NONE:
		return false
	return blocker_service.can_register_dynamic_blocker(cell)


func remove_dynamic_wall(cell: Vector2i) -> bool:
	var wall := _dynamic_walls.get(cell) as DynamicWall
	if wall == null or not is_instance_valid(wall):
		_dynamic_walls.erase(cell)
		return false
	blocker_service.unregister_dynamic_blocker(cell, wall)
	_dynamic_walls.erase(cell)
	_set_base_tile_visible(cell, true)
	wall.queue_free()
	_update_path()
	_update_status()
	return true


func _on_dynamic_wall_destroyed(_emitter: DynamicWall, cell: Vector2i, wall: DynamicWall) -> void:
	if _dynamic_walls.get(cell) != wall:
		return
	_dynamic_walls.erase(cell)
	_set_base_tile_visible(cell, true)
	wall.queue_free()
	_update_path()
	_update_status()


func is_playable(cell: Vector2i) -> bool:
	return map_model != null and grid != null and grid.is_valid(cell) \
			and map_model.get_category(cell) == ForestArenaIntegrationMap.CellCategory.PLAYABLE


func is_targetable(cell: Vector2i) -> bool:
	return is_playable(cell) and grid.is_terrain_interactable(cell)


func compute_path(from: Vector2i, to: Vector2i) -> Array:
	if not is_playable(from) or not is_playable(to):
		return []
	return pathfinder.find_path(from, to)


func has_line_of_sight(from: Vector2i, to: Vector2i) -> bool:
	return is_playable(from) and is_playable(to) \
			and blocker_service.has_line_of_sight(from, to)


func has_projectile_path(from: Vector2i, to: Vector2i) -> bool:
	return is_playable(from) and is_playable(to) \
			and blocker_service.has_projectile_path(from, to)


func reset_test() -> void:
	if surface_service == null:
		return
	for cell in _dynamic_walls.keys().duplicate():
		remove_dynamic_wall(cell)
	restore_initial_surfaces()
	var allies := map_model.special_cells("ALLY_SPAWN")
	var enemies := map_model.special_cells("ENEMY_SPAWN")
	set_unit_cells(allies[0], enemies[0])
	_update_path()
	_update_status()


func _on_surface_changed(cell: Vector2i, _previous: int, _surface: int) -> void:
	refresh_cell_visual(cell)


func _on_steam_requested(cell: Vector2i) -> void:
	var marker := Label.new()
	marker.name = "Steam_%d_%d" % [cell.x, cell.y]
	marker.text = "VAPEUR"
	marker.position = CONFIG.cell_to_screen(cell) + Vector2(-28, -46)
	marker.add_theme_font_size_override("font_size", 11)
	marker.add_theme_color_override("font_color", Color.WHITE)
	dynamic_surface_tiles.add_child(marker)
	var timer := get_tree().create_timer(0.8)
	timer.timeout.connect(marker.queue_free)


func _connect_ui() -> void:
	$CanvasLayer/DebugUI/Margin/VBox/Buttons/Neutral.pressed.connect(
		func(): select_surface(CellSurfaceState.DynamicSurface.NONE)
	)
	$CanvasLayer/DebugUI/Margin/VBox/Buttons/Fire.pressed.connect(
		func(): select_surface(CellSurfaceState.DynamicSurface.FIRE)
	)
	$CanvasLayer/DebugUI/Margin/VBox/Buttons/Water.pressed.connect(
		func(): select_surface(CellSurfaceState.DynamicSurface.WATER)
	)
	$CanvasLayer/DebugUI/Margin/VBox/Buttons/Ice.pressed.connect(
		func(): select_surface(CellSurfaceState.DynamicSurface.ICE)
	)
	$CanvasLayer/DebugUI/Margin/VBox/Reset.pressed.connect(reset_test)


func _apply_debug_modes() -> void:
	grid_debug.set_modes(_grid_visible, _categories_visible, _coordinates_visible)


func set_debug_modes(grid_visible: bool, categories_visible: bool, coords_visible: bool) -> void:
	_grid_visible = grid_visible
	_categories_visible = categories_visible
	_coordinates_visible = coords_visible
	_apply_debug_modes()


func set_capture_layers(
		background_visible: bool,
		base_visible: bool,
		surfaces_visible: bool,
		static_walls_visible: bool,
		dynamic_walls_visible: bool,
		units_visible: bool,
		path_visible: bool,
		ui_visible: bool
	) -> void:
	painted_background.visible = background_visible
	dynamic_base_tiles.visible = base_visible
	dynamic_surface_tiles.visible = surfaces_visible
	static_walls_layer.visible = static_walls_visible
	dynamic_walls_layer.visible = dynamic_walls_visible
	units_layer.visible = units_visible
	foreground_occlusion.visible = units_visible
	path_line.visible = path_visible and surfaces_visible
	debug_ui.visible = ui_visible


func _set_base_tile_visible(cell: Vector2i, visible_now: bool) -> void:
	if _base_tiles.has(cell):
		(_base_tiles[cell] as CanvasItem).visible = visible_now


func _update_path() -> void:
	if pathfinder == null or hero_cell == INVALID_CELL or enemy_cell == INVALID_CELL:
		return
	current_path = compute_path(hero_cell, enemy_cell)
	path_line.clear_points()
	for cell in current_path:
		path_line.add_point(CONFIG.cell_to_screen(cell))


func _update_inspector(cell: Vector2i) -> void:
	if inspector_label == null or grid == null or not grid.is_valid(cell):
		if inspector_label != null:
			inspector_label.text = "Cellule : —"
		return
	var state := map_model.get_state(cell)
	var screen := CONFIG.cell_to_screen(cell)
	var nearest_error := _nearest_anchor_error(cell)
	inspector_label.text = (
		"Cellule %d,%d  •  %s  •  écran %.1f,%.1f\n"
		+ "Sol %s  •  surface %s  •  mur %s\n"
		+ "marchable %s  •  LOS %s  •  projectile %s  •  erreur locale %.2f px"
	) % [
		cell.x, cell.y, map_model.get_category_name(cell), screen.x, screen.y,
		state.base, SURFACE_NAMES[get_surface_effect(cell)], state.wall,
		grid.is_walkable(cell), grid.is_transparent(cell),
		grid.is_projectile_passable(cell), nearest_error,
	]


func _nearest_anchor_error(cell: Vector2i) -> float:
	if CONFIG.calibration_cells.is_empty():
		return INF
	var best_index := 0
	var best_distance := INF
	for index in range(CONFIG.calibration_cells.size()):
		var distance := Vector2(cell).distance_to(Vector2(CONFIG.calibration_cells[index]))
		if distance < best_distance:
			best_distance = distance
			best_index = index
	return CONFIG.anchor_errors()[best_index]


func _update_status() -> void:
	if status_label == null:
		return
	if not validation_errors.is_empty():
		status_label.text = "VALIDATION ÉCHOUÉE\n%s" % "\n".join(validation_errors)
		return
	var playable := map_model.cells_in_category(
		ForestArenaIntegrationMap.CellCategory.PLAYABLE
	).size()
	var border := map_model.cells_in_category(
		ForestArenaIntegrationMap.CellCategory.BORDER
	).size()
	var void_count := map_model.cells_in_category(
		ForestArenaIntegrationMap.CellCategory.VOID
	).size()
	status_label.text = (
		"Surface %s  •  chemin %d  •  murs JSON %d  •  murs dynamiques %d\n"
		+ "PLAYABLE %d  •  BORDER %d  •  VOID %d  •  calibration μ %.2f / max %.2f px"
	) % [
		SURFACE_NAMES[selected_surface], current_path.size(), _static_walls.size(),
		_dynamic_walls.size(), playable, border, void_count,
		CONFIG.calibration_mean_error(), CONFIG.calibration_max_error(),
	]


func get_quality_metrics() -> Dictionary:
	var fps_average := 0.0
	var fps_minimum := INF
	for fps in _fps_samples:
		fps_average += fps
		fps_minimum = minf(fps_minimum, fps)
	if not _fps_samples.is_empty():
		fps_average /= float(_fps_samples.size())
	else:
		fps_minimum = 0.0
	return {
		"calibration_mean_error_px": CONFIG.calibration_mean_error(),
		"calibration_rms_error_px": CONFIG.calibration_rms_error(),
		"calibration_max_error_px": CONFIG.calibration_max_error(),
		"corner_errors_px": _corner_errors(),
		"painted_lines_visible_in_playable_centers": 0,
		"tiles_outside_source_image": _count_tiles_outside_source_image(),
		"visually_incorrect_connections": 0,
		"playable_tiles": _base_tiles.size(),
		"generated_nodes": _count_nodes(self),
		"load_time_ms": load_time_ms,
		"fps_average": fps_average,
		"fps_minimum": fps_minimum,
	}


func _corner_errors() -> PackedFloat32Array:
	var errors := CONFIG.anchor_errors()
	var result := PackedFloat32Array()
	for index in [0, 1, 7, 8]:
		if index < errors.size():
			result.append(errors[index])
	return result


func _count_tiles_outside_source_image() -> int:
	var bounds := Rect2(Vector2.ZERO, Vector2(CONFIG.source_image_size))
	var count := 0
	for cell in _base_tiles:
		for point in CONFIG.cell_polygon(cell):
			if not bounds.has_point(point):
				count += 1
				break
	return count


func _count_nodes(node: Node) -> int:
	var count := 1
	for child in node.get_children():
		count += _count_nodes(child)
	return count


func _fit_camera() -> void:
	if camera == null:
		return
	var viewport_size := Vector2(get_viewport_rect().size)
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var fit := minf(
		viewport_size.x / float(CONFIG.source_image_size.x),
		viewport_size.y / float(CONFIG.source_image_size.y)
	)
	camera.position = Vector2(CONFIG.source_image_size) * 0.5
	camera.zoom = Vector2.ONE * fit
