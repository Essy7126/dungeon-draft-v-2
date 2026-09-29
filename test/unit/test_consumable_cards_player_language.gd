extends GutTest
const Catalog := preload("res://core/expedition/consumable_card_catalog.gd")
const Language := preload("res://ui/expedition/card_player_language.gd")
const Math := preload("res://core/expedition/consumable_card_math.gd")


func test_every_printed_card_explains_its_effect_without_internal_math() -> void:
	for definition in Catalog.data().cards:
		for upgraded in [false, true]:
			var row := Catalog.card(str(definition.id), upgraded)
			var before := row.duplicate(true)
			for power in [18.0, 31.5, 80.0]:
				var text := Language.effect(row, power)
				assert_false(text.is_empty(), str(row.id))
				for forbidden in [
					" P",
					"min(",
					" S ",
					"activation",
					"dynamique",
					"famille",
					"prouesse",
				]:
					assert_false(
						forbidden in text.replace(" PV", "").replace(" PM", ""),
						str(row.id) + forbidden,
					)
				assert_false(Language.scaling(row).is_empty(), str(row.id))
			assert_eq(row, before, "Reading never changes an effective definition")


func test_examples_explain_real_conditions_and_upgraded_values() -> void:
	assert_string_contains(Language.effect(Catalog.card("a02"), 18), "17 dégâts physiques")
	assert_string_contains(
		Language.effect(Catalog.card("a02"), 18),
		"+10 dégâts si la cible porte une Marque",
	)
	assert_string_contains(Language.effect(Catalog.card("g06", true), 20), "9 points de garde")
	assert_string_contains(Language.effect(Catalog.card("t01", true), 20), "pendant 3 tours")
	assert_string_contains(Language.effect(Catalog.card("r07", true), 20), "1 ou 2 cases, au choix")
	assert_string_contains(Language.effect(Catalog.card("r06"), 20), "ligne de 3 cases")
	assert_string_contains(Language.effect(Catalog.card("t05"), 20), "même vous")
	assert_string_contains(Language.effect(Catalog.card("i01"), 20), "60 % de vos PV maximum")
	assert_string_contains(Language.effect(Catalog.card("g09"), 20), "jusqu'à 16 points")
	assert_string_contains(Language.effect(Catalog.card("g09"), 20), "150 % de la garde sacrifiée")


func test_power_percentages_do_not_claim_a_damage_multiplier() -> void:
	assert_eq(Language.plain("+0,25 P ; 1.5 P"), "+25 % de Puissance ; 150 % de Puissance")
	assert_string_contains(Language.PASSIVES.assassin, "25 % de votre Puissance")
	assert_string_contains(Language.PASSIVES.assassin, "hors diagonales")
	assert_string_contains(Language.scaling(Catalog.card("n01")), "55 % de votre Puissance")
	assert_eq(Language.scaling(Catalog.card("n03")), "Cet effet ne dépend pas de votre Puissance.")
	for id in Catalog.CLASSES:
		assert_eq(Language.CLASSES[id].size(), 3)
		assert_false(Language.PASSIVES[id].is_empty())
		for spec in Catalog.class_row(id).specs:
			assert_false(Language.SPECIALIZATIONS[spec].is_empty())


func test_role_does_not_invent_an_element_for_utility_cards() -> void:
	assert_eq(Language.identity(Catalog.card("n02")), "Protection · Soleil")
	assert_eq(Language.identity(Catalog.card("n03")), "Déplacement")
	assert_eq(Language.identity(Catalog.card("t02")), "Attaque · Feu · magique")
	assert_eq(Language.identity(Catalog.card("t04")), "Attaque · Eau/Nuit · magique")
	assert_string_contains(Language.DECK_HELP, "3 cartes Estoc = 3 utilisations")
