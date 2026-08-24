@tool
class_name SkillEffectEditorDescriptor
extends RefCounted

var descriptor_id: StringName = &""
var display_name := ""
var effect_type := -1
var modifier_class := ""
var fields: Array[Dictionary] = []
var unit := "sans unité"
var target := "selon le sort"
var condition := "toujours"
var duration := "instantané"
var frequency := "une fois par résolution"
var stacking := "cumul additif"


func sentence(modifier: SpellModifier = null) -> String:
	var amount_text := ""
	if modifier != null and _has_property(modifier, &"amount"):
		amount_text = " %s %s" % [modifier.get(&"amount"), unit]
	return "%s%s sur %s ; condition : %s ; durée : %s ; fréquence : %s ; empilement : %s." % [
		display_name, amount_text, target, condition, duration, frequency, stacking,
	]


## Phrase courte destinée aux endroits où la place manque : nœud du graphe,
## résumé d'une amélioration, tooltip. La version complète reste disponible
## dans « Comment fonctionne cet effet ? », qui détaille les six informations
## séparément plutôt que de les empiler dans une seule ligne illisible.
func short_sentence(modifier: SpellModifier = null) -> String:
	var amount_text := ""
	if modifier != null and _has_property(modifier, &"amount"):
		amount_text = " %s %s" % [modifier.get(&"amount"), unit]
	return "%s%s sur %s." % [display_name, amount_text, target]


func validate(modifier: SpellModifier) -> PackedStringArray:
	var errors := PackedStringArray()
	if modifier == null:
		errors.append("Le modificateur est absent.")
		return errors
	for field in fields:
		var property_name := StringName(field.get("property", &""))
		if property_name == &"" or not _has_property(modifier, property_name):
			errors.append("Champ de descripteur absent : %s." % property_name)
			continue
		if bool(field.get("required_positive", false)) \
				and float(modifier.get(property_name)) <= 0.0:
			errors.append("%s doit être strictement positif." % field.get("label", property_name))
	return errors


func to_dictionary() -> Dictionary:
	return {
		"descriptor_id": descriptor_id,
		"display_name": display_name,
		"effect_type": effect_type,
		"modifier_class": modifier_class,
		"fields": fields.duplicate(true),
		"unit": unit,
		"target": target,
		"condition": condition,
		"duration": duration,
		"frequency": frequency,
		"stacking": stacking,
	}


func _has_property(object: Object, property_name: StringName) -> bool:
	return object.get_property_list().any(func(info: Dictionary) -> bool:
		return StringName(info.get("name", &"")) == property_name
	)
