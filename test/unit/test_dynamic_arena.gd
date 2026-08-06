extends GutTest

const CellStateScript := preload("res://tools/labs/dynamic_arena/dynamic_cell_state.gd")
const LabScene := preload("res://tools/labs/dynamic_arena/DynamicArenaLab.tscn")
const WallScene := preload("res://tools/labs/dynamic_arena/DynamicWall.tscn")
const NORMALIZED_DIR := "res://tools/labs/dynamic_arena/assets/normalized"
const WALL_FILES := ["wall_base.png", "wall_fire.png", "wall_ice.png"]
const WALL_CANVAS := Vector2i(512, 704)
const WALL_BOUNDS := Rect2i(32, 32, 448, 640)
const WALL_PIVOT := Vector2i(256, 672)
const CAPTURE_DIR := "res://artifacts/labs/dynamic_arena/walls_final"
const CAPTURE_FILES := [
	"wall_assets_normalized.png", "wall_base.png", "wall_fire.png", "wall_ice.png",
	"wall_cycle.png", "wall_hp_damage.png", "wall_destroyed.png",
	"fire_water_interaction.png", "fire_ice_interaction.png",
	"path_before_wall.png", "path_blocked.png", "path_restored.png",
	"los_blocked.png", "unit_behind_wall.png", "unit_in_front_wall.png",
	"final_dynamic_arena.png",
]


class BlockerFixture:
	extends RefCounted
	var movement := true
	var los := true
	var projectile := true

	func blocks_movement() -> bool:
		return movement

	func blocks_line_of_sight() -> bool:
		return los

	func blocks_projectiles() -> bool:
		return projectile


func test_three_normalized_wall_assets_share_canvas_bbox_and_alpha() -> void:
	for file_name in WALL_FILES:
		var image := _load_wall_png(file_name)
		assert_false(image.is_empty(), file_name)
		assert_eq(image.get_size(), WALL_CANVAS, file_name)
		assert_eq(image.get_format(), Image.FORMAT_RGBA8, file_name)
		assert_eq(_alpha_bounds(image), WALL_BOUNDS, file_name)
		assert_eq(image.get_pixel(0, 0).a, 0.0, file_name)


func test_all_sixteen_final_capture_files_are_present_and_non_empty() -> void:
	for file_name in CAPTURE_FILES:
		var path := CAPTURE_DIR.path_join(file_name)
		assert_true(FileAccess.file_exists(path), file_name)
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		assert_false(image.is_empty(), file_name)
		assert_gte(image.get_width(), 1200, file_name)
		assert_gte(image.get_height(), 896, file_name)


func test_wall_scene_uses_one_shared_bottom_center_pivot() -> void:
	var wall := WallScene.instantiate() as DynamicWall
	add_child_autofree(wall)
	var sprite := wall.get_node("VisualRoot/Sprite2D") as Sprite2D
	assert_false(sprite.centered)
	assert_eq(sprite.position, -Vector2(WALL_PIVOT) * sprite.scale + Vector2(0, 16))
	var useful_display_size := Vector2(WALL_BOUNDS.size) * sprite.scale
	assert_lte(useful_display_size.x, 64.0)
	assert_gte(useful_display_size.y, 100.0)
	var footprint := wall.get_node("ContactShadow") as Polygon2D
	assert_eq(
		footprint.polygon,
		PackedVector2Array([Vector2(0, -16), Vector2(32, 0), Vector2(0, 16), Vector2(-32, 0)])
	)
	assert_not_null(wall.get_node_or_null("HealthIndicator"))
	assert_not_null(wall.get_node_or_null("AnimationPlayer"))
	assert_not_null(wall.get_node_or_null("VFXAnchor"))
	assert_not_null(wall.get_node_or_null("OcclusionArea"))


func test_three_lab_configs_match_the_requested_temporary_rules() -> void:
	var base := DynamicArenaLab.BASE_CONFIG
	var fire := DynamicArenaLab.FIRE_CONFIG
	var ice := DynamicArenaLab.ICE_CONFIG
	assert_eq(base.max_hp, 30)
	assert_eq(base.duration_turns, 5)
	assert_eq(base.damage_on_adjacent_turn, 0)
	assert_eq(fire.max_hp, 24)
	assert_eq(fire.duration_turns, 3)
	assert_eq(fire.damage_on_adjacent_turn, 2)
	assert_true(fire.vulnerable_to.has(&"WATER"))
	assert_true(fire.vulnerable_to.has(&"ICE"))
	assert_eq(ice.max_hp, 20)
	assert_eq(ice.duration_turns, 3)
	assert_true(ice.vulnerable_to.has(&"FIRE"))
	assert_true(ice.resistant_to.has(&"WATER"))
	for config in [base, fire, ice]:
		assert_eq(config.validation_errors(), PackedStringArray())
		assert_true(config.blocks_movement)
		assert_true(config.blocks_line_of_sight)
		assert_true(config.blocks_projectiles)


func test_griddata_dynamic_blocker_is_an_overlay_not_a_cell_type_replacement() -> void:
	var grid := GridData.new(3, 1)
	grid.set_type(Vector2i(1, 0), GridData.CellType.ICE)
	var blocker := BlockerFixture.new()
	assert_true(grid.register_dynamic_blocker(Vector2i(1, 0), blocker))
	assert_eq(grid.get_type(Vector2i(1, 0)), GridData.CellType.ICE)
	assert_false(grid.is_walkable(Vector2i(1, 0)))
	assert_false(grid.is_transparent(Vector2i(1, 0)))
	assert_false(grid.is_projectile_passable(Vector2i(1, 0)))
	assert_true(grid.unregister_dynamic_blocker(Vector2i(1, 0), blocker))
	assert_eq(grid.get_type(Vector2i(1, 0)), GridData.CellType.ICE)
	assert_true(grid.is_walkable(Vector2i(1, 0)))


func test_dynamic_blocker_service_refreshes_the_existing_pathfinder() -> void:
	var grid := GridData.new(3, 1)
	var pathfinder := Pathfinder.new(grid)
	var service := DynamicBlockerService.new()
	service.configure(grid, pathfinder)
	var blocker := BlockerFixture.new()
	assert_eq(pathfinder.find_path(Vector2i(0, 0), Vector2i(2, 0)).size(), 3)
	assert_true(service.register_dynamic_blocker(Vector2i(1, 0), blocker))
	assert_eq(pathfinder.find_path(Vector2i(0, 0), Vector2i(2, 0), null, false), [])
	assert_false(service.has_line_of_sight(Vector2i(0, 0), Vector2i(2, 0)))
	assert_false(service.has_projectile_path(Vector2i(0, 0), Vector2i(2, 0)))
	assert_true(service.unregister_dynamic_blocker(Vector2i(1, 0), blocker))
	assert_eq(pathfinder.find_path(Vector2i(0, 0), Vector2i(2, 0), null, false).size(), 3)
	assert_true(service.has_line_of_sight(Vector2i(0, 0), Vector2i(2, 0)))
	assert_true(service.has_projectile_path(Vector2i(0, 0), Vector2i(2, 0)))


func test_lab_uses_one_grid_and_one_shared_y_sorted_world() -> void:
	var lab := _new_lab()
	for path in [
		"FloorLayer", "SurfaceVFXLayer", "YSortedWorld",
		"GridDebugLayer", "Camera2D", "CanvasLayer/Toolbar",
	]:
		assert_not_null(lab.get_node_or_null(path), path)
	assert_true((lab.get_node("YSortedWorld") as Node2D).y_sort_enabled)
	assert_eq(lab.get_node("YSortedWorld/TestUnit").get_parent(), lab.get_node("YSortedWorld"))
	assert_eq(lab.grid.cols, 8)
	assert_eq(lab.grid.rows, 8)
	assert_eq(lab.get_node("FloorLayer").get_child_count(), 64)


func test_valid_placement_and_all_requested_rejections() -> void:
	var lab := _new_lab()
	assert_not_null(lab.place_wall(Vector2i(3, 3), DynamicWall.WallVariant.BASE))
	assert_true(lab.has_wall(Vector2i(3, 3)))
	assert_true(
		(lab._tile_sprites[Vector2i(3, 3)] as Sprite2D).visible,
		"Le mur se superpose a la dalle au lieu de supprimer le sol."
	)
	assert_null(lab.place_wall(Vector2i(-1, 0), DynamicWall.WallVariant.BASE))
	assert_null(lab.place_wall(lab.start_cell, DynamicWall.WallVariant.BASE), "unite")
	lab.grid.set_type(Vector2i(0, 0), GridData.CellType.HOLE)
	assert_null(lab.place_wall(Vector2i(0, 0), DynamicWall.WallVariant.BASE), "VOID")
	lab.grid.set_type(Vector2i(0, 1), GridData.CellType.WALL)
	assert_null(lab.place_wall(Vector2i(0, 1), DynamicWall.WallVariant.BASE), "obstacle")
	lab.cell_states.set_surface(Vector2i(0, 2), DynamicCellState.Surface.LAVA)
	assert_null(lab.place_wall(Vector2i(0, 2), DynamicWall.WallVariant.FIRE), "LAVA")


func test_variant_replacement_is_atomic_and_never_duplicates_the_wall() -> void:
	var lab := _new_lab()
	var cell := Vector2i(3, 3)
	var wall := lab.place_wall(cell, DynamicWall.WallVariant.BASE)
	assert_not_null(wall)
	var refresh_before := lab.blocker_service.refresh_count
	assert_true(lab.transform_wall(cell, DynamicWall.WallVariant.FIRE))
	assert_eq(lab.get_wall(cell), wall)
	assert_eq(wall.variant, DynamicWall.WallVariant.FIRE)
	assert_eq(lab.get_wall_count(), 1)
	assert_eq(lab.grid.get_dynamic_blockers(cell).size(), 1)
	assert_eq(lab.blocker_service.refresh_count, refresh_before)
	assert_true(lab.transform_wall(cell, DynamicWall.WallVariant.ICE))
	assert_eq(lab.get_wall(cell), wall)
	assert_eq(lab.get_wall_count(), 1)


func test_ctrl_click_contract_same_variant_removes_different_variant_replaces() -> void:
	var lab := _new_lab()
	var cell := Vector2i(3, 3)
	lab.select_wall_variant(DynamicWall.WallVariant.BASE)
	assert_true(lab.toggle_wall_at(cell))
	lab.select_wall_variant(DynamicWall.WallVariant.FIRE)
	assert_true(lab.toggle_wall_at(cell))
	assert_eq(lab.get_wall(cell).variant, DynamicWall.WallVariant.FIRE)
	assert_false(lab.toggle_wall_at(cell))
	assert_false(lab.has_wall(cell))


func test_path_detours_then_is_restored_after_wall_removal() -> void:
	var lab := _new_lab()
	lab.set_start_cell(Vector2i(0, 3))
	lab.set_destination(Vector2i(7, 3))
	var direct := lab.get_current_path()
	assert_eq(direct.size(), 8)
	assert_not_null(lab.place_wall(Vector2i(4, 3), DynamicWall.WallVariant.BASE))
	var detour := lab.get_current_path()
	assert_gt(detour.size(), direct.size())
	assert_false(detour.has(Vector2i(4, 3)))
	assert_true(lab.remove_wall(Vector2i(4, 3)))
	assert_eq(lab.get_current_path().size(), 8)
	assert_true((lab._tile_sprites[Vector2i(4, 3)] as Sprite2D).visible)


func test_lava_base_state_stays_blocked_after_dynamic_wall_removal() -> void:
	var lab := _new_lab()
	var cell := Vector2i(3, 3)
	assert_not_null(lab.place_wall(cell, DynamicWall.WallVariant.BASE))
	assert_true(lab.cell_states.set_surface(cell, DynamicCellState.Surface.LAVA))
	assert_true(lab.remove_wall(cell))
	assert_eq(lab.get_cell_surface(cell), DynamicCellState.Surface.LAVA)
	assert_false(lab.is_cell_walkable(cell))
	assert_eq(lab.grid.get_type(cell), GridData.CellType.WALL)


func test_lab_wall_blocks_and_restores_los_and_projectiles() -> void:
	var lab := _new_lab()
	var from := Vector2i(1, 3)
	var to := Vector2i(6, 3)
	assert_true(lab.has_line_of_sight(from, to))
	assert_true(lab.has_projectile_path(from, to))
	assert_not_null(lab.place_wall(Vector2i(3, 3), DynamicWall.WallVariant.BASE))
	assert_false(lab.has_line_of_sight(from, to))
	assert_false(lab.has_projectile_path(from, to))
	lab.remove_wall(Vector2i(3, 3))
	assert_true(lab.has_line_of_sight(from, to))
	assert_true(lab.has_projectile_path(from, to))


func test_hp_damage_state_and_destruction_are_idempotent() -> void:
	var lab := _new_lab()
	var cell := Vector2i(3, 3)
	var wall := lab.place_wall(cell, DynamicWall.WallVariant.BASE)
	var destroyed_count := [0]
	wall.destroyed.connect(func(_wall): destroyed_count[0] += 1)
	assert_eq(lab.damage_wall(cell, 16, &"NONE"), 16)
	assert_eq(wall.wall_state, DynamicWall.WallState.DAMAGED)
	assert_eq(wall.hp, 14)
	assert_eq(lab.damage_wall(cell, 14, &"NONE"), 14)
	assert_eq(wall.wall_state, DynamicWall.WallState.DESTROYED)
	assert_false(lab.has_wall(cell))
	assert_false(lab.grid.is_cell_dynamically_blocked(cell))
	assert_false(wall.destroy())
	assert_eq(destroyed_count[0], 1)


func test_duration_expiration_and_fire_aura_work_per_turn() -> void:
	var lab := _new_lab()
	var fire_cell := Vector2i(2, 3)
	var wall := lab.place_wall(fire_cell, DynamicWall.WallVariant.FIRE)
	assert_not_null(wall)
	assert_eq(lab.test_unit_hp, 20)
	lab.advance_turn()
	assert_eq(lab.test_unit_hp, 18)
	assert_eq(wall.remaining_turns, 2)
	lab.advance_turn()
	lab.advance_turn()
	assert_false(lab.has_wall(fire_cell))
	assert_false(lab.grid.is_cell_dynamically_blocked(fire_cell))


func test_water_and_ice_against_fire_wall_transform_it_to_damaged_base() -> void:
	var lab := _new_lab()
	var water_cell := Vector2i(3, 3)
	var fire_water := lab.place_wall(water_cell, DynamicWall.WallVariant.FIRE)
	var water_result := lab.apply_element_to_wall(water_cell, &"WATER")
	assert_true(water_result.handled)
	assert_eq(water_result.action, &"steam_to_base")
	assert_eq(fire_water.variant, DynamicWall.WallVariant.BASE)
	assert_eq(fire_water.hp, 4)
	assert_eq(fire_water.wall_state, DynamicWall.WallState.DAMAGED)
	assert_eq(fire_water.config.damage_on_adjacent_turn, 0)

	var ice_cell := Vector2i(4, 3)
	var fire_ice := lab.place_wall(ice_cell, DynamicWall.WallVariant.FIRE)
	var ice_result := lab.apply_element_to_wall(ice_cell, &"ICE")
	assert_true(ice_result.handled)
	assert_eq(ice_result.action, &"thermal_shock")
	assert_eq(fire_ice.variant, DynamicWall.WallVariant.BASE)
	assert_eq(fire_ice.hp, 4)


func test_fire_melts_ice_and_water_reinforces_ice() -> void:
	var lab := _new_lab()
	var melt_cell := Vector2i(3, 3)
	var ice_wall := lab.place_wall(melt_cell, DynamicWall.WallVariant.ICE)
	var melt := lab.apply_element_to_wall(melt_cell, &"FIRE")
	assert_true(melt.handled)
	assert_true(melt.destroyed)
	assert_eq(ice_wall.wall_state, DynamicWall.WallState.DESTROYED)
	assert_false(lab.has_wall(melt_cell))
	assert_eq(lab.get_cell_surface(melt_cell), DynamicCellState.Surface.STONE)

	var reinforce_cell := Vector2i(4, 3)
	var reinforced := lab.place_wall(reinforce_cell, DynamicWall.WallVariant.ICE)
	reinforced.apply_damage(6, &"WATER")
	assert_eq(reinforced.hp, 17)
	var water := lab.apply_element_to_wall(reinforce_cell, &"WATER")
	assert_true(water.handled)
	assert_eq(reinforced.hp, 20)
	assert_eq(reinforced.remaining_turns, 4)


func test_fire_and_ice_can_transform_base_wall_through_central_resolver() -> void:
	var lab := _new_lab()
	var fire_cell := Vector2i(3, 3)
	var fire_wall := lab.place_wall(fire_cell, DynamicWall.WallVariant.BASE)
	assert_eq(lab.apply_element_to_wall(fire_cell, &"FIRE").action, &"ignite")
	assert_eq(fire_wall.variant, DynamicWall.WallVariant.FIRE)

	var ice_cell := Vector2i(4, 3)
	var ice_wall := lab.place_wall(ice_cell, DynamicWall.WallVariant.BASE)
	assert_eq(lab.apply_element_to_wall(ice_cell, &"ICE").action, &"freeze")
	assert_eq(ice_wall.variant, DynamicWall.WallVariant.ICE)


func test_surface_commands_feed_the_resolver_without_overwriting_base_terrain() -> void:
	var lab := _new_lab()
	var cell := Vector2i(3, 3)
	var wall := lab.place_wall(cell, DynamicWall.WallVariant.FIRE)
	assert_true(lab.set_cell_surface(cell, DynamicCellState.Surface.WATER))
	assert_eq(wall.variant, DynamicWall.WallVariant.BASE)
	assert_eq(lab.get_cell_surface(cell), DynamicCellState.Surface.STONE)


func test_occlusion_contract_uses_ground_y_and_keeps_sides_visible() -> void:
	var lab := _new_lab()
	var wall_cell := Vector2i(4, 4)
	var wall := lab.place_wall(wall_cell, DynamicWall.WallVariant.BASE)
	assert_eq(wall.get_parent(), lab.get_node("YSortedWorld"))
	assert_eq(lab.get_node("YSortedWorld/TestUnit").get_parent(), wall.get_parent())
	assert_true(lab.is_unit_visually_behind_wall(Vector2i(3, 3), wall_cell))
	assert_true(lab.is_unit_visually_in_front_of_wall(Vector2i(5, 5), wall_cell))
	assert_false(lab.is_unit_visually_behind_wall(Vector2i(4, 3), wall_cell))
	assert_false(lab.is_unit_visually_in_front_of_wall(Vector2i(5, 4), wall_cell))


func test_reset_removes_walls_blockers_and_signals_then_restores_path() -> void:
	var lab := _new_lab()
	lab.set_start_cell(Vector2i(0, 3))
	lab.set_destination(Vector2i(7, 3))
	for cell in [Vector2i(3, 2), Vector2i(3, 3), Vector2i(3, 4)]:
		assert_not_null(lab.place_wall(cell, DynamicWall.WallVariant.FIRE))
	lab.cell_states.set_surface(Vector2i(5, 5), DynamicCellState.Surface.LAVA)
	lab.reset_lab()
	assert_eq(lab.get_wall_count(), 0)
	for x in range(lab.grid.cols):
		for y in range(lab.grid.rows):
			var cell := Vector2i(x, y)
			assert_false(lab.grid.is_cell_dynamically_blocked(cell), str(cell))
			assert_eq(lab.get_cell_surface(cell), DynamicCellState.Surface.STONE, str(cell))
	assert_eq(lab.get_current_path().size(), 6)
	assert_true(lab.has_line_of_sight(lab.start_cell, lab.destination_cell))
	assert_true(lab.has_projectile_path(lab.start_cell, lab.destination_cell))


func test_cell_screen_round_trip_and_foot_anchors_do_not_drift() -> void:
	var lab := _new_lab()
	var grid_view := lab.get_node("GridDebugLayer") as IsoGridView
	for x in range(8):
		for y in range(8):
			var cell := Vector2i(x, y)
			assert_eq(grid_view.local_to_grid(grid_view.grid_to_local(cell)), cell)
	var unit_cell := Vector2i(5, 6)
	lab.set_start_cell(unit_cell)
	var world := lab.get_node("YSortedWorld") as Node2D
	var marker := lab.get_node("YSortedWorld/TestUnit") as Node2D
	var expected := world.to_local(grid_view.to_global(grid_view.grid_to_local(unit_cell)))
	assert_eq(marker.position, expected)


func _new_lab() -> DynamicArenaLab:
	var lab := LabScene.instantiate() as DynamicArenaLab
	add_child_autofree(lab)
	return lab


func _load_wall_png(file_name: String) -> Image:
	return Image.load_from_file(ProjectSettings.globalize_path(NORMALIZED_DIR.path_join(file_name)))


func _alpha_bounds(image: Image) -> Rect2i:
	var minimum := Vector2i(image.get_width(), image.get_height())
	var maximum := Vector2i(-1, -1)
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a <= 1.0 / 255.0:
				continue
			minimum.x = mini(minimum.x, x)
			minimum.y = mini(minimum.y, y)
			maximum.x = maxi(maximum.x, x)
			maximum.y = maxi(maximum.y, y)
	return Rect2i(minimum, maximum - minimum + Vector2i.ONE)
