@tool
class_name ItemEffectDescriptor
extends RefCounted

var effect_id: StringName = &""
var runtime_class := ""
var display_name := ""
var description := ""
var group_name := ""
var unit := ""
var target := ""
var condition := "Toujours"
var duration := "Permanent"
var frequency := "Continue"
var stacking_rule := "Cumul contrôlé par instance"
var properties: Array[Dictionary] = []


func configure(data: Dictionary) -> ItemEffectDescriptor:
	effect_id = StringName(data.get("effect_id", &""))
	runtime_class = str(data.get("runtime_class", ""))
	display_name = str(data.get("display_name", ""))
	description = str(data.get("description", ""))
	group_name = str(data.get("group_name", ""))
	unit = str(data.get("unit", ""))
	target = str(data.get("target", ""))
	condition = str(data.get("condition", condition))
	duration = str(data.get("duration", duration))
	frequency = str(data.get("frequency", frequency))
	stacking_rule = str(data.get("stacking_rule", stacking_rule))
	properties.clear()
	for property_value in data.get("properties", []) as Array:
		properties.append((property_value as Dictionary).duplicate(true))
	return self


func to_snapshot() -> Dictionary:
	return {
		"effect_id": str(effect_id),
		"runtime_class": runtime_class,
		"display_name": display_name,
		"description": description,
		"group": group_name,
		"unit": unit,
		"target": target,
		"condition": condition,
		"duration": duration,
		"frequency": frequency,
		"stacking_rule": stacking_rule,
		"properties": properties.duplicate(true),
	}
