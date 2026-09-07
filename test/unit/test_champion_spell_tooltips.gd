extends GutTest

const CHASSIS := preload("res://data/units/allies/achilles.tres")
const CATALOG := preload("res://data/characters/achilles/doctrines/achilles_mastery_catalog.tres")


func test_scourge_hud_tooltip_announces_two_target_line() -> void:
	_assert_mastery_zone(&"achilles_wrath_scourge_of_troy", "peleid_strike", "Ligne · 2 cibles", "132 / 77")


func test_death_line_hud_tooltip_announces_three_target_line() -> void:
	_assert_mastery_zone(&"achilles_chiron_death_line", "pelion_shot", "Ligne · 3 cibles", "100 / 70 / 40")


func test_centaur_volley_hud_tooltip_announces_fan_instead_of_single_target() -> void:
	_assert_mastery_zone(&"achilles_chiron_centaur_volley", "pelion_shot", "Éventail · 3 cibles", "70 / 70 / 70")


func test_unmodified_champion_and_legacy_tooltips_keep_the_authored_zone() -> void:
	var hero := Unit.from_data(CHASSIS)
	var strike := load("res://data/spells/achilles/peleid_strike.tres") as Spell
	assert_true(CombatGlossary.spell_card_bbcode(hero, strike).contains("Zone : 1"))
	var legacy := load("res://data/spells/Guerrier/tourbillon.tres") as Spell
	assert_true(CombatGlossary.spell_card_bbcode(hero, legacy).contains("Zone : Carre 1"))


func _assert_mastery_zone(node_id: StringName, spell_file: String, expected: String, damage_values: String) -> void:
	var hero := Unit.from_data(CHASSIS)
	hero.attack_power.base_value = 200.0
	var node := CATALOG.node_catalog()[node_id] as SkillTreeNodeData
	hero.mastery_nodes = [node]
	var spell := load("res://data/spells/achilles/%s.tres" % spell_file) as Spell
	var text := CombatGlossary.spell_card_bbcode(hero, spell)
	assert_true(text.contains("Zone : " + expected), text)
	assert_true(text.contains("Inflige %s dégâts physiques par cible." % damage_values), text)
	assert_true(text.contains("Avec vos statistiques et maîtrises"), text)
	assert_false(text.contains("Zone : 1"), text)
	assert_eq(spell.aoe_shape, Spell.AoeShape.SINGLE, "The shared spell is not mutated by the tooltip")


func test_guard_hud_value_includes_mastery_and_creation_multiplier_with_combat_rounding() -> void:
	var hero := Unit.from_data(CHASSIS)
	hero.mastery_nodes = [CATALOG.node_catalog()[&"achilles_summit_aeacus"] as SkillTreeNodeData]
	hero.shield_creation_multiplier = 1.1
	var guard := load("res://data/spells/achilles/bronze_guard.tres") as Spell
	for values in [[200.0, 100.0, 73], [16.0, 200.0, 19]]:
		hero.attack_power.base_value = values[0]
		hero.max_hp.base_value = values[1]
		var text := CombatGlossary.spell_card_bbcode(hero, guard)
		assert_true(text.contains("Accorde %d bouclier." % values[2]), text)
		assert_true(text.contains("Expire au début de la prochaine activation."))
	assert_almost_eq(guard.shield_scaling.prowess_coefficient, 0.25, 0.0001)
