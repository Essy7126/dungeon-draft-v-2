extends GutTest

const RUN: RunData = preload("res://data/runs/odyssey.tres")
const TRIAL: RunData = preload("res://data/runs/philosopher_trial.tres")
const MAGE: UnitData = preload("res://data/units/enemies/philosopher_mage.tres")
const AXIOM: Spell = preload("res://data/spells/enemies/philosopher_axiom.tres")
const CLASSIFICATIONS = preload("res://data/characters/philosopher_mage/attack_classifications.tres")
const CAMPAIGN_CLASSIFICATIONS = preload("res://data/characters/catabase/attack_classifications.tres")


class ClassificationBattle:
	extends "res://battle/battle.gd"

	func _ready() -> void:
		pass


func test_campaign_introduces_the_canonical_mage_in_lethe_without_adding_an_enemy() -> void:
	assert_eq(RUN.rooms.size(), 5)
	assert_eq(RUN.content_profile.hero_profiles.size(), 1)
	assert_eq(RUN.content_profile.hero_profiles[0].base_unit_data.unit_id, &"achilles")
	var expected_counts := [1, 3, 2, 3, 3]
	for index in range(RUN.rooms.size()):
		var room := RUN.rooms[index]
		var encounter := room.encounter_definition
		assert_true(encounter.is_valid(), str(encounter.validation_errors()))
		var roster := encounter.expanded_roster()
		assert_eq(roster.size(), expected_counts[index], room.room_name)
		assert_eq(room.enemies, roster, "fallback and encounter must name the same units in order")
		assert_eq(encounter.living_enemy_cap, expected_counts[index], room.room_name)
		assert_eq(roster.has(MAGE), index == 3, "the mage is introduced only in room IV")
	var lethe := RUN.rooms[3]
	assert_eq(lethe.encounter_definition.expanded_roster().map(
		func(unit: UnitData): return unit.unit_id),
		[&"philosopher_mage", &"spectre_greatsword", &"odyssey_skirmisher"])
	assert_eq(lethe.encounter_definition.encounter_id, &"catabase_room_04")
	assert_eq(lethe.encounter_definition.base_xp, 160)
	assert_eq(lethe.encounter_definition.minimum_path_distance_by_role[&"philosopher_mage"], 12)
	assert_eq(lethe.encounter_definition.maximum_path_distance_by_role[&"philosopher_mage"], 17)
	assert_eq(TRIAL.rooms[0].encounter_definition.expanded_roster().map(
		func(unit: UnitData): return unit.unit_id), [&"philosopher_mage", &"spectre_greatsword"])


func test_campaign_battle_merges_projectile_axiom_with_all_achilles_classifications() -> void:
	assert_same(RUN.action_classification_catalog, CAMPAIGN_CLASSIFICATIONS)
	assert_true(RUN.action_classification_catalog.is_valid())
	var state := CharacterRunState.new()
	state.progression_profile = RUN.content_profile.hero_profiles[0].progression_profile
	var hero_catalog := state.progression_profile.combat_action_classification_catalog
	var hero_entries_before := hero_catalog.entries.duplicate()
	var mage_entries_before := CLASSIFICATIONS.entries.duplicate()
	var battle := ClassificationBattle.new()
	autofree(battle)
	battle.grid = GridData.new(5, 3)
	battle.pathfinder = Pathfinder.new(battle.grid)
	battle.terrain_effects = TerrainEffects.new(battle.grid)
	battle.spell_caster = SpellCaster.new(battle.grid, battle.pathfinder, battle.terrain_effects)
	assert_eq(battle.spell_caster.get_action_classification(AXIOM), &"")
	battle._configure_action_classifications(RUN, [state])
	assert_eq(battle.spell_caster.get_action_classification(AXIOM), &"PROJECTILE")
	for entry: CombatActionClassificationData in hero_catalog.entries:
		var ability := Spell.new()
		ability.spell_id = entry.ability_id
		assert_eq(battle.spell_caster.get_action_classification(ability), entry.classification_id(),
			"the run catalog retains Achilles classification: %s" % entry.ability_id)
	for entry: CombatActionClassificationData in CLASSIFICATIONS.entries:
		var ability := Spell.new()
		ability.spell_id = entry.ability_id
		assert_eq(battle.spell_caster.get_action_classification(ability), entry.classification_id())
	assert_eq(hero_catalog.entries, hero_entries_before, "the merge does not rewrite the hero catalog")
	assert_eq(CLASSIFICATIONS.entries, mage_entries_before, "the trial's shared catalog is not rewritten")
