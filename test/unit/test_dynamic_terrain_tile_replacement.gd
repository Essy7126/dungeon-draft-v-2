extends GutTest

const FIREBALL_PATH := "res://data/spells/Mage/boule_de_feu.tres"
const ICE_WALL_PATH := "res://data/spells/mur_de_glace.tres"
const LAVA_PATH := "res://data/terrain/lave.tres"
const WATER_PATH := "res://data/terrain/eau.tres"
const ICE_PATH := "res://data/terrain/glace.tres"


func test_stable_ids_and_catalog_textures_are_reloadable() -> void:
	var cases := [
		[LAVA_PATH, &"fire", &"lava"],
		[WATER_PATH, &"water", &"water"],
		[ICE_PATH, &"ice", &"ice"],
		["res://data/terrain/vapeur.tres", &"steam", &"steam"],
	]
	for entry in cases:
		var effect := load(entry[0]) as TerrainEffectData
		assert_not_null(effect)
		assert_eq(effect.surface_id, entry[1])
		assert_eq(effect.visual_terrain_id, entry[2])
		var visual := TerrainSurfaceVisualResolver.resolve(entry[2])
		assert_true(bool(visual.get("ok", false)), str(visual))
		var texture := visual.get("texture") as Texture2D
		assert_not_null(texture)
		assert_true(ResourceLoader.exists(texture.resource_path))
		assert_not_null(load(texture.resource_path))


func test_terrain_effects_and_dynamic_surface_facade_share_one_authority() -> void:
	var grid := GridData.new(3, 3)
	var terrain := TerrainEffects.new(grid)
	assert_true(terrain.capture_base_state().ok)
	var compatibility := DynamicSurfaceService.new()
	compatibility.configure(grid, [], terrain.runtime_service)
	assert_same(compatibility.runtime_service, terrain.runtime_service)
	var result := terrain.place_effect(Vector2i.ONE, load(LAVA_PATH))
	assert_true(result.changed)
	assert_eq(compatibility.get_surface_id(Vector2i.ONE), &"fire")
	assert_eq(compatibility.get_remaining_duration(Vector2i.ONE), 3)
	assert_eq(grid.get_type(Vector2i.ONE), GridData.CellType.LAVA)


func test_fireball_uses_true_nine_cell_geometry_and_keeps_balance_values() -> void:
	var arena := _arena_fixture()
	var before := ArenaEditSession.fingerprint(arena.to_snapshot())
	var state := ArenaRuntimeProjectionService.build(arena)
	var spell := load(FIREBALL_PATH) as Spell
	assert_not_null(state)
	assert_not_null(spell)
	assert_eq(spell.ap_cost, 1)
	assert_eq(spell.spell_range, 14)
	assert_eq(spell.aoe_shape, Spell.AoeShape.CROSS)
	assert_eq(spell.aoe_size, 2)
	assert_eq(spell.damage, 25)
	assert_eq(spell.terrain_effect.duration, 3)
	assert_eq(spell.terrain_effect.damage, 15)
	assert_eq(spell.terrain_effect.trigger, TerrainEffectData.Trigger.ON_ENTER)
	var caster_unit := Unit.from_data(load("res://data/units/alliés/mage.tres"))
	caster_unit.grid_pos = Vector2i(3, 6)
	var caster := SpellCaster.new(
		state.grid, Pathfinder.new(state.grid), state.terrain_effects
	)
	var cells: Array = caster.get_aoe_cells(
		spell, Vector2i(3, 3), caster_unit.grid_pos
	)
	assert_eq(cells.size(), 9)
	assert_eq(_unique_cells(cells).size(), 9)
	var terrain_changed: Array[Vector2i] = []
	for cell in cells:
		var result := state.apply_terrain_effect(
			cell, spell.terrain_effect, caster_unit, spell
		)
		if bool(result.get("changed", false)):
			terrain_changed.append(cell)
	assert_eq(_sorted_cells(terrain_changed), _sorted_cells(cells))
	assert_eq(state.terrain_effects.active_surface_cells().size(), 9)
	for cell in cells:
		assert_eq(state.terrain_effects.get_surface_id(cell), &"fire")
		assert_eq(state.terrain_effects.get_visual_terrain_id(cell), &"lava")
		assert_eq(state.terrain_effects.get_remaining_duration(cell), 3)
		assert_eq(state.grid.get_type(cell), GridData.CellType.LAVA)
	assert_eq(ArenaEditSession.fingerprint(arena.to_snapshot()), before)


func test_ice_water_duration_and_exact_static_base_restoration() -> void:
	var arena := _arena_fixture()
	var before := ArenaEditSession.fingerprint(arena.to_snapshot())
	var state := ArenaRuntimeProjectionService.build(arena)
	var water := load(WATER_PATH) as TerrainEffectData
	var ice := load(ICE_PATH) as TerrainEffectData
	var lava := load(LAVA_PATH) as TerrainEffectData
	var stone_cell := Vector2i(3, 3)
	var static_water_cell := Vector2i(1, 1)
	var static_ice_cell := Vector2i(2, 1)
	assert_true(state.apply_terrain_effect(stone_cell, water).changed)
	assert_eq(state.grid.get_type(stone_cell), GridData.CellType.NORMAL)
	assert_eq(state.terrain_effects.get_visual_terrain_id(stone_cell), &"water")
	assert_not_null(water.applied_status)
	assert_true(state.apply_terrain_effect(static_water_cell, ice).changed)
	assert_eq(state.grid.get_type(static_water_cell), GridData.CellType.ICE)
	assert_eq(state.terrain_effects.get_base_state(static_water_cell).terrain_id, &"water")
	assert_true(state.apply_terrain_effect(static_ice_cell, lava).changed)
	assert_eq(state.grid.get_type(static_ice_cell), GridData.CellType.LAVA)
	assert_eq(state.terrain_effects.get_base_state(static_ice_cell).cell_type, GridData.CellType.ICE)
	for expected in [2, 1]:
		state.advance_surface_tick()
		assert_eq(state.terrain_effects.get_remaining_duration(stone_cell), expected)
		assert_eq(state.terrain_effects.get_remaining_duration(static_water_cell), expected)
		assert_eq(state.terrain_effects.get_remaining_duration(static_ice_cell), expected)
	state.advance_surface_tick()
	assert_eq(state.terrain_effects.active_surface_cells(), [] as Array[Vector2i])
	assert_eq(state.grid.get_type(stone_cell), GridData.CellType.NORMAL)
	assert_eq(state.grid.get_type(static_water_cell), GridData.CellType.NORMAL)
	assert_eq(state.grid.get_type(static_ice_cell), GridData.CellType.ICE)
	assert_eq(state.terrain_effects.get_base_state(stone_cell).terrain_id, &"stone")
	assert_eq(state.terrain_effects.get_base_state(static_water_cell).terrain_id, &"water")
	assert_eq(state.terrain_effects.get_base_state(static_ice_cell).terrain_id, &"ice")
	assert_eq(ArenaEditSession.fingerprint(arena.to_snapshot()), before)


func test_removed_wall_and_out_of_bounds_cells_are_rejected() -> void:
	var state := ArenaRuntimeProjectionService.build(_arena_fixture())
	var lava := load(LAVA_PATH) as TerrainEffectData
	var removed := state.apply_terrain_effect(Vector2i(0, 0), lava)
	var wall := state.apply_terrain_effect(Vector2i(0, 1), lava)
	var outside := state.apply_terrain_effect(Vector2i(-1, 2), lava)
	assert_false(removed.changed)
	assert_eq(removed.reason, "absent_from_captured_topology")
	assert_false(wall.changed)
	assert_eq(wall.reason, "absent_from_captured_topology")
	assert_false(outside.changed)
	assert_eq(outside.reason, "out_of_bounds")
	assert_eq(state.terrain_effects.active_surface_cells().size(), 0)


func test_stable_reaction_matrix_and_same_surface_policy_match_production() -> void:
	var cases := [
		[&"fire", &"water", &"steam", &"steam"],
		[&"water", &"fire", &"steam", &"steam"],
		[&"fire", &"ice", &"water", &"melt"],
		[&"ice", &"fire", &"water", &"melt"],
		[&"water", &"ice", &"ice", &"freeze"],
		[&"ice", &"water", &"ice", &"freeze"],
		[&"water", &"lightning", &"none", &"shock"],
	]
	for entry in cases:
		var result := TerrainInteractionResolver.resolve_ids(entry[0], entry[1])
		assert_eq(result.result_surface_id, entry[2])
		assert_eq(result.reaction, entry[3])
	var state := ArenaRuntimeProjectionService.build(_arena_fixture())
	var cell := Vector2i(3, 3)
	var lava := load(LAVA_PATH) as TerrainEffectData
	assert_true(state.apply_terrain_effect(cell, lava).changed)
	state.advance_surface_tick()
	assert_eq(state.terrain_effects.get_remaining_duration(cell), 2)
	var same := state.apply_terrain_effect(cell, lava)
	assert_true(same.same)
	assert_false(same.changed)
	assert_eq(state.terrain_effects.get_remaining_duration(cell), 2)
	var melt := state.apply_terrain_effect(cell, load(ICE_PATH))
	assert_eq(melt.reaction, "melt")
	assert_eq(state.terrain_effects.get_surface_id(cell), &"water")
	assert_eq(state.terrain_effects.get_visual_terrain_id(cell), &"water")


func test_steam_uses_its_catalog_tile_and_expires_to_the_exact_base() -> void:
	var state := ArenaRuntimeProjectionService.build(_arena_fixture())
	var cell := Vector2i(3, 3)
	assert_true(state.apply_terrain_effect(cell, load(LAVA_PATH)).changed)
	var steam := state.apply_terrain_effect(cell, load(WATER_PATH))
	assert_eq(steam.reaction, "steam")
	assert_eq(state.terrain_effects.get_surface_id(cell), &"steam")
	assert_eq(state.terrain_effects.get_visual_terrain_id(cell), &"steam")
	var visual := TerrainSurfaceVisualResolver.resolve(&"steam")
	assert_true(visual.ok)
	assert_true(str((visual.texture as Texture2D).resource_path).ends_with(
		"normalized/steam.png"
	))
	assert_eq(state.grid.get_type(cell), GridData.CellType.NORMAL)
	state.advance_surface_tick()
	assert_eq(state.terrain_effects.get_remaining_duration(cell), 1)
	state.advance_surface_tick()
	assert_eq(state.terrain_effects.get_surface_id(cell), &"none")
	assert_eq(state.grid.get_type(cell), GridData.CellType.NORMAL)
	assert_eq(state.terrain_effects.get_base_state(cell).terrain_id, &"stone")


func test_duration_and_damage_overrides_do_not_mutate_canonical_resources() -> void:
	var canonical := load(LAVA_PATH) as TerrainEffectData
	var spell := load(FIREBALL_PATH) as Spell
	var canonical_duration := canonical.duration
	var canonical_damage := canonical.damage
	var spell_duration := spell.terrain_effect.duration
	var modified := canonical.duplicate(true) as TerrainEffectData
	modified.duration = 5
	modified.damage = 19
	var grid := GridData.new(3, 3)
	var terrain := TerrainEffects.new(grid)
	assert_true(terrain.capture_base_state().ok)
	var cell := Vector2i.ONE
	assert_true(terrain.place_effect(cell, modified, null, spell, 7).changed)
	assert_eq(terrain.get_remaining_duration(cell), 7)
	var fixture := Unit.new("Fixture", 0, 100)
	fixture.grid_pos = cell
	terrain.on_enter_cell(fixture, cell)
	assert_eq(fixture.current_hp, 81)
	assert_eq(canonical.duration, canonical_duration)
	assert_eq(canonical.damage, canonical_damage)
	assert_eq(spell.terrain_effect.duration, spell_duration)
	assert_same(spell.terrain_effect, canonical)


func test_visual_adapter_replaces_one_tile_then_restores_base_without_residue() -> void:
	var state := ArenaRuntimeProjectionService.build(_arena_fixture())
	var root := Node2D.new()
	add_child_autofree(root)
	var floor_layer := Node2D.new()
	floor_layer.name = "ArenaTilesLayer"
	root.add_child(floor_layer)
	var dynamic_layer := Node2D.new()
	dynamic_layer.name = "ArenaDynamicSurfaceLayer"
	dynamic_layer.y_sort_enabled = false
	root.add_child(dynamic_layer)
	var grid_view := PaintedGridView.new()
	grid_view.configure(
		state.visual_data, state.layout, state.hero_spawns, state.enemy_spawns
	)
	grid_view.setup(state.grid)
	root.add_child(grid_view)
	var cell := Vector2i(3, 3)
	var base := Node2D.new()
	base.name = "BaseStone"
	base.set_meta("arena_cell", cell)
	base.set_meta("renderer_role", &"arena_floor")
	floor_layer.add_child(base)
	var adapter := DynamicSurfaceVisualAdapter.new()
	root.add_child(adapter)
	adapter.configure(
		state.terrain_effects.runtime_service,
		grid_view,
		dynamic_layer,
		&"forest"
	)
	assert_true(state.apply_terrain_effect(cell, load(LAVA_PATH)).changed)
	assert_false(base.visible)
	var dynamic_tile := adapter.node_for_cell(cell)
	assert_not_null(dynamic_tile)
	assert_eq(dynamic_tile.get_parent(), dynamic_layer)
	assert_eq(dynamic_tile.get_meta("renderer_role"), &"dynamic_surface")
	assert_eq(dynamic_tile.get_meta("visual_terrain_id"), &"lava")
	var report := adapter.renderer.actual_render_report()
	assert_eq(report.rendered_terrain_node_count, 1)
	assert_eq(report.cells["3,3"].duplication_count, 1)
	assert_true(str(report.cells["3,3"].texture_path).ends_with("lava.png"))
	for _tick in 3:
		state.advance_surface_tick()
	assert_true(base.visible)
	assert_null(adapter.node_for_cell(cell))
	assert_eq(adapter.rendered_cells().size(), 0)


func test_exact_preview_simulates_true_spell_not_surface_config_values() -> void:
	var arena := _arena_fixture()
	var before := ArenaEditSession.fingerprint(arena.to_snapshot())
	var preview := ArenaRuntimePreview.new()
	add_child_autofree(preview)
	preview.set_view_mode(ArenaRuntimePreview.ViewMode.GAME)
	preview.set_arena(arena)
	# L'assemblage de cette fixture volontairement sans fond peut rapporter une
	# fidelite visuelle incomplete ; la projection et l'adaptateur doivent
	# toutefois etre les composants runtime reels et pleinement operationnels.
	preview.rebuild_now()
	assert_not_null(preview.runtime_state)
	assert_not_null(preview.dynamic_surface_visuals)
	var report := preview.simulate_terrain_spell(
		load(FIREBALL_PATH), Vector2i(3, 3),
		load("res://data/units/alliés/mage.tres")
	)
	assert_true(report.handled)
	assert_eq(report.spell_id, &"mage_fireball")
	assert_eq(report.requested_cells.size(), 9)
	assert_eq(report.terrain_changed.size(), 9)
	assert_eq(report.duration, 3)
	assert_eq(report.terrain_damage, 15)
	assert_eq(report.direct_damage, 25)
	assert_eq(report.surface_id, &"fire")
	assert_eq(report.visual_terrain_id, &"lava")
	assert_eq(preview.dynamic_surface_visuals.rendered_cells().size(), 9)
	for _tick in 3:
		preview.advance_runtime_surface_tick()
	assert_eq(preview.dynamic_surface_visuals.rendered_cells().size(), 0)
	assert_eq(ArenaEditSession.fingerprint(arena.to_snapshot()), before)


func test_twenty_cycles_leave_no_state_node_or_duplicate_signal() -> void:
	var state := ArenaRuntimeProjectionService.build(_arena_fixture())
	var cell := Vector2i(3, 3)
	var applied_signal_count := [0]
	state.terrain_effects.surface_applied.connect(
		func(_fact): applied_signal_count[0] += 1
	)
	for _cycle in 20:
		assert_true(state.apply_terrain_effect(cell, load(ICE_PATH)).changed)
		for _tick in 3:
			state.advance_surface_tick()
		assert_eq(state.terrain_effects.active_surface_cells().size(), 0)
		assert_eq(state.grid.get_type(cell), GridData.CellType.NORMAL)
	assert_eq(applied_signal_count[0], 20)
	assert_eq(state.terrain_effects.runtime_service.state_count(), 47)


func _arena_fixture() -> ArenaDefinition:
	var arena := ArenaDefinition.new()
	arena.set_identity("Dynamic terrain fixture", "dynamic_terrain_fixture")
	arena.visual_mode = ArenaDefinition.VisualMode.HYBRID
	arena.theme_id = &"forest"
	arena.grid_size = Vector2i(7, 7)
	arena.source_image_size = Vector2i(448, 448)
	# Fixture sans fond peint : le test cible exclusivement les dalles runtime.
	arena.background_path = ""
	arena.grid_origin = Vector2(224.0, 32.0)
	arena.axis_x = Vector2(32.0, 16.0)
	arena.axis_y = Vector2(-32.0, 16.0)
	for y in range(arena.grid_size.y):
		for x in range(arena.grid_size.x):
			var cell := arena.ensure_cell(Vector2i(x, y))
			cell.playable = true
			cell.terrain_id = &"stone"
	var removed := arena.get_cell_definition(Vector2i(0, 0))
	removed.defined = false
	removed.playable = false
	removed.cell_type = GridData.CellType.HOLE
	removed.terrain_id = &"void"
	var wall := arena.get_cell_definition(Vector2i(0, 1))
	wall.playable = false
	wall.cell_type = GridData.CellType.WALL
	wall.terrain_id = &"wall"
	var water := arena.get_cell_definition(Vector2i(1, 1))
	water.cell_type = GridData.CellType.NORMAL
	water.terrain_id = &"water"
	var ice := arena.get_cell_definition(Vector2i(2, 1))
	ice.cell_type = GridData.CellType.ICE
	ice.terrain_id = &"ice"
	return arena


func _unique_cells(cells: Array) -> Dictionary:
	var unique := {}
	for cell in cells:
		unique[cell] = true
	return unique


func _sorted_cells(cells: Array) -> Array[String]:
	var result: Array[String] = []
	for cell in cells:
		result.append("%03d,%03d" % [cell.x, cell.y])
	result.sort()
	return result
