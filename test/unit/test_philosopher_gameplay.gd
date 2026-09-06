extends GutTest

const Factory = preload("res://test/support/factory.gd")
const MAGE: UnitData = preload("res://data/units/enemies/philosopher_mage.tres")
const AXIOM: Spell = preload("res://data/spells/enemies/philosopher_axiom.tres")
const REFUTATION: Spell = preload("res://data/spells/enemies/philosopher_refutation.tres")
const MENDING: Spell = preload("res://data/spells/enemies/philosopher_mending.tres")
const APORIA: Spell = preload("res://data/spells/enemies/philosopher_aporia.tres")
const AEGIS: Spell = preload("res://data/spells/enemies/philosopher_aegis.tres")
const TRIAL: RunData = preload("res://data/runs/philosopher_trial.tres")


class MinimumRangeWard:
	extends SpellModifier

	func get_minimum_range_override(_caster, _spell) -> int:
		return 4


func _field(mage_cell := Vector2i(1, 2), hero_cell := Vector2i(5, 2)) -> Dictionary:
	var field := Factory.make_battlefield(10, 6)
	assert_true(field.caster.set_action_classification_catalog(TRIAL.action_classification_catalog))
	var mage := Unit.from_data(MAGE)
	var hero := Factory.make_unit("Achille", 0)
	field.grid.place_unit(mage, mage_cell)
	field.grid.place_unit(hero, hero_cell)
	mage.start_turn()
	return {"grid": field.grid, "pathfinder": field.pathfinder, "caster": field.caster,
		"mage": mage, "hero": hero, "units": [mage, hero],
		"ai": EnemyAI.new(field.grid, field.pathfinder, field.caster)}


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
			assert_true(f.mage.spend_mp(cost))
			for index in range(1, path.size()):
				assert_true(f.grid.is_walkable(path[index], f.mage))
				f.grid.move_unit(f.mage.grid_pos, path[index])
		elif action.type == "cast":
			assert_true(f.caster.can_cast(f.mage, action.spell, action.cell), str(action))
			var report: Dictionary = f.caster.cast(f.mage, action.spell, action.cell)
			assert_false(report.get("failed", false), str(report))


func test_complete_enemy_has_five_spells_and_every_semantic_clip() -> void:
	assert_eq([MAGE.max_hp, MAGE.max_ap, MAGE.max_mp], [76, 4, 3])
	assert_eq(MAGE.ai_profile.strategy, EnemyAIProfile.Strategy.SUPPORT_MAGE)
	assert_eq(MAGE.spells, [AXIOM, REFUTATION, MENDING, APORIA, AEGIS])
	assert_false(MAGE.basic_attack_enabled)
	for pair in [["idle", "idle"], ["walk", "walk"], ["hit", "hit"], ["death", "death"],
		["cast:philosopher_axiom", "attack"], ["cast:philosopher_refutation", "control"],
		["cast:philosopher_mending", "heal"], ["cast:philosopher_aporia", "control"],
		["cast:philosopher_aegis", "shield"]]:
		assert_eq(MAGE.animation_set.get_animation_name(pair[0]), StringName(pair[1]))
	assert_true(MAGE.preview_sprite_frames.has_animation(&"idle_E"))


func test_ai_controls_then_attacks_and_spends_exactly_four_ap() -> void:
	var f := _field()
	var plan: Array = f.ai.decide(f.mage, f.units)
	assert_eq(_spell_ids(plan), [&"philosopher_aporia", &"philosopher_axiom"])
	assert_eq(f.mage.current_ap, 4, "Planning spends nothing.")
	assert_eq(f.mage.grid_pos, Vector2i(1, 2), "Planning moves nothing.")
	_execute(f, plan)
	assert_eq(f.mage.current_ap, 0)
	assert_eq(f.hero.current_hp, 84)
	assert_true(f.hero.has_status(&"philosopher_aporia"))
	assert_true(f.ai.decide(f.mage, f.units).is_empty())


func test_aporia_reduces_only_one_activation_of_movement() -> void:
	var f := _field()
	f.caster.cast(f.mage, APORIA, f.hero.grid_pos)
	f.hero.start_turn()
	assert_false(f.hero.process_statuses(), "Aporia never skips the turn.")
	assert_eq(f.hero.current_mp, 1)
	assert_eq(f.hero.current_ap, 6)
	f.hero.tick_statuses()
	assert_false(f.hero.has_status(&"philosopher_aporia"))
	f.hero.start_turn()
	f.hero.process_statuses()
	assert_eq(f.hero.current_mp, 3)


func test_ai_heals_wounded_self_before_control() -> void:
	var f := _field()
	f.mage.take_damage(30)
	var plan: Array = f.ai.decide(f.mage, f.units)
	assert_eq(_spell_ids(plan), [&"philosopher_mending", &"philosopher_aporia"])
	assert_eq(plan[0].cell, f.mage.grid_pos)
	_execute(f, plan)
	assert_eq(f.mage.current_hp, 68)
	assert_eq(f.mage.current_ap, 0)


func test_ai_heals_an_ally_in_range_even_if_more_wounded_ally_is_unreachable() -> void:
	var f := _field()
	var reachable := Unit.new("Spectre proche", 1, 64)
	var distant := Unit.new("Spectre éloigné", 1, 64)
	f.grid.place_unit(reachable, Vector2i(2, 3))
	f.grid.place_unit(distant, Vector2i(9, 5))
	reachable.take_damage(24)
	distant.take_damage(50)
	f.units.append_array([reachable, distant])
	var plan: Array = f.ai.decide(f.mage, f.units)
	assert_eq(_spell_ids(plan)[0], &"philosopher_mending")
	assert_eq(plan[0].cell, reachable.grid_pos)
	_execute(f, plan)
	assert_eq(reachable.current_hp, 62)
	assert_eq(distant.current_hp, 14)


func test_ai_does_not_heal_full_health_or_refresh_an_existing_aporia() -> void:
	var f := _field()
	f.hero.apply_status(APORIA.applied_status)
	var plan: Array = f.ai.decide(f.mage, f.units)
	assert_eq(_spell_ids(plan), [&"philosopher_axiom", &"philosopher_axiom"])
	_execute(f, plan)
	assert_eq(f.hero.current_hp, 68)


func test_ai_shields_the_exposed_ally_and_control_stays_legal() -> void:
	var f := _field(Vector2i(1, 2), Vector2i(4, 2))
	var ally := Unit.new("Spectre", 1, 64)
	f.grid.place_unit(ally, Vector2i(3, 3))
	f.units.append(ally)
	var plan: Array = f.ai.decide(f.mage, f.units)
	assert_eq(_spell_ids(plan), [&"philosopher_aegis", &"philosopher_aporia"])
	assert_eq(plan[0].cell, ally.grid_pos)
	_execute(f, plan)
	assert_eq(ally.current_shield, 20)
	assert_eq(f.mage.current_shield, 0)


func test_aegis_absorbs_damage_and_expires_on_beneficiary_activation() -> void:
	var f := _field()
	f.caster.cast(f.mage, AEGIS, f.mage.grid_pos)
	assert_eq(f.mage.current_shield, 20)
	f.mage.take_damage(12)
	assert_eq(f.mage.current_hp, 76)
	assert_eq(f.mage.current_shield, 8)
	f.mage.start_turn()
	assert_eq(f.mage.current_shield, 8)
	f.mage.start_turn()
	assert_eq(f.mage.current_shield, 0)


func test_refutation_pushes_once_without_planning_an_attack_at_the_old_cell() -> void:
	var f := _field(Vector2i(1, 2), Vector2i(2, 2))
	var plan: Array = f.ai.decide(f.mage, f.units)
	assert_eq(_spell_ids(plan), [&"philosopher_refutation", &"philosopher_aegis"])
	_execute(f, plan)
	assert_eq(f.hero.grid_pos, Vector2i(3, 2))
	assert_eq(f.hero.current_hp, 92)
	assert_eq(f.mage.current_shield, 20)
	assert_eq(f.mage.current_ap, 0)


func test_push_stops_at_walls_and_never_spends_an_extra_cast() -> void:
	var f := _field(Vector2i(1, 2), Vector2i(2, 2))
	f.grid.set_type(Vector2i(3, 2), GridData.CellType.WALL)
	_execute(f, f.ai.decide(f.mage, f.units))
	assert_eq(f.hero.grid_pos, Vector2i(2, 2))
	assert_eq(f.mage.current_ap, 0)
	assert_eq(f.hero.current_hp, 92)


func test_cooldowns_block_following_activation_then_reopen() -> void:
	var f := _field()
	f.caster.cast(f.mage, APORIA, f.hero.grid_pos)
	f.caster.cast(f.mage, AEGIS, f.mage.grid_pos)
	f.mage.start_turn()
	assert_false(f.mage.can_use_spell(APORIA))
	assert_false(f.mage.can_use_spell(AEGIS))
	var plan: Array = f.ai.decide(f.mage, f.units)
	assert_eq(_spell_ids(plan), [&"philosopher_axiom", &"philosopher_axiom"])
	f.mage.start_turn()
	assert_true(f.mage.can_use_spell(APORIA))
	assert_true(f.mage.can_use_spell(AEGIS))


func test_ai_moves_into_range_then_resolves_both_casts_without_projected_mutation() -> void:
	var f := _field(Vector2i(0, 2), Vector2i(7, 2))
	var plan: Array = f.ai.decide(f.mage, f.units)
	assert_eq(plan[0].type, "move")
	assert_eq(_spell_ids(plan), [&"philosopher_aporia", &"philosopher_axiom"])
	assert_eq(f.mage.grid_pos, Vector2i(0, 2))
	assert_same(f.grid.get_unit(Vector2i(0, 2)), f.mage)
	assert_eq([f.mage.current_ap, f.mage.current_mp], [4, 3])
	_execute(f, plan)
	assert_eq([f.mage.current_ap, f.mage.current_mp], [0, 0])
	assert_eq(f.hero.current_hp, 84)


func test_insufficient_ap_never_produces_an_unaffordable_spell() -> void:
	var f := _field()
	f.mage.current_ap = 1
	assert_true(f.ai.decide(f.mage, f.units).is_empty())
	f.mage.current_ap = 2
	assert_eq(_spell_ids(f.ai.decide(f.mage, f.units)), [&"philosopher_aporia"])


func test_walls_block_casts_and_movement_in_a_closed_corridor() -> void:
	var field := Factory.make_battlefield(8, 1)
	var mage := Unit.from_data(MAGE)
	var hero := Factory.make_unit("Achille", 0)
	field.grid.place_unit(mage, Vector2i(0, 0))
	field.grid.place_unit(hero, Vector2i(7, 0))
	field.grid.set_type(Vector2i(2, 0), GridData.CellType.WALL)
	mage.start_turn()
	var ai := EnemyAI.new(field.grid, field.pathfinder, field.caster)
	assert_true(ai.decide(mage, [mage, hero]).is_empty())
	assert_false(field.caster.can_cast(mage, AXIOM, hero.grid_pos))


func test_support_spells_reject_enemy_targets_and_offense_rejects_allies() -> void:
	var f := _field()
	for spell in [MENDING, AEGIS]:
		assert_false(f.caster.can_cast(f.mage, spell, f.hero.grid_pos))
		assert_true(f.caster.can_cast(f.mage, spell, f.mage.grid_pos))
	for spell in [AXIOM, APORIA, REFUTATION]:
		assert_false(f.caster.can_cast(f.mage, spell, f.mage.grid_pos))


func test_dedicated_trial_is_valid_selectable_and_has_a_support_partner() -> void:
	assert_true(TRIAL.is_valid(), str(TRIAL.validation_errors()))
	assert_eq(TRIAL.rooms.size(), 1)
	var room := TRIAL.rooms[0]
	var roster := room.encounter_definition.expanded_roster()
	assert_eq(roster.map(func(unit: UnitData): return unit.unit_id), [&"philosopher_mage", &"spectre_greatsword"])
	assert_eq(room.enemies, roster)
	var entries := CharacterSelectionCatalog.get_entries()
	var matches := entries.filter(func(entry: Dictionary): return entry.run == TRIAL)
	assert_eq(matches.size(), 1)
	assert_eq(matches[0].chapter, TRIAL.run_name)
	assert_eq(matches[0].unit.unit_id, &"achilles")


func test_trial_catalog_makes_axiom_respect_projectile_only_barriers() -> void:
	var f := _field()
	assert_true(TRIAL.action_classification_catalog.is_valid())
	assert_eq(TRIAL.action_classification_catalog.entries.size(), 6)
	assert_eq(f.caster.get_action_classification(AXIOM), &"PROJECTILE")
	for spell in [REFUTATION, MENDING, APORIA, AEGIS]:
		assert_eq(f.caster.get_action_classification(spell), &"AREA")
	var cleave := load("res://data/spells/enemies/spectre_heavy_cleave.tres") as Spell
	assert_eq(f.caster.get_action_classification(cleave), &"MELEE")
	f.grid.set_terrain_properties(Vector2i(3, 2), {
		"walkable": true, "transparent": true, "projectile_passable": false,
	})
	assert_true(f.pathfinder.has_line_of_sight(f.mage.grid_pos, f.hero.grid_pos))
	assert_false(f.caster.can_cast(f.mage, AXIOM, f.hero.grid_pos))
	assert_true(f.caster.can_cast(f.mage, APORIA, f.hero.grid_pos),
		"Aporia creates a local glyph; it does not travel through the projectile barrier.")


func test_projected_firing_position_cannot_queue_axiom_through_transparent_barrier() -> void:
	var field := Factory.make_battlefield(8, 1)
	assert_true(field.caster.set_action_classification_catalog(TRIAL.action_classification_catalog))
	var mage := Unit.from_data(MAGE)
	mage.spells.assign([AXIOM])
	var hero := Factory.make_unit("Achille", 0)
	field.grid.place_unit(mage, Vector2i(0, 0))
	field.grid.place_unit(hero, Vector2i(7, 0))
	field.grid.set_terrain_properties(Vector2i(4, 0), {
		"walkable": true, "transparent": true, "projectile_passable": false,
	})
	mage.start_turn()
	var ai := EnemyAI.new(field.grid, field.pathfinder, field.caster)
	var plan: Array = ai.decide(mage, [mage, hero])
	assert_true(_spell_ids(plan).is_empty(), "Every firing cell reachable this turn is behind the projectile barrier.")
	assert_eq(mage.grid_pos, Vector2i.ZERO)
	assert_eq(mage.current_ap, 4)
	for action in plan:
		if action.type == "move":
			assert_lte(field.pathfinder.path_movement_cost(action.path, mage), mage.current_mp)
	assert_true(field.pathfinder.has_line_of_sight(Vector2i(3, 0), hero.grid_pos))
	assert_false(field.pathfinder.has_projectile_path(Vector2i(3, 0), hero.grid_pos))


func test_projected_firing_position_respects_modified_minimum_range() -> void:
	var field := Factory.make_battlefield(8, 1)
	assert_true(field.caster.set_action_classification_catalog(TRIAL.action_classification_catalog))
	var mage := Unit.from_data(MAGE)
	mage.spells.assign([AXIOM])
	mage.preferred_range = 2
	mage.set_progression_spell_modifiers_by_spell({AXIOM.spell_id: [MinimumRangeWard.new()]})
	var hero := Factory.make_unit("Achille", 0)
	field.grid.place_unit(mage, Vector2i(0, 0))
	field.grid.place_unit(hero, Vector2i(6, 0))
	mage.start_turn()
	var ai := EnemyAI.new(field.grid, field.pathfinder, field.caster)
	var plan: Array = ai.decide(mage, [mage, hero])
	assert_eq(field.caster.get_effective_spell_minimum_range(mage, AXIOM), 4)
	assert_eq(plan[0].type, "move")
	assert_eq(_spell_ids(plan), [&"philosopher_axiom", &"philosopher_axiom"])
	var destination: Vector2i = plan[0].path.back()
	assert_gte(field.grid.manhattan(destination, hero.grid_pos), 4,
		"Preferred range must not override the actual minimum imposed by a modifier.")
	var f := {"grid": field.grid, "pathfinder": field.pathfinder, "caster": field.caster, "mage": mage}
	_execute(f, plan)
	assert_eq(mage.current_ap, 0)
	assert_eq(hero.current_hp, 68)
