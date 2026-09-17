extends GutTest
## Audit fixtures measure laws/transactions, not victories or human win rates.
const Contract = preload("res://tools/catabase_run_balance_validation/run_validation_contract.gd")
const Factory = preload("res://test/support/factory.gd")
const Cleanup = preload("res://test/support/isolated_battlefield_cleanup.gd")
var managers: Array = []
var fields: Array = []
var observations: Dictionary = {}

class Manager:
	extends "res://core/game_manager.gd"
	func start_next_battle() -> void: pass
	func _request_scene_change(_path: String, _mode: PersistentRunUI.RunUIMode = PersistentRunUI.RunUIMode.NON_COMBAT) -> void: pass
	func _ensure_persistent_run_ui() -> PersistentRunUI: return null


func make_manager(weapon: String):
	var manager := Manager.new()
	manager.expedition_save_path = "user://studio_audit_%d.json" % Time.get_ticks_usec()
	add_child(manager)
	managers.append(manager)
	assert_true(manager.start_expedition(7201, {}, false, true, "normal", true))
	assert_true(manager.confirm_catabase_preparation(CatabasePreparationCatalog.preset(weapon)).success)
	return manager


func after_each() -> void:
	for field in fields:
		field.terrain.dispose()
		Cleanup.dispose_grid(field.grid)
	fields.clear()
	for manager in managers:
		manager.cleanup_run_state()
		ExpeditionSaveService.remove_snapshot(manager.expedition_save_path)
		manager.queue_free()
	managers.clear()
	await get_tree().process_frame


func after_all() -> void:
	var path := "res://artifacts/catabase_run_balance_validation/studio_mechanics_iteration"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))
	var file := FileAccess.open(path.path_join("observations.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(observations, "\t"))
	file.close()


func test_conditional_rarity_distributions_180000_draws() -> void:
	var rows := []
	for weapon in Contract.weapon_ids():
		var manager = make_manager(weapon)
		var cards: CatabaseCards = manager.expedition.cards
		var pool := cards.eligible_pool()
		for depth in [1, 8, 17]:
			var rng := RandomNumberGenerator.new()
			rng.seed = 81723 + depth
			var counts := [0, 0, 0, 0, 0]
			var families := {}
			for i in 10000:
				var family := cards._roll(pool, CatabaseCards.weights(depth), rng)
				counts[cards.rarity(family)] += 1
				families[family] = int(families.get(family, 0)) + 1
			assert_eq(counts.reduce(func(a, b): return a + b, 0), 10000)
			rows.append({"weapon": weapon, "weight_depth": depth, "pool": pool, "rarities": counts, "families": families, "scope": "fixed starting eligibility, not evolved full-run pool"})
	observations["conditional_drops"] = rows


func test_transaction_fuzz_keeps_deck_and_currency_consistent() -> void:
	var accepted := {"move": 0, "sell": 0, "undo": 0}
	for weapon in Contract.weapon_ids():
		var manager = make_manager(weapon)
		assert_true(manager.expedition.combat_won())
		var cards: CatabaseCards = manager.expedition.cards
		for family in cards.eligible_pool():
			cards._teach(family)
			for i in 3: cards.add_copy(family)
		var rng := RandomNumberGenerator.new()
		rng.seed = 7751
		for step in 1000:
			var before_gold: int = manager.expedition.gold
			var action := rng.randi_range(0, 2)
			if action == 2 and not cards.sale_undo.is_empty():
				var keys := cards.sale_undo.keys()
				var id := str(keys[rng.randi_range(0, keys.size() - 1)])
				var price: int = CatabaseCards.SELL[cards.rarity(str(cards.sale_undo[id].family))]
				if cards.undo_sale(id):
					accepted.undo += 1
					assert_eq(manager.expedition.gold, before_gold - price)
			else:
				var card := cards.copies[rng.randi_range(0, cards.copies.size() - 1)]
				if action == 1:
					var price: int = CatabaseCards.SELL[cards.rarity(str(card.family))]
					if cards.sell(str(card.id)):
						accepted.sell += 1
						assert_eq(manager.expedition.gold, before_gold + price)
				else:
					var replace := cards.active[rng.randi_range(0, cards.active.size() - 1)] if rng.randf() < 0.7 else ""
					if cards.move_card(str(card.id), replace): accepted.move += 1
			assert_true(cards.valid_deck(cards.active), "atomic invariant %s/%d" % [weapon, step])
			assert_gte(manager.expedition.gold, 0)
			if step % 100 == 0:
				assert_true(manager.restore_expedition_snapshot(JSON.parse_string(JSON.stringify(manager.get_expedition_snapshot()))), "fuzz checkpoint")
				cards = manager.expedition.cards
	observations["transactions"] = {"attempts": 6000, "accepted": accepted, "roundtrips": 60}


func test_starting_hands_and_cycle_30000_turns() -> void:
	var rows := []
	for weapon in Contract.weapon_ids():
		var manager = make_manager(weapon)
		var cards: CatabaseCards = manager.expedition.cards
		var zero_weapon := 0
		var unique_sum := 0
		var opening_families := []
		for seed_id in 1000:
			manager.expedition.route.seed = seed_id + 50000
			cards.prepare_entry()
			for turn in 5:
				cards.start_turn()
				var families := {}
				for id in cards.hand: families[cards.copy_for(id).family] = true
				if turn == 0:
					if opening_families.is_empty(): opening_families = families.keys()
					assert_eq(families.keys(), opening_families, "prepared opening seed invariant")
				else:
					if not families.has(CatabaseCards.GESTURE): zero_weapon += 1
					unique_sum += families.size()
				assert_eq(cards.hand.size() + cards.draw_pile.size() + cards.discard.size() + cards.exhausted.size(), cards.active.size())
				cards.end_turn()
		rows.append({"weapon": weapon, "opening_unique_families": opening_families.size(), "post_opening_hands": 4000, "no_weapon_hands": zero_weapon, "mean_unique_families": float(unique_sum) / 4000.0, "scope": "4-card hand, no casts/retain/recompose; pure draw law"})
	observations["draw_law"] = rows


func test_resale_learning_and_offturn_boundary_observations() -> void:
	var manager = make_manager("marteau")
	var session = manager.expedition
	var cards: CatabaseCards = session.cards
	cards.start_turn()
	var hero: Unit = session.character.unit
	hero.start_turn()
	ArenaTerrainStatusTimingService.resolve_activation_end(hero)
	EventBus.turn_ended.emit(hero, &"audit_fixture")
	var spent_offturn := cards.recompose(cards.hand[0])
	assert_false(spent_offturn, "the model must reject recomposition outside the hero activation")
	observations["model_offturn_recompose"] = {"accepted_after_hero_end_turn": spent_offturn, "scope": "model API only; production UI independently blocks enemy-turn input"}
	assert_true(session.combat_won())
	var family := ""
	for candidate in cards.eligible_pool():
		if candidate != CatabaseCards.GESTURE and not cards.known_family(candidate): family = candidate; break
	assert_false(family.is_empty())
	cards._teach(family)
	var id := cards.add_copy(family)
	assert_true(cards.sell(id))
	cards.sync_learned()
	observations["sold_learning"] = {"family": family, "still_known": cards.known_family(family), "owned_copies": cards.copies.filter(func(card): return card.family == family).size()}
	assert_true(cards.known_family(family), "observed knowledge is permanent, not a free playable copy")
	assert_eq(cards.copies.filter(func(card): return card.family == family).size(), 0)


func test_real_drop_bands_across_fixture_route() -> void:
	var rows := []
	for weapon in Contract.weapon_ids():
		var manager = make_manager(weapon)
		var session = manager.expedition
		for depth in range(1, 21):
			if session.route.phase == "combat":
				assert_true(session.combat_won())
				var cards: CatabaseCards = session.cards
				rows.append({"weapon": weapon, "depth": depth, "pool_size": cards.entry_pool.size(), "pool": cards.entry_pool.duplicate(), "drops": cards.last_drops.map(func(id): return cards.copy_for(id).family), "ranks": cards.last_drops.map(func(id): return cards.rarity(str(cards.copy_for(id).family)))})
				if depth in [6, 10, 15]: assert_true(cards.last_drops.any(func(id): return cards.rarity(str(cards.copy_for(id).family)) >= 2))
			while not session.advancement_step.is_empty():
				while session.character.champion_progression.unspent_attribute_points > 0: session.character.champion_progression.spend_attribute(&"vitality")
				assert_true(session.advance_level_step().success)
			if depth == 12: assert_true(session.build.choose_depth_eight("slot").success)
			var choice := "finish" if depth == 20 else "leave_hub" if ExpeditionRouteCatalog.is_halt(str(session.route.get_current_node().kind)) else "supplies"
			assert_true(session.claim(choice, manager.run_inventory, manager.item_catalog).success)
			if depth < 20:
				var node := Contract.choose_route_node(session.route.get_available_nodes(), 7201, depth + 1)
				assert_true(session.enter(str(node.id)))
	observations["fixture_route_drops"] = rows


func test_seeded_loot_economy_1000_routes_fixed_pool() -> void:
	var manager = make_manager("marteau")
	var cards: CatabaseCards = manager.expedition.cards
	var initial := cards.copies.duplicate(true)
	var rows := []
	for seed_id in range(9000, 10000):
		var route := ExpeditionRouteState.new()
		route.initialize(seed_id, ExpeditionRouteCatalog.REVISION, "normal")
		manager.expedition.route.seed = seed_id
		cards.receipts.clear()
		var family_counts := {}
		var ranks := [0, 0, 0, 0, 0]
		var sell_value := 0
		var drops := 0
		for depth in range(1, 21):
			var node := Contract.choose_route_node(route.get_available_nodes(), seed_id, depth)
			assert_true(route.choose_node(str(node.id)))
			if ExpeditionRouteCatalog.is_combat(str(node.kind)):
				cards.copies = initial.duplicate(true)
				cards.serial = 12
				cards.grant_loot(node)
				if depth != 20:
					for id in cards.last_drops:
						var family := str(cards.copy_for(id).family)
						var rank := cards.rarity(family)
						ranks[rank] += 1
						family_counts[family] = int(family_counts.get(family, 0)) + 1
						sell_value += int(CatabaseCards.SELL[rank])
						drops += 1
				route.mark_combat_won()
			route.complete_current_node()
		assert_between(drops, 14, 25)
		rows.append({"seed": seed_id, "drops": drops, "ranks": ranks, "families": family_counts, "sell_value": sell_value, "unique_families": family_counts.size()})
	observations["seeded_loot_routes"] = {"scope": "1000 actual route/loot RNG sequences; fixed initial eligibility, no character progression, all drops valued for hypothetical sale, no actual combat", "rows": rows}


func test_repercussion_marker_is_not_its_real_damage() -> void:
	var rows := []
	for bronze in [10, 30, 80]:
		var manager = make_manager("xiphos")
		var cards: CatabaseCards = manager.expedition.cards
		var hero: Unit = manager.expedition.character.unit
		hero.start_turn()
		cards.start_turn()
		hero.set_meta("ct_bronze", bronze)
		var field = Factory.make_battlefield(8, 6)
		fields.append(field)
		field.grid.place_unit(hero, Vector2i(2, 2))
		var target := Factory.make_unit("Audit target", 1)
		field.grid.place_unit(target, Vector2i(4, 2))
		var spell := cards.family_spell("exp_ct_repercussion")
		var marker := spell.get_scaled_damage(hero)
		var expected := roundi(1.5 * mini(bronze, CatabaseCombatModifier.bronze_spend_cap(hero)))
		var context: CastContext = field.caster.begin_cast(hero, spell, target.grid_pos)
		assert_false(context.failed)
		var report: Dictionary = field.caster.resolve_cast(context)
		assert_false(report.get("failed", false))
		var actual := marker + int(context.damage_bonus_by_cell.get(Vector2i(4, 2), 0))
		assert_eq(actual, expected)
		assert_gt(actual, marker)
		rows.append({"bronze_before": bronze, "marker": marker, "real_pre_mitigation_payload": actual})
	observations["repercussion_payload"] = rows
