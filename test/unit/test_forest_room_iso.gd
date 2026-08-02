extends GutTest

const IsoGridViewScript = preload("res://battle/iso/iso_grid_view.gd")
const NEW_SCENE := "res://data/rooms/maps/battle_salle1_iso.tscn"
const CALIBRATION_SCENE := "res://battle/iso/forest_map_calibration.tscn"
const BACKGROUND_SCENE := "res://battle/iso/forest_room_01_background.tscn"
const PLACEHOLDER_SCRIPT := "res://battle/iso/iso_unit_placeholder.gd"
const FOREST_TEXTURE := "res://asset/map/iso/forest_room_01_source.png"
const FIRST_ROOM := "res://data/rooms/first_run_room_01.tres"
const FIRST_RUN := "res://data/runs/first_run.tres"


func test_round_trip_complet_de_la_grille_10_par_8() -> void:
	var view: IsoGridView = IsoGridViewScript.new()
	add_child_autofree(view)
	view.setup(GridData.new(10, 8))
	assert_eq(IsoGridViewScript.FOOTPRINT, Vector2i(64, 32))
	for x in range(10):
		for y in range(8):
			var cell := Vector2i(x, y)
			assert_eq(view.local_to_grid(view.grid_to_local(cell)), cell)


func test_scene_de_production_charge_et_contient_le_contrat_iso() -> void:
	var packed := load(NEW_SCENE) as PackedScene
	assert_not_null(packed)
	var battle := packed.instantiate()
	assert_eq(battle.get("grid_cols"), 10)
	assert_eq(battle.get("grid_rows"), 8)
	assert_true(battle.get("standalone_preview_without_room"))
	assert_true(battle.get("temporary_iso_placeholders"))
	var sprite := battle.get_node_or_null("ForestBackground/ForestSprite") as Sprite2D
	assert_not_null(sprite)
	assert_eq(sprite.texture.resource_path, FOREST_TEXTURE)
	assert_almost_eq(sprite.position.x, 29.88284, 0.001)
	assert_almost_eq(sprite.position.y, 133.16354, 0.001)
	assert_almost_eq(sprite.scale.x, 0.368949, 0.00001)
	assert_almost_eq(sprite.scale.y, 0.345600, 0.00001)
	assert_almost_eq(sprite.rotation_degrees, 0.341, 0.001)
	var view := battle.get_node_or_null("IsoGridView") as IsoGridView
	assert_not_null(view)
	assert_false(view.draw_base_cells)
	assert_false(view.draw_grid_lines)
	assert_false(view.draw_cell_centers)
	assert_false(view.draw_map_bounds)
	var world := battle.get_node_or_null("YSortedWorld") as Node2D
	assert_not_null(world)
	assert_true(world.y_sort_enabled)
	assert_eq(battle.get_node("TerrainEffectLayer").get_child_count(), 0)
	for node_path in [
		"TerrainEffectLayer", "ForegroundLayer", "VFXLayer", "DebugOverlay",
		"FloatingTextSpawner", "ImpactJuice", "AudioStreamPlayer",
	]:
		assert_not_null(battle.get_node_or_null(node_path), node_path)
	battle.free()


func test_laboratoire_de_calibration_charge_avec_etat_valide() -> void:
	var packed := load(CALIBRATION_SCENE) as PackedScene
	assert_not_null(packed)
	var lab := packed.instantiate()
	assert_false(lab.get("provisional_calibration"))
	assert_not_null(lab.get_node_or_null("CalibrationOverlay"))
	assert_not_null(lab.get_node_or_null("YSortedWorld/ControlMarkers"))
	var sprite := lab.get_node("ForestBackground/ForestSprite") as Sprite2D
	assert_eq(sprite.texture.resource_path, FOREST_TEXTURE)
	lab.free()


func test_laboratoire_et_production_partagent_une_calibration_unique() -> void:
	var lab_source := FileAccess.get_file_as_string(CALIBRATION_SCENE)
	var production_source := FileAccess.get_file_as_string(NEW_SCENE)
	var background_source := FileAccess.get_file_as_string(BACKGROUND_SCENE)
	assert_true(BACKGROUND_SCENE in lab_source)
	assert_true(BACKGROUND_SCENE in production_source)
	assert_false(FOREST_TEXTURE in lab_source)
	assert_false(FOREST_TEXTURE in production_source)
	assert_true(FOREST_TEXTURE in background_source)
	assert_true("position = Vector2(29.88284, 133.16354)" in background_source)
	assert_true("scale = Vector2(0.368949, 0.3456)" in background_source)


func test_placeholders_temporaires_sont_limites_a_la_scene_iso() -> void:
	assert_true(ResourceLoader.exists(PLACEHOLDER_SCRIPT))
	var production_source := FileAccess.get_file_as_string(NEW_SCENE)
	var generic_source := FileAccess.get_file_as_string("res://battle.tscn")
	assert_true("temporary_iso_placeholders = true" in production_source)
	assert_false("temporary_iso_placeholders = true" in generic_source)
	var placeholder_source := FileAccess.get_file_as_string(PLACEHOLDER_SCRIPT)
	assert_true("temporary_iso_only" in placeholder_source)
	assert_true("Pivot au sol" in placeholder_source)
	assert_true("func get_ground_pivot()" in placeholder_source)
	assert_true("return Rect2(-15.0, -58.0, 30.0, 58.0)" in placeholder_source)


func test_vraie_premiere_roomdata_reference_la_scene_iso() -> void:
	var run = load(FIRST_RUN)
	assert_not_null(run)
	assert_gt(run.rooms.size(), 0)
	var first_room = run.rooms[0]
	assert_eq(first_room.resource_path, FIRST_ROOM)
	assert_eq(first_room.battle_scene.resource_path, NEW_SCENE)
	assert_eq(first_room.background_image.resource_path, FOREST_TEXTURE)
	assert_eq(first_room.hero_spawn_zone, [
		Vector2i(9, 7), Vector2i(8, 7), Vector2i(9, 6),
		Vector2i(7, 7), Vector2i(8, 6), Vector2i(9, 5),
	])
	assert_eq(first_room.enemy_spawn_zone, [
		Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1),
		Vector2i(2, 0), Vector2i(1, 1), Vector2i(0, 2),
	])


func test_zones_de_deploiement_sont_valides_dans_10_par_8() -> void:
	var room = load(FIRST_ROOM)
	var grid := GridData.new(10, 8)
	for cell in room.hero_spawn_zone + room.enemy_spawn_zone:
		assert_true(grid.is_valid(cell), "%s doit etre dans la grille" % cell)


func test_overlay_transparent_reste_interactif_sans_muter_griddata() -> void:
	var grid := GridData.new(10, 8)
	var view: IsoGridView = IsoGridViewScript.new()
	add_child_autofree(view)
	view.setup(grid)
	assert_true(view.draw_base_cells)
	assert_true(view.draw_grid_lines)
	assert_true(view.draw_cell_centers)
	assert_true(view.draw_map_bounds)
	view.set_render_options(false, false, false, false)
	grid.set_type(Vector2i(2, 2), GridData.CellType.WALL)
	var type_before := grid.get_type(Vector2i(2, 2))
	view.highlight([Vector2i(3, 3)], Color.RED)
	assert_eq(view.click_at(view.grid_to_local(Vector2i(4, 4))), Vector2i(4, 4))
	assert_eq(view.update_hover(view.grid_to_local(Vector2i(5, 5))), Vector2i(5, 5))
	assert_eq(view.get_selected_cell(), Vector2i(4, 4))
	assert_eq(view.get_hovered_cell(), Vector2i(5, 5))
	assert_true(view.get("_highlights").has(Vector2i(3, 3)))
	assert_eq(grid.get_type(Vector2i(2, 2)), type_before)
	assert_false(grid.has_unit(Vector2i(3, 3)))


func test_textes_flottants_n_utilisent_aucune_formule_cartesienne() -> void:
	var source := FileAccess.get_file_as_string("res://battle/floating_text_spawner.gd")
	assert_false("CELL_SIZE" in source)
	assert_false("cell.x *" in source)
	assert_true("unit_views" in source)
	assert_true("grid_to_local" in source)


func test_battle_conserve_bounds_iso_et_repli_cartesien() -> void:
	var source := FileAccess.get_file_as_string("res://battle/battle.gd")
	assert_true("get_map_bounds" in source)
	assert_true("res://battle/grid_view.gd" in source)
	assert_true("grid_cell_to_parent_local" in source)
	assert_true("face_grid_direction" in source)
