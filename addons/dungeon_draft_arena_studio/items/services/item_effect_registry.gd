@tool
class_name ItemEffectRegistry
extends RefCounted

const STAT_LABELS := {
	&"max_hp": "PV maximum",
	&"initiative": "Initiative",
	&"max_ap": "PA maximum",
	&"max_mp": "PM maximum",
	&"attack_power": "Attaque",
	&"armure": "Armure",
	&"resist_magique": "Résistance magique",
	&"esquive": "Esquive",
	&"crit_chance": "Chance critique",
	&"crit_multi": "Multiplicateur critique",
	&"force": "Force",
	&"resistance_ice": "Résistance glace",
}

var _descriptors := {}


func _init() -> void:
	_register_defaults()


func descriptors() -> Array[ItemEffectDescriptor]:
	var result: Array[ItemEffectDescriptor] = []
	var ids: Array = _descriptors.keys()
	ids.sort_custom(func(a, b): return str(a) < str(b))
	for effect_id in ids:
		result.append(_descriptors[effect_id] as ItemEffectDescriptor)
	return result


func get_descriptor(effect_id: StringName) -> ItemEffectDescriptor:
	return _descriptors.get(effect_id) as ItemEffectDescriptor


func descriptor_for_resource(resource: Resource) -> ItemEffectDescriptor:
	if resource is ItemStatModifierData:
		var stat := resource as ItemStatModifierData
		return get_descriptor(
			&"stat.percent" if stat.modifier_type == ItemStatModifierData.ModifierType.PERCENT \
			else &"stat.flat"
		)
	if resource is ItemSpellModifierData:
		return get_descriptor(&"spell.item_modifier")
	return null


func descriptor_for_use_effect(use_effect: int) -> ItemEffectDescriptor:
	match use_effect:
		ItemDefinition.UseEffect.HEAL_FLAT:
			return get_descriptor(&"use.heal_flat")
		ItemDefinition.UseEffect.RESTORE_AP_FLAT:
			return get_descriptor(&"use.restore_ap_flat")
		_:
			return null


func create_effect(effect_id: StringName) -> Resource:
	match effect_id:
		&"stat.flat", &"stat.percent":
			var stat := ItemStatModifierData.new()
			stat.stat_id = &"max_hp"
			stat.value = 1.0
			stat.modifier_type = ItemStatModifierData.ModifierType.PERCENT \
				if effect_id == &"stat.percent" else ItemStatModifierData.ModifierType.FLAT
			return stat
		&"spell.item_modifier":
			var spell := ItemSpellModifierData.new()
			spell.modifier_name = "Effet d’objet"
			spell.damage_percent = 0.1
			return spell
		_:
			return null


func coverage_report(definitions: Array[ItemDefinition]) -> Dictionary:
	var reachable := {}
	var unsupported: Array[Dictionary] = []
	for definition in definitions:
		if definition == null:
			continue
		for index in range(definition.stat_modifiers.size()):
			var resource := definition.stat_modifiers[index]
			_register_reachable(resource, definition, "stat_modifiers[%d]" % index, reachable, unsupported)
		for index in range(definition.spell_modifiers.size()):
			var resource := definition.spell_modifiers[index]
			_register_reachable(resource, definition, "spell_modifiers[%d]" % index, reachable, unsupported)
		if definition.use_effect != ItemDefinition.UseEffect.NONE:
			var use_descriptor := descriptor_for_use_effect(definition.use_effect)
			var key := "ItemDefinition.UseEffect.%d" % definition.use_effect
			reachable[key] = str(use_descriptor.effect_id) if use_descriptor != null else ""
			if use_descriptor == null:
				unsupported.append({"class": key, "item_id": str(definition.item_id)})
	return {
		"valid": unsupported.is_empty(),
		"reachable_classes": reachable,
		"unsupported": unsupported,
		"descriptor_count": _descriptors.size(),
	}


func summarize(resource: Resource) -> Dictionary:
	var descriptor := descriptor_for_resource(resource)
	if descriptor == null:
		return {
			"supported": false,
			"player": "%s — Effet non pris en charge par le Studio" % _runtime_class(resource),
			"technical": _runtime_class(resource),
		}
	if resource is ItemStatModifierData:
		var stat := resource as ItemStatModifierData
		var suffix := " %" if stat.modifier_type == ItemStatModifierData.ModifierType.PERCENT else ""
		var displayed_value := stat.value * 100.0 \
			if stat.modifier_type == ItemStatModifierData.ModifierType.PERCENT else stat.value
		return {
			"supported": true,
			"player": "%+.2f%s %s" % [displayed_value, suffix, STAT_LABELS.get(stat.stat_id, str(stat.stat_id))],
			"technical": "%s value=%s type=%d" % [stat.stat_id, stat.value, stat.modifier_type],
		}
	var spell := resource as ItemSpellModifierData
	var parts: Array[String] = []
	if spell.damage_percent > 0.0:
		parts.append("%+.0f %% dégâts" % (spell.damage_percent * 100.0))
	if spell.range_bonus > 0:
		parts.append("+%d portée" % spell.range_bonus)
	if spell.push_bonus > 0:
		parts.append("+%d poussée" % spell.push_bonus)
	if spell.healing_and_shield_percent > 0.0:
		parts.append("%+.0f %% soin/bouclier" % (spell.healing_and_shield_percent * 100.0))
	if spell.target_hp_at_or_below >= 0.0:
		parts.append("cible ≤ %.0f %% PV" % (spell.target_hp_at_or_below * 100.0))
	return {
		"supported": true,
		"player": ", ".join(parts) if not parts.is_empty() else descriptor.display_name,
		"technical": JSON.stringify(ItemFingerprintService._resource_snapshot(spell)),
	}


func _register_reachable(
		resource: Resource,
		definition: ItemDefinition,
		property_path: String,
		reachable: Dictionary,
		unsupported: Array[Dictionary]
	) -> void:
	var runtime_class_name := _runtime_class(resource)
	var descriptor := descriptor_for_resource(resource)
	reachable[runtime_class_name] = str(descriptor.effect_id) if descriptor != null else ""
	if descriptor == null:
		unsupported.append({
			"class": runtime_class_name,
			"item_id": str(definition.item_id),
			"property_path": property_path,
		})


func _runtime_class(resource: Resource) -> String:
	if resource == null:
		return "<null>"
	var script := resource.get_script() as Script
	return script.resource_path.get_file().get_basename() \
		if script != null and not script.resource_path.is_empty() else resource.get_class()


func _register_defaults() -> void:
	_register({
		"effect_id": &"stat.flat",
		"runtime_class": "ItemStatModifierData",
		"display_name": "Modification de statistique fixe",
		"description": "Ajoute ou retire une valeur fixe à une statistique du héros.",
		"group_name": "Statistiques", "unit": "points", "target": "Héros équipé",
		"properties": [
			_prop("stat_id", "Statistique", "enum", &"max_hp", 0.0, 0.0, 0.0, STAT_LABELS),
			_prop("value", "Valeur", "number", 1.0, -999.0, 999.0, 1.0),
		],
	})
	_register({
		"effect_id": &"stat.percent",
		"runtime_class": "ItemStatModifierData",
		"display_name": "Modification de statistique en pourcentage",
		"description": "Multiplie une statistique du héros équipé.",
		"group_name": "Statistiques", "unit": "%", "target": "Héros équipé",
		"properties": [
			_prop("stat_id", "Statistique", "enum", &"max_hp", 0.0, 0.0, 0.0, STAT_LABELS),
			_prop("value", "Valeur", "percent", 0.1, -1.0, 5.0, 0.01),
		],
	})
	_register({
		"effect_id": &"spell.item_modifier",
		"runtime_class": "ItemSpellModifierData",
		"display_name": "Modification de sorts",
		"description": "Applique les filtres et bonus réellement lus par le pipeline SpellCaster.",
		"group_name": "Sorts", "unit": "mixte", "target": "Sorts du héros équipé",
		"condition": "Filtres de sort, élément, type et seuil de PV",
		"properties": [
			_prop("target_spell_id", "ID du sort ciblé", "text", &""),
			_prop("damage_percent", "Bonus de dégâts", "percent", 0.0, 0.0, 5.0, 0.01),
			_prop("damage_type_filter", "Type de dégâts", "enum", -1, -1.0, 1.0, 1.0, { -1: "Tous", 0: "Physique", 1: "Magique" }),
			_prop("require_elemental_damage", "Dégâts élémentaires requis", "bool", false),
			_prop("target_hp_at_or_below", "Seuil de PV cible", "percent", -1.0, -1.0, 1.0, 0.01),
			_prop("range_bonus", "Portée", "integer", 0, 0.0, 10.0, 1.0),
			_prop("push_bonus", "Poussée", "integer", 0, 0.0, 10.0, 1.0),
			_prop("healing_and_shield_percent", "Soin et bouclier", "percent", 0.0, 0.0, 5.0, 0.01),
		],
	})
	_register({
		"effect_id": &"use.heal_flat", "runtime_class": "ItemDefinition.UseEffect.HEAL_FLAT",
		"display_name": "Soin fixe", "description": "Rend des PV via ItemUseService.",
		"group_name": "Consommation", "unit": "PV", "target": "Héros sélectionné",
		"duration": "Instantanée", "frequency": "À l’utilisation",
		"stacking_rule": "Consomme une unité", "properties": [
			_prop("use_value", "PV rendus", "number", 25.0, 1.0, 999.0, 1.0),
		],
	})
	_register({
		"effect_id": &"use.restore_ap_flat", "runtime_class": "ItemDefinition.UseEffect.RESTORE_AP_FLAT",
		"display_name": "Restauration de PA", "description": "Rend des PA via ItemUseService.",
		"group_name": "Consommation", "unit": "PA", "target": "Héros sélectionné",
		"duration": "Instantanée", "frequency": "À l’utilisation",
		"stacking_rule": "Consomme une unité", "properties": [
			_prop("use_value", "PA rendus", "integer", 1, 1.0, 6.0, 1.0),
		],
	})


func _register(data: Dictionary) -> void:
	var descriptor := ItemEffectDescriptor.new().configure(data)
	_descriptors[descriptor.effect_id] = descriptor


func _prop(
		property_name: String,
		label: String,
		widget: String,
		default_value: Variant,
		minimum := 0.0,
		maximum := 0.0,
		step := 0.0,
		enum_labels := {}
	) -> Dictionary:
	return {
		"property": property_name, "label": label, "widget": widget,
		"default": default_value, "min": minimum, "max": maximum,
		"step": step, "enum_labels": enum_labels.duplicate(true),
	}
