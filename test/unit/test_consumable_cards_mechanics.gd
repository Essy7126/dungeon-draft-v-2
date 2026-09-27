extends GutTest
const Profile := preload("res://core/expedition/consumable_cards_profile.gd")
const Catalog := preload("res://core/expedition/consumable_card_catalog.gd")
const Battle := preload("res://core/expedition/consumable_cards_battle.gd")
const Effects := preload("res://core/expedition/consumable_card_effects.gd")
const Turns := preload("res://core/expedition/consumable_card_turns.gd")
const Enemies := preload("res://core/expedition/consumable_enemy_rules.gd")
const Run := preload("res://core/expedition/consumable_cards_run.gd")
var battles: Array = []


func test_all_96_card_forms_cast_legally_and_consume_exactly_one_uid() -> void:
	for row in Catalog.data().cards:
		for improved in [false, true]:
			var b = fixture(row.affinity if row.affinity in Catalog.CLASSES else "gardien")
			b.grid.relocate_unit(b.hero, Vector2i(3, 4))
			var definition := Catalog.card(row.id, improved)
			assert_true(b.grid.relocate_unit(b.enemies[0], Vector2i(3, 4 - maxi(1, int(definition.min)))))
			b.hero.current_hp = 30
			Effects.guard(b.hero, 1.0, b.cards)
			for enemy in b.enemies: Effects.apply_state(enemy, "mark", 10, 2, b.hero, {"origin": "direct"})
			if improved: b.cards.upgraded_ids.assign([str(row.id)])
			var uid := give(b, row.id)
			b.cards.selected = uid
			b.cards.action_options = {"sacrifice": 0, "pull": 1}
			var spell: Spell = b.cards.family_spell(row.id)
			var legal := Vector2i(-1, -1)
			for x in 7:
				for y in 7:
					if legal.x < 0 and b.caster.get_cast_failure_reason(b.hero, spell, Vector2i(x, y)) == &"": legal = Vector2i(x, y)
			assert_gte(legal.x, 0, "%s improved=%s" % [row.id, improved])
			if legal.x >= 0:
				assert_true(b.command({"kind": "card", "uid": uid, "cell": [legal.x, legal.y], "options": {"sacrifice": 0, "pull": 1}}).success, row.id)
				assert_true(b.cards.consumed.has(uid), row.id)
				assert_eq(b.cards.consumed.size(), 1, row.id)
				assert_true(b.cards.copy_for(uid).is_empty(), row.id)
			b.dispose()
			battles.erase(b)


func after_each() -> void:
	for battle in battles:
		battle.dispose()
	battles.clear()


func fixture(class_id := "assassin", index := 3):
	var cards = Profile.create_cards(Catalog.preset(class_id))
	cards.level = 4
	var battle := Battle.new()
	assert_true(battle.initialize(cards, index))
	battles.append(battle)
	return battle


func give(battle, family: String) -> String:
	var cards = battle.cards
	for pile in [cards.hand, cards.draw_pile, cards.discard, cards.active]:
		pile.clear()
	var uid: String = cards.acquire(family, "loot", "mechanic:" + str(cards.serial))
	cards.active.append(uid)
	cards.hand.append(uid)
	cards.opening.clear()
	cards.used_families.clear()
	battle.hero.current_ap = 4
	return uid


func test_relay_choice_survives_restore_and_cannot_be_retransmitted() -> void:
	var b = fixture()
	b.cards.specialization = "relay"
	b.grid.relocate_unit(b.hero, Vector2i(3, 4))
	var target: Unit = b.enemies[0]
	b.grid.relocate_unit(target, Vector2i(3, 3))
	b.grid.relocate_unit(b.enemies[1], Vector2i(4, 3))
	target.current_hp = 1
	Effects.apply_state(target, "mark", 20, 2, b.hero, { "origin": "direct" })
	var uid := give(b, "n01")
	assert_true(b.command({ "kind": "card", "uid": uid, "cell": [3, 3] }).success)
	assert_eq(b.cards.pending_choice.get("kind"), "relay")
	var next_cards = Profile.create_cards(Catalog.preset())
	assert_true(next_cards.restore(JSON.parse_string(JSON.stringify(b.cards.snapshot()))))
	var resumed = Battle.restore(next_cards, b.snapshot())
	assert_not_null(resumed)
	if resumed == null:
		return
	battles.append(resumed)
	assert_true(resumed.command({ "kind": "relay", "target": str(resumed.enemies[1].unit_id) }).success)
	var mark: Dictionary = Effects.states(resumed.enemies[1]).mark
	assert_eq(mark.origin, "relay")
	assert_almost_eq(float(mark.amount), .2 * resumed.hero.attack_power.get_value(), .001)
	Turns.end_hero(next_cards, resumed.grid)
	assert_true(Effects.states(resumed.enemies[1]).has("mark"))
	next_cards.start_turn()
	Turns.end_hero(next_cards, resumed.grid)
	assert_false(Effects.states(resumed.enemies[1]).has("mark"))


func test_interrupted_execution_cancels_telegraph_and_boss_phase_keeps_its_line() -> void:
	var b = fixture()
	var executor: Unit = b.enemies.back()
	executor.set_meta("cc2_intent", { "cells": [[3, 5]], "multiplier": 1.5 })
	Effects.apply_state(executor, "stasis", 1, 1, b.hero)
	Effects.apply_state(executor, "stasis_ward", 1, 3, b.hero)
	var result := Enemies.activate(
		executor,
		b.hero,
		[b.hero] + b.enemies,
		b.grid,
		b.terrain,
		b.caster,
		b.reference_power(),
	)
	assert_eq(result.kind, "skipped")
	assert_true(executor.get_meta("cc2_intent").is_empty())
	assert_eq(int(Effects.states(executor).stasis_ward.duration), 3)
	for _activation in 3:
		Turns.apply_activation_statuses(executor, b.grid)
	assert_false(Effects.states(executor).has("stasis_ward"))
	var boss_field = fixture("gardien", 12)
	var boss: Unit = boss_field.enemies[0]
	boss.set_meta("cc2_intent", { "cells": [[3, 4], [3, 5], [3, 6]], "multiplier": 1.4 })
	boss.current_hp = 400
	Enemies.update_boss_phase(boss_field.enemies)
	assert_eq(int(boss.get_meta("cc2_phase")), 2)
	var resumed = Battle.restore(boss_field.cards, boss_field.snapshot())
	assert_not_null(resumed)
	if resumed != null:
		battles.append(resumed)
		assert_eq(resumed.enemies[0].get_meta("cc2_intent").cells.size(), 3)


func test_guard_sacrifice_preview_matches_actual_and_does_not_publish() -> void:
	var b = fixture("gardien")
	b.grid.relocate_unit(b.hero, Vector2i(3, 4))
	b.grid.relocate_unit(b.enemies[0], Vector2i(3, 3))
	Effects.guard(b.hero, 1.0, b.cards)
	var uid := give(b, "g09")
	var runtime := Run.new()
	runtime.cards = b.cards
	runtime.battle = b
	var before: Dictionary = b.snapshot()
	var request := { "kind": "card", "uid": uid, "cell": [3, 3], "options": { "sacrifice": 7 } }
	var preview: Dictionary = runtime.preview(request)
	assert_true(preview.success)
	assert_eq(b.snapshot(), before)
	assert_true(b.command(request).success)
	for row in preview.units:
		var unit: Unit = b.unit_for(row.id)
		assert_eq(unit.current_hp, int(row.hp))
		assert_eq(unit.current_shield, int(row.guard))
	assert_false(b.cards.consumed.is_empty())
	runtime.battle = null


func test_water_transform_steam_blocks_sight_and_no_enter_tick() -> void:
	var b = fixture("thaumaturge")
	b.grid.relocate_unit(b.enemies[0], Vector2i(3, 3))
	var uid := give(b, "t04")
	assert_true(b.command({ "kind": "card", "uid": uid, "cell": [3, 3] }).success)
	assert_eq(b.terrain.runtime_service.get_state(Vector2i(3, 3)).surface_id, &"water")
	uid = give(b, "t02")
	assert_true(b.command({ "kind": "card", "uid": uid, "cell": [3, 3] }).success)
	assert_eq(b.terrain.runtime_service.get_state(Vector2i(3, 3)).surface_id, &"steam")
	assert_false(b.pathfinder.has_line_of_sight(Vector2i(3, 5), Vector2i(3, 1)))
	assert_lte(b.cards.surface_groups.size(), 2)
	var saved: Dictionary = b.snapshot()
	var restored = Battle.restore(b.cards, saved)
	assert_not_null(restored)
	if restored != null:
		battles.append(restored)
		assert_eq(restored.snapshot(), saved)
		Turns.end_enemy_phase(restored.cards, restored.grid, restored.terrain)
		assert_ne(restored.terrain.runtime_service.get_state(Vector2i(3, 3)).surface_id, &"steam")


func test_malformed_intent_and_foreign_enemy_identity_rejected() -> void:
	var b = fixture()
	var snapshot: Dictionary = b.snapshot()
	snapshot.units[1].metadata.cc2_intent = { "cells": "broken", "multiplier": 1.5 }
	assert_null(Battle.restore(b.cards, snapshot))
	snapshot = b.snapshot()
	snapshot.units[1].metadata.cc2_kind = "boss"
	assert_null(Battle.restore(b.cards, snapshot))


func test_third_surface_group_removes_oldest_cells_and_survives_restore() -> void:
	var b = fixture("thaumaturge", 1)
	# Three distinct families: the Unit once-per-activation contract remains
	# active even when this focused fixture replenishes AP between casts.
	var cells := [Vector2i(1, 4), Vector2i(5, 4), Vector2i(3, 6)]
	var families := ["t04", "t05", "t06"]
	for index in 3:
		var cell: Vector2i = cells[index]
		var uid := give(b, families[index])
		assert_true(b.command({ "kind": "card", "uid": uid, "cell": [cell.x, cell.y] }).success)
	assert_eq(b.cards.surface_groups.size(), 2)
	assert_ne(b.terrain.get_surface_id(Vector2i(1, 4)), &"water")
	assert_eq(b.terrain.get_surface_id(Vector2i(5, 4)), &"fire")
	assert_eq(b.terrain.get_surface_id(Vector2i(3, 6)), &"ice")
	var resumed = Battle.restore(b.cards, b.snapshot())
	assert_not_null(resumed)
	if resumed != null:
		battles.append(resumed)
		assert_eq(resumed.cards.surface_groups.size(), 2)
		assert_ne(resumed.terrain.get_surface_id(Vector2i(1, 4)), &"water")


func test_room_commands_pay_once_and_restore_used_mechanisms() -> void:
	for row in [
		{ "index": 4, "mode": "forge", "value": 5, "cost": 1 },
		{ "index": 5, "mode": "delay", "value": 0, "cost": 1 },
		{ "index": 8, "mode": "seal", "value": 0, "cost": 2 },
		{ "index": 9, "mode": "discharge", "value": 0, "cost": 1 },
	]:
		var b = fixture("gardien", row.index)
		b.grid.relocate_unit(b.hero, Vector2i(0, 4))
		b.hero.current_ap = 4
		if row.mode == "discharge":
			b.room.charges[0] = 2
		var command := { "kind": "room", "mode": row.mode, "value": row.value }
		assert_true(b.command(command).success, row.mode)
		assert_eq(b.hero.current_ap, 4 - int(row.cost))
		var saved: Dictionary = b.snapshot()
		assert_false(b.command(command).success)
		assert_eq(b.snapshot(), saved)
		var resumed = Battle.restore(b.cards, saved)
		assert_not_null(resumed)
		if resumed != null:
			battles.append(resumed)
			assert_false(resumed.command(command).success)
			assert_eq(resumed.hero.current_ap, 4 - int(row.cost))


func test_lethal_enemy_attack_does_not_trigger_postmortem_reflection() -> void:
	var b = fixture("gardien", 1)
	b.cards.active_relics.assign(["mirror"])
	b.hero.current_hp = 1
	b.hero.clear_shield()
	var enemy: Unit = b.enemies[0]
	var hp := enemy.current_hp
	Enemies.attack(enemy, b.hero)
	assert_false(b.hero.is_alive)
	assert_eq(enemy.current_hp, hp)
	b._check_outcome()
	assert_eq(b.outcome, "defeat")
