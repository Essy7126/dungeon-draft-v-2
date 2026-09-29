extends GutTest
const Rules := preload("res://core/expedition/consumable_progression_v1.gd")
const Integration := preload("res://core/expedition/consumable_cards_integration.gd")
const Math := preload("res://core/expedition/consumable_card_math.gd")
const Effects := preload("res://core/expedition/consumable_card_effects.gd")
const Turns := preload("res://core/expedition/consumable_card_turns.gd")
const Spells := preload("res://core/expedition/consumable_card_spells.gd")
const Words := preload("res://ui/expedition/card_player_language.gd")
const Factory := preload("res://test/support/factory.gd")
const Cleanup := preload("res://test/support/isolated_battlefield_cleanup.gd")
var fields: Array = []
var manager
var save_path := ""


class Manager:
	extends "res://core/game_manager.gd"
	func start_next_battle() -> void:
		pass


	func _request_scene_change(
		_path: String,
		_mode: PersistentRunUI.RunUIMode = PersistentRunUI.RunUIMode.NON_COMBAT,
	) -> void:
		pass


	func _ensure_persistent_run_ui() -> PersistentRunUI:
		return null


func after_each() -> void:
	for field in fields:
		field.terrain.dispose()
		Cleanup.dispose_grid(field.grid)
	fields.clear()
	if is_instance_valid(manager):
		manager.cleanup_run_state()
		manager.free()
	if not save_path.is_empty():
		ExpeditionSaveService.remove_snapshot(save_path)
	await wait_process_frames(2)


func cards_for(class_id := "thaumaturge"):
	var cards = Integration.Cards.new()
	cards.initialize_deck(Integration.Catalog.preset(class_id))
	return cards


func session_after_first_combat():
	manager = Manager.new()
	add_child(manager)
	assert_true(manager.select_run_variant("cards"))
	save_path = "user://prototype_v1_%d.json" % Time.get_ticks_usec()
	manager.expedition_save_path = save_path
	assert_true(manager.start_expedition(33, { }, false, true, "normal", true))
	assert_true(manager.expedition.combat_won())
	return manager.expedition


func field_for(family: String) -> Dictionary:
	var runtime := Factory.make_battlefield(7, 7)
	var cards = cards_for()
	var hero := Factory.make_unit("Hero", 0)
	hero.unit_id = &"prototype_hero"
	hero.attack_power.base_value = 100
	hero.max_hp.base_value = 300
	hero.current_hp = 50
	hero.max_ap.base_value = 4
	Turns.bind_hero(hero, cards)
	hero.start_turn()
	runtime.grid.place_unit(hero, Vector2i(3, 4))
	var target := Factory.make_unit("Target", 1)
	target.unit_id = &"prototype_enemy"
	target.max_hp.base_value = 500
	target.current_hp = 500
	target.armure.base_value = 0
	target.resist_magique.base_value = 0
	target.set_meta("cc2_ruleset", Effects.ID)
	runtime.grid.place_unit(target, Vector2i(3, 3))
	cards.start_turn()
	for pile in [cards.hand, cards.draw_pile, cards.discard, cards.active]:
		pile.clear()
	var uid: String = cards.acquire(family, "loot", "prototype:test")
	cards.hand.append(uid)
	cards.active.append(uid)
	var field := {
		"cards": cards,
		"hero": hero,
		"target": target,
		"grid": runtime.grid,
		"terrain": runtime.terrain,
		"caster": runtime.caster,
	}
	fields.append(field)
	return field


func test_budget_growth_and_allocation_validation() -> void:
	var cards = cards_for()
	assert_eq(cards.prototype_revision, 1)
	assert_eq(cards.attribute_points(), 4)
	assert_false(cards.spend_attribute("power"))
	for level in range(1, 13):
		cards.level = level
		assert_eq(Rules.element_budget(level), 4 + 2 * (level - 1))
		assert_eq(Rules.aptitude_budget(level), mini(3, level / 3))
	assert_almost_eq(Rules.mastery(4), .12, .00001)
	assert_almost_eq(Rules.mastery(8), .20, .00001)
	assert_almost_eq(Rules.mastery(26), .38, .00001)
	for _point in 26:
		assert_true(cards.spend_attribute("night"))
	assert_false(cards.spend_attribute("water"))
	for _point in 3:
		assert_true(cards.spend_attribute("contact"))
	assert_false(cards.spend_attribute("vitality"))
	assert_eq(cards.invariant_errors(), [])
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(cards.snapshot()))
	var restored = Integration.Cards.new()
	assert_true(restored.restore(snapshot))
	assert_eq(restored.masteries, cards.masteries)
	snapshot.masteries.night = 26.5
	assert_false(restored.restore(snapshot))
	assert_eq(restored.masteries, cards.masteries)
	snapshot.masteries.night = 26
	snapshot.aptitudes.contact = 4
	assert_false(restored.restore(snapshot))


func test_components_cover_catalog_without_scaling_utility_or_derived_values() -> void:
	for card in Integration.Catalog.data().cards:
		assert_eq(Rules.component_errors(card), [], str(card.id))
	assert_eq(Integration.Catalog.card("n03").elements, { })
	assert_false(Integration.Catalog.card("t07").elements.has("amount"), "drain ratio is derived")
	assert_eq(Integration.Catalog.card("t04").elements.damage, { "water": .8, "night": .2 })
	var invalid := Integration.Catalog.card("n03")
	invalid.elements = { "amount": { "wind": 1.0 } }
	assert_false(Rules.component_errors(invalid).is_empty())
	invalid = Integration.Catalog.card("t04")
	invalid.elements.damage.water = .9
	assert_false(Rules.component_errors(invalid).is_empty())


func test_hybrid_direct_damage_and_conversion_use_additive_bonuses() -> void:
	var cards = cards_for()
	cards.level = 12
	cards.masteries.water = 13
	cards.masteries.night = 13
	cards.aptitudes.contact = 2
	var result := Math.impact(
		Integration.Catalog.card("t04"),
		100,
		{ "distance": 1 },
		{ "damage": .1 },
		"thaumaturge",
		"",
		{ },
		cards,
	)
	assert_almost_eq(result.raw, 66.15, .0001)
	cards.masteries = Rules.empty_elements()
	cards.masteries.earth = 26
	cards.aptitudes.contact = 3
	result = Math.impact(
		Integration.Catalog.card("g09"),
		100,
		{ "distance": 1, "sacrifice": 10 },
		{ },
		"gardien",
		"",
		{ },
		cards,
	)
	assert_almost_eq(result.raw, 124.2, .0001, "sacrificed guard receives no second mastery")
	assert_eq(Math.stats(12, { }, { }, cards).power, 93.0)
	cards.aptitudes = Rules.empty_aptitudes()
	cards.aptitudes.vitality = 3
	assert_eq(Math.stats(12, { }, { }, cards).hp, 837)


func test_burn_is_snapshotted_and_guard_preview_matches_cast() -> void:
	var f := field_for("t02")
	f.cards.masteries.fire = 4
	var result: Dictionary = f.caster.cast(f.hero, f.cards.family_spell("t02"), f.target.grid_pos)
	assert_false(result.get("failed", false))
	assert_eq(f.target.current_hp, 438)
	assert_almost_eq(float(Effects.states(f.target).burn.amount), 20.16, .0001)
	f.cards.masteries.fire = 0 # Simulate a later stat change; stored payload must stay fixed.
	Turns.apply_activation_statuses(f.target, f.grid)
	assert_eq(f.target.current_hp, 418)
	var g := field_for("n02")
	g.cards.level = 3
	g.cards.masteries.sun = 4
	g.cards.aptitudes.protection = 1
	assert_string_contains(Words.effect(Integration.Catalog.card("n02"), 100, g.cards), "55 dégâts")
	g.caster.cast(g.hero, g.cards.family_spell("n02"), g.hero.grid_pos)
	assert_eq(g.hero.current_shield, 55)


func test_drain_does_not_apply_element_to_healing_twice() -> void:
	var f := field_for("t07")
	f.cards.masteries.night = 4
	f.cards.equipped.belt = "s_care"
	f.caster.cast(f.hero, f.cards.family_spell("t07"), f.target.grid_pos)
	assert_eq(f.target.current_hp, 420)
	assert_eq(f.hero.current_hp, 102, "80 HP removed × 50 % × 1.30 healing = 52")


func test_permanent_guardian_attack_scales_its_two_components_independently() -> void:
	var f := field_for("n01")
	f.cards.primary_class = "gardien"
	f.cards.level = 3
	f.cards.masteries.earth = 4
	f.cards.masteries.sun = 4
	f.cards.aptitudes.contact = 1
	var spell: Spell = f.cards.family_spell("fallback_strike")
	var count: int = f.cards.copies.size()
	f.caster.cast(f.hero, spell, f.target.grid_pos)
	assert_eq(f.target.current_hp, 470, "25 × (1 + .12 earth + .06 contact), rounded")
	assert_eq(f.hero.current_shield, 13, "12 × (1 + .12 sun), rounded")
	assert_eq(f.cards.copies.size(), count)
	assert_false(f.caster.get_cast_failure_reason(f.hero, spell, f.target.grid_pos).is_empty())


func test_fire_surface_keeps_its_payload_after_mastery_changes() -> void:
	var f := field_for("t05")
	f.cards.masteries.fire = 4
	var terrain_rules = preload("res://core/expedition/consumable_card_terrain.gd")
	f.caster.cast(f.hero, f.cards.family_spell("t05"), f.target.grid_pos)
	var state: CellSurfaceState = f.terrain.runtime_service.get_state(f.target.grid_pos)
	assert_not_null(state)
	assert_eq(state.surface_id, &"fire")
	var coefficient: float = Integration.Catalog.card("t05").amount
	assert_almost_eq(
		float(state.gameplay_flags.cc2_payload),
		coefficient * 100 * (1 + .7 * .12),
		.0001,
	)
	f.cards.masteries.fire = 0
	var before: int = f.target.current_hp
	terrain_rules.begin_activation(f.terrain, f.target)
	assert_eq(before - f.target.current_hp, Math.rounded(coefficient * 100 * (1 + .7 * .12)))


func test_four_basic_attacks_are_permanent_and_class_specific() -> void:
	var names := { }
	for id in Integration.Catalog.CLASSES:
		var cards = cards_for(id)
		var spell: Spell = cards.family_spell("fallback_strike")
		names[spell.spell_name] = true
		assert_eq(spell.ap_cost, 1)
		assert_eq(Rules.component_errors(Spells.definition("fallback_strike", false, id)), [])
		cards.start_turn()
		var count: int = cards.copies.size()
		assert_true(cards.consume(spell))
		assert_false(cards.consume(spell))
		assert_eq(cards.copies.size(), count)
	assert_eq(names.size(), 4)
	assert_eq(Spells.make_spell("fallback_strike", false, "arpenteur").minimum_range, 2)
	assert_eq(
		Spells.make_spell("fallback_strike", false, "thaumaturge").damage_type,
		Spell.DamageType.MAGICAL,
	)


func test_training_can_be_released_without_refunding_copies_or_gold() -> void:
	var cards = cards_for("assassin")
	cards.level = 4
	assert_false(cards.upgrade_copy("g08"), "must own a copy when assigning")
	assert_true(cards.upgrade_copy("a01"))
	var count: int = cards.copies.size()
	assert_true(cards.release_upgrade("a01"))
	assert_eq(cards.points(), 1)
	assert_true(cards.upgrade_copy("a02"))
	assert_eq(cards.copies.size(), count)
	assert_eq(cards.gold, 40)
	cards.start_turn()
	assert_false(cards.release_upgrade("a02"))


func test_atomic_halt_correction_and_full_reset_preserve_health_and_receipts() -> void:
	var session = session_after_first_combat()
	var cards = session.cards
	var allocation := Rules.empty_elements()
	allocation.night = 6
	assert_true(Integration.allocate_progression(session, allocation, cards.aptitudes))
	allocation.night = 5
	allocation.water = 1
	assert_false(
		Integration.allocate_progression(session, allocation, cards.aptitudes),
		"combat reward is not a halt",
	)
	for node in session.route.nodes:
		if int(node.depth) == 4:
			session.route.current_node_id = node.id
			break
	allocation.night = 3
	allocation.water = 3
	assert_false(
		Integration.allocate_progression(session, allocation, cards.aptitudes),
		"maximum two refunded points",
	)
	allocation.night = 4
	allocation.water = 2
	assert_true(Integration.allocate_progression(session, allocation, cards.aptitudes))
	assert_false(Integration.correction_available(session))
	var saved: Dictionary = JSON.parse_string(JSON.stringify(cards.snapshot()))
	assert_true(cards.restore(saved))
	assert_false(
		Integration.correction_available(session),
		"opening or reloading cannot reset the allowance",
	)
	cards.level = 8
	cards.aptitudes.vitality = 2
	Integration.rebuild(session, true)
	session.character.unit.current_hp = 101
	var old_max: int = session.character.unit.max_hp.get_int()
	for node in session.route.nodes:
		if int(node.depth) == 11:
			session.route.current_node_id = node.id
			break
	assert_true(Integration.full_reorientation(session))
	assert_eq(session.character.unit.current_hp, Math.rounded(101.0 / old_max * 420))
	assert_eq(Rules.spent(cards.masteries), 0)
	assert_eq(Rules.spent(cards.aptitudes), 0)
	assert_false(Integration.full_reorientation(session))
	var aptitude := Rules.empty_aptitudes()
	aptitude.vitality = 2
	assert_true(Integration.allocate_progression(session, cards.masteries, aptitude))
	assert_eq(
		session.character.unit.current_hp,
		101,
		"unrounded health basis survives reallocation",
	)


func test_old_boundary_save_migrates_once_and_retains_inventory_and_health_ratio() -> void:
	var session = session_after_first_combat()
	var cards = session.cards
	cards.prototype_revision = 0
	cards.attributes.vitality = 1
	Integration.rebuild(session, false, false, false)
	session.character.unit.current_hp = 37
	session.character.champion_progression.current_hp = 37
	var previous_max: int = session.character.unit.max_hp.get_int()
	var saved: Dictionary = JSON.parse_string(JSON.stringify(manager.get_expedition_snapshot()))
	for key in [
		"prototype_revision",
		"masteries",
		"aptitudes",
		"correction_visits",
		"full_reorientation_used",
	]:
		saved.session.cards_run.erase(key)
	var copies: Array = saved.session.cards_run.copies.duplicate(true)
	assert_true(manager.restore_expedition_snapshot(saved))
	session = manager.expedition
	assert_eq(session.cards.prototype_revision, 1)
	assert_eq(session.cards.attributes, { "power": 0, "vitality": 0, "resolve": 0 })
	assert_eq(session.cards.copies, copies)
	assert_eq(session.character.unit.current_hp, Math.rounded(37.0 / previous_max * 135))
	var again: Dictionary = JSON.parse_string(JSON.stringify(manager.get_expedition_snapshot()))
	assert_true(manager.restore_expedition_snapshot(again))
	assert_eq(
		JSON.parse_string(JSON.stringify(manager.expedition.cards.snapshot())),
		JSON.parse_string(JSON.stringify(session.cards.snapshot())),
	)


func test_active_legacy_profile_defers_migration_until_combat_finishes() -> void:
	var cards = cards_for()
	cards.prototype_revision = 0
	cards.start_turn()
	var saved: Dictionary = cards.snapshot()
	for key in [
		"prototype_revision",
		"masteries",
		"aptitudes",
		"correction_visits",
		"full_reorientation_used",
	]:
		saved.erase(key)
	var restored = Integration.Cards.new()
	assert_true(restored.restore(saved))
	assert_false(restored.migrate_prototype())
	assert_eq(restored.family_spell("fallback_strike").spell_name, "Attaque de secours")
	restored.finish_combat()
	assert_true(restored.migrate_prototype())
	assert_false(restored.migrate_prototype())
	assert_eq(restored.family_spell("fallback_strike").spell_name, "Étincelle du Léthé")
