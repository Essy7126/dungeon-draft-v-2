extends GutTest

const DATA_PATH := "res://data/maps/mountain_pass_blockout.tres"
const ROOM_PATH := "res://data/rooms/mountain_pass_blockout_test.tres"
const BATTLE_SCENE := "res://data/rooms/maps/mountain_pass_blockout_battle.tscn"
const LAB_SCENE := "res://battle/iso/mountain_pass_blockout_lab.tscn"
const DEBUG_SCENE := "res://tools/MountainPassBlockoutDebug.tscn"
const EXPORT_DIR := "res://artifacts/maps/mountain_pass_blockout"
const INVALID := Vector2i(-1,-1)

var data: MountainPassBlockoutData

func before_each() -> void:data=load(DATA_PATH) as MountainPassBlockoutData

func test_dimensions_et_comptages_exacts() -> void:
	assert_not_null(data);assert_eq(data.logical_size,Vector2i(14,14));assert_eq(data.layout_rows.size(),14)
	for row in data.layout_rows:assert_eq(row.length(),14)
	assert_true(data.validation_errors().is_empty(),str(data.validation_errors()))
	var counts:=data.layout_counts()
	assert_eq(counts[MountainPassBlockoutData.NORMAL],133);assert_eq(counts[MountainPassBlockoutData.ICE],8)
	assert_eq(counts[MountainPassBlockoutData.ALLY_SPAWN],6);assert_eq(counts[MountainPassBlockoutData.ENEMY_SPAWN],6)
	assert_eq(counts[MountainPassBlockoutData.BLOCKED],7);assert_eq(counts[MountainPassBlockoutData.LANDMARK],4);assert_eq(counts[MountainPassBlockoutData.VOID],32)
	assert_eq(data.walkable_cells().size(),153);assert_eq(data.blocked_cells().size(),11)

func test_conversion_des_196_centres_est_bijective() -> void:
	var centers: Dictionary={}
	for y in range(14):
		for x in range(14):
			var cell:=Vector2i(x,y);var center:=data.cell_to_screen(cell)
			assert_eq(data.screen_to_cell(center),cell);assert_false(centers.has(center));centers[center]=cell
	assert_eq(centers.size(),196);assert_eq(data.axis_x,Vector2(48,24));assert_eq(data.axis_y,Vector2(-48,24))
	assert_eq(data.logical_bounds().size,Vector2(1344,672));assert_almost_eq(data.cell_native_size.x/data.cell_native_size.y,2.0,0.0001)

func test_types_griddata_ice_et_vides() -> void:
	var grid:=_grid()
	for cell in data.void_cells():assert_eq(grid.get_type(cell),GridData.CellType.HOLE);assert_false(grid.is_walkable(cell))
	for cell in data.blocked_cells():assert_eq(grid.get_type(cell),GridData.CellType.WALL);assert_false(grid.is_walkable(cell))
	for cell in data.ice_cells():assert_eq(grid.get_type(cell),GridData.CellType.ICE);assert_true(grid.is_walkable(cell));assert_null(grid.get_effect(cell))
	for cell in data.ally_spawn_cells()+data.enemy_spawn_cells():assert_true(grid.is_walkable(cell))

func test_connectivite_et_distance_pathfinder_dix() -> void:
	var grid:=_grid();var reached:=_reachable(grid,data.walkable_cells()[0],INVALID)
	assert_eq(reached.size(),153)
	var pathfinder:=Pathfinder.new(grid);var minimum:=999
	for ally in data.ally_spawn_cells():
		for enemy in data.enemy_spawn_cells():
			var path:=pathfinder.find_path(ally,enemy)
			if not path.is_empty():minimum=mini(minimum,path.size()-1)
	assert_eq(minimum,10)

func test_aucune_case_non_spawn_n_est_un_goulot_obligatoire() -> void:
	var grid:=_grid();var spawns:=data.ally_spawn_cells()+data.enemy_spawn_cells()
	for removed in data.walkable_cells():
		if spawns.has(removed):continue
		assert_true(_camps_connected(grid,removed),"Goulot inattendu: %s"%removed)

func test_deploiement_et_empreintes_derivent_du_layout() -> void:
	var room:=load(ROOM_PATH) as RoomData
	assert_not_null(room);assert_eq(room.room_name,"mountain_pass_blockout_test")
	assert_eq(room.hero_spawn_zone,data.ally_spawn_cells());assert_eq(room.enemy_spawn_zone,data.enemy_spawn_cells());assert_gte(room.hero_spawn_zone.size(),3)
	var sizes: Array[int]=[]
	for group in data.obstacle_groups():sizes.append(group.size())
	sizes.sort();assert_eq(sizes,[1,1,1,2,2,4])
	assert_eq(data.landmark_cells(),[Vector2i(9,4),Vector2i(10,4),Vector2i(9,5),Vector2i(10,5)])

func test_route_visuelle_ne_mute_pas_le_gameplay() -> void:
	var grid:=_grid();var before: Dictionary={}
	for cell in data.road_visual_cells:assert_ne(data.symbol_at(cell),MountainPassBlockoutData.VOID);before[cell]=grid.get_type(cell)
	for cell in data.road_visual_cells:assert_true(data.is_road_cell(cell));assert_eq(grid.get_type(cell),before[cell])

func test_scenes_et_facade_iso_chargeables() -> void:
	for path in [BATTLE_SCENE,LAB_SCENE,DEBUG_SCENE]:assert_true(ResourceLoader.exists(path));assert_not_null(load(path) as PackedScene)
	var battle: Node=(load(BATTLE_SCENE) as PackedScene).instantiate()
	assert_eq(battle.get("grid_cols"),14);assert_eq(battle.get("grid_rows"),14)
	for node_path in ["EnvironmentBack","PlatformCliffs","GroundCells","GroundVariants","IsoGridView","StaticObstacles","LogicalGridDebug","YSortedWorld","YSortedWorld/UnitPreviewLayer","OverlayPreviewLayer","EnvironmentFront","Camera2D"]:assert_not_null(battle.get_node_or_null(node_path),node_path)
	assert_true((battle.get_node("YSortedWorld") as Node2D).y_sort_enabled);battle.free()
	var view:=MountainPassBlockoutView.new();view.blockout_data=data;add_child_autofree(view);view.setup(_grid())
	for cell in [Vector2i(4,9),Vector2i(8,2),Vector2i(6,7),Vector2i(12,12)]:assert_eq(view.local_to_grid(view.grid_to_local(cell)),cell);assert_eq(view.click_at(view.grid_to_local(cell)),cell)
	assert_eq(view.click_at(view.grid_to_local(Vector2i(9,4))),MountainPassBlockoutView.INVALID_CELL)
	assert_eq(view.click_at(view.grid_to_local(Vector2i(0,0))),MountainPassBlockoutView.INVALID_CELL)

func test_six_exports_font_exactement_2048() -> void:
	for filename in ["mountain_pass_blockout_reference.png","mountain_pass_blockout_clean.png","mountain_pass_blockout_debug.png","mountain_pass_blockout_logic_mask.png","mountain_pass_blockout_height_guide.png","mountain_pass_blockout_comparison.png"]:
		var path:=EXPORT_DIR.path_join(filename);assert_true(FileAccess.file_exists(path),path)
		var image:=Image.load_from_file(ProjectSettings.globalize_path(path));assert_not_null(image);assert_eq(image.get_size(),Vector2i(2048,2048),filename)

func _grid() -> GridData:
	var result:=GridData.new(14,14);data.apply_to_grid(result);return result

func _reachable(grid: GridData,start: Vector2i,removed: Vector2i) -> Dictionary:
	var reached: Dictionary={};var frontier: Array[Vector2i]=[start];reached[start]=true
	while not frontier.is_empty():
		var current: Vector2i=frontier.pop_front()
		for direction in [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]:
			var neighbor: Vector2i=current+direction
			if neighbor==removed or reached.has(neighbor) or not grid.is_terrain_interactable(neighbor):continue
			reached[neighbor]=true;frontier.append(neighbor)
	return reached

func _camps_connected(grid: GridData,removed: Vector2i) -> bool:
	for ally in data.ally_spawn_cells():
		var reached:=_reachable(grid,ally,removed)
		for enemy in data.enemy_spawn_cells():
			if reached.has(enemy):return true
	return false
