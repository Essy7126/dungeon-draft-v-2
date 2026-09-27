extends GutTest
const Runtime = preload("res://battle/consumable_cards_runtime.gd")
const Catalog = preload("res://core/expedition/consumable_card_catalog.gd")
var driver: Node
var battle: Node
var path := ""


class Manager:
	extends "res://core/game_manager.gd"
	func _request_scene_change(
		_path: String,
		_mode: PersistentRunUI.RunUIMode = PersistentRunUI.RunUIMode.NON_COMBAT,
	) -> void:
		pass


	func start_next_battle() -> void:
		pass


	func _ensure_persistent_run_ui() -> PersistentRunUI:
		return null


func before_each() -> void:
	driver = Manager.new()
	add_child(driver)
	driver.select_run_variant("cards")
	driver.expedition_save_path = "user://rooms_driver.json"
	path = "user://rooms_live_%d.json" % Time.get_ticks_usec()
	GameManager.cleanup_run_state()
	GameManager.expedition_save_path = path


func clear_battle() -> void:
	if is_instance_valid(battle):
		remove_child(battle)
		battle.free()
	battle = null


func after_each() -> void:
	clear_battle()
	GameManager._battle_outcome_generation += 1
	GameManager.cleanup_run_state()
	GameManager.expedition_save_path = ExpeditionSaveService.SAVE_PATH
	GameManager.selected_run_variant = "classic"
	if is_instance_valid(driver):
		driver.cleanup_run_state()
		driver.free()
	ExpeditionSaveService.remove_snapshot(path)
	ExpeditionSaveService.remove_snapshot("user://rooms_driver.json")
	await wait_process_frames(2)


func load_depth(depth: int) -> void:
	driver.cleanup_run_state()
	ExpeditionSaveService.remove_snapshot("user://rooms_driver.json")
	assert_true(driver.start_expedition(33, { }, false, true, "normal", true))
	while int(driver.expedition.route.get_current_node().depth) < depth:
		var session: ExpeditionSession = driver.expedition
		if session.route.phase == "combat":
			assert_true(session.combat_won())
			assert_true(session.acknowledge_combat_receipt().success)
		if session.cards.level >= 4 and session.cards.specialization.is_empty():
			assert_true(session.cards.specialize("execution"))
		while not session.advancement_step.is_empty():
			assert_true(session.advance_level_step().success)
		var offers: Array = session.reward_options(driver.item_catalog)
		assert_true(session.claim(str(offers[0].id), driver.run_inventory, driver.item_catalog).success)
		assert_true(driver.choose_expedition_node(str(session.route.get_available_nodes()[0].id)))
	await mount(driver.get_expedition_snapshot())


func mount(snapshot: Dictionary) -> void:
	clear_battle()
	GameManager.cleanup_run_state()
	assert_true(GameManager.restore_expedition_snapshot(snapshot))
	battle = GameManager.get_current_room().battle_scene.instantiate()
	add_child(battle)
	await wait_process_frames(3)
	if GameManager.expedition.combat_checkpoint.is_empty():
		battle._deployment.on_cell_clicked(battle._deployment._deploy_zone[0])
	for _tick in 300:
		await wait_seconds(.02)
		if battle._can_accept_player_intent():
			break
	assert_true(battle._can_accept_player_intent())


func near(unit: Unit, target: Vector2i) -> bool:
	for cell in [
		target,
		target + Vector2i.LEFT,
		target + Vector2i.UP,
		target + Vector2i.DOWN,
		target + Vector2i.RIGHT,
	]:
		if battle.grid.is_walkable(cell, unit) and battle.grid.relocate_unit(unit, cell):
			return true
	fail_test("No fixture cell near mechanism")
	return false


func test_five_room_commands_are_visible_saved_and_not_replayed_on_resume() -> void:
	for entry in [
		[5, "forge", "rail_1"],
		[6, "hourglass", "delay"],
		[8, "garden", "pedestal_0"],
		[12, "convoy", "seal"],
		[13, "reservoir", "discharge_0"],
		[17, "garden", "pedestal_1"],
	]:
		await load_depth(entry[0])
		var runtime = battle._cards_runtime
		var room = runtime.room_rules
		assert_eq(room.room_id, entry[1])
		assert_eq(
			GameManager.get_current_room().battle_scene.resource_path,
			"res://battle/painted/registered_terrain/RegisteredTerrainBattle.tscn",
		)
		var hero: Unit = GameManager.expedition.character.unit
		var cards = GameManager.expedition.cards
		assert_true(
			near(
				hero,
				room.layout.reservoirs[0] if room.room_id == "reservoir" else room.layout.lever,
			)
		)
		if room.room_id == "reservoir":
			room.end_hero()
			assert_gt(room.state.charges[0], 0)
			hero.current_ap = 4 # next decision fixture; charge storage itself is real
		var hand: Array = cards.hand.duplicate()
		var consumed: Dictionary = cards.consumed.duplicate(true)
		await wait_process_frames(3)
		var button: Button = battle.action_bar.find_child(
			"RoomAction_" + str(entry[2]),
			true,
			false,
		)
		assert_not_null(button)
		assert_false(button.disabled, room.failure(entry[2]))
		var target: Unit = room.current_target()
		var target_hp := target.current_hp
		button.pressed.emit()
		assert_false(runtime.save_failed)
		assert_true(room.state.used)
		assert_eq(hero.current_ap, 2 if entry[2] == "seal" else 3)
		match room.room_id:
			"forge":
				assert_eq(room.state.rail, 1)
				assert_false(room.danger_cells().is_empty())
				assert_true(
					room.danger_cells().all(
						func(cell):
							return cell.y == room.layout.rails[1],
					)
				)
			"hourglass":
				assert_true(room.state.delayed)
			"garden":
				assert_eq(target.grid_pos, room.layout.pedestals[int(str(entry[2])[-1])])
			"convoy":
				assert_true(room.state.sealed)
				for carrier in room.carriers:
					assert_false(room.is_courier(carrier))
			"reservoir":
				assert_eq(room.state.charges[0], 0)
				assert_lt(target.current_hp, target_hp)
		var before: Dictionary = room.state.duplicate(true)
		var positions: Array = battle.units.map(
			func(u):
				return u.grid_pos,
		)
		var saved := ExpeditionSaveService.read_snapshot(path)
		assert_eq(saved.session.combat_checkpoint.version, 2.0)
		await mount(saved)
		assert_eq(battle._cards_runtime.room_rules.state, JSON.parse_string(JSON.stringify(before)))
		assert_eq(
			battle.units.map(
				func(u):
					return u.grid_pos,
			),
			positions,
		)
		assert_eq(GameManager.expedition.cards.hand, hand)
		assert_eq(GameManager.expedition.cards.consumed, consumed)
		assert_false(battle._cards_runtime.use_room_command(entry[2]))
		var invalid := saved.duplicate(true)
		invalid.session.combat_checkpoint.room.charges[0] = -1
		assert_false(GameManager.restore_expedition_snapshot(invalid))
		assert_eq(battle._cards_runtime.room_rules.state, JSON.parse_string(JSON.stringify(before)))


func test_sablier_delays_once_then_resolves_and_rearms_its_actual_telegraph() -> void:
	await load_depth(6)
	var runtime = battle._cards_runtime
	var room = runtime.room_rules
	var hero: Unit = GameManager.expedition.character.unit
	assert_true(near(hero, room.layout.lever))
	room.state.clock = [hero.grid_pos.x, hero.grid_pos.y]
	assert_true(runtime.use_room_command("delay"))
	var hp := hero.current_hp
	runtime.round_started(2)
	assert_eq(hero.current_hp, hp)
	assert_false(room.state.delayed)
	assert_true(room.state.debt)
	assert_false(runtime.use_room_command("delay"))
	assert_has(room.danger_cells(), hero.grid_pos)
	runtime.round_started(3)
	assert_eq(hero.current_hp, hp - Runtime.Math.rounded(.7 * 1.5 * room.power()))
	assert_false(room.state.debt)
	assert_false(room.state.used)
	assert_eq(room.state.clock, [hero.grid_pos.x, hero.grid_pos.y])


func test_formation_exists_in_real_combat_seven_and_breaks_when_hero_is_adjacent() -> void:
	await load_depth(10)
	var actors: Array = battle.units.filter(
		func(u):
			return u.team == 1,
	)
	var guards: Array = actors.filter(
		func(u):
			return u.get_meta("cc2_variant", "") == "formation",
	)
	assert_eq(guards.size(), 1)
	var guard: Unit = guards[0]
	var ally: Unit = actors[1] if actors[0] == guard else actors[0]
	assert_true(near(ally, guard.grid_pos))
	var hero: Unit = GameManager.expedition.character.unit
	for y in battle.grid.rows:
		for x in battle.grid.cols:
			var cell := Vector2i(x, y)
			if battle.grid.is_walkable(cell, hero) and battle.grid.manhattan(cell, guard.grid_pos) > 2:
				battle.grid.relocate_unit(hero, cell)
				break
	Runtime.Enemies.prepare_activation(
		guard,
		hero,
		battle.units,
		battle.grid,
		battle.terrain_effects,
		57.0,
	)
	assert_eq(ally.current_shield, 14)
	assert_eq(guard.current_shield, 0)
	assert_true(near(hero, guard.grid_pos))
	Runtime.Enemies.prepare_activation(
		guard,
		hero,
		battle.units,
		battle.grid,
		battle.terrain_effects,
		57.0,
	)
	assert_eq(ally.current_shield, 0)


func test_boss_periodic_transition_keeps_pending_intent_and_same_health_pool() -> void:
	await load_depth(20)
	var boss: Unit = battle.units.filter(
		func(u):
			return u.get_meta("cc2_boss", false),
	)[0]
	var hero: Unit = GameManager.expedition.character.unit
	var intent := { "cells": [[hero.grid_pos.x, hero.grid_pos.y]], "multiplier": 1.4 }
	boss.set_meta("cc2_intent", intent.duplicate(true))
	boss.current_hp = floori(boss.max_hp.get_int() * .51)
	boss.clear_shield()
	var hp := boss.current_hp
	var burn := ceili(boss.max_hp.get_int() * .04)
	Runtime.Effects.apply_state(boss, "burn", burn, 1, hero)
	assert_false(battle._cards_runtime.begin_activation(boss))
	assert_eq(boss.current_hp, hp - burn)
	assert_eq(boss.get_meta("cc2_phase"), 2)
	assert_eq(boss.get_meta("cc2_intent"), intent)
	var report := Runtime.Enemies.prepare_activation(
		boss,
		hero,
		battle.units,
		battle.grid,
		battle.terrain_effects,
		112.0,
		false,
		false,
	)
	assert_eq(report.kind, "resolve_intent")
	assert_true(boss.get_meta("cc2_intent").is_empty())
	assert_true(battle._cards_runtime.checkpoint())
	var saved := ExpeditionSaveService.read_snapshot(path)
	await mount(saved)
	boss = battle.units.filter(
		func(u):
			return u.get_meta("cc2_boss", false),
	)[0]
	assert_eq(boss.get_meta("cc2_phase"), 2)
	assert_eq(boss.current_hp, hp - burn)
	var older := saved.duplicate(true)
	older.session.combat_checkpoint.version = 1
	older.session.combat_checkpoint.erase("room")
	for record in older.session.combat_checkpoint.units:
		if record.metadata.get("cc2_boss", false):
			record.metadata.cc2_phase = 1
	await mount(older)
	boss = battle.units.filter(
		func(u):
			return u.get_meta("cc2_boss", false),
	)[0]
	assert_eq(boss.get_meta("cc2_phase"), 2)
	assert_eq(boss.current_hp, hp - burn)


func advance_round(expected: int) -> void:
	battle._commit_player_end_turn()
	for _tick in 900:
		await wait_seconds(.02)
		if (
			battle._battle_over
			or (
				GameManager.expedition.cards.round_index == expected
				and battle._can_accept_player_intent()
			)
		):
			break
	assert_false(battle._battle_over)
	assert_eq(GameManager.expedition.cards.round_index, expected)
	assert_true(battle._can_accept_player_intent())


func test_convoy_stasis_blocks_delivery_then_sacrifices_and_bonuses_survive_reload() -> void:
	await load_depth(12)
	var room = battle._cards_runtime.room_rules
	var hero: Unit = GameManager.expedition.character.unit
	assert_eq(room.carriers.size(), 2)
	var maximum: int = room.chief.max_hp.get_int()
	var attack: float = room.chief.attack_power.get_value()
	var ids: Array = room.carriers.map(
		func(u):
			return str(u.unit_id),
	)
	var cards = GameManager.expedition.cards
	var key := str(room.definition.index)
	for carrier in room.carriers:
		assert_true(near(carrier, room.layout.altar))
		Runtime.Effects.apply_state(carrier, "stasis", 1, 1, hero)
		cards.loot_commitments[key][str(carrier.unit_id)] = {
			"cards": ["n01"],
			"equipment": [],
			"relics": [],
			"bags": [],
		}
	await advance_round(2)
	assert_true(room.state.deliveries.is_empty())
	for carrier in room.carriers:
		assert_true(carrier.is_alive)
		assert_false(Runtime.Effects.states(carrier).has("stasis"))
	await advance_round(3)
	assert_eq(room.state.deliveries.size(), 2)
	assert_eq(room.chief.max_hp.get_int(), maximum + 2 * Runtime.Math.rounded(.8 * 68))
	assert_eq(room.chief.attack_power.get_value(), attack + 2 * Runtime.Math.rounded(.02 * 420))
	for carrier in room.carriers:
		assert_false(carrier.is_alive)
		assert_true(carrier.get_meta("cc2_sacrificed"))
		assert_true(cards.loot_commitments[key][str(carrier.unit_id)].forfeited)
	assert_false(battle._cards_runtime.save_failed)
	maximum = room.chief.max_hp.get_int()
	attack = room.chief.attack_power.get_value()
	var hp: int = room.chief.current_hp
	var saved := ExpeditionSaveService.read_snapshot(path)
	await mount(saved)
	room = battle._cards_runtime.room_rules
	cards = GameManager.expedition.cards
	assert_eq(room.state.deliveries, ids)
	assert_eq(room.chief.max_hp.get_int(), maximum)
	assert_eq(room.chief.current_hp, hp)
	assert_eq(room.chief.attack_power.get_value(), attack)
	# Victory transaction fixture: only test loot eligibility here.
	assert_true(GameManager.expedition.combat_won())
	assert_eq(cards.receipts["reward:" + key].forfeited, ids)
	for id in ids:
		assert_false(
			cards.copies.any(
				func(copy):
					return str(copy.receipt).ends_with(":" + id),
			)
		)


func test_room_write_failure_blocks_commands_until_retry() -> void:
	await load_depth(5)
	var hero: Unit = GameManager.expedition.character.unit
	var runtime = battle._cards_runtime
	assert_true(near(hero, runtime.room_rules.layout.lever))
	GameManager.expedition_save_path = "user://missing_audit_directory/save.json"
	assert_true(runtime.use_room_command("rail_0"))
	assert_true(runtime.save_failed)
	assert_false(battle._can_accept_player_intent())
	assert_false(runtime.use_room_command("rail_1"))
	GameManager.expedition_save_path = path
	assert_true(runtime.checkpoint())
	assert_false(runtime.save_failed)
	var saved := ExpeditionSaveService.read_snapshot(path)
	await mount(saved)
	assert_eq(GameManager.expedition.character.unit.current_ap, 3)
	assert_true(battle._cards_runtime.room_rules.state.used)


func test_garden_and_reservoir_continue_on_the_next_living_enemy_after_reload() -> void:
	for depth in [8, 13]:
		await load_depth(depth)
		var runtime = battle._cards_runtime
		var room = runtime.room_rules
		var first: Unit = room.current_target()
		Runtime.Effects.hit(first, null, first.current_hp + 1000, false, "fixture", true)
		assert_false(first.is_alive)
		assert_true(room.active())
		var next_id: String = str(room.current_target().unit_id)
		assert_ne(next_id, str(first.unit_id))
		assert_true(runtime.checkpoint())
		await mount(ExpeditionSaveService.read_snapshot(path))
		runtime = battle._cards_runtime
		room = runtime.room_rules
		assert_eq(str(room.current_target().unit_id), next_id)
		assert_true(room.active())
		if depth == 8:
			assert_eq(room.danger_cells(), room.Topology.profile_danger_cells(
					"garden",
					battle.grid,
					room.current_target().grid_pos,
					2,
				))
		else:
			var hero: Unit = GameManager.expedition.character.unit
			assert_true(near(hero, room.layout.reservoirs[0]))
			room.end_hero()
			hero.current_ap = 4
			var target: Unit = room.current_target()
			var hp := target.current_hp
			assert_true(runtime.use_room_command("discharge_0"))
			assert_lt(target.current_hp, hp)


func test_version_one_checkpoint_keeps_the_players_hand_when_room_rules_are_added() -> void:
	await load_depth(5)
	var hero: Unit = GameManager.expedition.character.unit
	var spell: Spell = GameManager.expedition.cards.family_spell("fallback_guard")
	await battle._on_request_cast_spell(spell, hero.grid_pos)
	for _tick in 300:
		await wait_seconds(.02)
		if not battle._spell_resolution_pending:
			break
	var saved := ExpeditionSaveService.read_snapshot(path)
	saved.session.combat_checkpoint.version = 1
	saved.session.combat_checkpoint.erase("room")
	var hand: Array = GameManager.expedition.cards.hand.duplicate()
	var shield := hero.current_shield
	await mount(saved)
	assert_eq(GameManager.expedition.cards.hand, hand)
	assert_eq(GameManager.expedition.character.unit.current_ap, 3)
	assert_eq(GameManager.expedition.character.unit.current_shield, shield)
	assert_eq(battle._cards_runtime.room_rules.room_id, "forge")
	assert_true(battle._cards_runtime.checkpoint())
	assert_eq(ExpeditionSaveService.read_snapshot(path).session.combat_checkpoint.version, 2.0)
