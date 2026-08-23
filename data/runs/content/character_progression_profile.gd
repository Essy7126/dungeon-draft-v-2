@tool
class_name CharacterProgressionProfile
extends Resource

@export var character_id: StringName = &""
@export_range(1, 12, 1) var active_spell_slots: int = 4
@export var spells: Array[Spell] = []
var _legacy_disciplines: Array[DisciplineData] = []
var disciplines: Array[DisciplineData]:
	get:
		var derived := get_skill_trees()
		return derived if not derived.is_empty() else _legacy_disciplines.duplicate()
	set(value):
		_legacy_disciplines.assign(value)


func get_skill_trees() -> Array[DisciplineData]:
	var trees: Array[DisciplineData] = []
	for spell in spells:
		if spell != null and spell.skill_tree != null \
				and not trees.has(spell.skill_tree):
			trees.append(spell.skill_tree)
	return trees


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if str(character_id).strip_edges().is_empty():
		errors.append("Le character_id de progression est absent.")
	if active_spell_slots < 1 or active_spell_slots > 12:
		errors.append("Le nombre de slots actifs doit etre compris entre 1 et 12.")
	if spells.is_empty():
		errors.append("La progression %s ne contient aucun sort." % character_id)
	for index in range(spells.size()):
		if spells[index] == null:
			errors.append("Le sort %d de %s est absent." % [index, character_id])
	var spell_ids := {}
	var tree_ids := {}
	var tree_owners := {}
	for spell in spells:
		if spell == null:
			continue
		var spell_id := spell.get_effective_spell_id()
		if spell_id == &"spell:unassigned":
			errors.append("Un sort de %s ne possede aucun spell_id stable." % character_id)
		elif spell_ids.has(spell_id):
			errors.append("Le spell_id %s est duplique dans %s." % [spell_id, character_id])
		spell_ids[spell_id] = true
		if spell.skill_tree == null:
			continue
		var tree_id := spell.skill_tree.discipline_id
		if tree_id == &"":
			errors.append("L'arbre du sort %s ne possede aucun identifiant stable." % spell_id)
		elif tree_ids.has(tree_id) and tree_owners.get(tree_id) != spell_id:
			errors.append("L'arbre %s est associe a plusieurs sorts distincts." % tree_id)
		tree_ids[tree_id] = true
		tree_owners[tree_id] = spell_id
	return errors


func is_valid() -> bool:
	return validation_errors().is_empty()
