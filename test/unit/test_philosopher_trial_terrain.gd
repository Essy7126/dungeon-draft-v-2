extends GutTest

const Layout = preload("res://tools/philosopher_sprite_pipeline/trial_terrain_layout.gd")
const Factory = preload("res://test/support/factory.gd")
const RUN: RunData = preload("res://data/runs/philosopher_trial.tres")
const MAGE: UnitData = preload("res://data/units/enemies/philosopher_mage.tres")


func _room() -> ArenaDefinition:
	return RUN.rooms[0] as ArenaDefinition


func _coordinates(arena: ArenaDefinition) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell in arena.cells:
		if cell != null and cell.defined:
			result.append(cell.coordinate)
	result.sort_custom(func(a: Vector2i, b: Vector2i): return a.y < b.y or (a.y == b.y and a.x < b.x))
	return result


func test_published_trial_uses_its_own_lethe_room_and_preserves_source_geometry() -> void:
	var source := load(Layout.SOURCE) as ArenaDefinition
	var room := _room()
	assert_eq(room.resource_path, Layout.OUTPUT)
	assert_eq(room.arena_id, &"philosopher_trial_lethe")
	assert_eq(room.source_room_path, Layout.SOURCE)
	assert_eq(room.registered_terrain_plan_path, source.registered_terrain_plan_path)
	assert_eq(room.background_path, source.background_path)
	assert_eq(room.presentation_profile_path, source.presentation_profile_path)
	assert_eq(room.grid_size, source.grid_size)
	assert_eq(_coordinates(room), _coordinates(source), "Authored dalles cannot add or remove any source island or recess.")
	assert_eq(room.obstacles.size(), source.obstacles.size())
	for index in range(source.obstacles.size()):
		assert_eq(room.obstacles[index].to_dict(), source.obstacles[index].to_dict())
	assert_eq(room.encounter_definition.expanded_roster().map(func(u: UnitData): return u.unit_id),
		[&"philosopher_mage", &"spectre_greatsword"])


func test_regeneration_preserves_the_source_and_matches_authored_production_cells() -> void:
	var source := load(Layout.SOURCE) as ArenaDefinition
	var before := RoomDataSnapshotService.room_fingerprint(source)
	var generated := Layout.build(source)
	assert_not_null(generated)
	if generated == null:
		return
	assert_eq(RoomDataSnapshotService.room_fingerprint(source), before)
	var room := _room()
	for definition in generated.cells:
		assert_eq(room.get_cell_definition(definition.coordinate).terrain_id, definition.terrain_id)
	assert_eq(room.hero_spawn_zone, generated.hero_spawn_zone)
	assert_eq(room.enemy_spawn_zone, generated.enemy_spawn_zone)
	assert_eq(room.vortex_networks[0].unique_cells(), generated.vortex_networks[0].unique_cells())


func test_all_four_permanent_dalles_have_real_runtime_effects_and_costs() -> void:
	var runtime := ArenaRuntimeProjectionService.build(_room())
	var count := 0
	for terrain_id in Layout.TERRAIN_CELLS:
		var catalog := ArenaTerrainRegistry.definition_for(terrain_id)
		for cell in Layout.TERRAIN_CELLS[terrain_id]:
			assert_eq(_room().get_cell_definition(cell).terrain_id, terrain_id)
			assert_true(runtime.grid.is_walkable(cell))
			assert_eq(runtime.grid.get_movement_cost(cell), catalog.movement_cost)
			var state := runtime.terrain_effects.get_surface_state(cell)
			assert_eq(state.base_terrain_id, terrain_id)
			assert_same(state.base_effect, catalog.unit_effect)
			assert_true(state.base_apply_on_enter)
			count += 1
	assert_eq(count, 8)
	assert_lt(float(count) / _coordinates(_room()).size(), 0.1, "Hazards remain a modest share of playable terrain.")


func test_every_spawn_is_safe_and_reachable_without_crossing_hazard_or_using_a_portal() -> void:
	var room := _room()
	var runtime := ArenaRuntimeProjectionService.build(room)
	assert_eq(room.hero_spawn_zone, Layout.HERO_CELLS)
	assert_eq(room.enemy_spawn_zone, [Layout.MAGE_CELL, Layout.SPECTRE_CELL])
	var visited := {}
	var queue: Array[Vector2i] = [room.hero_spawn_zone[0]]
	visited[queue[0]] = true
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		for direction in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var next: Vector2i = current + direction
			if visited.has(next) or not runtime.grid.is_walkable(next) or runtime.grid.has_vortex(next):
				continue
			if runtime.terrain_effects.get_effect_data(next) != null:
				continue
			visited[next] = true
			queue.append(next)
	for cell in room.hero_spawn_zone + room.enemy_spawn_zone:
		assert_true(runtime.grid.is_walkable(cell))
		assert_null(runtime.terrain_effects.get_effect_data(cell), "Starting positions must not apply damage or debuffs.")
		assert_true(visited.has(cell), "There must be an ordinary safe route to %s." % cell)


func test_production_portal_pair_is_bidirectional_and_available_to_both_sides() -> void:
	var room := _room()
	assert_eq(room.vortex_networks.size(), 1)
	var network := room.vortex_networks[0]
	assert_eq(network.network_id, Layout.NETWORK_ID)
	assert_eq(network.unique_cells(), Layout.PORTAL_CELLS)
	var runtime := ArenaRuntimeProjectionService.build(room)
	var mage := Unit.from_data(MAGE)
	var hero := Factory.make_unit("Achille", 0)
	for entry in Layout.PORTAL_CELLS:
		var exit: Vector2i = Layout.PORTAL_CELLS[1] if entry == Layout.PORTAL_CELLS[0] else Layout.PORTAL_CELLS[0]
		assert_eq(runtime.grid.get_vortex_destination(entry), exit)
		assert_true(runtime.grid.can_unit_use_vortex_network(entry, mage))
		assert_true(runtime.grid.can_unit_use_vortex_network(entry, hero))


func test_mage_naturally_uses_the_production_portal_to_find_a_casting_position() -> void:
	var runtime := ArenaRuntimeProjectionService.build(_room())
	var mage := Unit.from_data(MAGE)
	var hero := Factory.make_unit("Achille", 0)
	var spectre := Unit.from_data(Layout.ENCOUNTER.expanded_roster()[1])
	var pathfinder := Pathfinder.new(runtime.grid)
	var formation := EncounterFormationPlanner.new(runtime.grid, pathfinder).build_plan(
		_room().encounter_definition, _room().hero_spawn_zone, _room().enemy_spawn_zone,
		EncounterSeedResolver.effective_seed(RUN.default_seed, 0))
	assert_true(formation.get("valid", false), str(formation))
	for placement in formation.get("placements", []):
		var unit: Unit = mage if placement.unit_data.unit_id == &"philosopher_mage" else spectre
		runtime.grid.place_unit(unit, placement.cell)
	assert_eq(mage.grid_pos, Layout.MAGE_CELL)
	assert_eq(spectre.grid_pos, Layout.SPECTRE_CELL)
	runtime.grid.place_unit(hero, Layout.HERO_CELLS[0])
	var caster := SpellCaster.new(runtime.grid, pathfinder, runtime.terrain_effects)
	caster.set_action_classification_catalog(RUN.action_classification_catalog)
	mage.start_turn()
	var ai := EnemyAI.new(runtime.grid, pathfinder, caster)
	var plan: Array = ai.decide(mage, [mage, hero, spectre])
	assert_false(plan.is_empty())
	if plan.is_empty():
		return
	assert_eq(plan[0].type, "move")
	assert_true(plan[0].path.has(Layout.PORTAL_CELLS[0]))
	assert_eq(plan[0].path.back(), Layout.PORTAL_CELLS[1])
	assert_lte(pathfinder.path_movement_cost(plan[0].path, mage), mage.current_mp)
	assert_true(plan.any(func(action: Dictionary): return action.type == "cast"))
