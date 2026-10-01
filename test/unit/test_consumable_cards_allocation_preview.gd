extends GutTest
const Preview := preload("res://ui/expedition/consumable_allocation_preview.gd")
const Cards := preload("res://core/expedition/consumable_cards_state.gd")
const Catalog := preload("res://core/expedition/consumable_card_catalog.gd")


func test_preview_uses_prepared_deck_and_valid_distance_contexts() -> void:
	var cards := Cards.new()
	cards.prototype_revision = 1
	cards.level = 8
	cards.acquire("n02", "loot", "reserve")
	cards.active.append(cards.acquire("n01", "loot", "deck"))
	var candidate := Cards.new()
	candidate.prototype_revision = 1
	candidate.level = 8
	candidate.aptitudes.contact = 1
	var rows := Preview.rows(cards, candidate)
	assert_eq(rows.size(), 1)
	assert_eq(rows[0].family, "n01", "reserve guard must not hide the active attack")
	assert_eq(rows[0].distance, 1)
	assert_gt(rows[0].after, rows[0].before, "Contact is visible at one cell")
	assert_eq(cards.aptitudes.contact, 0, "preview is read-only")
	candidate.aptitudes.contact = 0
	candidate.aptitudes.distance = 1
	rows = Preview.rows(cards, candidate)
	assert_eq(rows[0].after, rows[0].before, "Distance does not improve melee")


func test_changed_ranged_effects_are_prioritized_without_inventing_range() -> void:
	var cards := Cards.new()
	cards.prototype_revision = 1
	cards.level = 8
	cards.active.append(cards.acquire("n01", "loot", "melee"))
	var ranged_id := ""
	for card in Catalog.data().cards:
		if float(card.damage) > 0 and int(card.max) >= 3:
			ranged_id = str(card.id)
			break
	assert_false(ranged_id.is_empty())
	cards.active.append(cards.acquire(ranged_id, "loot", "ranged"))
	var candidate := Cards.new()
	candidate.prototype_revision = 1
	candidate.level = 8
	candidate.aptitudes.distance = 1
	var rows := Preview.rows(cards, candidate)
	assert_eq(rows[0].family, ranged_id)
	assert_gte(rows[0].distance, 3)
	assert_gt(rows[0].after, rows[0].before)
	for row in rows:
		var card := Catalog.card(row.family)
		assert_between(row.distance, int(card.min), int(card.max))
		if row.distance < 3:
			assert_eq(row.before, row.after)


func test_secondary_effect_and_rounding_are_visible() -> void:
	var cards := Cards.new()
	cards.prototype_revision = 1
	cards.level = 8
	cards.active.append(cards.acquire("n02", "loot", "guard"))
	var candidate := Cards.new()
	candidate.prototype_revision = 1
	candidate.level = 8
	candidate.aptitudes.protection = 1
	var rows := Preview.rows(cards, candidate)
	assert_eq(rows[0].caption, "Garde")
	assert_eq(rows[0].distance, 0)
	assert_gt(rows[0].after, rows[0].before)


func test_rounding_does_not_invent_a_damage_gain() -> void:
	var cards := Cards.new()
	cards.prototype_revision = 1
	cards.active.append(cards.acquire("n01", "loot", "rounding"))
	var candidate := Cards.new()
	candidate.prototype_revision = 1
	candidate.aptitudes.contact = 1
	var rows := Preview.rows(cards, candidate)
	assert_eq(rows[0].before, 9)
	assert_eq(rows[0].after, 9, "8.8 and 9.328 both round to nine")
	assert_false(rows[0].changed)
