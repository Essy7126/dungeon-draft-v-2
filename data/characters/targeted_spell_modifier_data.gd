@tool
class_name TargetedSpellModifierData
extends Resource

## Un wrapper explicite remplace l'ancien couple implicite
## target_spell_id/spell_modifiers et permet a un node de viser plusieurs sorts.
@export var spell_id: StringName = &""
@export var modifiers: Array[MasterySpellModifierData] = []


func get_modifiers_for_spell() -> Array[SpellModifier]:
	var result: Array[SpellModifier] = []
	for modifier in modifiers:
		if modifier == null:
			continue
		# Les sous-resources d'une doctrine ne sont pas partagees entre sorts.
		# Poser le filtre ici garde le wrapper comme autorite de ciblage.
		modifier.target_spell_id = spell_id
		result.append(modifier)
	return result


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if spell_id == &"":
		errors.append("TARGETED_SPELL_ID_EMPTY")
	if modifiers.is_empty():
		errors.append("TARGETED_MODIFIERS_EMPTY")
	for modifier in modifiers:
		if modifier == null:
			errors.append("TARGETED_MODIFIER_NULL")
		elif not modifier.is_structurally_valid():
			errors.append("TARGETED_MODIFIER_INVALID")
	return errors
