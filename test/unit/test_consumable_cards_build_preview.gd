extends GutTest
const Preview := preload("res://ui/expedition/consumable_build_preview.gd")
const State := preload("res://core/expedition/consumable_cards_state.gd")
const Catalog := preload("res://core/expedition/consumable_card_catalog.gd")
const Presenter := preload("res://ui/expedition/consumable_cards_presenter.gd")


func test_all_equipment_previews_match_rules_without_changing_loadout() -> void:
	var cards := State.new()
	cards.level = 6
	cards.attributes = { "power": 2, "vitality": 1, "resolve": 2 }
	for item in Catalog.data().equipment:
		cards.equipped[item.slot] = item.id
	for item in Catalog.data().equipment:
		var original := cards.equipped.duplicate(true)
		var result := Preview.compare(cards, item.id)
		assert_eq(cards.equipped, original, "inspection is pure: " + str(item.id))
		var changed := original.duplicate()
		if changed.get(item.slot) == item.id:
			changed.erase(item.slot)
		else:
			changed[item.slot] = item.id
		var before := Preview.Math.stats(
			cards.level,
			cards.attributes,
			Preview.Math.equipment_mods(original),
		)
		var after := Preview.Math.stats(cards.level, cards.attributes, Preview.Math.equipment_mods(
				changed
			))
		for metric in Preview.METRICS:
			var rows: Array = result.rows.filter(
				func(row):
					return row.key == metric,
			)
			if is_equal_approx(float(before[metric]), float(after[metric])):
				assert_true(rows.is_empty(), "no fake change for " + metric)
			else:
				assert_eq(rows.size(), 1)
				assert_eq(rows[0].before, before[metric])
				assert_eq(rows[0].after, after[metric])


func test_caps_and_sources_explain_effective_bonuses() -> void:
	var cards := State.new()
	cards.attributes.resolve = 17
	var result := Preview.compare(cards, "b_plate")
	var physical: Array = result.rows.filter(
		func(row):
			return row.key == "physical",
	)
	assert_almost_eq(float(physical[0].before), .34, .0001)
	assert_almost_eq(float(physical[0].after), .4, .0001)
	assert_string_contains(" ".join(result.caps), "excédent sans effet 6 %")
	cards.equipped.body = "b_plate"
	for source in Preview.sources(cards):
		assert_almost_eq(
			float(source.base) + float(source.attributes) + float(source.equipment),
			float(source.total),
			.0001,
		)
	var sources := Preview.sources(cards).filter(
		func(row):
			return row.key == "physical",
	)
	assert_almost_eq(float(sources[0].equipment), .06, .0001)


func test_conditional_gear_does_not_inflate_power_and_p_units_are_not_percentages() -> void:
	var cards := State.new()
	var result := Preview.compare(cards, "w_blade")
	assert_true(result.rows.is_empty())
	assert_eq(result.effects[0].key, "melee")
	assert_almost_eq(float(result.effects[0].after), .12, .0001)
	assert_eq(
		Presenter.item_text(Presenter.item("h_bronze")),
		"+60 % de Puissance · garde initiale",
	)
	assert_string_contains(Presenter.item_text(Presenter.item("j_eye")), "+12 % de Puissance")
	assert_true(Preview.compare(cards, "thread").is_empty(), "relic rules are not permanent stats")
