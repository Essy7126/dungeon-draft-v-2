extends GutTest

const MASTERY_CATALOG: MasteryCatalogData = preload(
	"res://data/characters/achilles/doctrines/achilles_mastery_catalog.tres"
)
const STRIKE: Spell = preload("res://data/spells/achilles/peleid_strike.tres")
const DASH: Spell = preload("res://data/spells/achilles/fulminant_dash.tres")
const SHOT: Spell = preload("res://data/spells/achilles/pelion_shot.tres")
const GUARD: Spell = preload("res://data/spells/achilles/bronze_guard.tres")
const LEGACY_BREAKER: DisciplineData = preload(
	"res://data/characters/warrior/disciplines/breaker.tres"
)
const ATTACK_CLASSIFICATIONS: CombatActionClassificationCatalogData = preload(
	"res://data/characters/achilles/attack_classifications.tres"
)


func test_mastery_catalog_is_typed_complete_and_has_exact_topology() -> void:
	var errors: PackedStringArray = MASTERY_CATALOG.validation_errors()
	assert_true(errors.is_empty(), "\n".join(errors))
	assert_eq(MASTERY_CATALOG.doctrines.size(), 3)
	assert_eq(MASTERY_CATALOG.get_advanced_nodes().size(), 9)
	var expected_ids: Array[StringName] = [
		&"achilles_wrath_of_peleus",
		&"achilles_lesson_of_chiron",
		&"achilles_aegis_of_aeacus",
	]
	for doctrine: DisciplineData in MASTERY_CATALOG.doctrines:
		assert_true(expected_ids.has(doctrine.discipline_id))
		assert_eq(
			doctrine.progression_mode,
			DisciplineData.ProgressionMode.MASTERY_POINTS,
		)
		var nodes: Array[SkillTreeNodeData] = (
			SkillTreeResolver.champion_doctrine_nodes(doctrine)
		)
		assert_eq(nodes.size(), 9)
		var tier_counts: Dictionary = {}
		var capstone_levels: Array[int] = []
		for node: SkillTreeNodeData in nodes:
			tier_counts[node.tier] = int(tier_counts.get(node.tier, 0)) + 1
			assert_eq(node.mastery_cost, 2 if node.node_type == SkillTreeNodeData.NodeType.CAPSTONE else 1)
			assert_false(node.effect_axis.is_empty())
			if node.node_type == SkillTreeNodeData.NodeType.CAPSTONE:
				capstone_levels.append(node.required_champion_level)
		assert_eq(tier_counts, {1: 1, 2: 2, 3: 2, 4: 2, 5: 2})
		capstone_levels.sort()
		assert_eq(capstone_levels, [10, 13])
		assert_eq(SkillTreeResolver.minimal_champion_capstone_cost(doctrine), 6)
		assert_eq(SkillTreeResolver.full_champion_doctrine_cost(doctrine), 9)


func test_four_canonical_spells_have_exact_doctrine_ownership() -> void:
	assert_same(STRIKE.skill_tree, MASTERY_CATALOG.doctrines[0])
	assert_same(SHOT.skill_tree, MASTERY_CATALOG.doctrines[1])
	assert_same(GUARD.skill_tree, MASTERY_CATALOG.doctrines[2])
	assert_null(DASH.skill_tree)
	var dash_targets: int = 0
	for node_value: Variant in MASTERY_CATALOG.node_catalog().values():
		var node: SkillTreeNodeData = node_value as SkillTreeNodeData
		if node != null and node.affected_spell_ids.has(DASH.get_effective_spell_id()):
			dash_targets += 1
	assert_gt(dash_targets, 0, "Percée reste ciblable sans posséder de doctrine")


func test_every_authored_capstone_path_is_purchaseable_in_shared_resolver() -> void:
	var advanced: Array[SkillTreeNodeData] = MASTERY_CATALOG.get_advanced_nodes()
	for doctrine: DisciplineData in MASTERY_CATALOG.doctrines:
		var paths: Array = SkillTreeResolver.champion_capstone_paths(doctrine, 13)
		assert_gt(paths.size(), 0, str(doctrine.discipline_id))
		for path_value: Variant in paths:
			var selected: Array[StringName] = []
			var path: Array = path_value as Array
			for node_id_value: Variant in path:
				var node_id := StringName(node_id_value)
				var node: SkillTreeNodeData = MASTERY_CATALOG.node_catalog().get(node_id) as SkillTreeNodeData
				var decision: Dictionary = SkillTreeResolver.evaluate_mastery_purchase(
					node,
					MASTERY_CATALOG.doctrines,
					advanced,
					13,
					99,
					selected,
				)
				assert_true(
					bool(decision.get("allowed", false)),
					"%s / %s: %s" % [doctrine.discipline_id, node_id, decision],
				)
				selected.append(node_id)


func test_nonexclusive_siblings_can_both_be_bought_and_capstones_cannot() -> void:
	var doctrine: DisciplineData = MASTERY_CATALOG.doctrines[0]
	var catalog: Dictionary = MASTERY_CATALOG.node_catalog()
	var selected: Array[StringName] = [&"achilles_wrath_focused_fury"]
	var opening: SkillTreeNodeData = catalog[&"achilles_wrath_opening_slash"]
	var momentum: SkillTreeNodeData = catalog[&"achilles_wrath_murderous_momentum"]
	var first: Dictionary = SkillTreeResolver.evaluate_mastery_purchase(
		opening, MASTERY_CATALOG.doctrines, MASTERY_CATALOG.get_advanced_nodes(),
		13, 10, selected,
	)
	assert_true(first.allowed)
	selected.append(opening.upgrade_id)
	var sibling: Dictionary = SkillTreeResolver.evaluate_mastery_purchase(
		momentum, MASTERY_CATALOG.doctrines, MASTERY_CATALOG.get_advanced_nodes(),
		13, 10, selected,
	)
	assert_true(sibling.allowed)
	assert_eq(opening.exclusive_group, &"")
	assert_eq(momentum.exclusive_group, &"")

	var full_route: Array[StringName] = [
		&"achilles_wrath_focused_fury",
		&"achilles_wrath_opening_slash",
		&"achilles_wrath_murderous_momentum",
		&"achilles_wrath_execution",
		&"achilles_wrath_blood_for_blood",
		&"achilles_wrath_victorious_step",
		&"achilles_wrath_break_formation",
		&"achilles_wrath_scourge_of_troy",
	]
	var other_capstone: SkillTreeNodeData = catalog[&"achilles_wrath_irrepressible_wrath"]
	var rejected: Dictionary = SkillTreeResolver.evaluate_mastery_purchase(
		other_capstone, [doctrine], [], 13, 10, full_route,
	)
	assert_false(rejected.allowed)
	assert_true(rejected.reason_id in ["EXCLUDED_BY_SELECTION", "EXCLUSIVE_GROUP"])


func test_extra_or_merchant_mastery_points_cannot_bypass_level_gates() -> void:
	var advanced: Array[SkillTreeNodeData] = MASTERY_CATALOG.get_advanced_nodes()
	for doctrine: DisciplineData in MASTERY_CATALOG.doctrines:
		for node: SkillTreeNodeData in SkillTreeResolver.champion_doctrine_nodes(doctrine):
			if node.node_type != SkillTreeNodeData.NodeType.CAPSTONE:
				continue
			var decision: Dictionary = SkillTreeResolver.evaluate_mastery_purchase(
				node,
				MASTERY_CATALOG.doctrines,
				advanced,
				node.required_champion_level - 1,
				99,
				[],
			)
			assert_false(decision.allowed)
			assert_eq(decision.reason_id, "LEVEL_GATE")
	for node: SkillTreeNodeData in advanced:
		var decision: Dictionary = SkillTreeResolver.evaluate_mastery_purchase(
			node,
			MASTERY_CATALOG.doctrines,
			advanced,
			node.required_champion_level - 1,
			99,
			[],
		)
		assert_false(decision.allowed)
		assert_eq(decision.reason_id, "LEVEL_GATE")


func test_every_sibling_is_reachable_and_has_a_distinct_effect_axis() -> void:
	for doctrine: DisciplineData in MASTERY_CATALOG.doctrines:
		var paths: Array = SkillTreeResolver.champion_capstone_paths(doctrine, 13)
		var nodes: Array[SkillTreeNodeData] = SkillTreeResolver.champion_doctrine_nodes(
			doctrine,
		)
		for tier: int in [2, 3, 4, 5]:
			var siblings: Array[SkillTreeNodeData] = []
			for node: SkillTreeNodeData in nodes:
				if node.tier == tier:
					siblings.append(node)
			assert_eq(siblings.size(), 2)
			assert_ne(siblings[0].effect_axis, siblings[1].effect_axis)
			for sibling: SkillTreeNodeData in siblings:
				var reachable := false
				for path_value: Variant in paths:
					if (path_value as Array).has(sibling.upgrade_id):
						reachable = true
						break
				assert_true(reachable, "%s est dominé ou inaccessible" % sibling.upgrade_id)


func test_advanced_nodes_are_separate_typed_resources_with_exact_gates() -> void:
	var type_counts: Dictionary = {}
	for node: SkillTreeNodeData in MASTERY_CATALOG.get_advanced_nodes():
		type_counts[node.node_type] = int(type_counts.get(node.node_type, 0)) + 1
		match node.node_type:
			SkillTreeNodeData.NodeType.SPECIALIST_SUMMIT:
				assert_eq(node.required_champion_level, 13)
				assert_eq(node.mastery_cost, 3)
			SkillTreeNodeData.NodeType.MYTHIC_JUNCTION, SkillTreeNodeData.NodeType.APOTHEOSIS:
				assert_eq(node.required_champion_level, 14)
			_:
				fail_test("Type avancé inattendu: %s" % node.upgrade_id)
	assert_eq(type_counts.get(SkillTreeNodeData.NodeType.SPECIALIST_SUMMIT, 0), 3)
	assert_eq(type_counts.get(SkillTreeNodeData.NodeType.MYTHIC_JUNCTION, 0), 3)
	assert_eq(type_counts.get(SkillTreeNodeData.NodeType.APOTHEOSIS, 0), 3)


func test_legacy_rank_xp_api_and_default_are_unchanged() -> void:
	var fresh := DisciplineData.new()
	assert_eq(fresh.progression_mode, DisciplineData.ProgressionMode.LEGACY_RANK_XP)
	assert_eq(
		LEGACY_BREAKER.progression_mode,
		DisciplineData.ProgressionMode.LEGACY_RANK_XP,
	)
	var available: Array[SkillUpgradeData] = SkillTreeResolver.get_available_nodes(
		LEGACY_BREAKER, 2, 2, [2], [],
	)
	assert_eq(available.size(), 2)
	var decision: Dictionary = SkillTreeResolver.evaluate_selection(
		LEGACY_BREAKER,
		2,
		&"warrior_breaker_coup_brutal",
		2,
		[2],
		[],
	)
	assert_true(decision.allowed)


func test_static_shape_and_data_driven_attack_classification() -> void:
	var catalog: Dictionary = MASTERY_CATALOG.node_catalog()
	var scourge: SkillTreeNodeData = catalog[&"achilles_wrath_scourge_of_troy"]
	var profile: Dictionary = MasteryStaticModifierResolver.resolve_spell_profile(
		STRIKE, [scourge],
	)
	assert_eq(profile.target_shape, &"LINE")
	assert_eq(profile.maximum_targets, 2)
	var multipliers: PackedFloat32Array = profile.target_multipliers
	assert_eq(multipliers.size(), 2)
	assert_almost_eq(multipliers[0], 1.2, 0.0001)
	assert_almost_eq(multipliers[1], 0.7, 0.0001)

	var registry := CombatActionClassificationRegistry.new()
	assert_true(registry.initialize(ATTACK_CLASSIFICATIONS))
	assert_eq(registry.classification_for_spell(STRIKE), &"MELEE")
	assert_eq(registry.classification_for_spell(SHOT), &"PROJECTILE")
	assert_eq(registry.classification_for_spell(GUARD), &"SELF")
	assert_eq(registry.classification_for_spell(DASH), &"MOVEMENT")
	assert_eq(registry.classification_for_ability(&"unknown"), &"")
