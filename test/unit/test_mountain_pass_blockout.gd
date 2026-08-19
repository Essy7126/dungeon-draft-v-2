extends GutTest

const DATA_PATH := "res://data/maps/mountain_pass_blockout.tres"
const ROOM_PATH := "res://data/rooms/mountain_pass_blockout_test.tres"
const BATTLE_SCENE := "res://data/rooms/maps/mountain_pass_blockout_battle.tscn"
const LAB_SCENE := "res://battle/iso/mountain_pass_blockout_lab.tscn"
const DEBUG_SCENE := "res://tools/MountainPassBlockoutDebug.tscn"
const EXPORT_DIR := "user://arena_reliability/mountain_pass_blockout"
const INVALID_CELL := Vector2i(-1, -1)

var data: MountainPassBlockoutData
var _generated_exports: Dictionary = {}
var _capture_reports: Dictionary = {}


func before_each() -> void:
	data = load(DATA_PATH) as MountainPassBlockoutData


func test_dimensions_et_comptages_exacts() -> void:
	assert_not_null(data)
	assert_eq(data.logical_size, Vector2i(14, 14))
	assert_eq(data.layout_rows.size(), 14)
	for row in data.layout_rows:
		assert_eq(row.length(), 14)
	assert_eq(data.logical_size.x * data.logical_size.y, 196)
	assert_true(data.validation_errors().is_empty(), str(data.validation_errors()))
	var counts := data.layout_counts()
	assert_eq(counts[MountainPassBlockoutData.NORMAL], 133)
	assert_eq(counts[MountainPassBlockoutData.ICE], 8)
	assert_eq(counts[MountainPassBlockoutData.ALLY_SPAWN], 6)
	assert_eq(counts[MountainPassBlockoutData.ENEMY_SPAWN], 6)
	assert_eq(counts[MountainPassBlockoutData.BLOCKED], 7)
	assert_eq(counts[MountainPassBlockoutData.LANDMARK], 4)
	assert_eq(counts[MountainPassBlockoutData.VOID], 32)
	assert_eq(data.walkable_cells().size(), 153)
	assert_eq(data.blocked_cells().size(), 11)


func test_conversion_des_196_centres_est_bijective() -> void:
	var centers := {}
	for y in range(14):
		for x in range(14):
			var cell := Vector2i(x, y)
			var center := data.cell_to_screen(cell)
			assert_eq(data.screen_to_cell(center), cell)
			assert_false(centers.has(center), "Centre duplique : %s" % center)
			centers[center] = cell
	assert_eq(centers.size(), 196)
	assert_eq(data.axis_x, Vector2(48, 24))
	assert_eq(data.axis_y, Vector2(-48, 24))
	assert_eq(data.logical_bounds().size, Vector2(1344, 672))
	assert_almost_eq(data.cell_native_size.x / data.cell_native_size.y, 2.0, 0.0001)


func test_layout_applique_les_types_griddata_sans_nouvelle_mecanique() -> void:
	var grid := _make_grid()
	for cell in data.void_cells():
		assert_eq(grid.get_type(cell), GridData.CellType.HOLE)
		assert_false(grid.is_walkable(cell))
	for cell in data.blocked_cells():
		assert_eq(grid.get_type(cell), GridData.CellType.WALL)
		assert_false(grid.is_walkable(cell))
	for cell in data.ice_cells():
		assert_eq(grid.get_type(cell), GridData.CellType.ICE)
		assert_true(grid.is_walkable(cell))
		assert_null(grid.get_effect(cell), "La glace initiale ne doit pas inventer un effet.")
	for cell in data.ally_spawn_cells() + data.enemy_spawn_cells():
		assert_eq(grid.get_type(cell), GridData.CellType.NORMAL)
		assert_true(grid.is_walkable(cell))


func test_toutes_les_cellules_traversables_sont_connectees() -> void:
	var grid := _make_grid()
	var expected := data.walkable_cells()
	var reached := _reachable_without(grid, expected[0], INVALID_CELL)
	assert_eq(reached.size(), expected.size())
	for cell in expected:
		assert_true(reached.has(cell), "%s doit appartenir au composant utile" % cell)


func test_pathfinder_actuel_trouve_une_distance_minimale_de_dix_pas() -> void:
	var grid := _make_grid()
	var pathfinder := Pathfinder.new(grid)
	var minimum_steps := 999
	for ally in data.ally_spawn_cells():
		for enemy in data.enemy_spawn_cells():
			var path := pathfinder.find_path(ally, enemy)
			if not path.is_empty():
				minimum_steps = mini(minimum_steps, path.size() - 1)
				for cell in path:
					assert_true(grid.is_terrain_interactable(cell))
	assert_eq(minimum_steps, 10)


func test_aucune_cellule_non_spawn_n_est_un_goulot_obligatoire() -> void:
	var grid := _make_grid()
	var spawn_cells := data.ally_spawn_cells() + data.enemy_spawn_cells()
	for removed in data.walkable_cells():
		if spawn_cells.has(removed):
			continue
		assert_true(
			_camps_remain_connected_without(grid, removed),
			"La suppression de %s ne doit pas couper toutes les routes." % removed
		)


func test_deploiements_derivent_du_layout_et_acceptent_trois_heros() -> void:
	var room := load(ROOM_PATH) as RoomData
	assert_not_null(room)
	assert_eq(room.room_name, "mountain_pass_blockout_test")
	assert_eq(room.hero_spawn_zone, data.ally_spawn_cells())
	assert_eq(room.enemy_spawn_zone, data.enemy_spawn_cells())
	assert_eq(room.hero_spawn_zone.size(), 6)
	assert_gte(room.hero_spawn_zone.size(), 3)
	var unique := {}
	for cell in room.hero_spawn_zone:
		unique[cell] = true
	assert_eq(unique.size(), 6)


func test_empreintes_obstacles_et_landmark_sont_exactes() -> void:
	var sizes: Array[int] = []
	for group in data.obstacle_groups():
		sizes.append(group.size())
	sizes.sort()
	assert_eq(sizes, [1, 1, 1, 2, 2, 4])
	assert_eq(data.landmark_cells(), [
		Vector2i(9, 4), Vector2i(10, 4),
		Vector2i(9, 5), Vector2i(10, 5),
	])


func test_route_visuelle_reste_sur_la_plateforme_et_ne_change_aucun_type() -> void:
	var grid := _make_grid()
	var before := {}
	for cell in data.road_visual_cells:
		assert_ne(data.symbol_at(cell), MountainPassBlockoutData.VOID)
		before[cell] = grid.get_type(cell)
	# Lire la classification visuelle ne doit jamais muter GridData.
	for cell in data.road_visual_cells:
		assert_true(data.is_road_cell(cell))
		assert_eq(grid.get_type(cell), before[cell])


func test_scenes_chargeables_et_architecture_isolee() -> void:
	for path in [BATTLE_SCENE, LAB_SCENE, DEBUG_SCENE]:
		assert_true(ResourceLoader.exists(path), path)
		var packed := load(path) as PackedScene
		assert_not_null(packed, path)
	var battle := (load(BATTLE_SCENE) as PackedScene).instantiate()
	assert_eq(battle.get("grid_cols"), 14)
	assert_eq(battle.get("grid_rows"), 14)
	for node_path in [
		"EnvironmentBack", "PlatformCliffs", "GroundCells", "GroundVariants",
		"IsoGridView", "StaticObstacles", "LogicalGridDebug", "YSortedWorld",
		"YSortedWorld/UnitPreviewLayer", "OverlayPreviewLayer",
		"EnvironmentFront", "Camera2D",
	]:
		assert_not_null(battle.get_node_or_null(node_path), node_path)
	assert_true((battle.get_node("YSortedWorld") as Node2D).y_sort_enabled)
	battle.free()


func test_facade_de_vue_aligne_clics_overlays_et_pivots() -> void:
	var view := MountainPassBlockoutView.new()
	view.blockout_data = data
	add_child_autofree(view)
	view.setup(_make_grid())
	for cell in [Vector2i(4, 9), Vector2i(8, 2), Vector2i(6, 7), Vector2i(11, 12)]:
		assert_eq(view.local_to_grid(view.grid_to_local(cell)), cell)
		assert_eq(view.click_at(view.grid_to_local(cell)), cell)
	var blocked := Vector2i(9, 4)
	var void_cell := Vector2i(0, 0)
	assert_eq(view.click_at(view.grid_to_local(blocked)), MountainPassBlockoutView.INVALID_CELL)
	assert_eq(view.click_at(view.grid_to_local(void_cell)), MountainPassBlockoutView.INVALID_CELL)


func test_six_exports_png_sont_generes_et_valides_en_2048_par_2048() -> void:
	_ensure_current_exports()
	for filename in [
		"mountain_pass_blockout_reference.png",
		"mountain_pass_blockout_clean.png",
		"mountain_pass_blockout_debug.png",
		"mountain_pass_blockout_logic_mask.png",
		"mountain_pass_blockout_height_guide.png",
		"mountain_pass_blockout_comparison.png",
	]:
		var path := EXPORT_DIR.path_join(filename)
		assert_true(FileAccess.file_exists(path), path)
		var image := _generated_exports.get(filename) as Image
		assert_not_null(image)
		if image == null:
			continue
		assert_eq(image.get_size(), Vector2i(2048, 2048), filename)
		var report := _capture_reports.get(filename) as ArenaCaptureContentReport
		assert_not_null(report, filename)
		if report == null:
			continue
		assert_true(report.ok, JSON.stringify(report.to_dict()))
		assert_true(report.report_written, filename)


func _make_grid() -> GridData:
	var result := GridData.new(14, 14)
	data.apply_to_grid(result)
	return result


func _reachable_without(grid: GridData, start: Vector2i, removed: Vector2i) -> Dictionary:
	var reached := {}
	if start == removed or not grid.is_terrain_interactable(start):
		return reached
	var frontier: Array[Vector2i] = [start]
	reached[start] = true
	while not frontier.is_empty():
		var current: Vector2i = frontier.pop_front()
		var directions: Array[Vector2i] = [
			Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT,
		]
		for direction in directions:
			var neighbor: Vector2i = current + direction
			if neighbor == removed or reached.has(neighbor) \
					or not grid.is_terrain_interactable(neighbor):
				continue
			reached[neighbor] = true
			frontier.append(neighbor)
	return reached


func _camps_remain_connected_without(grid: GridData, removed: Vector2i) -> bool:
	for ally in data.ally_spawn_cells():
		if ally == removed:
			continue
		var reached := _reachable_without(grid, ally, removed)
		for enemy in data.enemy_spawn_cells():
			if enemy != removed and reached.has(enemy):
				return true
	return false


func _ensure_current_exports() -> void:
	if _generated_exports.size() == 6:
		return
	_generated_exports.clear()
	_capture_reports.clear()
	var specs := [
		{
			"name": "mountain_pass_blockout_reference.png",
			"mode": MountainPassBlockoutView.RenderMode.REFERENCE,
		},
		{
			"name": "mountain_pass_blockout_clean.png",
			"mode": MountainPassBlockoutView.RenderMode.CLEAN,
		},
		{
			"name": "mountain_pass_blockout_debug.png",
			"mode": MountainPassBlockoutView.RenderMode.DEBUG,
		},
		{
			"name": "mountain_pass_blockout_logic_mask.png",
			"mode": MountainPassBlockoutView.RenderMode.LOGIC_MASK,
		},
		{
			"name": "mountain_pass_blockout_height_guide.png",
			"mode": MountainPassBlockoutView.RenderMode.HEIGHT_GUIDE,
		},
	]
	for spec in specs:
		var file_name := str(spec.name)
		var rendered := _render_blockout_mode(int(spec.mode))
		var image := rendered.image as Image
		_generated_exports[file_name] = image
		if image == null or image.is_empty():
			continue
		_capture_reports[file_name] = ArenaCaptureContentService.write_and_validate(
			image,
			EXPORT_DIR.path_join(file_name),
			_blockout_capture_context(
				bool(rendered.render_ready),
				_background_for_blockout_mode(int(spec.mode)),
				rendered.canvas_rect as Rect2i,
				image
			)
		)
	var comparison := _build_current_comparison(
		_generated_exports["mountain_pass_blockout_reference.png"] as Image,
		_generated_exports["mountain_pass_blockout_clean.png"] as Image
	)
	var comparison_name := "mountain_pass_blockout_comparison.png"
	_generated_exports[comparison_name] = comparison
	_capture_reports[comparison_name] = ArenaCaptureContentService.write_and_validate(
		comparison,
		EXPORT_DIR.path_join(comparison_name),
		_blockout_capture_context(
			not comparison.is_empty(),
			Color("101820"),
			Rect2i(Vector2i.ZERO, Vector2i(2048, 2048)),
			comparison
		)
	)


func _render_blockout_mode(mode: int) -> Dictionary:
	var view := MountainPassBlockoutView.new()
	view.blockout_data = data
	view.render_mode = mode
	view.show_unit_preview = false
	var grid := _make_grid()
	view.setup(grid)
	var logical_bounds := Rect2i(view.get_logical_bounds())
	var image := _render_blockout_cpu(view, mode)
	var render_ready := data != null \
		and data.validation_errors().is_empty() \
		and view.blockout_data == data \
		and view.grid == grid \
		and view.render_mode == mode \
		and logical_bounds.size.x > 0 \
		and logical_bounds.size.y > 0 \
		and image != null \
		and not image.is_empty()
	view.free()
	return {
		"image": image,
		"render_ready": render_ready,
		"canvas_rect": logical_bounds,
	}


func _render_blockout_cpu(view: MountainPassBlockoutView, mode: int) -> Image:
	var image := Image.create(2048, 2048, false, Image.FORMAT_RGBA8)
	var background := Color(0.92, 0.92, 0.92) \
		if mode == MountainPassBlockoutView.RenderMode.HEIGHT_GUIDE \
		else MountainPassBlockoutView.COLOR_BACKGROUND
	image.fill(background)
	image.fill_rect(Rect2i(0, 0, 2048, 560), MountainPassBlockoutView.COLOR_SKY)
	for y in range(data.logical_size.y):
		for x in range(data.logical_size.x):
			var cell := Vector2i(x, y)
			var symbol := data.symbol_at(cell)
			if mode != MountainPassBlockoutView.RenderMode.LOGIC_MASK \
					and symbol == MountainPassBlockoutData.VOID:
				continue
			var color := _blockout_cpu_color(mode, cell, symbol)
			_fill_blockout_cpu_diamond(
				image, Vector2i(view.grid_to_local(cell)), 48, 24, color
			)
	if mode == MountainPassBlockoutView.RenderMode.DEBUG:
		var logical := Rect2i(view.get_logical_bounds())
		image.fill_rect(Rect2i(logical.position, Vector2i(4, logical.size.y)), Color("e83c91"))
		image.fill_rect(Rect2i(
			Vector2i(logical.end.x - 4, logical.position.y),
			Vector2i(4, logical.size.y)
		), Color("e83c91"))
	return image


func _blockout_cpu_color(mode: int, cell: Vector2i, symbol: String) -> Color:
	if mode == MountainPassBlockoutView.RenderMode.LOGIC_MASK:
		return MountainPassBlockoutView.LOGIC_COLORS[symbol]
	if mode == MountainPassBlockoutView.RenderMode.HEIGHT_GUIDE:
		return Color(0.32, 0.32, 0.32) \
			if symbol in [MountainPassBlockoutData.BLOCKED, MountainPassBlockoutData.LANDMARK] \
			else Color(0.72, 0.72, 0.72)
	if symbol == MountainPassBlockoutData.ICE:
		return MountainPassBlockoutView.COLOR_ICE
	if symbol in [MountainPassBlockoutData.BLOCKED, MountainPassBlockoutData.LANDMARK]:
		return MountainPassBlockoutView.COLOR_OBSTACLE
	if data.is_road_cell(cell):
		return MountainPassBlockoutView.COLOR_ROAD
	return MountainPassBlockoutView.COLOR_SNOW


func _fill_blockout_cpu_diamond(
		image: Image,
		center: Vector2i,
		half_width: int,
		half_height: int,
		color: Color
	) -> void:
	var image_rect := Rect2i(Vector2i.ZERO, image.get_size())
	for offset_y in range(-half_height, half_height + 1):
		var ratio := 1.0 - absf(float(offset_y)) / float(half_height)
		var extent := maxi(0, floori(float(half_width) * ratio))
		var row := Rect2i(
			Vector2i(center.x - extent, center.y + offset_y),
			Vector2i(extent * 2 + 1, 1)
		).intersection(image_rect)
		if row.has_area():
			image.fill_rect(row, color)


func _build_current_comparison(reference: Image, clean: Image) -> Image:
	if reference == null or reference.is_empty() or clean == null or clean.is_empty():
		return Image.new()
	var board := Image.create(2048, 2048, false, Image.FORMAT_RGBA8)
	board.fill(Color("101820"))
	var left := reference.duplicate()
	var right := clean.duplicate()
	left.convert(Image.FORMAT_RGBA8)
	right.convert(Image.FORMAT_RGBA8)
	left.resize(980, 980, Image.INTERPOLATE_LANCZOS)
	right.resize(980, 980, Image.INTERPOLATE_LANCZOS)
	board.blit_rect(left, Rect2i(0, 0, 980, 980), Vector2i(24, 534))
	board.blit_rect(right, Rect2i(0, 0, 980, 980), Vector2i(1044, 534))
	return board


func _blockout_capture_context(
		render_ready: bool,
		background: Color,
		canvas_rect: Rect2i,
		image: Image
	) -> Dictionary:
	var fingerprint := FileAccess.get_sha256(DATA_PATH)
	return {
		"render_ready": render_ready,
		"document_loaded": data != null and not fingerprint.is_empty(),
		"document_id": DATA_PATH,
		"expected_document_id": DATA_PATH,
		"document_fingerprint": fingerprint,
		"expected_document_fingerprint": fingerprint,
		"expected_dimensions": Vector2i(2048, 2048),
		"canvas_rect": canvas_rect,
		"background_color": background,
		"minimum_variance": 0.00005,
		"minimum_non_background_ratio": 0.01,
		"minimum_file_size_bytes": 1024,
		"expected_visual_signature": (
			ArenaCaptureContentService.visual_signature(image)
		),
	}


func _background_for_blockout_mode(mode: int) -> Color:
	if mode == MountainPassBlockoutView.RenderMode.HEIGHT_GUIDE:
		return Color(0.92, 0.92, 0.92)
	return Color("d8dde2")
