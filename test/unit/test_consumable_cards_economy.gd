extends GutTest
const Catalog := preload("res://core/expedition/consumable_card_catalog.gd")
const Profile := preload("res://core/expedition/consumable_cards_profile.gd")
const Cards := preload("res://core/expedition/consumable_cards_state.gd")
const Economy := preload("res://core/expedition/consumable_card_economy.gd")


func test_precommitted_loot_independent_from_draws_and_reload() -> void:
	var cards = Profile.create_cards(Catalog.preset())
	cards.run_seed = 7912
	var encounter: Dictionary = Catalog.data().route[2]
	var roster: Array[String] = ["e1", "e2", "e3"]
	var committed := Economy.commit_loot(cards, encounter, roster)
	for uid in roster:
		assert_gte(committed[uid].cards.size(), 2)
	cards.start_turn()
	for _round in 4:
		cards.end_turn()
		cards.start_turn()
	var restored := Cards.new()
	assert_true(restored.restore(JSON.parse_string(JSON.stringify(cards.snapshot()))))
	assert_eq(
		Economy.commit_loot(restored, encounter, roster),
		JSON.parse_string(JSON.stringify(committed)),
	)
	cards.finish_combat()
	var reward := Economy.collect_victory(cards, encounter, ["e1", "e3"])
	assert_true(reward.success)
	assert_eq(
		reward.reward.copies.size(),
		committed.e1.cards.size() + committed.e3.cards.size(),
		"sacrificed e2 has no loot",
	)
	var count: int = cards.copies.size()
	assert_true(Economy.collect_victory(cards, encounter, ["e1", "e3"]).replayed)
	assert_eq(cards.copies.size(), count)


func test_finite_shop_atomic_payment_and_reload() -> void:
	var cards = Profile.create_cards(Catalog.preset())
	var shop := Economy.market(cards, "d04", 3)
	assert_eq(shop.bags.size(), 2)
	assert_eq(shop.singles.size(), 12)
	assert_true(Economy.transact(cards, "d04", { "id": "bag1", "kind": "bag" }).success)
	assert_eq(cards.gold, 4)
	assert_eq(cards.copies.size(), 21)
	var before: Dictionary = cards.snapshot()
	assert_false(Economy.transact(cards, "d04", { "id": "bag2", "kind": "bag" }).success)
	assert_eq(cards.snapshot(), before, "insufficient money leaves RNG and stock unchanged")
	var restored := Cards.new()
	assert_true(restored.restore(JSON.parse_string(JSON.stringify(before))))
	assert_true(Economy.transact(restored, "d04", { "id": "bag1", "kind": "bag" }).replayed)
	assert_eq(restored.gold, 4)
	assert_eq(Economy.market(restored, "d04", 3).bags.size(), 1)


func test_trade_uids_sale_opening_and_family_progression() -> void:
	var cards = Profile.create_cards(Catalog.preset())
	Economy.market(cards, "d04", 3)
	var uids: Array = cards.active.slice(0, 3)
	assert_true(cards.set_opening(uids[0]))
	var before: Dictionary = cards.snapshot()
	assert_false(Economy.transact(cards, "d04", {
			"id": "bad",
			"kind": "trade",
			"copies": [uids[0], uids[0], uids[1]],
			"family": "n01",
		}).success)
	assert_eq(cards.snapshot(), before)
	var trade := Economy.transact(
		cards,
		"d04",
		{ "id": "trade1", "kind": "trade", "copies": uids, "family": "n01" },
	)
	assert_true(trade.success)
	assert_eq(trade.receipt.removed, uids)
	assert_eq(cards.copies.size(), 13)
	assert_eq(cards.retired.size(), 3)
	assert_eq(cards.opening.size(), 0)
	assert_eq(cards.invariant_errors(), [])
	assert_true(Economy.transact(cards, "d04", {
			"id": "sale1",
			"kind": "sell",
			"copies": [cards.active[0]],
		}).success)
	assert_eq(cards.gold, 41)


func test_route_budget_before_boss_and_level_twelve() -> void:
	var cards = Profile.create_cards(Catalog.preset())
	var index := 0
	for encounter in Catalog.data().route:
		index += 1
		var uids: Array[String] = ["e1"]
		Economy.commit_loot(cards, encounter, uids)
		assert_true(Economy.collect_victory(cards, encounter, uids).success)
		if index == 11:
			assert_eq(cards.gold, 515)
			assert_eq(cards.level, 12)
	assert_eq(cards.gold, 515, "boss does not manufacture post-run loot or gold")
