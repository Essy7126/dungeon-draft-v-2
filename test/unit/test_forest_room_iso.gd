extends GutTest

const PaintedGridViewScript = preload("res://battle/painted/painted_grid_view.gd")
const NEW_SCENE := "res://data/rooms/maps/painted_battle.tscn"
const CALIBRATION_SCENE := "res://battle/painted/painted_map_calibration.tscn"
const FOREST_TEXTURE := "res://asset/map/painted/room_01_forest/forest_background_v2.webp"
const FIRST_ROOM := "res://data/rooms/first_run_room_01.tres"
const FIRST_RUN := "res://data/runs/first_run.tres"


func test_round_trip_complet_de_la_grille_peinte_14_par_14() -> void:
	var room := load(FIRST_ROOM) as RoomData
	var view: PaintedGridView = PaintedGridViewScript.new()
	add_child_autofree(view)
	view.configure(room.painted_map_visual_data, room.grid_layout)
	view.setup(GridData.new(14, 14))
	for x in range(14):
		for y in range(14):
			var cell := Vector2i(x, y)
			assert_eq(view.local_to_grid(view.grid_to_local(cell)), cell)


func test_scene_de_production_charge_et_contient_les_couches_peintes() -> void:
	var packed := load(NEW_SCENE) as PackedScene
	assert_not_null(packed)
	var battle := packed.instantiate()
	assert_eq(battle.get("grid_cols"), 14)
	assert_eq(battle.get("grid_rows"), 14)
	assert_true(battle.get("temporary_iso_placeholders"))
	assert_almost_eq(battle.get("iso_unit_view_scale"), 0.58, 0.001)
	var view := battle.get_node_or_null("IsoGridView") as PaintedGridView
	assert_not_null(view)
	assert_false(view.draw_base_cells)
	assert_false(view.draw_grid_lines)
	assert_false(view.draw_cell_centers)
	assert_false(view.draw_map_bounds)
	var world := battle.get_node_or_null("YSortedWorld") as Node2D
	assert_not_null(world)
	assert_true(world.y_sort_enabled)
	for node_path in [
		"PaintedBackground/BackgroundSprite", "TerrainVisuals", "IsoGridView",
		"TerrainEffectLayer", "YSortedWorld", "PaintedForeground/ForegroundSprite",
		"VFXLayer", "CalibrationDebug", "DebugOverlay", "FloatingTextSpawner",
		"ImpactJuice", "AudioStreamPlayer",
	]:
		assert_not_null(battle.get_node_or_null(node_path), node_path)
	battle.free()


func test_laboratoire_generique_est_tool_et_expose_tous_les_switches() -> void:
	var packed := load(CALIBRATION_SCENE) as PackedScene
	assert_not_null(packed)
	var source := FileAccess.get_file_as_string(
		"res://battle/painted/painted_map_calibration.gd"
	)
	assert_true(source.begins_with("@tool"))
	for contract in [
		"show_image", "show_grid", "show_foreground", "show_terrain",
		"show_spawns", "show_coordinates", "export_capture",
	]:
		assert_true(contract in source, contract)


func test_vraie_premiere_roomdata_reference_la_nouvelle_foret() -> void:
	var run := load(FIRST_RUN) as RunData
	assert_not_null(run)
	assert_eq(run.rooms.size(), 6)
	var first_room := run.rooms[0]
	assert_eq(first_room.resource_path, FIRST_ROOM)
	assert_eq(first_room.battle_scene.resource_path, NEW_SCENE)
	assert_null(first_room.background_image)
	assert_not_null(first_room.grid_layout)
	assert_not_null(first_room.painted_map_visual_data)
	assert_eq(first_room.painted_map_visual_data.background_texture_path, FOREST_TEXTURE)
	assert_eq(first_room.enemies.map(func(enemy): return enemy.unit_id), [
		&"skeleton_melee", &"skeleton_melee", &"skeleton_ranged",
	])
	assert_eq(first_room.hero_spawn_zone, [
		Vector2i(4, 9), Vector2i(3, 10), Vector2i(4, 10),
		Vector2i(5, 10), Vector2i(3, 11), Vector2i(4, 11),
	])
	assert_eq(first_room.enemy_spawn_zone, [
		Vector2i(8, 2), Vector2i(9, 2), Vector2i(10, 2),
		Vector2i(8, 3), Vector2i(9, 3), Vector2i(10, 3),
	])


func test_layout_foret_remplit_le_griddata_commun() -> void:
	var room := load(FIRST_ROOM) as RoomData
	var grid := GridData.new(14, 14)
	room.grid_layout.apply_to_grid(grid)
	assert_eq(room.grid_layout.void_cells().size(), 32)
	assert_eq(room.grid_layout.blocked_cells().size(), 11)
	for cell in room.hero_spawn_zone + room.enemy_spawn_zone:
		assert_true(grid.is_valid(cell), "%s doit etre dans la grille" % cell)
		assert_true(grid.is_terrain_interactable(cell), "%s doit etre praticable" % cell)
	for cell in room.grid_layout.void_cells():
		assert_eq(grid.get_type(cell), GridData.CellType.HOLE)
		assert_false(grid.is_walkable(cell))


func test_overlay_transparent_reste_interactif_sans_muter_griddata() -> void:
	var room := load(FIRST_ROOM) as RoomData
	var grid := GridData.new(14, 14)
	room.grid_layout.apply_to_grid(grid)
	var view: PaintedGridView = PaintedGridViewScript.new()
	add_child_autofree(view)
	view.configure(room.painted_map_visual_data, room.grid_layout)
	view.setup(grid)
	var type_before := grid.get_type(Vector2i(6, 6))
	view.highlight([Vector2i(6, 6)], Color.RED)
	assert_eq(view.click_at(view.grid_to_local(Vector2i(6, 6))), Vector2i(6, 6))
	assert_eq(view.update_hover(view.grid_to_local(Vector2i(7, 6))), Vector2i(7, 6))
	assert_eq(view.get_selected_cell(), Vector2i(6, 6))
	assert_eq(view.get_hovered_cell(), Vector2i(7, 6))
	assert_true(view.get("_highlights").has(Vector2i(6, 6)))
	assert_eq(grid.get_type(Vector2i(6, 6)), type_before)
	assert_false(grid.has_unit(Vector2i(6, 6)))


func test_textes_flottants_n_utilisent_aucune_formule_cartesienne() -> void:
	var source := FileAccess.get_file_as_string("res://battle/floating_text_spawner.gd")
	assert_false("CELL_SIZE" in source)
	assert_false("cell.x *" in source)
	assert_true("unit_views" in source)
	assert_true("grid_to_local" in source)
