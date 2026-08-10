@tool
class_name ArenaDecorationLayerRegistry
extends RefCounted

const ENTRIES := {
	&"background_detail": {"parent_role": &"floor", "y_sorted": false, "z_index": -20, "runtime": true},
	&"floor_detail": {"parent_role": &"floor", "y_sorted": false, "z_index": -10, "runtime": true},
	&"props": {"parent_role": &"conditional", "y_sorted": true, "z_index": 0, "runtime": true},
	&"y_sorted_props": {"parent_role": &"y_sorted_world", "y_sorted": true, "z_index": 0, "runtime": true},
	&"foreground": {"parent_role": &"y_sorted_world", "y_sorted": true, "z_index": 20, "runtime": true},
	&"editor_only": {"parent_role": &"none", "y_sorted": false, "z_index": 0, "runtime": false},
}


static func has(layer: StringName) -> bool:
	return ENTRIES.has(layer)


static func get_entry(layer: StringName) -> Dictionary:
	return (ENTRIES.get(layer, {}) as Dictionary).duplicate(true)


static func all_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	result.assign(ENTRIES.keys())
	return result
