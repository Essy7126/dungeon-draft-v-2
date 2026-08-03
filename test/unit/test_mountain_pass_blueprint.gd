extends GutTest

const DATA_PATH := "res://data/maps/mountain_pass_blockout.tres"
const LAB_PATH := "res://battle/iso/mountain_pass_blockout_lab.tscn"
const OUTPUT_DIR := "res://artifacts/maps/mountain_pass_blueprint"
const EXPECTED_LAYOUT := [
	"XXXX......XXXX",
	"XX..........XX",
	"X.......EEE..X",
	"........EEE...",
	".........RR...",
	"....#....RR...",
	"..##..........",
	"......~~~.....",
	"XX...~~~~#....",
	"XX..A.~...#...",
	"...AAA..##....",
	"X..AA........X",
	"XX..........XX",
	"XXXX......XXXX",
]

var data: MountainPassBlockoutData


func before_each() -> void:
	data = load(DATA_PATH) as MountainPassBlockoutData


func test_blueprint_conserve_le_layout_autoritaire_et_les_comptages() -> void:
	assert_not_null(data)
	assert_eq(Array(data.layout_rows), EXPECTED_LAYOUT)
	var counts := data.layout_counts()
	assert_eq(counts[MountainPassBlockoutData.NORMAL], 133)
	assert_eq(counts[MountainPassBlockoutData.ICE], 8)
	assert_eq(counts[MountainPassBlockoutData.ALLY_SPAWN], 6)
	assert_eq(counts[MountainPassBlockoutData.ENEMY_SPAWN], 6)
	assert_eq(counts[MountainPassBlockoutData.BLOCKED], 7)
	assert_eq(counts[MountainPassBlockoutData.LANDMARK], 4)
	assert_eq(counts[MountainPassBlockoutData.VOID], 32)
	assert_eq(data.walkable_cells().size(), 153)


func test_calibration_16_9_projection_et_196_centres() -> void:
	var view := MountainPassBlueprintView.new()
	view.blockout_data = data
	add_child_autofree(view)
	assert_true(view.validation_errors().is_empty(), str(view.validation_errors()))
	assert_eq(view.get_pixel_size(), Vector2(1920, 1080))
	assert_eq(view.grid_origin, Vector2(960, 232))
	assert_eq(view.axis_x, Vector2(48, 24))
	assert_eq(view.axis_y, Vector2(-48, 24))
	assert_eq(view.get_cell_polygon(Vector2i.ZERO)[1].x - view.get_cell_polygon(Vector2i.ZERO)[3].x, 96.0)
	assert_eq(view.get_cell_polygon(Vector2i.ZERO)[2].y - view.get_cell_polygon(Vector2i.ZERO)[0].y, 48.0)
	assert_eq(view.get_logical_bounds(), Rect2(288, 208, 1344, 672))
	assert_almost_eq(view.get_logical_bounds().size.x / 1920.0, 0.70, 0.0001)
	var centers := {}
	for y in range(14):
		for x in range(14):
			var cell := Vector2i(x, y)
			var expected := Vector2(960, 232) + Vector2(48, 24) * x + Vector2(-48, 24) * y
			assert_eq(view.grid_to_local(cell), expected)
			assert_eq(view.local_to_grid(expected), cell)
			centers[expected] = true
	assert_eq(centers.size(), 196)


func test_les_douze_categories_graphiques_sont_declarees() -> void:
	assert_eq(MountainPassBlueprintView.GRAPHIC_CATEGORIES, [
		"DISTANT_BACKGROUND",
		"REAR_MOUNTAINS",
		"REAR_CLIFFS",
		"NON_PLAYABLE_SNOW",
		"WALKABLE_SNOW",
		"OLD_ROAD",
		"ICE",
		"BLOCKED_ROCKS",
		"RUIN",
		"VOID_RAVINES",
		"FRONT_CLIFFS",
		"FOREGROUND_OCCLUSION_GUIDE",
	])


func test_reference_exclut_les_32_faces_void_et_garde_164_cellules_plateforme() -> void:
	var view := MountainPassBlueprintView.new()
	view.blockout_data = data
	add_child_autofree(view)
	var platform_cells := view.get_reference_grid_cells()
	assert_eq(platform_cells.size(), 164)
	for cell in data.void_cells():
		assert_false(platform_cells.has(cell), str(cell))
	for cell in platform_cells:
		assert_ne(data.symbol_at(cell), MountainPassBlockoutData.VOID)
	var visual_void_count := 0
	for group in view.get_void_visual_groups():
		visual_void_count += group.size()
	assert_eq(visual_void_count, 32)


func test_toutes_les_aretes_plateforme_void_ont_une_transition_sans_face_complete() -> void:
	var view := MountainPassBlueprintView.new()
	view.blockout_data = data
	add_child_autofree(view)
	var expected := 0
	for cell in view.get_reference_grid_cells():
		for direction in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
			var neighbor: Vector2i = cell + direction
			if neighbor.x >= 0 and neighbor.y >= 0 and neighbor.x < 14 and neighbor.y < 14 \
					and data.symbol_at(neighbor) == MountainPassBlockoutData.VOID:
				expected += 1
	var edges := view.get_platform_void_edges()
	assert_eq(edges.size(), expected)
	var unique := {}
	for edge in edges:
		var platform_cell: Vector2i = edge["cell"]
		var void_cell: Vector2i = edge["void_cell"]
		assert_ne(data.symbol_at(platform_cell), MountainPassBlockoutData.VOID)
		assert_eq(data.symbol_at(void_cell), MountainPassBlockoutData.VOID)
		var key := "%s>%s" % [platform_cell, void_cell]
		assert_false(unique.has(key), key)
		unique[key] = true
		var face := view.get_cliff_transition_polygon(edge)
		assert_eq(face.size(), 4)
		assert_ne(face, view.get_cell_polygon(void_cell))
		assert_false(Geometry2D.is_point_in_polygon(view.grid_to_local(void_cell), face), key)
	assert_eq(unique.size(), expected)


func test_obstacles_visuels_sont_six_volumes_groupes_sur_les_empreintes_logiques() -> void:
	var view := MountainPassBlueprintView.new()
	view.blockout_data = data
	add_child_autofree(view)
	var sizes: Array[int] = []
	for group in view.get_obstacle_visual_groups():
		sizes.append(group.size())
	sizes.sort()
	assert_eq(sizes, [1, 1, 1, 2, 2, 4])
	assert_eq(view.get_obstacle_visual_groups().size(), 6)
	var covered := {}
	for group in view.get_obstacle_visual_groups():
		for cell in group:
			covered[cell] = true
	assert_eq(covered.size(), 11)
	for cell in data.blocked_cells():
		assert_true(covered.has(cell), str(cell))


func test_six_exports_png_sont_pixel_alignes_en_1920_par_1080() -> void:
	for filename in [
		"mountain_pass_blueprint_reference.png",
		"mountain_pass_blueprint_clean.png",
		"mountain_pass_blueprint_logic.png",
		"mountain_pass_blueprint_foreground_guide.png",
		"mountain_pass_blueprint_debug.png",
		"mountain_pass_blueprint_comparison.png",
	]:
		var path := OUTPUT_DIR.path_join(filename)
		assert_true(FileAccess.file_exists(path), path)
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		assert_not_null(image, filename)
		assert_eq(image.get_size(), Vector2i(1920, 1080), filename)


func test_logic_export_distingue_chaque_type_sans_deplacer_les_cellules() -> void:
	var path := OUTPUT_DIR.path_join("mountain_pass_blueprint_logic.png")
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	assert_not_null(image)
	for y in range(14):
		for x in range(14):
			var cell := Vector2i(x, y)
			var center := Vector2i(960, 232) + Vector2i(48, 24) * x + Vector2i(-48, 24) * y
			var sample := image.get_pixelv(center + Vector2i(8, 0))
			var expected: Color = MountainPassBlueprintView.LOGIC_COLORS[data.symbol_at(cell)]
			assert_almost_eq(sample.r, expected.r, 0.015, str(cell))
			assert_almost_eq(sample.g, expected.g, 0.015, str(cell))
			assert_almost_eq(sample.b, expected.b, 0.015, str(cell))


func test_foreground_est_transparent_et_ne_recouvre_aucune_cellule() -> void:
	var path := OUTPUT_DIR.path_join("mountain_pass_blueprint_foreground_guide.png")
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	assert_not_null(image)
	var used := image.get_used_rect()
	assert_gte(used.position.y, 895)
	assert_false(Rect2i(288, 208, 1344, 672).intersects(used))
	for y in range(14):
		for x in range(14):
			var center := Vector2i(960, 232) + Vector2i(48, 24) * x + Vector2i(-48, 24) * y
			assert_eq(image.get_pixelv(center).a, 0.0, str(Vector2i(x, y)))


func test_reference_remplit_un_environnement_bleu_gris_non_studio() -> void:
	var path := OUTPUT_DIR.path_join("mountain_pass_blueprint_reference.png")
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	assert_not_null(image)
	var sky := image.get_pixel(8, 8)
	assert_gt(sky.b, sky.r)
	assert_gt(sky.g, sky.r)
	assert_gt(sky.r, 0.75)
	assert_ne(sky, Color("d8dde2"))


func test_laboratoire_separe_fond_grille_overlays_unites_et_foreground() -> void:
	var packed := load(LAB_PATH) as PackedScene
	assert_not_null(packed)
	var lab := packed.instantiate()
	for node_path in [
		"BlueprintBackground",
		"IsoGridView",
		"StaticObstacles",
		"LogicalGridDebug",
		"UnitPreviewLayer",
		"OverlayPreviewLayer",
		"TerrainEffectLayer",
		"ForegroundGuide",
		"VFXLayer",
		"Camera2D",
	]:
		assert_not_null(lab.get_node_or_null(node_path), node_path)
	assert_true(lab.get_node("BlueprintBackground") is Sprite2D)
	assert_true(lab.get_node("IsoGridView") is MountainPassBlueprintView)
	assert_true(lab.get_node("ForegroundGuide") is Sprite2D)
	assert_false((lab.get_node("ForegroundGuide") as Sprite2D).visible)
	lab.free()
