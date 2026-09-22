extends GutTest
const Lab = preload("res://tools/charon_workshop/charon_lab.tscn")
const Combat = preload("res://tools/charon_workshop/charon_combat.gd")
var fields: Array = []


func field(class_id := "gardien"):
	var model := Combat.new()
	model.initialize(class_id, 42)
	fields.append(model)
	return model


func after_each() -> void:
	for model in fields:
		model.dispose()
	fields.clear()


func test_playable_scene_routes_buttons_cards_and_restart() -> void:
	var scene = Lab.instantiate()
	add_child_autofree(scene)
	await get_tree().process_frame
	assert_eq(scene.hand.get_child_count(), 4)
	var guard_id: String = scene.combat.cards.active[2]
	_ensure_card_in_hand(scene.combat, guard_id)
	scene._refresh()
	scene.hand.get_child(scene.combat.cards.hand.find(guard_id)).pressed.emit()
	assert_false(scene.selected.is_empty())
	scene.board.cell_clicked.emit(scene.combat.hero.grid_pos)
	assert_gt(scene.combat.hero.current_shield, 0)
	assert_eq(scene.hand.get_child_count(), 3)
	scene.end_button.pressed.emit()
	assert_false(scene.combat.pending.is_empty())
	scene.combat.grid.relocate_unit(scene.combat.boss, Vector2i(8, 3))
	scene._refresh()
	assert_true(scene.intention.text.contains("INTERROMPUE"))
	scene.class_choice.select(2)
	scene._restart()
	assert_eq(scene.combat.cards.primary_class, "arpenteur")
	assert_eq(scene.combat.round_number, 1)
	assert_eq(scene.combat.oboles, 0)
	assert_eq(scene.hand.get_child_count(), 4)
	await get_tree().process_frame


func _ensure_card_in_hand(model, id: String) -> void:
	if id in model.cards.hand:
		return
	model.cards.draw_pile.erase(id)
	model.cards.draw_pile.append(model.cards.hand.pop_front())
	model.cards.hand.append(id)


func test_shared_cards_and_three_bridges_for_all_classes() -> void:
	for id in Combat.Catalog.CLASSES:
		var model = field(id)
		assert_eq(model.cards.active.size(), 10)
		assert_eq(model.cards.hand.size(), 4)
		assert_eq(model.hero.current_ap, 4)
		for y in 7:
			assert_eq(model.grid.is_terrain_interactable(Vector2i(4, y)), y in [1, 3, 5])


func test_failed_card_and_move_leave_resources_unchanged() -> void:
	var model = field()
	var before: Array = model.cards.hand.duplicate()
	assert_false(model.play_card(before[0], Vector2i(8, 6)))
	assert_eq(model.cards.hand, before)
	assert_eq(model.hero.current_ap, 4)
	assert_false(model.move_hero(Vector2i(4, 0)))
	assert_eq(model.hero.current_mp, 3)


func test_crossing_warns_for_one_full_player_turn_and_hits_allies() -> void:
	var model = field()
	model.grid.relocate_unit(model.carriers[0], Vector2i(5, 3))
	model.end_turn()
	assert_false(model.pending.is_empty())
	assert_eq(model.carriers[0].current_hp, 50)
	assert_true(model.player_turn)
	model.end_turn()
	assert_eq(model.carriers[0].current_hp, 6)
	assert_true(model.pending.is_empty())
	assert_eq(model.metrics.friendly_hits, 1)


func test_obole_drops_on_death_and_pickup_is_idempotent() -> void:
	var model = field()
	model.grid.relocate_unit(model.carriers[0], Vector2i(2, 3))
	model.carriers[0].take_damage(100, model.hero)
	assert_eq(model.oboles, 0)
	assert_true(model.move_hero(Vector2i(2, 3)))
	assert_eq(model.oboles, 1)
	model.grid.relocate_unit(model.hero, Vector2i(1, 3))
	model.grid.relocate_unit(model.hero, Vector2i(2, 3))
	assert_eq(model.oboles, 1)


func test_gate_is_paid_once_and_consumes_boss_activation() -> void:
	var model = field()
	model.end_turn()
	model.oboles = 1
	var hp: int = model.boss.current_hp
	assert_true(model.use_terminal("gate"))
	assert_eq(model.oboles, 0)
	assert_eq(model.hero.current_ap, 3)
	assert_false(model.use_terminal("gate"))
	model.end_turn()
	assert_eq(model.boss.current_hp, hp - 35)
	assert_eq(model.boss.current_ap, 0)
	assert_eq(model.metrics.crossings, 0)


func test_terminal_preview_has_no_side_effects_and_rotation_matches_resolution() -> void:
	var model = field()
	model.end_turn()
	model.oboles = 1
	var preview: Array = model.preview_terminal("left")
	assert_false(preview.is_empty())
	assert_eq(model.oboles, 1)
	assert_eq(model.hero.current_ap, 4)
	assert_true(model.use_terminal("left"))
	assert_eq(model.pending.cells, preview)
	assert_false(model.use_terminal("right"))
	model.end_turn()
	assert_eq(model.boss.grid_pos, preview.back())


func test_terminal_without_coin_or_out_of_range_does_not_charge() -> void:
	var model = field()
	model.end_turn()
	assert_false(model.use_terminal("gate"))
	model.oboles = 1
	model.grid.relocate_unit(model.hero, Vector2i(0, 0))
	assert_false(model.use_terminal("gate"))
	assert_eq(model.oboles, 1)
	assert_eq(model.hero.current_ap, 4)


func test_displacing_charon_cancels_crossing_without_free_attack() -> void:
	var model = field()
	model.end_turn()
	model.grid.relocate_unit(model.boss, Vector2i(7, 2))
	model.end_turn()
	assert_eq(model.metrics.crossings, 0)
	assert_eq(model.boss.current_ap, 0)
	assert_eq(model.boss.grid_pos, Vector2i(7, 2))


func test_victory_clears_warning_and_locks_actions() -> void:
	var model = field()
	model.end_turn()
	model.boss.take_damage(1000, model.hero)
	model._finish_action()
	assert_eq(model.outcome, "Victoire")
	assert_true(model.pending.is_empty())
	assert_false(model.move_hero(Vector2i(2, 3)))
	var round_before: int = model.round_number
	model.end_turn()
	assert_eq(model.round_number, round_before)


func test_dispose_disconnects_global_card_listener() -> void:
	var count := EventBus.turn_ended.get_connections().size()
	var model := Combat.new()
	model.initialize()
	model.dispose()
	assert_eq(EventBus.turn_ended.get_connections().size(), count)


func test_real_card_resolution_consumes_card_and_activates_each_class() -> void:
	for id in Combat.Catalog.CLASSES:
		var model = field(id)
		var target := Vector2i(2, 3) if id in ["assassin", "gardien"] else Vector2i(4, 3)
		model.grid.relocate_unit(model.boss, target)
		var card_id: String = model.cards.active[0]
		_ensure_card_in_hand(model, card_id)
		assert_true(model.play_card(card_id, target), id)
		assert_eq(model.hero.current_ap, 2)
		assert_false(card_id in model.cards.hand)
		assert_true(card_id in model.cards.discard)
		assert_lt(model.boss.current_hp, 220)
		assert_eq(model.metrics.cards, 1)


func test_card_retention_and_recomposition_use_shared_piles() -> void:
	var model = field()
	var retained: String = model.cards.hand[0]
	model.retain(retained)
	model.end_turn()
	assert_has(model.cards.hand, retained)
	assert_eq(model.cards.hand.size(), 4)
	assert_true(model.recompose(retained))
	assert_eq(model.hero.current_ap, 3)
	assert_false(model.recompose(model.cards.hand[0]))
	assert_eq(model.hero.current_ap, 3)


func test_emergency_gestures_work_without_consuming_a_card() -> void:
	var model = field()
	var hand: Array = model.cards.hand.duplicate()
	assert_true(model.play_gesture(1, model.hero.grid_pos))
	assert_gt(model.hero.current_shield, 0)
	assert_eq(model.hero.current_ap, 3)
	assert_eq(model.cards.hand, hand)
	assert_false(model.play_gesture(1, model.hero.grid_pos))
	model.grid.relocate_unit(model.boss, Vector2i(2, 3))
	assert_true(model.play_gesture(0, model.boss.grid_pos))
	assert_eq(model.hero.current_ap, 1)
	assert_eq(model.cards.hand, hand)


func test_four_class_playthroughs_reach_a_terminal_result() -> void:
	for id in Combat.Catalog.CLASSES:
		var model = field(id)
		for _round in 35:
			if not model.outcome.is_empty():
				break
			_bot_turn(model)
			model.end_turn()
		assert_false(model.outcome.is_empty(), "Le combat doit se terminer : " + id)
		assert_gt(model.metrics.cards, 0, id)
		print(
			"CHARON_PLAYTHROUGH ",
			id,
			" ",
			model.outcome,
			" tours=",
			model.round_number,
			" PV=",
			model.hero.current_hp,
			" metrics=",
			model.metrics,
		)


func _bot_turn(model) -> void:
	if model.terminal_failure("gate").is_empty():
		model.use_terminal("gate")
	for _action in 12:
		if not model.outcome.is_empty():
			return
		var best := -1.0
		var choice := ""
		var target := Vector2i.ZERO
		for id: String in model.cards.hand:
			var spell: Spell = model.cards.spells_for(id)[0]
			for cell in model.caster.get_targetable_cells(model.hero, spell):
				if not model.caster.can_cast(model.hero, spell, cell):
					continue
				var victim: Unit = model.grid.get_unit(cell)
				var score := 0.0
				if victim != null and victim.team != model.hero.team:
					score = float(spell.get_scaled_damage(model.hero))
					if victim != model.boss:
						score *= 1.3
					if victim.current_hp <= score:
						score += 50.0
				elif victim == model.hero:
					score = float(spell.get_scaled_shield(model.hero))
				if score > best and score > 0:
					best = score
					choice = id
					target = cell
		if not choice.is_empty():
			model.play_card(choice, target)
			continue
		var destination: Vector2i = model.hero.grid_pos
		var best_distance := 100000.0
		for cell in model.pathfinder.get_reachable(
			model.hero.grid_pos,
			model.hero.current_mp,
			model.hero,
		):
			var distance := 1000.0
			for enemy: Unit in model.grid.get_units():
				if enemy.team != model.hero.team and enemy.is_alive:
					distance = minf(distance, float(model.grid.manhattan(cell, enemy.grid_pos)))
			if cell in model.pending.get("cells", []):
				distance += 100.0
			if model.coins.has(cell):
				distance -= 5.0
			if cell == model.hero.grid_pos:
				distance -= .1
			if distance < best_distance:
				best_distance = distance
				destination = cell
		if destination != model.hero.grid_pos and model.move_hero(destination):
			continue
		break
	if model.terminal_failure("gate").is_empty():
		model.use_terminal("gate")
