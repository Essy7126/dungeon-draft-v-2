extends GutTest
const Catalog := preload("res://core/expedition/class_card_catalog.gd")
const Cards := preload("res://core/expedition/class_cards.gd")
const Factory := preload("res://test/support/factory.gd")
const Cleanup := preload("res://test/support/isolated_battlefield_cleanup.gd")
var managers: Array = []
var fields: Array = []


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


func manager_for(class_id := "assassin"):
	var m := Manager.new()
	add_child(m)
	managers.append(m)
	m.expedition_save_path = "user://class_test_%d.json" % Time.get_ticks_usec()
	m._cards_departure_selection = Catalog.preset(class_id)
	assert_true(m.start_expedition(2401, { }, false, true, "normal", true))
	assert_true(m.confirm_catabase_preparation(Catalog.preset(class_id)).get("success", false))
	return m


func after_each() -> void:
	for field in fields:
		for actor: Unit in field.grid.get_units():
			actor.clear_combat_effect_history()
		field.terrain.dispose()
		Cleanup.dispose_grid(field.grid)
	fields.clear()
	for m in managers:
		m.cleanup_run_state()
		ExpeditionSaveService.remove_snapshot(m.expedition_save_path)
		m.queue_free()
	managers.clear()
	await get_tree().process_frame


func test_catalog_has_four_independent_fifteen_card_pools_and_icons() -> void:
	assert_eq(Catalog.pool().size(), 60)
	for id in Catalog.CLASSES:
		assert_eq(Catalog.pool(id).size(), 15)
		assert_true(Catalog.valid(Catalog.preset(id)))
	for id in Catalog.pool():
		var base := Catalog.make_spell(id, 0)
		var expert := Catalog.make_spell(id, 4)
		assert_not_null(base.icon, id)
		assert_eq(base.ap_cost, expert.ap_cost, id)
		assert_eq(base.spell_range, expert.spell_range, id)
		assert_ne(base, expert)
		assert_gt(base.description.length(), 40)


func test_four_starters_have_no_equipment_and_restore_the_same_hand() -> void:
	for id in Catalog.CLASSES:
		var m = manager_for(id)
		var cards = m.expedition.cards
		assert_eq(cards.rules_revision, 3)
		assert_eq(cards.active.size(), 10)
		assert_eq(m.run_inventory.get_empty_slot_count(), m.run_inventory.capacity)
		assert_true(m.expedition.character.equipment_loadout.get_equipped_items().is_empty())
		assert_eq(m.expedition.build.points, 0)
		cards.start_turn()
		var hand: Array = cards.hand.duplicate()
		assert_eq(hand.size(), 4)
		var snapshot: Dictionary = JSON.parse_string(JSON.stringify(m.get_expedition_snapshot()))
		assert_true(m.restore_expedition_snapshot(snapshot), id)
		m.expedition.cards.start_turn()
		assert_eq(m.expedition.cards.hand, hand)


func test_victory_loot_is_idempotent_and_first_weapon_is_equippable() -> void:
	var m = manager_for()
	var s: ExpeditionSession = m.expedition
	assert_true(s.combat_won())
	var cards = s.cards
	assert_eq(cards.active.size(), 10)
	assert_eq(cards.last_drops.size(), 1)
	assert_eq(m.run_inventory.get_empty_slot_count(), m.run_inventory.capacity - 1)
	var size: int = cards.copies.size()
	cards.grant_loot(s.route.get_current_node())
	assert_eq(cards.copies.size(), size)
	var item: ItemInstance = m.run_inventory.get_slots().filter(
		func(value):
			return value != null,
	)[0]
	var service := EquipmentService.new()
	assert_true(service.initialize(m.item_catalog))
	assert_true(service.equip(m.run_inventory, s.character, item.instance_id, ItemDefinition
		.EquipmentSlot
		.WEAPON).get("success", false))
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(m.get_expedition_snapshot()))
	assert_true(m.restore_expedition_snapshot(snapshot))
	assert_eq(m.expedition.character.equipment_loadout.get_equipped_items().size(), 1)


func test_all_new_equipment_valid_and_six_slots_restore() -> void:
	var catalog := ExpeditionEquipmentCatalog.merge_into(null)
	for item in preload("res://core/expedition/class_equipment_catalog.gd").definitions():
		assert_true(item.is_valid(), item.item_id)
		assert_not_null(item.icon, item.item_id)
	var equipped := EquipmentLoadout.new()
	equipped.initialize(&"achilles")
	for slot in 6:
		var item := ItemInstance.new()
		item.initialize(StringName("class_gear_1_%d_0" % slot))
		assert_true(equipped.set_item(slot, item))
	var restored := EquipmentLoadout.new()
	restored.initialize(&"achilles")
	assert_true(restored.restore_snapshot(equipped.to_snapshot(), catalog))
	assert_eq(restored.get_equipped_items().size(), 6)


func test_foreign_cards_and_upgrade_requirements() -> void:
	var m = manager_for()
	var s: ExpeditionSession = m.expedition
	s.combat_won()
	var cards = s.cards
	s.character.champion_progression.current_level = 6
	assert_eq(cards.points(), 6)
	var id: String = cards.add_copy("t_frost")
	assert_true(cards.move_card(id, cards.active[0]))
	assert_false(cards.upgrade_copy(id))
	assert_true(cards.train("thaumaturge"))
	assert_true(cards.train("thaumaturge"))
	assert_false(cards.train("thaumaturge"))
	assert_eq(cards.points(), 1)
	assert_false(cards.train("assassin"))
	assert_false(cards.move_card(id))
	assert_true(cards.specialize("execution"))
	assert_false(cards.specialize("ambush"))


func test_opening_combo_and_periodic_effects_in_common_caster() -> void:
	var f = Factory.make_battlefield(9, 7)
	fields.append(f)
	var hero := Factory.make_unit("Hero", 0)
	var enemy := Factory.make_unit("Enemy", 1)
	hero.attack_power.base_value = 100
	enemy.max_hp.base_value = 1000
	enemy.current_hp = 1000
	f.grid.place_unit(hero, Vector2i(2, 2))
	f.grid.place_unit(enemy, Vector2i(3, 2))
	assert_false(f.caster.cast(hero, Catalog.make_spell("a_open"), enemy.grid_pos).get(
			"failed",
			false,
		))
	assert_false(f.caster.cast(hero, Catalog.make_spell("a_finish"), enemy.grid_pos).get(
			"failed",
			false,
		))
	assert_eq(enemy.current_hp, 830)
	assert_false(f.caster.cast(hero, Catalog.make_spell("a_cut"), enemy.grid_pos).get(
			"failed",
			false,
		))
	assert_eq(enemy.current_hp, 760)
	assert_same(
		enemy.active_statuses.back().get("source"),
		hero,
		"Damage-over-time is attributed to its caster",
	)
	enemy.start_turn()
	enemy.process_statuses()
	assert_eq(enemy.current_hp, 740, "Periodic value is applied by the shared engine")


func test_passive_is_once_per_activation_and_resets_between_battles() -> void:
	var m = manager_for()
	var s: ExpeditionSession = m.expedition
	var f = Factory.make_battlefield(7, 7)
	fields.append(f)
	var hero := Factory.make_unit("Hero", 0)
	var enemy := Factory.make_unit("Enemy", 1)
	hero.set_meta("ct_session", weakref(s))
	hero.attack_power.base_value = 100
	enemy.max_hp.base_value = 1000
	enemy.current_hp = 1000
	f.grid.place_unit(hero, Vector2i(2, 2))
	f.grid.place_unit(enemy, Vector2i(3, 2))
	var spell: Spell = s.cards.weapon_spells()[0]
	assert_false(f.caster.cast(hero, spell, enemy.grid_pos).get("failed", false))
	assert_eq(enemy.current_hp, 934, "55 direct + 11 isolated opener")
	assert_false(f.caster.cast(hero, spell, enemy.grid_pos).get("failed", false))
	assert_eq(enemy.current_hp, 879, "Second cast does not receive opener")
	hero.start_turn()
	assert_false(f.caster.cast(hero, spell, enemy.grid_pos).get("failed", false))
	assert_eq(enemy.current_hp, 813, "New activation restores opener")
	s.character.unit.set_meta("ct_class_passive_turn", 1)
	s.cards.begin_combat()
	assert_false(s.character.unit.has_meta("ct_class_passive_turn"), "Next battle resets passive marker")


func test_improvement_affects_one_copy_and_survives_reload() -> void:
	var m = manager_for()
	var s: ExpeditionSession = m.expedition
	s.combat_won()
	while s.character.champion_progression.current_level < 6:
		while s.character.champion_progression.unspent_attribute_points > 0:
			s.character.champion_progression.spend_attribute(&"power")
		if s.character.champion_progression.current_level >= 4 and s.cards.specialization.is_empty():
			s.cards.specialize("execution")
		while not s.advancement_step.is_empty():
			if s.advancement_step == "advancement":
				s.cards.resolve_progression("skip")
			else:
				s.advance_level_step()
		var halt := ExpeditionRouteCatalog.is_halt(str(s.route.get_current_node().kind))
		assert_true(
			s
			.claim("leave_hub" if halt else "class_continue", m.run_inventory, m.item_catalog)
			.success
		)
		assert_true(s.enter(str(s.route.get_available_nodes()[0].id)))
		if s.route.phase == "combat":
			assert_true(s.combat_won())
	var cards = s.cards
	var first: String = cards.active[0]
	var second: String = cards.active[1]
	assert_same(
		cards.spells_for(first)[0],
		cards.spells_for(first)[0],
		"HUD keeps stable spell identity",
	)
	assert_true(cards.train("assassin"))
	assert_true(cards.upgrade_copy(first))
	assert_false(cards.upgrade_copy(first))
	assert_false(cards.spells_for(first)[0].needs_line_of_sight)
	assert_true(cards.spells_for(second)[0].needs_line_of_sight)
	assert_eq(cards.points(), 1)
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(m.get_expedition_snapshot()))
	assert_true(m.restore_expedition_snapshot(snapshot))
	assert_true(m.expedition.cards.copy_for(first).upgraded)
	assert_false(m.expedition.cards.copy_for(second).get("upgraded", false))
	assert_eq(m.expedition.cards.points(), 1)
	assert_null(Catalog.make_spell("a_open", -1))
	assert_null(Catalog.make_spell("a_open", 5))
	assert_null(Catalog.make_spell("a_open", 2, true))


func test_all_four_routes_progress_and_restore_at_every_reward_boundary() -> void:
	for class_id in Catalog.CLASSES:
		var m = manager_for(class_id)
		for depth in range(1, 21):
			var s: ExpeditionSession = m.expedition
			if depth > 1:
				var choices := s.route.get_available_nodes()
				assert_false(choices.is_empty(), "available route at depth %d" % depth)
				assert_true(s.enter(str(choices[0].id)))
			if s.route.phase == "combat":
				assert_true(s.combat_won())
			while s.character.champion_progression.unspent_attribute_points > 0:
				assert_true(s.character.champion_progression.spend_attribute(&"power"))
			if (
				s.character.champion_progression.current_level >= 4
				and s.cards.specialization.is_empty()
			):
				assert_true(s.cards.specialize(Catalog.SPECS[class_id][0][0]))
			while not s.advancement_step.is_empty():
				if s.advancement_step == "advancement":
					assert_true(s.cards.resolve_progression("skip"))
				else:
					assert_true(s.advance_level_step().success)
			if depth == 5 and s.cards.points() >= 3:
				assert_true(s.cards.train(class_id))
			assert_eq(s.build.points, 0)
			var snapshot: Dictionary = JSON.parse_string(
				JSON.stringify(m.get_expedition_snapshot())
			)
			assert_true(m.restore_expedition_snapshot(snapshot), "%s depth %d" % [class_id, depth])
			s = m.expedition
			var id := (
				"finish"
				if depth == 20
				else (
					"leave_hub"
					if ExpeditionRouteCatalog.is_halt(str(s.route.get_current_node().kind))
					else "class_continue"
				)
			)
			assert_true(s.claim(id, m.run_inventory, m.item_catalog).success)
		assert_eq(m.expedition.route.phase, "complete")


func test_rune_changes_equipped_stats_once_and_survives_restore() -> void:
	var m = manager_for()
	var s: ExpeditionSession = m.expedition
	s.combat_won()
	var item: ItemInstance = m.run_inventory.get_slots().filter(
		func(value):
			return value != null,
	)[0]
	var service := EquipmentService.new()
	service.initialize(m.item_catalog)
	assert_true(
		service.equip(m.run_inventory, s.character, item.instance_id, ItemDefinition
		.EquipmentSlot
		.WEAPON).success
	)
	var before := s.character.unit.attack_power.get_value()
	var grant: Dictionary = m.run_inventory.try_add(&"class_rune_edge")
	assert_true(grant.success)
	assert_true(s.cards.socket_rune(grant.instance_ids[0], item.instance_id))
	assert_eq(s.character.unit.attack_power.get_value(), before + 4.)
	assert_false(s.cards.socket_rune(grant.instance_ids[0], item.instance_id))
	service.rebuild_state(s.character)
	assert_eq(
		s.character.unit.attack_power.get_value(),
		before + 4.,
		"Rebuild never stacks the rune",
	)
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(m.get_expedition_snapshot()))
	assert_true(m.restore_expedition_snapshot(snapshot))
	assert_eq(m.expedition.character.unit.attack_power.get_value(), before + 4.)
	assert_true(service.unequip(m.run_inventory, m.expedition.character, ItemDefinition
		.EquipmentSlot
		.WEAPON).success)
	assert_eq(m.expedition.character.equipment_loadout.get_equipped_items().size(), 0)
	var bad_item := item.to_snapshot()
	bad_item.rune_id = 42
	assert_null(ItemInstance.from_snapshot(bad_item, m.item_catalog))


func test_combat_receipt_survives_sale_equipment_and_reload() -> void:
	var m = manager_for()
	var s: ExpeditionSession = m.expedition
	var xp_before := s.character.champion_progression.current_xp
	var gold_before := s.gold
	assert_true(s.combat_won())
	var receipt: Dictionary = s.cards.battle_results[s.route.current_node_id].duplicate(true)
	assert_eq(int(receipt.xp), s.character.champion_progression.current_xp - xp_before)
	assert_eq(int(receipt.gold), s.gold - gold_before)
	var results := preload("res://ui/expedition/class_combat_results.gd")
	var original: Array = results.records_for(s).map(
		func(row):
			return [row.id, row.count],
	)
	assert_eq(original.size(), 2, "first victory grants a card and a weapon")
	assert_true(s.cards.sell(s.cards.last_drops[0]))
	assert_eq(
		results.records_for(s).map(
			func(row):
				return [row.id, row.count],
		),
		original,
		"sold card stays in the receipt",
	)
	var item: ItemInstance = m.run_inventory.get_slots().filter(
		func(value):
			return value != null,
	)[0]
	var equipment := EquipmentService.new()
	assert_true(equipment.initialize(m.item_catalog))
	assert_true(
		equipment.equip(m.run_inventory, s.character, item.instance_id, ItemDefinition
		.EquipmentSlot
		.WEAPON).success
	)
	s.cards.record_reward(s.route.get_current_node(), { "gained_xp": 9999 }, 9999)
	assert_eq(
		s.cards.battle_results[s.route.current_node_id],
		receipt,
		"second reward record cannot overwrite the receipt",
	)
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(m.get_expedition_snapshot()))
	assert_true(m.restore_expedition_snapshot(snapshot))
	assert_eq(
		results.records_for(m.expedition).map(
			func(row):
				return [row.id, row.count],
		),
		original,
	)
	assert_eq(m.expedition.cards.battle_results[m.expedition.route.current_node_id], receipt)
	var bad := snapshot.duplicate(true)
	bad.session.cards_run.battle_results[s.route.current_node_id].duration_seconds = "invalid"
	assert_false(m.restore_expedition_snapshot(bad))
	snapshot.session.cards_run.erase("battle_results")
	assert_true(
		m.restore_expedition_snapshot(snapshot),
		"older class saves without receipts remain loadable",
	)


func test_combat_receipt_keeps_report_statistics_and_duration() -> void:
	var m = manager_for()
	var s: ExpeditionSession = m.expedition
	s.character.unit.activation_index = 3
	assert_true(s.combat_won())
	var report := CombatReport.new()
	report.started_at_msec = 1000
	report.completed_at_msec = 66500
	var hero := CharacterCombatReport.new()
	hero.character_id = s.character.character_id
	hero.damage_dealt = 73
	hero.damage_taken = 12
	hero.shield_applied = 8
	hero.kills = 2
	report.character_reports.append(hero)
	s.cards.record_combat(report)
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(m.get_expedition_snapshot()))
	assert_true(m.restore_expedition_snapshot(snapshot))
	var receipt: Dictionary = m.expedition.cards.battle_results[s.route.current_node_id]
	assert_eq(receipt.duration_seconds, 65)
	assert_eq(receipt.turns, 3, "combat cleanup must not erase the reported turn count")
	assert_eq(receipt.damage_dealt, 73)
	assert_eq(receipt.damage_taken, 12)
	assert_eq(receipt.shield, 8)
	assert_eq(receipt.kills, 2)


func test_combat_receipt_groups_duplicate_drops_without_changing_rewards() -> void:
	var m = manager_for()
	var s: ExpeditionSession = m.expedition
	assert_true(s.combat_won())
	var receipt: Dictionary = s.cards.battle_results[s.route.current_node_id]
	receipt.card_families.append(receipt.card_families[0])
	var results := preload("res://ui/expedition/class_combat_results.gd")
	var rows: Array = results.records_for(s)
	assert_eq(rows[0].count, 2)
	assert_eq(s.cards.copies.size(), 11, "presentation never grants extra copies")
	assert_not_null(rows[0].icon)
	assert_true(rows[0].body.contains("PA"))


func test_invalid_mastery_and_duplicate_cards_do_not_replace_a_run() -> void:
	var m = manager_for()
	var original = m.expedition
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(m.get_expedition_snapshot()))
	snapshot.session.cards_run.masteries.thaumaturge = 4
	assert_false(m.restore_expedition_snapshot(snapshot))
	assert_same(m.expedition, original)
	snapshot = JSON.parse_string(JSON.stringify(m.get_expedition_snapshot()))
	snapshot.session.cards_run.spent = 0.5
	assert_false(m.restore_expedition_snapshot(snapshot))
	assert_same(m.expedition, original)
	snapshot = JSON.parse_string(JSON.stringify(m.get_expedition_snapshot()))
	snapshot.session.cards_run.active[0] = snapshot.session.cards_run.active[1]
	assert_false(m.restore_expedition_snapshot(snapshot))
	assert_same(m.expedition, original)


func test_every_card_executes_on_the_shared_grid() -> void:
	for id in Catalog.pool():
		var f = Factory.make_battlefield(11, 7)
		fields.append(f)
		var hero := Factory.make_unit("Hero", 0)
		var enemy := Factory.make_unit("Enemy", 1)
		hero.attack_power.base_value = 100
		enemy.max_hp.base_value = 1000
		enemy.current_hp = 1000
		f.grid.place_unit(hero, Vector2i(3, 3))
		var spell := Catalog.make_spell(id, 2)
		var target := Vector2i(3 + maxi(1, spell.minimum_range), 3)
		if spell.caster_movement == Spell.CasterMovement.NONE:
			f.grid.place_unit(enemy, target)
		else:
			f.grid.place_unit(enemy, Vector2i(9, 3))
		if spell.can_target_self:
			target = hero.grid_pos
		var report: Dictionary = f.caster.cast(hero, spell, target)
		assert_false(report.get("failed", false), id)
		assert_eq(hero.current_ap, 6 - spell.ap_cost, id)
		if spell.deals_damage():
			assert_lt(enemy.current_hp, 1000, id)
		elif spell.caster_movement != Spell.CasterMovement.NONE:
			assert_eq(hero.grid_pos, target, id)
		else:
			assert_gt(hero.current_shield, 0, id)
