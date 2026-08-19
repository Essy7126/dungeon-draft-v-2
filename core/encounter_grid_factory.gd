@tool
class_name EncounterGridFactory
extends RefCounted

const ArenaGeneratorScript = preload("res://core/arena_generator.gd")


static func build_for_battle(
		room: RoomData,
		battle_root: Node,
		fallback_cols: int,
		fallback_rows: int
	) -> GridData:
	var size := Vector2i(maxi(1, fallback_cols), maxi(1, fallback_rows))
	if room != null and room.grid_layout != null:
		size = room.grid_layout.logical_size
	var grid := GridData.new(size.x, size.y)
	populate_base_grid(
		grid,
		room,
		battle_root.get_node_or_null("TerrainLayer") if battle_root != null else null,
		bool(battle_root.get("terrain_unpainted_defaults_to_wall")) \
			if battle_root != null else false,
	)
	return grid


static func build_from_room(room: RoomData) -> GridData:
	if room == null:
		return null
	if room.grid_layout != null:
		var size := room.grid_layout.logical_size
		var grid := GridData.new(size.x, size.y)
		populate_base_grid(grid, room, null, false)
		return grid
	if room.battle_scene == null:
		return null
	var battle_root := room.battle_scene.instantiate()
	if battle_root == null:
		return null
	var cols_value: Variant = battle_root.get("grid_cols")
	var rows_value: Variant = battle_root.get("grid_rows")
	if not cols_value is int or not rows_value is int:
		push_error(
			"La scene de bataille doit exposer grid_cols et grid_rows comme entiers."
		)
		battle_root.free()
		return null
	var fallback_cols: int = cols_value
	var fallback_rows: int = rows_value
	var grid := build_for_battle(
		room,
		battle_root,
		fallback_cols,
		fallback_rows,
	)
	battle_root.free()
	return grid


static func populate_base_grid(
		grid: GridData,
		room: RoomData,
		terrain_layer: Node,
		unpainted_defaults_to_wall: bool
	) -> void:
	if grid == null:
		return
	if room != null and room.grid_layout != null:
		room.grid_layout.apply_to_grid(grid)
		return
	if terrain_layer == null or not terrain_layer.has_method("get_used_cells"):
		return
	if unpainted_defaults_to_wall:
		for x in grid.cols:
			for y in grid.rows:
				grid.set_type(Vector2i(x, y), GridData.CellType.WALL)
	for cell_value in terrain_layer.get_used_cells():
		var cell := Vector2i(cell_value)
		if not grid.is_valid(cell):
			continue
		var tile_data = terrain_layer.get_cell_tile_data(cell_value)
		if tile_data == null:
			continue
		grid.set_type(cell, cell_type_from_string(str(
			tile_data.get_custom_data("cell_type")
		)))


static func generate_arena_layout(
		grid: GridData,
		room: RoomData,
		requested_seed: int = 0
	) -> Dictionary:
	if grid == null or room == null or room.arena_generation_profile == null:
		return {"success": false, "seed": 0, "features": {}}
	var protected_cells: Array[Vector2i] = []
	protected_cells.append_array(room.hero_spawn_zone)
	protected_cells.append_array(room.enemy_spawn_zone)
	return ArenaGeneratorScript.generate(
		grid, room.arena_generation_profile, protected_cells, requested_seed
	)


static func cell_type_from_string(type_name: String) -> GridData.CellType:
	match type_name:
		"NORMAL": return GridData.CellType.NORMAL
		"WALL": return GridData.CellType.WALL
		"HOLE": return GridData.CellType.HOLE
		"LAVA": return GridData.CellType.LAVA
		"ICE": return GridData.CellType.ICE
		"SHADOW": return GridData.CellType.SHADOW
		"RUNE": return GridData.CellType.RUNE
	return GridData.CellType.NORMAL
