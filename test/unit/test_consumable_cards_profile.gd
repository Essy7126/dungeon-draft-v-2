extends GutTest
const Catalog := preload("res://core/expedition/consumable_card_catalog.gd")
const Profile := preload("res://core/expedition/consumable_cards_profile.gd")
const Cards := preload("res://core/expedition/consumable_cards_state.gd")


func test_catalog_contract_and_detached_rows() -> void:
	assert_eq(Catalog.validation_errors(Catalog.data()), [])
	assert_eq(Catalog.pool().size(), 48)
	for id in Catalog.CLASSES:
		assert_true(Catalog.valid_departure(Catalog.preset(id)))
		assert_eq(Catalog.pool(id, "normal", true).size(), 12)
	var changed := Catalog.card("g09", true)
	assert_eq(int(changed.max), 4)
	assert_eq(float(changed.sacrificeCap), 0.8)
	changed.damage = 999
	assert_eq(float(Catalog.card("g09").damage), 0.7)
	var malformed := Catalog.data()
	malformed.cards[0].op = "unknown"
	assert_false(Catalog.validation_errors(malformed).is_empty())
	malformed = Catalog.data()
	malformed.route[0].roster = ["missing"]
	assert_false(Catalog.validation_errors(malformed).is_empty())


func test_custom_departure_allows_fifteen_copies_without_five_family_constraint() -> void:
	var selection := Catalog.preset()
	selection.card_families[0] = "n01"
	assert_true(Catalog.valid_departure(selection))
	selection.card_families[1] = "a05"
	assert_false(Catalog.valid_departure(selection), "no elite at departure")
	selection = Catalog.preset()
	selection.card_families[3] = "a01"
	assert_false(Catalog.valid_departure(selection), "three per family")
	assert_false(Profile.matches({ "rules_revision": 4 }))
	assert_false(Profile.matches({ "ruleset_id": "catabase_cards_v1" }))


func test_optional_normal_opening_and_disjoint_piles() -> void:
	var cards = Profile.create_cards(Catalog.preset())
	var opening_uid: String = cards.active[0]
	assert_true(cards.set_opening(opening_uid))
	var rare: String = cards.acquire("a05", "loot", "test")
	assert_true(cards.move_card(rare))
	assert_false(cards.set_opening(rare))
	cards.start_turn()
	assert_eq(cards.hand.size(), 5)
	assert_has(cards.hand, opening_uid)
	assert_does_not_have(cards.draw_pile, opening_uid)
	assert_false(cards.move_card(rare))
	assert_eq(cards.invariant_errors(), [])


func test_zero_prepared_and_large_reserve_are_legal() -> void:
	var cards = Profile.create_cards(Catalog.preset())
	for uid in cards.active.duplicate():
		assert_true(cards.move_card(uid))
	for index in 210:
		cards.acquire("n01", "loot", "reserve:%d" % index)
	assert_eq(cards.copies.size(), 225)
	assert_true(cards.valid_deck(cards.active))
	cards.start_turn()
	assert_eq(cards.hand.size(), 0)
	assert_eq(cards.invariant_errors(), [])
	var restored := Cards.new()
	assert_true(restored.restore(JSON.parse_string(JSON.stringify(cards.snapshot()))))
	assert_eq(restored.copies.size(), 225)


func test_restore_rejects_duplicated_zones_and_consumed_uids_atomically() -> void:
	var cards = Profile.create_cards(Catalog.preset())
	cards.start_turn()
	var before: Dictionary = cards.snapshot()
	var corrupted := before.duplicate(true)
	corrupted.draw_pile.append(corrupted.hand[0])
	assert_false(cards.restore(corrupted))
	assert_eq(cards.snapshot(), before)
	corrupted = before.duplicate(true)
	corrupted.consumed[corrupted.hand[0]] = { "family": cards.copy_for(corrupted.hand[0]).family }
	assert_false(cards.restore(corrupted))
	assert_eq(cards.snapshot(), before)


func test_rng_and_retention_survive_json_roundtrip() -> void:
	var cards = Profile.create_cards(Catalog.preset())
	cards.run_seed = 251
	cards.encounter_id = "c3"
	cards.start_turn()
	var kept: String = cards.hand[0]
	cards.pending_choice = { "kind": "retain" }
	assert_false(cards.retain_copy("unknown"))
	assert_true(cards.retain_copy(kept))
	cards.end_turn()
	assert_eq(cards.hand, [kept])
	var restored := Cards.new()
	assert_true(restored.restore(JSON.parse_string(JSON.stringify(cards.snapshot()))))
	for _round in 10:
		cards.start_turn()
		restored.start_turn()
		assert_eq(restored.hand, cards.hand)
		cards.end_turn()
		restored.end_turn()
	assert_eq(restored.invariant_errors(), [])


func test_class_and_specialization_have_separate_counters_and_family_upgrades() -> void:
	var cards = Profile.create_cards(Catalog.preset())
	assert_false(cards.specialize("execution"))
	cards.level = 4
	assert_true(cards.specialize("execution"))
	assert_false(cards.specialize("relay"))
	assert_true(cards.upgrade_copy("a01"))
	assert_false(cards.upgrade_copy("a02"))
	cards.level = 8
	assert_false(cards.upgrade_copy("a01"))
	assert_true(cards.upgrade_copy("a02"))
	cards.start_turn()
	assert_true(cards.take_trigger("class"))
	assert_true(cards.take_trigger("spec"))
	assert_false(cards.take_trigger("class"))
	cards.end_turn()
	cards.start_turn()
	assert_true(cards.take_trigger("class"))
