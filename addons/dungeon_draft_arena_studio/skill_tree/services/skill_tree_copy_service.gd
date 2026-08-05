@tool
class_name SkillTreeCopyService
extends RefCounted


static func copy_unit(source: UnitData) -> Dictionary:
	if source == null:
		return {}
	var source_to_work := {}
	var work_to_source := {}
	var work := _copy_unit(source, source_to_work, work_to_source)
	return {
		"source": source,
		"work": work,
		"source_to_work": source_to_work,
		"work_to_source": work_to_source,
	}


static func _copy_unit(
		source: UnitData,
		source_to_work: Dictionary,
		work_to_source: Dictionary
	) -> UnitData:
	var existing := source_to_work.get(source) as UnitData
	if existing != null:
		return existing
	var work := source.duplicate(false) as UnitData
	_register(source, work, source_to_work, work_to_source)
	var disciplines: Array[DisciplineData] = []
	for discipline in source.disciplines:
		disciplines.append(
			_copy_discipline(discipline, source_to_work, work_to_source)
			if discipline != null else null
		)
	work.disciplines = disciplines
	var spells: Array[Spell] = []
	for spell in source.spells:
		spells.append(
			_copy_spell(spell, source_to_work, work_to_source)
			if spell != null else null
		)
	work.spells = spells
	return work


static func _copy_discipline(
		source: DisciplineData,
		source_to_work: Dictionary,
		work_to_source: Dictionary
	) -> DisciplineData:
	var existing := source_to_work.get(source) as DisciplineData
	if existing != null:
		return existing
	var work := source.duplicate(false) as DisciplineData
	_register(source, work, source_to_work, work_to_source)
	var ranks: Array[DisciplineRankData] = []
	for rank_data in source.ranks:
		ranks.append(
			_copy_rank(rank_data, source_to_work, work_to_source)
			if rank_data != null else null
		)
	work.ranks = ranks
	return work


static func _copy_rank(
		source: DisciplineRankData,
		source_to_work: Dictionary,
		work_to_source: Dictionary
	) -> DisciplineRankData:
	var existing := source_to_work.get(source) as DisciplineRankData
	if existing != null:
		return existing
	var work := source.duplicate(false) as DisciplineRankData
	_register(source, work, source_to_work, work_to_source)
	var choices: Array[SkillUpgradeData] = []
	for choice in source.choices:
		choices.append(
			_copy_upgrade(choice, source_to_work, work_to_source)
			if choice != null else null
		)
	work.choices = choices
	return work


static func _copy_upgrade(
		source: SkillUpgradeData,
		source_to_work: Dictionary,
		work_to_source: Dictionary
	) -> SkillUpgradeData:
	var existing := source_to_work.get(source) as SkillUpgradeData
	if existing != null:
		return existing
	var work := source.duplicate(false) as SkillUpgradeData
	_register(source, work, source_to_work, work_to_source)
	var modifiers: Array[SpellModifier] = []
	for modifier in source.spell_modifiers:
		modifiers.append(
			_copy_modifier(modifier, source_to_work, work_to_source)
			if modifier != null else null
		)
	work.spell_modifiers = modifiers
	if source is SkillTreeNodeData and work is SkillTreeNodeData:
		(work as SkillTreeNodeData).prerequisite_node_ids = (
			(source as SkillTreeNodeData).prerequisite_node_ids.duplicate()
		)
		(work as SkillTreeNodeData).excluded_node_ids = (
			(source as SkillTreeNodeData).excluded_node_ids.duplicate()
		)
	return work


static func _copy_spell(
		source: Spell,
		source_to_work: Dictionary,
		work_to_source: Dictionary
	) -> Spell:
	var existing := source_to_work.get(source) as Spell
	if existing != null:
		return existing
	var work := source.duplicate(false) as Spell
	_register(source, work, source_to_work, work_to_source)
	var modifiers: Array[SpellModifier] = []
	for modifier in source.modifiers:
		modifiers.append(
			_copy_modifier(modifier, source_to_work, work_to_source)
			if modifier != null else null
		)
	work.modifiers = modifiers
	work.summon_initial_cooldowns = source.summon_initial_cooldowns.duplicate(true)
	return work


static func _copy_modifier(
		source: SpellModifier,
		source_to_work: Dictionary,
		work_to_source: Dictionary
	) -> SpellModifier:
	var existing := source_to_work.get(source) as SpellModifier
	if existing != null:
		return existing
	var work := source.duplicate(true) as SpellModifier
	_register(source, work, source_to_work, work_to_source)
	return work


static func _register(
		source: Resource,
		work: Resource,
		source_to_work: Dictionary,
		work_to_source: Dictionary
	) -> void:
	source_to_work[source] = work
	work_to_source[work] = source
	if source.resource_path.is_empty() or source.is_built_in():
		return
	# set_path_cache n'enregistre pas la copie dans le cache global. Il indique
	# seulement au ResourceSaver que cette Resource doit rester externe.
	work.set_path_cache(source.resource_path)
