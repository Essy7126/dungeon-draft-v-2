extends GutTest

const Factory = preload("res://test/support/factory.gd")
const SEISMIC_PATH := "res://data/spells/Mage/onde_sismique.tres"


func _spell() -> Spell:
	return load(SEISMIC_PATH) as Spell


func test_resource_matches_the_locked_seismic_wave_contract() -> void:
	var spell := _spell()
	assert_eq(spell.spell_id, &"mage_seismic_wave")
	assert_eq(spell.get_skill_tree_id(), &"mage_geomancy")
	assert_eq(spell.spell_name, "Onde sismique")
	assert_eq([spell.ap_cost, spell.spell_range, spell.damage], [2, 3, 6])
	assert_true(spell.needs_line_of_sight)
	assert_eq(spell.aoe_shape, Spell.AoeShape.LINE)
	assert_true(spell.line_from_caster)
	assert_eq(spell.element, Spell.Element.EARTH)
	assert_eq(spell.push_distance, 1)
	assert_true(spell.push_affected_units)
	assert_null(spell.terrain_effect)
	assert_null(spell.applied_status)


func test_targeting_and_affected_cells_form_one_cardinal_line_from_caster() -> void:
	var battlefield := Factory.make_battlefield(7, 7)
	var mage := Factory.make_unit("Mage", 0)
	battlefield.grid.place_unit(mage, Vector2i(2, 2))
	var targetable := battlefield.caster.get_targetable_cells(mage, _spell())
	assert_has(targetable, Vector2i(5, 2))
	assert_has(targetable, Vector2i(2, 5))
	assert_does_not_have(targetable, Vector2i(4, 3))
	assert_eq(
		battlefield.caster.get_aoe_cells(
			_spell(),
			Vector2i(5, 2),
			mage.grid_pos,
		),
		[Vector2i(3, 2), Vector2i(4, 2), Vector2i(5, 2)],
	)


func test_wave_damages_and_pushes_each_enemy_in_the_line_once() -> void:
	var battlefield := Factory.make_battlefield(7, 3)
	var mage := Factory.make_unit("Mage", 0)
	var first := Factory.make_unit("Premier", 1)
	var second := Factory.make_unit("Second", 1)
	battlefield.grid.place_unit(mage, Vector2i(0, 1))
	battlefield.grid.place_unit(first, Vector2i(1, 1))
	battlefield.grid.place_unit(second, Vector2i(3, 1))
	var report := battlefield.caster.cast(mage, _spell(), Vector2i(3, 1))
	assert_false(report.get("failed", false))
	assert_eq([first.current_hp, second.current_hp], [94, 94])
	assert_eq([first.grid_pos, second.grid_pos], [
		Vector2i(2, 1),
		Vector2i(4, 1),
	])
	assert_true(report["pushed"])


func test_blocked_push_keeps_the_cast_valid_and_damage_resolved() -> void:
	var battlefield := Factory.make_battlefield(6, 3)
	var mage := Factory.make_unit("Mage", 0)
	var target := Factory.make_unit("Cible", 1)
	battlefield.grid.place_unit(mage, Vector2i(0, 1))
	battlefield.grid.place_unit(target, Vector2i(2, 1))
	battlefield.grid.set_type(Vector2i(3, 1), GridData.CellType.WALL)
	var report := battlefield.caster.cast(mage, _spell(), Vector2i(2, 1))
	assert_false(report.get("failed", false))
	assert_eq(target.current_hp, 94)
	assert_eq(target.grid_pos, Vector2i(2, 1))
	assert_false(report["pushed"])


func test_grid_boundary_blocks_push_without_invalidating_the_cast() -> void:
	var battlefield := Factory.make_battlefield(3, 1)
	var mage := Factory.make_unit("Mage", 0)
	var target := Factory.make_unit("Cible", 1)
	battlefield.grid.place_unit(mage, Vector2i(0, 0))
	battlefield.grid.place_unit(target, Vector2i(2, 0))
	var report := battlefield.caster.cast(mage, _spell(), Vector2i(2, 0))
	assert_false(report.get("failed", false))
	assert_eq(target.current_hp, 94)
	assert_eq(target.grid_pos, Vector2i(2, 0))


func test_historical_line_spell_keeps_single_target_behavior_by_default() -> void:
	var battlefield := Factory.make_battlefield(6, 1)
	var historical := Factory.make_spell({
		"aoe_shape": Spell.AoeShape.LINE,
		"damage": 3,
		"spell_range": 4,
	})
	assert_false(historical.line_from_caster)
	assert_eq(
		battlefield.caster.get_aoe_cells(
			historical,
			Vector2i(3, 0),
			Vector2i(0, 0),
		),
		[Vector2i(3, 0)],
	)
