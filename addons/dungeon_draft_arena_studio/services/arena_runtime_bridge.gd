@tool
class_name ArenaRuntimeBridge
extends RefCounted


static func sync_runtime_resources(arena: ArenaDefinition) -> bool:
	if arena == null or arena.grid_size.x <= 0 or arena.grid_size.y <= 0:
		return false
	var layout := RoomGridLayout.new()
	layout.layout_id = arena.arena_id
	layout.debug_name = arena.display_name
	layout.logical_size = arena.grid_size
	layout.layout_rows = _build_layout_rows(arena)
	layout.cell_type_overrides = _build_type_overrides(arena)
	layout.visual_only_cells = arena.border_cells()
	arena.grid_layout = layout

	var visual := PaintedMapVisualData.new()
	visual.map_id = arena.arena_id
	visual.debug_name = arena.display_name
	visual.background_texture_path = arena.background_path
	visual.source_image_size = arena.source_image_size
	visual.logical_grid_size = arena.grid_size
	visual.grid_origin = arena.grid_origin
	visual.axis_x = arena.axis_x
	visual.axis_y = arena.axis_y
	visual.image_offset = arena.image_offset
	visual.image_scale = arena.image_scale
	visual.camera_offset = arena.camera_offset
	visual.camera_zoom = arena.camera_zoom
	visual.calibration_cells = arena.calibration_cells.duplicate()
	visual.calibration_pixels = arena.calibration_pixels.duplicate()
	if ResourceLoader.exists(arena.presentation_profile_path):
		visual.presentation_profile = load(arena.presentation_profile_path) \
			as BattlePresentationProfile
	arena.painted_map_visual_data = visual

	arena.room_name = arena.display_name
	arena.hero_spawn_zone = []
	arena.enemy_spawn_zone = []
	for spawn in arena.spawns:
		if spawn == null:
			continue
		if spawn.is_hero() and not arena.hero_spawn_zone.has(spawn.cell):
			arena.hero_spawn_zone.append(spawn.cell)
		elif spawn.is_enemy() and not arena.enemy_spawn_zone.has(spawn.cell):
			arena.enemy_spawn_zone.append(spawn.cell)
	# EncounterDefinition n'est volontairement pas @tool dans le projet. En
	# contexte editeur, Godot le charge donc comme placeholder : conserver le
	# roster importe et laisser painted_battle l'etendre au lancement reel.
	if arena.encounter_definition != null and not Engine.is_editor_hint():
		arena.enemies = arena.encounter_definition.expanded_roster()
	if arena.battle_scene == null and ResourceLoader.exists(
		ArenaDefinition.DEFAULT_BATTLE_SCENE
	):
		arena.battle_scene = load(ArenaDefinition.DEFAULT_BATTLE_SCENE) as PackedScene
	return true


static func build_grid(arena: ArenaDefinition) -> GridData:
	if not sync_runtime_resources(arena):
		return null
	var grid := GridData.new(arena.grid_size.x, arena.grid_size.y)
	arena.grid_layout.apply_to_grid(grid)
	return grid


static func build_pathfinder(arena: ArenaDefinition) -> Pathfinder:
	var grid := build_grid(arena)
	return Pathfinder.new(grid) if grid != null else null


static func runtime_signature(arena: ArenaDefinition) -> Dictionary:
	var grid := build_grid(arena)
	if grid == null:
		return {}
	var centers := {}
	var types := {}
	for y in range(arena.grid_size.y):
		for x in range(arena.grid_size.x):
			var cell := Vector2i(x, y)
			centers["%d,%d" % [x, y]] = arena.painted_map_visual_data.cell_to_image(cell)
			types["%d,%d" % [x, y]] = grid.get_type(cell)
	return {
		"size": arena.grid_size,
		"centers": centers,
		"types": types,
		"hero_spawns": arena.hero_spawn_zone.duplicate(),
		"enemy_spawns": arena.enemy_spawn_zone.duplicate(),
		"battle_scene": arena.battle_scene.resource_path if arena.battle_scene != null else "",
	}


static func _build_layout_rows(arena: ArenaDefinition) -> PackedStringArray:
	var rows := PackedStringArray()
	for y in range(arena.grid_size.y):
		var row := ""
		for x in range(arena.grid_size.x):
			var cell := Vector2i(x, y)
			var definition := arena.get_cell_definition(cell)
			var obstacle := arena.obstacle_at(cell)
			if definition == null or not definition.defined or definition.border:
				row += RoomGridLayout.VOID
			elif obstacle != null and obstacle.blocks_movement:
				row += RoomGridLayout.BLOCKED \
					if obstacle.blocks_line_of_sight else RoomGridLayout.VOID
			elif not definition.playable:
				row += RoomGridLayout.VOID
			else:
				row += RoomGridLayout.WALKABLE
		rows.append(row)
	return rows


static func _build_type_overrides(arena: ArenaDefinition) -> Dictionary:
	var overrides := {}
	for definition in arena.cells:
		if definition == null or not definition.defined or definition.border:
			continue
		var obstacle := arena.obstacle_at(definition.coordinate)
		if obstacle != null and obstacle.blocks_movement:
			overrides[definition.coordinate] = GridData.CellType.WALL \
				if obstacle.blocks_line_of_sight else GridData.CellType.HOLE
		elif not definition.playable:
			continue
		elif definition.cell_type != GridData.CellType.NORMAL:
			overrides[definition.coordinate] = definition.cell_type
	return overrides
