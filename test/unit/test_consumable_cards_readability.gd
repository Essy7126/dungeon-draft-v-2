extends GutTest
const Catalog := preload("res://core/expedition/consumable_card_catalog.gd")
const Description := preload("res://ui/expedition/consumable_card_description.gd")
const Receipt := preload("res://ui/expedition/consumable_loot_receipt.gd")


func test_upgraded_range_keeps_the_action_and_conditional_effects() -> void:
	for id in ["n06", "n07", "a02", "r01", "r02", "r03", "r06", "g09", "t08"]:
		var row := Catalog.card(id, true)
		var before := row.duplicate(true)
		var text := Description.full_text(row, true)
		assert_string_contains(text, str(row.baseText), id + " keeps its full action")
		assert_false(text.begins_with("Effet de base"))
		assert_false(text.begins_with("Même effet"))
		assert_eq(row, before, "presentation never mutates rules")
		assert_eq(Receipt.card_record(id, true).body, text, "loot and combat agree")


func test_improved_durations_and_collision_replace_obsolete_values() -> void:
	var cases := {
		"a01": ["3 phases ennemies", "2 phases ennemies"],
		"t01": ["3 phases", "2 phases"],
		"t02": ["2 phases.", "1 phase."],
		"t04": ["3 phases", "2 phases"],
		"g06": ["0,45 P de garde", "0,30 P de garde"],
	}
	for id in cases:
		var text := Description.full_text(Catalog.card(id, true), true)
		assert_string_contains(text, cases[id][0], id)
		assert_false(cases[id][1] in text, id + " no obsolete amount")
		assert_eq(Description.full_text(Catalog.card(id)), Catalog.card(id).baseText)


func test_all_printed_forms_have_standalone_text() -> void:
	for row in Catalog.data().cards:
		for improved in [false, true]:
			var text := Description.full_text(Catalog.card(str(row.id), improved), improved)
			assert_false(text.is_empty(), str(row.id))
			assert_false(text.begins_with("Même "), str(row.id))
			assert_false(text.begins_with("Effet de base"), str(row.id))
