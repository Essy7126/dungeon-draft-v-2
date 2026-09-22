extends GutTest
const Rooms = preload("res://core/expedition/card_tactical_room_catalog.gd")
const Rules = preload("res://core/expedition/card_tactical_room_rules.gd")
const ResourceRules = preload("res://core/expedition/card_tactical_resource_rules.gd")
var fields: Array = []


class Manager extends "res://core/game_manager.gd":
	func start_next_battle() -> void:
		pass


	func _request_scene_change(
		_path: String,
		_mode: PersistentRunUI.RunUIMode = PersistentRunUI.RunUIMode.NON_COMBAT,
	) -> void:
		pass


	func _ensure_persistent_run_ui() -> PersistentRunUI:
		return null


func test_card_preview_survives_save_without_changing_canonical_route() -> void:
	var catalog = preload("res://core/expedition/class_card_catalog.gd")
	var manager := Manager.new()
	add_child(manager)
	manager.expedition_save_path = "user://tactical_room_test_%d.json" % [Time.get_ticks_usec()]
	manager._cards_departure_selection = catalog.preset("gardien")
	assert_true(manager.start_expedition(42, { }, false, true, "normal", true))
	assert_true(manager.confirm_catabase_preparation(catalog.preset("gardien")).get(
			"success",
			false,
		))
	assert_true(manager.expedition.route.card_tactical_rooms_enabled)
	var snapshot: Dictionary = manager.get_expedition_snapshot()
	assert_true(manager.restore_expedition_snapshot(snapshot))
	assert_true(manager.expedition.route.card_tactical_rooms_enabled)
	var found := false
	for preview in manager.expedition.route.get_visible_nodes():
		if Rooms.id_for(preview) == "forge":
			found = true
			assert_eq(preview.title, Rooms.ROOMS.forge.name)
	assert_true(found)
	assert_eq(manager.expedition.route.nodes, ExpeditionRouteCatalog.create_nodes(42))
	manager.cleanup_run_state()
	ExpeditionSaveService.remove_snapshot(manager.expedition_save_path)
	manager.queue_free()
	await get_tree().process_frame


func field(id: String):
	var runtime := ArenaRuntimeProjectionService.build(Rooms.build(id))
	var hero := Unit.new("Achille", 0, 240, 20, 4, 3, 40)
	var boss := Unit.new("Chef", 1, 220, 10, 4, 2, 24)
	var porter := Unit.new("Porteur", 1, 70, 8, 2, 2, 12)
	runtime.grid.place_unit(hero, Vector2i(1, 3))
	runtime.grid.place_unit(boss, Vector2i(7, 3))
	runtime.grid.place_unit(porter, Vector2i(6, 1))
	hero.start_turn()
	var rules = ResourceRules.new() if id in ["hourglass", "reservoir"] else Rules.new()
	rules.bind(
		id,
		runtime.grid,
		runtime.terrain_effects,
		[hero, boss, porter],
		func():
			return true,
	)
	fields.append({ "runtime": runtime, "rules": rules, "actors": [hero, boss, porter] })
	return rules


func after_each() -> void:
	for entry in fields:
		entry.rules.dispose()
		entry.runtime.terrain_effects.dispose()
		for actor in entry.actors:
			actor.clear_combat_effect_history()
			entry.runtime.grid.remove_unit(actor)
	fields.clear()


func test_factory_only_changes_five_card_destinations_and_preserves_roster() -> void:
	var count := 0
	for node in ExpeditionRouteCatalog.create_nodes(42):
		var id: String = Rooms.id_for(node)
		if id.is_empty():
			continue
		count += 1
		var classic := ExpeditionRunFactory.make_room(node, 42, false)
		var cards := ExpeditionRunFactory.make_room(node, 42, true)
		assert_false(classic.has_meta("card_tactical_room_id"))
		assert_eq(cards.get_meta("card_tactical_room_id"), id)
		assert_eq(cards.enemies.size(), classic.enemies.size())
		assert_eq(
			cards.encounter_definition.encounter_id,
			classic.encounter_definition.encounter_id,
		)
		assert_true(cards.enemy_spawn_zone.size() >= cards.enemies.size())
		var grid := EncounterGridFactory.build_from_room(cards)
		var paths := Pathfinder.new(grid)
		for cell in cards.enemy_spawn_zone:
			assert_true(grid.is_walkable(cell))
			assert_gt(paths.find_path(cards.hero_spawn_zone[0], cell).size(), 1)
	assert_eq(count, 5)


func test_forge_preview_cost_and_environment_hit_both_sides() -> void:
	var rules = field("forge")
	assert_has(rules.danger_cells(), rules.hero.grid_pos)
	assert_has(rules.danger_cells(), rules.boss.grid_pos)
	var preview: Array = rules.preview_terminal("left")
	assert_eq(rules.hero.current_ap, 4)
	assert_true(rules.use_terminal("left"))
	assert_eq(rules.hero.current_ap, 3)
	assert_eq(rules.danger_cells(), preview)
	assert_false(rules.use_terminal("right"))
	rules.finish_hero_turn()
	assert_eq(rules.carriers[0].current_hp, 10)
	assert_eq(rules.hero.current_hp, 240)
	assert_eq(rules.rail, 3)
	rules.finish_hero_turn()
	assert_eq(rules.hero.current_hp, 208)
	assert_eq(rules.boss.current_hp, 160)


func test_pillars_block_sight_and_movement_while_pits_only_block_movement() -> void:
	for id in Rooms.IDS:
		var rules = field(id)
		var pillar := Vector2i(3, 2) if id == "convoy" else Vector2i(2, 2)
		assert_eq(rules.grid.get_type(pillar), GridData.CellType.WALL)
		assert_false(rules.grid.is_walkable(pillar))
		assert_false(rules.pathfinder.has_line_of_sight(
				pillar + Vector2i.LEFT,
				pillar + Vector2i.RIGHT,
			))
		if id != "convoy":
			var pit := Vector2i(0, 0) if id == "forge" else Vector2i(4, 0)
			assert_eq(rules.grid.get_type(pit), GridData.CellType.HOLE)


func test_garden_follows_moved_boss_and_blocked_pedestal_costs_nothing() -> void:
	var rules = field("garden")
	var initial: Array = rules.danger_cells()
	rules.grid.relocate_unit(rules.boss, Vector2i(5, 3))
	assert_ne(rules.danger_cells(), initial)
	rules.grid.relocate_unit(rules.carriers[0], Vector2i(5, 1))
	assert_false(rules.use_terminal("left"))
	assert_eq(rules.hero.current_ap, 4)
	var expected: Array = rules.preview_terminal("right")
	assert_true(rules.use_terminal("right"))
	assert_eq(rules.danger_cells(), expected)
	rules.finish_hero_turn()
	assert_eq(rules.radius, 3)


func test_convoy_delivery_and_seal_are_alternative_outcomes() -> void:
	var rules = field("convoy")
	var porter: Unit = rules.carriers[0]
	rules.grid.relocate_unit(porter, Vector2i(7, 2))
	rules.boss.take_damage(50)
	var attack: int = rules.boss.attack_power.get_int()
	assert_true(rules.begin_enemy_turn(porter))
	assert_eq(rules.deliveries, 1)
	assert_eq(rules.boss.current_hp, 205)
	assert_eq(rules.boss.attack_power.get_int(), attack + 8)
	assert_false(porter.is_alive)
	assert_true(rules.coins.is_empty())
	var sealed = field("convoy")
	assert_true(sealed.use_terminal("gate"))
	assert_eq(sealed.hero.current_ap, 2)
	assert_false(sealed.use_terminal("gate"))
	assert_false(sealed.begin_enemy_turn(sealed.carriers[0]))
	assert_eq(sealed.deliveries, 0)


func test_convoy_separation_removes_guard_and_soul_pickup_is_once() -> void:
	var rules = field("convoy")
	var porter: Unit = rules.carriers[0]
	rules.grid.relocate_unit(porter, Vector2i(6, 3))
	rules.begin_enemy_turn(rules.boss)
	assert_eq(rules.boss.current_shield, 12)
	rules.boss.clear_shield()
	rules.grid.relocate_unit(porter, Vector2i(2, 3))
	rules.begin_enemy_turn(rules.boss)
	assert_eq(rules.boss.current_shield, 0)
	porter.take_damage(100)
	rules.grid.relocate_unit(rules.hero, Vector2i(2, 3))
	assert_eq(rules.hero.current_shield, 12)
	rules.grid.relocate_unit(rules.hero, Vector2i(1, 3))
	rules.grid.relocate_unit(rules.hero, Vector2i(2, 3))
	assert_eq(rules.hero.current_shield, 12)


func test_hourglass_fixed_cross_delay_is_bounded_and_hits_both_sides() -> void:
	var rules = field("hourglass")
	var initial: Array = rules.danger_cells()
	rules.grid.relocate_unit(rules.hero, Vector2i(2, 3))
	assert_eq(rules.danger_cells(), initial, "Moving does not drag the telegraph")
	assert_true(rules.use_terminal("left"))
	assert_eq(rules.hero.current_ap, 3)
	assert_true(rules.danger_cells().is_empty())
	rules.finish_hero_turn()
	assert_eq(rules.hero.current_hp, 240, "Delay skips exactly this blast")
	assert_eq(rules.mark, Vector2i(1, 3))
	assert_false(rules.use_terminal("left"), "Cannot delay the same blast forever")
	assert_eq(rules.hero.current_ap, 3)
	rules.grid.relocate_unit(rules.carriers[0], Vector2i(1, 4))
	rules.finish_hero_turn()
	assert_eq(rules.hero.current_hp, 192)
	assert_eq(rules.carriers[0].current_hp, 22)
	assert_eq(rules.mark, Vector2i(2, 3))
	assert_eq(rules.blast_damage, 32)
	assert_false(rules.postponed)


func test_hourglass_retarget_cost_preview_walls_and_escape() -> void:
	var rules = field("hourglass")
	assert_false(rules.use_terminal("gate"))
	var preview: Array = rules.preview_terminal("right")
	assert_eq(rules.hero.current_ap, 4, "Preview is pure")
	assert_true(rules.use_terminal("right"))
	assert_eq(rules.hero.current_ap, 2)
	assert_eq(rules.danger_cells(), preview)
	assert_false(rules.use_terminal("left"))
	rules.finish_hero_turn()
	assert_eq(rules.boss.current_hp, 188)
	assert_eq(rules.hero.current_hp, 240)
	rules.mark = Vector2i(2, 3)
	assert_does_not_have(rules.danger_cells(), Vector2i(2, 1), "Pillar stops the cross")
	rules.grid.relocate_unit(rules.hero, Vector2i(0, 6))
	assert_false(rules.use_terminal("left"), "Cannot operate remotely")
	rules.finish_hero_turn()
	assert_eq(rules.hero.current_hp, 240)


func test_reservoir_stores_only_remaining_ap_caps_and_siphons() -> void:
	var rules = field("reservoir")
	rules.finish_hero_turn()
	assert_eq(rules.charges, [0, 0], "No storage far from a reservoir")
	assert_eq(rules.hero.current_ap, 4)
	rules.grid.relocate_unit(rules.hero, Vector2i(3, 1))
	rules.hero.spend_ap(1)
	rules.finish_hero_turn()
	assert_eq(rules.charges, [3, 0])
	assert_eq(rules.hero.current_ap, 0)
	rules.hero.start_turn()
	rules.finish_hero_turn()
	assert_eq(rules.charges, [6, 0])
	assert_eq(rules.hero.current_ap, 1, "Only deposited AP are spent")
	var porter: Unit = rules.carriers[0]
	porter.take_damage(30)
	rules.grid.relocate_unit(porter, Vector2i(4, 1))
	assert_false(rules.begin_enemy_turn(porter), "Siphon does not replace ordinary AI")
	assert_eq(rules.charges, [5, 0])
	assert_eq(porter.current_hp, 52)
	rules.grid.relocate_unit(porter, Vector2i(7, 1))
	rules.begin_enemy_turn(porter)
	assert_eq(rules.charges, [5, 0], "Displacement prevents siphoning")


func test_reservoir_discharge_spends_once_and_uses_normal_defense() -> void:
	var rules = field("reservoir")
	assert_false(rules.use_terminal("left"))
	rules.grid.relocate_unit(rules.hero, Vector2i(4, 1))
	rules.finish_hero_turn()
	rules.hero.start_turn()
	assert_eq(rules.preview_terminal("left"), [rules.boss.grid_pos])
	assert_eq(rules.charges, [4, 0])
	rules.boss.add_shield(10)
	assert_true(rules.use_terminal("left"))
	assert_eq(rules.hero.current_ap, 3)
	assert_eq(rules.charges, [0, 0])
	assert_eq(rules.boss.current_hp, 142, "88 raw damage minus 10 shield")
	assert_false(rules.use_terminal("left"))
	assert_eq(rules.hero.current_ap, 3)
	rules.finish_hero_turn()
	assert_eq(rules.charges, [3, 0], "Can bank the remaining AP after discharge")
	rules.outcome = "closed"
	assert_false(rules.use_terminal("left"))
	rules.finish_hero_turn()
	assert_eq(rules.charges, [3, 0])
