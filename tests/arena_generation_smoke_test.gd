extends SceneTree

const ROOM_PATH := "res://data/rooms/first_run_room_02b_plateau.tres"


func _initialize() -> void:
	var room := load(ROOM_PATH) as RoomData
	if room == null or room.battle_scene == null:
		quit(1)
		return
	if room.arena_generation_profile == null \
			or room.arena_visual_profile == null:
		quit(1)
		return

	for test_seed in range(1, 21):
		if not _verify_seed(room, test_seed):
			quit(1)
			return
	quit(0)


func _verify_seed(room: RoomData, test_seed: int) -> bool:
	var battle = room.battle_scene.instantiate()
	battle.room_data = room
	battle.grid = GridData.new(battle.grid_cols, battle.grid_rows)
	battle._import_terrain_from_tilemap()

	room.arena_generation_profile.use_test_seed = true
	room.arena_generation_profile.test_seed = test_seed
	battle._generate_arena_layout()
	var features: Dictionary = battle._generated_arena_features
	if features.size() < room.arena_generation_profile.minimum_obstacle_count \
			or features.size() > room.arena_generation_profile.maximum_obstacle_count:
		battle.free()
		return false

	var protected_cells: Array[Vector2i] = []
	protected_cells.append_array(room.hero_spawn_zone)
	protected_cells.append_array(room.enemy_spawn_zone)
	for cell in features:
		if battle.grid.get_type(cell) != features[cell]:
			battle.free()
			return false
		for protected_cell in protected_cells:
			if battle.grid.manhattan(cell, protected_cell) \
					<= room.arena_generation_profile.spawn_safety_distance:
				battle.free()
				return false

	battle._setup_view()
	var feature_parent: Node2D = battle._unit_view_parent
	var previous_child_count: int = feature_parent.get_child_count()
	battle._setup_arena_visuals()
	var rendered_count: int = feature_parent.get_child_count() - previous_child_count
	var expected_rendered_count := 0
	for x in range(battle.grid.cols):
		for y in range(battle.grid.rows):
			var cell := Vector2i(x, y)
			if features.has(cell) \
					or battle.grid.get_type(cell) == GridData.CellType.NORMAL:
				expected_rendered_count += 1
	var valid: bool = rendered_count == expected_rendered_count
	if valid:
		var spawn_cell: Vector2i = room.hero_spawn_zone[0]
		var spawn_local: Vector2 = battle.grid_view.grid_to_local(spawn_cell)
		valid = battle.grid_view._valid_cell_at(spawn_local) == spawn_cell
	if valid and test_seed == 1:
		valid = _verify_live_geometry_follow(battle, features)
	battle.free()
	return valid


func _verify_live_geometry_follow(battle, features: Dictionary) -> bool:
	var first_cell: Vector2i = features.keys()[0]
	var renderer = battle._arena_feature_renderer
	var root: Node2D = renderer._feature_roots[first_cell]
	var sprite := root.get_node("Visual") as Sprite2D
	var previous_transform: Transform2D = sprite.transform
	var terrain := battle.get_node("TerrainLayer") as TileMapLayer
	terrain.position += Vector2(17.0, -9.0)
	terrain.scale *= Vector2(1.08, 0.93)
	terrain.skew += 0.08
	renderer._process(0.0)
	if sprite.transform.is_equal_approx(previous_transform):
		return false
	var expected_center: Vector2 = battle._unit_view_parent.to_local(
		battle.grid_view.to_global(battle.grid_view.grid_to_local(first_cell))
	)
	return root.position.is_equal_approx(expected_center)
