extends GutTest

const Factory = preload("res://test/support/factory.gd")
const PARIS: UnitData = preload("res://data/units/enemies/catabase_shadow_paris.tres")
const CATALOG = preload("res://data/characters/paris/attack_classifications.tres")
const ARROW: Spell = preload("res://data/spells/enemies/paris/spectral_arrow.tres")
const FIRE: Spell = preload("res://data/spells/enemies/paris/fire_arrow.tres")
const ICE: Spell = preload("res://data/spells/enemies/paris/ice_arrow.tres")
const VORTEX: Spell = preload("res://data/spells/enemies/paris/vortex_arrow.tres")
const STEP: Spell = preload("res://data/spells/enemies/paris/vortex_step.tres")
const WHIP: Spell = preload("res://data/spells/enemies/paris/infernal_whip.tres")
const SWEEP: Spell = preload("res://data/spells/enemies/paris/infernal_sweep.tres")
const PULL: Spell = preload("res://data/spells/enemies/paris/infernal_pull.tres")


func _field(paris_cell := Vector2i(1, 3), hero_cell := Vector2i(5, 3), tiles: Dictionary = {}, portals: Array[Vector2i] = [], obstacles: Array[ArenaObstacleDefinition] = []) -> Dictionary:
	var arena := ArenaDefinition.new()
	arena.set_identity("Paris gameplay fixture", "paris_gameplay_fixture")
	arena.grid_size = Vector2i(12, 8)
	for y in range(8):
		for x in range(12):
			var cell := Vector2i(x, y)
			ArenaTerrainRegistry.configure_cell(arena.ensure_cell(cell), tiles.get(cell, &"neutral"))
	if not portals.is_empty():
		var network := ArenaVortexNetworkService.create_network(arena)
		network.cells = portals.duplicate()
	arena.obstacles.assign(obstacles)
	assert_true(ArenaRuntimeBridge.sync_runtime_resources(arena))
	var runtime := ArenaRuntimeProjectionService.build(arena)
	runtime.terrain_effects.runtime_service.configure_resolution_context(42, 1)
	var grid := runtime.grid
	var pathfinder := Pathfinder.new(grid)
	var caster := SpellCaster.new(grid, pathfinder, runtime.terrain_effects)
	assert_true(caster.set_action_classification_catalog(CATALOG))
	var paris := Unit.from_data(PARIS)
	var hero := Unit.new("Achille", 0, 400, 10, 6, 3, 20)
	assert_true(grid.place_unit(paris, paris_cell))
	assert_true(grid.place_unit(hero, hero_cell))
	paris.start_turn()
	return {"grid": grid, "pathfinder": pathfinder, "terrain": runtime.terrain_effects,
		"caster": caster, "paris": paris, "hero": hero, "units": [paris, hero],
		"ai": EnemyAI.new(grid, pathfinder, caster)}


func _spell_ids(plan: Array) -> Array[StringName]:
	var result: Array[StringName] = []
	for action in plan:
		if action.type == "cast":
			result.append((action.spell as Spell).get_effective_spell_id())
	return result


func _execute(f: Dictionary, plan: Array) -> void:
	for action in plan:
		if action.type == "cast":
			assert_true(f.caster.can_cast(f.paris, action.spell, action.cell), str(action))
			var report: Dictionary = f.caster.cast(f.paris, action.spell, action.cell)
			assert_false(report.get("failed", false), str(report))
		elif action.type == "move":
			var path: Array = action.path
			assert_true(f.paris.spend_mp(f.pathfinder.path_movement_cost(path, f.paris)))
			f.terrain.begin_unit_resolution(f.paris, &"movement")
			for index in range(1, path.size()):
				assert_true(f.grid.relocate_unit(f.paris, path[index]))
				var entry: Dictionary = f.terrain.consume_last_entry_result(f.paris)
				if entry.get("end_movement", false) or not f.paris.is_alive:
					break
			f.terrain.end_unit_resolution(f.paris)


func test_complete_kit_and_unambiguous_form_threshold() -> void:
	assert_eq(PARIS.get_effective_unit_id(), &"catabase_shadow_paris")
	assert_eq([PARIS.max_hp, PARIS.max_ap, PARIS.max_mp], [120, 4, 3])
	assert_eq(PARIS.spells, [ARROW, FIRE, ICE, VORTEX, STEP])
	assert_eq(PARIS.combat_form_change.spells, [WHIP, SWEEP, PULL, STEP])
	assert_true(PARIS.combat_form_change.is_valid())
	assert_eq(PARIS.combat_form_change.below_hp_percent, 20)
	assert_eq(PARIS.combat_form_change.shield_grant, 30)


func test_exactly_twenty_percent_does_not_transform_but_next_real_damage_does() -> void:
	var paris := Unit.from_data(PARIS)
	var events: Array = []
	paris.combat_form_changed.connect(func(unit, old_form, new_form): events.append([unit.get_instance_id(), old_form, new_form]))
	paris.take_damage(96)
	assert_eq(paris.current_hp, 24)
	assert_eq(paris.combat_form_id, &"spectral")
	assert_true(events.is_empty())
	paris.take_damage(1)
	assert_eq(paris.current_hp, 23, "Transformation never heals the real damage.")
	assert_eq(paris.current_shield, 30)
	assert_eq(events, [[paris.get_instance_id(), &"spectral", &"infernal"]])
	assert_eq(paris.spells, [WHIP, SWEEP, PULL, STEP])


func test_nineteen_percent_of_original_hp_triggers_once() -> void:
	var paris := Unit.from_data(PARIS)
	paris.take_damage(98)
	assert_eq(paris.current_hp, 22)
	assert_eq(paris.combat_form_id, &"infernal")
	paris.take_damage(20)
	assert_eq(paris.current_shield, 10)
	paris.heal(60)
	paris.take_damage(70)
	assert_eq(paris.current_hp, 22)
	assert_eq(paris.current_shield, 0, "Dropping below the threshold again never refills the carapace.")
	assert_eq(paris.combat_form_id, &"infernal")


func test_transformation_preserves_identity_cell_resources_and_statuses() -> void:
	var f := _field()
	var paris := f.paris as Unit
	var identity := paris.get_instance_id()
	var stable_id := paris.get_runtime_stable_id()
	paris.spend_ap(1)
	paris.spend_mp(1)
	paris.apply_status(ICE.applied_status)
	var status_count := paris.get_active_statuses().size()
	paris.take_damage(97)
	assert_eq(paris.get_instance_id(), identity)
	assert_eq(paris.get_runtime_stable_id(), stable_id)
	assert_eq(paris.grid_pos, Vector2i(1, 3))
	assert_same(f.grid.get_unit(paris.grid_pos), paris)
	assert_eq([paris.current_ap, paris.current_mp, paris.activation_index], [3, 2, 1])
	assert_eq(paris.get_active_statuses().size(), status_count)
	assert_true(paris.has_status(&"frozen"))
	assert_eq(paris.max_hp.get_int(), 120)
	assert_eq(paris.initiative.get_int(), 9)


func test_lethal_hit_dies_without_transformation_or_resurrection() -> void:
	var paris := Unit.from_data(PARIS)
	var events: Array = []
	paris.combat_form_changed.connect(func(_unit, old_form, new_form): events.append([old_form, new_form]))
	paris.take_damage(120)
	assert_false(paris.is_alive)
	assert_eq(paris.current_hp, 0)
	assert_eq(paris.current_shield, 0)
	assert_true(events.is_empty())
	assert_false(paris._try_combat_form_change())


func test_periodic_damage_crosses_threshold_with_the_same_rules() -> void:
	var paris := Unit.from_data(PARIS)
	paris.take_damage(92)
	paris.apply_status(FIRE.applied_status)
	paris.start_turn()
	paris.process_statuses()
	assert_eq(paris.current_hp, 22)
	assert_eq(paris.combat_form_id, &"infernal")
	assert_eq(paris.current_shield, 30)
	assert_true(paris.has_status(&"burn"), "Transformation does not cleanse the initiating burn.")


func test_lethal_periodic_damage_does_not_transform() -> void:
	var paris := Unit.from_data(PARIS)
	paris.take_damage(96)
	var poison := StatusData.new()
	poison.status_id = &"paris_test_lethal_dot"
	poison.damage_per_turn = 30
	paris.apply_status(poison)
	paris.start_turn()
	paris.process_statuses()
	assert_false(paris.is_alive)
	assert_eq(paris.combat_form_id, &"spectral")
	assert_eq(paris.current_shield, 0)


func test_max_hp_modifiers_do_not_move_the_original_threshold() -> void:
	var paris := Unit.from_data(PARIS)
	paris.max_hp.base_value = 200
	paris.take_damage(81)
	assert_eq(paris.current_hp, 39)
	assert_eq(paris.combat_form_id, &"spectral", "39/200 is below 20%, but 39/120 is not.")
	paris.take_damage(16)
	assert_eq(paris.combat_form_id, &"infernal")
	assert_eq(paris.max_hp.get_int(), 200)


func test_shield_absorption_is_not_hp_loss_or_an_early_transformation() -> void:
	var paris := Unit.from_data(PARIS)
	paris.take_damage(96)
	paris.add_shield(10)
	paris.take_damage(10)
	assert_eq(paris.current_hp, 24)
	assert_eq(paris.combat_form_id, &"spectral")


func test_units_without_form_data_keep_the_original_behavior() -> void:
	var unit := Factory.make_unit()
	unit.take_damage(95)
	assert_eq(unit.current_hp, 5)
	assert_eq(unit.combat_form_id, &"")
	assert_eq(unit.current_shield, 0)


func test_old_form_actions_are_rejected_before_costs_and_after_commit() -> void:
	var f := _field()
	var context: CastContext = f.caster.begin_cast(f.paris, ARROW, f.hero.grid_pos)
	assert_eq(f.paris.current_ap, 2)
	f.paris.take_damage(97)
	assert_eq(f.paris.get_spell_availability_reason(ARROW), &"combat_form")
	var hp_before: int = f.hero.current_hp
	var report: Dictionary = f.caster.resolve_cast(context)
	assert_true(report.failed)
	assert_eq(f.hero.current_hp, hp_before)
	assert_eq(f.paris.current_ap, 2, "An already committed old arrow is cancelled without refunding resources.")
	assert_eq(f.caster.resolve_cast(context), report)
	assert_eq(f.paris.current_ap, 2)
	assert_false(f.caster.can_cast(f.paris, ARROW, f.hero.grid_pos))
	assert_true(f.paris.can_use_spell(WHIP))
	assert_true(f.paris.can_use_spell(STEP))


func test_transform_cancels_a_prepared_delayed_old_form_spell() -> void:
	var f := _field()
	var delayed := ARROW.duplicate() as Spell
	delayed.spell_id = &"paris_test_prepared_arrow"
	delayed.delayed_resolution = Spell.DelayedResolution.RANGED_STRIKE
	f.caster.cast(f.paris, delayed, f.hero.grid_pos)
	assert_false(f.paris.pending_ability.is_empty())
	f.paris.take_damage(97)
	assert_true(f.paris.pending_ability.is_empty())
	var report: Dictionary = f.caster.resolve_pending_activation(f.paris)
	assert_false(report.had_pending)
	assert_eq(f.hero.current_hp, 400)


func test_fire_arrow_applies_real_damage_burn_and_two_round_surface() -> void:
	var f := _field()
	var report: Dictionary = f.caster.cast(f.paris, FIRE, f.hero.grid_pos)
	assert_false(report.get("failed", false))
	assert_eq(f.hero.current_hp, 380, "12 arrow damage + 8 immediate new fire entry.")
	assert_true(f.hero.has_status(&"burn"))
	assert_true(report.terrain_changed.has(f.hero.grid_pos))
	assert_eq(f.terrain.get_effect_data(f.hero.grid_pos).surface_id, &"fire")
	f.terrain.tick_all_effects()
	assert_not_null(f.terrain.get_effect_data(f.hero.grid_pos))
	f.terrain.tick_all_effects()
	assert_null(f.terrain.get_effect_data(f.hero.grid_pos))


func test_ice_arrow_applies_one_activation_slow_and_real_ice() -> void:
	var f := _field()
	f.caster.cast(f.paris, ICE, f.hero.grid_pos)
	assert_eq(f.hero.current_hp, 390)
	assert_true(f.hero.has_status(&"frozen"))
	assert_eq(f.terrain.get_effect_data(f.hero.grid_pos).surface_id, &"ice")
	f.hero.start_turn()
	assert_false(f.hero.process_statuses())
	assert_eq(f.hero.current_mp, 2)
	f.hero.tick_statuses()
	f.hero.start_turn()
	f.hero.process_statuses()
	assert_eq(f.hero.current_mp, 3)


func test_elemental_arrows_react_with_water_and_do_not_rewrite_permanent_map() -> void:
	var cell := Vector2i(5, 3)
	var f := _field(Vector2i(1, 3), cell, {cell: &"water"})
	f.caster.cast(f.paris, ICE, cell)
	assert_eq(f.terrain.get_surface_state(cell).base_terrain_id, &"water")
	assert_eq(f.terrain.get_effect_data(cell).surface_id, &"ice")
	f.terrain.tick_all_effects()
	f.terrain.tick_all_effects()
	assert_eq(f.terrain.get_surface_state(cell).base_terrain_id, &"water")
	assert_eq(f.terrain.get_effect_data(cell).surface_id, &"water")


func test_vortex_arrow_pulls_onto_fire_with_real_additional_damage() -> void:
	var landing := Vector2i(4, 3)
	var f := _field(Vector2i(1, 3), Vector2i(5, 3), {landing: &"lava"})
	var report: Dictionary = f.caster.cast(f.paris, VORTEX, f.hero.grid_pos)
	assert_false(report.get("failed", false))
	assert_eq(f.hero.grid_pos, landing)
	assert_eq(f.hero.current_hp, 377, "8 arrow damage + 15 permanent lava entry.")
	assert_true(f.hero.has_status(&"burn"))
	assert_true(report.landed_on_terrain)


func test_vortex_arrow_pulls_into_a_real_portal_exit() -> void:
	var entry := Vector2i(4, 3)
	var exit := Vector2i(9, 5)
	var f := _field(Vector2i(1, 3), Vector2i(5, 3), {}, [entry, exit])
	f.caster.cast(f.paris, VORTEX, f.hero.grid_pos)
	assert_eq(f.hero.grid_pos, exit)
	assert_same(f.grid.get_unit(exit), f.hero)
	assert_null(f.grid.get_unit(Vector2i(5, 3)))


func test_vortex_step_is_a_real_teleport_with_paid_ap_and_destination_water() -> void:
	var origin := Vector2i(1, 3)
	var destination := Vector2i(4, 3)
	var f := _field(origin, Vector2i(8, 3), {destination: &"water"})
	var report: Dictionary = f.caster.cast(f.paris, STEP, destination)
	assert_false(report.get("failed", false))
	assert_eq(f.paris.grid_pos, destination)
	assert_null(f.grid.get_unit(origin))
	assert_same(f.grid.get_unit(destination), f.paris)
	assert_eq(f.paris.current_ap, 2)
	assert_eq(f.paris.current_mp, 3, "The spell spends AP, not walking MP.")
	assert_true(f.paris.has_status(&"wet"))
	assert_eq(report.caster_movement_from, origin)
	assert_eq(report.caster_movement_to, destination)
	assert_true(report.landed_on_terrain)


func test_vortex_step_reports_actual_portal_destination_and_runs_entry_once() -> void:
	var entry := Vector2i(4, 3)
	var exit := Vector2i(9, 5)
	var f := _field(Vector2i(1, 3), Vector2i(8, 3), {exit: &"lava"}, [entry, exit])
	var report: Dictionary = f.caster.cast(f.paris, STEP, entry)
	assert_eq(f.paris.grid_pos, exit)
	assert_eq(report.caster_movement_to, exit)
	assert_eq(f.paris.current_hp, 105, "Exit lava damage is applied exactly once.")
	assert_eq(f.paris.current_ap, 2)
	assert_false(f.caster.can_cast(f.paris, STEP, Vector2i(7, 5)))


func test_teleport_rejects_occupied_hole_and_out_of_range_without_spending() -> void:
	var f := _field(Vector2i(1, 3), Vector2i(4, 3), {Vector2i(3, 3): &"hole"})
	for destination in [Vector2i(4, 3), Vector2i(3, 3), Vector2i(11, 7)]:
		assert_false(f.caster.can_cast(f.paris, STEP, destination))
		var report: Dictionary = f.caster.cast(f.paris, STEP, destination)
		assert_true(report.failed)
	assert_eq(f.paris.current_ap, 4)
	assert_eq(f.paris.grid_pos, Vector2i(1, 3))


func test_ai_casts_ice_and_fire_then_spectral_on_cooldown_without_mutation() -> void:
	var f := _field()
	var initial_hp: int = f.hero.current_hp
	var plan: Array = f.ai.decide(f.paris, f.units)
	assert_eq(_spell_ids(plan), [&"paris_ice_arrow", &"paris_fire_arrow"])
	assert_eq(f.paris.current_ap, 4)
	assert_eq(f.hero.current_hp, initial_hp)
	_execute(f, plan)
	assert_eq(f.paris.current_ap, 0)
	f.paris.start_turn()
	var next: Array = f.ai.decide(f.paris, f.units)
	assert_eq(_spell_ids(next), [&"paris_spectral_arrow", &"paris_spectral_arrow"])
	_execute(f, next)
	assert_eq(f.paris.current_ap, 0)


func test_ai_uses_terrain_pull_before_arrows() -> void:
	var f := _field(Vector2i(1, 3), Vector2i(5, 3), {Vector2i(4, 3): &"lava"})
	var plan: Array = f.ai.decide(f.paris, f.units)
	assert_eq(_spell_ids(plan)[0], &"paris_vortex_arrow")
	assert_eq(_spell_ids(plan).size(), 1, "Do not invent the displaced target position for a second arrow.")
	_execute(f, plan)
	assert_eq(f.hero.grid_pos, Vector2i(4, 3))


func test_ai_teleports_out_of_contact_and_fires_from_real_new_cell() -> void:
	var f := _field(Vector2i(3, 3), Vector2i(4, 3))
	var plan: Array = f.ai.decide(f.paris, f.units)
	assert_eq(_spell_ids(plan)[0], &"paris_vortex_step")
	assert_eq(_spell_ids(plan).size(), 2)
	var destination: Vector2i = plan[0].cell
	_execute(f, plan)
	assert_eq(f.paris.grid_pos, destination)
	assert_eq(f.paris.current_ap, 0)
	assert_eq(f.paris.current_mp, 3)
	assert_lt(f.hero.current_hp, 400)


func test_infernal_ai_closes_distance_by_teleport_and_uses_whip() -> void:
	var f := _field(Vector2i(1, 3), Vector2i(7, 3))
	f.paris.take_damage(97)
	var plan: Array = f.ai.decide(f.paris, f.units)
	assert_eq(_spell_ids(plan), [&"paris_vortex_step", &"paris_infernal_whip"])
	_execute(f, plan)
	assert_eq(f.hero.current_hp, 380)
	assert_eq(f.paris.current_ap, 0)
	assert_eq(f.paris.current_hp, 23)


func test_infernal_aoe_spares_allies_direct_impact_but_ground_fire_affects_everyone() -> void:
	var f := _field(Vector2i(1, 3), Vector2i(4, 3))
	var other := Factory.make_unit("Second hero", 0)
	var ally := Factory.make_unit("Spectre allié", 1)
	f.grid.place_unit(other, Vector2i(4, 2))
	f.grid.place_unit(ally, Vector2i(4, 4))
	f.units.append_array([other, ally])
	f.paris.take_damage(97)
	var plan: Array = f.ai.decide(f.paris, f.units)
	assert_eq(_spell_ids(plan)[0], &"paris_infernal_sweep")
	var report: Dictionary = f.caster.cast(f.paris, SWEEP, f.hero.grid_pos)
	assert_false(report.get("failed", false))
	assert_eq(f.hero.current_hp, 378)
	assert_eq(other.current_hp, 78)
	assert_eq(ally.current_hp, 92, "The direct 14 damage spares allies; the actual floor fire still deals 8.")
	assert_eq(f.paris.current_hp, 23)


func test_arrow_projectiles_respect_opaque_obstacles() -> void:
	# A non-walkable terrain cell is not necessarily opaque. The canonical
	# FULL_WALL obstacle owns all three independent collision properties.
	var wall := ArenaObstacleDefinition.new()
	wall.cell = Vector2i(3, 3)
	wall.apply_preset(ArenaObstacleDefinition.Preset.FULL_WALL)
	var f := _field(Vector2i(1, 3), Vector2i(5, 3), {}, [], [wall])
	assert_false(f.grid.is_walkable(wall.cell))
	assert_false(f.pathfinder.has_line_of_sight(f.paris.grid_pos, f.hero.grid_pos))
	assert_false(f.pathfinder.has_projectile_path(f.paris.grid_pos, f.hero.grid_pos))
	for spell in [ARROW, FIRE, ICE, VORTEX]:
		assert_eq(f.caster.get_action_classification(spell), &"PROJECTILE")
		assert_false(f.caster.can_cast(f.paris, spell, f.hero.grid_pos))
	assert_eq(f.paris.current_ap, 4)


func test_initial_shield_absorption_report_survives_transformation_carapace() -> void:
	var f := _field()
	f.paris.take_damage(90)
	f.paris.add_shield(10)
	var attack := Factory.make_spell({"damage": 17, "spell_range": 7, "ap_cost": 2})
	var report: Dictionary = f.caster.cast(f.hero, attack, f.paris.grid_pos)
	assert_false(report.get("failed", false))
	assert_eq(f.paris.current_hp, 23)
	assert_eq(f.paris.current_shield, 30)
	assert_eq(report.hp_damage_total, 7)
	assert_eq(report.shield_absorbed_total, 10)


func test_infernal_single_target_turn_varies_whip_and_sweep() -> void:
	var f := _field(Vector2i(1, 3), Vector2i(3, 3))
	f.paris.take_damage(97)
	var plan: Array = f.ai.decide(f.paris, f.units)
	assert_eq(_spell_ids(plan), [&"paris_infernal_whip", &"paris_infernal_sweep"])
	_execute(f, plan)
	assert_eq(f.hero.current_hp, 358, "20 whip + 14 sweep + 8 new fire.")
	assert_eq(f.paris.current_ap, 0)


func test_shared_teleport_cooldown_is_not_reset_by_transformation() -> void:
	var f := _field(Vector2i(1, 3), Vector2i(8, 3))
	f.caster.cast(f.paris, STEP, Vector2i(4, 3))
	var cooldown: int = f.paris.get_spell_cooldown_remaining(STEP)
	f.paris.take_damage(97)
	assert_eq(f.paris.get_spell_cooldown_remaining(STEP), cooldown)
	assert_eq(f.paris.get_spell_uses(STEP), 1)
	assert_eq(f.paris.current_ap, 2)
	assert_false(f.paris.can_use_spell(STEP))


func test_real_ice_then_fire_arrows_melt_to_water_instead_of_stacking_hazards() -> void:
	var f := _field()
	f.caster.cast(f.paris, ICE, f.hero.grid_pos)
	f.caster.cast(f.paris, FIRE, f.hero.grid_pos)
	assert_eq(f.terrain.get_effect_data(f.hero.grid_pos).surface_id, &"water")
	assert_eq(f.hero.current_hp, 378, "10 ice + 12 fire; the melted surface is not an extra fire hit.")


func test_arrows_respect_projectile_barriers_even_when_line_of_sight_is_clear() -> void:
	var barrier := ArenaObstacleDefinition.new()
	barrier.cell = Vector2i(3, 3)
	barrier.apply_preset(ArenaObstacleDefinition.Preset.PASSABLE_DECOR)
	barrier.blocks_projectiles = true
	var f := _field(Vector2i(1, 3), Vector2i(5, 3), {}, [], [barrier])
	assert_true(f.pathfinder.has_line_of_sight(f.paris.grid_pos, f.hero.grid_pos))
	assert_false(f.pathfinder.has_projectile_path(f.paris.grid_pos, f.hero.grid_pos))
	for spell in [ARROW, FIRE, ICE, VORTEX]:
		assert_eq(f.caster.get_action_classification(spell), &"PROJECTILE")
		assert_false(f.caster.can_cast(f.paris, spell, f.hero.grid_pos))
	assert_eq(f.paris.current_ap, 4)


func test_low_map_obstacles_do_not_falsely_block_arrows() -> void:
	var low := ArenaObstacleDefinition.new()
	low.cell = Vector2i(3, 3)
	low.apply_preset(ArenaObstacleDefinition.Preset.LOW_OBSTACLE)
	var f := _field(Vector2i(1, 3), Vector2i(5, 3), {}, [], [low])
	assert_false(f.grid.is_walkable(low.cell))
	assert_true(f.pathfinder.has_line_of_sight(f.paris.grid_pos, f.hero.grid_pos))
	assert_true(f.pathfinder.has_projectile_path(f.paris.grid_pos, f.hero.grid_pos))
	for spell in [ARROW, FIRE, ICE, VORTEX]:
		assert_true(f.caster.can_cast(f.paris, spell, f.hero.grid_pos))
	assert_eq(f.paris.current_ap, 4)
