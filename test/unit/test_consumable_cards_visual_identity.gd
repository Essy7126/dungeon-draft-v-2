extends GutTest
const Symbols := preload("res://ui/expedition/player_stat_symbols.gd")
const Catalog := preload("res://core/expedition/consumable_card_catalog.gd")
const Spells := preload("res://core/expedition/consumable_card_spells.gd")
const View := preload("res://ui/expedition/consumable_combat_card_view.gd")
const Receipt := preload("res://ui/expedition/consumable_loot_receipt.gd")


func test_element_symbols_follow_actual_components_without_mutating_them() -> void:
	for row in Catalog.data().cards:
		var before: Dictionary = row.duplicate(true)
		var elements := Symbols.elements(row)
		for id in Symbols.Rules.ELEMENTS:
			var expected := false
			for weights in row.elements.values():
				expected = expected or float(weights.get(id, 0)) > 0
			assert_eq(id in elements, expected, str(row.id) + " / " + id)
		assert_eq(row, before)
	for id in Symbols.COLORS:
		assert_not_null(Symbols.icon(id), id)


func test_all_card_faces_fit_seven_card_width_and_keep_identity_when_disabled() -> void:
	var hero := Unit.new()
	for row in Catalog.data().cards:
		for upgraded in [false, true]:
			var button := Button.new()
			button.disabled = upgraded
			button.size = Vector2(98, 190)
			add_child(button)
			var spell := Spells.make_spell(row.id, upgraded)
			View.face(button, spell, hero, int(row.ap))
			await get_tree().process_frame
			await get_tree().process_frame
			var rarity = button.find_child("CardRarityName", true, false)
			assert_eq(rarity.text, Receipt.RARITY_NAMES[row.rarity])
			assert_not_null(button.find_child("CardAffinity", true, false))
			for child in button.find_children("*", "Control", true, false):
				assert_true(
					button.get_global_rect().grow(1).encloses(child.get_global_rect()),
					str(row.id) + " " + str(child.name),
				)
			button.free()
