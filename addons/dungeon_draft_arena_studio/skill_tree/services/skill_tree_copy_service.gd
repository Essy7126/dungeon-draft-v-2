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


static func copy_discipline(source: DisciplineData) -> Dictionary:
	if source == null:
		return {}
	var source_to_work := {}
	var work_to_source := {}
	var work := _copy_discipline(source, source_to_work, work_to_source)
	return {
		"source": source,
		"work": work,
		"source_to_work": source_to_work,
		"work_to_source": work_to_source,
	}


static func resources_by_key(root: UnitData) -> Dictionary:
	var result := {}
	if root == null:
		return result
	result["unit"] = root
	if root.animation_set != null:
		result["animations"] = root.animation_set
	for spell_index in range(root.spells.size()):
		var spell := root.spells[spell_index]
		if spell == null:
			continue
		var spell_key := "spell:%s" % spell.get_effective_spell_id()
		result[spell_key] = spell
		for modifier_index in range(spell.modifiers.size()):
			var modifier := spell.modifiers[modifier_index]
			if modifier != null:
				result["%s/modifier:%d" % [spell_key, modifier_index]] = modifier
	var trees := root.get_skill_trees()
	for discipline_index in range(trees.size()):
		var discipline := trees[discipline_index]
		if discipline == null:
			continue
		var discipline_key := "discipline:%s" % discipline.discipline_id
		result[discipline_key] = discipline
		for rank_index in range(discipline.ranks.size()):
			var rank_data := discipline.ranks[rank_index]
			if rank_data == null:
				continue
			var rank_key := "%s/rank:%d" % [discipline_key, rank_data.rank]
			result[rank_key] = rank_data
			for node_index in range(rank_data.choices.size()):
				var node := rank_data.choices[node_index]
				if node == null:
					continue
				var node_key := "node:%s" % node.upgrade_id
				result[node_key] = node
				for modifier_index in range(node.spell_modifiers.size()):
					var modifier := node.spell_modifiers[modifier_index]
					if modifier != null:
						result["%s/modifier:%d" % [node_key, modifier_index]] = modifier
	return result


static func keys_by_resource(root: UnitData) -> Dictionary:
	var result := {}
	for key_value in resources_by_key(root):
		var key := str(key_value)
		var resource := resources_by_key(root)[key_value] as Resource
		if resource != null:
			result[resource] = key
	return result


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
	var spells: Array[Spell] = []
	for spell in source.spells:
		spells.append(
			_copy_spell(spell, source_to_work, work_to_source)
			if spell != null else null
		)
	work.spells = spells
	work.animation_set = _copy_animation_set(
		source.animation_set, source_to_work, work_to_source
	)
	return work


static func _copy_animation_set(
		source: CharacterAnimationSetData,
		source_to_work: Dictionary,
		work_to_source: Dictionary
	) -> CharacterAnimationSetData:
	if source == null:
		return null
	var existing := source_to_work.get(source) as CharacterAnimationSetData
	if existing != null:
		return existing
	var work := source.duplicate(true) as CharacterAnimationSetData
	_register(source, work, source_to_work, work_to_source)
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
	work.skill_tree = _copy_discipline(
		source.skill_tree, source_to_work, work_to_source
	) if source.skill_tree != null else null
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


## Copie de travail d'un Spell deja ecrit ailleurs dans le projet, pour qu'un
## second personnage puisse le referencer sans que le Studio edite la Resource
## d'origine. Le chemin est conserve par _register : sur le disque il n'existe
## toujours qu'un seul fichier, partage par tous ceux qui le referencent.
static func copy_spell(
		source: Spell,
		source_to_work: Dictionary,
		work_to_source: Dictionary
	) -> Spell:
	if source == null:
		return null
	return _copy_spell(source, source_to_work, work_to_source)
