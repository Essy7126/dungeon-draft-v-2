extends GutTest

const RUN: RunData = preload("res://data/runs/odyssey.tres")
const CAMPAIGN := preload("res://data/characters/catabase/attack_classifications.tres")
const PARIS := preload("res://data/characters/paris/attack_classifications.tres")
const MAGE := preload("res://data/characters/philosopher_mage/attack_classifications.tres")


class ClassificationBattle:
	extends "res://battle/battle.gd"

	func _ready() -> void:
		pass


func test_campaign_uses_both_complete_enemy_catalogs_without_mutating_standalones() -> void:
	assert_same(RUN.action_classification_catalog, CAMPAIGN)
	assert_true(CAMPAIGN.is_valid(), str(CAMPAIGN.validation_errors()))
	assert_eq(CAMPAIGN.entries.size(), MAGE.entries.size() + PARIS.entries.size())
	assert_eq(MAGE.entries.size(), 6)
	assert_eq(PARIS.entries.size(), 8)
	for entry in MAGE.entries + PARIS.entries:
		assert_true(CAMPAIGN.entries.has(entry), "campaign reuses each canonical resource")


func test_real_battle_merge_retains_hero_and_classifies_both_paris_forms() -> void:
	var state := CharacterRunState.new()
	state.progression_profile = RUN.content_profile.hero_profiles[0].progression_profile
	var hero_catalog := state.progression_profile.combat_action_classification_catalog
	var before := hero_catalog.entries.duplicate()
	var battle := ClassificationBattle.new()
	autofree(battle)
	battle.grid = GridData.new(6, 6)
	battle.pathfinder = Pathfinder.new(battle.grid)
	battle.terrain_effects = TerrainEffects.new(battle.grid)
	battle.spell_caster = SpellCaster.new(battle.grid, battle.pathfinder, battle.terrain_effects)
	battle._configure_action_classifications(RUN, [state])
	for entry: CombatActionClassificationData in hero_catalog.entries + CAMPAIGN.entries:
		var ability := Spell.new()
		ability.spell_id = entry.ability_id
		assert_eq(battle.spell_caster.get_action_classification(ability), entry.classification_id(), str(entry.ability_id))
	assert_eq(hero_catalog.entries, before)
	for id: StringName in [&"paris_spectral_arrow", &"paris_fire_arrow", &"paris_ice_arrow", &"paris_vortex_arrow"]:
		var ability := Spell.new()
		ability.spell_id = id
		assert_eq(battle.spell_caster.get_action_classification(ability), &"PROJECTILE")
