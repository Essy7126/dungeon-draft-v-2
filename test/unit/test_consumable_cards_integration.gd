extends GutTest
const Catalog := preload("res://core/expedition/consumable_card_catalog.gd")
const Runtime := preload("res://battle/consumable_cards_runtime.gd")
const Workshop := preload("res://ui/expedition/consumable_cards_workshop.gd")
var manager
var paths: Array[String] = []
var live_battle: Node
var global_used := false


class Manager:
	extends "res://core/game_manager.gd"
	var destinations: Array[String] = []


	func _request_scene_change(
		path: String,
		_mode: PersistentRunUI.RunUIMode = PersistentRunUI.RunUIMode.NON_COMBAT,
	) -> void:
		destinations.append(path)


	func start_next_battle() -> void:
		destinations.append("battle")


	func _ensure_persistent_run_ui() -> PersistentRunUI:
		return null


func after_each() -> void:
	if is_instance_valid(live_battle):
		remove_child(live_battle)
		live_battle.free()
	if global_used:
		GameManager.cleanup_run_state()
		GameManager.expedition_save_path = ExpeditionSaveService.SAVE_PATH
		GameManager.selected_run_variant = "classic"
	global_used = false
	if is_instance_valid(manager):
		manager.cleanup_run_state()
		remove_child(manager)
		manager.free()
	for path in paths:
		ExpeditionSaveService.remove_snapshot(path)
	paths.clear()
	await wait_process_frames(2)


func make_manager():
	manager = Manager.new()
	add_child(manager)
	assert_true(manager.select_run_variant("cards"))
	manager.expedition_save_path = "user://cc2_integrated_%d.json" % Time.get_ticks_usec()
	paths.append(manager.expedition_save_path)
	return manager


func test_public_cards_uses_existing_threshold_session_and_save() -> void:
	make_manager()
	assert_false(manager.select_run_variant("cards_v2"))
	assert_true(manager.configure_next_run(ExpeditionRunFactory.create(33), 0))
	var selection := Catalog.preset("gardien")
	selection.deck_selected = true
	selection.difficulty_id = "easy"
	selection.masteries = Runtime.Integration.Progression.empty_elements()
	selection.masteries.earth = 4
	assert_true(manager.configure_cards_departure(selection))
	assert_true(manager.continue_after_intro())
	assert_eq(manager.destinations[-1], manager.CATABASE_THRESHOLD_SCREEN_PATH)
	assert_true(manager.finish_catabase_threshold().success)
	assert_true(manager.run_active)
	assert_not_null(manager.expedition)
	assert_true(manager.expedition.uses_consumable_cards())
	assert_eq(manager.expedition.cards.active.size(), 15)
	assert_eq(int(manager.expedition.cards.masteries.earth), 4)
	assert_eq(manager.expedition.route.current_node_id, "d01_0")
	assert_eq(manager.expedition.route.difficulty_id, "easy")
	assert_eq(manager.destinations[-1], "battle")
	assert_eq(manager.expedition.gold, 40)
	assert_eq(manager.expedition.character.unit.max_ap.get_int(), 4)
	assert_eq(manager.expedition.character.unit.max_mp.get_int(), 3)
	assert_false(manager.expedition.challenges.enabled)
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(manager.get_expedition_snapshot()))
	assert_true(manager.restore_expedition_snapshot(snapshot))
	assert_eq(manager.expedition.cards.primary_class, "gardien")
	assert_eq(int(manager.expedition.cards.masteries.earth), 4)
	assert_eq(manager.expedition.cards.active.size(), 15)
	assert_eq(manager.expedition_save_path, paths[0])


func test_replacement_guard_protects_current_cards_run() -> void:
	make_manager()
	assert_true(manager.start_expedition(33, { }, false, true, "normal", true))
	var before: Dictionary = manager.get_expedition_snapshot()
	assert_false(manager.start_expedition(34, { }, false, true, "normal", true))
	assert_eq(manager.get_expedition_snapshot(), before)
	var guard: Dictionary = manager.get_expedition_replacement_guard()
	assert_true(manager.confirm_expedition_replacement(str(guard.token)))
	assert_true(manager.start_expedition(34, { }, false, true, "normal", true))
	assert_eq(manager.expedition.route.seed, 34)


func test_twenty_depth_route_awards_new_progression_and_restores_every_stop() -> void:
	make_manager()
	assert_true(manager.start_expedition(33, { }, false, true, "normal", true))
	var combats := 0
	for depth in range(1, 21):
		var session: ExpeditionSession = manager.expedition
		if session.route.phase == "combat":
			combats += 1
			assert_true(session.combat_won())
			var receipt: Dictionary = session.cards.receipts.duplicate(true)
			session.award_destination()
			assert_eq(session.cards.receipts, receipt)
			assert_true(session.acknowledge_combat_receipt().success)
		if session.cards.level >= 4 and session.cards.specialization.is_empty():
			assert_true(session.cards.specialize("execution"))
		while not session.advancement_step.is_empty():
			assert_true(session.advance_level_step().success)
		var snapshot: Dictionary = JSON.parse_string(
			JSON.stringify(manager.get_expedition_snapshot())
		)
		assert_true(manager.restore_expedition_snapshot(snapshot), "depth %d" % depth)
		session = manager.expedition
		assert_eq(session.cards.level, session.character.champion_progression.current_level)
		assert_eq(session.cards.gold, session.gold)
		if depth == 19:
			assert_false(Runtime.Integration.is_market(session))
			assert_true(Runtime.Integration.services(session).is_empty())
		if depth == 20:
			break
		var options: Array = session.reward_options(manager.item_catalog)
		assert_true(session.claim(str(options[0].id), manager.run_inventory, manager.item_catalog).success)
		var next: Array = session.route.get_available_nodes()
		assert_false(next.is_empty())
		assert_true(manager.choose_expedition_node(str(next[0].id)))
	assert_eq(combats, 12)
	assert_eq(manager.expedition.cards.level, 12)


func test_all_twelve_authored_encounters_accept_a_live_combat_checkpoint() -> void:
	make_manager()
	assert_true(manager.start_expedition(33, {}, false, true, "normal", true))
	GameManager.cleanup_run_state()
	global_used = true
	GameManager.expedition_save_path = "user://cc2_rooms_%d.json" % Time.get_ticks_usec()
	paths.append(GameManager.expedition_save_path)
	var combats := 0
	for depth in range(1, 21):
		var session: ExpeditionSession = manager.expedition
		if session.route.phase == "combat":
			assert_true(GameManager.restore_expedition_snapshot(manager.get_expedition_snapshot()))
			live_battle = GameManager.get_current_room().battle_scene.instantiate()
			add_child(live_battle)
			await wait_process_frames(3)
			live_battle._deployment.on_cell_clicked(live_battle._deployment._deploy_zone[0])
			for _tick in 300:
				await wait_seconds(.02)
				if live_battle._can_accept_player_intent(): break
			assert_true(live_battle._can_accept_player_intent(), "depth %d starts" % depth)
			var enemies: Array = live_battle.units.filter(func(unit): return unit.team == 1)
			assert_eq(enemies.size(), GameManager.get_current_room().enemies.size())
			if depth == 20: assert_true(enemies[0].get_meta("cc2_boss", false))
			# A dead unit must remain serializable beside living enemies.
			if enemies.size() > 1:
				Runtime.Effects.hit(enemies[-1], GameManager.expedition.character.unit, enemies[-1].current_hp + 1000, false, "fixture", true)
				assert_false(enemies[-1].is_alive)
			assert_true(live_battle._cards_runtime.checkpoint(), "depth %d saves" % depth)
			var saved := ExpeditionSaveService.read_snapshot(GameManager.expedition_save_path)
			remove_child(live_battle)
			live_battle.free()
			live_battle = null
			GameManager.cleanup_run_state()
			assert_true(manager.restore_expedition_snapshot(saved), "depth %d restores" % depth)
			session = manager.expedition
			combats += 1
			# Transaction fixture: this does not simulate winning or difficulty.
			assert_true(session.combat_won())
			assert_true(session.acknowledge_combat_receipt().success)
		if session.cards.level >= 4 and session.cards.specialization.is_empty():
			assert_true(session.cards.specialize("execution"))
		while not session.advancement_step.is_empty():
			assert_true(session.advance_level_step().success)
		if depth == 20: break
		var options: Array = session.reward_options(manager.item_catalog)
		assert_true(session.claim(str(options[0].id), manager.run_inventory, manager.item_catalog).success)
		var next: Array = session.route.get_available_nodes()
		assert_true(manager.choose_expedition_node(str(next[0].id)))
	assert_eq(combats, 12)


func test_victory_is_committed_before_animation_and_defeat_removes_continuation() -> void:
	make_manager()
	assert_true(manager.start_expedition(33, {}, false, true, "normal", true))
	var cards = manager.expedition.cards
	cards.begin_combat()
	cards.start_turn()
	var copy: Dictionary = cards.copy_for(cards.hand[0])
	cards.selected = str(copy.id)
	assert_true(cards.consume(cards.family_spell(str(copy.family))))
	assert_true(manager._checkpoint_consumable_outcome(true))
	var saved := ExpeditionSaveService.read_snapshot(manager.expedition_save_path)
	assert_eq(saved.session.route.phase, "reward")
	assert_has(saved.session.cards_run.consumed, str(copy.id))
	assert_true(manager.restore_expedition_snapshot(saved))
	var before: Dictionary = manager.expedition.cards.receipts.duplicate(true)
	assert_true(manager._checkpoint_consumable_outcome(true))
	assert_eq(manager.expedition.cards.receipts, before, "Delayed completion cannot pay twice")
	assert_true(manager._checkpoint_consumable_outcome(false))
	assert_false(FileAccess.file_exists(manager.expedition_save_path))


func test_existing_workshop_displays_deck_with_empty_search() -> void:
	make_manager()
	assert_true(manager.start_expedition(33, {}, false, true, "normal", true))
	GameManager.cleanup_run_state()
	global_used = true
	GameManager.expedition_save_path = "user://cc2_workshop_%d.json" % Time.get_ticks_usec()
	paths.append(GameManager.expedition_save_path)
	assert_true(GameManager.restore_expedition_snapshot(manager.get_expedition_snapshot()))
	var workshop := Workshop.new()
	add_child(workshop)
	assert_not_null(workshop.get_node_or_null("Family_n02"), "An empty search shows owned families")
	workshop.query = "zzzz_no_family"
	workshop._render()
	assert_null(workshop.get_node_or_null("Family_n02"))
	workshop.free()
	assert_true(GameManager.expedition.combat_won())
	workshop = Workshop.new()
	workshop.mode = "progression"
	add_child(workshop)
	var allocation := workshop.find_child("Allocation_night", true, false) as SpinBox
	assert_not_null(allocation)
	allocation.value = 1
	var apply := workshop.find_child("ApplyPrototypeAllocation", true, false) as Button
	assert_false(apply.disabled)
	apply.pressed.emit()
	assert_eq(int(GameManager.expedition.cards.masteries.night), 1)
	assert_eq(int(ExpeditionSaveService.read_snapshot(GameManager.expedition_save_path).session.cards_run.masteries.night), 1)
	workshop.free()


func test_equipment_swaps_preserve_unrounded_health_across_save_and_other_edits() -> void:
	make_manager()
	assert_true(manager.start_expedition(33, {}, false, true, "normal", true))
	assert_true(manager.expedition.combat_won())
	var item := {}
	for candidate in Catalog.data().equipment:
		if float(candidate.mods.get("hp", 0)) > 0:
			item = candidate
			break
	assert_false(item.is_empty())
	Runtime.Integration.Economy.acquire_equipment(manager.expedition.cards, str(item.id), "integration_fixture")
	manager.expedition.cards.equipped[item.slot] = item.id
	Runtime.Integration.rebuild(manager.expedition)
	manager.expedition.character.unit.current_hp = 6
	for _swap in 5:
		manager.expedition.cards.equipped.erase(item.slot)
		Runtime.Integration.rebuild(manager.expedition, true)
		Runtime.Integration.rebuild(manager.expedition)
		assert_true(manager.restore_expedition_snapshot(JSON.parse_string(JSON.stringify(manager.get_expedition_snapshot()))))
		manager.expedition.cards.equipped[item.slot] = item.id
		Runtime.Integration.rebuild(manager.expedition, true)
		assert_eq(manager.expedition.character.unit.current_hp, 6)


func test_level_heal_includes_equipment_only_once() -> void:
	make_manager()
	assert_true(manager.start_expedition(33, {}, false, true, "normal", true))
	var session: ExpeditionSession = manager.expedition
	for item in Catalog.data().equipment:
		if float(item.mods.get("hp", 0)) > 0:
			Runtime.Integration.Economy.acquire_equipment(session.cards, str(item.id), "integration_fixture")
			session.cards.equipped[item.slot] = item.id
			break
	Runtime.Integration.rebuild(session)
	var previous_max := session.character.unit.max_hp.get_int()
	session.character.unit.current_hp = 20
	assert_true(session.combat_won())
	assert_eq(session.character.unit.current_hp, 20 + session.character.unit.max_hp.get_int() - previous_max)


func test_authored_battle_consumes_card_and_resumes_exact_hand_ap_and_shield() -> void:
	make_manager()
	assert_true(manager.start_expedition(33, { }, false, true, "normal", true))
	var opening := ""
	for copy in manager.expedition.cards.copies:
		if copy.family == "n02":
			opening = copy.id
			break
	assert_true(manager.expedition.cards.set_opening(opening))
	GameManager.cleanup_run_state()
	global_used = true
	GameManager.expedition_save_path = "user://cc2_real_battle_%d.json" % Time.get_ticks_usec()
	paths.append(GameManager.expedition_save_path)
	assert_true(GameManager.restore_expedition_snapshot(manager.get_expedition_snapshot()))
	live_battle = GameManager.get_current_room().battle_scene.instantiate()
	add_child(live_battle)
	await wait_process_frames(3)
	assert_not_null(live_battle._deployment)
	assert_true(live_battle._deployment.is_active())
	live_battle._deployment.on_cell_clicked(live_battle._deployment._deploy_zone[0])
	for _tick in 300:
		await wait_seconds(.02)
		if live_battle._can_accept_player_intent() and GameManager.expedition.cards.hand.size() == 5:
			break
	var session: ExpeditionSession = GameManager.expedition
	assert_eq(session.cards.hand.size(), 5)
	assert_has(session.cards.hand, opening)
	assert_not_null(live_battle.action_bar.find_child("CatabaseCardHand", true, false))
	assert_true(live_battle._can_accept_player_intent())
	var spell: Spell = session.cards.family_spell("n02")
	session.cards.selected = opening
	await live_battle._on_request_cast_spell(spell, session.character.unit.grid_pos)
	for _tick in 300:
		await wait_seconds(.02)
		if not live_battle._spell_resolution_pending:
			break
	assert_has(session.cards.consumed, opening)
	assert_eq(session.cards.copies.size(), 14)
	assert_gt(session.character.unit.current_shield, 0)
	var native_status := StatusData.new()
	native_status.status_id = &"integration_slow"
	native_status.duration = 3
	native_status.mp_reduction = 1
	native_status.damage_per_turn = 1
	native_status.stat_modifiers = { "resist_magique": 5 }
	session.character.unit.apply_status(
		native_status,
		live_battle.units[0],
		{ "terrain_id": "poison" },
	)
	session.character.unit.active_statuses[-1].remaining = 2
	var enemy: Unit = live_battle.units[0]
	enemy.set_meta("cc2_intent", {"cells": [[enemy.grid_pos.x, enemy.grid_pos.y]], "multiplier": 1.5})
	live_battle._cards_runtime._publish_intent(enemy)
	assert_eq(live_battle._tactical_telegraphs.get_telegraph_count(), 1)
	live_battle.terrain_effects.runtime_service._void_impulse_round_by_unit[session.character.unit.get_instance_id()] = 1
	assert_true(live_battle._cards_runtime.checkpoint())
	assert_false(live_battle._cards_runtime.save_failed)
	var saved := ExpeditionSaveService.read_snapshot(GameManager.expedition_save_path)
	assert_has(saved.session.cards_run.consumed, opening)
	var ap := session.character.unit.current_ap
	var shield := session.character.unit.current_shield
	var hand: Array = session.cards.hand.duplicate()
	var hero_cell := session.character.unit.grid_pos
	remove_child(live_battle)
	live_battle.free()
	live_battle = null
	assert_true(GameManager.restore_expedition_snapshot(saved))
	live_battle = GameManager.get_current_room().battle_scene.instantiate()
	add_child(live_battle)
	await wait_process_frames(4)
	assert_false(live_battle._deployment.is_active(), "A continuation must not offer redeployment")
	assert_eq(GameManager.expedition.cards.hand, hand)
	assert_eq(GameManager.expedition.character.unit.current_ap, ap)
	assert_eq(GameManager.expedition.character.unit.current_shield, shield)
	assert_eq(GameManager.expedition.character.unit.grid_pos, hero_cell)
	assert_eq(GameManager.expedition.character.unit.activation_index, 1)
	assert_has(GameManager.expedition.cards.consumed, opening)
	assert_true(GameManager.expedition.character.unit.has_status(&"integration_slow"))
	assert_eq(GameManager.expedition.character.unit.get_status_remaining(&"integration_slow"), 2)
	assert_eq(GameManager.expedition.character.unit.active_statuses[0].source, live_battle.units[0])
	assert_eq(live_battle._tactical_telegraphs.get_telegraph_count(), 1)
	assert_eq(live_battle.terrain_effects.runtime_service._void_impulse_round_by_unit[GameManager.expedition.character.unit.get_instance_id()], 1)
	var malformed := saved.duplicate(true)
	malformed.session.combat_checkpoint.units[0].ap = -1
	assert_false(GameManager.restore_expedition_snapshot(malformed))
	assert_eq(GameManager.expedition.cards.hand, hand)
	malformed = saved.duplicate(true)
	malformed.session.combat_checkpoint.units[0].statuses[0].values.mp_reduction = "bad"
	assert_false(GameManager.restore_expedition_snapshot(malformed))
	live_battle._commit_player_end_turn()
	for _tick in 600:
		await wait_seconds(.02)
		if GameManager.expedition.cards.round_index == 2 and live_battle._can_accept_player_intent():
			break
	assert_eq(GameManager.expedition.cards.round_index, 2)
	assert_eq(GameManager.expedition.cards.hand.size(), 5)
	assert_eq(GameManager.expedition.cards.copies.size(), 14)
	assert_eq(GameManager.expedition.character.unit.current_mp, 2)
	assert_false(live_battle._cards_runtime.save_failed)
	# Finish the actual room through a real damaging card. Only the enemy HP
	# and position are arranged here; targeting, cast, outcome and save are real.
	var hero: Unit = GameManager.expedition.character.unit
	enemy = live_battle.units[0]
	for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var cell: Vector2i = hero.grid_pos + direction
		if live_battle.grid.is_walkable(cell) and live_battle.grid.get_unit(cell) == null:
			live_battle.grid.relocate_unit(enemy, cell)
			break
	enemy.current_hp = 1
	var winner := ""
	for uid in GameManager.expedition.cards.hand:
		var family: String = GameManager.expedition.cards.copy_for(uid).family
		if Catalog.card(family).get("op") == "hit":
			winner = uid
			break
	assert_false(winner.is_empty())
	if not winner.is_empty():
		var cards = GameManager.expedition.cards
		cards.selected = winner
		await live_battle._on_request_cast_spell(cards.family_spell(cards.copy_for(winner).family), enemy.grid_pos)
		for _tick in 300:
			await wait_seconds(.02)
			if live_battle._battle_over: break
		# Keep GUT's scene alive while checking the pre-animation checkpoint.
		GameManager._battle_outcome_generation += 1
		GameManager._battle_outcome_pending = false
		assert_true(live_battle._battle_over)
		var victory := ExpeditionSaveService.read_snapshot(GameManager.expedition_save_path)
		assert_eq(victory.session.route.phase, "reward")
		assert_has(victory.session.cards_run.consumed, winner)
