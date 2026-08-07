@tool
class_name ItemComparisonService
extends RefCounted


func compare(first: ItemDefinition, second: ItemDefinition) -> Dictionary:
	if first == null or second == null:
		return {"status": &"INCOMPARABLE", "reason": "Sélection incomplète."}
	if first.equipment_slot != second.equipment_slot \
			or first.category != second.category \
			or first.rarity != second.rarity \
			or _audience(first) != _audience(second):
		return {"status": &"INCOMPARABLE", "reason": "Emplacement, catégorie ou audience différents."}
	var first_vector := _effect_vector(first)
	var second_vector := _effect_vector(second)
	var conditional := _has_conditional_effect(first) or _has_conditional_effect(second)
	var first_downside := _has_downside(first)
	var second_downside := _has_downside(second)
	var keys: Array = first_vector.keys()
	for key in second_vector.keys():
		if key not in keys:
			keys.append(key)
	var first_ge := true
	var second_ge := true
	var first_strict := false
	var second_strict := false
	for key in keys:
		var first_value := float(first_vector.get(key, 0.0))
		var second_value := float(second_vector.get(key, 0.0))
		first_ge = first_ge and first_value >= second_value
		second_ge = second_ge and second_value >= first_value
		first_strict = first_strict or first_value > second_value
		second_strict = second_strict or second_value > first_value
	var status: StringName = &"PARTIAL"
	var dominant: StringName = &""
	if not conditional and not first_downside and first_ge and first_strict:
		status = &"STRICT_DOMINANCE"
		dominant = first.item_id
	elif not conditional and not second_downside and second_ge and second_strict:
		status = &"STRICT_DOMINANCE"
		dominant = second.item_id
	return {
		"status": status,
		"dominant_item_id": dominant,
		"first": first_vector,
		"second": second_vector,
		"conditional": conditional,
		"first_has_downside": first_downside,
		"second_has_downside": second_downside,
		"reason": "Comparaison conservatrice : conditions et contreparties interdisent la dominance." \
			if status == &"PARTIAL" else "Tous les effets comparables sont supérieurs ou égaux, sans condition ni contrepartie.",
	}


func _effect_vector(definition: ItemDefinition) -> Dictionary:
	var result := {}
	for modifier in definition.stat_modifiers:
		if modifier == null:
			continue
		var key := "stat:%s:%d" % [modifier.stat_id, modifier.modifier_type]
		result[key] = float(result.get(key, 0.0)) + modifier.value
	for modifier in definition.spell_modifiers:
		if modifier is ItemSpellModifierData:
			var item_modifier := modifier as ItemSpellModifierData
			result["spell:damage"] = float(result.get("spell:damage", 0.0)) + item_modifier.damage_percent
			result["spell:range"] = float(result.get("spell:range", 0.0)) + item_modifier.range_bonus
			result["spell:push"] = float(result.get("spell:push", 0.0)) + item_modifier.push_bonus
			result["spell:support"] = float(result.get("spell:support", 0.0)) + item_modifier.healing_and_shield_percent
	return result


func _has_conditional_effect(definition: ItemDefinition) -> bool:
	for modifier in definition.spell_modifiers:
		if modifier is ItemSpellModifierData:
			var item_modifier := modifier as ItemSpellModifierData
			if item_modifier.target_spell_id != &"" or not item_modifier.target_spell_name.is_empty() \
					or item_modifier.damage_type_filter >= 0 or item_modifier.require_elemental_damage \
					or item_modifier.target_hp_at_or_below >= 0.0:
				return true
	return false


func _has_downside(definition: ItemDefinition) -> bool:
	return definition.stat_modifiers.any(func(modifier):
		return modifier != null and modifier.value < 0.0
	)


func _audience(definition: ItemDefinition) -> String:
	var values := _strings(definition.compatible_character_ids)
	values.sort()
	return ",".join(values)


func _strings(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(str(value))
	return result
