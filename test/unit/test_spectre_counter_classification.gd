extends GutTest

const HERO := preload("res://data/units/allies/achilles.tres")
const SPECTRE := preload("res://data/units/enemies/spectre_greatsword.tres")
const PROFILE := preload("res://data/runs/progression/odyssey/achilles_progression_profile.tres")
const CATALOG := preload("res://data/characters/achilles/doctrines/achilles_mastery_catalog.tres")
const CLEAVE := preload("res://data/spells/enemies/spectre_heavy_cleave.tres")
const STRIKE := preload("res://data/spells/achilles/peleid_strike.tres")
const GUARD := preload("res://data/spells/achilles/bronze_guard.tres")

var _battle: ClassificationBattle
var _hero: Unit
var _spectre: Unit
var _state: CharacterRunState
var _automatic: Array[Dictionary] = []


class ClassificationBattle:
	extends "res://battle/battle.gd"

	func _ready() -> void:
		pass


func before_each() -> void:
	_automatic.clear()
	_battle = ClassificationBattle.new()
	add_child(_battle)
	_battle.grid = GridData.new(5, 3)
	_battle.pathfinder = Pathfinder.new(_battle.grid)
	_battle.terrain_effects = TerrainEffects.new(_battle.grid)
	_battle.spell_caster = SpellCaster.new(_battle.grid, _battle.pathfinder, _battle.terrain_effects)
	_hero = Unit.from_data(HERO)
	_hero.spells.assign(PROFILE.spells)
	_spectre = Unit.from_data(SPECTRE)
	for unit in [_hero, _spectre]:
		unit.crit_chance.base_value = 0.0
		unit.esquive.base_value = 0.0
	assert_true(_battle.grid.place_unit(_hero, Vector2i(1, 1)))
	assert_true(_battle.grid.place_unit(_spectre, Vector2i(2, 1)))
	_hero.facing_dir = Vector2i.RIGHT
	_state = CharacterRunState.new()
	_state.progression_profile = PROFILE
	_state.unit = _hero
	EventBus.spell_visual_resolved.connect(_on_resolved_visual)


func after_each() -> void:
	EventBus.spell_visual_resolved.disconnect(_on_resolved_visual)
	_battle._begin_battle_shutdown()
	_battle.free()
	_battle = null
	_state = null


func test_battle_loads_the_explicit_profile_catalog_including_the_canonical_cleave() -> void:
	assert_eq(_battle.spell_caster.get_action_classification(CLEAVE), &"")
	_battle._configure_action_classifications(null, [_state])
	assert_eq(_battle.spell_caster.get_action_classification(CLEAVE), &"MELEE")
	assert_eq(_battle.spell_caster.get_action_classification(STRIKE), &"MELEE")
	assert_eq(_battle.spell_caster.get_action_classification(PROFILE.spells[2]), &"PROJECTILE")
	assert_eq([CLEAVE.damage, CLEAVE.ap_cost, CLEAVE.spell_range], [18, 2, 1])


func test_explicit_run_entry_overrides_profile_without_mutating_the_shared_catalog() -> void:
	var original_count := PROFILE.combat_action_classification_catalog.entries.size()
	var entry := CombatActionClassificationData.new()
	entry.ability_id = CLEAVE.spell_id
	entry.classification = CombatActionClassificationData.Classification.AREA
	var catalog := CombatActionClassificationCatalogData.new()
	catalog.catalog_id = &"classification_override_fixture"
	catalog.entries = [entry]
	var run := RunData.new()
	run.action_classification_catalog = catalog
	_battle._configure_action_classifications(run, [null, CharacterRunState.new(), _state])
	assert_eq(_battle.spell_caster.get_action_classification(CLEAVE), &"AREA")
	assert_eq(_battle.spell_caster.get_action_classification(STRIKE), &"MELEE")
	assert_eq(PROFILE.combat_action_classification_catalog.entries.size(), original_count)
	var registry := CombatActionClassificationRegistry.new()
	assert_true(registry.initialize(PROFILE.combat_action_classification_catalog))
	assert_eq(registry.classification_for_spell(CLEAVE), &"MELEE")


func test_nil_profiles_preserve_unknown_classification_without_inference() -> void:
	_battle._configure_action_classifications(null, [null, CharacterRunState.new()])
	assert_eq(_battle.spell_caster.get_action_classification(CLEAVE), &"")
	assert_eq(_battle.spell_caster.get_action_classification(STRIKE), &"")


func test_battle_catalog_allows_real_spectre_spell_to_trigger_one_cost_free_counter() -> void:
	_battle._configure_action_classifications(null, [_state])
	var counter := CATALOG.node_catalog()[&"achilles_aeacus_counter"] as SkillTreeNodeData
	_hero.mastery_nodes.assign([counter])
	_hero.mastery_runtime = MasteryReactiveRuntimeService.new()
	assert_true(_hero.mastery_runtime.configure_from_nodes(_hero.mastery_nodes).is_empty())
	var adapter := MasteryCombatAdapter.new()
	adapter.configure(_battle.grid, _battle.spell_caster, _battle.terrain_effects,
		_battle.pathfinder, [_hero, _spectre])
	_battle._mastery_adapter = adapter
	var guard_report := _battle.spell_caster.cast(_hero, GUARD, _hero.grid_pos)
	assert_false(guard_report.get("failed", false), str(guard_report))
	var guard_value := _hero.get_shield_value(&"achilles_bronze_guard")
	assert_gt(guard_value, 0)
	var hero_ap := _hero.current_ap
	var hero_uses := _hero.get_spell_uses(STRIKE)
	var hero_hp := _hero.current_hp
	var target_hp := _spectre.current_hp
	var expected_damage := int(round(float(STRIKE.get_scaled_damage(_hero)) * 0.7))
	var context := _battle.spell_caster.begin_cast(_spectre, CLEAVE, _hero.grid_pos)
	assert_false(context.failed)
	var report := _battle.spell_caster.resolve_cast(context)
	assert_false(report.get("failed", false), str(report))
	assert_eq(_hero.current_hp, hero_hp - maxi(0, CLEAVE.damage - guard_value))
	assert_eq(_spectre.current_hp, target_hp - expected_damage,
		"A canonical frontal cleave, including its absorbed portion, triggers the real counter")
	assert_eq(_spectre.current_ap, 0)
	assert_eq(_spectre.get_spell_uses(CLEAVE), 1)
	assert_eq(_hero.current_ap, hero_ap)
	assert_eq(_hero.get_spell_uses(STRIKE), hero_uses)
	assert_eq(_automatic.size(), 1)
	if _automatic.size() == 1:
		assert_eq(_automatic[0].spell_id, STRIKE.spell_id)
		assert_eq(_automatic[0].source_chain, [&"achilles_aeacus_counter.automatic_strike"])
		assert_eq(_automatic[0].target_hp_at_event, target_hp - expected_damage)
	_battle.spell_caster.resolve_cast(context)
	adapter.flush_automatic()
	assert_eq(_automatic.size(), 1, "Resolving or flushing again cannot replay the counter")
	assert_eq(_spectre.current_hp, target_hp - expected_damage)
	assert_eq(_hero.current_ap, hero_ap)
	assert_eq(_hero.get_spell_uses(STRIKE), hero_uses)


func _on_resolved_visual(actor: Unit, spell: Spell, _report: Dictionary, presentation: Dictionary) -> void:
	if actor == _hero and bool(presentation.get("automatic", false)):
		_automatic.append({"spell_id": spell.spell_id,
			"source_chain": presentation.get("source_chain", []), "target_hp_at_event": _spectre.current_hp})
