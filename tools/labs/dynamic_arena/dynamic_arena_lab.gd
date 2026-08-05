@tool
class_name DynamicArenaLab
extends Node2D

## Editeur dynamique document-backed. ArenaDefinition est l'autorite
## persistante ; DynamicCellState, GridData et les murs sont des caches
## d'execution reconstruits depuis la working copy.

signal document_changed(arena: ArenaDefinition, dirty: bool)
signal transfer_created(result: Dictionary)

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
const BASE_CONFIG: WallConfig = preload("res://battle/dynamic_terrain/configs/wall_base.tres")
const FIRE_CONFIG: WallConfig = preload("res://battle/dynamic_terrain/configs/wall_fire.tres")
const ICE_CONFIG: WallConfig = preload("res://battle/dynamic_terrain/configs/wall_ice.tres")

const WALL_CONFIGS := {
	DynamicWall.WallVariant.BASE: BASE_CONFIG,
	DynamicWall.WallVariant.FIRE: FIRE_CONFIG,
	DynamicWall.WallVariant.ICE: ICE_CONFIG,
}

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

const WALL_COLORS := {
	DynamicWall.WallVariant.BASE: Color("d3b69e"),
	DynamicWall.WallVariant.FIRE: Color("ff6b3b"),
	DynamicWall.WallVariant.ICE: Color("a8e8ff"),
}

const SURFACE_ELEMENTS := {
	DynamicCellState.Surface.WATER: WallInteractionResolver.WATER,
	DynamicCellState.Surface.ICE: WallInteractionResolver.ICE,
	DynamicCellState.Surface.LAVA: WallInteractionResolver.FIRE,
}

const SURFACE_TERRAIN_IDS := {
	DynamicCellState.Surface.STONE: &"stone",
	DynamicCellState.Surface.WATER: &"water",
	DynamicCellState.Surface.ICE: &"ice",
	DynamicCellState.Surface.LAVA: &"lava",
	DynamicCellState.Surface.VOID: &"void",
}

@onready var floor_layer: Node2D = $FloorLayer
@onready var surface_vfx_layer: Node2D = $SurfaceVFXLayer
@onready var y_sorted_world: Node2D = $YSortedWorld
@onready var dynamic_object_layer: Node2D = $YSortedWorld
@onready var unit_layer: Node2D = $YSortedWorld
@onready var grid_view: IsoGridView = $GridDebugLayer
@onready var camera: Camera2D = $Camera2D
@onready var path_line: Line2D = $SurfaceVFXLayer/PathLine
@onready var destination_marker: Line2D = $SurfaceVFXLayer/DestinationMarker
@onready var unit_marker: Node2D = $YSortedWorld/TestUnit

@onready var selected_state_label: Label = $CanvasLayer/Toolbar/Margin/VBox/SelectedState
@onready var hovered_label: Label = $CanvasLayer/Toolbar/Margin/VBox/Hovered
@onready var current_surface_label: Label = $CanvasLayer/Toolbar/Margin/VBox/CurrentSurface
@onready var wall_status_label: Label = $CanvasLayer/Toolbar/Margin/VBox/WallStatus
@onready var walkable_label: Label = $CanvasLayer/Toolbar/Margin/VBox/Walkable
@onready var blocking_label: Label = $CanvasLayer/Toolbar/Margin/VBox/Blocking
@onready var coordinates_label: Label = $CanvasLayer/Toolbar/Margin/VBox/Coordinates
@onready var path_length_label: Label = $CanvasLayer/Toolbar/Margin/VBox/PathLength
@onready var los_label: Label = $CanvasLayer/Toolbar/Margin/VBox/LOS
@onready var mode_label: Label = $CanvasLayer/Toolbar/Margin/VBox/Mode

var grid: GridData = null
var pathfinder: Pathfinder = null
var blocker_service: DynamicBlockerService = null
var cell_states: DynamicCellState = null
var edit_session: ArenaEditSession = null
var working_arena: ArenaDefinition:
	get:
		return edit_session.working_arena if edit_session != null else null
var document_path := ""
var dirty: bool:
	get:
		return edit_session != null and edit_session.is_dirty()
var start_cell := START_CELL
var destination_cell := DESTINATION_CELL
var hovered_cell := INVALID_CELL
var selected_surface := DynamicCellState.Surface.STONE
var selected_wall_variant := DynamicWall.WallVariant.BASE
var current_path: Array = []
var path_recalculation_count := 0
var test_unit_hp := 20

var _textures: Dictionary = {}
var _tile_sprites: Dictionary = {}
var _walls: Dictionary = {}
var _grid_debug_visible := true
var _path_visible := true
var _unit_moving := false
var _resetting := false
var _syncing_document := false
var _embedded_mode := false
var _document_controls: HBoxContainer = null
var _document_label: Label = null
var _open_dialog: FileDialog = null
var _width_spin: SpinBox = null
var _height_spin: SpinBox = null


func _ready() -> void:
	_build_document_controls()
	_load_textures()
	if edit_session == null:
		new_document(GRID_SIZE, "Nouvelle arene dynamique", "dynamic_arena")
	_rebuild_runtime_from_document()
	get_viewport().size_changed.connect(_fit_camera)
	_fit_camera()
	queue_redraw()


func bind_session(session: ArenaEditSession, embedded := true) -> bool:
	if session == null or session.working_arena == null:
		return false
	edit_session = session
	document_path = session.source_path
	_embedded_mode = embedded
	if is_node_ready():
		_rebuild_runtime_from_document()
		_refresh_document_controls()
	return true


func new_document(
		size := GRID_SIZE,
		display_name := "Nouvelle arene dynamique",
		requested_id := "dynamic_arena"
	) -> ArenaDefinition:
	var definition := ArenaDefinition.new()
	definition.set_identity(display_name, requested_id)
	definition.visual_mode = ArenaDefinition.VisualMode.MODULAR
	definition.theme_id = &"dynamic_default"
	definition.modular_visual_profile = ArenaModularVisualProfile.new()
	definition.grid_size = Vector2i(clampi(size.x, 1, 64), clampi(size.y, 1, 64))
	definition.grid_origin = Vector2(0.0, 0.0)
	definition.axis_x = Vector2(32.0, 16.0)
	definition.axis_y = Vector2(-32.0, 16.0)
	for y in range(definition.grid_size.y):
		for x in range(definition.grid_size.x):
			ArenaTerrainRegistry.configure_cell(
				definition.ensure_cell(Vector2i(x, y)), &"stone"
			)
	_add_default_spawns(definition)
	ArenaRuntimeBridge.sync_runtime_resources(definition)
	var session := ArenaEditSession.new()
	session.open(definition, "", true, "lab:%s" % Time.get_ticks_usec())
	edit_session = session
	document_path = ""
	if is_node_ready():
		_rebuild_runtime_from_document()
		document_changed.emit(working_arena, dirty)
	return working_arena


func open_document(path: String, migrate_working_copy := false) -> Dictionary:
	var source := ArenaSerializer.load_canonical(path)
	if source == null:
		return {"ok": false, "error": "arena_load_failed"}
	var inspection := ArenaSchemaMigrator.inspect(source.to_snapshot())
	if bool(inspection.requires_migration) and not migrate_working_copy:
		return {
			"ok": false,
			"requires_migration": true,
			"from_version": inspection.from_version,
			"to_version": inspection.to_version,
		}
	var session := ArenaEditSession.new()
	if not session.open(source, path, false, path):
		return {"ok": false, "error": "session_open_failed"}
	edit_session = session
	document_path = path
	if bool(inspection.requires_migration):
		var migration := ArenaSchemaMigrator.migrate_snapshot(working_arena.to_snapshot())
		if not bool(migration.ok):
			return migration
		var before := working_arena.to_snapshot()
		working_arena.restore_snapshot(migration.snapshot)
		edit_session.commit("Mettre a niveau le schema", before, working_arena.to_snapshot())
	if is_node_ready():
		_rebuild_runtime_from_document()
	document_changed.emit(working_arena, dirty)
	return {"ok": true, "arena": working_arena, "migrated": bool(inspection.requires_migration)}


func save_document(path := "") -> Error:
	if working_arena == null or edit_session.has_external_conflict():
		return ERR_BUSY
	var destination := path
	if destination.is_empty():
		destination = document_path
	if destination.is_empty():
		destination = ArenaSerializer.suggested_path(working_arena)
	var save_error := ArenaSerializer.save_canonical(working_arena, destination)
	if save_error == OK:
		document_path = destination
		edit_session.mark_saved(destination)
		_refresh_document_controls()
		document_changed.emit(working_arena, false)
	return save_error


func send_to_studio() -> Dictionary:
	if working_arena == null:
		return {"ok": false, "error": "arena_missing"}
	ArenaRuntimeBridge.sync_runtime_resources(working_arena)
	var report := ArenaValidator.validate(working_arena, false)
	var result := ArenaLabTransferService.create_transfer(working_arena, report)
	transfer_created.emit(result)
	return result


func resize_document(size: Vector2i) -> bool:
	if working_arena == null or size.x < 1 or size.y < 1 or size.x > 64 or size.y > 64:
		return false
	var before := working_arena.to_snapshot()
	working_arena.grid_size = size
	working_arena.cells = working_arena.cells.filter(func(value):
		return value != null and working_arena.is_in_bounds(value.coordinate)
	)
	working_arena.obstacles = working_arena.obstacles.filter(func(value):
		return value != null and working_arena.is_in_bounds(value.cell)
	)
	working_arena.spawns = working_arena.spawns.filter(func(value):
		return value != null and working_arena.is_in_bounds(value.cell)
	)
	for y in range(size.y):
		for x in range(size.x):
			var cell := Vector2i(x, y)
			if working_arena.get_cell_definition(cell) == null:
				ArenaTerrainRegistry.configure_cell(working_arena.ensure_cell(cell), &"stone")
	_add_default_spawns(working_arena)
	ArenaRuntimeBridge.sync_runtime_resources(working_arena)
	var changed := edit_session.commit("Redimensionner la grille", before, working_arena.to_snapshot())
	if changed:
		_rebuild_runtime_from_document()
		document_changed.emit(working_arena, dirty)
	return changed


func history_undo() -> bool:
	if edit_session == null or not edit_session.history.undo():
		return false
	_rebuild_runtime_from_document()
	document_changed.emit(working_arena, dirty)
	return true


func history_redo() -> bool:
	if edit_session == null or not edit_session.history.redo():
		return false
	_rebuild_runtime_from_document()
	document_changed.emit(working_arena, dirty)
	return true


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
				selected_surface = cell_states.cycle_surface(cell) \
					if not has_wall(cell) else selected_surface
				if has_wall(cell):
					set_cell_surface(cell, selected_surface)
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
		KEY_5:
			_select_surface(DynamicCellState.Surface.VOID, true)
		KEY_B:
			select_wall_variant(DynamicWall.WallVariant.BASE)
		KEY_F:
			select_wall_variant(DynamicWall.WallVariant.FIRE)
		KEY_I:
			select_wall_variant(DynamicWall.WallVariant.ICE)
		KEY_DELETE:
			remove_wall(hovered_cell)
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
	if working_arena == null:
		return
	var before := working_arena.to_snapshot()
	working_arena.cells.clear()
	working_arena.obstacles.clear()
	working_arena.spawns.clear()
	working_arena.objectives.clear()
	working_arena.decorations.clear()
	for y in range(working_arena.grid_size.y):
		for x in range(working_arena.grid_size.x):
			ArenaTerrainRegistry.configure_cell(
				working_arena.ensure_cell(Vector2i(x, y)), &"stone"
			)
	_add_default_spawns(working_arena)
	ArenaRuntimeBridge.sync_runtime_resources(working_arena)
	edit_session.commit("Reinitialiser le Lab", before, working_arena.to_snapshot())
	_rebuild_runtime_from_document()
	document_changed.emit(working_arena, dirty)


func set_cell_surface(cell: Vector2i, surface: int) -> bool:
	if not grid.is_valid(cell) or not DynamicCellState.Surface.values().has(surface):
		return false
	var before := _document_snapshot()
	var wall := get_wall(cell)
	var element: StringName = SURFACE_ELEMENTS.get(surface, WallInteractionResolver.NONE)
	if wall != null and element != WallInteractionResolver.NONE:
		var result := WallInteractionResolver.resolve(wall, element)
		if bool(result.handled):
			if result.action == &"steam_to_base":
				_play_interaction_vfx(cell, "VAPEUR", Color("d9f7ff"))
			elif result.action == &"thermal_shock" or result.action == &"melt":
				_play_interaction_vfx(cell, "CHOC", Color("aeeaff"))
			_update_toolbar()
			_sync_wall_document(wall)
			_commit_document_action("Transformer le mur", before)
			return true
	var changed := cell_states.set_surface(cell, surface)
	if changed:
		_commit_document_action("Peindre le terrain", before)
	return changed


func get_cell_surface(cell: Vector2i) -> int:
	return cell_states.get_surface(cell)


func is_cell_walkable(cell: Vector2i) -> bool:
	return cell_states.is_effectively_walkable(cell)


func set_start_cell(cell: Vector2i) -> bool:
	if not grid.is_valid(cell) or has_wall(cell):
		return false
	var before := _document_snapshot()
	start_cell = cell
	_sync_spawn_document(true, cell)
	_place_unit_marker(cell)
	_recalculate_path()
	_commit_document_action("Deplacer le spawn heros", before)
	return true


func set_destination(cell: Vector2i) -> bool:
	if not grid.is_valid(cell):
		return false
	var before := _document_snapshot()
	destination_cell = cell
	_sync_spawn_document(false, cell)
	_update_destination_marker()
	_recalculate_path()
	_update_toolbar()
	_commit_document_action("Deplacer le spawn ennemi", before)
	return true


func select_wall_variant(wall_variant: int) -> bool:
	if not DynamicWall.WallVariant.values().has(wall_variant):
		return false
	selected_wall_variant = wall_variant
	_update_toolbar()
	return true


func can_place_wall(cell: Vector2i) -> bool:
	if not grid.is_valid(cell) or has_wall(cell):
		return false
	if cell == start_cell or grid.has_unit(cell):
		return false
	if cell_states.get_surface(cell) == DynamicCellState.Surface.LAVA:
		return false
	return blocker_service.can_register_dynamic_blocker(cell)


## Future API Battle : cree un mur avec la configuration transmise et conserve
## l'unique GridData. Retourne null si le placement est incompatible.
func spawn_wall(cell: Vector2i, wall_config: WallConfig, source = null) -> DynamicWall:
	if wall_config == null or not can_place_wall(cell):
		return null
	var before := _document_snapshot()
	var wall_variant := _variant_for_config(wall_config)
	if wall_variant < 0:
		return null
	var wall := WallScene.instantiate() as DynamicWall
	wall.source_unit = source
	wall.setup(cell, wall_variant, wall_config)
	wall.position = _cell_position_in(y_sorted_world, cell)
	y_sorted_world.add_child(wall)
	if not blocker_service.register_dynamic_blocker(cell, wall):
		wall.free()
		return null
	_walls[cell] = wall
	_update_cell_visual(cell)
	wall.destroyed.connect(_on_wall_destroyed, CONNECT_ONE_SHOT)
	wall.hp_changed.connect(_on_wall_status_changed)
	wall.duration_changed.connect(_on_wall_duration_changed)
	wall.variant_changed.connect(_on_wall_variant_changed)
	wall.aura_damage_requested.connect(_on_wall_aura_requested)
	_sync_wall_document(wall)
	_commit_document_action("Ajouter un mur", before)
	_update_toolbar()
	return wall


func place_wall(cell: Vector2i, wall_variant: int) -> DynamicWall:
	var wall_config := WALL_CONFIGS.get(wall_variant) as WallConfig
	return spawn_wall(cell, wall_config)


func toggle_wall_at(cell: Vector2i) -> bool:
	if not grid.is_valid(cell):
		return false
	var existing := get_wall(cell)
	if existing != null:
		if existing.variant == selected_wall_variant:
			remove_wall(cell)
			return false
		return transform_wall(cell, selected_wall_variant)
	return place_wall(cell, selected_wall_variant) != null


## Future API Battle : applique les resistances et detruit de facon idempotente.
func damage_wall(cell: Vector2i, amount: int, element: StringName = &"NONE") -> int:
	var wall := get_wall(cell)
	return wall.apply_damage(amount, element) if wall != null else 0


## Future API Battle : remplacement atomique, sans retrait du bloqueur.
func transform_wall(cell: Vector2i, wall_variant: int) -> bool:
	var wall := get_wall(cell)
	var wall_config := WALL_CONFIGS.get(wall_variant) as WallConfig
	if wall == null or wall_config == null:
		return false
	var before := _document_snapshot()
	var changed := wall.change_variant(wall_variant, wall_config)
	if changed:
		_sync_wall_document(wall)
		_commit_document_action("Transformer le mur", before)
	_update_toolbar()
	return changed


## Future API Battle : retrait exact de l'objet enregistre sur la cellule.
func remove_wall(cell: Vector2i) -> bool:
	var wall := get_wall(cell)
	if wall == null:
		return false
	var before := _document_snapshot()
	var changed := wall.destroy()
	if changed:
		_remove_wall_from_document(cell)
		_commit_document_action("Retirer un mur", before)
	return changed


func apply_element_to_wall(cell: Vector2i, element: StringName) -> Dictionary:
	var wall := get_wall(cell)
	var result := WallInteractionResolver.resolve(wall, element)
	_update_toolbar()
	return result


func advance_turn() -> void:
	for wall_value in _walls.values().duplicate():
		var wall := wall_value as DynamicWall
		if is_instance_valid(wall):
			wall.advance_turn()
	_update_toolbar()


func has_wall(cell: Vector2i) -> bool:
	return get_wall(cell) != null


func get_wall(cell: Vector2i) -> DynamicWall:
	var wall := _walls.get(cell) as DynamicWall
	return wall if is_instance_valid(wall) and wall.is_blocking_state() else null


func get_wall_count() -> int:
	return _walls.size()


func has_line_of_sight(from: Vector2i, to: Vector2i) -> bool:
	return blocker_service.has_line_of_sight(from, to)


func has_projectile_path(from: Vector2i, to: Vector2i) -> bool:
	return blocker_service.has_projectile_path(from, to)


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
			_cell_position_in(y_sorted_world, travel_path[index]),
			0.13
		)
		await tween.finished
	start_cell = destination_cell
	_unit_moving = false
	_recalculate_path()
	_update_toolbar()


func is_unit_visually_behind_wall(unit_cell: Vector2i, wall_cell: Vector2i) -> bool:
	var delta := grid_view.grid_to_local(unit_cell) - grid_view.grid_to_local(wall_cell)
	return absf(delta.x) < 28.0 and delta.y < 0.0


func is_unit_visually_in_front_of_wall(unit_cell: Vector2i, wall_cell: Vector2i) -> bool:
	var delta := grid_view.grid_to_local(unit_cell) - grid_view.grid_to_local(wall_cell)
	return absf(delta.x) < 28.0 and delta.y > 0.0


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
	_sync_surface_document(cell, _surface)
	_update_cell_visual(cell)
	if walkability_changed:
		pathfinder.sync()
	_recalculate_path(false)
	_update_toolbar()


func _on_dynamic_blocker_changed(_cell: Vector2i, _blocker) -> void:
	if _resetting:
		return
	_recalculate_path(false)
	_update_toolbar()


func _on_wall_destroyed(wall: DynamicWall) -> void:
	var wall_cell := wall.get_cell()
	if _walls.get(wall_cell) == wall:
		_walls.erase(wall_cell)
	_remove_wall_from_document(wall_cell)
	_update_cell_visual(wall_cell)
	_update_toolbar()
	wall.call_deferred("queue_free")


func _on_wall_status_changed(_wall: DynamicWall, _hp: int, _max_hp: int) -> void:
	_update_toolbar()


func _on_wall_duration_changed(_wall: DynamicWall, _duration: int) -> void:
	_update_toolbar()


func _on_wall_variant_changed(
	wall: DynamicWall,
	_previous_variant: int,
	_variant: int
	) -> void:
	_sync_wall_document(wall)
	_update_toolbar()


func _on_wall_aura_requested(
	_wall: DynamicWall,
	cell: Vector2i,
	amount: int,
	_element: StringName
	) -> void:
	if grid.manhattan(cell, start_cell) == 1:
		test_unit_hp = maxi(0, test_unit_hp - amount)
		_play_interaction_vfx(start_cell, "-%d PV" % amount, Color("ff794f"))


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
	if grid == null:
		return
	for diagonal in range(grid.cols + grid.rows - 1):
		for x in range(grid.cols):
			var y := diagonal - x
			if y < 0 or y >= grid.rows:
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
	# Le mur remplace visuellement la dalle 1x1. La dalle n'est restauree
	# qu'apres le retrait exact du bloqueur dynamique.
	var surface := cell_states.get_surface(cell)
	sprite.visible = not has_wall(cell) and surface != DynamicCellState.Surface.VOID
	sprite.texture = _textures.get(surface) as Texture2D
	sprite.modulate = Color.WHITE


func _update_destination_marker() -> void:
	destination_marker.position = _cell_position_in(surface_vfx_layer, destination_cell)


func _place_unit_marker(cell: Vector2i) -> void:
	unit_marker.position = _cell_position_in(y_sorted_world, cell)


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


func _play_interaction_vfx(cell: Vector2i, text: String, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.z_index = 200
	label.position = _cell_position_in(surface_vfx_layer, cell) + Vector2(-30.0, -72.0)
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 15)
	surface_vfx_layer.add_child(label)
	var tween := create_tween()
	tween.tween_property(label, "position:y", label.position.y - 16.0, 0.75)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.75)
	tween.tween_callback(label.queue_free)


func _variant_for_config(wall_config: WallConfig) -> int:
	match wall_config.variant_id:
		&"base":
			return DynamicWall.WallVariant.BASE
		&"fire":
			return DynamicWall.WallVariant.FIRE
		&"ice":
			return DynamicWall.WallVariant.ICE
	return -1


func _wall_variant_name(wall_variant: int) -> String:
	return str(DynamicWall.VARIANT_NAMES.get(wall_variant, "UNKNOWN"))


func _update_toolbar() -> void:
	if not is_node_ready() or cell_states == null:
		return
	selected_state_label.text = "Mur [B/F/I] : %s   •   Surface [1-4] : %s" % [
		_wall_variant_name(selected_wall_variant),
		cell_states.surface_name(selected_surface),
	]
	selected_state_label.add_theme_color_override(
		"font_color", WALL_COLORS.get(selected_wall_variant, Color.WHITE)
	)
	if not grid.is_valid(hovered_cell):
		hovered_label.text = "Cellule survolee : —"
		current_surface_label.text = "Terrain de base : —"
		wall_status_label.text = "Mur : —"
		walkable_label.text = "Praticabilite : —"
		blocking_label.text = "Blocages M/LOS/P : —"
		coordinates_label.text = "Coordonnees : —"
	else:
		hovered_label.text = "Cellule survolee : (%d, %d)" % [hovered_cell.x, hovered_cell.y]
		current_surface_label.text = "Terrain de base : %s" % cell_states.get_surface_name(hovered_cell)
		var wall := get_wall(hovered_cell)
		if wall == null:
			wall_status_label.text = "Mur : AUCUN"
			blocking_label.text = "Blocages M/LOS/P : NON / NON / NON"
		else:
			var duration := "∞" if wall.remaining_turns < 0 else str(wall.remaining_turns)
			wall_status_label.text = "Mur : %s • %d/%d PV • %s tours • %s" % [
				wall.get_variant_name(), wall.hp, wall.config.max_hp, duration, wall.get_state_name()
			]
			blocking_label.text = "Blocages M/LOS/P : %s / %s / %s" % [
				"OUI" if wall.blocks_movement() else "NON",
				"OUI" if wall.blocks_line_of_sight() else "NON",
				"OUI" if wall.blocks_projectiles() else "NON",
			]
		var walkable := is_cell_walkable(hovered_cell)
		walkable_label.text = "Praticabilite effective : %s" % ("OUI" if walkable else "BLOQUEE")
		walkable_label.add_theme_color_override(
			"font_color", Color("75f0b3") if walkable else Color("ff6b72")
		)
		coordinates_label.text = "Coordonnees : Vector2i(%d, %d)" % [hovered_cell.x, hovered_cell.y]
	path_length_label.text = "Chemin courant : %d pas (%d cellules)" % [
		maxi(0, current_path.size() - 1), current_path.size()
	]
	var los_clear := blocker_service.has_line_of_sight(start_cell, destination_cell)
	var projectile_clear := blocker_service.has_projectile_path(start_cell, destination_cell)
	los_label.text = "LOS : %s   •   Projectile : %s   •   Unite : %d PV" % [
		"LIBRE" if los_clear else "BLOQUEE",
		"LIBRE" if projectile_clear else "BLOQUE",
		test_unit_hp,
	]
	mode_label.text = "Grille [G] : %s   |   Chemin [P] : %s   |   Murs : %d" % [
		"ON" if _grid_debug_visible else "OFF",
		"ON" if _path_visible else "OFF",
		_walls.size(),
	]
	_refresh_document_controls()


func place_objective(cell: Vector2i, objective_id := &"objective") -> bool:
	if working_arena == null or not working_arena.is_in_bounds(cell):
		return false
	var before := _document_snapshot()
	var existing := working_arena.objectives.filter(func(value): return value.cell == cell)
	if existing.is_empty():
		var objective := ArenaObjectiveDefinition.new()
		objective.objective_id = objective_id
		objective.cell = cell
		working_arena.objectives.append(objective)
	else:
		working_arena.objectives.erase(existing[0])
	_commit_document_action("Modifier un objectif", before)
	return true


func place_decoration_anchor(cell: Vector2i, anchor_id := &"art_anchor") -> bool:
	if working_arena == null or not working_arena.is_in_bounds(cell):
		return false
	var before := _document_snapshot()
	var existing := working_arena.decorations.filter(func(value):
		return value.cell == cell and value.visual_variant == &"art_anchor"
	)
	if existing.is_empty():
		var decoration := ArenaDecorationDefinition.new()
		decoration.decoration_id = anchor_id
		decoration.visual_variant = &"art_anchor"
		decoration.cell = cell
		working_arena.decorations.append(decoration)
	else:
		working_arena.decorations.erase(existing[0])
	_commit_document_action("Modifier une ancre de decor", before)
	return true


func set_visual_mode(mode: int) -> bool:
	if working_arena == null or mode < ArenaDefinition.VisualMode.PAINTED \
			or mode > ArenaDefinition.VisualMode.HYBRID:
		return false
	if working_arena.visual_mode == mode:
		return false
	var before := working_arena.to_snapshot()
	working_arena.visual_mode = mode
	if mode != ArenaDefinition.VisualMode.PAINTED \
			and working_arena.modular_visual_profile == null:
		working_arena.modular_visual_profile = ArenaModularVisualProfile.new()
	ArenaRuntimeBridge.sync_runtime_resources(working_arena)
	return _commit_document_action("Changer le mode visuel", before)


func _rebuild_runtime_from_document() -> void:
	if not is_node_ready() or working_arena == null:
		return
	_syncing_document = true
	_resetting = true
	_clear_runtime()
	ArenaRuntimeBridge.sync_runtime_resources(working_arena)
	grid = GridData.new(working_arena.grid_size.x, working_arena.grid_size.y)
	cell_states = CellStateScript.new()
	cell_states.configure(grid, DynamicCellState.Surface.STONE, {
		DynamicCellState.Surface.STONE: true,
		DynamicCellState.Surface.WATER: true,
		DynamicCellState.Surface.ICE: true,
		DynamicCellState.Surface.LAVA: false,
		DynamicCellState.Surface.VOID: false,
	})
	for y in range(grid.rows):
		for x in range(grid.cols):
			var cell := Vector2i(x, y)
			var definition := working_arena.get_cell_definition(cell)
			var surface := DynamicCellState.Surface.VOID \
				if definition == null or not definition.defined \
				else _surface_for_terrain(definition.terrain_id, definition.cell_type)
			cell_states.set_surface(cell, surface)
	pathfinder = Pathfinder.new(grid)
	blocker_service = DynamicBlockerService.new()
	blocker_service.configure(grid, pathfinder)
	cell_states.cell_surface_changed.connect(_on_cell_surface_changed)
	blocker_service.blocker_registered.connect(_on_dynamic_blocker_changed)
	blocker_service.blocker_unregistered.connect(_on_dynamic_blocker_changed)
	grid_view.setup(grid)
	grid_view.set_render_options(false, true, false, true)
	grid_view.set_process_unhandled_input(false)
	_build_floor()
	for obstacle in working_arena.obstacles:
		if obstacle == null or obstacle.wall_id == &"":
			continue
		var config := obstacle.wall_config
		if config == null:
			config = ArenaWallRegistry.config_for(obstacle.wall_id)
		if config != null:
			spawn_wall(obstacle.cell, config)
	var hero_spawns := working_arena.spawns.filter(func(value): return value.is_hero())
	var enemy_spawns := working_arena.spawns.filter(func(value): return value.is_enemy())
	start_cell = hero_spawns[0].cell if not hero_spawns.is_empty() else _clamped_start()
	destination_cell = enemy_spawns[0].cell if not enemy_spawns.is_empty() else _clamped_destination()
	selected_surface = DynamicCellState.Surface.STONE
	selected_wall_variant = DynamicWall.WallVariant.BASE
	hovered_cell = INVALID_CELL
	path_recalculation_count = 0
	test_unit_hp = 20
	grid_view.clear_selection()
	grid_view.clear_highlights()
	pathfinder.sync()
	_place_unit_marker(start_cell)
	_update_destination_marker()
	_syncing_document = false
	_resetting = false
	_recalculate_path(false)
	_update_toolbar()
	_fit_camera()
	queue_redraw()


func _clear_runtime() -> void:
	for wall_value in _walls.values():
		var wall := wall_value as DynamicWall
		if is_instance_valid(wall):
			wall.free()
	_walls.clear()
	if grid != null:
		grid.clear_dynamic_blockers()
	for child in floor_layer.get_children():
		child.free()
	_tile_sprites.clear()


func _surface_for_terrain(terrain_id: StringName, cell_type: int) -> int:
	for surface in SURFACE_TERRAIN_IDS:
		if SURFACE_TERRAIN_IDS[surface] == terrain_id:
			return surface
	match cell_type:
		GridData.CellType.ICE:
			return DynamicCellState.Surface.ICE
		GridData.CellType.LAVA:
			return DynamicCellState.Surface.LAVA
		GridData.CellType.HOLE:
			return DynamicCellState.Surface.VOID
	return DynamicCellState.Surface.STONE


func _sync_surface_document(cell: Vector2i, surface: int) -> void:
	if _syncing_document or working_arena == null:
		return
	var terrain_id: StringName = SURFACE_TERRAIN_IDS.get(surface, &"stone")
	var definition := working_arena.get_cell_definition(cell)
	if definition == null:
		definition = working_arena.ensure_cell(cell)
	ArenaTerrainRegistry.configure_cell(definition, terrain_id)
	ArenaRuntimeBridge.sync_runtime_resources(working_arena)


func _sync_wall_document(wall: DynamicWall) -> void:
	if _syncing_document or working_arena == null or wall == null:
		return
	var definition := working_arena.obstacle_at(wall.get_cell())
	if definition == null:
		definition = ArenaObstacleDefinition.new()
		definition.obstacle_id = &"wall_%d_%d" % [wall.get_cell().x, wall.get_cell().y]
		definition.cell = wall.get_cell()
		working_arena.obstacles.append(definition)
	definition.wall_id = ArenaWallRegistry.id_for_variant(wall.variant)
	definition.wall_config = wall.config
	definition.visual_variant = StringName(wall.get_variant_name().to_lower())
	definition.blocks_movement = wall.config.blocks_movement
	definition.blocks_line_of_sight = wall.config.blocks_line_of_sight
	definition.blocks_projectiles = wall.config.blocks_projectiles
	definition.blocks_push = true
	ArenaRuntimeBridge.sync_runtime_resources(working_arena)


func _remove_wall_from_document(cell: Vector2i) -> void:
	if _syncing_document or working_arena == null:
		return
	working_arena.obstacles = working_arena.obstacles.filter(func(value):
		return value != null and (value.cell != cell or value.wall_id == &"")
	)
	ArenaRuntimeBridge.sync_runtime_resources(working_arena)


func _sync_spawn_document(hero: bool, cell: Vector2i) -> void:
	if _syncing_document or working_arena == null:
		return
	var matches := working_arena.spawns.filter(func(value):
		return value.is_hero() if hero else value.is_enemy()
	)
	var spawn: ArenaSpawnDefinition = matches[0] if not matches.is_empty() else null
	if spawn == null:
		spawn = ArenaSpawnDefinition.new()
		spawn.kind = ArenaSpawnDefinition.Kind.HERO_1 if hero else ArenaSpawnDefinition.Kind.ENEMY
		spawn.spawn_id = &"lab_hero" if hero else &"lab_enemy"
		working_arena.spawns.append(spawn)
	spawn.cell = cell
	ArenaRuntimeBridge.sync_runtime_resources(working_arena)


func _add_default_spawns(definition: ArenaDefinition) -> void:
	var hero_spawns := definition.spawns.filter(func(value): return value.is_hero())
	if hero_spawns.is_empty():
		var hero := ArenaSpawnDefinition.new()
		hero.spawn_id = &"lab_hero"
		hero.kind = ArenaSpawnDefinition.Kind.HERO_1
		hero.unit_id = &"elf"
		hero.cell = Vector2i(
			clampi(START_CELL.x, 0, definition.grid_size.x - 1),
			clampi(START_CELL.y, 0, definition.grid_size.y - 1)
		)
		definition.spawns.append(hero)
	var enemy_spawns := definition.spawns.filter(func(value): return value.is_enemy())
	if enemy_spawns.is_empty():
		var enemy := ArenaSpawnDefinition.new()
		enemy.spawn_id = &"lab_enemy"
		enemy.kind = ArenaSpawnDefinition.Kind.ENEMY
		enemy.cell = Vector2i(
			clampi(DESTINATION_CELL.x, 0, definition.grid_size.x - 1),
			clampi(DESTINATION_CELL.y, 0, definition.grid_size.y - 1)
		)
		definition.spawns.append(enemy)


func _clamped_start() -> Vector2i:
	return Vector2i(clampi(START_CELL.x, 0, grid.cols - 1), clampi(START_CELL.y, 0, grid.rows - 1))


func _clamped_destination() -> Vector2i:
	return Vector2i(
		clampi(DESTINATION_CELL.x, 0, grid.cols - 1),
		clampi(DESTINATION_CELL.y, 0, grid.rows - 1)
	)


func _document_snapshot() -> Dictionary:
	return working_arena.to_snapshot() if working_arena != null and not _syncing_document else {}


func _commit_document_action(action_name: String, before: Dictionary) -> bool:
	if before.is_empty() or edit_session == null or working_arena == null or _syncing_document:
		return false
	ArenaRuntimeBridge.sync_runtime_resources(working_arena)
	var changed := edit_session.commit(action_name, before, working_arena.to_snapshot())
	if changed:
		_refresh_document_controls()
		document_changed.emit(working_arena, dirty)
	return changed


func _build_document_controls() -> void:
	var box := get_node_or_null("CanvasLayer/Toolbar/Margin/VBox") as VBoxContainer
	if box == null:
		return
	_document_controls = HBoxContainer.new()
	_document_controls.name = "DocumentControls"
	box.add_child(_document_controls)
	box.move_child(_document_controls, 2)
	for spec in [
		["Nouvelle", func(): new_document(Vector2i(int(_width_spin.value), int(_height_spin.value)))],
		["Ouvrir", func(): _open_dialog.popup_centered_ratio(0.72)],
		["Sauver", func(): save_document()],
		["Annuler", history_undo],
		["Retablir", history_redo],
		["Envoyer au Studio", _on_send_pressed],
	]:
		var button := Button.new()
		button.text = spec[0]
		button.pressed.connect(spec[1])
		_document_controls.add_child(button)
	_width_spin = SpinBox.new()
	_width_spin.min_value = 1
	_width_spin.max_value = 64
	_width_spin.value = GRID_SIZE.x
	_width_spin.custom_minimum_size.x = 58
	_document_controls.add_child(_width_spin)
	_height_spin = SpinBox.new()
	_height_spin.min_value = 1
	_height_spin.max_value = 64
	_height_spin.value = GRID_SIZE.y
	_height_spin.custom_minimum_size.x = 58
	_document_controls.add_child(_height_spin)
	var resize_button := Button.new()
	resize_button.text = "Redimensionner"
	resize_button.pressed.connect(func(): resize_document(
		Vector2i(int(_width_spin.value), int(_height_spin.value))
	))
	_document_controls.add_child(resize_button)
	_document_label = Label.new()
	_document_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_document_label)
	box.move_child(_document_label, 3)
	_open_dialog = FileDialog.new()
	_open_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_open_dialog.access = FileDialog.ACCESS_RESOURCES
	_open_dialog.add_filter("*.tres", "ArenaDefinition")
	_open_dialog.file_selected.connect(_on_document_selected)
	get_node("CanvasLayer").add_child(_open_dialog)


func _on_document_selected(path: String) -> void:
	var result := open_document(path, false)
	if bool(result.get("requires_migration", false)):
		_document_label.text = "Ancien schema detecte : ouvrir depuis le Studio pour choisir la migration."


func _on_send_pressed() -> void:
	var result := send_to_studio()
	_document_label.text = (
		"Transfert %s pret pour le Studio." % result.get("transfer_id", "")
		if bool(result.get("ok", false)) else
		"Echec du transfert : %s" % result.get("error", "inconnu")
	)


func _refresh_document_controls() -> void:
	if _document_label == null or working_arena == null:
		return
	_document_label.text = "%s%s • %d x %d • ArenaDefinition v%d" % [
		working_arena.display_name,
		" *" if dirty else "",
		working_arena.grid_size.x,
		working_arena.grid_size.y,
		working_arena.schema_version,
	]
	if _width_spin != null:
		_width_spin.value = working_arena.grid_size.x
	if _height_spin != null:
		_height_spin.value = working_arena.grid_size.y
	var title_node := get_node_or_null("CanvasLayer/Toolbar/Margin/VBox/Title") as Label
	if title_node != null:
		title_node.text = "DYNAMIC ARENA LAB • %d x %d" % [
			working_arena.grid_size.x, working_arena.grid_size.y
		]
