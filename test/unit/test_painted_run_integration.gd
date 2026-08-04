extends GutTest

const GameManagerScript = preload("res://core/game_manager.gd")
const RUN_PATH := "res://data/runs/first_run.tres"
const RESULT_PATH := "res://ui/RunResultScreen.tscn"
const POST_COMBAT_PATH := "res://ui/post_combat/PostCombatScreen.tscn"
const PAINTED_SCENE := "res://data/rooms/maps/painted_battle.tscn"
const ROOM_PATHS := [
	"res://data/rooms/first_run_room_01.tres",
	"res://data/rooms/room_05_volcano.tres",
	"res://data/rooms/room_06_space.tres",
]
const EXPECTED_RUN := [
	"res://data/rooms/first_run_room_01.tres",
	"res://data/rooms/first_run_room_02.tres",
	"res://data/rooms/first_run_room_03.tres",
	"res://data/rooms/first_run_room_04_boss.tres",
	"res://data/rooms/room_05_volcano.tres",
	"res://data/rooms/room_06_space.tres",
]
const IMAGE_CONTRACTS := [
	{
		"source": "res://artifacts/maps/pool_map/map_foret_v2.jpg",
		"production": "res://asset/map/painted/room_01_forest/forest_background_v2.webp",
		"sha256": "d0b17944c945431ee1bf4e3394055062e8502a08ab7d654b792a2b9b3d6af098",
	},
	{
		"source": "res://artifacts/maps/pool_map/map_lave_v2.jpg",
		"production": "res://asset/map/painted/room_05_volcano/volcano_background_v2.jpg",
		"sha256": "68053a810ea874f04eb61e1fe9b1ca219e96480ebcb8ddb69599dd00435cf235",
	},
	{
		"source": "res://artifacts/maps/pool_map/map_espace.jpg",
		"production": "res://asset/map/painted/room_06_space/space_background_source.jpg",
		"sha256": "07a4990b46169a11e2cb31ebc20db710b8dc29fa2591b23e59400a03fcf63629",
	},
]


func test_pool_et_copies_de_production_sont_bit_a_bit_identiques() -> void:
	for contract in IMAGE_CONTRACTS:
		assert_true(FileAccess.file_exists(contract.source), contract.source)
		assert_true(FileAccess.file_exists(contract.production), contract.production)
		assert_eq(FileAccess.get_sha256(contract.source), contract.sha256)
		assert_eq(FileAccess.get_sha256(contract.production), contract.sha256)
		var texture := load(contract.production) as Texture2D
		assert_not_null(texture)
		assert_eq(texture.get_size(), Vector2(1376, 768))


func test_run_contient_exactement_six_salles_et_aucune_salle_sept() -> void:
	var run := load(RUN_PATH) as RunData
	assert_not_null(run)
	assert_eq(run.rooms.size(), 6)
	assert_eq(run.rooms.map(func(room): return room.resource_path), EXPECTED_RUN)
	assert_eq(run.rooms[0].painted_map_visual_data.map_id, &"room_01_forest")
	assert_eq(run.rooms[4].painted_map_visual_data.map_id, &"room_05_volcano")
	assert_eq(run.rooms[5].painted_map_visual_data.map_id, &"room_06_space")
	assert_eq(run.rooms[0].battle_scene.resource_path, PAINTED_SCENE)
	assert_eq(run.rooms[4].battle_scene.resource_path, PAINTED_SCENE)
	assert_eq(run.rooms[5].battle_scene.resource_path, PAINTED_SCENE)


func test_run_ne_charge_pas_les_trois_grandes_textures_en_tant_que_dependances() -> void:
	var run := load(RUN_PATH) as RunData
	for index in [0, 4, 5]:
		var visual := run.rooms[index].painted_map_visual_data
		assert_null(visual.background_texture)
		assert_false(visual.background_texture_path.is_empty())
		assert_true(ResourceLoader.exists(visual.background_texture_path))


func test_layouts_sont_derives_d_une_topologie_unique_sans_matrice_dupliquee() -> void:
	var rooms := _painted_rooms()
	var shared_base: RoomGridLayout = rooms[0].grid_layout.base_layout
	assert_not_null(shared_base)
	assert_eq(shared_base.layout_rows.size(), 14)
	assert_eq(shared_base.void_cells().size(), 32)
	assert_eq(shared_base.blocked_cells().size(), 11)
	assert_eq(shared_base.validation_errors(), PackedStringArray())
	for room in rooms:
		assert_same(room.grid_layout.base_layout, shared_base)
		assert_true(room.grid_layout.layout_rows.is_empty())
		assert_eq(room.grid_layout.logical_size, Vector2i(14, 14))
		assert_eq(room.grid_layout.validation_errors(), PackedStringArray())


func test_chaque_layout_remplit_le_griddata_commun_et_tous_les_spawns_sont_valides() -> void:
	for room in _painted_rooms():
		var layout: RoomGridLayout = room.grid_layout
		var grid := GridData.new(layout.logical_size.x, layout.logical_size.y)
		layout.apply_to_grid(grid)
		assert_eq(layout.walkable_cells().size(), 153, room.room_name)
		assert_eq(layout.blocked_cells().size(), 11, room.room_name)
		assert_eq(layout.void_cells().size(), 32, room.room_name)
		assert_gte(room.hero_spawn_zone.size(), 3)
		assert_false(room.enemy_spawn_zone.is_empty())
		assert_not_null(room.encounter_definition)
		for cell in room.hero_spawn_zone + room.enemy_spawn_zone:
			assert_true(grid.is_valid(cell), "%s %s" % [room.room_name, cell])
			assert_true(grid.is_terrain_interactable(cell), "%s %s" % [room.room_name, cell])
		for cell in layout.void_cells():
			assert_eq(grid.get_type(cell), GridData.CellType.HOLE)
			assert_false(grid.is_walkable(cell))
		for cell in layout.blocked_cells():
			assert_eq(grid.get_type(cell), GridData.CellType.WALL)
			assert_false(grid.is_walkable(cell))


func test_conversion_affine_round_trip_et_residus_1920_par_1080() -> void:
	for room in _painted_rooms():
		var visual: PaintedMapVisualData = room.painted_map_visual_data
		assert_eq(visual.validation_errors(), PackedStringArray())
		for y in range(visual.logical_grid_size.y):
			for x in range(visual.logical_grid_size.x):
				var cell := Vector2i(x, y)
				assert_eq(visual.image_to_cell(visual.cell_to_image(cell)), cell)
		var cover_scale := maxf(1920.0 / 1376.0, 1080.0 / 768.0)
		assert_lte(visual.calibration_rms() * cover_scale, 2.0, room.room_name)
		assert_lte(visual.calibration_max_error() * cover_scale, 4.0, room.room_name)


func test_pathfinding_reliera_les_camps_sans_traverser_void_ni_obstacle() -> void:
	for room in _painted_rooms():
		var layout: RoomGridLayout = room.grid_layout
		var grid := GridData.new(layout.logical_size.x, layout.logical_size.y)
		layout.apply_to_grid(grid)
		var pathfinder := Pathfinder.new(grid)
		var path := pathfinder.find_path(room.hero_spawn_zone[0], room.enemy_spawn_zone[0])
		assert_gt(path.size(), 1, room.room_name)
		for cell in path:
			assert_true(grid.is_terrain_interactable(cell), "%s %s" % [room.room_name, cell])
		var reachable := pathfinder.get_reachable(room.hero_spawn_zone[0], 196)
		assert_eq(reachable.size() + 1, layout.walkable_cells().size(), room.room_name)


func test_terrains_speciaux_reutilisent_les_types_existants_sans_effet_invente() -> void:
	var forest := load(ROOM_PATHS[0]) as RoomData
	var volcano := load(ROOM_PATHS[1]) as RoomData
	var space := load(ROOM_PATHS[2]) as RoomData
	assert_eq(forest.grid_layout.terrain_cell_type, -1)
	assert_true(forest.grid_layout.terrain_cells.is_empty())
	assert_eq(volcano.grid_layout.terrain_cell_type, GridData.CellType.LAVA)
	assert_eq(space.grid_layout.terrain_cell_type, GridData.CellType.ICE)
	assert_eq(volcano.grid_layout.terrain_cells.size(), 14)
	assert_eq(space.grid_layout.terrain_cells.size(), 14)
	var volcano_grid := GridData.new(14, 14)
	volcano.grid_layout.apply_to_grid(volcano_grid)
	var effects := TerrainEffects.new(volcano_grid)
	for cell in volcano.grid_layout.terrain_cells:
		assert_eq(volcano_grid.get_type(cell), GridData.CellType.LAVA)
		assert_null(volcano_grid.get_effect(cell))
	assert_not_null(effects)


func test_adaptateur_peint_n_instancie_aucun_second_griddata() -> void:
	var battle_source := FileAccess.get_file_as_string(
		"res://battle/painted/painted_battle.gd"
	)
	var view_source := FileAccess.get_file_as_string(
		"res://battle/painted/painted_grid_view.gd"
	)
	assert_false("GridData.new" in battle_source)
	assert_false("GridData.new" in view_source)
	assert_true("painted_grid_layout.apply_to_grid(grid)" in battle_source)
	assert_true("extends \"res://battle/battle.gd\"" in battle_source)


func test_victoire_finale_cible_run_result_sans_salle_sept() -> void:
	var run := load(RUN_PATH) as RunData
	var manager = GameManagerScript.new()
	manager._ready()
	manager.rooms = run.rooms.duplicate()
	manager.current_room_index = 5
	manager.run_active = true
	manager.set("_active_run_name", run.run_name)
	var requested_paths: Array[String] = []
	manager.scene_change_requested.connect(
		func(path: String): requested_paths.append(path)
	)
	manager._go_to_next_room()
	assert_eq(manager.current_room_index, 6)
	assert_null(manager.get_current_room())
	assert_false(manager.run_active)
	assert_eq(requested_paths, [RESULT_PATH])
	assert_true(manager.get_last_run_result().victory)
	manager.cleanup_run_state()
	manager._exit_tree()
	manager.free()


func test_double_signal_de_victoire_reste_protege_avant_post_combat() -> void:
	var run := load(RUN_PATH) as RunData
	var manager = GameManagerScript.new()
	manager._ready()
	manager.rooms = run.rooms.duplicate()
	manager.current_room_index = 5
	manager.run_active = true
	var requested_paths: Array[String] = []
	manager.scene_change_requested.connect(
		func(path: String): requested_paths.append(path)
	)
	manager.on_battle_won()
	manager.on_battle_won()
	assert_eq(requested_paths, [POST_COMBAT_PATH])
	manager.cleanup_run_state()
	manager._exit_tree()
	manager.free()


func _painted_rooms() -> Array[RoomData]:
	var result: Array[RoomData] = []
	for path in ROOM_PATHS:
		result.append(load(path) as RoomData)
	return result
