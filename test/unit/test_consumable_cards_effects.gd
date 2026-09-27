extends GutTest
const Catalog := preload("res://core/expedition/consumable_card_catalog.gd")
const Profile := preload("res://core/expedition/consumable_cards_profile.gd")
const Spells := preload("res://core/expedition/consumable_card_spells.gd")
const Effects := preload("res://core/expedition/consumable_card_effects.gd")
const Math := preload("res://core/expedition/consumable_card_math.gd")
const Factory := preload("res://test/support/factory.gd")
const Cleanup := preload("res://test/support/isolated_battlefield_cleanup.gd")
var fields: Array = []


func after_each() -> void:
	for field in fields:
		field.terrain.dispose()
		Cleanup.dispose_grid(field.grid)
	fields.clear()


func field_for(class_id := "assassin") -> Dictionary:
	var runtime := Factory.make_battlefield(7, 7)
	var field := { "grid": runtime.grid, "terrain": runtime.terrain, "caster": runtime.caster }
	var cards = Profile.create_cards(Catalog.preset(class_id))
	var hero := Factory.make_unit("Hero", 0)
	hero.attack_power.base_value = 18
	hero.max_ap.base_value = 4
	hero.set_meta("cc2_ruleset", Profile.ID)
	hero.set_meta("cc2_cards", weakref(cards))
	hero.start_turn()
	field.grid.place_unit(hero, Vector2i(3, 4))
	var target := Factory.make_unit("Target", 1)
	target.unit_id = &"enemy_01"
	target.max_hp.base_value = 500
	target.current_hp = 500
	target.armure.base_value = 8
	target.set_meta("cc2_ruleset", Profile.ID)
	field.grid.place_unit(target, Vector2i(3, 3))
	cards.start_turn()
	field.hero = hero
	field.target = target
	field.cards = cards
	fields.append(field)
	return field


func force_hand(field: Dictionary, family: String) -> Spell:
	var cards = field.cards
	for pile in [cards.hand, cards.draw_pile, cards.discard]:
		pile.clear()
	cards.active.clear()
	var uid: String = cards.acquire(family, "loot", "test:" + family)
	cards.active.append(uid)
	cards.hand.append(uid)
	return cards.family_spell(family)


func test_every_definition_builds_both_forms_without_mutating_catalog() -> void:
	var before := Catalog.data().duplicate(true)
	for id in Catalog.pool():
		for upgraded in [false, true]:
			var spell := Spells.make_spell(id, upgraded)
			assert_not_null(spell, id)
			assert_eq(String(spell.spell_id), "cc2_" + id)
			var gameplay := spell.modifiers.filter(
				func(modifier):
					return modifier.get_script() == preload(
						"res://core/expedition/consumable_card_modifier.gd"
					),
			)
			assert_eq(
				gameplay.size(),
				1,
				"One gameplay modifier; visual companions do not duplicate it",
			)
	assert_eq(Catalog.data(), before)
	assert_eq(Spells.make_spell("fallback_strike").ap_cost, 1)
	assert_eq(Spells.make_spell("fallback_guard").ap_cost, 1)


func test_final_rounding_no_legacy_floor_and_resistance_cap() -> void:
	assert_eq(Math.damage(18 * .25, .08), 4, "round after resistance, not 5 * .92")
	assert_eq(Math.damage(.1, 0), 0, "no old minimum-one rule")
	assert_eq(Math.damage(10, .9), 6)
	assert_eq(Math.damage(10, .4, true), 10)
	assert_eq(Math.damage(20, .25, false, 8), 9, "parry before resistance")
	assert_eq(Math.rounded(4.5), 5)
	assert_eq(Math.pressure(110, 8), 0)
	assert_eq(Math.pressure(110, 9), 3)


func test_pressure_bypasses_guard_resistance_and_edict_with_real_damage_events() -> void:
	var f := field_for("gardien")
	f.hero.max_hp.base_value = 110
	f.hero.current_hp = 110
	f.hero.armure.base_value = 40
	f.hero.add_shield(18)
	Effects.apply_state(f.hero, "edict", 1, 1, f.hero)
	watch_signals(EventBus)
	var result := Effects.hit(f.hero, null, Math.pressure(110, 9), false, "pressure", true)
	assert_eq(f.hero.current_hp, 107)
	assert_eq(f.hero.current_shield, 18)
	assert_eq(result.hp_damage_applied, 3)
	assert_eq(result.shield_damage_absorbed, 0)
	assert_true(Effects.states(f.hero).has("edict"))
	assert_eq(f.cards.absorbed_since_turn, 0)
	assert_signal_emit_count(EventBus, "hp_damage_taken", 1)
	Effects.hit(f.hero, null, 200, false, "pressure", true)
	assert_false(f.hero.is_alive)
	assert_eq(f.hero.current_hp, 0)
	assert_eq(f.hero.current_shield, 18)
	assert_signal_emit_count(EventBus, "unit_killed", 1)


func test_shared_cast_consumes_once_and_invalid_target_preserves_costs() -> void:
	var f := field_for()
	var spell := force_hand(f, "n01")
	var before: Dictionary = f.cards.snapshot()
	var invalid: Dictionary = f.caster.cast(f.hero, spell, Vector2i(0, 0))
	assert_true(invalid.get("failed", false))
	assert_eq(f.cards.snapshot(), before)
	assert_eq(f.hero.current_ap, 4)
	var ctx: CastContext = f.caster.begin_cast(f.hero, spell, f.target.grid_pos)
	assert_false(ctx.failed)
	assert_eq(f.cards.hand.size(), 0)
	assert_eq(f.cards.consumed.size(), 1)
	assert_eq(f.cards.active.size(), 0)
	f.caster.resolve_cast(ctx)
	assert_eq(f.target.current_hp, 487, "(.55 + .25) * 18 * .92 = 13")
	f.caster.resolve_cast(ctx)
	assert_eq(f.target.current_hp, 487)
	assert_eq(f.hero.current_ap, 3)
	f.cards.end_turn()
	f.cards.start_turn()
	assert_eq(f.cards.hand.size(), 0)
	assert_eq(f.cards.invariant_errors(), [])


func test_guard_sacrifice_is_chosen_before_costs_and_not_absorption() -> void:
	var f := field_for("gardien")
	var spell := force_hand(f, "g09")
	Effects.guard(f.hero, 1, f.cards)
	assert_eq(f.caster.get_cast_failure_reason(f.hero, spell, f.target.grid_pos), &"choose_guard_sacrifice")
	assert_eq(f.hero.current_shield, 18)
	f.cards.action_options = { "sacrifice": 14 }
	f.caster.cast(f.hero, spell, f.target.grid_pos)
	assert_eq(f.hero.current_shield, 4)
	assert_eq(f.cards.absorbed_since_turn, 0)
	assert_eq(f.target.current_hp, 469, "(.7 * 18 + 1.5 * 14) * .92 rounds to 31")


func test_mark_is_consumed_before_replacement_and_fallback_does_not_trigger_it() -> void:
	var f := field_for("gardien")
	Effects.apply_state(f.target, "mark", 9, 2, f.hero)
	var fallback := Spells.make_spell("fallback_strike")
	f.caster.cast(f.hero, fallback, f.target.grid_pos)
	assert_true(Effects.states(f.target).has("mark"))
	assert_eq(f.target.current_hp, 495)
	var spell := force_hand(f, "n06")
	f.caster.cast(f.hero, spell, f.target.grid_pos)
	assert_eq(f.target.current_hp, 483)
	assert_almost_eq(float(Effects.states(f.target).mark.amount), 6.3, .001)


func test_line_shape_uses_perpendicular_axis_and_clips_walls() -> void:
	var f := field_for("arpenteur")
	var spell := force_hand(f, "r06")
	var modifier: SpellModifier = spell.modifiers[0]
	f.grid.set_type(Vector2i(5, 3), GridData.CellType.WALL)
	var cells: Array = modifier.get_area_override(f.hero, spell, Vector2i(5, 2), f.grid)
	assert_has(cells, Vector2i(5, 2))
	assert_does_not_have(cells, Vector2i(5, 3))
	assert_does_not_have(cells, Vector2i(4, 2))


func test_anchor_and_push_do_not_invent_voluntary_movement() -> void:
	var f := field_for("arpenteur")
	f.cards.anchor_cell = Vector2i(1, 4)
	f.cards.anchor_available = true
	assert_true(Effects.return_to_anchor(f.hero, f.cards, f.grid))
	assert_eq(f.hero.grid_pos, Vector2i(1, 4))
	assert_eq(f.cards.moved_cells, 0)
	assert_false(Effects.return_to_anchor(f.hero, f.cards, f.grid))
	f.grid.set_type(Vector2i(3, 1), GridData.CellType.WALL)
	var moved := Effects.displace(f.grid, f.target, Vector2i.UP, 3)
	assert_eq(moved.moved, 1)
	assert_true(moved.wall)


func test_only_enemy_attacks_count_as_absorbed_for_guard_passives() -> void:
	var f := field_for("gardien")
	Effects.guard(f.hero, 2.5, f.cards)
	var enemy_hp: int = f.target.current_hp
	for kind in ["environment", "periodic", "indirect"]:
		var result := Effects.hit(f.hero, f.target, 3, false, kind)
		assert_gt(result.shield_damage_absorbed, 0)
		assert_eq(f.cards.absorbed_since_turn, 0, kind)
		assert_eq(f.target.current_hp, enemy_hp, "No guardian retaliation: " + kind)
	var attack := Effects.hit(f.hero, f.target, 3, false, "attack")
	assert_eq(f.cards.absorbed_since_turn, attack.shield_damage_absorbed)
	assert_lt(f.target.current_hp, enemy_hp, "Enemy attack triggers guardian retaliation")


func test_new_combat_clears_absorption_before_bronze_opening() -> void:
	var f := field_for("gardien")
	f.cards.active_relics.assign(["bronze"])
	Effects.guard(f.hero, 1, f.cards)
	Effects.hit(f.hero, f.target, 3, false, "attack")
	assert_gt(f.cards.absorbed_since_turn, 0)
	f.cards.finish_combat()
	preload("res://core/expedition/consumable_card_turns.gd").begin_hero(f.hero, f.cards, f.terrain)
	assert_eq(f.cards.absorbed_since_turn, 0)
	assert_eq(f.cards.absorbed_last_round, 0)
	assert_eq(f.hero.current_shield, 0, "Previous fight cannot grant bronze opening guard")
