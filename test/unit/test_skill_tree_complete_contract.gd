extends GutTest

const HERO_PATHS := [
	"res://data/units/alliés/elfe.tres",
	"res://data/units/alliés/mage.tres",
	"res://data/units/alliés/Guerrier.tres",
]
const LEGACY_WARRIOR_PATHS := [
	"res://data/spells/Guerrier/bourrade.tres",
	"res://data/spells/Guerrier/marque_de_guerre.tres",
	"res://data/spells/Guerrier/execution_de_guerre.tres",
	"res://data/spells/Guerrier/pietinement.tres",
]
const EXPECTED_TOPOLOGY := {1: 0, 2: 2, 3: 4, 4: 8, 5: 4}
const EXPECTED_THRESHOLDS := {1: 0, 2: 5, 3: 12, 4: 21, 5: 30}


func test_fixed_production_trio_owns_twelve_complete_trees() -> void:
	assert_eq(GameManager.ELF_DATA_PATH, HERO_PATHS[0])
	assert_eq(GameManager.MAGE_DATA_PATH, HERO_PATHS[1])
	assert_eq(GameManager.WARRIOR_DATA_PATH, HERO_PATHS[2])
	var character_ids: Array[StringName] = []
	var discipline_ids: Array[StringName] = []
	var spell_ids: Array[StringName] = []
	var node_ids: Array[StringName] = []
	var tree_count := 0
	var node_count := 0
	for path in HERO_PATHS:
		var hero := load(path) as UnitData
		assert_not_null(hero, path)
		character_ids.append(hero.unit_id)
		assert_eq(hero.spells.size(), 4, path)
		assert_eq(hero.disciplines.size(), 4, path)
		var hero_discipline_ids: Array[StringName] = []
		for spell in hero.spells:
			assert_not_null(spell)
			assert_false(spell_ids.has(spell.spell_id), str(spell.spell_id))
			spell_ids.append(spell.spell_id)
			assert_not_null(spell.skill_tree)
			hero_discipline_ids.append(spell.skill_tree.discipline_id)
		assert_eq(_unique(hero_discipline_ids).size(), 4, path)
		for discipline in hero.disciplines:
			tree_count += 1
			node_count += 1 # racine R1, représentée par le sort de base
			assert_not_null(discipline)
			assert_false(discipline_ids.has(discipline.discipline_id), str(discipline.discipline_id))
			discipline_ids.append(discipline.discipline_id)
			assert_true(hero_discipline_ids.has(discipline.discipline_id))
			assert_eq(SkillTreeResolver.validate_discipline(discipline), PackedStringArray(), str(discipline.discipline_id))
			assert_eq(discipline.ranks.size(), 5, str(discipline.discipline_id))
			var expected_prefix := (
				"elf_%s_" % discipline.discipline_id
				if hero.unit_id == &"elf"
				else "%s_" % discipline.discipline_id
			)
			for rank_data in discipline.ranks:
				assert_eq(rank_data.required_total_xp, EXPECTED_THRESHOLDS[rank_data.rank])
				assert_eq(rank_data.choices.size(), EXPECTED_TOPOLOGY[rank_data.rank])
				for node in rank_data.choices:
					node_count += 1
					assert_true(str(node.upgrade_id).begins_with(expected_prefix), str(node.upgrade_id))
					assert_false(node_ids.has(node.upgrade_id), str(node.upgrade_id))
					node_ids.append(node.upgrade_id)
					assert_false(node.display_name.strip_edges().is_empty())
					assert_false(node.description.strip_edges().is_empty())
					assert_eq(node.discipline_id, discipline.discipline_id)
					assert_eq(node.target_spell_id, &"", str(node.upgrade_id))
					assert_true(node.spell_modifiers.all(
						func(modifier): return modifier.target_spell_id == &""
					))
					assert_false(node.spell_modifiers.is_empty(), str(node.upgrade_id))
	assert_eq(character_ids, [&"elf", &"mage", &"warrior"])
	assert_eq(tree_count, 12)
	assert_eq(node_count, 228)
	assert_eq(node_ids.size(), 216)


func test_every_tree_exposes_exactly_sixteen_valid_final_configurations() -> void:
	for path in HERO_PATHS:
		var hero := load(path) as UnitData
		for discipline in hero.disciplines:
			var configurations := _final_configurations(discipline)
			assert_eq(configurations.size(), 16, str(discipline.discipline_id))
			for configuration in configurations:
				var progress := DisciplineProgressState.new()
				assert_true(progress.initialize(discipline))
				progress.add_xp(30)
				assert_eq(progress.rank, 5)
				assert_eq(progress.get_pending_rank_choices(), [2, 3, 4, 5])
				for rank_index in range(4):
					assert_not_null(progress.select_upgrade(configuration[rank_index], rank_index + 2), "%s: %s" % [discipline.discipline_id, configuration])
				assert_eq(progress.get_selected_upgrade_ids(), configuration)
				assert_eq(progress.get_selected_upgrades().size(), 4)
				assert_true(progress.get_selected_upgrades().all(
					func(node): return not node.spell_modifiers.is_empty()
				))
				var snapshot := progress.get_snapshot()
				var restored := DisciplineProgressState.new()
				assert_true(restored.initialize(discipline))
				assert_true(restored.restore_snapshot(snapshot))
				assert_eq(restored.get_snapshot(), snapshot)


func test_higher_rank_is_rejected_until_earlier_pending_rank_is_resolved() -> void:
	for path in HERO_PATHS:
		var hero := load(path) as UnitData
		for discipline in hero.disciplines:
			var progress := DisciplineProgressState.new()
			progress.initialize(discipline)
			progress.add_xp(30)
			var rank_three := discipline.ranks[2].choices[0] as SkillUpgradeData
			assert_null(progress.select_upgrade(rank_three.upgrade_id, 3), str(discipline.discipline_id))


func test_character_run_state_reconstructs_choices_and_modifiers() -> void:
	for path in HERO_PATHS:
		var hero := load(path) as UnitData
		var original := CharacterRunState.new()
		assert_true(original.initialize(Unit.from_data(hero), hero))
		for discipline in hero.disciplines:
			var configuration := _final_configurations(discipline)[0] as Array
			original.add_discipline_xp(discipline.discipline_id, 30)
			for rank_index in range(4):
				assert_true(original.select_upgrade(
					discipline.discipline_id,
					rank_index + 2,
					configuration[rank_index]
				))
		var snapshot := original.get_progression_snapshot()
		var modifier_count := original.get_active_progression_spell_modifiers().size()
		var restored := CharacterRunState.new()
		assert_true(restored.initialize(Unit.from_data(hero), hero))
		assert_true(restored.restore_progression_snapshot(snapshot))
		assert_eq(restored.get_progression_snapshot(), snapshot)
		assert_eq(restored.get_active_progression_spell_modifiers().size(), modifier_count)
		assert_eq(restored.unit.get_progression_spell_modifiers().size(), modifier_count)


func test_active_tree_resources_exclude_removed_systems_and_legacy_warrior_kit() -> void:
	var forbidden := ["ferveur", "éveil", "eveil", "empreinte", "signature", "energy"]
	for path in HERO_PATHS:
		var hero := load(path) as UnitData
		var active_paths := [path]
		for spell in hero.spells:
			active_paths.append(spell.resource_path)
		for discipline in hero.disciplines:
			active_paths.append(discipline.resource_path)
		for active_path in active_paths:
			var text := FileAccess.get_file_as_string(active_path).to_lower()
			for symbol in forbidden:
				assert_false(text.contains(symbol), "%s: %s" % [active_path, symbol])
	assert_false(FileAccess.file_exists("res://data/units/alliés/Gardien.tres"))
	for legacy_path in LEGACY_WARRIOR_PATHS:
		assert_false(FileAccess.file_exists(legacy_path), legacy_path)


func _final_configurations(discipline: DisciplineData) -> Array[Array]:
	var result: Array[Array] = []
	var r2 := discipline.ranks[1].choices
	var r3 := discipline.ranks[2].choices
	var r4 := discipline.ranks[3].choices
	var r5 := discipline.ranks[4].choices
	for branch in r2:
		for third in r3.filter(func(node): return node.prerequisite_node_ids.has(branch.upgrade_id)):
			for fourth in r4.filter(func(node): return node.prerequisite_node_ids.has(third.upgrade_id)):
				for capstone in r5.filter(func(node): return node.prerequisite_node_ids.has(branch.upgrade_id)):
					result.append([
						branch.upgrade_id,
						third.upgrade_id,
						fourth.upgrade_id,
						capstone.upgrade_id,
					])
	return result


func _unique(values: Array[StringName]) -> Array[StringName]:
	var result: Array[StringName] = []
	for value in values:
		if not result.has(value):
			result.append(value)
	return result
