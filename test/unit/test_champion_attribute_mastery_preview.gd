extends GutTest

const PROFILE: CharacterProgressionProfile = preload("res://data/runs/progression/odyssey/achilles_progression_profile.tres")
var _state: CharacterRunState

func after_each() -> void:
	if _state != null:
		_state.dispose()

func _champion(xp: int) -> CharacterRunState:
	var data := UnitData.new()
	data.unit_id = PROFILE.character_id
	data.max_hp = 110
	data.attack_power = 18
	data.spells = PROFILE.spells
	data.progression_profile = PROFILE
	_state = CharacterRunState.new()
	assert_true(_state.initialize(Unit.from_data(data), data))
	_state.award_encounter_xp(&"attribute_preview_fixture", xp, true)
	return _state

func _impact(attribute_id: StringName, spell_id: StringName) -> Dictionary:
	for impact in _state.preview_champion_attribute(attribute_id):
		if impact.spell_id == spell_id:
			return impact
	fail_test("Missing preview for %s / %s" % [attribute_id, spell_id])
	return {}

func test_power_preview_resolves_each_scourge_target_and_preserves_snapshot() -> void:
	var state := _champion(1700)
	var doctrine := PROFILE.mastery_catalog.doctrines[0]
	for path in SkillTreeResolver.champion_capstone_paths(doctrine, 10):
		if StringName(path.back()) != &"achilles_wrath_scourge_of_troy":
			continue
		for node_id in path:
			assert_true(state.purchase_mastery_node(StringName(node_id)).get("purchased", false))
		break
	state.unit.attack_power.add_modifier(100.0, Stat.ModType.FLAT, "equipment")
	assert_eq(state.unit.attack_power.get_int(), 200)
	var before := state.get_progression_snapshot()
	var impact := _impact(&"power", &"achilles_peleid_strike")
	assert_eq(impact.current_targets, PackedInt32Array([132, 77]))
	assert_eq(impact.next_targets, PackedInt32Array([139, 81]))
	assert_eq(int(impact.current), 132)
	assert_eq(int(impact.next), 139)
	assert_eq(state.get_progression_snapshot(), before)
	assert_true(state.spend_champion_attribute(&"power"))
	assert_eq(state.unit.attack_power.get_int(), 210)

func test_resolve_preview_uses_both_guard_rounding_stages_with_aeacus_summit() -> void:
	var state := _champion(2630)
	var doctrine := PROFILE.mastery_catalog.doctrines[2]
	var bought_capstone := false
	for node in SkillTreeResolver.champion_doctrine_nodes(doctrine):
		if node.node_type == SkillTreeNodeData.NodeType.CAPSTONE:
			if bought_capstone:
				continue
			bought_capstone = true
		assert_true(state.purchase_mastery_node(node.upgrade_id).get("purchased", false), str(node.upgrade_id))
	assert_true(state.purchase_mastery_node(&"achilles_summit_aeacus").get("purchased", false))
	state.unit.attack_power.add_modifier(-9.0, Stat.ModType.FLAT, "equipment")
	assert_eq(state.unit.attack_power.get_int(), 110)
	assert_true(state.spend_champion_attribute(&"resolve"))
	assert_true(state.spend_champion_attribute(&"resolve"))
	var before := state.get_progression_snapshot()
	var impact := _impact(&"resolve", &"achilles_bronze_guard")
	assert_eq(int(impact.current), 85)
	assert_eq(int(impact.next), 89)
	assert_eq(state.get_progression_snapshot(), before)
	assert_true(state.spend_champion_attribute(&"resolve"))
	var guard := PROFILE.spells[3]
	assert_eq(guard.get_scaled_shield(state.unit), 64)
	var static_profile := MasteryStaticModifierResolver.resolve_spell_profile(guard, state.get_selected_mastery_nodes())
	var shield_before_creation := MasteryStaticModifierResolver.resolve_shield_amount(guard.get_scaled_shield(state.unit), static_profile)
	state.unit.add_shield(shield_before_creation, state.unit, {"shield_source_id": &"preview_guard"})
	assert_eq(state.unit.get_shield_value(&"preview_guard"), 89)
