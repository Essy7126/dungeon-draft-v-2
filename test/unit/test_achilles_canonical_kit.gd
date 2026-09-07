extends GutTest

const Factory = preload("res://test/support/factory.gd")

const ODYSSEY_PATH := "res://data/runs/odyssey.tres"
const ACHILLES_DATA_PATH := "res://data/units/allies/achilles.tres"
const EXPECTED_SPELL_IDS: Array[StringName] = [
	&"achilles_peleid_strike",
	&"achilles_fulminant_dash",
	&"achilles_pelion_shot",
	&"achilles_bronze_guard",
]


func test_odyssey_uses_exactly_the_four_canonical_achilles_techniques() -> void:
	var run := load(ODYSSEY_PATH) as RunData
	assert_not_null(run)
	assert_eq(run.content_profile.hero_profiles.size(), 1)
	var hero_profile := run.content_profile.hero_profiles[0]
	var progression := (
		hero_profile.progression_profile as CharacterProgressionProfile
	)
	assert_not_null(progression)
	assert_true(progression.validation_errors().is_empty(), str(
		progression.validation_errors()
	))
	assert_eq(progression.active_spell_slots, 4)
	assert_eq(progression.spells.size(), 4)
	assert_eq(_spell_ids(progression.spells), EXPECTED_SPELL_IDS)
	assert_eq(
		[
			hero_profile.base_unit_data.max_hp,
			hero_profile.base_unit_data.initiative,
			hero_profile.base_unit_data.max_ap,
			hero_profile.base_unit_data.max_mp,
			hero_profile.base_unit_data.attack_power,
		],
		[110, 14, 6, 3, 18],
	)
	assert_false(hero_profile.base_unit_data.basic_attack_enabled)
	assert_eq(hero_profile.base_unit_data.active_spell_slots, 4)


func test_canonical_technique_cost_range_targeting_and_scaling_are_exact() -> void:
	var spells := _progression().spells
	var strike := spells[0]
	assert_eq([strike.ap_cost, strike.minimum_range, strike.spell_range], [3, 1, 1])
	assert_true(strike.can_target_enemy)
	assert_false(strike.can_target_free_cell)
	assert_true(strike.once_per_activation)
	assert_eq(strike.damage_type, Spell.DamageType.PHYSICAL)
	assert_eq(strike.damage, 0)
	assert_not_null(strike.damage_scaling)
	assert_almost_eq(strike.damage_scaling.prowess_coefficient, 0.55, 0.0001)
	assert_almost_eq(strike.damage_scaling.max_hp_coefficient, 0.0, 0.0001)

	var dash := spells[1]
	assert_eq([dash.ap_cost, dash.minimum_range, dash.spell_range], [1, 1, 3])
	assert_false(dash.deals_damage())
	assert_false(dash.can_target_enemy)
	assert_true(dash.can_target_free_cell)
	assert_true(dash.line_from_caster)
	assert_false(dash.needs_line_of_sight)
	assert_true(dash.once_per_activation)
	assert_eq(dash.caster_movement, Spell.CasterMovement.TARGET_CELL)
	assert_true(dash.movement_requires_clear_path)

	var shot := spells[2]
	assert_eq([shot.ap_cost, shot.minimum_range, shot.spell_range], [3, 2, 6])
	assert_true(shot.needs_line_of_sight)
	assert_true(shot.can_target_enemy)
	assert_true(shot.once_per_activation)
	assert_eq(shot.damage_type, Spell.DamageType.PHYSICAL)
	assert_eq(shot.damage, 0)
	assert_not_null(shot.damage_scaling)
	assert_almost_eq(shot.damage_scaling.prowess_coefficient, 0.5, 0.0001)

	var guard := spells[3]
	assert_eq([guard.ap_cost, guard.spell_range], [2, 0])
	assert_true(guard.is_self_only())
	assert_true(guard.once_per_activation)
	assert_eq(guard.shield_grant, 0)
	assert_not_null(guard.shield_scaling)
	assert_almost_eq(guard.shield_scaling.max_hp_coefficient, 0.05, 0.0001)
	assert_almost_eq(guard.shield_scaling.prowess_coefficient, 0.25, 0.0001)
	assert_eq(guard.shield_duration_activations, 1)


func test_scaling_resolver_is_shared_pure_and_honors_level_curve_and_rounding() -> void:
	var scaling := SpellScalingData.new()
	scaling.flat_value = 0.25
	scaling.prowess_coefficient = 0.5
	scaling.max_hp_coefficient = 0.1
	scaling.level_curve = PackedFloat32Array([0.0, 1.4])
	assert_eq(
		SpellScalingResolver.resolve_from_values(scaling, 20.0, 100.0, 2),
		22,
	)
	scaling.rounding_policy = SpellScalingData.RoundingPolicy.FLOOR
	assert_eq(
		SpellScalingResolver.resolve_from_values(scaling, 20.0, 100.0, 2),
		21,
	)
	scaling.rounding_policy = SpellScalingData.RoundingPolicy.CEIL
	assert_eq(
		SpellScalingResolver.resolve_from_values(scaling, 20.0, 100.0, 2),
		22,
	)

	var achilles := _runtime_unit()
	var strike_scaling := _progression().spells[0].damage_scaling
	var coefficient_before := strike_scaling.prowess_coefficient
	assert_eq(SpellScalingResolver.resolve(strike_scaling, achilles), 10)
	achilles.attack_power.base_value = 30.0
	assert_eq(SpellScalingResolver.resolve(strike_scaling, achilles), 17)
	assert_almost_eq(
		strike_scaling.prowess_coefficient,
		coefficient_before,
		0.0001,
	)


func test_scaled_damage_and_guard_use_the_real_spell_caster() -> void:
	var spells := _progression().spells
	var strike_field := Factory.make_battlefield(8, 1)
	var achilles := _runtime_unit()
	var adjacent := Unit.new("Adjacent", 1, 100)
	strike_field.grid.place_unit(achilles, Vector2i.ZERO)
	strike_field.grid.place_unit(adjacent, Vector2i(1, 0))
	var strike_report := strike_field.caster.cast(
		achilles,
		spells[0],
		adjacent.grid_pos,
	)
	assert_false(strike_report.get("failed", false), str(strike_report))
	assert_eq(adjacent.current_hp, 90)
	assert_eq(achilles.current_ap, 3)

	var shot_field := Factory.make_battlefield(8, 1)
	var archer := _runtime_unit()
	var distant := Unit.new("Distant", 1, 100)
	shot_field.grid.place_unit(archer, Vector2i.ZERO)
	shot_field.grid.place_unit(distant, Vector2i(6, 0))
	assert_false(shot_field.caster.can_cast(archer, spells[2], Vector2i(1, 0)))
	var shot_report := shot_field.caster.cast(archer, spells[2], distant.grid_pos)
	assert_false(shot_report.get("failed", false), str(shot_report))
	assert_eq(distant.current_hp, 91)
	assert_eq(archer.current_ap, 3)

	var guard_field := Factory.make_battlefield(1, 1)
	var guarded := _runtime_unit()
	guard_field.grid.place_unit(guarded, Vector2i.ZERO)
	var guard_report := guard_field.caster.cast(
		guarded,
		spells[3],
		guarded.grid_pos,
	)
	assert_false(guard_report.get("failed", false), str(guard_report))
	assert_true(guard_report.get("effective_cast", false), str(guard_report))
	assert_eq(guarded.current_shield, 10)
	assert_eq(guarded.current_ap, 4)


func test_fulminant_dash_moves_on_grid_without_damage_or_crossing() -> void:
	var dash := _progression().spells[1]
	var open_field := Factory.make_battlefield(6, 2)
	var achilles := _runtime_unit()
	open_field.grid.place_unit(achilles, Vector2i.ZERO)
	assert_true(open_field.caster.can_cast(achilles, dash, Vector2i(3, 0)))
	assert_false(open_field.caster.can_cast(achilles, dash, Vector2i(2, 1)))
	var report := open_field.caster.cast(achilles, dash, Vector2i(3, 0))
	assert_false(report.get("failed", false), str(report))
	assert_true(report.get("effective_cast", false), str(report))
	assert_eq(report.get("movement_count", 0), 1)
	assert_eq(achilles.grid_pos, Vector2i(3, 0))
	assert_eq(achilles.current_hp, 110)
	assert_eq(achilles.current_ap, 5)

	var unit_field := Factory.make_battlefield(6, 1)
	var unit_achilles := _runtime_unit()
	var blocker := Unit.new("Bloqueur", 1, 100)
	unit_field.grid.place_unit(unit_achilles, Vector2i.ZERO)
	unit_field.grid.place_unit(blocker, Vector2i(1, 0))
	assert_false(unit_field.caster.can_cast(unit_achilles, dash, Vector2i(3, 0)))
	var unit_report := unit_field.caster.cast(
		unit_achilles,
		dash,
		Vector2i(3, 0),
	)
	assert_true(unit_report.get("failed", false), str(unit_report))
	assert_eq(unit_achilles.grid_pos, Vector2i.ZERO)
	assert_eq(unit_achilles.current_ap, 6)
	assert_eq(blocker.current_hp, 100)

	var wall_field := Factory.make_battlefield(6, 1)
	var wall_achilles := _runtime_unit()
	wall_field.grid.place_unit(wall_achilles, Vector2i.ZERO)
	wall_field.grid.set_type(Vector2i(1, 0), GridData.CellType.WALL)
	assert_false(wall_field.caster.can_cast(wall_achilles, dash, Vector2i(3, 0)))
	assert_eq(wall_achilles.grid_pos, Vector2i.ZERO)
	assert_eq(wall_achilles.current_ap, 6)




func test_legacy_spell_skill_tree_contract_remains_intact() -> void:
	var legacy_paths := [
		"res://data/spells/achilles/spear_thrust.tres",
		"res://data/spells/achilles/advance.tres",
		"res://data/spells/achilles/sweep.tres",
		"res://data/spells/achilles/guard.tres",
	]
	for path in legacy_paths:
		var legacy := load(path) as Spell
		assert_not_null(legacy, path)
		assert_not_null(legacy.skill_tree, path)
		assert_ne(legacy.get_skill_tree_id(), &"", path)




func _progression() -> CharacterProgressionProfile:
	var run := load(ODYSSEY_PATH) as RunData
	return run.content_profile.hero_profiles[0].progression_profile


func _runtime_unit() -> Unit:
	var run := load(ODYSSEY_PATH) as RunData
	var resolution := RunHeroResolver.resolve_runtime_hero_data(run, false)
	return Unit.from_data(resolution.heroes[0])


func _spell_ids(spells: Array[Spell]) -> Array[StringName]:
	var ids: Array[StringName] = []
	for spell in spells:
		ids.append(spell.get_effective_spell_id())
	return ids


func test_new_guard_keeps_the_current_sprite_vfx_and_expires_next_activation() -> void:
	var guard := _progression().spells[3]
	var legacy := load("res://data/spells/achilles/guard.tres") as Spell
	assert_not_null(guard.vfx_scene)
	assert_eq(guard.vfx_scene, legacy.vfx_scene)
	var field := Factory.make_battlefield(1, 1)
	var achilles := _runtime_unit()
	field.grid.place_unit(achilles, Vector2i.ZERO)
	field.caster.cast(achilles, guard, achilles.grid_pos)
	assert_eq(achilles.get_shield_value(guard.spell_id), guard.get_scaled_shield(achilles))
	achilles.start_turn()
	assert_eq(achilles.get_shield_value(guard.spell_id), 0)


func test_scaling_is_opt_in_and_flat_legacy_spells_remain_unchanged() -> void:
	var spell := Spell.new()
	spell.damage = 7
	spell.shield_grant = 10
	var unit := Factory.make_unit()
	unit.attack_power.add_modifier(100.0, Stat.ModType.FLAT, "test")
	unit.max_hp.add_modifier(300.0, Stat.ModType.FLAT, "test")
	assert_eq(spell.get_scaled_damage(unit), 7)
	assert_eq(spell.get_scaled_shield(unit), 10)
	assert_eq(SpellScalingResolver.resolve(null, null, 7), 7)
	var invalid := SpellScalingData.new()
	invalid.prowess_coefficient = NAN
	assert_eq(SpellScalingResolver.resolve(invalid, unit, 7), 0)
	assert_eq(SpellScalingResolver.resolve_from_values(invalid, 20.0, 100.0), 0)


func test_dash_presentation_and_minimum_range_use_the_same_targeting_contract() -> void:
	var field := Factory.make_battlefield(8, 1)
	var unit := _runtime_unit()
	field.grid.place_unit(unit, Vector2i.ZERO)
	var spells := _progression().spells
	assert_true(field.caster.spell_moves_caster(unit, spells[1]))
	assert_false(field.caster.spell_moves_caster(unit, spells[0]))
	assert_eq(field.caster.get_effective_spell_minimum_range(unit, spells[2]), 2)
	assert_false(field.caster.get_targetable_cells(unit, spells[1]).has(Vector2i.ZERO))
