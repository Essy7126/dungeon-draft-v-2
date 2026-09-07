extends GutTest

const Factory = preload("res://test/support/factory.gd")
const MAGE: UnitData = preload("res://data/units/enemies/philosopher_mage.tres")
const TRIAL: RunData = preload("res://data/runs/philosopher_trial.tres")
const FIRE: TerrainEffectData = preload("res://data/terrain/lave.tres")


func _field(mage_cell := Vector2i(0, 2), hero_cell := Vector2i(6, 2), tiles: Dictionary = {}, portals: Array[Vector2i] = [], size := Vector2i(10, 5)) -> Dictionary:
	var arena := ArenaDefinition.new()
	arena.set_identity("Mage terrain fixture", "philosopher_terrain_fixture")
	arena.grid_size = size
	for y in range(size.y):
		for x in range(size.x):
			var cell := Vector2i(x, y)
			ArenaTerrainRegistry.configure_cell(arena.ensure_cell(cell), tiles.get(cell, &"neutral"))
	if not portals.is_empty():
		var network := ArenaVortexNetworkService.create_network(arena)
		network.cells = portals.duplicate()
	assert_true(ArenaRuntimeBridge.sync_runtime_resources(arena))
	var runtime := ArenaRuntimeProjectionService.build(arena)
	runtime.terrain_effects.runtime_service.configure_resolution_context(42, 1)
	var grid := runtime.grid
	var pathfinder := Pathfinder.new(grid)
	var caster := SpellCaster.new(grid, pathfinder, runtime.terrain_effects)
	assert_true(caster.set_action_classification_catalog(TRIAL.action_classification_catalog))
	var mage := Unit.from_data(MAGE)
	var hero := Factory.make_unit("Achille", 0)
	assert_true(grid.place_unit(mage, mage_cell))
	assert_true(grid.place_unit(hero, hero_cell))
	mage.start_turn()
	return {"grid": grid, "pathfinder": pathfinder, "caster": caster, "terrain": runtime.terrain_effects,
		"runtime": runtime, "mage": mage, "hero": hero, "units": [mage, hero],
		"ai": EnemyAI.new(grid, pathfinder, caster)}


func _spell_ids(plan: Array) -> Array[StringName]:
	var ids: Array[StringName] = []
	for action in plan:
		if action.type == "cast":
			ids.append((action.spell as Spell).get_effective_spell_id())
	return ids


func _execute(f: Dictionary, plan: Array) -> void:
	for action in plan:
		if action.type == "move":
			var path: Array = action.path
			assert_eq(path[0], f.mage.grid_pos)
			var cost: int = f.pathfinder.path_movement_cost(path, f.mage)
			assert_true(f.mage.spend_mp(cost), "The real movement cost must fit the activation budget.")
			f.terrain.begin_unit_resolution(f.mage, &"movement")
			for index in range(1, path.size()):
				assert_true(f.grid.relocate_unit(f.mage, path[index]))
				var entry: Dictionary = f.terrain.consume_last_entry_result(f.mage)
				if bool(entry.get("end_movement", false)) or not f.mage.is_alive:
					break
			f.terrain.end_unit_resolution(f.mage)
		elif action.type == "cast":
			assert_true(f.caster.can_cast(f.mage, action.spell, action.cell), str(action))
			var report: Dictionary = f.caster.cast(f.mage, action.spell, action.cell)
			assert_false(report.get("failed", false), str(report))


func _assert_avoids_cell(plan: Array, cell: Vector2i) -> void:
	for action in plan:
		if action.type == "move":
			assert_false((action.path as Array).slice(1).has(cell), "The selected path must avoid %s." % cell)


func test_permanent_fire_is_avoided_when_a_safe_firing_path_exists() -> void:
	var fire := Vector2i(1, 2)
	var f := _field(Vector2i(0, 2), Vector2i(6, 2), {fire: &"lava"})
	var plan: Array = f.ai.decide(f.mage, f.units)
	assert_eq(plan[0].type, "move")
	_assert_avoids_cell(plan, fire)
	assert_false(_spell_ids(plan).is_empty())
	_execute(f, plan)
	assert_eq(f.mage.current_hp, 76)
	assert_false(f.mage.has_status(&"burn"))


func test_temporary_fire_obeys_the_same_movement_safety_as_permanent_fire() -> void:
	var fire := Vector2i(1, 2)
	var f := _field()
	f.terrain.place_effect(fire, FIRE)
	var plan: Array = f.ai.decide(f.mage, f.units)
	assert_eq(plan[0].type, "move")
	_assert_avoids_cell(plan, fire)
	_execute(f, plan)
	assert_eq(f.mage.current_hp, 76)


func test_mage_leaves_fire_even_when_it_could_cast_without_moving() -> void:
	var origin := Vector2i(0, 2)
	var f := _field(origin, Vector2i(4, 2), {origin: &"lava"})
	assert_true(f.caster.can_cast(f.mage, MAGE.spells[3], f.hero.grid_pos))
	var before_hp: int = f.mage.current_hp
	var plan: Array = f.ai.decide(f.mage, f.units)
	assert_eq(plan[0].type, "move")
	assert_eq(f.mage.grid_pos, origin, "Decision must not trigger terrain entry.")
	assert_eq(f.mage.current_hp, before_hp)
	_execute(f, plan)
	assert_ne(f.mage.grid_pos, origin)
	assert_eq(f.terrain.get_surface_state(f.mage.grid_pos).base_terrain_id, &"neutral")
	assert_eq(f.mage.current_hp, before_hp)
	assert_eq(f.mage.current_ap, 0)


func test_mage_can_escape_fire_with_insufficient_ap_for_a_spell() -> void:
	var origin := Vector2i(0, 2)
	var f := _field(origin, Vector2i(4, 2), {origin: &"lava"})
	f.mage.current_ap = 1
	var plan: Array = f.ai.decide(f.mage, f.units)
	assert_eq(plan.size(), 1)
	assert_eq(plan[0].type, "move")
	_execute(f, plan)
	assert_ne(f.mage.grid_pos, origin)
	assert_eq(f.mage.current_ap, 1)


func _push_fixture(terrain_id: StringName) -> Dictionary:
	return _field(Vector2i(0, 2), Vector2i(1, 2), {Vector2i(2, 2): terrain_id})


func test_refutation_really_pushes_into_water_and_reduces_next_turn_mp() -> void:
	var f := _push_fixture(&"water")
	var plan: Array = f.ai.decide(f.mage, f.units)
	assert_eq(_spell_ids(plan)[0], &"philosopher_refutation")
	_execute(f, plan)
	assert_eq(f.hero.grid_pos, Vector2i(2, 2))
	assert_eq(f.hero.current_hp, 92)
	assert_true(f.hero.has_status(&"wet"))
	f.hero.start_turn()
	assert_false(f.hero.process_statuses())
	assert_eq(f.hero.current_mp, 2)


func test_refutation_really_pushes_into_ice_without_inventing_a_slide() -> void:
	var f := _push_fixture(&"ice")
	_execute(f, f.ai.decide(f.mage, f.units))
	assert_eq(f.hero.grid_pos, Vector2i(2, 2))
	assert_eq(f.hero.current_hp, 92)
	assert_true(f.hero.has_status(&"frozen"))
	f.hero.start_turn()
	assert_false(f.hero.process_statuses())
	assert_eq(f.hero.current_mp, 2)


func test_refutation_really_pushes_into_lava_and_applies_burn() -> void:
	var f := _push_fixture(&"lava")
	_execute(f, f.ai.decide(f.mage, f.units))
	assert_eq(f.hero.grid_pos, Vector2i(2, 2))
	assert_eq(f.hero.current_hp, 77)
	assert_true(f.hero.has_status(&"burn"))
	f.hero.start_turn()
	f.hero.process_statuses()
	assert_eq(f.hero.current_hp, 71)


func test_forced_electrified_water_entry_applies_the_canonical_next_turn_shock() -> void:
	var f := _push_fixture(&"electrified_water")
	_execute(f, f.ai.decide(f.mage, f.units))
	assert_eq(f.hero.grid_pos, Vector2i(2, 2))
	assert_eq(f.hero.current_hp, 72)
	assert_true(f.hero.has_status(&"wet"))
	assert_true(f.hero.has_status(&"shock"))
	f.hero.start_turn()
	assert_true(f.hero.process_statuses())


func test_mage_prefers_the_victim_that_can_be_pushed_into_real_harmful_terrain() -> void:
	var f := _field(Vector2i(3, 2), Vector2i(4, 2), {Vector2i(5, 2): &"lava"})
	var neutral_victim := Factory.make_unit("Victime neutre", 0)
	f.grid.place_unit(neutral_victim, Vector2i(3, 1))
	f.units.append(neutral_victim)
	var plan: Array = f.ai.decide(f.mage, f.units)
	assert_eq(plan[0].type, "cast")
	assert_eq(plan[0].cell, f.hero.grid_pos)
	_execute(f, plan)
	assert_true(f.hero.has_status(&"burn"))
	assert_eq(neutral_victim.current_hp, 100)


func test_mage_repositions_to_use_refutation_on_water_instead_of_only_shielding() -> void:
	var f := _field(Vector2i(0, 2), Vector2i(2, 2), {Vector2i(3, 2): &"water"})
	var plan: Array = f.ai.decide(f.mage, f.units)
	assert_eq(plan[0].type, "move")
	assert_eq(plan[0].path.back(), Vector2i(1, 2))
	assert_eq(_spell_ids(plan)[0], &"philosopher_refutation")
	_execute(f, plan)
	assert_eq(f.hero.grid_pos, Vector2i(3, 2))
	assert_true(f.hero.has_status(&"wet"))


func test_planning_does_not_consume_the_victims_forced_movement_resistance() -> void:
	var f := _push_fixture(&"water")
	f.hero.first_forced_movement_reduction_per_activation = 1
	var plan: Array = f.ai.decide(f.mage, f.units)
	assert_false(f.hero._forced_movement_reduction_used)
	_execute(f, plan)
	assert_true(f.hero._forced_movement_reduction_used)
	assert_eq(f.hero.grid_pos, Vector2i(1, 2))
	assert_false(f.hero.has_status(&"wet"))


func test_pair_portal_charges_entry_cost_and_casts_from_the_actual_exit() -> void:
	var entry := Vector2i(1, 2)
	var exit := Vector2i(5, 2)
	var f := _field(Vector2i(0, 2), Vector2i(7, 2), {}, [entry, exit])
	f.grid.set_terrain_properties(entry, {"movement_cost": 2})
	var plan: Array = f.ai.decide(f.mage, f.units)
	assert_eq(plan[0].type, "move")
	assert_eq(plan[0].path.back(), exit)
	assert_eq(f.pathfinder.path_movement_cost(plan[0].path, f.mage), 2)
	_execute(f, plan)
	assert_eq(f.mage.grid_pos, exit)
	assert_eq(f.mage.current_mp, 1)
	assert_eq(f.mage.current_ap, 0)
	assert_true(f.hero.has_status(&"philosopher_aporia"))


func test_pair_portal_with_occupied_exit_is_not_planned() -> void:
	var entry := Vector2i(1, 2)
	var exit := Vector2i(5, 2)
	var f := _field(Vector2i(0, 2), Vector2i(7, 2), {}, [entry, exit])
	# An opposing occupant cannot use this enemy-only pair, so placing it
	# preserves the genuinely blocked exit without a teleport side effect.
	var pair_cells: Array[Vector2i] = [entry, exit]
	f.grid.set_vortex_network(&"fixture_restricted", pair_cells, 2, true)
	var blocker := Unit.new("Sortie occupee", 0, 100)
	f.grid.place_unit(blocker, exit)
	f.units.append(blocker)
	var plan: Array = f.ai.decide(f.mage, f.units)
	_assert_avoids_cell(plan, entry)
	_execute(f, plan)
	assert_ne(f.mage.grid_pos, exit)


func test_random_network_casts_are_legal_from_every_exit_without_predicting_the_draw() -> void:
	var entry := Vector2i(1, 2)
	var exits: Array[Vector2i] = [Vector2i(5, 1), Vector2i(5, 2)]
	var f := _field(Vector2i(0, 2), Vector2i(8, 2), {}, [entry, exits[0], exits[1]])
	var before_serial: int = f.terrain.runtime_service._resolution_serial
	var plan: Array = f.ai.decide(f.mage, f.units)
	assert_eq(f.terrain.runtime_service._resolution_serial, before_serial, "Planning must not roll or resolve a vortex.")
	assert_eq(plan[0].type, "move")
	assert_eq(plan[0].path.back(), entry)
	assert_eq(_spell_ids(plan), [&"philosopher_aporia", &"philosopher_axiom"])
	for action in plan:
		if action.type == "cast":
			assert_eq(action.cell, f.hero.grid_pos, "Unknown self-position must never become a queued target cell.")
	_execute(f, plan)
	assert_true(exits.has(f.mage.grid_pos))
	assert_eq(f.mage.current_ap, 0)
	assert_eq(f.mage.current_mp, 2)
	assert_eq(f.hero.current_hp, 84)


func test_random_network_is_declined_if_any_exit_is_dangerous() -> void:
	var entry := Vector2i(1, 2)
	var hazard := Vector2i(5, 1)
	var f := _field(Vector2i(0, 2), Vector2i(8, 2), {hazard: &"lava"}, [entry, hazard, Vector2i(5, 2)])
	var plan: Array = f.ai.decide(f.mage, f.units)
	_assert_avoids_cell(plan, entry)
	_execute(f, plan)
	assert_eq(f.mage.current_hp, 76)
	assert_false(f.mage.has_status(&"burn"))


func test_one_network_exit_blocking_projectiles_prevents_an_unreliable_axiom() -> void:
	var entry := Vector2i(1, 2)
	var f := _field(Vector2i(0, 2), Vector2i(8, 2), {}, [entry, Vector2i(5, 1), Vector2i(5, 2)])
	f.grid.set_terrain_properties(Vector2i(6, 1), {"transparent": true, "projectile_passable": false})
	var plan: Array = f.ai.decide(f.mage, f.units)
	assert_eq(plan[0].type, "move")
	assert_eq(plan[0].path.back(), entry)
	assert_eq(_spell_ids(plan), [&"philosopher_aporia"], "A projectile blocked from one possible exit is not reliable.")
	_execute(f, plan)


func test_voluntary_electrified_water_is_not_used_as_a_shortcut_before_casting() -> void:
	var electric := Vector2i(1, 2)
	var f := _field(Vector2i(0, 2), Vector2i(6, 2), {electric: &"electrified_water"})
	var plan: Array = f.ai.decide(f.mage, f.units)
	_assert_avoids_cell(plan, electric)
	assert_false(_spell_ids(plan).is_empty())
	_execute(f, plan)
	assert_eq(f.mage.current_hp, 76)
	assert_false(f.mage.has_status(&"shock"))


func test_water_corridor_is_traversed_when_it_is_the_useful_affordable_route() -> void:
	var f := _field(Vector2i(0, 0), Vector2i(7, 0), {Vector2i(1, 0): &"water"}, [], Vector2i(10, 1))
	var plan: Array = f.ai.decide(f.mage, f.units)
	assert_eq(plan[0].type, "move")
	assert_true(plan[0].path.has(Vector2i(1, 0)))
	assert_eq(f.pathfinder.path_movement_cost(plan[0].path, f.mage), 3)
	_execute(f, plan)
	assert_eq(f.mage.grid_pos, Vector2i(3, 0))
	assert_eq(f.mage.current_mp, 0, "Water changes next-turn MP, not this path's entry cost.")
	assert_true(f.mage.has_status(&"wet"))
	f.mage.start_turn()
	f.mage.process_statuses()
	assert_eq(f.mage.current_mp, 2)


func test_single_vortex_grants_its_real_impulse_without_spending_unearned_mp() -> void:
	var entry := Vector2i(1, 2)
	var f := _field(Vector2i(0, 2), Vector2i(7, 2), {}, [entry])
	var plan: Array = f.ai.decide(f.mage, f.units)
	assert_eq(plan[0].type, "move")
	assert_true(plan[0].path.has(entry))
	assert_eq(f.pathfinder.path_movement_cost(plan[0].path, f.mage), 3)
	_execute(f, plan)
	assert_eq(f.mage.grid_pos, Vector2i(3, 2))
	assert_eq(f.mage.current_mp, 1, "The canonical singleton impulse refunds one MP only on actual entry.")


func test_low_health_mage_does_not_plan_a_lethal_fire_crossing_before_healing() -> void:
	var f := _field(Vector2i(0, 0), Vector2i(7, 0), {Vector2i(1, 0): &"lava"}, [], Vector2i(10, 1))
	f.mage.take_damage(66)
	var plan: Array = f.ai.decide(f.mage, f.units)
	_assert_avoids_cell(plan, Vector2i(1, 0))
	assert_eq(_spell_ids(plan)[0], &"philosopher_mending")
	_execute(f, plan)
	assert_true(f.mage.is_alive)
	assert_eq(f.mage.current_hp, 32)


func test_network_with_only_one_unoccupied_exit_can_target_its_known_self_cell() -> void:
	var entry := Vector2i(1, 2)
	var exit := Vector2i(5, 2)
	var blocked := Vector2i(5, 1)
	var f := _field(Vector2i(0, 2), Vector2i(8, 2), {}, [entry, exit, blocked])
	var network_cells: Array[Vector2i] = [entry, exit, blocked]
	f.grid.set_vortex_network(&"fixture_single_exit", network_cells, 2, true)
	var occupant := Factory.make_unit("Sortie bloquee", 0)
	f.grid.place_unit(occupant, blocked)
	f.units.append(occupant)
	var plan: Array = f.ai.decide(f.mage, f.units)
	assert_eq(plan[0].type, "move")
	assert_eq(plan[0].path.back(), entry)
	assert_true(_spell_ids(plan).has(&"philosopher_aegis"))
	for action in plan:
		if action.type == "cast" and action.spell.shield_grant > 0:
			assert_eq(action.cell, exit)
	_execute(f, plan)
	assert_eq(f.mage.grid_pos, exit)
	assert_eq(f.mage.current_shield, 20)
	assert_eq(f.mage.current_ap, 0)
