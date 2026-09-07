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


## Copie le profil et toutes ses dépendances éditoriales dans le même graphe de
## correspondance que l'adaptateur UnitData. Une doctrine référencée à la fois
## par un sort et par le MasteryCatalog conserve donc une identité unique dans
## la copie de travail.
static func copy_progression_profile(
		source: CharacterProgressionProfile,
		source_to_work: Dictionary = {},
		work_to_source: Dictionary = {}
	) -> CharacterProgressionProfile:
	if source == null:
		return null
	var existing := source_to_work.get(source) as CharacterProgressionProfile
	if existing != null:
		return existing
	var work := source.duplicate(false) as CharacterProgressionProfile
	_register(source, work, source_to_work, work_to_source)
	var spells: Array[Spell] = []
	for spell in source.spells:
		spells.append(
			_copy_spell(spell, source_to_work, work_to_source)
			if spell != null else null
		)
	work.spells = spells
	work.champion_progression_profile = _copy_champion_profile(
		source.champion_progression_profile, source_to_work, work_to_source
	)
	work.mastery_catalog = _copy_mastery_catalog(
		source.mastery_catalog, source_to_work, work_to_source
	)
	work.combat_action_classification_catalog = _copy_classification_catalog(
		source.combat_action_classification_catalog,
		source_to_work,
		work_to_source,
	)
	return work


static func resources_by_key(root: Resource) -> Dictionary:
	var result := {}
	if root == null:
		return result
	if root is CharacterProgressionProfile:
		var profile := root as CharacterProgressionProfile
		result["progression_profile"] = profile
		_append_spell_resources(result, profile.spells)
		if profile.champion_progression_profile != null:
			result["champion_profile"] = profile.champion_progression_profile
		if profile.mastery_catalog != null:
			_append_mastery_catalog_resources(result, profile.mastery_catalog)
		if profile.combat_action_classification_catalog != null:
			result["attack_classifications"] = (
				profile.combat_action_classification_catalog
			)
			for index in range(
				profile.combat_action_classification_catalog.entries.size()
			):
				var entry := profile.combat_action_classification_catalog.entries[index]
				if entry != null:
					result["attack_classification:%s" % entry.ability_id] = entry
		return result
	if not root is UnitData:
		result["resource"] = root
		return result
	var unit := root as UnitData
	result["unit"] = unit
	if unit.animation_set != null:
		result["animations"] = unit.animation_set
	_append_spell_resources(result, unit.spells)
	return result


static func _append_spell_resources(
		result: Dictionary,
		spells: Array[Spell]
	) -> void:
	for spell_index in range(spells.size()):
		var spell := spells[spell_index]
		if spell == null:
			continue
		var spell_key := "spell:%s" % spell.get_effective_spell_id()
		result[spell_key] = spell
		if spell.damage_scaling != null:
			result["%s/damage_scaling" % spell_key] = spell.damage_scaling
		if spell.shield_scaling != null:
			result["%s/shield_scaling" % spell_key] = spell.shield_scaling
		for modifier_index in range(spell.modifiers.size()):
			var modifier := spell.modifiers[modifier_index]
			if modifier != null:
				result["%s/modifier:%d" % [spell_key, modifier_index]] = modifier
	var trees: Array[DisciplineData] = []
	for spell in spells:
		if spell != null and spell.skill_tree != null and not trees.has(spell.skill_tree):
			trees.append(spell.skill_tree)
	for discipline_index in range(trees.size()):
		_append_discipline_resources(result, trees[discipline_index])


static func _append_mastery_catalog_resources(
		result: Dictionary,
		catalog: MasteryCatalogData
	) -> void:
	result["mastery_catalog:%s" % catalog.catalog_id] = catalog
	for doctrine in catalog.doctrines:
		_append_discipline_resources(result, doctrine)
	if catalog.advanced_catalog != null:
		result["advanced_mastery_catalog:%s" % catalog.advanced_catalog.catalog_id] = (
			catalog.advanced_catalog
		)
	for node in catalog.get_advanced_nodes():
		_append_node_resources(result, node, "advanced_node:%s" % node.upgrade_id)


static func _append_discipline_resources(
		result: Dictionary,
		discipline: DisciplineData
	) -> void:
	if discipline == null:
		return
	var discipline_key := "discipline:%s" % discipline.discipline_id
	result[discipline_key] = discipline
	for rank_data in discipline.ranks:
		if rank_data == null:
			continue
		var rank_key := "%s/rank:%d" % [discipline_key, rank_data.rank]
		result[rank_key] = rank_data
		for node in rank_data.choices:
			if node != null:
				_append_node_resources(result, node, "node:%s" % node.upgrade_id)


static func _append_node_resources(
		result: Dictionary,
		node: SkillUpgradeData,
		node_key: String
	) -> void:
	result[node_key] = node
	for modifier_index in range(node.spell_modifiers.size()):
		var modifier := node.spell_modifiers[modifier_index]
		if modifier != null:
			result["%s/modifier:%d" % [node_key, modifier_index]] = modifier
	if not node is SkillTreeNodeData:
		return
	var typed := node as SkillTreeNodeData
	for target_index in range(typed.targeted_spell_modifiers.size()):
		var targeted := typed.targeted_spell_modifiers[target_index]
		if targeted == null:
			continue
		var target_key := "%s/target:%s:%d" % [
			node_key, targeted.spell_id, target_index,
		]
		result[target_key] = targeted
		for modifier_index in range(targeted.modifiers.size()):
			var modifier := targeted.modifiers[modifier_index]
			if modifier != null:
				result["%s/modifier:%d" % [target_key, modifier_index]] = modifier
	for index in range(typed.reactive_effects.size()):
		if typed.reactive_effects[index] != null:
			result["%s/reactive:%d" % [node_key, index]] = typed.reactive_effects[index]
	for index in range(typed.doctrine_point_requirements.size()):
		if typed.doctrine_point_requirements[index] != null:
			result["%s/requirement:%d" % [node_key, index]] = (
				typed.doctrine_point_requirements[index]
			)


static func keys_by_resource(root: Resource) -> Dictionary:
	var result := {}
	var keyed := resources_by_key(root)
	for key_value in keyed:
		var key := str(key_value)
		var resource := keyed[key_value] as Resource
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
		var source_node := source as SkillTreeNodeData
		var work_node := work as SkillTreeNodeData
		work_node.prerequisite_node_ids = source_node.prerequisite_node_ids.duplicate()
		work_node.requires_any_node_ids = source_node.requires_any_node_ids.duplicate()
		work_node.excluded_node_ids = source_node.excluded_node_ids.duplicate()
		work_node.requires_completed_tree_ids = (
			source_node.requires_completed_tree_ids.duplicate()
		)
		work_node.affected_spell_ids = source_node.affected_spell_ids.duplicate()
		var targeted: Array[TargetedSpellModifierData] = []
		for wrapper in source_node.targeted_spell_modifiers:
			targeted.append(_copy_targeted_modifier(
				wrapper, source_to_work, work_to_source
			) if wrapper != null else null)
		work_node.targeted_spell_modifiers = targeted
		var reactive: Array[MasteryReactiveEffectData] = []
		for effect in source_node.reactive_effects:
			reactive.append(_copy_embedded_resource(
				effect, source_to_work, work_to_source
			) as MasteryReactiveEffectData if effect != null else null)
		work_node.reactive_effects = reactive
		var requirements: Array[DoctrinePointRequirementData] = []
		for requirement in source_node.doctrine_point_requirements:
			requirements.append(_copy_embedded_resource(
				requirement, source_to_work, work_to_source
			) as DoctrinePointRequirementData if requirement != null else null)
		work_node.doctrine_point_requirements = requirements
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
	work.damage_scaling = _copy_embedded_resource(
		source.damage_scaling, source_to_work, work_to_source
	) as SpellScalingData if source.damage_scaling != null else null
	work.shield_scaling = _copy_embedded_resource(
		source.shield_scaling, source_to_work, work_to_source
	) as SpellScalingData if source.shield_scaling != null else null
	return work


static func _copy_targeted_modifier(
		source: TargetedSpellModifierData,
		source_to_work: Dictionary,
		work_to_source: Dictionary
	) -> TargetedSpellModifierData:
	var existing := source_to_work.get(source) as TargetedSpellModifierData
	if existing != null:
		return existing
	var work := source.duplicate(false) as TargetedSpellModifierData
	_register(source, work, source_to_work, work_to_source)
	var modifiers: Array[MasterySpellModifierData] = []
	for modifier in source.modifiers:
		modifiers.append(_copy_modifier(
			modifier, source_to_work, work_to_source
		) as MasterySpellModifierData if modifier != null else null)
	work.modifiers = modifiers
	return work


static func _copy_champion_profile(
		source: ChampionProgressionProfile,
		source_to_work: Dictionary,
		work_to_source: Dictionary
	) -> ChampionProgressionProfile:
	return _copy_embedded_resource(
		source, source_to_work, work_to_source
	) as ChampionProgressionProfile if source != null else null


static func _copy_mastery_catalog(
		source: MasteryCatalogData,
		source_to_work: Dictionary,
		work_to_source: Dictionary
	) -> MasteryCatalogData:
	if source == null:
		return null
	var existing := source_to_work.get(source) as MasteryCatalogData
	if existing != null:
		return existing
	var work := source.duplicate(false) as MasteryCatalogData
	_register(source, work, source_to_work, work_to_source)
	var doctrines: Array[DisciplineData] = []
	for doctrine in source.doctrines:
		doctrines.append(_copy_discipline(
			doctrine, source_to_work, work_to_source
		) if doctrine != null else null)
	work.doctrines = doctrines
	work.advanced_catalog = _copy_advanced_mastery_catalog(
		source.advanced_catalog, source_to_work, work_to_source
	)
	var legacy_advanced: Array[SkillTreeNodeData] = []
	for node in source.advanced_nodes:
		legacy_advanced.append(_copy_upgrade(
			node, source_to_work, work_to_source
		) as SkillTreeNodeData if node != null else null)
	work.advanced_nodes = legacy_advanced
	return work


static func _copy_advanced_mastery_catalog(
		source: AdvancedMasteryCatalogData,
		source_to_work: Dictionary,
		work_to_source: Dictionary
	) -> AdvancedMasteryCatalogData:
	if source == null:
		return null
	var existing := source_to_work.get(source) as AdvancedMasteryCatalogData
	if existing != null:
		return existing
	var work := source.duplicate(false) as AdvancedMasteryCatalogData
	_register(source, work, source_to_work, work_to_source)
	var nodes: Array[SkillTreeNodeData] = []
	for node in source.nodes:
		nodes.append(_copy_upgrade(
			node, source_to_work, work_to_source
		) as SkillTreeNodeData if node != null else null)
	work.nodes = nodes
	return work


static func _copy_classification_catalog(
		source: CombatActionClassificationCatalogData,
		source_to_work: Dictionary,
		work_to_source: Dictionary
	) -> CombatActionClassificationCatalogData:
	if source == null:
		return null
	var existing := source_to_work.get(source) as CombatActionClassificationCatalogData
	if existing != null:
		return existing
	var work := source.duplicate(false) as CombatActionClassificationCatalogData
	_register(source, work, source_to_work, work_to_source)
	var entries: Array[CombatActionClassificationData] = []
	for entry in source.entries:
		entries.append(_copy_embedded_resource(
			entry, source_to_work, work_to_source
		) as CombatActionClassificationData if entry != null else null)
	work.entries = entries
	return work


static func _copy_embedded_resource(
		source: Resource,
		source_to_work: Dictionary,
		work_to_source: Dictionary
	) -> Resource:
	if source == null:
		return null
	var existing := source_to_work.get(source) as Resource
	if existing != null:
		return existing
	var work := source.duplicate(true)
	_register(source, work, source_to_work, work_to_source)
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
