extends GutTest
const Inventory := preload("res://ui/expedition/consumable_deck_inventory.gd")
const Dossier := preload("res://ui/expedition/consumable_player_dossier.gd")
const State := preload("res://core/expedition/consumable_cards_state.gd")
const Catalog := preload("res://core/expedition/consumable_card_catalog.gd")


func test_each_copy_has_exactly_one_destination_after_transfers() -> void:
	var cards := State.new()
	cards.initialize_deck(Catalog.preset())
	for row in Catalog.data().cards:
		cards.add_copy(str(row.id))
	var total := cards.copies.size()
	for copy in cards.copies.duplicate(true):
		cards.move_card(copy.id)
		var view := Inventory.partition(cards.copies, cards.active)
		var ids: Array = []
		for lane in ["deck", "reserve"]:
			for group in view[lane].values():
				ids.append_array(group)
		assert_eq(ids.size(), total)
		assert_eq(view.deck_count, cards.active.size())
		for item in cards.copies:
			assert_eq(ids.count(item.id), 1, "No duplicate or missing copy")
			var lane := "deck" if item.id in cards.active else "reserve"
			assert_has(view[lane][item.family], item.id)


func test_same_spell_has_independent_stacks_and_costs_only_count_deck() -> void:
	var cards := State.new()
	var first := cards.add_copy("n01")
	var second := cards.add_copy("n01")
	var third := cards.add_copy("t02")
	assert_true(cards.move_card(first))
	var view := Inventory.partition(cards.copies, cards.active)
	assert_eq(view.deck.n01, [first])
	assert_eq(view.reserve.n01, [second])
	assert_eq(view.reserve.t02, [third])
	assert_eq(view.costs, { 1: 1 })
	assert_true(cards.set_opening(first))
	assert_true(cards.move_card(first))
	assert_true(cards.opening.is_empty(), "Removing opening repairs the opening choice")
	view = Inventory.partition(cards.copies, cards.active)
	assert_true(view.deck.is_empty())
	assert_eq(view.reserve_count, 3)


func test_cap_and_combat_lock_preserve_partition() -> void:
	var cards := State.new()
	for index in 4:
		var uid := cards.add_copy("n01")
		assert_eq(cards.move_card(uid), index < 3)
	var before := Inventory.partition(cards.copies, cards.active)
	assert_eq(before.deck.n01.size(), 3)
	assert_eq(before.reserve.n01.size(), 1)
	cards.combat_started = true
	assert_false(cards.move_card(cards.active[0]))
	assert_eq(Inventory.partition(cards.copies, cards.active), before)


func test_affinity_labels_are_rules_backed_and_inspection_is_read_only() -> void:
	assert_eq(Inventory.affinity(Catalog.card("n01")), "Commune")
	assert_eq(Inventory.affinity(Catalog.card("a01")), "Assassin")
	var cards := State.new()
	cards.initialize_deck(Catalog.preset("thaumaturge"))
	var copies := cards.copies.duplicate(true)
	var active := cards.active.duplicate()
	Inventory.partition(cards.copies, cards.active)
	assert_eq(cards.copies, copies)
	assert_eq(cards.active, active)
